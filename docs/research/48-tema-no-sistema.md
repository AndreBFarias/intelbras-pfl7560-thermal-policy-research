# 48 - Tema Drácula no sistema do fabricante: sobreposições (RRO) (2026-10-31)

**Estado: pronto em código, gerado e conferido no PC. Nada disto rodou no aparelho.** O que só o aparelho
confirma está marcado **PROVISÓRIO** e reunido na seção 8 (bloco 13A) e na §10.7 (bloco 16A).

**Bloco 16A (2026-10-31):** seis sobreposições novas (Bluetooth, gerenciador de arquivos, TvSettings, galeria,
entradas HDMI, menu de energia), o ZYSetting sem o laranja das telas de modo, e a do `android` com os diálogos
escuros do Leanback e a forma do Toast. A varredura de todo app com tela do firmware está na §10.1.

**Bloco 17A (2026-10-31):** seis sobreposições novas (foco automático, modo caixa de som, avisos do
`NewLinkService`, IjkPlayer, player de vídeo e de música HiSilicon), §11. A do `android` não foi tocada.

**Bloco 18 (2026-10-31):** cinco sobreposições novas (teclado na tela, avisos de tecla de atalho, pareamento do
controle e lista de entradas, menu de imagem das entradas, instalador) e a do `android` com mais 2 cores (o título
vermelho da contagem de desligar e o `background_light`), versionCode 3, §12. Vinte ao todo.

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
| `system/app/HiPinyinIME` | `com.hisilicon.android.inputmethod.remote` | teclado na tela (senha do Wi-Fi, renomear) | sim: `PFL7560TemaHiPinyinIME` (18, §12.1) |
| `system/app/NLHotkeyService` | `com.newlink.hotkeysservices` (com s, lido no manifesto) | avisos de tecla de atalho (`MyDialog` claro, `ToastActivity`) | sim, o `MyDialog`: `PFL7560TemaNLHotkeyService` (18, §12.2); a `ToastActivity` fica (cores do framework, §12.7) |
| `system/priv-app/NewLinkService` | `com.newlink.service` | contagem de desligar do descanso, aviso de tela apagada, atualização do MCU e concluída, `BlackDialog` | sim: `PFL7560TemaNewLinkService` (17A, §11.3); o título vermelho e a `ToastActivity` pela do `android` (18, §12.6); o aviso de USB fica (§12.7) |
| `system/app/ZYCustomUI` | `com.zhiying.sourceui` | pareamento do controle por voz (`MatchIRUIYuYinActivity`, `SYSTEM_ALERT`) e lista de entradas (`SourceUIActivity`) | sim: `PFL7560TemaZYCustomUI` (18, §12.3) |
| `system/app/ZYSpeakerModel` | `com.zhiying.bluetoothmodelservice` | modo caixa de som Bluetooth (aberto pelo menu de energia e pela tela de Bluetooth) | sim: `PFL7560TemaZYSpeakerModel` (17A, §11.2) |
| `system/app/AutoFocus3` | `com.zhiying.autofocus` | foco e trapézio automáticos: o aviso durante o ajuste; telas de calibração de fábrica | só o aviso: `PFL7560TemaAutoFocus` (17A, §11.1); a imagem de teste da câmera fica de propósito |
| `system/app/HiTvSetting` | `com.hisilicon.tvsetting` | menu de imagem e som das entradas | sim: `PFL7560TemaHiTvSetting` (18, §12.4) |
| `system/app/HiMusic`, `system/priv-app/HiVideoPlayer`, `system/app/IjkPlayer` | players do fabricante | abertos pelo gerenciador de arquivos (o IjkPlayer para vídeo com áudio AC3/EAC3) | sim: `PFL7560TemaHiMusic`, `PFL7560TemaHiVideoPlayer`, `PFL7560TemaIjkPlayer` (17A, §11.4) |
| `system/priv-app/PackageInstaller` | `com.android.packageinstaller` | instalar e desinstalar app, pedido de permissão | sim, o que é do app: `PFL7560TemaPackageInstaller` (18, §12.5); as telas de instalar ficam claras (tema claro do framework) |
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

---

## 11. Bloco 17A: o que o 16A deixou sem analisar (2026-10-31)

