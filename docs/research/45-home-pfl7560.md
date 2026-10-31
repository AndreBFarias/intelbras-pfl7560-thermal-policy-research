# 45 - Home nova do PFL7560 (`com.pfl7560.home`): pesquisa, segurança e desenho (2026-10-31)

**Estado em 2026-10-31: a home MeowCast (v4) é a tela inicial do projetor do dono.** O que mudou depois desta
pesquisa, no aparelho:

- **O caminho aplicado é o B (§4.2), não o A.** O `cmd package set-home-activity` não vence: o `nlprovision` tem
  prioridade 29 no filtro HOME (visto no aparelho em 2026-10-31). O kit grava
  `vendor.newlink.launcher.package=com.pfl7560.home` no `/vendor/build.prop`, só com a home instalada e
  conferida; o `nlprovision` segue como HOME, faz o trabalho de boot e repassa para a nossa. O `suite.sh
  --desinstalar` tira a linha e a home de fábrica volta no boot seguinte. Os comandos `set-home-activity` das §5,
  §9 e §10 ficam como registro do plano, não como caminho.
- **A luz (§11) volta à home pela prop `vendor.pfl7560.luz`**, que a home lê com `getprop`; o arquivo `luz-atual`
  da primeira versão saiu na revisão de segurança (doc 44 §13).

O que segue marcado **PROVISÓRIO** é do plano original (seção 9, roteiro na seção 10); o estado do conjunto está
em [`docs/ESTADO.md`](../ESTADO.md).

Origem: o pedido do dono de 2026-10-31 ("uma nova home e um novo tema [...] gosto da paleta drácula") e o
[bloco 10](../sprints/2026-10-31-bloco-10-home-e-tema-dracula.md), parte 10A. O app fica em
[`artifacts/home/`](../../artifacts/home/README.md).

**Convenção (a do doc 43).** `CONFIRMADO` = lido no código do firmware, no arquivo e na linha citados.
`INFERIDO` = dedução sem execução. A confiança (alta, média, baixa) é sobre funcionar no aparelho como
descrito. "smali L*n*" é a linha *n* do arquivo gerado pelo baksmali do apktool (`--api-level 28`).

---

## 0. Resumo

1. **Entradas.** O launcher de fábrica abre HDMI 1, HDMI 2 e USB-C com
   `com.newlink.nlsource/.MainActivity` e o extra int `SourceName` = número da fonte, lido das props
   `zysys.source.hdmi1` (11 no aparelho), `zysys.source.hdmi2` (10) e `zysys.source.typec1` (9). A home
   faz igual (§3). Confiança **alta**.
2. **A tela inicial de fábrica deste aparelho é a `MainActivityBx`**, não a `MainActivityRg` que o doc 43
   §6 citou: o `WizardAciticity` só vai para a `Rg` com `vendor.newlink.rg_rgtp.style=true`, e com
   `vendor.newlink.rgtp_ui.style=1` cai na `Bx` (§2). A `Rg` nem tem o botão de USB-C.
3. **O `nlprovision` faz muito mais que repassar** (§4). Como HOME, ele roda no boot a configuração do
   aparelho (serviços, MAC do Wi-Fi em prop, recuperação do repouso, entrada de vídeo do boot, assistente de
   primeira vez). Com `cmd package set-home-activity com.pfl7560.home/.HomeActivity` (o caminho do spec)
   **isso deixa de rodar no boot**. O alerta de temperatura continua (sobe com o `Application`, não com a
   atividade). Há um caminho mais conservador, que mantém o `nlprovision` como HOME e o faz repassar para a
   nossa home (`vendor.newlink.launcher.package`). Ele está documentado, mas não foi aplicado nem provado.
   **A decisão é do dono no teste do aparelho (§4.3).**
4. **Segurança:** a home de fábrica continua instalada. A nossa só vira padrão pelo comando e volta pelo
   outro (§5). Uma trava anti-laço entrega a tela ao launcher de fábrica se a home cair duas vezes em 2 min.
