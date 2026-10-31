# Mapa do repositório

Onde está cada coisa, quem chama, que teste cobre e que doc explica. O código não tem comentário: o porquê de cada
decisão está nas **notas do código** (`docs/codigo/`), uma por área.

## Pastas

| Pasta | O que tem | Notas do código |
|---|---|---|
| `pendrive-autorun/` | o kit que roda no projetor (vai para a raiz de um pendrive FAT32); ASCII puro, md5 de cada arquivo conferido | [kit](codigo/kit.md) |
| raiz | comandos do PC (`pfl7560-*.sh`), instaladores, `Makefile` | [pc](codigo/pc.md) |
| `artifacts/app`, `home`, `tema`, `overlay` | os APKs do MeowCast, a paleta, a marca e as 20 sobreposições | [apps](codigo/apps.md) |
| `artifacts/tela`, `camcheck`, `lcd-color-fix` | os binários ARM do kit, em C | [binários](codigo/binarios.md) |
| `artifacts/bin-build` | o gerador do `.bin` | [bin](codigo/bin.md) |
| `artifacts/` (soltos), `historico/`, `firmware-extraido/` | arquivos de fábrica e da correção com md5 fixo ([tabela](../artifacts/README.md)); histórico; extraídos do firmware | — |
| `tests/` | provas no PC, com aparelho de mentira | [testes](codigo/testes.md) |
| `docs/` | `research/` (referência e sessões, 01 a 48), `guide/`, `sprints/` (um arquivo por bloco), `archive/`, `disclosure/` | [índice](README.md) |
| `firmware/` | zips oficiais (Git LFS), `.md5` das nossas builds; os `.bin` são locais | [README](../firmware/README.md) |
| `media/` | fotos do aparelho aberto | [README](../media/README.md) |
| fora do git | `evidencias/` (medições), `backups-projetor/` (backups de fábrica do aparelho), `private/`, `firmware/*.bin` | — |

## Pontos de entrada

| Quando | O que roda | Como |
|---|---|---|
| pendrive plugado no boot | `pendrive-autorun/newlink_update.sh` | o `/vendor/bin/nl_usb_update.sh` de fábrica o executa como root em `sys.boot_completed=1` |
| logo depois, destacado | `suite.sh pendrive` (com a suíte) ou `cor.sh` (sem ela) | lançados pelo autorun com `setsid` |
| todo boot, com o kit instalado | `/data/vendor/pfl7560-suite/suite-boot.sh` | serviço `pfl7560_suite` do `/vendor/etc/init/pfl7560-suite.rc` |
| ícone "Verificar projetor", botão Luz, descanso de tela | `suite-pedido.sh` | o vigia (`inotifyd`) que o `suite-boot.sh` liga |
| boot depois de um teste de cor interrompido | `/data/local/nlsu/update_after_boot.sh` → `cor.sh --restaurar` | gancho de fábrica do `init.bigfish.rc` |
| no PC | `install.sh` / `install.bat` (pendrive), `pfl7560-fix.sh` (adb), `pfl7560-menu.sh` | à mão |

## Código, arquivo a arquivo

### Kit (`pendrive-autorun/`)

| Arquivo | O que é | Quem chama | Teste | Doc |
|---|---|---|---|---|
| `newlink_update.sh` | confere o kit, aplica a térmica, instala suíte, apps, sobreposições e marca | firmware (autorun) | `test-kit-pendrive.sh`, `test-suite.sh` | 41, 44 |
| `cor.sh` | cor pela câmera (VESA/JEIDA), backup, journal, gancho | autorun, `suite.sh`, gancho | `test-kit-pendrive.sh` | 41 |
| `suite.sh` | a suíte: cor, ângulo, foco, nitidez, temperatura, rampa, resumo; `--desinstalar` | autorun, `suite-boot.sh`, `suite-pedido.sh` | `test-suite.sh` | 44 |
| `suite-boot.sh` | gatilho do boot, luz, descanso, sobreposições, apps desligados, vigia | serviço de boot | `test-suite.sh` | 44 |
| `suite-pedido.sh` | pedidos do app e da home (verificação, luz, descanso) | vigia | `test-suite.sh` | 44 §13, §14 |
| `pfl7560-suite.rc` | o serviço de boot | autorun copia para `/vendor/etc/init` | `test-suite.sh` | 44 §2 |
| `ZYCustom.ini` | a correção térmica (md5 `252ab7a7…`) | autorun | `make check` | 08, 34 |
| `lvdsctl`, `nl_camcheck`, `nl_tela` | binários ARM (cópias de `artifacts/`) | `cor.sh`, `suite.sh` | `test-camcheck.sh`, `test-tela.sh` | 28, 41, 44 |
| `pfl7560.apk`, `pfl7560-home.apk`, `overlay/*.apk`, `marca/*` | cópias de `artifacts/` | autorun instala | `atualizar-md5-kit.sh --check` | 44 §15, 45, 48 |
| `kit/*.png`, `fontes/*`, `LEIA-ME.txt` | telas estáticas, IBM Plex (OFL), leia-me | `cor.sh`, `nl_tela`, pessoa | `simula-padroes-kit.py`, `test-tela.sh` | 41 |