Pedido do dono: "Pode tocar todo o resto", com quatro exceções ditas por ele: o Toast e os diálogos do sistema
(dependem da sobreposição do `android`, que fica para o fim, com o pendrive de resgate à mão), os nove cartões do
gerenciador de arquivos (§10.5), e o teclado na tela, os avisos de tecla de atalho, o pareamento do controle, o menu
de imagem das entradas e o instalador (próximo bloco). Spec:
[bloco 17](../sprints/2026-10-31-bloco-17-overlays-restantes.md). Mesmo método do 13A e do 16A (§1, §7): só
`color`, `drawable` e `mipmap`, mesmo nome e mesmo tipo do alvo, valores literais, conferido pelo `conferir.py`.
**A do `android` não foi tocada** (o mesmo md5 do 16A).

Arquivos lidos (md5, 8 primeiros dígitos): `AutoFocus3.apk` `d30a2637`; `ZYSpeakerModel.apk` `4a7d0e1b`;
`NewLinkService.apk` `615fd40f`; `IjkPlayer.apk` `ceadcaf9`; `HiVideoPlayer.apk` `6f111de0`; `HiMusic.apk`
`483d6a89`; `HiTvPlayer.apk` `31129715`; `NLSourcePlayer.apk` `e7c7a107` (o mesmo do 16A). O smali dos que só têm
odex saiu como no 16A (§1).

### 11.1 `com.zhiying.autofocus` → `PFL7560TemaAutoFocus.apk`

| Recurso | Fábrica | Drácula | Onde |
|---|---|---|---|
| `drawable/toast_bg` | forma branca, raio 5 dp | forma `texto` com fio `comentario` de 2 dp, mesmo raio (como o Toast do sistema, §10.6) | aviso durante o foco e o trapézio automáticos (layout `toast`; `AutoFocusService$14`, `OneACKSService$3`, `AutoCorrectKeyStoneService$2`, no caminho sem `vendor.newlink.toastbg.black`). Texto `#666666` fixo no layout: 5,4:1 |

**Fica de propósito:** as imagens projetadas durante o ajuste (`autofocus_bg`, `autofocus_bg0..2`, `main_bg`,
`correct_user_bg`) são o alvo que a câmera lê (`vendor.newlink.focus.pic=1`); trocar a cor delas pode quebrar o foco
automático. As telas `MainActivity`, `CameraActivity`, `CorrectUserActivity`, `CorrectTipActivity` e
`TrapezoidDatumActivity` são de calibração: nenhum app do firmware abre `AUTO_KEYSTONE_CORRECT_USER` nem
`ONE_AUTO_CORRECTION_KEYSTONE` (busca nos `.apk`/`.vdex`), e `AUTO_FOCUS_CORRECTION` só o `NewLinkService` (fábrica).
O `toast_yk` e o `passworderror` só abrem com `vendor.newlink.toast_style=1` ou `vendor.newlink.setting.xiaoxin=1`,
que este aparelho não tem. CONFIRMADO no smali e no `getprop`.

### 11.2 `com.zhiying.bluetoothmodelservice` → `PFL7560TemaZYSpeakerModel.apk`

Aberto pelo menu de energia ("Só áudio") e pela tela de Bluetooth (`WelcomeActivity` → `MainActivity`). Com
`rgtp_ui.style=1` (`isPTStyle`) o fundo é o `FlyBanner` com `pt_bg` e as fotos `zy_back1..5` (60 s cada).

| Recurso | Fábrica | Drácula | Onde |
|---|---|---|---|
| `drawable/pt_bg` (PNG 1280x720) | teal `#163134` com desenho branco | teal → `fundo`, branco → `texto`, preto fica | primeira imagem do fundo (`initImageUrl`, `isPTStyle`) |
| `drawable/paly_paly_focus`, `paly_pause_focus`, `paly_back_focus`, `paly_forward_focus`, `lock_focus` (`hdpi`, `xhdpi`; `lock_focus` também `mcc451-hdpi`) | círculo azul `#159EFF`, ícone branco | círculo `rosa`, ícone `fundo` (6,0:1) | botões de tocar, voltar, avançar e apagar a tela em foco |
| `drawable/selected_background` | degradê verde-água → lilás, raio 8 dp | `rosa`, mesmo raio | botões "Tela desligada" / "Sair" em foco (`text_view_selector`) |
| `drawable/unselected_background` | branco | `linha` | os mesmos botões parados |
| `drawable/text_color_selector` (lista de cores guardada em `drawable/`) | foco branco, parado preto | foco `fundo`, parado `texto` (8,6:1 sobre `linha`) | texto desses botões |
| `drawable/bg_button` | azul `#3875EF`, raio 15 dp | `comentario` | etiqueta `main_tv_screen` (texto branco 4,7:1) |
| `color/pt_green` | `#00B26B` | `comentario` | botão em foco do aviso de sair (`MyDialog.changeBgByFocus`, texto branco fixo 4,7:1) |
| `color/pt_grey_white` | `#E1EFE9` | `texto` | painel do aviso e botão parado (texto preto fixo 19,7:1) |