5. **Linha de estado:** rede (nome ou "Sem rede") e temperatura do LED (`zysys.env_temp`, se o SELinux
   deixar um app comum ler). "Última verificação" foi **omitida**: o resultado da suíte fica em lugar que
   um app comum não lê (§6).

---

## 1. Método (reproduzível)

Offline, só leitura, no firmware oficial V1.0.0.9 (`firmware/Software PFL7560.zip`, `PFL7560.bin` md5
`28a2f280eee313a4b115567926b2ba4f`), com os scripts da pesquisa P (doc 43 §1):

```sh
SP=<scratchpad>/home10a
unzip -j "firmware/Software PFL7560.zip" "Software PFL7560/PFL7560.bin" -d $SP/fw/
python3 -I extrai.py $SP/fw/PFL7560.bin 13 $SP/fw/system.raw        # record 13 = system
debugfs -R "rdump /system/app /system/priv-app $SP/x" $SP/fw/system.raw
apktool d -f --api-level 28 -o $SP/dec/<App> <App>.apk               # APKs com classes.dex
java -cp apktool.jar Desmonta.java <odex com o vdex ao lado> <saida>  # APKs sem dex (NLSourcePlayer)
aapt2 dump badging|xmltree <apk>                                     # manifests, rótulos, LAUNCHER
```

Nenhum comando foi mandado ao projetor. Os brutos foram apagados no fim. Arquivos lidos (md5, 8 dígitos):

| Arquivo | Pacote | md5 |
|---|---|---|
| `system/app/RGTPLauncher/RGTPLauncher.apk` | `com.newlink.hisilauncher` | `c1a01f23` |
| `system/priv-app/NLProvision/NLProvision.apk` | `com.newlink.nlprovision` | `a2e7466b` |
| `system/app/NLSourcePlayer/NLSourcePlayer.apk` / `oat/arm/NLSourcePlayer.vdex` | `com.newlink.nlsource` | `e7c7a107` / `5b1d733c` |
| `system/app/ZYSetting/ZYSetting.apk` | `com.zhiying.settings` | `8a9d0d57` |
| `system/app/ZYBluetooth/ZYBluetooth.apk` | `com.example.bluetoothsetting` | `f384eda2` |
| `system/app/Miracast/Miracast.apk` | `com.hisilicon.miracast` | `653296bd` |
| `system/app/HBCastNew/HBCastNew.apk` | `com.newlink.cast` | `c74543f4` |
| `system/priv-app/TvSettings/TvSettings.apk` | `com.android.tv.settings` | `f654955d` |

Props do aparelho: `artifacts/build.prop.STOCK` (o `/vendor/build.prop` do modelo com USB-C).

---

## 2. Qual tela inicial o aparelho mostra hoje

| Achado | Fonte | Confiança |
|---|---|---|
| HOME do sistema = `com.newlink.nlprovision/.MainActivity` (filtro MAIN + HOME + DEFAULT + SETUP_WIZARD, `priority=29`), que repassa a outra HOME (§4) | manifest do `NLProvision.apk` | alta (visto no aparelho em 2026-10-30, sprint do bloco 10) |
| O `WizardAciticity` do launcher escolhe a tela pela ordem: `zysys.rgtp.launcher` = 1..8 (`New`, `Second`, ... `YaberAce`); `kjm_ui`, `kjm_npx_ui`, `ry_ui`, `rg_rgtp` (booleanas); `rgtp_ui.style == "1"` → **`MainActivityBx`**; `"2"` → `Yg`; senão `MainActivity` | `WizardAciticity.smali` L28-500 (Bx em L480-490) | alta (CONFIRMADO no código) |
| No aparelho: `vendor.newlink.rgtp_ui.style=1`; `zysys.rgtp.launcher` e as booleanas não estão no `build.prop` → **`MainActivityBx`** | `build.prop.STOCK` L50 | média (INFERIDO: alguma prop pode vir de outro arquivo) |
| A `MainActivityBx` tem HDMI 1, HDMI 2, USB-C (`TYPE_C` = `zysys.source.typec1`), arquivos USB, Miracast, iOSCast e Configurações | `MainActivityBx.smali` `initData` L426-518, `onClick` L2362-2757 | alta |

