# Correção de cor pós-troca de painel LCD (VESA / JEIDA)

Artefatos da solução. Diagnóstico completo em
[`../../docs/research/28-troca-painel-rx058b-diagnostico-cor.md`](../../docs/research/28-troca-painel-rx058b-diagnostico-cor.md).

## Contexto
1ª troca (2026-07-10): painel de fábrica `RX058B-4300` (driver SC5010E, LVDS VESA) trocado por
`RX058B-0600`, que pediu **JEIDA**. 2ª troca (2026-10-29): o painel instalado é de novo um
`FPX-RX058B-4300-V0` `20241101 HT` e pediu **VESA**
([doc 40](../../docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §1). 3ª troca (2026-10-30): o painel
pediu **JEIDA**, e o aparelho está hoje em JEIDA ([doc 41](../../docs/research/41-auto-pareamento-camera-e-kit-universal.md) §8).
Sintoma de formato errado: primárias certas, preto e cinzas tingidos (a cor muda com a imagem).
**O formato não se deduz do nome do painel:** decide o teste de cinza. Sem PC, o kit de pendrive
(`pendrive-autorun/`, que leva uma cópia deste `lvdsctl`) faz o teste da escada de 16 cinzas (pela câmera interna ou pelo controle; a suíte de boot, [doc 44](../../docs/research/44-suite-de-boot.md), repete o teste a cada volta da tomada)
([doc 41](../../docs/research/41-auto-pareamento-camera-e-kit-universal.md) §4).

## Modo fácil: `pfl7560-lcd-color.sh` (na raiz do repo)

Script que faz tudo usando os arquivos deste diretório. Requer adb + root (Wi-Fi):
```
PFL_IP=<ip> ./pfl7560-lcd-color.sh status     # formato LVDS atual
PFL_IP=<ip> ./pfl7560-lcd-color.sh jeida       # aplica JEIDA (foi o caso do -0600 da 1a troca)
PFL_IP=<ip> ./pfl7560-lcd-color.sh vesa         # aplica VESA (painel de fábrica e o da 2a troca)
PFL_IP=<ip> ./pfl7560-lcd-color.sh test gamma   # projeta um padrão (barras|gamma|bits|nitidez|resolucao)
PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard       # guia leigo: BACKUP automático + testa VESA/JEIDA na tela
PFL_IP=<ip> ./pfl7560-lcd-color.sh backup arq.img   # salva o panelparam (valida 8 MiB + grava arq.img.md5)
PFL_IP=<ip> ./pfl7560-lcd-color.sh restore arq.img  # regrava o panelparam (com read-back de md5)
```
`jeida`/`vesa` aplicam ao vivo (sem reboot) e persistem no `panelparam`; antes de gravar, fazem o backup
do dia (`panelparam.backup-<serial>-<data>.img` + `.md5`) e abortam se ele falhar. `swap <0-5>`/`bit <0-1>`
para ajuste fino se nenhum formato bastar (pedem confirmação explícita; só fazem sentido se uma primária
sair no lugar da outra). O `wizard` faz um backup do `panelparam` antes de mexer e reverte
sozinho se a tela ficar preta (sem resposta em `WIZ_TIMEOUT`s, padrão 25). O `backup` valida que o dump
tem o tamanho da partição e grava um `.md5`; o `restore` confere tamanho + md5 e faz read-back após gravar
(não confia no exit code do `dd` via adb). O binário `lvdsctl` (pré-compilado, ARM) já acompanha.

**Integridade do binário versionado** (para auditar/reproduzir — decisão da sprint REPO-S2):
`lvdsctl` = ELF 32-bit ARM EABI5 PIE, 6348 bytes, **md5 `178d812872cb9306c0ae6faeed07184a`**.
Compilado com **NDK 27** (`armv7a-linux-androideabi24-clang`) a partir do `lvdsctl.c` deste diretório —
ver a seção de build abaixo. Para reproduzir do zero, recompile e confira o md5.

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
# o lvdsctl GRAVA na panelparam: faca antes o backup (./pfl7560-lcd-color.sh backup arq.img)
adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=/vendor/lib:/system/lib ./lvdsctl fmt 1"   # 1=JEIDA
# reverter para VESA:  ./lvdsctl fmt 0
# outros: swap <0-5> | bit <0-1> | map <valor>
```

## Padrões de teste (exibir via: adb push X.png /sdcard/ ; am start -a VIEW -d file:///sdcard/X.png -t image/png)

> **Ressalva (2026-09-03):** essa via funcionou em 2026-07-10 (doc 28), mas na sessão do
> [doc 39](../../docs/research/39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3 o `am start ... VIEW`
> abriu a galeria com **tela preta** (OPT-S13, aberto). Se a tela ficar preta, abra o PNG pelo gerenciador
> de arquivos com o controle remoto.

- `teste-cor-barras.png` — barras de cor puras rotuladas (discrimina swap de canal).
- `gamma-test.png` — gradientes + patches de cinza (discrimina gamma/bit-mapping nos meios-tons).
- `bits-test.png` — cada bit isolado por canal (decodifica o mapeamento de bits).
- `nitidez.png` — linhas de 1px + texto pequeno (foco e resolução efetiva).
- `resolucao.png` — réguas de resolução rotuladas (resolução nativa vs óptica).
