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
| Térmico | `/vendor/etc/ZYCustom.ini` (md5 `1ad641ed…`) | 2º sensor ativo (`HW_VIRTUAL_CHANNEL=1`), fans 100% sempre, brilho 100%, shutdown 75 °C | validado |
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
- Backups do stock em `mod-termica-PFL7560/artefatos/` e em `backups-projetor/` (criado pelo `.sh` no 1º apply):
  `ZYCustom.ini.STOCK`, `build.prop.STOCK`, `init.bigfish.rc.STOCK`.

## Sobre o `.bin` distribuível (#2 - em investigação)

O `.bin` modificado **não foi aceito** pelo updater. Motivo confirmado: além do CRC-32/MPEG-2 por partição
(que recalculamos certo), o container "LOAD" tem **checksums de nível-container** (cabeçalho `@0x04` = `0x738ebd09`;
rodapé `@0x2b8`/`@0x2bc`) que **não** recalculamos. Força-bruta descartou CRC/soma/xor simples sobre a imagem
inteira e sobre os payloads — é um esquema específico do formato. Para fechar o `.bin` flashável (útil só para
**distribuir a quem não usa adb**), o caminho é **reverter o updater on-device** (recovery ramdisk / scripts de
update) e ver exatamente o que ele calcula. Investigação dedicada em andamento.

Para o SEU aparelho, nada disso é necessário — o método `/vendor` já resolveu, permanente.
