# 43 - Pesquisa P do bloco 9: autofoco, correção de 4 pontos, teclas, modo de projeção e launcher

Pesquisa de 2026-10-30, só leitura e offline, no firmware oficial do aparelho do dono (modelo **com** USB-C,
V1.0.0.9, `PFL7560.bin` md5 `28a2f280eee313a4b115567926b2ba4f`, de `firmware/Software PFL7560.zip`).
Nenhum comando foi mandado ao projetor e nenhum binário do firmware foi executado. Todo o Python rodou com
`-I`. Os dados extraídos foram apagados no fim; ficaram só listagens pequenas no scratchpad.

**Convenção.** `CONFIRMADO` quer dizer lido no código do firmware, no caminho e na linha citados.
`INFERIDO` quer dizer dedução sem execução. A confiança (alta, média ou baixa) é sobre o comando
funcionar no aparelho como descrito. Nada daqui foi rodado no aparelho; a prova é do teste final.

**Linhas citadas.** "smali L*n*" é a linha *n* do arquivo gerado pelo baksmali do apktool
(`--api-level 28`) com o método do §1. "Java L*n*" é a diretiva `.line` (linha do fonte original) quando
existe. Nos `.so` o endereço é virtual (ELF32 Thumb).

---

## 0. Resumo para o 9B e o 9C

1. **Autofoco só de foco, sem mexer no keystone:**
   `am startservice -n com.zhiying.autofocus/.AutoFocusService -a com.zhiying.AUTO_FOCUS_SERVICE --ei auto_focus_keystone 0`.
   É o mesmo intent da tecla AUTOFOCUS do controle (§2). Confiança **alta**.
2. **`vendor.focus.camera.is_focused` não indica fim de foco.** Vira `true` no `onCreate` do serviço, antes
   de focar, e nada no firmware a põe em `false`. O sinal certo é `sys.newlink.auto`: `1` enquanto o serviço
   vive, `0` no fim do foco e no `onDestroy` (§2.3). Isso afeta o `aguardar_autofoco` do `cor.sh` e a etapa
   2 do spec 9B.
3. **A correção de 4 pontos aparece em props:** `persist.sys.keystone.{lt,rt,lb,rb}`. Correção zerada em
   1080p = `0,1080` / `1920,1080` / `0,0` / `1920,0` (§3). Para zerar com segurança, use a tela oficial
   (`am start -n com.newlink.hisetting/.FourPointActivity` e o botão de redefinir). Não há caminho por shell
   que faça o mesmo, por inteiro.
4. **Nenhuma tecla leva a um script nosso.** O mapa de teclas é fixo no código. A única ação configurável
   são as props `vendor.nl.facir.{7,8,9}.*` (abrem um componente Android), presas a teclas de fábrica
   (`NEWLINK7..9`) que o controle comum provavelmente não tem (§4).
5. **Modo de projeção:** o menu grava `Factory.setPanelFlipMirror(0..3)` na PDM. As props que dá para ler são
   `persist.sys.mountingmode` (1..4) e `persist.sys.fac_flipmode` (§5). **Launcher:** lista por
   `android.intent.category.LAUNCHER`, com ícone e sem banner (§6).

---

## 1. Método (reproduzível)

```sh
SP=<scratchpad>/pesquisa
unzip -j "firmware/Software PFL7560.zip" "Software PFL7560/PFL7560.bin" -d $SP/fw/   # md5 28a2f280...
# record 13 = system, record 14 = vendor (tabela LOAD em 0x40, BE: tamanho +0x14, offset +0x18);
# expande o sparse com um extrator próprio (python3 -I), como o build_fix_bin.py faz para o vendor
python3 -I extrai.py $SP/fw/PFL7560.bin 13 $SP/fw/system.raw
python3 -I extrai.py $SP/fw/PFL7560.bin 14 $SP/fw/vendor.raw
debugfs -R "rdump /system/app /system/priv-app /system/framework /system/etc /system/bin $SP/x/system" $SP/fw/system.raw
debugfs -R "rdump /etc /bin /lib /build.prop /default.prop $SP/x/vendor" $SP/fw/vendor.raw
~/.local/bin/apktool d -f --api-level 28 -o $SP/dec/<App> <App>.apk         # APKs com classes.dex
# APKs sem dex (AutoFocus3, HiTvSetting, HiTvService) e jars do framework: dex compacto (cdex) no vdex.
# Desmontados pelo dexlib2 do próprio apktool.jar (programa Java de 20 linhas, Opcodes(28,138)):
java -cp ~/.local/bin/apktool.jar Desmonta.java <odex com o vdex ao lado> <saída>
```

