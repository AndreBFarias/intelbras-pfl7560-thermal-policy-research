# 46 - Pesquisa 11P: foco, ajustes de imagem, resolução e keystone

Pesquisa de 2026-10-31, só leitura e offline, no firmware oficial do aparelho do dono (V1.0.0.9,
`PFL7560.bin` md5 `28a2f280eee313a4b115567926b2ba4f`, de `firmware/Software PFL7560.zip`), para o
[bloco 11](../sprints/2026-10-31-bloco-11-qualidade-e-foco.md). Mesmo formato do
[doc 43](43-pesquisa-autofoco-keystone-teclas.md). Nenhum comando foi mandado ao projetor e nenhum binário
do firmware foi executado. Todo o Python rodou com `-I`. Os dados extraídos foram apagados no fim.

**Convenção.** `CONFIRMADO` quer dizer lido no firmware, no caminho, linha ou endereço citados.
`INFERIDO` quer dizer dedução sem execução. A confiança (alta, média ou baixa) é sobre o comando ou o fato
funcionar no aparelho como descrito. Nada daqui rodou no aparelho; o que só o aparelho confirma está na
seção 9.

**Endereços e linhas.** "smali L*n*" é a linha *n* do arquivo desmontado (dexlib2 do `apktool.jar`,
`Opcodes(28,138)`, igual ao doc 43). "Java L*n*" é a diretiva `.line`. Nos `.so` o endereço é virtual (ELF32
Thumb). Nos `.ini`/`.conf` é a linha do arquivo.

---

## 0. Resumo para o bloco 11

1. **Há controle do motor de foco por shell, pelo `hidebug`** (o mesmo REPL que a suíte já usa para brilho e
   ventoinha). Posição absoluta: `gfd` lê, `gfdr` dá a faixa, `sfd <pos>` vai até a posição. Passo relativo:
   `sfd2 <0 frente|1 trás> <passos>`. Fonte: `/atv/dbg/cmds.conf` L4431-4480 (§2.1). Isso permite a **varredura
   de foco** que o bloco 11 queria: guardar `gfd`, andar em passos, medir a borda no centro pela câmera, voltar
   ao melhor e, no pior caso, restaurar o valor guardado. Confiança média (o comando está na tabela; o
   efeito só o aparelho prova).
2. **O autofoco do fabricante mede só o miolo da imagem.** Ele maximiza o gradiente de luma numa janela
   central de 500 x 300 px do quadro da câmera, com o alvo "FOCUS" na tela (§2.2). Por isso ele **não enxerga**
   o lado esquerdo: o borrão de 1,5x à esquerda não entra na conta dele.
3. **O keystone é feito na GPU, com filtro bilinear fixo e sem mipmap.** Plano gráfico: SurfaceFlinger; plano de
   vídeo: `hipluginserver` + `libkeystone.so` (Mali). Com `persist.sys.keystone.enable=true`, o SurfaceFlinger
   força `GL_LINEAR` em **todas** as camadas (§5). Não há prop para trocar o filtro.
4. **Os cantos atuais encolhem o lado esquerdo mais que o direito** (altura útil 890 px à esquerda contra 995
   à direita, §5.4). Isso combina com as duas hipóteses ao mesmo tempo: o projetor está girado (lado esquerdo
   mais longe da parede, logo fora do plano de foco) **e** a reamostragem comprime mais aquele lado. A ordem de
   teste da §7 separa as duas.
5. **Os ajustes de imagem (nitidez, NR, MEMC, DCI, SR, overscan, aspecto) agem no caminho de vídeo**, não na tela
   de calibração desenhada pelo app (plano gráfico). Leem-se pelo `hidebug` (`gshr`, `gnr`, `gmemc`, ...) e por
   `cat /proc/msp/pq`. Medir o efeito deles pela câmera exige o padrão **tocado como vídeo** (§3).
6. **A saída é 1080p nativa sem reescala do plano gráfico** no caso do dono (painel 1920 px, `ro.lr.ram_level=low`;
   §4). Conferir com `getprop sys.nl.panel.resolution` (= `1080P`) e `cat /proc/msp/disp1`.
7. **Causas novas de o autofoco "não começar" ou "não mexer":** câmera ocupada (o `nl_camcheck` aberto no
   `/dev/video0`), proteção térmica do motor por intervalo (`Motor is too hot!`) e o limite de 60 s (§2.4).

---

## 1. Método (reproduzível)

O do doc 43 §1, com duas fontes novas:

```sh
SP=<scratchpad>/pesquisa-11p
# record 15 do container LOAD = partição atv (ext4 cru, 50 MiB, volume "atv"; NÃO é sparse)
python3 -I - PFL7560.bin   # lê a tabela em 0x40 e grava o record 15 em rec15.raw
debugfs -R "rdump /pq /ini /dbg /etc /xml $SP/x/atv" rec15.raw
# record 3 = boot.img; dentro, uImage com zImage; o vmlinux sai do gzip no offset 0x4133
python3 -I - kernel   # zlib.decompressobj(16+MAX_WBITS) a partir de 0x4133 -> vmlinux.bin (28,9 MB)
strings -n 4 vmlinux.bin > vmlinux.str   # textos de ajuda dos /proc/msp/*
```

