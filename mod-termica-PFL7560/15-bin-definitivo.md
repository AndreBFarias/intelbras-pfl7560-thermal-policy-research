# 15 - O .bin definitivo (checksum decifrado + build verificado)

O que faltava para gerar um firmware `.bin` flashável com a correção embutida era **entender os checksums
do container "LOAD"**. Isso foi feito revertendo o loader on-device. Resultado: o `.bin` corrigido existe,
verificado end-to-end.

## O formato "LOAD" e seus checksums (revertido do loader)

O flasher on-device (fastboot/loader HiSilicon, partição rec2 do `.bin`, função `hisi_file_verify_header`
@ VA `0x1406421c`) valida **um** checksum de container + os CRCs por partição:

| Campo | Onde | Algoritmo | Cobre |
|---|---|---|---|
| **checksum1** | `@0x04` (BE) | **CRC-32/MPEG-2** sobre `[0x00:0x2b4]` com `[0x04:0x08]` zerado; length = BE u32 `@0x08` | **só o cabeçalho + tabela de partições** (metadados) |
| CRC por partição | prefixo `[size BE][CRC BE]` de cada partição | **CRC-32/MPEG-2** sobre o payload | os dados daquela partição |
| rodapés | `@0x2b8`/`@0x2bc` | metadados do empacotador | **NÃO são lidos/verificados** pelo loader |

CRC-32/MPEG-2 = poly `0x04C11DB7`, init `0xFFFFFFFF`, sem reflexão, sem xorout. É o **mesmo** primitivo para
os dois usos. Provado de duas formas: disassembly da função de verificação **e** reprodução empírica exata do
`checksum1` stock (`0x738ebd09`).

### Consequência-chave

`checksum1` cobre **apenas a tabela de partições**, não os payloads. Então: **se editarmos o payload de uma
partição mantendo o TAMANHO, a tabela não muda e o `checksum1` continua válido** — basta recalcular o **CRC
daquela partição**. Os rodapés `@0x2b8`/`@0x2bc` podem ficar intactos (o loader os ignora).

## A build (o que foi feito)

Partição alvo: **vendor = record 14** (prefixo `@0x4b0b1d54`, payload em `+8`, tamanho `0x4cdc094` =
80593044 bytes). O payload é um **Android sparse image** (ext4, sem dm-verity, sem `metadata_csum`, sem journal).

1. Extraí o vendor e expandi o sparse → ext4 raw (314 MB).
2. Substituí 3 arquivos via `debugfs` (mantendo a contagem de blocos):
   - `/etc/ZYCustom.ini` → a build térmica (`1ad641ed`, 2º sensor, fans/brilho 100%, shutdown 75 C);
   - `/build.prop` → `wifi_disconnect_on_boot=0`;
   - `/etc/init/hw/init.bigfish.rc` → `xiriservice` com `disabled`.
3. **Patch in-place no sparse**: os 11 blocos alterados caíram todos em chunks RAW, então reescrevi só esses
   bytes no sparse original → **tamanho idêntico** (80593044). Round-trip conferido (expandir o sparse novo
   dá exatamente o ext4 editado).
4. Recalculei o CRC da partição: `0xdd5cdc49` (stock) → **`0x35ca9b46`** (novo). Gravei BE no prefixo.
5. `checksum1` @0x04: **inalterado `0x738ebd09`** (tabela intacta) — verificado.

Todo o resto do `.bin` é **byte-idêntico ao stock**. Só a partição vendor mudou.

O build é **byte-reproduzível**: o `debugfs`/`e2fsck` carimbam a hora atual nos inodes dos 3 arquivos e
no superbloco (`s_wtime`/`s_lastcheck`); o script fixa esses campos, então rodar 2× dá o mesmo md5.

## Verificação (tudo OK)

```
tamanho .bin        1393758396  (== stock)
checksum1 @0x04     0x738ebd09  (inalterado, valido p/ o loader)
CRC vendor          0x35ca9b46  (recalculado)
ext4 vendor         e2fsck limpo
ZYCustom embutido   md5 1ad641ed  |  HW_VIRTUAL_CHANNEL Thermistor_1 = 1
build.prop embutido wifi_disconnect_on_boot=0
init embutido       xiriservice disabled
```

Arquivo: **`PFL7560-FIX.bin`** · md5 `f5ff89c95f6ff9e622a9097d14b0c222` (byte-reproduzível a partir do
stock de referência).

## Como flashar (opcional)

Pela "Atualização local do sistema" do menu, o projetor procura **`PFL7560.bin`** na raiz do pendrive.
Para flashar o corrigido: renomeie `PFL7560-FIX.bin` → `PFL7560.bin` e rode o update. **Recuperação:** o
firmware de fábrica (o `PFL7560.bin` stock) volta tudo.

> **Honestidade:** o `.bin` está **verificado internamente** (checksums válidos + fs correto), mas **ainda
> não testado em hardware**. Como o SEU projetor já está corrigido pelo método `/vendor` (permanente), este
> `.bin` é para **distribuição** e para quem prefere um flash único. Se for testar, tenha o `.bin` stock à mão.

## Reprodutível

A receita completa (parser de sparse, edição, patch in-place, CRC) está em `artefatos/bin-build/`.
