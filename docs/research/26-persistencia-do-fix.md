# 26 - Persistência do fix e método de escrita no /vendor

Registro da investigação de campo de **2026-07-09**, feita ao vivo por adb durante a sessão de
captura de evidências. Resolve uma dúvida legítima: **o fix realmente sobrevive a reboots?**

## TL;DR

- **Sim, o fix persiste.** Gravado na partição `/vendor` real, sobrevive ao reboot (testado).
- O `/vendor` é uma **partição ext4 real** (`/dev/block/...by-name/vendor`), montada `ro`, **sem dm-verity**.
- Tanto `adb remount` quanto `mount -o rw,remount /vendor` tornam a partição **rw real** — **não** criam overlay volátil neste aparelho (hipótese testada e **refutada**).
- Os 3 fixes (térmico, Wi-Fi, xiri) foram confirmados **persistentes** após reboot.
- Houve **uma reversão pontual** do `ZYCustom.ini` para stock (observada no início da sessão) que **não se reproduziu** — causa provável: resgate/reflash recente ou ação manual. Fica como questão aberta.

## Contexto (o que gerou a dúvida)

No início da sessão, o aparelho aparecia **corrigido** (`gtt1 ~61 °C`, `HW_VIRTUAL_CHANNEL = 1`).
Minutos depois, após um reboot (uptime ~369 s), apareceu **stock**: `gtt0 == gtt1 == 26,36 °C`,
`/vendor/etc/ZYCustom.ini` com md5 `29d8ba36…` (fábrica). Sem pendrive plugado (`/mnt/media_rw` vazio),
sem overlay montado. Isso levantou a hipótese de que **o fix nunca teria persistido** — que o que o
"segurava" seria o pendrive-autorun reaplicando a cada boot.

## Investigação (fatos do device)

```
# /vendor é partição ext4 REAL, montada ro, sem verity:
/dev/block/platform/soc/f9830000.emmc/by-name/vendor /vendor ext4 ro,seclabel,relatime,...

# adb remount NÃO cria overlay — deixa a MESMA partição rw:
$ adb remount            # -> "remount succeeded"
/dev/block/...by-name/vendor /vendor ext4 rw,...     # sem linha 'overlay' em /proc/mounts
```

Props de verity (`ro.boot.veritymode`, `partition.vendor.verified`) vazias. Ou seja: a escrita em
`/vendor` vai para a **partição eMMC real** e é durável — não há redirecionamento para tmpfs/overlay.

## Teste de persistência (o experimento)

1. Estado inicial: `ZYCustom.ini` = stock (`29d8ba36…`).
2. `mount -o rw,remount /vendor` (rc=0, partição real vira rw).
3. Escrita atômica do fix (`ZYCustom_390.ini`, md5 `1ad641ed…`): `push .new` -> confere md5 -> `chmod 644` -> `mv`.
4. Confirmação pré-reboot na partição: md5 = `1ad641ed…`.
5. **Reboot.**
6. Pós-reboot: md5 = **`1ad641ed…`** (persistiu) e sensores **`gtt0 = 24,5 °C · gtt1 = 65,8 °C`** (mux vivo, fix ativo).

Nota sobre `mtime`: o arquivo fica com data `2026-07-06` mesmo escrito em `2026-07-09` porque o
`adb push` **preserva o timestamp do arquivo de origem** (o artefato `ZYCustom_390.ini` do repo é de
2026-07-06). Não é sinal de overlay nem de restauração — é comportamento normal do `adb push`.

## Conclusões (confirmado)

- O fix **persiste** reboots quando gravado na partição `/vendor` real.
- **`adb remount` é suficiente** neste aparelho (grava na partição real). O `pfl7560-fix.sh`, que usa
  `adb remount`, **não tem** bug de overlay — a suspeita inicial foi **refutada** pelo teste.
- Os 3 fixes foram confirmados persistentes na partição, byte a byte:
  - térmico `ZYCustom.ini` = `1ad641ed…`
  - Wi-Fi `build.prop`: `wifi_disconnect_on_boot=0`
  - xiri `init.bigfish.rc`: `disabled` após `service xiriservice`

## Questão aberta

A reversão pontual do `ZYCustom.ini` para stock (observada uma vez, no início) **não foi reproduzida**
no teste controlado. Hipóteses não descartadas: (a) resíduo do resgate/reflash pós-brick recente;
(b) ação manual durante a troca de fontes de vídeo.

**Recomendação — CORRIGIDA.** A versão anterior deste doc mandava manter o **pendrive-autorun plugado
como garantia**. **Não faça isso:** ligar o projetor segurando o botão de power com um pendrive plugado
dispara o modo de upgrade do loader, que regrava o firmware e **formata o `/data`** — a "garantia" custa
mais do que o risco que cobre. Guarde o pendrive de autorun **desconectado** no dia a dia e apenas
**monitore** se a reversão recorre; se recorrer, reaplique com `pfl7560-fix.sh apply` e reabra esta
investigação. Mesma regra em [`../../INSTALL.md`](../../INSTALL.md) e em
[`../../pendrive-autorun/LEIA-ME.txt`](../../pendrive-autorun/LEIA-ME.txt).

## Correções de documentação associadas (mesma sessão)

- **USB-C não expõe adb** neste aparelho (só vídeo). Única via de adb = Wi-Fi. Ver doc 06 (corrigido).
- **Wi-Fi só ativo no launcher** (tela inicial do Android). Ao exibir fonte HDMI externa, o Wi-Fi dorme
  e o adb cai. Ver doc 06.

## Como reproduzir (read-only + teste)

```
# 1) confirma que /vendor é partição real, sem overlay:
adb -s <ip>:5555 shell 'grep -w /vendor /proc/mounts; grep -i overlay /proc/mounts'
# 2) confirma que adb remount grava na partição real (não overlay):
adb -s <ip>:5555 remount ; adb -s <ip>:5555 shell 'grep -w /vendor /proc/mounts'
# 3) teste de persistência: grava o fix, reinicia, relê o md5:
#    (use pfl7560-fix.sh apply, ou mount -o rw,remount + push atômico)
adb -s <ip>:5555 shell 'md5sum /vendor/etc/ZYCustom.ini'   # esperado 252ab7a72a007a8b79b3fc86bd5c0d19 após reboot
```
