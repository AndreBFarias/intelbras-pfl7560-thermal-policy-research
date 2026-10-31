# 15 - O .bin: checksum do container decifrado (build EM QUARENTENA — brica o boot)

> **NOTA (2026-08-18) — este documento descreve o protótipo APAGADO.** A build aqui descrita embute a
> config `1ad641ed` (pré-escada de brilho) e tem CRC de vendor `0x35ca9b46`; ela **não existe mais** no
> repositório. O que continua válido aqui é o **método** (formato do container, os dois checksums
> CRC-32/MPEG-2, a edição in-place do sparse) — os números da build, não.
>
> **Bloco 21 (2026-10-31):** a build **viva** é `PFL7560-S4a-NAO-GRADUADO.bin` (md5 `a6e5da14…`, CRC de vendor
> `0x883b40d6`), gerada de novo pelo método in-place desta página, agora com o inode intacto (só o `i_size`
> muda); as builds `eae3a83d…` e `397698b9…` saíram de uso porque o re-pack delas usa chunks FILL e zeros soltos
> no slot, forma que o loader nunca gravou ([doc 47](47-build-completa.md) §10). Registro em
> [`../../firmware/README.md`](../../firmware/README.md). Nenhuma delas foi gravada.

O que faltava para gerar um firmware `.bin` flashável com a correção embutida era **entender os checksums
do container "LOAD"**. Isso foi feito revertendo o loader on-device, e os **checksums estão corretos**. Mas
o `.bin` resultante **trava o boot** em hardware (rótulo SELinux ausente nos arquivos reescritos) e está
**em quarentena — não flashe** (detalhes na seção "ATENÇÃO" abaixo e na [`16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md)).

## O formato "LOAD" e seus checksums (revertido do loader)

O flasher on-device (fastboot/loader HiSilicon, partição rec2 do `.bin`, função `hisi_file_verify_header`
@ VA `0x1406421c`) valida **um** checksum de container + os CRCs por partição:

| Campo | Onde | Algoritmo | Cobre |
|---|---|---|---|
| **checksum1** | `@0x04` (BE) | **CRC-32/MPEG-2** sobre `[0x00:header_len]` com `[0x04:0x08]` zerado; `header_len` = BE u32 `@0x08` (`0x2b4`) | **só o cabeçalho + tabela de partições** (metadados) |
| CRC por partição | prefixo `[len BE][CRC BE]` de cada partição | **CRC-32/MPEG-2** sobre o payload | os dados daquela partição (o do `deviceinfo`, record 5, não confere nem no stock e o loader o ignora) |
| CRC do blob do loader | prefixo `[len BE][CRC BE]` em `header_len` (`@0x2b4`/`@0x2b8`) | **CRC-32/MPEG-2** sobre os `len` bytes a partir de `0x2bc` | um blob ARM de 473912 B (começa com uma instrução `b`) que vem antes do record 0 |

CRC-32/MPEG-2 = poly `0x04C11DB7`, init `0xFFFFFFFF`, sem reflexão, sem xorout. É o **mesmo** primitivo para
os dois usos. Provado de duas formas: disassembly da função de verificação **e** reprodução empírica exata do
`checksum1` stock (`0x738ebd09`).

### Formato LOAD (layout medido no stock, bloco 21)

Esta é a referência do formato; os outros docs apontam para cá. Tudo big-endian.

| Onde | Campo |
|---|---|
| `0x00` | magic `LOAD` |
| `0x04` | `checksum1` |
| `0x08` | `header_len` (`0x2b4`) |
| `0x0c` | `file_len`, u64 (o tamanho do `.bin`: `0x531310bc` no V1.0.0.9) |
| `0x54 + 32*i`, i = 0..18 | imagem i: `img_length` u32, `offset` do prefixo u32, `flash_begin` u64, `flash_end` u64, `flash_type` u32, `flash_index` u32 |
| `0x2b4` | prefixo `[len][CRC]` do blob do loader; o blob vai de `0x2bc` até `0x73df4` |
| `offset` de cada imagem | prefixo `[len][CRC]` e o payload; os records são contíguos e sem alinhamento (`offset` = anterior + 8 + `len`) |

O vendor é a imagem 14: payload sparse de 80593044 B em `0x4b0b1d54` no V1.0.0.9 (`0x4b0bc954` no V1.0.0.1),
gravado na eMMC de `0x84000000` a `0x96c00000` (300 MiB, os 76800 blocos do ext4). O antigo "rodapé
`@0x2b8`/`@0x2bc`" é o prefixo do blob, e o "`flashOffset@+8`" do doc 01 é o `flash_begin` do record anterior.
Não há assinatura: o loader confere magic, `header_len`, `checksum1`, versões, serial, o CRC de cada partição e a
forma do sparse.

### Consequência-chave

`checksum1` cobre **apenas a tabela de partições**, não os payloads. Então: **se editarmos o payload de uma
partição mantendo o TAMANHO, a tabela não muda e o `checksum1` continua válido** — basta recalcular o **CRC
daquela partição**. Para mudar o tamanho de um record, mudam `img_length` dele, `offset` dos records seguintes,
`file_len` e `checksum1` (os mesmos campos que a HiSilicon muda entre V1.0.0.1 e V1.0.0.9; `--realocar` do
gerador, [doc 47](47-build-completa.md) §10).

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

## ATENÇÃO: este `.bin` NÃO deve ser flashado (em quarentena)

> **Este `.bin` foi TESTADO em hardware e TRAVA O BOOT** (fica preso na logo do Android). Causa: os 3
> arquivos reescritos na partição vendor via `debugfs write` ficaram **sem rótulo SELinux**
> (`security.selinux` xattr) e sem o modo/owner exato do stock. A CONFIG e os checksums estão certos — o
> problema é o **metadado dos arquivos**. Recuperamos via power-hold + `usb_update.bin` (ver
> [`16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md)). O arquivo foi renomeado para
> `firmware/PFL7560-FIX.NAO-USAR-brica-SELinux.bin`. **Use o método `/vendor` (autorun/adb), que é seguro.**

**Receita de metadados (implementada em `artifacts/bin-build/build_fix_bin.py`):**

Depois de cada `write`, o builder lê mode/uid/gid/`security.selinux` do **stock** e reaplica com:

- `sif <arq> mode 0100xxx` (**com** bit `S_IFREG` — `sif mode 0644` sozinho vira `bad type`)
- `sif uid/gid` iguais ao stock
- `ea_set … security.selinux <ctx>\000` (NUL terminal como no stock)

Valores V1.0.0.9: `ZYCustom.ini`/`init.bigfish.rc` → 0644 + `vendor_configs_file:s0`; `build.prop` → 0600 +
`vendor_file:s0`. O script **aborta** se o `.rc` ficar group-writable ou se o label faltar. **Bloco 21:** o
padrão do gerador voltou a ser o patch in-place, sem `debugfs write`: os bytes vão nos mesmos blocos e só o
`i_size` do inode muda, então modo, dono e rótulo nem são tocados; a receita acima vale para o `--realocar`.
**Ainda falta provar boot em hardware** antes de sair da quarentena; use pendrive de resgate oficial ao testar.

## Reprodutível

A receita completa (parser de sparse, edição, patch in-place, CRC) está em `artifacts/bin-build/`.