Os rótulos de tecla (`AUTOFOCUS` = 3012, etc.) saíram da tabela `KEYCODES` do `/system/lib/libinput.so`,
lida por script. Os `.so` foram desmontados com capstone (Thumb), só leitura.

Arquivos lidos, com o md5 (8 primeiros dígitos):

| Arquivo | md5 |
|---|---|
| `system/app/AutoFocus3/AutoFocus3.apk` / `oat/arm/AutoFocus3.vdex` | `d30a2637` / `aea49b02` |
| `system/app/NLHotkeyService/NLHotkeyService.apk` | `d4b261df` |
| `system/app/ZYCustomer/ZYCustomer.apk` (`com.newlink.hisetting`) | `c239182a` |
| `system/app/ZYSetting/ZYSetting.apk` (`com.zhiying.settings`) | `8a9d0d57` |
| `system/app/RGTPLauncher/RGTPLauncher.apk` (`com.newlink.hisilauncher`) | `c1a01f23` |
| `system/framework/oat/arm/services.vdex` (`PhoneWindowManager`) | `fee57d3a` |
| `system/framework/oat/arm/HitvShare.vdex` (`AdvancedPictureSetting`, `CusEx`) | `25553521` |
| `vendor/lib/libhitvservice.so` | `4ce86979` (o mesmo do doc 42) |
| `system/lib/libinput.so` / `vendor/usr/keylayout/Vendor_0001_Product_0001.kl` | `53ae35fb` / `f6332283` |
| `vendor/bin/android_ir_user` / `vendor/etc/ZYCustom.ini` | `da5a433e` / `29d8ba36` |

Os pacotes, conferidos no `AndroidManifest.xml` binário de cada APK, são estes:

- `com.zhiying.autofocus` = `AutoFocus3.apk`;
- `com.newlink.hotkeysservices` = `NLHotkeyService.apk`;
- `com.newlink.hisetting` = `ZYCustomer.apk`;
- `com.newlink.hisilauncher` = `RGTPLauncher.apk`;
- `com.zhiying.settings` = `ZYSetting.apk`.

---

## 2. Item 1 - Disparar o autofoco

### 2.1 Como disparar

O `AutoFocus3` não tem nenhum `<receiver>`, então **não existe broadcast que dispare o foco**. O disparo é
por `startService` ou pelas atividades.

| O quê | Comando (como root, no shell do kit) | Fonte | Confiança |
|---|---|---|---|
| **Foco só, sem keystone (recomendado)** | `am startservice -n com.zhiying.autofocus/.AutoFocusService -a com.zhiying.AUTO_FOCUS_SERVICE --ei auto_focus_keystone 0` | `NLHotkeyServices.autoFocus(I)` (smali L243-276) monta exatamente este intent (ação, componente, extra `auto_focus_keystone` int). A tecla AUTOFOCUS chega aqui com 0 (L2487, ramo sem TOF). Serviço `exported="true"`, sem permissão (`AndroidManifest.xml` L76-90) | alta |
| Foco + keystone automático | o mesmo com `--ei auto_focus_keystone 1` (ou sem o extra: o padrão é 2) | `AutoFocusService.onStartCommand`: `getIntExtra("auto_focus_keystone", 2)` (smali L20940). `initAutoKeystone` (L13414) zera o bit 0 de `feature` (keystone) só com 0. Após o foco, `feature & 1` escolhe o estado 8 (keystone) ou 0xb (smali L7773, L8639) | média |
| Pela via da tecla, com o serviço de teclas | `am startservice -n com.newlink.hotkeysservices/com.newlink.hotkeyservices.main.NLHotkeyServices -a android.intent.action.nl.hotkey.serivces --es quick_setting_mode start_auto_focus` | `NLHotkeyServices.onStartCommand` (L1748): `start_auto_focus` vai para o caso 0, que chama `autoFocus(0)` quando `persist.newlink.tof_focus.enable != 1` (L2470-2487). O serviço tem `android:permission="TODO"` (manifest L21): o shell (uid 2000) leva recusa, o root passa (o AMS libera o uid 0, `INFERIDO` do AOSP) | média |
| Pela tecla injetada | `input keyevent 3012` (rótulo `AUTOFOCUS`, scancode 289 no `.kl`) | `PhoneWindowManager.interceptKeyBeforeQueueing`, caso 3012 (smali L27081-27117): **na soltura** da tecla, se o `AutoFocusService` não está rodando (`isServiceRunning`), manda `start_auto_focus` ao serviço de teclas | média (falta provar que a injeção passa por esse caminho) |
| Tecla AUTO_KEYSTONE (3015) | (não usar: faz foco + keystone) | PWM caso 3015 (smali L26912): só se `zysys.autofocus == 1` e `sys.newlink.auto == 0`; manda `auto_focus_keystone=1` | alta |
| URI | `am startservice -a android.intent.action.VIEW -d alliance://start_auto_focus -n com.zhiying.autofocus/.AutoFocusService` | manifest L85-89. `onStartCommand` põe `mAutoFocusKeyStone = 0` para o host `start_auto_focus` e 1 para `start_auto_keystone` | média |