Os botões parados de tocar etc. são ícones brancos sem círculo e ficam (o `MyFocus` ainda os tinge com
`color/white`, que não muda: é texto em vários lugares). As fotos `zy_back*` ficam. As listas de contagem e de
"atmosfera" (`CountdownAdapter`, `MusicAtmosphereAdapter`) só aparecem com `vendor.newlink.sleepbutton.vis` /
`key_light.vis`, que este aparelho não tem: ficam.

### 11.3 `com.newlink.service` → `PFL7560TemaNewLinkService.apk`

| Recurso | Fábrica | Drácula | Onde |
|---|---|---|---|
| `color/black` | `#000000` | `fundo` | painel da contagem de desligar do descanso (`ShutDownDialog`, `persist.screensaver.shutdown.time`) e do `BlackDialog`, botão parado da contagem, e texto escuro dos avisos claros (títulos, botão parado). Escuro nos dois papéis: `fundo` sobre `texto` 13,4:1 |
| `color/red` | `#FF2121` | `vermelho` | botão em foco da contagem de desligar (texto branco 3,1:1, como o Desligar do menu de energia) |
| `color/dialog_bg` | roxo `#574FB0` | `linha` | painel do `my_dialog` (atualização do MCU, atualização concluída); texto branco 9,2:1 |
| `drawable/bg_white_90` | branco 90%, raio 13 dp | `texto` 90% | painel do aviso de tela apagada (`activity_shimba_light`, `screen/MyDialog`); texto preto fixo |
| `drawable/button_bg_itemcolor` | degradê laranja, raio 40 dp | `comentario` | botão em foco do aviso de tela apagada e do de tempo de uso (texto branco 4,7:1), como no ZYSetting (§10.2) |
| `drawable/button_bg_item_white` | branco | `texto` com fio `comentario` de 1 dp | botão parado dos avisos claros; botão em foco do `my_dialog` (texto `color/black`, agora `fundo`) |
| `drawable/button_bg_item_blue` | lilás `#A6A6E5` | `comentario` | botão parado do `my_dialog` (texto branco 4,7:1) |
| `drawable/button_bg_item_green` / `_focus` | verde `#82AA81` / com fio branco 3 dp | `comentario` / com fio `rosa` 3 dp | confirmar do `BlackDialog` |
| `drawable/button_bg_item_red` / `_focus` | `#FC5531` / `#FC1944` com fio branco 3 dp | `vermelho` / com fio `texto` 3 dp (rosa sobre vermelho: 1,3:1) | cancelar do `BlackDialog` |

O aviso de tempo de uso (`CumulativeTimeDialog`) só abre com `vendor.newlink.cumulative_time_pop.vis`, que este
aparelho não tem; os botões dele ficaram no tema mesmo assim. As telas de senha de ligar (`SetPasswordActivity`,
`VerifyPasswordActivity`) só abrem pelo `PasswordTransitActivity`, que nenhum app do firmware chama: ficam.

### 11.4 Players: `PFL7560TemaIjkPlayer`, `PFL7560TemaHiVideoPlayer`, `PFL7560TemaHiMusic`

O gerenciador de arquivos abre o IjkPlayer para vídeo com áudio AC3/EAC3 (`FileListFragment$9`) e, no resto, manda
`ACTION_VIEW`: o player de vídeo (`video/*`) e o de música (`audio/*`) da HiSilicon atendem, e o VLC também (bloco 14).
O IjkPlayer e o HiVideoPlayer usam as mesmas imagens de barra de controle.