O doc 43 §6 citou a `MainActivityRg`. A lista de apps que ele descreveu (`AppUtils`) é a mesma nas duas,
então o 9C não muda. Só a tela inicial estava errada.

---

## 3. Os intents de cada cartão

| Cartão | O que a home manda | Fonte | Confiança |
|---|---|---|---|
| HDMI 1 / HDMI 2 / USB-C | `new Intent().setComponent(com.newlink.nlsource/.MainActivity)`, extra int `SourceName` = `zysys.source.hdmi1` / `hdmi2` / `typec1` (padrão 11 / 10 / 9, os valores do `build.prop`), flags `NEW_TASK \| NO_HISTORY \| NO_ANIMATION`, sem animação de troca. Reserva: `com.hisilicon.tvui/.MainActivity` com o mesmo extra (o que o launcher usa com `persist.display.720p=true` em chip não HS352) | `MainActivityBx.selectHSSource` L1163-1329 (chip `HS352` → nlsource); `initData` L446-518; `NLSourcePlayer` `MainActivity` lê `getIntExtra("SourceName")` (smali L691-693 e L1541-1571) e é `exported=true` | alta |
| Verificar projetor | `com.pfl7560.verificar/.VerificarActivity` (o app do bloco 9C) | `artifacts/app/AndroidManifest.xml` | alta |
| Wi-Fi | ação `android.settings.WIFI_SETTINGS`; reserva `com.zhiying.settings/.network.WifiSettingActivity` | só o `ZYSetting` declara `WIFI_SETTINGS` (varredura de todos os APKs de `/system/app` e `/system/priv-app` com `aapt2 dump xmltree`); o mesmo par do `WifiActivity` do 9C | alta |
| Bluetooth | ação `android.settings.BLUETOOTH_SETTINGS` | só o `ZYBluetooth` (`BaseActivity`) a declara. As Configurações de fábrica abrem `com.example.bluetoothsetting/.MainActivity` direto (`MainPTActivity$3`), mas essa atividade **não é exportada** e um app de fora não a abre | alta |
| Imagem | ação `android.settings.projection.cra.6d.sen_new` (tela de Projeção: foco, correção, direção); reservas `com.zhiying.settings/.pictureSetting.pictureModeActivity` (Modo de imagem, `exported=true`) e `android.settings.SETTINGS` | as Configurações de fábrica (`MainActivity` → `ZY_PT_SETTING` com `rgtp_ui.style=1`, smali L248) abrem o item DLP por `NLPEntryUtils.getDLPIntent` (L118): `zysys.dlp_setting=2` → `getProjectionIntent`; `zysys.projection.is_new=2` → `get6DProjectionIntent` (L52); `vendor.newlink.projection_6d.style=1` → `...cra.6d.sen_new` (L68) → `ProjectionCra6DSenNewActivity` (`exported=true`) | alta para abrir; média para o conteúdo da tela (INFERIDO pelo nome) |
| Configurações | ação `android.settings.SETTINGS` (o mesmo do launcher, `startActivityByAction`) | só o `ZYSetting` a declara | alta |
| ~~Espelhamento~~ | **removido no bloco 16B** (o dono não quer; §12). Era `getLaunchIntentForPackage("com.hisilicon.miracast")`, reserva `com.newlink.cast` (iOSCast) | `MainActivityBx.onClick` (Miracast em chip não MediaTek e não Allwinner; o aparelho é `Hisilicon`) | alta |
| Apps | `MAIN` + `LAUNCHER` com o componente exato e `NEW_TASK \| RESET_TASK_IF_NEEDED` | doc 43 §6 (`AppUtils.queryAppInfo`) | alta |

Nenhuma das ações implícitas acima tem dois donos no firmware, então não aparece o seletor "Abrir com".