Os outros pontos de entrada do manifest abrem atividades com interface na tela, que atrapalham o kit:

- `com.zhiying.AUTO_FOCUS` (`AutoCorrectEntryActivity`, extra `feature`);
- `com.zhiying.AUTO_FOCUS_CORRECTION` (`CameraActivity`);
- `com.zhiying.ONE_AUTO_CORRECTION_KEYSTONE` (`MainActivity`);
- `com.zhiying.GYRO_CORRECTION` e `com.zhiying.TOF_CORRECTION`.

**Não use** essas atividades na suíte.

### 2.2 Condições para o serviço aceitar (`onStartCommand`, smali L20615-20666)

- **Backlight ligado:** `CusEx.isBacklightEnable()` (L20843). Se falso, o serviço faz `stopSelf` sem focar.
- `vendor.nl.enter.autotest != -1` e `sys.newlink.autocorrectkeystone != 1` (L20633-20637). Se um dos dois
  falhar, faz `stopSelf`.
- `vendor.newlink.autokeystone.skip_hisi_video == 1` com o player de vídeo ou a galeria da HiSilicon em
  primeiro plano força `auto_focus_keystone = 0` (smali L21067-21101).
- Arma um tempo-limite de **60 s** (`sendEmptyMessageDelayed(4, 60000)`, smali L21256), com o estado
  `AF_TOUT` (`handleAutoFocusTimeout`).
- Sobre o Android 9 e serviço em segundo plano, `INFERIDO` do AOSP: o app usa
  `sharedUserId=android.uid.system`. O uid 1000 nunca fica ocioso (o `system_server` roda nele), então o
  `startservice` vindo do shell não deve ser barrado. Confiança média.

### 2.3 Como saber que terminou

| Sinal | Quem escreve | Valor | Confiança como "terminou" |
|---|---|---|---|
| `sys.newlink.auto` | `AutoFocusService.onCreate` → `"1"` (smali L19878, Java L1876). `handleAutoFocusFinish` → `"0"` (L7267). `onDestroy` → `"0"` (L20256) | `1` em curso, `0` parado | **alta.** O próprio `PhoneWindowManager` usa `sys.newlink.auto == "0"` como "livre" (caso 3015) |
| `vendor.focus.camera.is_focused` | `AutoFocusService.onCreate` → `"true"` (smali L19885, Java L1879), **antes** de focar. `AutoFocus2Activity` → `"true"` (smali L15711, Java L1304) | só `true`. Nenhum escritor de `false` no system, no vendor nem no framework (busca por texto em todos os dex, vdex e `.so`) | **não serve:** fica `true` do 1º foco após o boot até o próximo boot |
| `vendor.sys.newlink.auto_focus` | `onCreate`/`onDestroy`, mas só com `SDK_INT > 28` | nunca no Android 9 | não serve |
| logcat, tag `CameraAutoFocus` | `MyLogger`: `handleAutoFocusFinish()` e `AF_TOUT` | só sai com `persist.newlink.debug=1` (lido na carga da classe, `MyLogger` L67) | baixa (exige depuração ligada) |
| `dumpsys activity services com.zhiying.autofocus` | sistema | lista o `AutoFocusService` enquanto vive | média (ver a saída real no aparelho) |