| APK | Recurso | Fábrica | Drácula |
|---|---|---|---|
| IjkPlayer (padrão) e HiVideoPlayer (`nodpi-v4`) | `drawable/video_bottom` | barra azul-marinho translúcida | `fundo`/`linha`/`comentario`, mesmo alfa, a sombra preta fica |
| | `drawable/pause_focus`, `play_focus` (e `control_settings_focus` no Ijk; `previous_`, `next_`, `fastbackward_`, `fastforward_focus` no HiVideo) | quadrado azul-marinho com brilho azul `#0099FD` | `fundo` com brilho `rosa`, ícone `texto` |
| HiVideoPlayer | `drawable/dialog_background_selector` | degradê azul translúcido `#88...` | `fundo`/`linha`, mesmo alfa |
| | `drawable/item_background_selector` | parado cinza, foco cinza-azulado com fio verde `#8890EE90`, pressionado tomate | parado `linha`, foco `comentario` com fio `rosa`, pressionado `rosa`; mesmos alfas |
| HiMusic (`hdpi-v4`) | `drawable/hisil_background_3` | degradê azul, laranja e vermelho | `fundo`, `linha` e `comentario` (texto branco por cima: 4,7:1 no mais claro) |
| | `drawable/hisil_lank_selected` (9-patch) | moldura azul `#11A9E1` | `rosa` |
| | `drawable/hisil_yuandian`, `_selected` | esfera azul | esfera `rosa` |
| | `drawable/mselector` | fio ciano `#00DAFF` de 4 px | fio `rosa` |

Os dois HiSilicon têm `drawable-nodpi-v4` / `drawable-hdpi-v4`: geradas com minSdk 1, como a galeria (§10.8).
O `HiTvPlayer` (`com.hisilicon.tvui`) nenhum app do firmware abre (busca nos `.apk`/`.vdex`): fora. O
`NLSourcePlayer` não tem tela além das do 16A (2 layouts, ambos já cobertos).

### 11.5 O que não dá para trocar sem mexer no app (17A)

- **Barras de progresso** dos players (`seekbar_style`, `media_controller_progress_bar_selector`): `layer-list` que
  cita `@android:id/background`/`progress`, como a do ZYSetting (§10.5). Ficam.
- **Título vermelho da contagem de desligar**: `@android:color/holo_red_dark` (`#CC0000`) no layout, cor do
  framework. Sobre o `fundo` dá 2,4:1 (sobre o preto de fábrica, 3,6:1). Só a sobreposição do `android` trocaria, e
  ela fica para o fim por decisão do dono.
- **`ToastActivity` e aviso de USB do `NewLinkService`**: fundo `@android:color/background_light` /
  `@android:color/white`, cores do framework: idem.
- **Botões de mídia do HiMusic** (`MediaButton.Play` etc.): desenho do framework. Ficam brancos.
- **Listas do HiMusic** (`FileListActivity`, `ImageListAcvitity`): tema `Theme.Dialog` / `Theme.Holo.Dialog` do
  framework. Só o foco (`mselector`) é do app.

### 11.6 Para o próximo bloco (decisão do dono)

Teclado na tela (`HiPinyinIME`), avisos de tecla de atalho (`NLHotkeyService`), pareamento do controle
(`ZYCustomUI`), menu de imagem das entradas (`HiTvSetting`) e o instalador (`PackageInstaller`). No fim, com o
pendrive de resgate à mão: a do `android` para o Toast, os diálogos do sistema e o título da contagem de desligar.
Os nove cartões do gerenciador de arquivos ficam como estão (§10.5): abrir direto a lista ou trocar o gerenciador.

### 11.7 PROVISÓRIO (só o aparelho confirma)

1. As seis novas aparecem no `cmd overlay list` sob os pacotes alvo e ligam (§8, item 1); as duas com minSdk 1
   (HiVideoPlayer, HiMusic) são aceitas como a da galeria (§10.7, item 2).
2. O aviso do foco automático sai no `toast_bg` novo (e não no caminho preto `toastbg.black`), e o foco automático
   continua funcionando igual (a imagem de teste não mudou; ver se nada mais mudou de lugar).
3. Modo caixa de som: o `pt_bg` recolorido é a primeira imagem do fundo; os botões em foco rosa com ícone escuro; o
   aviso de sair com painel claro e botão em foco `comentario`.
4. A contagem de desligar do descanso e o aviso de tela apagada como na prévia
   (`artifacts/overlay/previa/antes-depois-17a.png`; desenho com os valores, não captura); o título vermelho legível
   com a luz da sala (2,4:1, §11.5).