### PC (raiz)

| Arquivo | O que é | Teste | Doc |
|---|---|---|---|
| `install.sh`, `install.bat`, `install-firmware-pendrive.ps1` | preparam o PC e copiam o kit (e o firmware) para o pendrive | `test-preparar-pendrive.sh`, `test-kit-pendrive.sh` (texto do `.bat`) | INSTALL |
| `pfl7560-fix.sh` | térmica por adb: `apply`, `status`, `revert`, nos dois modelos | `test-fix-modelo.sh`, `make check` | 09, 42 |
| `pfl7560-menu.sh`, `PFL7560-Corrigir.desktop` | menu sobre o `pfl7560-fix.sh` | — | INSTALL |
| `pfl7560-saude.sh` | 12 checagens só de leitura; `--vivacidade` | — | 35, 37 |
| `pfl7560-vigia-lsadc.sh`, `pfl7560-monitor-props.sh` | acompanham a proteção sem sondar | — | 35, 37 |
| `pfl7560-monitor-termico.sh`, `pfl7560-autocaptura.sh`, `pfl7560-teste-brilho.sh` | medições que sondam o sensor | — | 34, 35, 39 |
| `pfl7560-evidencias.sh` | dossiê antes/depois | — | disclosure |
| `pfl7560-lcd-color.sh` | cor depois da troca do painel, com backup | — | 28, guia 32 |
| `pfl7560-processos.sh`, `pfl7560-qualidade.sh` | CPU em segundo plano; ajustes de imagem | `test-processos.sh`, `test-qualidade.sh` | 46 |
| `pfl7560-marca.sh`, `pfl7560-vlc.sh` | marca na partição `logo`; VLC como app do sistema | `test-pc-marca-vlc.sh` | 44 §15 |
| `Makefile` | os quatro alvos de prova | — | `tests/README.md` |

### `artifacts/`

| Arquivo | O que é | Quem chama | Teste | Doc |
|---|---|---|---|---|
| `app/build.sh`, `app/src/**/*.java`, `app/gerar-icones.py` | app "Verificar projetor", "Wi-Fi" e descanso de tela | à mão | `test-kit-pendrive.sh` (versionCode, md5) | 44 §7, §14 |
| `home/build.sh`, `home/src/**/*.java` | home MeowCast | à mão | `gerar-previas.sh` (navegação do D-pad) | 45 |
| `home/gerar-previas.sh`, `home/previa-src/**/*.java` | prévias da home no PC | à mão | — | 45 |
| `tema/gerar-fundo.py`, `gerar-marca.py`, `gerar-previa.py` | plano de fundo, marca de boot, prévia das telas | à mão, `pfl7560-marca.sh` | — | `tema/README` |
| `overlay/build.sh` | as 20 sobreposições | à mão | `overlay/conferir.py` | 48 |
| `overlay/recolorir.py`, `molde-alvo.py` | imagens recoloridas e ids do alvo (uma vez por firmware) | à mão, `build.sh` | `conferir.py` | 48 |
| `overlay/gerar-previa*.py` | folhas de prévia por bloco | à mão | — | 48 |
| `tela/nl_tela.c` | telas da suíte em PNG | `suite.sh` | `test-tela.sh` | 44 §5 |
| `camcheck/nl_camcheck.c` | câmera: faixas, níveis, geometria, nitidez | `cor.sh`, `suite.sh` | `test-camcheck.sh` | 41, 44 |
| `lcd-color-fix/lvdsctl.c` | troca o formato LVDS ao vivo | `cor.sh`, `pfl7560-lcd-color.sh` | `atualizar-md5-kit.sh` (md5 fixo) | 28, 40 |
| `bin-build/build_fix_bin.py`, `sparse.py` | gera e confere o `.bin` | à mão | `test-builder-bin.py` | 47, 15 |

### `tests/`

| Arquivo | Prova |
|---|---|
| `check-stock-md5.sh` | os 9 md5 de contrato (`make check`) |
| `test-kit-pendrive.sh`, `test-suite.sh` | kit e suíte reais contra aparelho de mentira |
| `test-camcheck.sh`, `test-tela.sh` | binários do host sobre quadros reais e exemplos; recompila o ARM com o NDK |
| `test-preparar-pendrive.sh`, `test-processos.sh`, `test-pc-marca-vlc.sh`, `test-qualidade.sh`, `test-fix-modelo.sh` | scripts do PC com `adb` e discos de mentira |
| `test-builder-bin.py` | gerador do `.bin` (`make check-bin`) |
| `simula-padroes-kit.py`, `gerar-padroes-kit.py` | telas de cor do kit |
| `atualizar-md5-kit.sh` | regrava (ou `--check`) as listas de md5 embutidas no kit |
| `preparar-pendrive.sh` | **formata** um pendrive e copia o kit (não é teste) |