O doc 43 dizia que a partição atv estava vazia no firmware (record 10). Está errado: o record 10 é outra
coisa; **a atv é o record 15** e tem `dbg/cmds.conf`, `ini/db.ini`, `pq/PQ.b` e `etc/key.xml` (ver §8).

Chamadas "quickened" do vdex aparecem como `vtable@N`. Para a classe `JNI` do AutoFocus3, a tabela começa em
11 (os métodos de `Object`); calibrado por `projectorData([D)`, que é `vtable@30` em `AutoFocusService$2`
smali L235 (19ª nativa em ordem alfabética). Daí `getPicClarity2JNI` = `vtable@17` e `getPicClarityJNI` =
`vtable@18`.

Arquivos lidos (md5, 8 primeiros dígitos):

| Arquivo | md5 |
|---|---|
| `atv/dbg/cmds.conf` (comandos do `hidebug`) / `atv/dbg/mods.conf` | `84b753c1` / `8d52553b` |
| `atv/ini/db.ini` (igual ao `db_44.ini`) | `39323012` |
| `vendor/etc/ZYCustom.ini` | `29d8ba36` (o mesmo do doc 43) |
| `system/app/AutoFocus3/oat/arm/AutoFocus3.vdex` / `lib/armeabi-v7a/libnative-lib.so` (do APK) | `aea49b02` / `ce5f0b8e` |
| `system/framework/oat/arm/HitvShare.vdex` | `25553521` |
| `system/app/ZYSetting/ZYSetting.apk` (`com.zhiying.settings`) | `8a9d0d57` |
| `system/lib/libsurfaceflinger.so` | `c9516bc9` |
| `vendor/lib/libkeystone.so` / `vendor/bin/hipluginserver` | `af3391c4` / `37fe6dbc` |
| `vendor/lib/hw/hwcomposer.bigfish.so` | `21d57fea` |
| `vendor/lib/libhitvservice.so` | `4ce86979` |
| `vendor/lib/egl/libGLES_mali.so` (Utgard r8p0) | `acdbf16a` |
| kernel `Linux 4.9.127_s5` (SDK `Hiv352`), `vmlinux.bin` | `3c227f6b` |

---

## 2. Foco

### 2.1 O motor e como mexer nele por shell

O motor de foco é um **passo a passo 24BYJ28** acionado por GPIO pelo `libhitvservice`
(`ZYCustom.ini` L219-248): 4 fases, `SW_MODE=2` (meio passo), `SW_UNIT=1` (passos), `SW_STEP_RANGE=12000`,
fins de curso `LENS_R` (GPIO4_2) e `LENS_L` (GPIO2_7), `SW_INTERVAL_STEP=80`, `SW_DIR_CHANGE_STEP=32`.
`FOCUS_CONTROLLER = Y` (L13).

| O quê | Comando (root, no shell do kit) | Fonte | Confiança |
|---|---|---|---|
| **Ler a posição** | `echo gfd \| /vendor/bin/hidebug` | `cmds.conf` L4465: `cus_GetFocusDistance`, `0xF113`, imprime `d` | média (alta que existe; o formato da saída é do aparelho) |
| **Ler a faixa** | `echo gfdr \| /vendor/bin/hidebug` | L4473: `0xF114`, imprime `[min, max]` | média |
| **Ir a uma posição absoluta** | `echo "sfd <pos>" \| /vendor/bin/hidebug` | L4437: `cus_SetFocusDistance`, `0xF112`, 1 parâmetro. No `libhitvservice`: `ZYProjectionFocus::setFocusDistance(int)` com "Focus Distance Align to %d" e "Out of Range[%d, %d]"; `AutoFocusImpl::updateMotorPositionAbsolutely(int)` (0x1ec496) | média |
| **Andar N passos** | `echo "sfd2 0 <n>" \| /vendor/bin/hidebug` (0 = frente, 1 = trás) | L4444. É o mesmo `0xF112` com 2 parâmetros que o `CusEx.setFocusMotor(II)` do AutoFocus3 manda (`CusExImpl` Java L345: `const v1, 0xf112`) | média-alta |
| Andar N passos com espera | `echo "sfd3 0 <n> <ms>" \| /vendor/bin/hidebug` (`-1` = espera o fim) | L4451; o AutoFocus3 usa este com 5000 ms (`AutoFocusService.setFocusMotor(ZI)`, smali L16515, Java L4553, `const/16 v1, 0x1388`) | média |
| Fins de curso | `echo gfml \| /vendor/bin/hidebug` | L4573, `0xF128` | média |
| Tipo, lente e estágio do motor | `echo "gfm 0" ...` | L4564 (`0xF127`). **Não usar:** `gfm` e `sfm` existem também no módulo `picture` (filme), nomes repetidos (§2.5) | baixa |
| Câmera de foco liga/desliga | `gfce` / `sfce 0\|1` | L4488-4495; `BOARD_FOCUS_CAMERA` no `libhitvservice` | média (só ler na suíte) |
| Pela API Java | `AdvancedPictureSetting.setMotorForward(n)` / `setMotorBackward(n)` / `getMotorPosition()` = `CusEx.setAdvancedPictureSetting(0x42, ±n)` / `get...(0x42)`; equivalente por shell: `saps 66 <n>` e `gaps 66` | `HitvShare` `AdvancedPictureSetting` smali L21 (`FOCUS_MOTOR = 0x42`), Java L506-510 (trás nega o valor); `cmds.conf` L4415-4422 | média (o valor é "nível", não passos: `focusUp(ZY_FOCUS_LEVEL_E)`) |
| Tela de foco manual do fabricante | `am start -a android.settings.motor_focus` | `ZYSetting` `AndroidManifest.xml` L51-57 (`dlpsetting.FocusActivity`, com `intent-filter`); setas ou teclas 3002/3003 chamam `setMotorForward/Backward(1 ou 2)` enquanto seguradas (smali L538-668) | alta (é a tela do menu) |
| GPIO direto | `echo write ... > /proc/msp/gpio` | ajuda no kernel (`vmlinux.str` L48775-48778) | **não usar:** passa por cima dos fins de curso e da proteção do motor |