5. Barra de controle e menus do player de vídeo (HiVideoPlayer e IjkPlayer) e a tela do player de música.
6. O `BlackDialog`, o `my_dialog` e o aviso de tempo de uso são raros: ver se algum aparece.

### 11.8 Construção e provas

- `build.sh` monta as quinze (as nove de antes + seis); as nove de antes saem com **o mesmo md5** do 16A
  (`md5sum -c` com os valores de antes: 9 SUCESSO), `VERSAO_CODIGO` continua 2. Duas rodadas seguidas, mesmo md5
  nas quinze; `apksigner verify` passa nas quinze (v3).
- `recolorir.py` ganhou as tabelas `zyspeakermodel`, `ijkplayer`, `hivideoplayer` e `himusic`, e aceita cor literal
  `#RRGGBB` como destino de uma âncora (o preto do desenho continua preto).
- `python3 -I artifacts/overlay/conferir.py <pasta com os 15 APKs alvo>`: **TUDO OK, 118 recursos** (os 76 do 16A,
  1 do foco automático, 12 da caixa de som, 11 do `NewLinkService`, 4 do IjkPlayer, 9 do HiVideoPlayer, 5 do HiMusic).
- `python3 -I artifacts/overlay/gerar-previa-17a.py <pasta com os apps desmontados>`: a prévia das 7 telas.
- Instalação: a mesma da §6, uma pasta por APK em `/vendor/overlay/`: `PFL7560TemaAutoFocus`,
  `PFL7560TemaZYSpeakerModel`, `PFL7560TemaNewLinkService`, `PFL7560TemaIjkPlayer`, `PFL7560TemaHiVideoPlayer`,
  `PFL7560TemaHiMusic` (pacotes `com.pfl7560.tema.<pasta>`). Nenhuma mexe no framework.

---

## 12. Bloco 18: as últimas telas fora do tema (2026-10-31)

Pedido do dono: "Pode tocar todo o resto". Spec: [bloco 18](../sprints/2026-10-31-bloco-18-overlays-finais.md):
os cinco apps que o 17A deixou para depois (§11.6) e a do `android` com o que só ela alcança (§11.5). Mesmo método
do 13A, 16A e 17A (§1, §7): só `color`, `drawable` e `mipmap`, mesmo nome e mesmo tipo do alvo, valores literais,
conferido pelo `conferir.py`. As quinze de antes não mudaram de nome nem de pacote; as catorze dos apps saem com o
mesmo md5; só a do `android` mudou (versionCode 3).

Arquivos lidos (md5, 8 primeiros dígitos): `HiPinyinIME.apk` `62879976`; `NLHotkeyService.apk` `d4b261df`;
`ZYCustomUI.apk` `f6e125df`; `HiTvSetting.apk` `fb57556c`; `PackageInstaller.apk` `26c4c1ab`;
`framework-res.apk` `3c124b63` (o mesmo do 13A). O smali dos que só têm odex saiu como no 16A (§1).

### 12.1 `com.hisilicon.android.inputmethod.remote` → `PFL7560TemaHiPinyinIME.apk`

O teclado na tela (o PinyinIME do AOSP adaptado ao controle). A pele está em `xml/skb_template1.xml`: fundo
`skb_bg`, teclas `normal_key_bg`/`light_key_bg`/`light_key_up_bg` e as versões `_hl_`. Com o controle, a tecla em
foco é desenhada com a imagem `_hl_` e a cor **normal** do rótulo (`SoftKeyboardView.drawSoftKey`: o ramo do foco
chama `getKeyHlBg` + `getColor`, vtable 17 e 12 de `SoftKey`), branca. CONFIRMADO no smali (odex; vtable pela
ordem dos métodos da classe).