**Fileira de Apps.** Lista `queryIntentActivities(MAIN+LAUNCHER)`, ordenada pelo nome com `Collator` pt-BR
(ignora maiúsculas e acentos), sem: a lista negra do launcher de fábrica (`com.qiyivideo.sibichi`,
`com.jrm.localmm`, `com.gitvvideo.shanghaishijiu`, `org.mozilla.tv.firefox` e o próprio
`com.newlink.hisilauncher`), os nossos (`com.pfl7560.home`, `com.pfl7560.verificar`) e o Miracast, que já
é o atalho Espelhamento. No firmware sobram 4 (`aapt2 dump badging`, rótulo em pt): Alto-falante Bluetooth,
Gerenciador de arquivos, iOSCast e VideoPlayer. Os apps que o dono instalou entram também. A lista se
refaz com `PACKAGE_ADDED/REMOVED/CHANGED/REPLACED`.

---

## 4. O que o `nlprovision` faz como HOME

### 4.1 O que foi lido

| Achado | Fonte | Confiança |
|---|---|---|
| `MainActivity.onCreate` põe `service.newlink.bootanim.delayexit=1` e, com o usuário desbloqueado, chama `initConfig` | smali L7609-7724 (prop em L7660) | alta |
| `initConfig` (L1771-3681): lê props de configuração; sobe `BatteryService`, `BTRemoteControlService` (HS352 no boot) e `TVService`; MAC do cabo (`setMacEth0`); `jumpPreprocessing` (L7488: `setWLANMacToProp`, `sleepRecovery`, `reset3dAuto`); `setProvision` (`device_provisioned=1`, `user_setup_complete=1`, `tv_user_setup_complete=1`, L5968); assistente de primeira vez (`zysys.wizard.enable=true`, `startOtherWizard`); vídeo de fábrica; entrada de vídeo do boot (`doSelectSourceId` → `startBootSelection`, que pode abrir uma fonte ou um app marcado, `persist.nl.enter.packageName`) | smali citados | alta (CONFIRMADO que o código existe; INFERIDO o que cada um muda no aparelho) |
| Repasse: `startHomeActivity` (L6905) abre `homePackage` (prop `vendor.newlink.launcher.package`, L1807) se houver; senão o `home_pkg/home_activity` guardado nas preferências, que `getLauncherHomeNameData` (L1396) escolhe como **a primeira HOME** que não é o `nlprovision` nem o `com.android.tv.settings` | smali L1261-1549, L6905-7069 | alta |
| O alerta de temperatura (`TempService`) sobe no `Application` (`MyApplication.startCoreService`, `MyApplication$4` L61), e o app é `persistent=true`. Não depende da atividade HOME | `MyApplication.smali` L1470-1512 | alta (INFERIDO que segue igual com outra HOME) |

### 4.2 Consequência para a home nova

- **Caminho A, o do spec:** `cmd package set-home-activity com.pfl7560.home/.HomeActivity`. Simples e
  reversível. O boot e o botão HOME vão direto para a nossa home, e **o `initConfig` do `nlprovision` deixa
  de rodar no boot**. O efeito exato de cada parte (MAC do Wi-Fi em prop, recuperação do repouso, entrada do
  boot, serviço do controle Bluetooth) não se sabe sem o aparelho. Confiança de que **nada importante quebra:
  baixa**.
- **Caminho B, mais conservador e NÃO aplicado:** deixar o `nlprovision` como HOME e pôr
  `vendor.newlink.launcher.package=com.pfl7560.home` no `/vendor/build.prop`. O `nlprovision` continua
  fazendo todo o trabalho de boot e repassa a HOME com `setPackage("com.pfl7560.home")`. Confiança média
  (INFERIDO): o intent repassado vem de `doSelectSourceId` sem ação explícita (L834-1000), e com a prop
  vazia o caminho por componente é o que roda hoje. Volta tirando a linha. Mexe no `/vendor` (o kit já
  escreve lá); fica para o coordenador e o dono decidirem.
- **Risco do caminho A mesmo sem `set-home-activity`:** se a preferência `home_pkg` do `nlprovision`
  estiver vazia (aparelho zerado), ele escolhe a primeira HOME da lista, e pode ser a nossa. Num aparelho em
  uso a preferência já guarda o `hisilauncher`. **PROVISÓRIO.**

### 4.3 Recomendação

