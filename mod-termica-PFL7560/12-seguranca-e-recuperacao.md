# 12 - Segurança e recuperação (à prova de pânico)

Feito para você não ter medo de perder o progresso. Regra de ouro do projeto: **nunca tocamos no bootloader
nem no recovery** — a correção são **três arquivos de texto** na partição **`/vendor`**
(`ZYCustom.ini`, `build.prop`, `init.bigfish.rc`). Então nenhuma mudança nossa pode impedir o aparelho de
ligar, e tudo é reversível.

> **Atenção — o `.bin` NÃO entra aqui.** O `PFL7560-FIX.bin` (Método 4) está **em quarentena** por travar o
> boot (rótulo SELinux ausente, ver [doc 16](16-recuperacao-brick.md)). Esta página cobre **só o método
> `/vendor`** (autorun por pendrive + `pfl7560-fix.sh`), que é o seguro.

## Onde está o seu "cofre" (no PC, longe do projetor)

| Arquivo | O que é | Para quê |
|---|---|---|
| `pfl7560-fix.sh` (raiz do projeto) | **script mestre auto-suficiente** (config embutida em base64) | reaplica/reverte TUDO com 1 comando |
| `backups-projetor/*.STOCK` (gerado no 1º `apply`) | os 3 arquivos de fábrica que o `apply` puxou do aparelho | fonte do `revert` |
| `mod-termica-PFL7560/artefatos/ZYCustom.ini.ORIGINAL` | `.ini` de fábrica versionado (md5 `29d8ba36…`) | stock de referência p/ backup/revert |
| `pendrive-autorun/` (`newlink_update.sh` + `ZYCustom.ini`) | autorun por pendrive | aplicar sem PC |
| `Software PFL7560.zip` | **firmware de fábrica completo** | recuperação máxima (reflash oficial) |
| `mod-termica-PFL7560/*.md` (01–16) | toda a pesquisa | conhecimento |

> **Faça HOJE:** copie a pasta inteira `Desktop/pfl7560/` para um **pen drive e/ou nuvem**. Esse é o seu seguro.
> O `pfl7560-fix.sh` sozinho já reaplica a correção mesmo se você perder todo o resto.

## Cenários que te dão medo — e a resposta

### 1. Restauração de fábrica (você ou alguém reseta o projetor)
- O que acontece: o reset de fábrica **limpa `/data`**, mas **NÃO** reescreve a partição `/vendor`. Como a
  correção mora em `/vendor` (que não tem dm-verity nesta build), ela **SOBREVIVE ao reset** — o aparelho
  continua corrigido. **Não perde a correção, não brica.**
- Se algum dia você quiser mesmo voltar ao stock, é **de propósito**: `./pfl7560-fix.sh revert` (ver abaixo).

### 2. Queda de energia com o projetor ligado
- Os 3 arquivos já estão gravados e sincronizados no eMMC (`sync` antes do reboot). Queda de luz **não
  corrompe** um arquivo já salvo. Ao religar, a correção continua lá. **Nada a fazer.**

### 3. Queda de energia / Wi-Fi bem no meio do `apply`
- O script grava cada arquivo de forma **atômica** (push para `*.new`, confere o md5 e só então `mv` por cima)
  e **confere tudo ANTES de reiniciar**. Se a gravação foi interrompida, o md5 não bate, o original fica
  intacto e ele **aborta sem reiniciar**. Você só roda `./pfl7560-fix.sh apply` de novo. **Sem risco.**

### 4. Perdi o PC / a pasta do projeto
- O `pfl7560-fix.sh` é **auto-contido** (a config está embutida em base64 dentro dele). Basta ter esse 1 arquivo
  para reaplicar. Ou use o **pendrive autorun** (`newlink_update.sh` + `ZYCustom.ini`), que aplica sem PC.
- Se perder até isso: o firmware de fábrica está no `Software PFL7560.zip`, e a correção inteira está
  documentada em `09` e `10` (dá pra refazer o `.ini` do zero).

### 5. "E se o projetor não ligar / travar?" (não deve acontecer pelo método `/vendor`)
- O método `/vendor` **não toca no bootloader/recovery** — nossas mudanças não podem causar isso.
- Se um dia acontecer (motivo alheio, ou por ter flashado o `.bin` em quarentena): a recuperação por
  **power-hold + `usb_update.bin`** (firmware de fábrica) está detalhada na [doc 16](16-recuperacao-brick.md).
  Último caso: UART/console U-Boot.

## Três camadas de recuperação (redundância)

1. **Re-aplicar:** `./pfl7560-fix.sh apply` (reinstala a correção) — ou plugar o pendrive autorun e ligar.
2. **Reverter ao stock:** `./pfl7560-fix.sh revert` — restaura os 3 arquivos de `backups-projetor/*.STOCK`
   (só funciona se o backup existir e for válido; o `apply` o cria na 1ª vez). Alternativa manual: com adb
   root e `/vendor` remontado rw, empurrar de volta os 3 `.STOCK` (`ZYCustom.ini`, `build.prop`,
   `init.bigfish.rc`) para `/vendor/…` e reiniciar.
3. **Reflash total:** gravar o `Software PFL7560.zip` de fábrica por pen drive FAT32 pela "Atualização local
   do sistema" (menu do projetor). Volta 100% ao original.

## Comandos do dia a dia

```
./pfl7560-fix.sh status    # ver como está (não muda nada)
./pfl7560-fix.sh apply     # aplicar/reaplicar a correção (backup + 3 fixes + reboot)
./pfl7560-fix.sh revert    # voltar ao stock (restaura backups-projetor/*.STOCK)
PFL_IP=<ip> ./pfl7560-fix.sh status   # se a busca automática falhar, informe o IP
```

Enquanto o `.ini` de fábrica não mudar (ele é o mesmo em todo PFL7560 V1.0.0.9), essa correção é estável e
re-aplicável quantas vezes precisar. **Pode dormir tranquilo.**
