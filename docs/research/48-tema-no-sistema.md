# 48 - Tema Drácula no sistema do fabricante: sobreposições (RRO) (2026-10-31)

**Estado: pronto em código, gerado e conferido no PC. Nada disto rodou no aparelho.** O que só o aparelho
confirma está marcado **PROVISÓRIO** e reunido na seção 8.

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
5. **Saída de emergência** (§7): `cmd overlay disable` desfaz na hora. Se a interface não subir, **o adb pode
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
- O **Toast** do framework (`toast_frame`) é imagem, não cor: fora do que a do `android` pode trocar.

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

- `bash artifacts/overlay/build.sh`: gera os 3 APKs do zero; `apksigner verify` passa (v2 e v3); duas rodadas
  seguidas dão o mesmo md5.
- `python3 -I artifacts/overlay/conferir.py <x>` (com os 3 APKs alvo do firmware): `TUDO OK`, 27 recursos
  (3 do `android`, 3 do `nlprovision`, 21 do `ZYSetting`). Provado também que ele **falha** com
  uma sobreposição errada de propósito: tipo trocado (`color/pt_bt`, que no alvo é `drawable`), recurso
  inexistente, `dimen`, configuração `hdpi` faltando e referência (`@color/...`), num valor e dentro de um XML.
- `python3 -I artifacts/overlay/gerar-previa.py <ZYSetting desmontado>`: `previa/antes-depois.png`, as cinco
  telas antes e depois, desenhadas com os valores de fábrica e os das sobreposições.