Testar primeiro o caminho A como o spec manda, com o roteiro da §10. Antes, com a home de fábrica, anotar
`getprop | grep -iE 'mac|wizard|bootanim|newlink.auto'`, o Wi-Fi e o controle Bluetooth, e repetir depois de
um boot com a home nova. Se algo mudar, voltar (`set-home-activity` do `nlprovision`) e ir para o caminho B.

---

## 5. Segurança

- A home de fábrica (`nlprovision` + `hisilauncher`) continua instalada e intocada.
- Vira padrão **só** com:

      cmd package set-home-activity com.pfl7560.home/.HomeActivity

  e volta com:

      cmd package set-home-activity com.newlink.nlprovision/.MainActivity

  (os dois também estão no README do app). Rodam por `adb shell`; INFERIDO que o usuário shell tem a
  permissão para isso (`SET_PREFERRED_APPLICATIONS`), **PROVISÓRIO**.
- Instalação: como o 9C, só como app do sistema em `/vendor/app/PFL7560Home/PFL7560Home.apk` (o `pm install`
  deste firmware recusa apps de fora). A instalação fica com o coordenador. Este bloco não instala nada.
- Boot: o `onCreate` só monta uma `View`. Lista de apps, rede e temperatura saem de threads de baixa
  prioridade e chegam por `Handler`. O fundo da janela já é `fundo` (nada de clarão branco).
- Falhas: cada `startActivity` está num `try` e, se nada abre, aparece "Não abriu: <cartão>" por 5 s na
  linha de estado. Erro na lista de apps vira fileira vazia ("Nenhum app para mostrar"). Erro de desenho
  deixa o fundo e tenta no quadro seguinte.
- Crash em laço: a `Guarda` anota cada queda do processo antes de o Android matá-lo. Se a home abre com
  duas quedas nos últimos 2 min, ela abre o `com.newlink.hisilauncher/.WizardAciticity` (tem HOME, logo é
  exportada) e sai. No pior caso são duas quedas e depois a home de fábrica.
- BACK na home não faz nada. HOME com a home na frente volta o foco para HDMI 1.
- Permissões: `ACCESS_NETWORK_STATE` e `ACCESS_WIFI_STATE`, ambas normais. Nenhuma perigosa
  (`aapt2 dump permissions`).

---

## 6. Linha de estado

| Campo | Como lê | Confiança |
|---|---|---|
| Rede | `ConnectivityManager.getActiveNetworkInfo()`: sem rede → "Sem rede"; cabo → "Cabo de rede"; Wi-Fi → o SSID do `WifiInfo`, ou, se o Android 9 o esconder ("<unknown ssid>", falta de permissão de localização, que é perigosa), o `NetworkInfo.getExtraInfo()` da rede ativa; se nenhum vier, "Wi-Fi conectado" | média: **PROVISÓRIO** se o nome aparece |
| Temperatura do LED | `SystemProperties.get("zysys.env_temp")` por reflexão (o sensor `gtt1`, no bloco do LED, doc 40 §3). Arredondada, por exemplo "LED 59 °C". Se vier vazia (SELinux bloqueando a prop para `untrusted_app`), o campo some | média: **PROVISÓRIO** |
| Última verificação | **Omitida.** A suíte (bloco 9B) grava o resultado como root, fora do alcance de um app comum, e o app do 9C só sabe que pediu | alta |

Os campos se atualizam a cada minuto (`TIME_TICK`) e quando a rede muda.

---

## 7. Desenho

A direção veio da skill `hallmark`, com a paleta e as fontes do contrato do bloco 10 por cima de qualquer
escolha dela. Gênero: utilitário e calmo, um painel de instrumento. O D-pad manda no layout.

- **Estrutura:** relógio grande (IBM Plex Mono SemiBold 176 px; os dois pontos em `roxo`, o único detalhe
  de marca) e a data por extenso abaixo, à esquerda; **Entradas** no alto à direita, alinhadas pelo topo
  do relógio, porque trocar de entrada é a ação principal de um projetor; **Atalhos** (6) e **Apps** (7
  visíveis por vez, com contador "1–7 de 12") em fileiras abaixo; linha de estado no rodapé. Quadro
  1920x1080, margens de 112 px, vão de 24 px, ritmo vertical de 96 px entre o fim de uma fileira e o título
  da seguinte.
