# Sobreposições Drácula do sistema do fabricante (blocos 13A, 16A, 17A, 18 e 19B)

Pedido do dono (2026-10-31): "Dentro das configs segue o tema antigo". As telas do fabricante passam
para a paleta do bloco 10 (`artifacts/tema/dracula.txt`) por **sobreposição de recursos em tempo
de execução** (RRO). Nenhum app do fabricante é alterado: cada APK daqui só traz cores e imagens (e,
desde o 19B, cópias de layouts do alvo com só as cores trocadas), e o Android as troca na hora de desenhar. Mapa completo, limites e saída de emergência:
`docs/research/48-tema-no-sistema.md`.

| APK (`apk/`) | Pacote | Alvo | O que troca |
| --- | --- | --- | --- |
| `PFL7560TemaZYSetting.apk` | `com.pfl7560.tema.zysetting` | `com.zhiying.settings` | fundo verde das Configurações e do Wi-Fi, os 4 cartões, a moldura de foco (rosa), a chave Ligado/Desligado, a janela de senha do Wi-Fi e o aviso "Deseja abrir HDMI1?"; desde o 19B (versionCode 3), o fio preto do Wi-Fi (layout) |
| `PFL7560TemaNLProvision.apk` | `com.pfl7560.tema.nlprovision` | `com.newlink.nlprovision` | os avisos próprios dele (painel, botão OK, toast) |
| `PFL7560TemaZYBluetooth.apk` | `com.pfl7560.tema.zybluetooth` | `com.example.bluetoothsetting` | a tela de Bluetooth: fundo, fio, moldura de foco rosa, chave Ligado/Desligado (16A) |
| `PFL7560TemaZYFileManager.apk` | `com.pfl7560.tema.zyfilemanager` | `com.newlink.filemanager` | gerenciador de arquivos: fundo, foco rosa, ícones da lista, carregando, janelas de operação, aviso de USB. Desde o 19B (versionCode 3), os cartões coloridos da página inicial (layout) (16A) |
| `PFL7560TemaTvSettings.apk` | `com.pfl7560.tema.tvsettings` | `com.android.tv.settings` | pedido de pareamento Bluetooth, aviso de disco USB novo, fundo e acento (16A) |
| `PFL7560TemaHiGallery.apk` | `com.pfl7560.tema.higallery` | `com.hisilicon.higallery` | botões em foco do menu da galeria e miniatura escolhida (16A) |
| `PFL7560TemaNLSource.apk` | `com.pfl7560.tema.nlsource` | `com.newlink.nlsource` | tela "sem sinal" das entradas HDMI/USB-C e o aviso `MyDialog` (16A) |
| `PFL7560TemaPowerService.apk` | `com.pfl7560.tema.powerservice` | `com.zhiying.powerservice` | menu de energia: círculos parados, em foco (rosa) e Desligar (vermelho) (16A) |
| `PFL7560TemaAutoFocus.apk` | `com.pfl7560.tema.autofocus` | `com.zhiying.autofocus` | só o aviso durante o foco/trapézio automático; a imagem de teste da câmera fica (doc 48 §11.1) (17A) |
| `PFL7560TemaZYSpeakerModel.apk` | `com.pfl7560.tema.zyspeakermodel` | `com.zhiying.bluetoothmodelservice` | modo caixa de som: fundo, botões em foco rosa, aviso de sair (17A) |
| `PFL7560TemaNewLinkService.apk` | `com.pfl7560.tema.newlinkservice` | `com.newlink.service` | contagem de desligar do descanso, aviso de tela apagada, avisos de atualização e o `BlackDialog` (17A) |
| `PFL7560TemaIjkPlayer.apk` | `com.pfl7560.tema.ijkplayer` | `com.newlink.isuperred.ijkplayerdemo` | barra de controle e botões em foco do player (17A) |
| `PFL7560TemaHiVideoPlayer.apk` | `com.pfl7560.tema.hivideoplayer` | `com.hisilicon.android.videoplayer` | barra de controle, botões em foco e menus do player de vídeo (17A, minSdk 1); desde o 19B (versionCode 3), o painel de informação (layout) |
| `PFL7560TemaHiMusic.apk` | `com.pfl7560.tema.himusic` | `com.hisilicon.android.music` | fundo, moldura de foco, ponto da barra e foco da lista do player de música (17A, minSdk 1) |
| `PFL7560TemaHiPinyinIME.apk` | `com.pfl7560.tema.hipinyinime` | `com.hisilicon.android.inputmethod.remote` | teclado na tela: fundo, teclas, tecla em foco (moldura rosa), barra de candidatos e texto sendo composto (18) |
| `PFL7560TemaNLHotkeyService.apk` | `com.pfl7560.tema.nlhotkeyservice` | `com.newlink.hotkeysservices` | avisos de tecla de atalho (`MyDialog`): painel claro e botões (18) |
| `PFL7560TemaZYCustomUI.apk` | `com.pfl7560.tema.zycustomui` | `com.zhiying.sourceui` | pareamento do controle (GIF animado recolorido) e lista de entradas do botão de entrada (18); desde o 19B (versionCode 3), o fundo da lista antes do primeiro foco (layout) |
| `PFL7560TemaHiTvSetting.apk` | `com.pfl7560.tema.hitvsetting` | `com.hisilicon.tvsetting` | menu de imagem e som das entradas: painel, linha em foco, barras de ajuste (18) |
| `PFL7560TemaPackageInstaller.apk` | `com.pfl7560.tema.packageinstaller` | `com.android.packageinstaller` | pedido de permissão do modo TV, opções da desinstalação, ícone das telas de instalar (18) |
| `PFL7560TemaAndroid.apk` | `com.pfl7560.tema.android` | `android` | **só 8 cores, 1 forma e 4 imagens**: diálogos claros e escuros do Leanback ("Temperatura anormal"), o fundo do Toast, desde o 18 o vermelho do título da contagem de desligar e o `background_light` e, desde o 19B (versionCode 4), as janelas das listas do player de música e o botão tocar/pausar. Nenhum layout. Instalar por último |