Não há `/dev` nem `/sys` do motor: o acionamento é do próprio `libhitvservice` (tabela de fases
`FW_DRIVE_SEQUENCE_*`). O cliente Java fala com o middleware por HIDL (`vendor.hisilicon.hardware.hwtvmw@1.0`,
string "please check hwtvmw@1.0-service" no `libhitvclient.so`), então `service call` não serve. O `hidebug`
é o único caminho de shell.

### 2.2 Como o autofoco decide o ponto

| Achado | Fonte | Confiança |
|---|---|---|
| **Por contraste da câmera.** A cada quadro de preview, `handlePicClarity` calcula a nitidez e a máquina de estados anda o motor | `AutoFocusService$4` (é o `Camera.PreviewCallback`) smali L480-900, Java L1212-1243 | alta |
| Métrica padrão (`vendor.newlink.autofocus_camera_pic_mode=0`): `getPicClarityJNI` = soma, em cada pixel da janela, de `sqrt(Σ (vizinho - centro)²)` nos 4 vizinhos, dividida pela área (gradiente médio) | `libnative-lib.so` `getPicClarity1` @0x6300 (laço 0x6378-0x63ca, `vsqrt.f64`) | alta |
| Com `pic_mode=1`: `getPicClarity2JNI`, laplaciano de 4 vizinhos, cortado em [0, máx], médio, numa janela centrada | `getBufferClarity3` @0x6470 (`vmla` com -4.0) | alta |
| **A janela é central**: `mCameraX/Y = (largura/altura do quadro - mWidth/mHeigh)/2`, com `mWidth = persist.newlink.camera_width` (padrão 500) e `mHeigh = persist.newlink.camera_heigh` (300). Props `PROJECTOR_X1/Y1/W/H` podem mover a janela | `AutoFocusService` smali L21227 (Java L2211, `0x1f4`); Java L5398-5414 | alta (leitura); o tamanho do quadro de preview é do aparelho |
| O padrão na tela é o alvo "FOCUS" (anéis concêntricos com traços, 1920x1080), em quatro fundos (`autofocus_bg0..3`: branco, branco "FOCO", amarelo, azul) | `AutoFocusService.<init>` smali L756-759 (tabela de drawables); escolha por `vendor.newlink.focus.pic` em `AutoFocusService$1` L74-358 | alta |
| Passo: `setFocusMotor(dir, n)` anda `n * mTuneStepMin` passos, `mTuneStepMin = persist.newlink.tunestep_min` (código 16, `vendor/build.prop` **40**); o passo grosso usa `tunestep_min_count` (4) vezes isso | `AutoFocusService.setFocusMotor(Z)` smali L16437; `setFocusMotor(ZI)` L16515 | alta |
| A sequência é grossa e depois fina: `handleAutoFocusTuneNew` (busca, guarda `picClarityMax`), `TuneNewReturn` (volta ao melhor), `FineTune2`, `StopTune`, `Finish`. A busca para depois de `persist.newlink.autofocus_dec_count` quedas (3 ou 6) | nomes dos métodos e das mensagens de log ("picClarityMax", "mTuneForward", "AF_COARSE_TUNE failed") | média (`INFERIDO`: as chamadas internas são `vtable@N`) |

Consequência: o autofoco acerta o **centro** da imagem. Se a parede não está paralela à lente, os lados ficam
fora do plano de foco e ele não tem como saber. Não há "foco por regiões" no firmware.

### 2.3 "Foco fino" ou repetir só a varredura fina

**Não por intent.** O `onStartCommand` só lê os extras `auto_keystone_startstatus`, `auto_focus_sensor_stable`,
`feature` e `auto_focus_keystone` (smali L20615-21283, Java L2160-2181). Não há extra de "só fino". O fino
depende de props `persist.newlink.*` (`tunestep_min`, `tunestep_min_return`, `autofocus_fast_mode`,
`autofocus_stop_tune_step`); mudar essas props muda o algoritmo do fabricante para sempre, e **não** é
recomendado.

O caminho certo para o bloco 11 é **a nossa varredura fina**, com os comandos da §2.1 e a nossa medida de borda
(§7, passo 3).