- **Cores (tokens do contrato):** fundo em gradiente vertical sutil `fundo` → mistura de `linha`; cartão
  em repouso = mistura de `linha` com `fundo`; cartão em foco = `linha` cheia, **anel `rosa` de 5 px**,
  ícone `rosa`; títulos de grupo em `roxo`; aviso em `amarelo`. Os derivados são misturas dos tokens, nenhuma
  cor nova (`Tema.java`).
- **Contraste** (WCAG, calculado):

  | Par | Contraste |
  |---|---|
  | `comentario` sobre `fundo` | 3,03:1 (por isso não usado em texto pequeno) |
  | texto secundário (`texto` 72 % sobre `fundo`, `#BEBEBD`) sobre `fundo` / base do gradiente / cartão | 7,66 / 6,62 / 5,87:1 |
  | `texto` sobre cartão em repouso / em foco | 10,24 / 8,59:1 |
  | `roxo` sobre `fundo` | 5,90:1 |
  | anel `rosa` sobre `fundo` | 5,97:1 (≥ 3:1 para foco) |

- **Fontes:** IBM Plex Sans Condensed (títulos, rótulos) e IBM Plex Mono (relógio, temperatura), as do kit
  (`pendrive-autorun/fontes/`, OFL). O `build.sh` as copia para `assets/fontes/` do APK, junto com a OFL.
- **Ícones:** desenhados no código (`Icones.java`), numa grade de 64 e traço único de 4/64 com pontas
  redondas: conector HDMI, USB-C, círculo com visto, Wi-Fi, runa do Bluetooth, tela em trapézio com os 4
  cantos (Imagem), reguladores (Configurações), tela com ondas (Espelhamento) e termômetro. Na fileira Apps
  (bloco 13B) todo ícone também é desenhado no código, sem `loadIcon`: um desenho por função para os pacotes conhecidos e, para o resto, a inicial num círculo na cor do tema escolhida pelo pacote.
- **Texto:** maiúscula no início de rótulo e de frase, português com acento, zero emoji. Rótulo longo
  quebra em até duas linhas e só ganha reticências depois disso.
- **Sem animação:** o foco aparece na hora. Nada de sombra, de brilho nem de gradiente nos cartões.

O código de desenho (`Desenho`, `Icones`, `Modelo`, `Tema`) é Java puro e fala com um `Pintor`. No aparelho
o pintor é o `PintorCanvas` (Canvas do Android); no PC é o `PintorJ2D` (Java2D). As prévias saem do
**mesmo** código de desenho, com as mesmas fontes.

---

## 8. Provas (no PC)

- `bash artifacts/home/build.sh` gera o APK do zero. A paleta confere 11 de 11 tokens entre o spec, o
  `colors.xml` e o `Tema.java` (e o `artifacts/tema/dracula.txt` do 10B, quando existir). Uma cor trocada de
  propósito derruba o build. `apksigner verify` passa: v3, e v1+v2+v3 com `--min-sdk-version 23`. O
  resultado é determinístico: dois builds dão o mesmo md5.
- `aapt2 dump badging`: `package: name='com.pfl7560.home' versionCode='1'`, `minSdkVersion:'28'`,
  `targetSdkVersion:'28'`, `launchable-activity: name='com.pfl7560.home.HomeActivity'`. No `xmltree`, o
  filtro tem MAIN, HOME, DEFAULT e LAUNCHER, com `launchMode=2` (singleTask) e `stateNotNeeded=true`.
  `aapt2 dump permissions`: só as duas normais.
- `bash artifacts/home/gerar-previas.sh` grava 5 prévias 1920x1080 em `artifacts/home/previa/` e confere
  a navegação do D-pad (9 conferências). Prévias: foco em HDMI 1; foco num atalho de duas linhas; foco num
  app, sem rede e com aviso; rolagem com 12 apps (os 8 extras se chamam "Exemplo N" e existem só para provar
  o contador); lista carregando.
