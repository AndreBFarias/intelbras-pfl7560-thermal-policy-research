# 48 - Tema Drácula no sistema do fabricante: sobreposições (RRO) (2026-10-31)

**Estado: pronto em código, gerado e conferido no PC. Nada disto rodou no aparelho.** O que só o aparelho
confirma está marcado **PROVISÓRIO** e reunido na seção 8 (bloco 13A) e na §10.7 (bloco 16A).

**Bloco 16A (2026-10-31):** seis sobreposições novas (Bluetooth, gerenciador de arquivos, TvSettings, galeria,
entradas HDMI, menu de energia), o ZYSetting sem o laranja das telas de modo, e a do `android` com os diálogos
escuros do Leanback e a forma do Toast. A varredura de todo app com tela do firmware está na §10.1.

Origem: o pedido do dono de 2026-10-31 ("Dentro das configs segue o tema antigo"; "Esse sim e não tão fora
do tema", sobre o aviso de HDMI) e o [bloco 13](../sprints/2026-10-31-bloco-13-tema-no-sistema.md), parte 13A.
Os APKs ficam em [`artifacts/overlay/`](../../artifacts/overlay/README.md). Paleta e tons derivados:
[`artifacts/tema/README.md`](../../artifacts/tema/README.md).

**Convenção (a do doc 43).** `CONFIRMADO` = lido no firmware, no arquivo e na linha citados. `INFERIDO` =
dedução sem execução. "smali L*n*" é a linha *n* do arquivo gerado pelo baksmali do apktool (`--api-level 28`).

---

## 0. Resumo

1. **Três sobreposições, uma por pacote alvo, só com `color` e `drawable`:** `com.zhiying.settings`
   (Configurações, Wi-Fi, aviso de HDMI), `com.newlink.nlprovision` (os avisos próprios dele) e `android`
   (três cores de diálogo). Nenhum app do fabricante muda; textos e layouts ficam como estão.
2. **O verde antigo é uma cor só.** Com `vendor.newlink.rgtp_ui.style=1` (o `/vendor/build.prop` de fábrica,
   linha 50), todas as telas das Configurações pintam o fundo com `color/pt_green` (`#00B26B`): os
   `MyFrameLayout`, `MyLinearLayout` e `MyRelativeLayout` fazem `setBackgroundResource(pt_green)` no `init()`.
   Trocar essa cor troca o fundo de todas as telas de uma vez (§3.1). CONFIRMADO.
3. **O "Temperatura anormal" não é desenhado pelo `nlprovision`.** É um `AlertDialog` comum
   (`QUtils.showTempDialog`), com o tema do app (`@android:style/Theme`). Como o aparelho é de modo TV
   (`config_defaultUiModeType=4` no `framework-res.apk`), ele cai no `Theme.Leanback.Light.Dialog.Alert`:
   cinza-claro `#EEEEEE` com texto `#222222`. Só uma sobreposição do `android` o alcança (§4, §5). CONFIRMADO.
4. **Cores fixas no código limitam o que dá para trocar** (§3.4): o texto do aviso de HDMI é branco fixo, o
   botão em foco usa a mesma cor do fundo da tela e não há como pôr contorno rosa nele sem mudar o app. O
   foco rosa do dono entrou onde o recurso permite: a moldura das listas e dos cartões, e o botão "Conectar"
   da senha do Wi-Fi.
5. **Bloco 16A** (§10): a tela de Bluetooth é outro app (`com.example.bluetoothsetting`), com o mesmo verde
   `pt_green`; o gerenciador de arquivos, as entradas HDMI e o menu de energia também. Ao todo são **nove**
   sobreposições. Fica de fora o que só muda trocando layout (os nove cartões coloridos da página inicial do
   gerenciador de arquivos, §10.5) e os apps não analisados nesta rodada (§10.1, coluna "Coberto").
6. **Saída de emergência** (§7): `cmd overlay disable` desfaz na hora. Se a interface não subir, **o adb pode
   não estar disponível** (neste aparelho ele só existe pela rede, e a rede sobe com o `system_server`): o
   caminho é o reflash pelo pendrive do kit. Por isso a do `android` vai por último, só com 3 cores.

---

## 1. Método (reproduzível)

```sh
SP=<scratchpad>/b13a
unzip -j "firmware/Software PFL7560.zip" "Software PFL7560/PFL7560.bin" -d $SP/fw/   # md5 28a2f280...
python3 -I extrai.py $SP/fw/PFL7560.bin 13 $SP/fw/system.raw     # record 13 = system (doc 43 §1)
python3 -I extrai.py $SP/fw/PFL7560.bin 14 $SP/fw/vendor.raw     # record 14 = vendor
debugfs -R "rdump /system/app/ZYSetting /system/priv-app/NLProvision /system/framework/framework-res.apk $SP/x" $SP/fw/system.raw
debugfs -R "rdump /overlay $SP/x" $SP/fw/vendor.raw              # as sobreposições de fábrica
debugfs -R "cat /build.prop" $SP/fw/vendor.raw                   # vendor.newlink.rgtp_ui.style=1
apktool d -f --api-level 28 -o $SP/dec/ZYSetting   $SP/x/ZYSetting/ZYSetting.apk
apktool d -f --api-level 28 -o $SP/dec/NLProvision $SP/x/NLProvision/NLProvision.apk
aapt2 dump resources $SP/x/framework-res.apk > $SP/fwres.txt
```

**Bloco 16A:** `debugfs -R "rdump /system/app $SP/x"` e o mesmo para `/system/priv-app` e `/app` do vendor
(67 APKs). Vários apps vêm sem `classes.dex` no APK, só com `oat/arm/<App>.odex` e `.vdex` (ZYFileManager,
HiGalleryL, NLSourcePlayer...): o smali deles sai do odex pelo dexlib2 do próprio `apktool.jar`
(`DexFileFactory.loadDexContainer` + `Baksmali.disassembleDexFile`, API 28), com as chamadas "quickened"
como `vtable@N` (doc 46). As constantes `0x7f...` e as strings, que é o que este mapa usa, saem inteiras.

O mapa de cada tela saiu de um fecho de referências: das classes smali da tela (ids `0x7f...` resolvidos pelo
`public.xml`) para os layouts, destes para os `drawable`, `color` e `style`, e assim por diante, com as cores de
cada PNG contadas (script de pesquisa, no scratchpad, não versionado). As cores fixas no código saíram de
`const-string "#..."` e `setTextColor`/`setBackgroundColor` no smali.

Arquivos lidos (md5, 8 primeiros dígitos):

| Arquivo | Pacote | md5 |
|---|---|---|
| `system/app/ZYSetting/ZYSetting.apk` | `com.zhiying.settings` (versionCode 1023) | `8a9d0d57` (o mesmo do doc 43) |
| `system/priv-app/NLProvision/NLProvision.apk` | `com.newlink.nlprovision` | `a2e7466b` (o mesmo do doc 45) |
| `system/framework/framework-res.apk` | `android` (28) | `3c124b63` |

As sobreposições de fábrica em `/vendor/overlay/` (`SysuiDarkThemeOverlay`, `DisplayCutoutEmulation*`) usam
`<overlay android:targetPackage=... android:priority="1"/>`, sem `isStatic`, `targetSdkVersion` 28. As nossas
seguem o mesmo molde.

---

## 2. Os alvos e as telas

| Tela que o dono vê | Quem desenha | Recursos que pintam |
|---|---|---|
| Configurações (4 cartões) | `com.zhiying.settings.MainPTActivity` (a `MainActivity` repassa para ela com `rgtp_ui.style=1`, smali L248), layout `layout_setting_pt` | fundo `pt_green`; cartões `pt_bt`, `pt_dlp`, `pt_update`, `pt_other` (PNG 248x248, teal `#1D3034` com ícone branco); moldura de foco `item_focus_white` (9-patch); texto branco fixo no layout |
| Wi-Fi | `network.WifiSettingActivity`, layout `layout_wifi` | fundo `pt_green`; chave `custom_pt_checkbox` → `open_check_pt`/`close_check_pt` (PNG com "Ligado"/"Desligado" pintados); moldura `item_focus_white` (`setUpRectResource`, com `rgtp_ui.style=1`); ícones de sinal brancos (não mudam); fio `#000000` fixo no layout |
| Senha do Wi-Fi | `network.WiFiConnectDialog`, layout `wifi_connect` | painel `confirm_dialog_bg` (9-patch preto); campos `edit_text_large` → `edit_large_focus` (verde `#82AA81`) e `edit_large_normal` (branco 20%); botões `button_bg` → `button_bg_normal`/`button_bg_press`; texto dos botões `color/button_text`; cursor `drawable/cursor` (preto) |
| "Dispositivo conectado. Deseja abrir HDMI1?" | `hdmiUtil.HDMIService.createUsbUpdateDialog` → `view.MyDialog$Builder`, janela `TYPE_SYSTEM_ALERT` (`0x7d3`, smali L442), layout `my_dialog`, texto do array `to_hdmi` | com `rgtp_ui.style=1` (`initView`): painel `pt_green_black` (`#163134`), textos brancos fixos (`setTextColor(-1)`), botões transparentes; em foco, fundo `pt_green` (`changeBgByFocus`) |
| "Temperatura anormal" | `com.newlink.nlprovision.util.QUtils.showTempDialog` (`AlertDialog.Builder`, `TYPE_SYSTEM_ALERT`), chamado por `TempService$16` L1372 no caso padrão | tema do framework: `Theme.Dialog.Alert` (television) → `Theme.Leanback.Light.Dialog.Alert`: `colorBackground` = `background_leanback_light`, `textColorPrimary`/`Secondary` = `primary_/secondary_text_leanback_light`; botão Material sem borda com o `colorAccent` (`#009688`) |
| Outros avisos de temperatura e ventilador do `nlprovision` (estilos 2 a 6, `showTempDialogStyleTwo`) | `com.newlink.nlprovision.view.MyDialog` | painel `bg_tem` (branco, texto `#333333` fixo no layout), botão `bg_tem_button`, toast `toast_bg` |

`pt_green` aparece em 5 classes, todas fundo de tela ou botão em foco de diálogo; `pt_green_black`
só nos painéis do `MyDialog` e do `MyConfirmDialog`; `qili_theme`/`siwei_bg` são os fundos de outros estilos
(props `zysys.bluetooth.enablesink`, `vendor.newlink.siwei_ui.style`), não deste aparelho (§8).

---

## 3. `com.zhiying.settings` → `PFL7560TemaZYSetting.apk`

### 3.1 Cores

| Recurso | Fábrica | Drácula | Onde | Contraste |
|---|---|---|---|---|
| `color/pt_green` | `#00B26B` | `#282A36` fundo | fundo de todas as telas; botão em foco do aviso de HDMI | - |
| `color/pt_green_black` | `#163134` | `#6272A4` comentario | painel do aviso de HDMI e do `MyConfirmDialog` | texto branco fixo 4,7:1; botão em foco (fundo) contra o painel 3,0:1 |
| `color/button_text` (seletor) | foco `#000000`, parado `#FFFFFF` | foco `#282A36`, parado `#F8F8F2` | botões da senha do Wi-Fi | fundo sobre rosa 6,0:1; texto sobre fundo 13,4:1 |

### 3.2 Imagens recoloridas (mesmo desenho, mesmas pastas do alvo)

Geradas por `artifacts/overlay/recolorir.py`: cada pixel vira a mesma mistura das cores Drácula que era das
cores de fábrica (antisserrilhado preservado); a borda de marcação dos 9-patch fica intacta.

| Recurso | Pastas | Fábrica → Drácula |
|---|---|---|
| `item_focus_white` (9-patch) | `drawable-hdpi` | moldura branca → rosa |
| `item_focus` (9-patch, outro estilo) | `drawable-hdpi` | branco e brilho ciano → rosa |
| `pt_bt`, `pt_dlp`, `pt_update`, `pt_other` | `drawable` | teal `#1D3034` → linha; ícone branco → texto |
| `open_check_pt/en/es` | `drawable` (+ `hdpi` no pt) | verde `#00B26B` → verde; branco → texto; preto → fundo |
| `close_check_pt/en/es` | `drawable` (+ `hdpi` no pt) | teal `#153134` → linha; branco → texto; preto → fundo |
| `confirm_dialog_bg` (9-patch) | `drawable-hdpi` | painel preto → linha |
| `edit_large_focus` (9-patch) | `drawable-hdpi` | verde `#82AA81` → comentario (texto branco fixo: 4,7:1) |
| `edit_large_normal` (9-patch) | `drawable-hdpi` | branco 20% → fundo cheio (o campo parado fica escuro, o em foco mais claro: 3,0:1 entre eles) |
| `button_bg_normal` | `drawable-hdpi` | preto com fio branco → fundo com fio comentario |
| `button_bg_press` | `drawable-hdpi` | branco → rosa |

### 3.3 Forma

`drawable/cursor`: o mesmo retângulo de 1 dp, preto → texto (no campo escuro o preto sumia).

### 3.4 O que não dá para trocar sem mexer no app (fica como está)

- **Texto branco fixo** no código (`MyDialog`, `MyConfirmDialog`, `#FFFFFFFF` nos layouts da tela principal e
  da senha). Branco é praticamente o `texto` (`#F8F8F2`); o que pesa é que ele exige fundo escuro: por isso o
  campo de senha em foco é `comentario`, não rosa (branco sobre rosa dá 2,4:1).
- **O botão em foco do aviso de HDMI** é pintado com `pt_green`, a mesma cor do fundo das telas, por
  `setBackgroundResource` de uma cor (vira um retângulo chapado). Não existe recurso para um contorno rosa ali.
  Ficou: painel `comentario`, botão em foco `fundo`, texto branco. Desvio do pedido "foco rosa" registrado.
- **Fio de 1 dp `#000000`** entre "Ativar / Desativar" e a lista do Wi-Fi: cor fixa no layout. No fundo
  Drácula quase não aparece.
- **Ícones de sinal do Wi-Fi e setas**: brancos, já combinam; não foram tocados.
- **`colorAccent` do app** (`#FF4081`) e o tema `Theme.Leanback` das telas: não aparecem nas telas mapeadas.

---

## 4. `com.newlink.nlprovision` → `PFL7560TemaNLProvision.apk`

| Recurso | Fábrica | Drácula | Por quê |
|---|---|---|---|
| `drawable/bg_tem` | branco, fio preto 60%, raio 25 dp | `texto` com fio `comentario`, mesmo raio | o texto da janela é `#333333` fixo no layout: o painel tem de continuar claro (11,9:1) |
| `drawable/bg_tem_button` | preto 40%, fio preto 60%, raio 10 dp | `fundo` com fio rosa de 2 dp | texto branco fixo (14,2:1); é o único botão da janela |
| `drawable/toast_bg` | branco, raio 5 dp | `texto` | texto `#666666` fixo (5,4:1) |

Isto cobre só os avisos que o próprio `nlprovision` desenha. O "Temperatura anormal" e o "ventilador anormal"
(`showFanDialog`) são `AlertDialog` do framework: §5.

---

## 5. `android` → `PFL7560TemaAndroid.apk` (por último)

**Só cores, nenhuma dimensão, layout, estilo ou imagem.** As três cores abaixo só são citadas, em todo o
`framework-res.apk`, pelo `Theme.Leanback.Light.Dialog.Alert` e pelo `Theme.Leanback.Settings.Dialog.Alert`
(varredura do `aapt2 dump resources`), ou seja, só pelos diálogos de alerta claros do modo TV.

| Recurso | Fábrica | Drácula |
|---|---|---|
| `color/background_leanback_light` | `#EEEEEE` | `#282A36` fundo |
| `color/primary_text_leanback_light` | `#CC222222` | `#F8F8F2` texto (13,4:1) |
| `color/secondary_text_leanback_light` | `#99222222` | `#B4BCCF` secundário (7,5:1) |

**Fica de fora, de propósito:**

- `colorAccent` (`accent_material_light`, `#009688`, o texto do botão OK) e `colorControlHighlight`
  (`ripple_material_light`, preto 12%, o realce do botão em foco) são **globais**: valem para todo app Material
  claro. Trocar o realce por rosa deixaria o texto teal do OK com 1,8:1 sobre ele; trocar o acento deixaria os
  apps claros com acento quase branco. Mantidos. O OK teal fica com 4,2:1 sobre o fundo com o realce de foco (antes, 2,4:1 sobre o
  cinza com realce).
- ~~O **Toast** do framework (`toast_frame`) é imagem, não cor~~ **Corrigido no 16A:** `drawable/toast_frame` é
  uma forma XML (`#E6EEEEEE`, raio 22 dp), não imagem; a do `android` passou a trocá-la (§10.6).

**Risco conhecido:** num diálogo claro do Leanback com dois botões (o `TvSettings` usa o
`Theme.Leanback.Settings.Dialog.Alert`), o realce preto 12% do botão em foco quase some no fundo escuro.
O "Temperatura anormal" tem um botão só. PROVISÓRIO (§8).

---

## 6. Instalação (só documentada; o coordenador integra ao kit)

Uma pasta por APK, com o mesmo nome. Primeiro as dos apps; a do `android` só depois de as dos apps provadas.

```sh
adb root && adb shell mount -o rw,remount /vendor
adb push artifacts/overlay/apk/PFL7560TemaZYSetting.apk /data/local/tmp/
adb shell 'd=/vendor/overlay/PFL7560TemaZYSetting; mkdir -p $d && cp /data/local/tmp/PFL7560TemaZYSetting.apk $d/ \
  && chown -R root:root $d && chmod 0755 $d && chmod 0644 $d/*.apk \
  && chcon -R u:object_r:vendor_overlay_file:s0 $d && ls -lZ $d'
adb reboot                                      # o PackageManager só varre /vendor/overlay no boot
adb shell cmd overlay list                      # deve listar  [ ] com.pfl7560.tema.zysetting  sob com.zhiying.settings
adb shell cmd overlay enable com.pfl7560.tema.zysetting
adb shell am force-stop com.zhiying.settings    # o serviço do aviso de HDMI pega os recursos novos
```

As seis do bloco 16A seguem o mesmo passo a passo, uma pasta por APK (lista e ordem na §10.8).

O mesmo para `PFL7560TemaNLProvision` (`com.pfl7560.tema.nlprovision`; o `nlprovision` é persistente, não
dar `force-stop`: a troca vale para as janelas abertas depois de ligada) e, por último, `PFL7560TemaAndroid`
(`com.pfl7560.tema.android`).

- **Não estáticas** (sem `isStatic`): ligadas e desligadas com `cmd overlay enable|disable`. O estado fica no
  `/data/system/overlays.xml` e sobrevive ao reboot.
- **Estática só depois de provada**, e nunca a do `android`: estática não desliga por comando.
- Desinstalar: `cmd overlay disable <pacote>`, `rm -rf /vendor/overlay/<Nome>`, reboot.

---

## 7. Segurança e saída de emergência

**Por que o risco é baixo, e onde ele mora.** As dos apps só afetam o app alvo: no pior caso o app desenha
errado ou fecha, e `cmd overlay disable` volta. A do `android` entra em todo processo; uma sobreposição errada
do framework pode derrubar a interface no boot. Por isso ela tem só 3 cores, citadas só por 2 estilos de
diálogo, sem nenhuma referência e conferida contra o `framework-res.apk` do firmware.

**Regras que o `conferir.py` prova no PC:** todo recurso existe no alvo com o mesmo nome e o **mesmo tipo**;
toda configuração do alvo (ex.: `hdpi`) tem a sua na sobreposição; nenhum valor referencia recurso (no
Android 9 o id de um recurso só da sobreposição cairia no espaço de ids do alvo); só `color` e `drawable`.

**Saída de emergência, em ordem:**

1. **Sempre antes de remover:** `adb shell cmd overlay disable <pacote>`. Se o problema some, pare aí.
2. **Se a interface não sobe:** o `adbd` sobe antes da interface, mas **neste aparelho o adb só existe pela
   rede** (o USB-C não é adb; doc 06 e doc 26), e Wi-Fi e cabo são ligados pelo `system_server`. Se ele
   ainda conectar: `adb root`, `adb shell cmd overlay disable <pacote>` (se o serviço responder),
   `adb shell mount -o rw,remount /vendor`, `adb shell rm -rf /vendor/overlay/<Nome>`, `adb reboot`.
3. **Se nem a rede sobe:** pendrive do kit com firmware (doc 44, arranjo B do `LEIA-ME.txt`): ligar segurando
   o power reflasha o aparelho e apaga o `/data`. Com o `/data` limpo, uma sobreposição não estática volta a
   nascer desligada (INFERIDO, código do `OverlayManagerService` do Android 9; PROVISÓRIO).

Por isso: a do `android` só depois de as dos apps estarem provadas, nunca estática, e com o pendrive do kit
de emergência à mão no primeiro boot com ela ligada.

---

## 8. PROVISÓRIO (só o aparelho confirma)

1. O `/vendor/overlay` aceita APK nosso, assinado com chave própria (v2 e v3), e o
   `cmd overlay list` o mostra depois do reboot; o `idmap` é criado para os três alvos, inclusive o `android`.
2. As telas ficam como na prévia (`artifacts/overlay/previa/antes-depois.png`): fundo, cartões, moldura rosa,
   chave, janela de senha. Em especial, que nenhuma variante de configuração do alvo (ex.: outra densidade
   escolhida pelo aparelho) passe por cima: a prévia supõe densidade 1,5 (recursos `hdpi`).
3. `zysys.bluetooth.enablesink` e `vendor.newlink.siwei_ui.style` falsos no aparelho (senão o fundo das telas é
   `qili_theme` ou `siwei_bg`, não `pt_green`). Conferir com `getprop`.
4. O aviso de HDMI: painel `comentario`, "Sim" em foco escuro e legível com a luz da sala.
5. O "Temperatura anormal" sai escuro (precisa do modo TV: `adb shell dumpsys uimode` com `type=4`); o OK
   teal legível. E se algum diálogo do `TvSettings` com dois botões perde o foco visível (§5).
6. Os avisos de estilo 2 a 6 do `nlprovision` e o toast dele: difíceis de provocar; ver se algum aparece.
7. Reflash pelo pendrive devolve a sobreposição desligada (§7, item 3).

---

## 9. Provas no PC

- `bash artifacts/overlay/build.sh`: gera os 3 APKs do zero; `apksigner verify` passa (esquema **v3**, o que o
  Android 9 lê; com minSdk 28 o apksigner não gera v2: corrigido no 16A, aqui dizia "v2 e v3"); duas rodadas
  seguidas dão o mesmo md5.
- `python3 -I artifacts/overlay/conferir.py <x>` (com os 3 APKs alvo do firmware): `TUDO OK`, 27 recursos
  (3 do `android`, 3 do `nlprovision`, 21 do `ZYSetting`). Provado também que ele **falha** com
  uma sobreposição errada de propósito: tipo trocado (`color/pt_bt`, que no alvo é `drawable`), recurso
  inexistente, `dimen`, configuração `hdpi` faltando e referência (`@color/...`), num valor e dentro de um XML.
- `python3 -I artifacts/overlay/gerar-previa.py <ZYSetting desmontado>`: `previa/antes-depois.png`, as cinco
  telas antes e depois, desenhadas com os valores de fábrica e os das sobreposições.

---

## 10. Bloco 16A: tema em toda tela e popup (2026-10-31)

Pedido do dono depois de usar o bloco 13: "A tela de bluetooth"; "Gerenciamento de arquivos falta ficar no tema
também"; "Qualquer outra tela ou subtela tem que tá no nosso tema. Qualquer popup também". Spec:
[bloco 16](../sprints/2026-10-31-bloco-16-tema-em-tudo.md), parte 16A. Mesmo método do 13A (§1, §7): só cor,
forma e imagem, com o mesmo nome e o mesmo tipo do alvo, valores literais, conferido pelo `conferir.py`.

Props que decidem o estilo, lidas do `/vendor/build.prop` de fábrica e do `getprop` do aparelho
(`artifacts/diagnostico/audit-logs/getprop.txt` no repositório principal): `vendor.newlink.rgtp_ui.style=1`,
`zysys.sys.is_android=1`, `persist.nl.usb_dialog.vis=false` (linha 52 do build.prop), sem `zysys.bg_white`.
CONFIRMADO.

### 10.1 Varredura: todo app com tela do firmware

67 APKs em `/system/app`, `/system/priv-app` e `/vendor/app`. "Com tela" = tem `res/layout` ou atividade. A
coluna "Coberto" diz qual sobreposição pinta o que o dono vê; "não analisado" é honesto: o app tem tela, mas
esta rodada não mapeou os recursos dele (ficou para o próximo bloco, §10.9).

| APK | Pacote | O que o dono vê | Coberto |
|---|---|---|---|
| `system/app/ZYSetting` | `com.zhiying.settings` | Configurações, todas as subtelas (Wi-Fi, rede, projeção, sistema, atualização, outras, modo de imagem e de brilho, data, idioma), aviso de HDMI | sim: `PFL7560TemaZYSetting` (13A + 16A, §10.2) |
| `system/app/ZYBluetooth` | `com.example.bluetoothsetting` | **a tela de Bluetooth** (o cartão Bluetooth abre `.MainActivity`, `MainPTActivity$3` L91-93) | sim: `PFL7560TemaZYBluetooth` (§10.3) |
| `system/app/ZYFileManager` | `com.newlink.filemanager` | gerenciador de arquivos, janelas de operação, aviso de segurança de USB (desligado de fábrica) | sim, menos os cartões da página inicial: `PFL7560TemaZYFileManager` (§10.4, §10.5) |
| `system/priv-app/NLProvision` | `com.newlink.nlprovision` | avisos de temperatura e ventilador | sim: `PFL7560TemaNLProvision` (13A) + `PFL7560TemaAndroid` |
| `system/priv-app/TvSettings` | `com.android.tv.settings` | pedido de pareamento Bluetooth, aviso de disco USB novo (`DiskReceiver` → `NewStorageActivity`) | sim, só cores: `PFL7560TemaTvSettings` (§10.6) |
| `system/app/HiGalleryL` | `com.hisilicon.higallery` | visor de fotos (abre as telas da suíte), menu de controle | sim: `PFL7560TemaHiGallery` (§10.6) |
| `system/app/NLSourcePlayer` | `com.newlink.nlsource` | entradas HDMI e USB-C, tela "sem sinal", aviso `MyDialog` | sim: `PFL7560TemaNLSource` (§10.6) |
| `system/app/PowerService` | `com.zhiying.powerservice` | menu de energia (botão de ligar do controle), contagem de desligar | sim: `PFL7560TemaPowerService` (§10.6) |
| `system/framework/framework-res.apk` | `android` | Toast de todo app; `AlertDialog` claro e escuro do Leanback | sim: `PFL7560TemaAndroid` (§5, §10.6) |
| `system/priv-app/NLScreenSaver` | `com.newlink.screensaver` | descanso de tela do fabricante | trocado pelo descanso MeowCast (16B) |
| `system/app/HBCastNew` | `com.newlink.cast` | iOSCast | desligado com `pm disable-user` (bloco 16, à mão) |
| `system/app/Miracast` | `com.hisilicon.miracast` | Espelhamento | desligado com `pm disable-user` |
| `system/app/NLOfficeSuit` | `com.mobisystems.editor.office_registered` | Office | desligado com `pm disable-user` |
| `system/app/RGTPLauncher` | `com.newlink.hisilauncher` | home do fabricante | não é mais a home (a nossa, doc 45); fora |
| `system/app/HiPinyinIME` | `com.hisilicon.android.inputmethod.remote` | teclado na tela (senha do Wi-Fi, renomear) | não analisado |
| `system/app/NLHotkeyService` | `com.newlink.hotkeyservices` | avisos de tecla de atalho (`MyDialog` claro, `ToastActivity`) | não analisado a fundo (painel `bg_white_90`, texto preto fixo) |
| `system/priv-app/NewLinkService` | `com.newlink.service` | avisos raros: tempo de uso acumulado, atualização concluída, `BlackDialog` | não analisado a fundo (botões laranja/azul/verde em forma) |
| `system/app/ZYCustomUI` | `com.zhiying.sourceui` | pareamento do controle por IR/voz (`MatchIRUIActivity`, `SYSTEM_ALERT`) | não analisado |
| `system/app/ZYSpeakerModel` | `com.zhiying.bluetoothmodelservice` | modo caixa de som Bluetooth | não analisado |
| `system/app/AutoFocus3` | `com.zhiying.autofocus` | foco e trapézio automáticos (telas de ajuste) | não analisado |
| `system/app/HiTvSetting` | `com.hisilicon.tvsetting` | menu de imagem e som das entradas | não analisado |
| `system/app/HiMusic`, `system/priv-app/HiVideoPlayer`, `system/app/IjkPlayer` | players do fabricante | abertos pelo gerenciador de arquivos | não analisado (o VLC está instalado, bloco 14) |
| `system/priv-app/PackageInstaller` | `com.android.packageinstaller` | instalar e desinstalar app | não analisado; os `AlertDialog` dele caem nos temas Leanback da `android` (INFERIDO) |
| `system/app/Bluetooth` | `com.android.bluetooth` | receber arquivo por Bluetooth (OPP) | não analisado; diálogo do framework (INFERIDO) |
| `system/priv-app/WTProvision`, `Service2`, `TvQuickSettings`, `SettingsIntelligence`, `StorageManager` | serviços e telas sem atalho neste aparelho | nenhuma vista no uso | fora |
| `system/app/HiFactoryMenu`, `NLFactoryMenu`, `NLAutoTest`, `TvTestingTools` | menus e testes de fábrica | só com código de fábrica | fora |
| `system/app/ZYCustomer` | `com.newlink.hisetting` | outro estilo de Configurações | não aberto no estilo `rgtp_ui=1` (INFERIDO) |
| `system/app/HiTvPlayer`, `HiTvService`, `HiExternalTvInput`, `HiRMService` | entradas pelo caminho HiSilicon | reserva; o chip HS352 usa o `nlsource` (doc 45) | fora |
| `KeyChain`, `VpnDialogs`, `SimAppDialog`, `BackupRestoreConfirmation`, `Shell`, `MediaProvider` | diálogos do Android | sem uso neste aparelho | fora |
| `ExtShared`, `PacProcessor`, `WallpaperBackup`, `webview`, `BluetoothMidiService`, `BlockedNumberProvider`, `DefaultContainerService`, `DownloadProvider(Ui)`, `ExternalStorageProvider`, `ExtServices`, `FusedLocation`, `InputDevices`, `MtpDocumentsProvider`, `OneTimeInitializer`, `ProxyHandler`, `SettingsProvider`, `SharedStorageBackup`, `StatementService`, `TvProvider`, `vendor/app/KeymasterProvisionDemo` | serviços | sem tela | fora |

Arquivos lidos no 16A (md5, 8 primeiros dígitos): `ZYBluetooth.apk` `f384eda2`; `ZYFileManager.apk` `c99de765`
(odex `73df0faf`, vdex `2d2fbc33`); `TvSettings.apk` `f654955d`; `HiGalleryL.apk` `cbd35d56` (vdex `33d9d52a`);
`NLSourcePlayer.apk` `e7c7a107` (vdex `5b1d733c`); `PowerService.apk` `040088b3`. Os do 13A na §1.

### 10.2 `com.zhiying.settings`: o que faltava

As subtelas (Projeção, Sistema, Atualização, Outras configurações, Wi-Fi, rede, data, idioma) já saíam no
tema com o 13A: todas descem de `RecyclerviewBaseActivity`/`RecyclerviewSimpleBaseActivity`, com fundo pelos
`My*Layout` (`pt_green`) e foco `item_focus_white` com `rgtp_ui.style=1`. CONFIRMADO no smali. Sobravam:

| Recurso | Fábrica | Drácula | Onde |
|---|---|---|---|
| `drawable/bg_itemcolor` (+ `bg_itemcolor_miroir`) | degradê laranja `#FB884C`→`#DC6641`, raio 10 dp | forma `comentario`, mesmo raio | item escolhido e em foco do modo de imagem e de brilho (`ModeBaseAdapter`, `brightnessBaseAdapter`, `ModeBaseActivity$3/$4`; abertos de `GeneralSettingActivity` L5123 e L9708), sem condição de estilo. Texto branco fixo: 4,7:1 |
| `drawable/button_bg_itemcolor` | o mesmo degradê, raio 40 dp | forma `comentario` | botão em foco do `MyDialog`/`MyConfirmDialog` fora do estilo `rgtp_ui=1` (neste aparelho é `pt_green`, 13A) |
| `color/color_FB884C` | `#FB884C` | `rosa` | seta pressionada dos valores personalizados (`CustomizeAdapter`, `setBackgroundTintList`) |
| `drawable/selected_image` | círculo branco, miolo laranja | miolo `rosa` | marca do modo escolhido |
| `drawable/update`, `drawable/cancel` | botão azul `#0A59F7` | `comentario` | botões em foco da janela de atualização automática (`systemupdate_tip`) |

### 10.3 `com.example.bluetoothsetting` → `PFL7560TemaZYBluetooth.apk`

O mesmo desenho do ZYSetting, num app à parte (layout `activity_main`, `device_item`, `layout_title`).

| Recurso | Fábrica | Drácula | Onde |
|---|---|---|---|
| `color/pt_green` | `#00B26B` | `fundo` | fundo da tela (`MyFrameLayout.init`, `rgtp_ui.style=1`) |
| `color/black` | `#000000` | `linha` | fio de 2 px entre Bluetooth, Procurar e as listas (`ImageView` no layout). Os textos só usam essa cor com `zysys.bg_white=1`, que este aparelho não tem |
| `drawable/item_focus` (9-patch, padrão e `hdpi`) | moldura branca | `rosa` | foco das linhas e dos dispositivos (`MainActivity$3..$7`, `MyAdapter$1`, sem `bg_white`) |
| `drawable/open_check_pt/en/es`, `close_check_pt/en/es` (`hdpi`) | os mesmos do ZYSetting | os mesmos do 13A | chave Ligado/Desligado (`custom_pt_checkbox` com `rgtp_ui.style=1`) |

Ícones (fone, controle, teclado, mouse) e setas são brancos: ficam. O fundo `app_bg` (azul) do layout é trocado
pelo `pt_green` no construtor do `MyFrameLayout`.

### 10.4 `com.newlink.filemanager` → `PFL7560TemaZYFileManager.apk`

A home abre a `SelectActivity`, que com `zysys.sys.is_android=1` repassa para a `MainOtherActivity` (smali
`handleExitAndNavigate`). Fundo de todas as telas: `pt_green` pelo `init()` de `MyConstraintLayout`,
`MyFrameLayout`, `MyLinearLayout`, `MyRecyclerView` e `MyCardView` (`rgtp_ui.style=1`).

| Recurso | Fábrica | Drácula | Onde |
|---|---|---|---|
| `color/pt_green` | `#00B26B` | `fundo` | fundo de todas as telas e dos itens |
| `drawable/background_white` | fio de 3 dp branco | fio de 3 dp `rosa` | moldura de foco dos itens e cartões (`ZoomAnimatorUtils`, `rgtp_ui.style=1`) |
| `mipmap/pt_list_folder_icon`, `_audio_`, `_music_`, `_video_` (`xhdpi`) | teal escuro `#163134` | `comentario` (3,0:1 no fundo) | ícones da lista (`UsbListAdapter`, `rgtp_ui.style=1`) |
| `mipmap/loading_pt` (`hdpi`, `pt-`, `en-`, `es-hdpi`) | "Carregando" verde | `rosa` | carregando do visor de fotos (`BigImagePagerAdapter`) |
| `color/color10` | caramelo `#D09C5A` | `comentario` | botão em foco das janelas de operação (texto branco 4,7:1) e fio do campo de nome |
| `color/color11` | verde-água pálido `#C7DDDA` | `texto` | painel das janelas de operação e da cópia; texto preto fixo (19,7:1) |
| `color/color7` | azul `#389FD6` | `comentario` | botão em foco do aviso de segurança de USB; os fundos com essa cor nos layouts são todos `My*`, trocados por `pt_green` |
| `drawable/usb_risk_shape_bg` | branco (`@android:color/white`), raio 30 dp | `texto` com fio `comentario` de 1 dp | painel do aviso de segurança de USB (texto preto fixo) |
| `drawable/bt_selected_bg` | fio verde `#55CF88` | fio `rosa` | botão em foco da senha do USB (`vendor.nl.usb_password_dialog.vis=1`) |

O aviso de USB do gerenciador (`UsbDialogService`) só abre com `persist.nl.usb_dialog.vis=true`; de fábrica é
`false` (build.prop L52), então o dono não o vê hoje. Ficou pronto mesmo assim. O aviso de disco novo que o
Android abre é o do TvSettings (§10.6).

### 10.5 O que não dá para trocar sem mexer no app (16A)

- **Os nove cartões da página inicial do gerenciador de arquivos** (`activity_main_other`): cada `CardView`
  tem a cor escrita no layout (`app:cardBackgroundColor="#ff06a279"`, `#ffd37405`, `#ffc44c36`, `#ff49a419`,
  `#ff597dda`, `#ffd57708`, `#ff8666f5`, `#ff0585d4`, `#ff019fad`). Não é recurso de cor: só uma sobreposição de
  **layout** trocaria, e layout está fora do método (precisa referenciar ids do alvo). O fundo em volta e a
  moldura de foco ficam no tema; os cartões continuam coloridos. Caminhos: trocar o app ou abrir a lista de
  arquivos direto (`UsbCountActivity`, que é como `vendor.nl.filemanage_file=1` faz); decisão do dono.
- **Barra de progresso da atualização** (`custom_progress_bar`, degradê vermelho-vinho): é `layer-list` que
  cita `@android:id/background`/`progress`; trocá-la exige referência no XML. Fica.
- **Fios das listas** do ZYSetting: cor de `Paint` no código (`setColor(-0x777778)`, cinza), como no 13A.
- **Texto do Toast** (`#DE000000`): é `@color/primary_text_default_material_light`, a cor de todo texto
  Material claro do sistema. Por isso o Toast continua claro (§10.6).
- **Ícones brancos sobre o rosa** no menu de energia: 2,4:1. O foco fica marcado pelo círculo inteiro rosa;
  o ícone é fixo no app.

### 10.6 TvSettings, galeria, entradas, energia e framework

| APK | Recurso | Fábrica | Drácula | Onde |
|---|---|---|---|---|
| `PFL7560TemaTvSettings` | `color/bt_pair_dialog_window_background` | `#EE000000` | `fundo` com o mesmo alfa | janela do pedido de pareamento Bluetooth (`Theme.BtPairReqeustDialog`) |
| | `color/settings_background` | `#1F292E` | `fundo` | fundo das telas do TvSettings (`Theme.Settings`) |
| | `color/settings_category_text_color` | azul `#51AAFF` | `roxo` (5,9:1) | `colorAccent` do `Theme.Settings`: títulos de grupo, chaves |
| | `color/lb_guidedactions_background` | `#111111` | `fundo` | painel das opções dos passos guiados (disco USB novo, formatar, ejetar) |
| `PFL7560TemaHiGallery` | `drawable/ic_*_focus_24dp` (6) e `ic_control_settings_focus` (padrão e `v21`) | amarelo `#FBFB2B`/`#F4EA2A` | `rosa` | botões em foco do menu da galeria (`EventController$MenuDialog`); o `pathData` é o do alvo |
| | `drawable/gallery_selected` (9-patch, `hdpi-v4`) | moldura branca com brilho azul | `rosa` | miniatura escolhida |
| `PFL7560TemaNLSource` | `color/pt_green` | `#00B26B` | `fundo` | tela "sem sinal" da entrada (`MainActivity$1$1` com `isPTStyle`) e botão em foco do `MyDialog` |
| | `color/pt_green_black` | `#163134` | `comentario` | painel do `MyDialog` (os mesmos valores do ZYSetting) |
| `PFL7560TemaPowerService` | `color/pt_green` | `#00B26B` | `rosa` | círculo em foco das opções (`cir_dcdcdc_focus_pt_green`) |
| | `color/pt_green_black` | `#163134` | `linha` (ícone branco 9,2:1) | círculo parado (`cir_dcdcdc_pt`) |
| | `color/pt_red` | `#ED1C24` | `vermelho` (ícone branco 3,1:1) | círculo em foco de Desligar e contagem do `ShutDownActivity` |
| `PFL7560TemaAndroid` | `color/background_leanback_dark` | `#324248` | `fundo` | `AlertDialog` escuro do Leanback (`Theme.Material.Dialog.Alert` vira `Theme.Leanback.Dialog.Alert` no modo TV) |
| | `color/primary_text_leanback_dark` | `#CCEEEEEE` | `texto` | idem |
| | `color/secondary_text_leanback_dark` | `#99EEEEEE` | secundário `#B4BCCF` | idem |
| | `drawable/toast_frame` | forma `#E6EEEEEE`, raio 22 dp | forma `texto` (mesmo alfa) com fio `comentario` de 2 dp, mesmo raio | fundo de todo Toast do sistema (texto preto: 13:1) |

As três cores escuras só são citadas, no `framework-res.apk` inteiro (valores e XML, desmontado pelo apktool),
pelos estilos `Theme.Leanback.Dialog`, `.Dialog.Alert`, `.Light.Dialog`, `.Settings.Dialog` e pelo
`layout-television/user_switching_dialog.xml`, que também é diálogo. `toast_frame` só pelo
`toastFrameBackground` dos temas. O acento dos botões do diálogo escuro (`accent_material_dark`, global) fica.
O risco da `android` continua o da §7; ela cresceu de 3 para 6 cores e 1 forma, nenhuma imagem, dimensão ou
layout, e continua a última a ligar.

### 10.7 PROVISÓRIO (só o aparelho confirma)

1. As seis novas aparecem no `cmd overlay list` sob os pacotes alvo e ligam, como as do 13A (§8, item 1).
2. A galeria: a sobreposição foi gerada com minSdk 1 (§10.8) para manter `v21` e `hdpi-v4` iguais aos do alvo;
   que o Android 9 a aceite como as outras.
3. A tela de Bluetooth, o gerenciador, o modo de imagem, o menu de energia e a tela sem sinal ficam como na
   prévia (`artifacts/overlay/previa/antes-depois-16a.png`). A prévia é desenho com os valores, não captura.
4. O pedido de pareamento e o aviso de disco USB novo do TvSettings: que sejam essas as telas que o dono vê ao
   parear um fone e ao pôr um pendrive (o `DiskReceiver` só abre o aviso para disco novo; pendrive já conhecido
   pode não abrir nada).
5. O Toast claro com fio comentário legível com a luz da sala; e um `AlertDialog` escuro (ex.: remover
   dispositivo) sai no fundo Drácula.
6. Ligar a do `android` nova só depois das dos apps, com o pendrive de emergência à mão (§7).

### 10.8 Construção, instalação e provas

- `build.sh` monta as nove; cada entrada de `SOBREPOSICOES` aceita um minSdk próprio (`pasta:Nome:minSdk`). Só a
  galeria usa (1): com `--min-sdk-version 28` o aapt2 funde as configurações com versão até 28 na padrão
  (`drawable-v21` → padrão, `hdpi-v4` → `hdpi`), e o alvo, feito com o aapt antigo, tem exatamente `v21` e
  `hdpi-v4`. Sem isso o `conferir.py` acusou "configs do alvo sem cobertura: v21 / hdpi-v4" (a configuração do
  alvo ganharia no aparelho). `VERSAO_CODIGO=2`.
- `recolorir.py` ganhou uma tabela por app (`zysetting`, `zybluetooth`, `zyfilemanager`, `higallery`) e procura
  também em `mipmap*`. Regerada a tabela `zysetting`: as 19 imagens do 13A saem com o mesmo md5.
- `conferir.py` aceita `mipmap` (é imagem, como `drawable`): o gerenciador guarda os ícones da lista em mipmap.
  Antes da mudança ele acusou "tipo mipmap não permitido" nos cinco.
- Instalação: a mesma da §6, uma pasta por APK em `/vendor/overlay/`, nesta ordem: `PFL7560TemaZYBluetooth`,
  `PFL7560TemaZYFileManager`, `PFL7560TemaNLSource`, `PFL7560TemaPowerService`, `PFL7560TemaHiGallery`,
  `PFL7560TemaTvSettings` (pacotes `com.pfl7560.tema.<pasta>`), as do 13A atualizadas (versionCode 2) e, por
  último, `PFL7560TemaAndroid`.
- Provas no PC: `bash artifacts/overlay/build.sh` gera as nove e `apksigner verify` passa em todas (v3); duas
  rodadas seguidas, mesmo md5. `python3 -I artifacts/overlay/conferir.py <pasta com os 9 APKs alvo>`:
  **TUDO OK, 76 recursos** (7 do `android`, 8 da galeria, 3 do `nlprovision`, 2 do `nlsource`, 3 da energia,
  4 do TvSettings, 9 do Bluetooth, 12 do gerenciador, 28 do ZYSetting).
  `python3 -I artifacts/overlay/gerar-previa-16a.py <pasta com os apps desmontados>`: a prévia das 8 telas.

### 10.9 Para o próximo bloco

Os apps marcados "não analisado" na §10.1, na ordem do que o dono mais vê: teclado na tela (`HiPinyinIME`),
avisos de tecla de atalho (`NLHotkeyService`), pareamento do controle (`ZYCustomUI`), menu de imagem das
entradas (`HiTvSetting`), foco automático (`AutoFocus3`), modo caixa de som (`ZYSpeakerModel`), avisos do
`NewLinkService`, players do fabricante e o instalador de pacotes. E a decisão sobre os cartões coloridos do
gerenciador de arquivos (§10.5).
