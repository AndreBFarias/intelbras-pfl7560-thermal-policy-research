# Correção de cor pós-troca de painel LCD (VESA -> JEIDA)

Artefatos da solução. Diagnóstico completo em
[`../../docs/research/28-troca-painel-rx058b-diagnostico-cor.md`](../../docs/research/28-troca-painel-rx058b-diagnostico-cor.md).

## Contexto
Painel de fábrica `RX058B-4300` (driver SC5010E, LVDS VESA) trocado por `RX058B-0600` (LVDS JEIDA).
Sintoma: cores certas nas primárias, embaralhadas nos meios-tons. Correção: emitir LVDS em JEIDA.

## Modo fácil: `pfl7560-lcd-color.sh` (na raiz do repo)

Script que faz tudo usando os arquivos deste diretório. Requer adb + root (Wi-Fi):
```
PFL_IP=<ip> ./pfl7560-lcd-color.sh status     # formato LVDS atual
PFL_IP=<ip> ./pfl7560-lcd-color.sh jeida       # aplica a correção (RX058B-0600)
PFL_IP=<ip> ./pfl7560-lcd-color.sh vesa         # reverte (RX058B-4300)
PFL_IP=<ip> ./pfl7560-lcd-color.sh test gamma   # projeta um padrão (barras|gamma|bits|nitidez|resolucao)
PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard       # guia leigo: aplica JEIDA e pergunta
PFL_IP=<ip> ./pfl7560-lcd-color.sh backup       # salva o panelparam antes de mexer
```
`jeida`/`vesa` aplicam ao vivo (sem reboot) e persistem no `panelparam`. `swap <0-5>`/`bit <0-1>` para
ajuste fino se nenhum formato bastar. O binário `lvdsctl` (pré-compilado, ARM) já acompanha.

## lvdsctl.c
Programa ARM que faz `dlopen` na `libhitvservice.so` do aparelho e chama
`HiPanelCtrl::SetLvdsFormat/Swap/BitMode/Map` (após `HI_SYS_Init` + `HiPanelCtrl::Init`).
Aplica ao vivo (sem reboot) e grava no `panelparam` (byte 0x5c do perfil).

Compilar (NDK):
```
$NDK/toolchains/llvm/prebuilt/*/bin/armv7a-linux-androideabi24-clang -o lvdsctl lvdsctl.c -ldl
```
Usar no aparelho (root):
```
adb push lvdsctl /data/local/tmp/ ; adb shell chmod 755 /data/local/tmp/lvdsctl
adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=/vendor/lib:/system/lib ./lvdsctl fmt 1"   # 1=JEIDA
# reverter para VESA:  ./lvdsctl fmt 0
# outros: swap <0-5> | bit <0-1> | map <valor>
```

## Padrões de teste (exibir via: adb push X.png /sdcard/ ; am start -a VIEW -d file:///sdcard/X.png -t image/png)
- `teste-cor-barras.png` — barras de cor puras rotuladas (discrimina swap de canal).
- `gamma-test.png` — gradientes + patches de cinza (discrimina gamma/bit-mapping nos meios-tons).
- `bits-test.png` — cada bit isolado por canal (decodifica o mapeamento de bits).
- `nitidez.png` — linhas de 1px + texto pequeno (foco e resolução efetiva).
- `resolucao.png` — réguas de resolução rotuladas (resolução nativa vs óptica).