### 2.4 Por que o serviço às vezes "não começa" (ou não mexe)

O doc 43 §2.2 já tinha: backlight desligado, `vendor.nl.enter.autotest`, `sys.newlink.autocorrectkeystone`,
vídeo da HiSilicon em primeiro plano e o limite de 60 s. Achados novos:

| Condição | O que acontece | Fonte | Confiança |
|---|---|---|---|
| **A câmera não abre** (ocupada por outro processo, por exemplo o `nl_camcheck`) | log "open error", desliga e religa a câmera de foco (`CusEx.enableFocusCamera(false)`, 600 ms, `true`), toast de estado e tenta de novo pela mensagem 2 do handler | `AutoFocusService.initCamera` smali L13516, Java L1676-1696 | alta (leitura); média (que o `nl_camcheck` seja a causa do caso visto) |
| Aparelho de 512 MB e nenhum quadro em 5 s (100 x 50 ms) | toast "自动对焦失败，请退出视频后重试!" ("autofoco falhou, saia do vídeo e tente de novo") e `stopSelf` | Java L1658-1671 | média (depende de `isTotalMemory512M`) |
| Espera antes do preview | `zysys.camera.sleep` (600 ms; 3000 ms com 512 MB) a cada abertura, no Android 9 (SDK 28; o ramo com `zysys.camera_sleep_first` é só para SDK > 28) | Java L1637-1651 | alta |
| **Proteção do motor por intervalo** | `Motor is too hot!` em `evaluateIntervalStatus`: o motor recusa movimentos seguidos demais. O foco "roda" mas não anda | `libhitvservice.so` 0x2148d6; `SW_INTERVAL_STEP=80` no `ZYCustom.ini` L236 | média (o critério exato do intervalo não foi decodificado) |
| Motor indisponível | "Focus Motor Not Available!" em todas as funções de foco | `libhitvservice.so` 0x1ed08e, 0x1ed3be e outras | alta (leitura) |

Para a suíte: **nunca** abrir a câmera com o `nl_camcheck` enquanto `sys.newlink.auto=1`, e dar uma pausa
de alguns segundos entre repetições do foco e entre passos da varredura.

### 2.5 Nomes repetidos no `hidebug`

`cmds.conf` tem nomes de comando repetidos entre módulos: `gbl gbri gclrtmp gfm glist glr gnla gsi gtp gvol
sbl sbri sclrtmp sfm si2ce slr snla spd stp`. Em especial, **`sfm`/`gfm` são "film mode" no módulo
`picture` (L196-203) e "focus motor" no `custom` (L4557-4564)**. Não se sabe qual o `hidebug` escolhe. Use só
os nomes únicos: `gfd`, `gfdr`, `sfd`, `sfd2`, `sfd3`, `gfml`, `gaps`, `saps`, `gnk` (todos aparecem uma vez).

---

## 3. Ajustes de imagem

### 3.1 Onde moram e como ler (só leitura)

Os valores do usuário ficam no banco do middleware (`/atv/db/`, formato não decodificado). Os **padrões de
fábrica** estão em `atv/ini/db.ini` (por fonte: `atv`, `dvbc`, `dtmb`, ..., `hdmi`, `media`). A leitura ao vivo
é pelo `hidebug`, módulo `picture` (`mods.conf`: `0x1000`), os mesmos códigos do `Picture` Java.

| Ajuste | Ler | Mudar | Valores | Padrão de fábrica (`db.ini`) | Fonte (`cmds.conf`) |
|---|---|---|---|---|---|
| Modo de imagem | `gpicm` | `spicm <m>` | 0 STANDARD, 1 DYNAMIC, 2 SOFTNESS, 3 USER, 4 VIVID, 5 NATURAL, 6 SPORTS | `Picture_hdmi_mode = 0` (L1081), igual em `media` | L5-12 |
| Nitidez | `gshr` | `sshr <0-100>` | 0-100; mapa não linear 0/30/60/192/255 (`NlaInfo_sharpness`, L437) | 50 no STANDARD e no USER, 75 no DYNAMIC (`PicImage_*`, L1115-1121) | L69-76 |
| Redução de ruído | `gnr` | `snr <0-4>` | 0 OFF, 1 LOW, 2 MID, 3 HIGH, 4 AUTO | `PicEf_hdmi_nr = 2`; o modo STANDARD traz NR 4 (AUTO) na 7ª coluna de `PicImage` (L1107, L1115) | L260-267 |
| Deblocking / deringing | `gdbk` / `gdrg` | `sdbk` / `sdrg` | 0-4 como o NR | 2 (L1108-1109) | L212-235 |
| MEMC | `gmemc` | `smemc <0-4>` | 0-4; `smemce` diz "(not support now)" | `PicVideo_hdmi_memc = 3` (L1102) | L276-299 |
| Contraste dinâmico (DCI) | `gdci` | `sdci 0\|1` | 0/1 | `PicPQ_hdmi_dci = 1` (L1084) | L308-315 |
| Super-resolução | `gsrl` | `ssrl <0-2>` | 0 OFF, 1 ON, 2 DEMO | `PicEf_hdmi_srlevel = 1` (L1111) | L529-536 |
| Overscan | `govs` | `sovs 0\|1` | 0/1 | `PicDisp_hdmi_overscan = 1` (L1093), mas a tabela HDMI é cheia: `HdmiOverScan_1080p_60 = 0,0,10000,10000` (L479). DTV corta 1 % de cada lado (L522) | L372-379 |
| Aspecto (zoom do vídeo) | `gasp` | `sasp <a> 0` | 0 16:9, 3 FULL, 4 P2P (ponto a ponto), 5 AUTO, 10 ZOOM ... | `PicDisp_hdmi_aspect = 0` (16:9), `media = 5` (AUTO) (L1096, L1140) | L420-436 |
| Modo jogo / PC | `ggm` / `gpm` | `sgm` / `spm` | PC: 0 AUTO, 1 PC, 2 VIDEO | `PicVideo_hdmi_pcmode = 2` (L1104) | L388-411 |
| Módulos PQ | `gpqme <n>` | `spqme <n> 0\|1` | 0 FMD, 1 NR, 2 DB, 3 DR, 4 DS, ..., 12 DCI, ..., 20 ALL | `PicPQ_hdmi_pqmodule` (L1089) | L630-637 |
| Zoom e deslocamento digitais da projeção | `gaps 8` (zoom), `gaps 10..13` (topo, baixo, esq., dir.) | `saps 8 <v>` etc. | `AdvancedPictureSetting`: `DIGITAL_ZOOM = 8`, `SHIFT_SCREEN_TOP..RIGHT = 0xa..0xd` | do aparelho | `HitvShare` `AdvancedPictureSetting` smali L13, L99-105 |