- `shellcheck` limpo no `build.sh` e no `gerar-previas.sh`.

---

## 9. PROVISÓRIO (só o aparelho confirma)

1. A home abre, desenha em 1920x1080 com as fontes Plex e responde ao D-pad.
2. HDMI 1, HDMI 2 e USB-C trocam para a entrada certa (`SourceName` 11 / 10 / 9).
3. Wi-Fi, Bluetooth, Imagem (tela de Projeção), Configurações e Espelhamento abrem a tela certa.
4. O nome da rede aparece (ou cai em "Wi-Fi conectado") e a temperatura do LED é legível sem root.
5. Com `set-home-activity`, o boot vai para a home nova e nada do `nlprovision` (§4) faz falta.
6. A volta com `set-home-activity com.newlink.nlprovision/.MainActivity` restaura a home de fábrica.
7. A instalação em `/vendor/app/PFL7560Home/` sobe com `flags=[ SYSTEM ]`, como a do 9C.

## 10. Roteiro de teste no aparelho (para o coordenador, com o dono)

1. Instalar o APK em `/vendor/app/PFL7560Home/PFL7560Home.apk` (como o 9C) e reiniciar. Conferir
   `dumpsys package com.pfl7560.home | grep flags`.
2. Com a home de fábrica, anotar o "antes" da §4.3.
3. `am start -n com.pfl7560.home/.HomeActivity`: olhar a tela, andar com o D-pad, abrir cada cartão e voltar
   com BACK ou HOME.
4. `cmd package set-home-activity com.pfl7560.home/.HomeActivity`, apertar HOME e depois reiniciar. Conferir
   o "depois" da §4.3, o alerta de temperatura e o controle.
5. Voltar com `cmd package set-home-activity com.newlink.nlprovision/.MainActivity` e apertar HOME: tem de
   aparecer a home de fábrica.

## 11. Atalho Luz (bloco 15, versionCode 3)

Pedido do dono: "controlamos a iluminação travando ela no 100%, não conseguimos um botão na interface pra
controlar isso abaixando ela?". Sim: o `sbl` do `hidebug` baixa a luz do LED (doc 44 §13).

- **Atalho.** "Luz", entre Imagem e Configurações, com um sol desenhado no traço da home e o valor atual por
  baixo ("100%", em Plex Mono). A fileira Atalhos passou de 6 para 7 cartões (a mesma largura da fileira Apps).
- **Painel.** OK no atalho abre o painel "Luz do projetor" (tela cheia, no tema): 100, 80, 60, 40 e 25
  ("Econômico"), com uma barra em cada um; o nível atual leva "Atual" em verde. Setas escolhem, OK aplica (o
  painel fica aberto, para ir de um nível a outro), BACK fecha. Um aviso diz que a proteção térmica continua
  baixando a luz sozinha e que o nível volta a cada boot.
- **Ponte.** OK grava só os dígitos em `luz`, em `getDataDir()` (`FileOutputStream`, fora da thread da
  interface). O vigia root aplica e devolve o valor na prop `vendor.pfl7560.luz`; o app a lê com `getprop` (100
  se não existe) ao abrir, a cada minuto e 4 s depois de um OK. Enquanto o root não responde, o app mostra o
  nível pedido. (A primeira versão devolvia num arquivo `luz-atual` na pasta do app; saiu na revisão de
  segurança de 2026-10-31.)
- **Sem permissão nova.** O APK continua com as duas permissões normais.
- **Provas no PC.** 15 conferências de navegação (o painel abre no nível mais perto do atual, anda de 100 a 25
  sem passar das pontas, HOME fecha o painel), prévias `home-foco-luz.png`, `home-painel-luz.png` e
  `home-painel-luz-economico.png` abertas e conferidas, build determinístico, `aapt2 dump badging` com
  versionCode 3.