## Fluxo de dados no aparelho

| Caminho | Quem escreve | Quem lê | O que é |
|---|---|---|---|
| `/vendor/etc/ZYCustom.ini`, `/vendor/build.prop`, `/vendor/etc/init/hw/init.bigfish.rc` | autorun, `pfl7560-fix.sh` | firmware | os 3 fixes (o `/atv/ini/ZYCustom*.ini`, se existir, vence) |
| `/data/vendor/pfl7560-kit/` | autorun | `cor.sh`, gancho | cópia conferida do kit, `journal`, `panelparam-original.img`, `cor.log` |
| `/data/vendor/pfl7560-suite/` | autorun, scripts da suíte | suíte | scripts e binários conferidos; `gatilho`, `luz`, `luz-antes-descanso` (nível do `gbl` guardado no início do descanso), `historico-boot.txt`, `resultados.txt`, `ultimo.log`, `incompletas`, `marca-original/` |
| `/vendor/etc/init/pfl7560-suite.rc` | autorun | init | serviço de boot |
| `/vendor/app/PFL7560`, `/vendor/app/PFL7560Home`, `/vendor/overlay/<Nome>/` | autorun | PackageManager (no boot) | apps e sobreposições do sistema |
| `/atv/bootvideo/logo.jpg`, `bootanimation.zip` | autorun | boot | marca MeowCast |
| `/data/data/com.pfl7560.verificar/pedir-verificacao`, `descanso-inicio`, `descanso-fim` | app | `suite-pedido.sh` | pedidos do app |
| `/data/data/com.pfl7560.home/luz` | home | `suite-pedido.sh` (move para a pasta do root) | pedido de luz (10 a 100) |
| prop `vendor.pfl7560.luz` | `suite-pedido.sh` | home | a luz aplicada, de volta ao app |
| prop `vendor.newlink.launcher.package`, `vendor.nl.filemanage_file` (no `/vendor/build.prop`) | autorun | `nlprovision`, gerenciador de arquivos | home nova; gerenciador abrindo na lista |
| prop `persist.sys.boot.reason` = `pfl7560,ligado` | `suite-boot.sh` | `suite-boot.sh` no boot seguinte | marca de "energia caiu ligado" |
| prop `vendor.zy.power.tm.temp` | rampa da suíte, `--vivacidade` | laço térmico | override de 71000 m°C, limpo no fim |
| `/sdcard/pfl7560-kit/`, `/sdcard/pfl7560-suite/` | `cor.sh`, `suite.sh` | galeria | as telas mostradas |
| `/dev/pfl7560-kit.lock`, `/dev/pfl7560-suite.lock` | `cor.sh`, suíte | idem | travas (tmpfs, somem no reboot) |
| `/data/local/nlsu/update_after_boot.sh` | `cor.sh` | init de fábrica | gancho de recuperação da cor |
| pendrive: `newlink_cor.log`, `newlink_suite.log`, `newlink_suite_resultados.txt` | `cor.sh`, `suite.sh` | pessoa | logs no fim da execução |
| pendrive: `DESINSTALAR-SUITE.txt` | pessoa | autorun | tira a suíte, a home, o tema e a marca |

Props lidas (não escritas): `zysys.env_temp` (sensor do LED, `gtt1`), `zysys.light_temp` (placa, `gtt0`),
`sys.newlink.auto` (autofoco em curso), `persist.sys.keystone.{lt,rt,lb,rb}`, `persist.sys.mountingmode`,
`zysys.typec_count` e `zysys.source.*`.

## Dados medidos e de referência

| Onde | O que |
|---|---|
| `evidencias/<data>/` (fora do git, só no repositório principal) | TSVs de medição, logs, capturas; `evidencias/lsadc/` do vigia; `evidencias/boot-tomada/` |
| `tests/fixtures/camera/` | quadros crus YUYV da câmera interna (2026-10-30), VESA e JEIDA |
| `tests/fixtures/tela/`, `tests/fixtures/processos/` | exemplos do contrato C-tela; saída de `top` do aparelho |
| `artifacts/*.STOCK`, `artifacts/ZYCustom*` | arquivos de fábrica e da correção, com md5 ([tabela](../artifacts/README.md)) |
| `artifacts/firmware-extraido/` | `board.dtb`, `full_dts.txt`, trechos da config térmica (doc 01) |
| `artifacts/historico/` | `.ini` e `.rc` antigos e perfis experimentais (não aplicar) |
| `firmware/*.md5`, `firmware/README.md` | md5 das nossas builds e dos oficiais |
| `docs/ESTADO.md` | o que está provado, o que falta, contagens das provas |

## Provas

```bash
make check       # md5 de contrato
make check-kit   # kit, suíte, telas, câmera, scripts do PC
make check-fix   # pfl7560-fix.sh nos dois modelos
make check-bin   # gerador do .bin
shellcheck -s sh pendrive-autorun/*.sh   # o kit roda no sh do Android
bash tests/atualizar-md5-kit.sh          # depois de mudar qualquer arquivo do kit
```