O estado dos algoritmos no driver lê-se direto: `cat /proc/msp/pq` (CCS/CLS, GAMMA, SD/HD CTI, "NR LVL", "PQ API":
DEI, SHP, DCI, NR, DB, SR, ...; `vmlinux.str` L49045-49075, L49200-49225). Confiança alta para a leitura.

### 3.2 O que é o "máximo de qualidade" para cada um

`INFERIDO` do papel de cada algoritmo; a prova é a câmera (§7):

| Ajuste | Para nitidez real | Por quê |
|---|---|---|
| Modo de imagem | USER (3) ou STANDARD (0) | DYNAMIC e VIVID sobem nitidez e saturação (75) e saturam o branco; SOFTNESS baixa nitidez (40) |
| Nitidez | 50 (o padrão) como base; testar 60-75 | Nitidez alta **estreita** a borda 10-90 % sem ganhar detalhe: cria halo. A métrica de borda engana; o bloco 11 precisa medir também o halo (sobressinal) |
| NR, deblocking, deringing | OFF (0) para fonte limpa (HDMI de PC, arquivo bom) | NR espacial e temporal amaciam detalhe fino |
| MEMC | OFF (0) | não ganha nitidez em imagem parada e cria artefato em movimento |
| DCI | OFF para medir | muda o contraste de quadro para quadro; atrapalha a comparação |
| Super-resolução | testar ON e OFF | com fonte 1080p num painel 1080p o ganho é incerto |
| Overscan / aspecto | overscan sem corte e aspecto P2P (4) ou 16:9 sem zoom | qualquer corte reescala a imagem |
| Zoom e deslocamento digitais | 0 | são reamostragem pelo mesmo caminho do keystone |

### 3.3 Como mudar de forma reversível

1. Ler e guardar o valor (`g...`), mudar (`s...`), medir, voltar ao guardado. Os `s...` gravam no banco do
   middleware (persistem); a volta é o mesmo comando com o valor antigo.
2. Alternativa que **não persiste**: os interruptores de depuração do driver, `echo <alg> 0|1 > /proc/msp/pq`
   (ajuda no kernel, `vmlinux.str` L49089-49139: `pqalg`, `acm`, `gamma`, `tnr`, `sdcti`, `hdcti`, `cccl`,
   `ifmd`, ...) e `echo pqbypass 1 > /proc/msp/disp1` (L57530). Voltam no reboot. Os nomes curtos de alguns
   (`dci`, `sharpen`, `snr`, `db`) não aparecem como texto separado no kernel; confirme com
   `echo help > /proc/msp/pq` no aparelho. Confiança média.
3. Nada disso toca os 4 pontos.

### 3.4 O plano gráfico não passa por esses ajustes

Nitidez, NR, deblocking, MEMC e SR são da cadeia de vídeo (VPSS/VDP: "VPSS alg", "SHP API", "NR API" em
`/proc/msp/pq`; `vmlinux.str` L49059, L49200-49225). A tela de calibração da suíte é um app Android, ou seja, plano
gráfico (HiFB + SurfaceFlinger). Gama, ACM e o CSC do misturador podem atingir os dois planos (pontos de
`ink` depois do misturador: `gam_in`, `acm_in`, `tcon_dith_in`, L57552-57560). Confiança média-alta.

Consequência: medir a nitidez de **vídeo** pede o padrão tocado como vídeo (um `.mp4` da grade no player da
HiSilicon). A tela de calibração atual mede só foco ótico, keystone e plano gráfico.

