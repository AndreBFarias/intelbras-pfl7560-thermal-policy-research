# 14 - Estado final aplicado (o que realmente ficou no aparelho)

Data: 2026-07-05, fim da sessão. Este doc reflete o que **de fato** está no projetor agora.

## Método definitivo: edição direta do `/vendor` (não o `.bin`)

O flash do `.bin` modificado **reverteu tudo** (rejeitado por um checksum de container não decifrado — ver
"#2" abaixo). Isso nos levou ao método melhor: **editar a partição `/vendor` direto por adb**. Como o `/vendor`
não tem dm-verity, isso é seguro, e por estar em `/vendor` **sobrevive a uma restauração de fábrica** — o que
era o objetivo do `.bin`, mas sem o risco de brick.

Aplicado via `pfl7560-fix.sh apply` (na raiz do projeto), que faz backup do stock antes e é reversível
(`pfl7560-fix.sh revert`).

## Os 3 fixes ativos (todos no `/vendor`, permanentes)

| Fix | Onde | O que faz | Estado |
|---|---|---|---|
| Térmico | `/vendor/etc/ZYCustom.ini` (md5 `252ab7a7…`) | 2º sensor ativo (`HW_VIRTUAL_CHANNEL=1`), fans 100% sempre, brilho 100% abaixo de 66 °C com escada 1000→850 acima disso (atuou no uso normal com a sala a 34 °C, doc 40 §2), shutdown 75 °C | validado |
| Wi-Fi | `/vendor/build.prop` `wifi_disconnect_on_boot=0` | reconecta ao Wi-Fi sozinho após reboot | validado (reconectou sozinho) |
| Xiri | `/vendor/etc/init/hw/init.bigfish.rc` (`disabled` no `xiriservice`) | para o spam de `xirivoice` no log | validado (spam = 0) |

## Validação medida (pós-reboot, automática)

```
PROJETOR VOLTOU SOZINHO no Wi-Fi  ->  fix do Wi-Fi OK
gtt0 = 24,5 °C (sensor cego)  |  gtt1 = 61,1 °C (sensor REAL vivo)
fan speed = 1000 / 1000  (máximo desde o boot)
backlight = 1000 (100%)
wifi_disconnect_on_boot = 0  (persistente)
overheat warnings = 0  (61 < 70)
xirivoice spam = 0
```
Resultado térmico medido antes: saída de ar 46,7 °C (stock) -> 37,2 °C (build) -> 32,9 °C (+ fan externo).

## Trade-offs / observações

- Xiri desabilitado pode afetar mirroring estilo **AirPlay/eShare**; o **Miracast** principal
  (`com.hisilicon.miracast`) é independente e continua funcionando.
- Backups do stock em `artifacts/` e em `backups-projetor/` (criado pelo `.sh` no 1º apply):
  `ZYCustom.ini.STOCK`, `build.prop.STOCK`, `init.bigfish.rc.STOCK`.

## Sobre o `.bin` distribuível (#2 - decifrado, construído e EM QUARENTENA)

Atualização (2026-07-06): a investigação avançou muito além do que dizia a versão anterior deste doc. O
resumo do estado **real** hoje:

- **Checksum do container FOI decifrado.** Revertendo o loader on-device, provou-se que o `checksum1` do
  container "LOAD" (`@0x04`) é **CRC-32/MPEG-2 sobre o cabeçalho + tabela de partições** (cobre só os
  metadados, não os payloads), e que os CRCs por partição também são CRC-32/MPEG-2. Detalhes e prova em
  [`15-bin-definitivo.md`](../research/15-bin-definitivo.md).
- **O `.bin` foi CONSTRUÍDO e é byte-reproduzível.** A receita (`artifacts/bin-build/build_fix_bin.py`) edita
  só a partição vendor mantendo o tamanho — a tabela não muda, o `checksum1` segue válido, e recalcula-se só o
  CRC daquela partição. Rodar 2× dá o mesmo md5.
- **Foi TESTADO em hardware — e TRAVA O BOOT.** O flash completou, mas o aparelho passou a travar na logo do
  Android. Causa: os 3 arquivos reescritos via `debugfs write` ficaram **sem rótulo SELinux**
  (`security.selinux` xattr) e sem o modo/owner exato do stock. A CONFIG e os checksums estão certos — o
  defeito é o **metadado dos arquivos**. Por isso o `.bin` foi posto em **quarentena**:
  `firmware/PFL7560-FIX.NAO-USAR-brica-SELinux.bin`. **Não flashe.** Ver [`16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md).
- **A recuperação do brick funcionou.** Power-hold ao ligar + `usb_update.bin` (firmware de fábrica) num
  pendrive separado reflasha o stock pelo loader HiSilicon, sem abrir o aparelho. Passo a passo na
  [`16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md).
- **O modelo de AUTONOMIA foi validado.** O autorun no pendrive reaplica o fix a cada boot de forma
  idempotente; o `usb_update.bin` recupera qualquer brick. Mesmo assim, o método **`/vendor` continua sendo o
  definitivo e seguro** para o seu aparelho — não precisa de `.bin`.
- **Auditoria e hardening.** Os scripts de entrega (autorun + `pfl7560-fix.sh`) passaram por auditoria
  adversarial e foram endurecidos; ver [`17-auditoria-e-hardening.md`](17-auditoria-e-hardening.md). O plano
  para produzir um `.bin` que **boota** (corrigir os rótulos SELinux) está em
  [`18-sprint-bin-futuro.md`](18-sprint-bin-futuro.md).

Para o SEU aparelho, nada disso é necessário — o método `/vendor` já resolveu, permanente.