Receita para a suíte (`INFERIDO`, pois junta os fatos acima):

1. Se `getprop sys.newlink.auto` der `1`, já está focando: não dispare, só espere.
2. Dispare. Espere até ~5 s ver `1`, depois até 70 s ver `0`.
3. Se nunca aparecer `1`, o serviço recusou (backlight desligado, etc.): siga.

O valor de `sys.newlink.auto` fica preso em `1` se o processo morrer sem passar pelo `onDestroy`; para esse
caso, use o teto de 70 s.

---

## 3. Item 2 - Onde a correção de 4 pontos é guardada, como ler e como zerar

### 3.1 O caminho

`FourPointActivity` (`com.newlink.hisetting`) → `AdvancedPictureSetting.setX1..Y4Keystone` /
`setX1..Y4KeystoneOffset` (smali L180-2160) → `CusEx.setAdvancedPictureSetting(id, valor)`. Os ids
(`HitvShare`, `AdvancedPictureSetting.smali` L35-95) são:

- `KEYSTONE_RESET = 1`;
- `KEYSTONE_AUTO = 2`;
- `MOUNTING_MODE = 7`;
- `SCREEN_FLIP = 0x19`;
- `KEYSTONE_CORNER_X1..Y4 = 0x20..0x27` e `KEYSTONE_OFFSET_X1..Y4 = 0x28..0x2f`.

Daí o pedido vai, por binder, ao `libhitvservice.so` (`ZYKeystoneService`/`KeystoneHal`), que publica os
cantos efetivos em props:

| Prop | Formato | Quem lê | Fonte | Confiança |
|---|---|---|---|---|
| `persist.sys.keystone.lt` / `rt` / `lb` / `rb` | `x,y` inteiros, origem embaixo à esquerda (`%8u,%8u`; o app grava sem espaço) | SurfaceFlinger (plano gráfico) | `KeystoneHal::updateGraphicsNative` / `queryGraphicsNative` (`libhitvservice.so` 0x206d60, 0x206840). Strings "keystone for SurfaceFlinger Disable!!" junto de `persist.sys.keystone.enable` | alta |
| `persist.hisi.keystone.lt` / `rt` / `lb` / `rb` | `x.x,y.y` em float | `hipluginserver` (plano de vídeo) | mesmas funções. String "keystone for hipluginserver Disable!!" | média-alta |
| `persist.sys.keystone.update` | `true` faz o SurfaceFlinger reaplicar | `surfaceflinger` (string no binário) | `KeystoneHal::setUpdate` / `reset` (0x205900, 0x208512) | alta |
| `persist.sys.keystone.enable` / `persist.hisi.keystone.enable` | liga o **mecanismo**, não diz se há correção | SurfaceFlinger, hwcomposer, hipluginserver | `vendor/build.prop` L170-171 (`true` de fábrica) | alta |
| Os deslocamentos do usuário (X1..Y4) | banco interno do middleware | `libhitvservice` | `ZYData::update(ZY_MW_ATTR_E, ...)`, `ZYData::LoadDbFile` e a string `/atv/db/ZYCustom.db` | média (`INFERIDO`: o caminho do banco é string, o vínculo com os 4 pontos não foi rastreado) |

**Onde não está:**

- não está em `Settings.Global`/`System`: nem `FourPointActivity` nem `BaseActivity` usam `Settings$*`;
- não está no `ZYCustom.ini`: a seção é `[AutoKeystone]` (FOV, eixos, offsets em milésimos; L133-141), sem
  cantos;
- não há HAL/hidl próprio: o `vendor.hisilicon.hardware.hwsysmanager@1.0-impl.so` só lê
  `persist.hisi.keystone.enable`.

### 3.2 Ler: a correção está ligada ou zerada?