| Recurso | Fábrica | Drácula |
|---|---|---|
| `drawable/skb_bg`, `skb_container_bg` | cinza `#272727`, fio `#848A90` | `fundo`, fio `comentario` |
| `drawable/normal_key_bg`, `light_key_bg`, `light_key_up_bg` (9-patch) | tecla cinza `#464646`–`#6B6B6B` com sombra preta | corpo `linha` (rótulo branco 9,2:1), sombra preta; o ponto do Shift aceso `verde` |
| `drawable/normal_key_hl_bg`, `light_key_hl_bg`, `light_key_up_hl_bg` | tecla cinza-claro `#787878`–`#DADADA` | corpo `comentario` (rótulo branco 4,7:1) e a sombra vira a **moldura rosa** |
| `drawable/cands_container_bg`, `candidates_area_bg`, `candidates_vertical_line`, `arrow_left`/`_right` | barra de candidatos branca, fio e setas cinza | `linha`, fio `comentario`, setas `texto` |
| `drawable/candidate_hl_bg`, `composing_hl_bg`, `composing_area_cursor` | laranja | `rosa` |
| `drawable/composing_area_bg` | branco 85% | `linha` |
| `color/candidate_color`, `composing_color` | preto | `texto` |
| `color/active_candidate_color`, `composing_color_hl` | preto / branco | `fundo` (6,0:1 sobre rosa) |
| `color/recommended_candidate_color` | laranja `#E35900` | `laranja` (5,4:1) |
| `color/footnote_color`, `composing_color_idle` | `#343233` / `#777777` | secundário `#B4BCCF` |

A barra de candidatos e o texto sendo composto só aparecem no modo pinyin. O balão da tecla (`key_balloon_bg`,
branco com `balloon_color` preto) fica claro. As teclas são cinzas puras e colineares: o `recolorir.py` resolve um
cinza pelo primeiro par de âncoras que o contém, por isso a tabela põe os cinzas do corpo antes do preto.

### 12.2 `com.newlink.hotkeysservices` → `PFL7560TemaNLHotkeyService.apk`

O pacote é `com.newlink.hotkeysservices` (com s; a §10.1 dizia sem). Os avisos de tecla de atalho (restaurar os
padrões de fábrica, modo de envelhecimento) são o `view/MyDialog` (`TYPE_SYSTEM_ALERT`), layout `my_dialog`, com
texto preto fixo (`color/black`, `#333333`; nos botões `parseColor`). Decisão do coordenador: painel claro.

| Recurso | Fábrica | Drácula |
|---|---|---|
| `drawable/bg_white_90` | branco 90%, raio 20 px | `texto` 90%, mesmo raio |
| `drawable/button_bg_itemcolor` | degradê laranja, raio 40 dp | `comentario` (texto branco 4,7:1), como no ZYSetting e no `NewLinkService` |
| `drawable/button_bg_item_white` | branco | `texto` com fio `comentario` de 1 dp |

A `ToastActivity` dele é uma tela cheia com o fundo do tema claro do framework e texto `@android:color/black`: fica
(§12.7).

### 12.3 `com.zhiying.sourceui` → `PFL7560TemaZYCustomUI.apk`

Duas telas que o dono vê:

- **Pareamento do controle por voz.** Com `zysys.match_irui_jinju=1` (getprop do aparelho), o `BootBroadcastReceiver`
  abre a `MatchIRUIYuYinActivity` até o dono apertar OK (preferência `match_irui_jinju`). Ela põe numa janela
  `TYPE_SYSTEM_ALERT` um `GifImageView` com `drawable/match_ir_yuyin1280x800` (sem `zysys.dpi`, o padrão "720p";
  com "800p", `match_ir_jinju`). São GIFs animados de 24 quadros, fundo azul com texto em chinês. O `recolorir.py`
  troca só as **paletas** (a global e as 23 locais): azul → `fundo`/`linha`/`comentario` (texto branco 4,7:1 no mais
  claro), brilho dos anéis → `roxo`; o controle, o branco e o vermelho do LED ficam. Quadros, tempos e transparência
  ficam byte a byte (o cabeçalho e o tamanho são os do alvo).
- **Lista de entradas.** O botão de entrada do controle (`com.android.tv.action.VIEW_INPUTS`,
  `TV_INPUT_BUTTON`) e o comando de voz (`VoiceBroadcastReceiver.openSource` do `NewLinkService`) abrem a
  `SourceUIActivity`. Com `rgtp_ui.style=1` (`isPTStyle`) o painel pinta `pt_grey_white` no primeiro foco e cada
  entrada usa `edit_text_large_green` (`pt_green` em foco, `pt_green_black` parada), texto branco do layout.

| Recurso | Fábrica | Drácula |
|---|---|---|
| `drawable/match_ir_yuyin1280x800`, `match_ir_jinju` (GIF) | fundo azul `#002060`–`#006BEF` | `fundo`, `linha`, `comentario`; anéis `roxo` |
| `color/pt_grey_white` | verde-claro `#E1EFE9` | `fundo` (o título, sem cor no código, sai claro: INFERIDO) |
| `color/pt_green` | `#00B26B` | `comentario` (branco 4,7:1) |
| `color/pt_green_black` | `#163134` | `linha` (branco 9,2:1) |

