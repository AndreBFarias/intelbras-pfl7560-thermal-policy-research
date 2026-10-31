# Sobreposições Drácula do sistema do fabricante (blocos 13A e 16A)

Pedido do dono (2026-10-31): "Dentro das configs segue o tema antigo". As telas do fabricante passam
para a paleta do bloco 10 (`artifacts/tema/dracula.txt`) por **sobreposição de recursos em tempo
de execução** (RRO). Nenhum app do fabricante é alterado: cada APK daqui só traz cores e imagens, e
o Android as troca na hora de desenhar. Mapa completo, limites e saída de emergência:
`docs/research/48-tema-no-sistema.md`.

| APK (`apk/`) | Pacote | Alvo | O que troca |
| --- | --- | --- | --- |
| `PFL7560TemaZYSetting.apk` | `com.pfl7560.tema.zysetting` | `com.zhiying.settings` | fundo verde das Configurações e do Wi-Fi, os 4 cartões, a moldura de foco (rosa), a chave Ligado/Desligado, a janela de senha do Wi-Fi e o aviso "Deseja abrir HDMI1?" |
| `PFL7560TemaNLProvision.apk` | `com.pfl7560.tema.nlprovision` | `com.newlink.nlprovision` | os avisos próprios dele (painel, botão OK, toast) |
| `PFL7560TemaZYBluetooth.apk` | `com.pfl7560.tema.zybluetooth` | `com.example.bluetoothsetting` | a tela de Bluetooth: fundo, fio, moldura de foco rosa, chave Ligado/Desligado (16A) |
| `PFL7560TemaZYFileManager.apk` | `com.pfl7560.tema.zyfilemanager` | `com.newlink.filemanager` | gerenciador de arquivos: fundo, foco rosa, ícones da lista, carregando, janelas de operação, aviso de USB. Os 9 cartões da página inicial têm cor fixa no layout e ficam (doc 48 §10.5) (16A) |
| `PFL7560TemaTvSettings.apk` | `com.pfl7560.tema.tvsettings` | `com.android.tv.settings` | pedido de pareamento Bluetooth, aviso de disco USB novo, fundo e acento (16A) |
| `PFL7560TemaHiGallery.apk` | `com.pfl7560.tema.higallery` | `com.hisilicon.higallery` | botões em foco do menu da galeria e miniatura escolhida (16A) |
| `PFL7560TemaNLSource.apk` | `com.pfl7560.tema.nlsource` | `com.newlink.nlsource` | tela "sem sinal" das entradas HDMI/USB-C e o aviso `MyDialog` (16A) |
| `PFL7560TemaPowerService.apk` | `com.pfl7560.tema.powerservice` | `com.zhiying.powerservice` | menu de energia: círculos parados, em foco (rosa) e Desligar (vermelho) (16A) |
| `PFL7560TemaAndroid.apk` | `com.pfl7560.tema.android` | `android` | **só 6 cores e 1 forma**: diálogos claros e escuros do Leanback ("Temperatura anormal") e o fundo do Toast. Instalar por último |

| Arquivo | O que é |
| --- | --- |
| `build.sh` | gera os nove APKs do zero (`aapt2 compile/link`, `zipalign`, `apksigner`); reprodutível (mesmo md5); minSdk por sobreposição quando o alvo tem `v21`/`hdpi-v4` |
| `conferir.py` | confere cada APK contra o APK do alvo extraído do firmware: mesmo nome e **mesmo tipo**, todas as configurações do alvo cobertas, nenhum valor com referência, só `color`, `drawable` e `mipmap` |
| `recolorir.py` | gera as imagens recoloridas a partir do app desmontado, uma tabela por app (`zysetting`, `zybluetooth`, `zyfilemanager`, `higallery`; roda uma vez por firmware) |
| `gerar-previa.py` | desenha `previa/antes-depois.png`, as cinco telas do 13A antes e depois, com os valores |
| `gerar-previa-16a.py` | desenha `previa/antes-depois-16a.png`, as oito telas do 16A antes e depois |
| `assinatura.keystore` | chave própria e estável (alias `pfl7560tema`, senha no `build.sh`; não é segredo) |

    bash artifacts/overlay/build.sh
    python3 -I artifacts/overlay/conferir.py <pasta com os 9 APKs alvo do firmware (doc 48 §10.1)>

Instalação: **o kit do pendrive faz sozinho** (bloco 14). `bash tests/atualizar-md5-kit.sh` copia cada APK desta
pasta `apk/` para `pendrive-autorun/overlay/` (sem lista fixa: um APK novo aqui entra sozinho, a do `android` sempre
por último) e o `newlink_update.sh` os grava em `/vendor/overlay/<Nome>/<Nome>.apk` (pasta 0755, arquivo 0644, root,
rótulo `vendor_overlay_file`); no boot seguinte o `suite-boot.sh` liga com `cmd overlay enable <pacote>` as que o
sistema lista como desligadas. O `DESINSTALAR-SUITE.txt` desliga e remove todas. Detalhes: `docs/research/44`, §15.
Na mão, o passo a passo está no doc 48, §6. Não estáticas: `cmd overlay disable <pacote>` desfaz na hora.