| Arquivo | O que é |
| --- | --- |
| `build.sh` | gera os vinte APKs do zero (`aapt2 compile/link`, `zipalign`, `apksigner`); reprodutível (mesmo md5); minSdk por sobreposição quando o alvo tem `v21`/`hdpi-v4`; versionCode por sobreposição (3 nas quatro com layout, 4 na do `android`); numa pasta com `alvo-ids.txt`, linka contra o molde do `molde-alvo.py` (19B) |
| `conferir.py` | confere cada APK contra o APK do alvo extraído do firmware: mesmo nome e **mesmo tipo**, todas as configurações do alvo cobertas, nenhum valor com referência, só `color`, `drawable`, `mipmap` e `layout`; cada layout tem a árvore do alvo (mesmos elementos, ordem, atributos e números de referência) e só valores de cor literais diferentes (19B) |
| `molde-alvo.py` | (19B) grava `<pasta>/alvo-ids.txt`, os ids no alvo de tudo que os layouts citam e dos recursos da sobreposição (roda uma vez por firmware); no build, gera o molde (APK só de nomes com esses ids) que faz cada referência do layout sair com o número do alvo |
| `recolorir.py` | gera as imagens recoloridas a partir do app desmontado, uma tabela por app (`zysetting`, `zybluetooth`, `zyfilemanager`, `higallery`, `zyspeakermodel`, `ijkplayer`, `hivideoplayer`, `himusic`, `hipinyinime`, `zycustomui` e, no 19B, `android` sobre o `framework-res`; roda uma vez por firmware). Um `.gif` é recolorido só na paleta de cada quadro (18) |
| `gerar-previa.py` | desenha `previa/antes-depois.png`, as cinco telas do 13A antes e depois, com os valores |
| `gerar-previa-16a.py` | desenha `previa/antes-depois-16a.png`, as oito telas do 16A antes e depois |
| `gerar-previa-17a.py` | desenha `previa/antes-depois-17a.png`, as sete telas do 17A antes e depois |
| `gerar-previa-18.py` | desenha `previa/antes-depois-18.png`, as oito telas do bloco 18 antes e depois |
| `gerar-previa-19b.py` | desenha `previa/antes-depois-19b.png`, as seis telas do 19B antes e depois |
| `assinatura.keystore` | chave própria e estável (alias `pfl7560tema`, senha no `build.sh`; não é segredo) |

    bash artifacts/overlay/build.sh
    python3 -I artifacts/overlay/conferir.py <pasta com os 20 APKs alvo do firmware (doc 48 §10.1, §11 e §12)>
    python3 -I artifacts/overlay/molde-alvo.py <APK alvo> artifacts/overlay/<pasta>   # só ao trocar um layout ou o firmware

Instalação: **o kit do pendrive faz sozinho** (bloco 14). `bash tests/atualizar-md5-kit.sh` copia cada APK desta
pasta `apk/` para `pendrive-autorun/overlay/` (sem lista fixa: um APK novo aqui entra sozinho, a do `android` sempre
por último) e o `newlink_update.sh` os grava em `/vendor/overlay/<Nome>/<Nome>.apk` (pasta 0755, arquivo 0644, root,
rótulo `vendor_overlay_file`); no boot seguinte o `suite-boot.sh` liga com `cmd overlay enable <pacote>` as que o
sistema lista como desligadas. O `DESINSTALAR-SUITE.txt` desliga e remove todas. Detalhes: `docs/research/44`, §15.
Na mão, o passo a passo está no doc 48, §6. Não estáticas: `cmd overlay disable <pacote>` desfaz na hora.