A `MatchIRUIActivity` (`zysys.match_irui`), a `SourceLCActivity` e a `BurnInActivity` não abrem neste aparelho
(props ausentes / fábrica): ficam.

### 12.4 `com.hisilicon.tvsetting` → `PFL7560TemaHiTvSetting.apk`

O `NLSourcePlayer` (entradas HDMI) abre a `SettingActivity` com `com.hisilicon.android.intent.action.tvsetting`
(o IjkPlayer e o HiVideoPlayer também). Painel `activity_setting` à direita, linhas `MainView`, `MainTextView`,
`SelectorView`, `ProgressView`, `CheckBoxView`; a linha em foco pinta `selct_back_color` (`onFocusChange`).

| Recurso | Fábrica | Drácula |
|---|---|---|
| `color/back_color` | `#202125` | `fundo` (painel e as janelas do app) |
| `color/selct_back_color` | `#3B454B` | `comentario` (texto branco 4,7:1) |
| `color/seekbar_bg_color` | `#606060` | `linha` |
| `color/seekbar_progress_fill_enable_color` | branco | `rosa` |
| `color/seekbar_progress_fill_color` | `#898989` | `comentario` |
| `color/seekbar_progress_fill_focus_color` | amarelo `#FFD800` | `rosa` |

O `layer-list` das barras cita `@android:id/...` e fica (§10.5); as cores que as formas dele citam, não: são essas.
O texto das linhas vem do array `text_colorchange` (branco, `#6B6B6B` desligado, `#FFD800`): tipo `array`, fora do
método; o amarelo dá 3,4:1 sobre `comentario`.

### 12.5 `com.android.packageinstaller` → `PFL7560TemaPackageInstaller.apk`

| Recurso | Configuração | Fábrica | Drácula | Onde |
|---|---|---|---|---|
| `color/grant_permissions_background_color` | `television` | `#263238` | `fundo` | pedido de permissão do modo TV (`layout-television/grant_permissions`) |
| `color/grant_permissions_focus_highlight` | `television` | branco 15% | `comentario` (texto `#EEEEEE` 4,1:1) | botão em foco do pedido |
| `color/lb_guidedactions_background` | padrão | `#111111` | `fundo` | opções da desinstalação no modo TV (`UninstallAlertFragment`, GuidedStep do Leanback), como no TvSettings |
| `color/bigIconColor` | padrão | cinza `#C8CCCE` | `comentario` (4,7:1 no branco) | ícone das telas de instalar e da desinstalação |

As telas de instalar (`PackageInstallerActivity`, `InstallInstalling`, `InstallSuccess`, `InstallFailed`) usam
`DialogWhenLarge` = `Theme.DeviceDefault.Light.NoActionBar`: fundo, texto e botões são cores globais do tema claro
do framework e ficam (painel claro). O lado esquerdo da desinstalação (`guidedStepBackground` =
`?android:colorBackground` do tema escuro do framework) também.

### 12.6 `android`: o que só ela alcança (versionCode 3)

**Só cores.** A do `android` vai de 6 para 8 cores (e a forma do Toast do 16A); nenhuma imagem, dimensão ou layout.

| Recurso | Fábrica | Drácula | Quem usa |
|---|---|---|---|
| `color/holo_red_dark` | `#CC0000` | `vermelho` (4,5:1 sobre o painel `fundo`; era 2,4:1) | título da contagem de desligar do `NewLinkService` (`activity_shut_down`). No `framework-res.apk` nenhum recurso a cita além da definição: a troca só alcança os apps que a usam |
| `color/background_light` | `#FFFFFF` | `texto` | fundo da `ToastActivity` do `NewLinkService` (texto `@android:color/black`, 19,7:1: painel claro). No framework ela é ainda o `colorBackground` do `Theme.Light` antigo e o valor de `bright_foreground_dark`, o texto claro dos temas escuros antigos e Holo (`primary_text_dark` e cia.): esses passam do branco ao `texto` Drácula |

Conferido contra o `framework-res.apk` (varredura de `res/` desmontado: `holo_red_dark` só na definição;
`background_light` só em `colors.xml`, linha 51, e `styles.xml`, linha 434).

### 12.7 O que não dá para trocar só com cor e forma (18)