- **PROVISÓRIO (só o aparelho confirma):** o painel e o atalho no projetor (leitura da parede, foco por D-pad);
  o app conseguir ler a prop `vendor.pfl7560.luz` (provado: o botão Luz funciona no aparelho); o valor aparecer certo depois de um reboot; a
  luz mudar de fato a cada nível (o dono já viu o 30 escurecer com o `sbl` à mão).

## 12. Sem Espelhamento e sem os apps desligados (bloco 16B, versionCode 4)

Pedido do dono: "Temos o ioscast e o espelhamento de tela. Acho que não precisamos deles também" e "falta
remover o office suite (ocultar da home)". Os três já foram desligados à mão no aparelho com `pm disable-user`
(`com.mobisystems.editor.office_registered`, `com.newlink.cast` e `com.hisilicon.miracast`).

- **Atalho.** O cartão Espelhamento saiu (`Modelo.padrao()`, `Acoes.ESPELHAR` e o caso no `Abridor`, com o
  `lancador()` que só ele usava). A fileira Atalhos passa de 7 para 6 cartões: Verificar projetor, Wi-Fi, Bluetooth,
  Imagem, Luz e Configurações. A largura do cartão não mudou (é a da fileira Apps, que continua em 7 colunas), então
  as duas fileiras seguem alinhadas e sobra um espaço à direita nos atalhos. O desenho `Icones.ESPELHAR` fica: um app
  qualquer com "cast" ou "mirror" no pacote ainda o usa.
- **Fileira Apps.** `queryIntentActivities(MAIN+LAUNCHER)` sem `MATCH_DISABLED_COMPONENTS` não devolve app
  desligado (por isso eles já sumiram da lista, como o dono viu). Por garantia, `Modelo.OCULTOS` lista os três
  pacotes e o `Modelo.definirApps` os tira da fileira mesmo que algum volte a ligar (atualização de firmware,
  redefinição). O Miracast saiu da lista `FORA` do `Leitor` (era o "já é o atalho Espelhamento") e foi para o
  `OCULTOS`. No firmware sobram 3 apps visíveis: Alto-falante Bluetooth, Gerenciador de arquivos e VideoPlayer.
- **Provas no PC.** `gerar-previas.sh` roda conferências novas na navegação (de USB-C desce para Configurações, 6
  atalhos, os três pacotes ocultos nunca entram na fileira, a lista de exemplo traz um "Office (oculto)" e o
  iOSCast de propósito); as prévias foram regeneradas e abertas: o iOSCast sumiu da fileira Apps (3 apps) e o
  Office de exemplo não aparece na de rolagem (12 apps). `build.sh` gera o APK com versionCode 4.
- **PROVISÓRIO (só o aparelho confirma):** a home nova no projetor com 6 atalhos e sem o iOSCast na fileira Apps.

## 13. Modelo sem USB-C e a luz fora da thread da interface (bloco 21, versionCode 5)

- **Entradas.** O kit também instala a home no modelo sem USB-C (V1.0.0.1, doc 42), cujo `build.prop` não tem
  `zysys.typec_count` nem `zysys.source.typec1`. O cartão USB-C só aparece quando `Leitor.temUsbC()` acha uma das
  duas (`typec_count` > 0 ou a fonte definida); sem elas, a fileira Entradas tem só HDMI 1 e HDMI 2.
- **Luz.** Quando o pedido de luz falha, a luz atual (que roda um `getprop`) é lida na thread `home-luz`, não mais
  na da interface.
- **Paleta.** O `build.sh` lê os 11 tokens de `artifacts/tema/dracula.txt`, a fonte única, e não mais do doc de
  sprint do bloco 10.
- **Provas no PC.** `gerar-previas.sh` confere a navegação com duas entradas (HDMI 2 é a última, desce para os
  atalhos e volta de Configurações para HDMI 2); sem o `Modelo.padrao(boolean)` o código nem compila. As prévias
  de sempre não mudaram (md5 iguais). `build.sh` gera o APK com versionCode 5.
- **PROVISÓRIO (só o aparelho confirma):** no modelo com USB-C, o cartão continua lá (o `build.prop` do V1.0.0.9 tem
  `zysys.typec_count=1`); no sem USB-C, nenhum aparelho do dono para conferir.