---

## 4. Resolução

| Achado | Fonte | Confiança |
|---|---|---|
| O `hwcomposer` lê a largura do painel (`HI_SYS_GetPolicy(3)`). Com 1920 px ou mais e `ro.lr.ram_level` diferente de `critical`, o UI fica 1080p: `sys.nl.panel.resolution=1080P`. Com menos de 1920 ou RAM "critical", grava `persist.display.720p=true` (UI de 720p reescalada) | `hwcomposer.bigfish.so` `HWCDevice::Init` 0x7e3c-0x7ecc | alta |
| `persist.vendor.prop.resolution` vira `1080` quando o framebuffer tem 1080 linhas | 0x7f98-0x7fc0 | alta |
| No aparelho: `ro.lr.ram_level=low`, `persist.display.720p=false` (`vendor/build.prop` L143); painel RX058B 1920x1080 nativo (doc 33) | build.prop, doc 33 | alta |
| Logo o plano gráfico sai 1920x1080 para um painel 1920x1080, **sem ZME (reescala) do HiFB** | dedução das linhas acima | média-alta (`INFERIDO`; conferir na §9) |
| Vídeo HDMI 1080p: overscan cheio (`0,0,10000,10000`) e `videorect 0,0,1920,1080` | `db.ini` L479, L1099 | alta (padrão de fábrica) |

Como ler no aparelho (só leitura):

```sh
getprop sys.nl.panel.resolution; getprop persist.vendor.prop.resolution; getprop persist.display.720p
wm size; wm density
cat /proc/msp/disp1    # fmt_info(W/H/...), virtual_screen(gfx/video), offset(T/B/L/R),
                       # mixer_info(.../panel W/H), sr_en, b_hor_flip/b_ver_flip  (vmlinux.str L57640-57690)
cat /proc/msp/hifb0    # retângulos de entrada e saída da camada gráfica (L58674-58682)
```

O "máximo" é: `fmt_info` 1920/1080/60, `virtual_screen` gfx 1920x1080, `offset` 0/0/0/0, `panel` 1920x1080.

---

## 5. Keystone e nitidez

### 5.1 Onde é feito

| Plano | Quem aplica | Fonte | Confiança |
|---|---|---|---|
| Gráfico (UI, launcher, nossa tela de calibração) | **SurfaceFlinger**, na composição GLES (RenderEngine), lendo `persist.sys.keystone.{lt,rt,lb,rb}` | `libsurfaceflinger.so` 0x6b24e-0x6b4b6 (lê os 4 cantos), 0x6b568 (`persist.sys.keystone.update=false` depois de aplicar) | alta |
| Vídeo | **`hipluginserver`** com a `libkeystone.so` (GPU Mali, `hi_keystone_draw`), lendo `persist.hisi.keystone.*` | `hipluginserver` `NEEDED libkeystone.so`, strings "GPU keystone draw err", "keystone server ..."; `libkeystone.so` exporta `hi_keystone_init/draw` | alta |
| Hardware de vídeo (VDP) | **não** faz a deformação | no kernel, "keystone" só aparece no decodificador (`VFMW_KEYSTONE`, `OMXVDEC` `keystone_correct`: configuração de saída do quadro), sem nada no VDP/HiFB; o Mali tem "mali hw_support_keystone" só como teste de suporte | média |

Com o keystone ligado, o `hwcomposer` desliga o `direct_present` (só o ativa se `persist.sys.keystone.enable`
for falso), então toda tela passa pela GPU (`HWCDisplay::HWCDisplay` 0x86ce-0x86e4). Confiança alta para o
código; média para o efeito.

### 5.2 Qual filtro

| Achado | Fonte | Confiança |
|---|---|---|
| SurfaceFlinger: `setupLayerTexturing` usa `GL_LINEAR` (0x2601) em MIN e MAG se **keystone ligado ou** a camada pedir filtro; senão `GL_NEAREST`. Com `persist.sys.keystone.enable=true`, toda camada é amostrada bilinear | `libsurfaceflinger.so` 0x6be2c-0x6be84 (`orr r0, r8, r7`; r8 = flag do keystone em `this+0x390`, gravada em 0x69f0e a partir da prop) | alta |
| Sem mipmap (MIN_FILTER é `GL_LINEAR`, não `*_MIPMAP_*`): onde a correção encolhe a imagem, a amostragem bilinear perde detalhe fino e serrilha | mesmo trecho | alta (leitura); o tamanho do efeito é da câmera |
| Shader do SurfaceFlinger: `precision mediump float`, `texture2D(sampler, outTexCoords) * texture2D(vig_sampler, outTexCoords)` | `libsurfaceflinger.so` strings 0xe228e-0xe283e | alta |
| `libkeystone.so` (vídeo): `GL_CLAMP_TO_EDGE` e `GL_LINEAR` em MIN e MAG; shaders GLES2 (Mali-450/470, Utgard) e GLES 3.1 com amostragem por amostra (Mali-G52) | `libkeystone.so` 0x2528-0x2552; shaders 0x6188-0x6658; "gpu is mali-450", "gpu is mali-G52" | alta |
| A textura "vig" é a máscara de antisserrilhado da **borda** do quadro: tudo 255, só a moldura com o valor `alias.edge`. Não mexe no miolo | `libsurfaceflinger.so` 0x6a4fa-0x6a6b0 (`memset 0xff`, borda com `r6`, `glTexImage2D` `GL_LUMINANCE`) | alta |
| `persist.sys.keystone.alias.scale` (código 4, aparelho **2**) e `alias.edge` (código 20, aparelho **235**); as mesmas em `persist.hisi.keystone.alias.*` para o vídeo | 0x6a504, 0x6a548; `libkeystone.so` 0x275c, 0x276a; `vendor/build.prop` L172-175 | alta |