- **Aviso de USB do `NewLinkService`** (`activity_usb`): fundo `@android:color/white`. Trocar o `white` do framework
  mudaria todo branco de todo app (ícones, textos, fundos): fora de proporção. Fica branco com texto preto, que é o
  painel claro da decisão do coordenador (`texto` e branco diferem em menos de 3%).
- **`ToastActivity` do `NLHotkeyService`**: fundo do tema claro do Material do framework (cor global); texto preto.
  Fica (painel claro).
- **Botões de mídia do HiMusic** (`MediaButton.Play`/`.Pause`): `ic_media_play`/`ic_media_pause` do framework são PNG
  (`drawable-xhdpi`), imagem; a do `android` é só cor e forma. Já são brancos, ≈ `texto`. Ficam.
- **Listas do HiMusic** (`FileListActivity` com `Theme.Dialog`, `ImageListAcvitity` com `Theme.Holo.Dialog`): o fundo
  da janela é 9-patch do framework (`panel_background`, `dialog_full_holo_dark`), imagem com margem; trocá-lo por
  forma mudaria a margem (layout). Ficam cinza-escuros; o texto delas (`primary_text_dark`) passa a `texto` pelo
  `background_light`, e o foco (`mselector`) já é rosa (17A).
- **Texto das linhas do HiTvSetting**: array de strings (§12.4).
- **As telas de instalar do PackageInstaller**: tema claro do framework (§12.5).

### 12.8 PROVISÓRIO (só o aparelho confirma)

1. As cinco novas aparecem no `cmd overlay list` sob os pacotes alvo e ligam (§8, item 1); a do teclado, a de um
   IME, como as outras.
2. Teclado: a tecla em foco sai em `comentario` com a moldura rosa e o rótulo branco; a barra de candidatos (pinyin)
   escura. Se o foco do controle usar outro caminho que não o `drawSoftKey` lido (odex), o foco pode sair sem a
   moldura.
3. Pareamento: o `GifImageView` (droidsonroids) anima o GIF recolorido igual ao de fábrica (só as paletas mudaram).
   Para ver de novo: apagar a preferência `match_irui_jinju` do `com.zhiying.sourceui` ou dados do app.
4. Lista de entradas: aparece no botão de entrada do controle com o painel `fundo` e o foco `comentario`.
5. Menu de imagem das entradas (botão de menu numa entrada HDMI) e o pedido de permissão do modo TV como na prévia
   (`artifacts/overlay/previa/antes-depois-18.png`; desenho com os valores, não captura).
6. A do `android` nova (versionCode 3) substitui a anterior no próximo boot; o título da contagem de desligar sai
   `vermelho` e a `ToastActivity` com o fundo `texto`. Ligar só com o pendrive de emergência à mão (§7).

### 12.9 Construção e provas

- `build.sh` monta as vinte; cada entrada de `SOBREPOSICOES` aceita um versionCode próprio no 4º campo
  (`pasta:Nome:minSdk:versao`); só a do `android` usa (3). As catorze dos apps de antes saem com **o mesmo md5** do
  17A (`md5sum -c`: 14 SUCESSO, só a do `android` difere). Duas rodadas seguidas, mesmo md5 nas vinte;
  `apksigner verify` passa nas vinte (v3).
- `recolorir.py` ganhou as tabelas `hipinyinime` e `zycustomui` e recolore `.gif` pela paleta. As imagens do HiMusic
  (17A) regeneradas com o código novo saem com o mesmo md5.
- `python3 -I artifacts/overlay/conferir.py <pasta com os 20 APKs alvo>`: **TUDO OK, 162 recursos** (os 118 do 17A,
  2 novos do `android`, 24 do teclado, 3 do `NLHotkeyService`, 5 do `ZYCustomUI`, 6 do HiTvSetting, 4 do
  PackageInstaller). Os GIFs dentro do APK são byte a byte os de `zycustomui/res`.
- `python3 -I artifacts/overlay/gerar-previa-18.py <pasta com os apps desmontados>`: a prévia das 8 telas.
- Kit: `bash tests/atualizar-md5-kit.sh` copia as vinte para `pendrive-autorun/overlay/` (a do `android` por último em
  `KIT_OVERLAYS`); `make check`, `make check-kit` e `make check-fix` verdes. O `PFL7560TemaZYCustomUI.apk` tem 1,5 MB
  (os dois GIFs); o `/vendor` tem folga (doc 47).