```sh
getprop persist.display.720p                 # "true" = cantos de 1280x720
for c in lt rt lb rb; do echo "$c=$(getprop persist.sys.keystone.$c | tr -d ' ')"; done
# zerada (1080p): lt=0,1080  rt=1920,1080  lb=0,0  rb=1920,0
# zerada (720p) : lt=0,720   rt=1280,720   lb=0,0  rb=1280,0
```

Fonte dos valores de "zerada": `BaseActivity.onCreate` do `com.newlink.hisetting` (smali L115-277) usa
exatamente esses padrões em `SystemProperties.get`, conforme `persist.display.720p`. `KeystoneHal::reset`
(0x208464) monta o mesmo retângulo (0,H)(W,H)(0,0)(W,0). Confiança **alta**.

Referência real: no `getprop` de 2026-07-05 (`artifacts/diagnostico/audit-logs/getprop.txt`, só no repo
principal) estava `lt=85,895 rt=1675,1000 lb=30,45 rb=1725,45`, ou seja, **correção ligada** naquela data.

### 3.3 Escrever ou zerar

| Caminho | Comando | O que faz | Confiança |
|---|---|---|---|
| **Tela oficial (recomendado para o conselho da suíte)** | `am start -n com.newlink.hisetting/.FourPointActivity` (ou `-a android.intent.action.FOUR_POINT`) | abre a tela. O "redefinir" (`lambda$createResetDialog$1`, smali L3540-3613) chama `resetKeystone()` (id 1, valor 0) e `setAutoKeystone(<extra keystone.mode, padrão 0>)`, e zera `persist.newlink.autokeystone_{yaw,roll,pitch}` | alta (a atividade tem `intent-filter`, logo é exportada) |
| Reset pela via das teclas | `am startservice -n com.newlink.hotkeysservices/com.newlink.hotkeyservices.main.NLSettingHotKeyService --ei nlhotkey 4017` | `NLHotkeyInputManager.handleHotkeyEvent(4017)` (smali L517) leva a `start_keystone_reset` (`NLHotkeyServices` smali L2206-2232), que faz `resetKeystone()` **e `setAutoKeystone(3)`** e zera as 3 props. Esse serviço é exportado e sem permissão | **baixa:** o significado do modo 3 não foi achado e difere do reset da tela (0). Não usar sem teste |
| Escrever as props direto | `setprop persist.sys.keystone.lt 0,1080` (e rt, lb, rb, os `persist.hisi.*` em float) + `setprop persist.sys.keystone.update true` | o próprio `BaseActivity.onCreate` regrava as 4 props e `update=true`, então o SurfaceFlinger aplica | média para o efeito imediato. **Não durável:** o `libhitvservice` mantém os deslocamentos no banco dele e regrava as props no próximo ajuste ou boot. Não recomendado |
| Pela API Java | `AdvancedPictureSetting.resetKeystone()` num app nosso (`uses-library com.hisilicon.android.tvapi`) | o mesmo da tela | média (o 9C teria de declarar a biblioteca e talvez ser app de sistema; não verificado) |

**Atenção:** com `persist.newlink.autokeystone_enabled=1` (valor no aparelho em 2026-07), um autofoco com
`auto_focus_keystone != 0` pode recalcular o keystone sozinho e mudar os cantos. Por isso a suíte sempre
passa `0` (§2.1).

---

## 4. Item 3 - Uma tecla do controle pode chamar uma ação nossa?

**Resposta: não por configuração simples.** O caminho e o que se achou nele:

| Achado | Fonte | Confiança |
|---|---|---|
| O `PhoneWindowManager` (services.jar) trata as teclas próprias em `interceptKeyBeforeQueueing` com códigos **fixos no código**. 4000-4010 (`NEWLINK0..10`, scancodes 410-420) e 4022-4025 vão ao `NLSettingHotKeyService` com o extra `nlhotkey=<keycode>`. 3012 (`AUTOFOCUS`) vai ao serviço de teclas com `start_auto_focus`. 3015 (`AUTO_KEYSTONE`) vai ao autofoco com keystone. 3000 (`KEY_ROTATE`) inicia o `com.newlink.hisetting/.ProjectionService`, que **gira o modo de projeção a cada chamada** (não usar). 3001 (`KEY_KEYSTONE`) abre `android.settings.DLP` | `PhoneWindowManager.smali` L25008-28749 (mapa caso→código por script) | alta |
| `NLHotkeyInputManager.handleHotkeyEvent` traduz `nlhotkey` em comandos fixos: 3004/3012 → `start_auto_focus`, 4017 → `start_keystone_reset`, 3016/3017 → `keystone_up`/`keystone_down`, 4000-4010 → menus de fábrica, envelhecimento, teste, etc. | `NLHotkeyInputManager.smali` L517-752 | alta |
| **A única ação configurável:** `startByProp("7"|"8"|"9")`, alcançada por 4007 (`start_mac_qr_code`), 4008 (`start_reset`) e 4009 (`start_tool_testing`). Lê `vendor.nl.facir.<N>.starttype` (`activity`, `service` ou `broadcast`), `.arg1` (pacote) e `.arg2` (lista por vírgula de `action:`, `uri:`, `acitivityname:` (com o erro de grafia), `category:`, `extra:k=v`, `flag:`). Com as props vazias, cai no padrão de fábrica | `NLHotkeyServices.startByProp` (smali L518-1242) | alta (leitura); média (uso) |
| Esses 3 códigos são `NEWLINK7..9` (scancodes 417-419). O mapa IR→scancode do `android_ir_user` viria de `/atv/etc/key.xml` ou `/vendor/etc/key.xml`, que **não existem** no firmware (partições atv, record 10, vazias), então vale a tabela embutida no binário, que não foi decodificada. Não se sabe se o controle comum emite 417-419 | `strings android_ir_user`; `debugfs ls` | baixa (provavelmente teclas só do controle de fábrica) |
| Mesmo configurada, a ação é um **componente Android** (atividade, serviço ou broadcast), não um script de shell. Um app nosso teria de fazer a ponte até o root, por exemplo gravando um arquivo que um laço root observa | `startByProp` | alta |
| Toque longo: `zysys.longpress.menu=1` faz o toque longo no MENU abrir `com.hisilicon.android.intent.action.tvsetting` (fixo). O duplo toque no MENU em 1 s, com `zysys.doubleclick.menu=1`, chama o zoom do hisetting (fixo) | `PhoneWindowManager.interceptKeyBeforeDispatching` smali L23037; `interceptKeyBeforeQueueing` L26369 | alta |
| `/system/etc/keyfunction.xml` (tecla → app, só SETTINGS=176 ativo) **não tem leitor**: nenhuma ocorrência de "keyfunction" em dex, vdex, `/system/lib` ou `/vendor` | busca de texto | média-alta |

O teste por shell, sem controle, é este (root): `setprop vendor.nl.facir.7.starttype ...` e depois
`am startservice -n com.newlink.hotkeysservices/com.newlink.hotkeyservices.main.NLSettingHotKeyService --ei nlhotkey 4007`.
As props `vendor.*` não são persistentes: teriam de ser regravadas a cada boot. Para o produto, o gatilho
continua sendo o ícone do app (9C).

---

## 5. Item 4 - Modo de projeção (mesa, teto, frontal, traseira)

| Peça | Valor e significado | Fonte | Confiança |
|---|---|---|---|
| Menu "Direção de projeção" (`com.zhiying.settings`) | `Factory.setPanelFlipMirror(i)`, com i = 0 Frontal, 1 Posterior, 2 Frontal/Teto, 3 Posterior/Teto | `ProjectionDirectionActivity.smali` L27-205, `ProjectionActivity.smali` L441-490; rótulos em `res/values-pt/arrays.xml` L201-206 (`mounting_mode_values`) | alta |
| Onde fica | `HiFactory::SetPanelFlipMirror` aplica `HiVideoPlay::setFlip` e, se `globalconfig:FlipMirrorToPdm`, grava na **PDM** (`HiPanelCtrl::SetPanelFlipMirrorToPdm`), não em prop | `libhitvservice.so` 0x14267c | alta |
| `persist.sys.mountingmode` | 1..4 (padrão 1). Vira a transformação do keystone em `KeystoneHal::getTransform`: 1→nenhuma, 2→FLIP_H, 3→ROT_180, 4→FLIP_V (tabela `0x02030100`). **Nenhum app escreve essa prop neste firmware:** o `setMountingmode` do ZYSetting é código morto | `libhitvservice.so` 0x205614; `ProjectionActivity.smali` L255 (sem chamador) | alta (leitura); média (quem grava) |
| `persist.sys.fac_flipmode` | 0..3, recalculado no boot por `ZYData::createImpl` como `PanelFlipMirror(PDM) XOR T[mountingmode-1]`, com T = {0,2,3,1} | `libhitvservice.so` 0x1e1514-0x1e1620, tabela em 0x2aa778 | média |
| Valores no aparelho (2026-07-05) | `persist.sys.mountingmode=3`, `persist.sys.fac_flipmode=2` | `getprop.txt` do repo principal | fato; a leitura "qual rótulo do menu isso dá" **não foi provada** |