O GPU é Utgard (Mali-470, driver r8p0). O fragment shader do Utgard roda em fp16. Se as coordenadas de textura
perderem precisão nesse caminho, a imagem inteira "anda" frações de pixel. **Hipótese de confiança baixa**: o
Utgard costuma ler varying direto para textura com mais precisão. A medida com os 4 pontos zerados resolve
(§7, passo 2).

### 5.3 Dá para trocar por um filtro mais nítido?

**Não por configuração.** O `GL_LINEAR` está fixo no código do SurfaceFlinger e da `libkeystone`. As props
`alias.*` mexem só na moldura. As saídas reais são:

1. **Não precisar de correção:** alinhar o projetor de frente e zerar os 4 pontos pela tela oficial (doc 43
   §3.3). Com cantos de identidade, a amostragem bilinear cai no centro dos texels e não borra (`INFERIDO`).
2. Desligar o mecanismo (`persist.sys.keystone.enable=false`) faria o `hwcomposer` liberar a apresentação direta,
   mas é prop de fábrica, só vale depois de reiniciar o SurfaceFlinger e desliga também o keystone de quem
   precisa dele. **Fora do bloco 11**, salvo palavra do dono; não testado.
3. Trocar o shader exigiria um SurfaceFlinger nosso. Fora de escopo.

Para ler os cantos sem tocar em nada: `getprop persist.sys.keystone.lt` (e `rt`, `lb`, `rb`, doc 43 §3.2) ou
`echo gnk | /vendor/bin/hidebug` (`cus_GetNativeKeystone`, `cmds.conf` L4510, 8 inteiros). **Nunca** `snk`.

### 5.4 O que os cantos atuais dizem

Cantos medidos (bloco 11): `lt=95,915 rt=1715,1030 lb=40,25 rb=1775,35` (origem embaixo à esquerda, doc 43 §3.2).

| Lado | Conta | Escala |
|---|---|---|
| Esquerdo, altura | 915 - 25 = 890 px | 0,82 de 1080 |
| Direito, altura | 1030 - 35 = 995 px | 0,92 de 1080 |
| Topo, largura | 1715 - 95 = 1620 px | 0,84 de 1920 |
| Base, largura | 1775 - 40 = 1735 px | 0,90 de 1920 |

A correção encolhe mais a esquerda. Isso quer dizer que, sem correção, o lado esquerdo sairia **maior** na
parede, ou seja, **mais longe da lente** (projetor girado). Leitura `INFERIDO`, confiança média:

- ótica: a lente foca a distância do centro (§2.2); o lado mais longe fica fora do plano de foco;
- digital: o lado esquerdo é o mais comprimido (0,82), com bilinear sem mipmap.

As duas causas apontam para o mesmo lado. Só a ordem da §7 separa uma da outra.

Há ainda uma confusão de medida: a câmera não está no eixo da lente (`persist.newlink.Camera_DiffX=130`,
`vendor/build.prop`). A nitidez da própria câmera nas bordas do quadro entra na conta. O mapa 3x3 deve ser
comparado **contra ele mesmo** (antes e depois), não em valor absoluto.

---

## 6. O que vira etapa automática e o que só se mostra ao dono

| Item | Automático na suíte (só leitura ou reversível sem risco) | Só mostrar ao dono (decisão dele) |
|---|---|---|
| Cantos do keystone | ler `persist.sys.keystone.*` (ou `gnk`) e calcular a escala de cada lado (§5.4); avisar quando um lado passar de ~10 % | zerar pela tela oficial (`FourPointActivity`) e alinhar o projetor |
| Resolução | ler `sys.nl.panel.resolution`, `persist.display.720p`, `wm size`, `/proc/msp/disp1` e `hifb0`; avisar se não for 1920x1080 sem offset | nada a mudar no caso normal |
| Foco ótico | repetir o autofoco até N=2 com pausa; **varredura fina** pelo `hidebug` (`gfd`, `sfd2`, `sfd`) em torno da posição atual, medindo a borda no centro e voltando ao melhor ou ao valor guardado | pedir a varredura larga (faixa inteira) só com a palavra dele |
| Mapa de nitidez 3x3 | medir e mostrar ("centro ok, canto esquerdo borrado") | a dica ("alinhe de frente e zere os 4 pontos") |
| Ajustes de imagem | ler `gpicm`, `gshr`, `gnr`, `gmemc`, `gdci`, `gsrl`, `govs`, `gasp`, `gaps 8`, `cat /proc/msp/pq` e comparar com a tabela da §3.2 | qualquer `s...`: mostrar "atual x sugerido" e mudar só com a palavra dele, guardando o antigo |
| Zoom e deslocamento digitais | ler `gaps 8`, `gaps 10..13`; avisar se não forem 0 | zerar pelo menu |
| Foco do fabricante | ler `persist.newlink.tunestep_min` e companhia, só para o relatório | não mexer nessas props |

