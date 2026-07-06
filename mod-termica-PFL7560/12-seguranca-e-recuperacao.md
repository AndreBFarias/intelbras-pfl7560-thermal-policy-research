# 12 - Segurança e recuperação (à prova de pânico)

Feito para você não ter medo de perder o progresso. Regra de ouro do projeto: **nunca tocamos no bootloader
nem na imagem de firmware** — só gravamos **um arquivo de texto** em `/atv/ini`. Então o pior caso é sempre
recuperável, e nada disso pode brickar o aparelho.

## Onde está o seu "cofre" (no PC, longe do projetor)

| Arquivo | O que é | Para quê |
|---|---|---|
| `pfl7560-fix.sh` (raiz do projeto) | **script mestre auto-suficiente** (config embutida) | reaplica TUDO com 1 comando |
| `mod-termica-PFL7560/artefatos/ZYCustom_390.ini` | a build | o arquivo que é gravado |
| `mod-termica-PFL7560/artefatos/ZYCustom.ini.ORIGINAL` | `.ini` de fábrica | restaurar o stock |
| `Software PFL7560.zip` | **firmware de fábrica completo** | recuperação máxima (reflash) |
| `mod-termica-PFL7560/*.md` (01–12) | toda a pesquisa | conhecimento |

> **Faça HOJE:** copie a pasta inteira `Desktop/pfl7560/` para um **pen drive e/ou nuvem**. Esse é o seu seguro.
> O `pfl7560-fix.sh` sozinho já reaplica a correção mesmo se você perder todo o resto.

## Cenários que te dão medo — e a resposta

### 1. Restauração de fábrica (você ou alguém reseta o projetor)
- O que acontece: o reset **apaga `/atv/ini`** → a correção some → o aparelho volta ao firmware de fábrica
  (V1.0.0.9). **Não perde o firmware, não brica.**
- Recuperação: **1 comando** — `./pfl7560-fix.sh apply`. Pronto, tudo de volta em ~2 min.

### 2. Queda de energia com o projetor ligado
- O arquivo `/atv/ini/ZYCustom_390.ini` já está gravado e sincronizado no eMMC. Queda de luz **não corrompe** um
  arquivo já salvo. Ao religar, a correção continua lá. **Nada a fazer.**

### 3. Queda de energia / Wi-Fi bem no meio do `apply`
- O script grava e **confere o md5 ANTES de reiniciar**. Se a gravação foi interrompida, o md5 não bate e ele
  **aborta sem reiniciar**. Você só roda `./pfl7560-fix.sh apply` de novo. **Sem risco.**

### 4. Perdi o PC / a pasta do projeto
- O `pfl7560-fix.sh` é **auto-contido** (a config está embutida em base64 dentro dele). Basta ter esse 1 arquivo.
- Se perder até ele: o firmware de fábrica está no `Software PFL7560.zip`, e a correção inteira está documentada
  em `09` e `10` (dá pra refazer o `.ini` do zero).

### 5. "E se o projetor não ligar / travar?" (não deve acontecer por nossa causa)
- Nós **não tocamos no bootloader/recovery** — nossas mudanças não podem causar isso.
- Se um dia acontecer (motivo alheio): grave o `Software PFL7560.zip` (o `.bin` de fábrica) por pen drive FAT32
  via "Atualização local do sistema". Volta 100% ao original. (Recuperação de último caso: UART/HiTool.)

## Três camadas de recuperação (redundância)

1. **Re-aplicar:** `./pfl7560-fix.sh apply` (reinstala a correção).
2. **Reverter ao stock:** `./pfl7560-fix.sh revert` **ou** `rm /atv/ini/ZYCustom_390.ini` + reboot.
3. **Reflash total:** gravar o `Software PFL7560.zip` de fábrica por pen drive.

## Comandos do dia a dia

```
./pfl7560-fix.sh status    # ver como está (não muda nada)
./pfl7560-fix.sh apply     # aplicar/reaplicar a correção
./pfl7560-fix.sh revert    # voltar ao firmware de fábrica
PFL_IP=<ip> ./pfl7560-fix.sh status   # se a busca automática falhar, informe o IP
```

Enquanto o `.ini` de fábrica não mudar (ele é o mesmo em todo PFL7560 V1.0.0.9), essa correção é estável e
re-aplicável quantas vezes precisar. **Pode dormir tranquilo.**