Para ler: `getprop persist.sys.mountingmode; getprop persist.sys.fac_flipmode`. Não há comando de shell para
ler o valor do menu (está na PDM). **Não escrever** essas props nem chamar o `ProjectionService` (ele
gira o modo). Antes de usar o modo para interpretar a câmera, confira no aparelho o rótulo mostrado no menu
junto com as duas props.

---

## 6. Item 5 - Como o launcher lista os apps

| Achado | Fonte | Confiança |
|---|---|---|
| `AppUtils.queryAppInfo` faz `queryIntentActivities(MAIN + android.intent.category.LAUNCHER)`, ordena pelo nome, usa `loadLabel` e **`loadIcon`** e cruza com `getInstalledApplications(0)`. Não há `LEANBACK_LAUNCHER` nem banner no launcher (busca em todo o smali) | `appmanager/qutils/AppUtils.smali` L126-300 | alta |
| Lista negra fixa: `com.qiyivideo.sibichi`, `com.jrm.localmm`, `com.gitvvideo.shanghaishijiu`, `org.mozilla.tv.firefox` (e o próprio launcher) | `AppUtils.<clinit>` L15-56 | alta |
| A lista aparece na tela de todos os apps (`AppManager`), que se atualiza com `PACKAGE_ADDED`/`REPLACED`/`REMOVED` | `AppManager.smali` L1305, L1697-1712 | alta |
| A tela inicial é escolhida pelo `WizardAciticity` (HOME) por props de estilo (`vendor.newlink.rgtp_ui.style=1` no aparelho), e os blocos dela são pacotes fixos (`getLaunchIntentForPackage`) | `WizardAciticity.smali`; `MainActivityRg.smali` L3250 | média (não se achou modo de pôr um app nosso direto na fileira da tela inicial) |

Para o 9C: basta uma atividade com `MAIN` + `LAUNCHER` e ícone. O banner é dispensável.

---

## 7. O que não se achou (ou ficou em aberto)

- Broadcast que dispare o autofoco: **não existe** (o `AutoFocus3` não tem receiver).
- O significado de `setAutoKeystone(3)` (reset via teclas) e de `KEYSTONE_AUTO` com valores 0 a 3.
- O formato do `/atv/db/ZYCustom.db`, e se os 4 deslocamentos ficam mesmo lá.
- A tabela IR→scancode embutida no `android_ir_user`: quais botões do controle comum existem.
- Qual rótulo do menu corresponde a `mountingmode=3` / `fac_flipmode=2` no aparelho do dono.
- Uma forma de ler o valor do menu de projeção (PDM) por shell.

## 8. Consequências anotadas (para os blocos, não feitas aqui)

1. `pendrive-autorun/cor.sh` L211-219 (`aguardar_autofoco`) espera `vendor.focus.camera.is_focused=true`.
   Pelo §2.3 essa prop vira `true` no **início** do foco, então o laço acaba cedo e só a `AUTOFOCO_FOLGA`
   protege. Trocar para `sys.newlink.auto` (ver `1`, depois `0`) é tarefa do 9B.
2. O spec 9B (etapa 2, "espera `vendor.focus.camera.is_focused=true` (até 60 s)") deve usar
   `sys.newlink.auto == 0` com um teto de 70 s.
3. O conselho de "zerar os 4 pontos" deve abrir a `FourPointActivity`, não escrever props.