---

## 7. O caminho mais útil para o bloco 11 (mede com a câmera)

Uma variável por vez, sempre com a medida antes e depois e o valor antigo guardado.

1. **Ler o estado** (automático): cantos, escala por lado, resolução, `/proc/msp/disp1`, ajustes de imagem,
   `gfd`/`gfdr`. Tirar o mapa 3x3 de agora. Esperar `sys.newlink.auto=0` antes de abrir a câmera.
2. **Separar digital de ótica sem mover o projetor:** o dono zera os 4 pontos pela tela oficial. A imagem fica
   trapezoidal, mas a amostragem vira identidade. Medir o mapa 3x3 (a grade tem de ser **achada** no quadro,
   não lida em janelas fixas, porque ela muda de lugar):
   - se a esquerda cai para perto do centro, o culpado era a **reamostragem**;
   - se a esquerda continua 1,5x pior, o culpado é **ótico** (distância e inclinação).
   Depois, o dono volta os cantos (pela tela oficial ou pelo autokeystone) ou segue para o passo 4.
3. **Foco fino por varredura** (resolve a hipótese 2 do bloco):
   `p0=$(gfd)`; para `k` em -3..+3: `sfd2` de 1 passo grosso (por exemplo 40 passos, o `tunestep_min`),
   pausa de 1-2 s (proteção do motor e câmera), medir a borda no **centro** e nos lados. Ficar com o mínimo
   do centro, ou com o melhor compromisso centro/lados (o autofoco do fabricante só olha o centro). Se algo
   falhar, `sfd $p0`. Pela folga de direção (`SW_DIR_CHANGE_STEP=32`), aproximar o ponto final sempre pelo
   mesmo sentido.
4. **Alinhar o projetor de frente** (dono), com trapézio perto de 0 e os 4 pontos zerados; foco (passo 3);
   mapa 3x3 final. É o estado de nitidez máxima possível.
5. **Ajustes de imagem só se o dono usar vídeo:** tocar a grade como `.mp4` (plano de vídeo) e testar um
   ajuste por vez (NR 0, MEMC 0, DCI 0, nitidez 50 e 70, SR 0 e 1), medindo borda **e** halo.

A métrica de borda 10-90 % do `nl_camcheck` serve para os passos 1 a 4 (plano gráfico, sem sharpen). No
passo 5, nitidez artificial estreita a borda e cria halo; medir os dois.

---

## 8. O que não se achou (ou ficou em aberto)

- O critério exato da proteção "Motor is too hot!" (quantos passos em quanto tempo).
- A unidade de `gfd`/`sfd` no aparelho (passos do motor, pelo `SW_UNIT=1`, ou outra escala) e a faixa real
  de `gfdr`.
- Qual comando o `hidebug` executa quando o nome se repete entre módulos (`sfm`, `gfm` e outros, §2.5).
- O que o nível de `setMotorForward(n)` (id `0x42`) significa em passos (`ZY_FOCUS_LEVEL_E`).
- O formato do banco `/atv/db/` com os valores do usuário (só os padrões do `db.ini` foram lidos).
- O tamanho real do quadro de preview que o AutoFocus3 usa (define onde fica a janela de 500 x 300).
- Se o Utgard perde precisão de coordenada de textura no shader `mediump` do SurfaceFlinger (§5.2).
- Se a tabela de overscan vale para `media` (não há `MediaOverScan_*` no `db.ini`).
- Os nomes curtos de alguns comandos de `/proc/msp/pq` (`dci`, `sharpen`, `snr`, `db`).
- Um "foco por regiões" ou um extra de intent para "só foco fino": **não existe** no AutoFocus3.
- Correção ao doc 43 §4 e §7: o `/atv/etc/key.xml` **existe** no firmware (record 15, md5 `9dfca095`). A tabela
  IR→scancode pode ser lida dele; não foi feito aqui (fora do 11P).

## 9. O que só o aparelho confirma (PROVISÓRIO)

1. Que `echo gfd | /vendor/bin/hidebug` imprime um número e `gfdr` uma faixa coerente com 12000 passos.
2. Que `sfd2 0 40` move o foco visivelmente e `sfd <p0>` volta ao mesmo ponto (medido pela borda).
3. Que `sys.nl.panel.resolution=1080P`, `persist.display.720p=false`, e que `/proc/msp/disp1` mostra
   `virtual_screen` 1920x1080 e `offset` 0.
4. Que os ajustes `gshr`, `gnr`, `gmemc`, `gdci`, `gsrl`, `govs`, `gasp` respondem e com que valores.
5. Que zerar os 4 pontos muda (ou não) a borda do lado esquerdo (§7, passo 2).
6. Que a câmera ocupada pelo `nl_camcheck` reproduz o "não começou" do autofoco.
