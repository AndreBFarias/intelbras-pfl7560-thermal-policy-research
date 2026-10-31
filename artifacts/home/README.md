# Home PFL7560 (`com.pfl7560.home`, bloco 10A)

Tela inicial nova para o projetor, na paleta Drácula do bloco 10: relógio e data, **Entradas** (HDMI 1,
HDMI 2, USB-C), **Atalhos** (Verificar projetor, Wi-Fi, Bluetooth, Imagem, Configurações, Espelhamento),
**Apps** e uma linha de estado (rede e temperatura do LED). Só D-pad, com o foco em rosa. Pesquisa, intents,
riscos e desenho: [doc 45](../../docs/research/45-home-pfl7560.md).

![prévia](previa/home-foco-entrada.png)

## Ligar e desligar (sem exceção, nesta ordem)

A home de fábrica continua instalada. A nossa só vira a padrão com:

    adb shell cmd package set-home-activity com.pfl7560.home/.HomeActivity

e volta para a de fábrica com:

    adb shell cmd package set-home-activity com.newlink.nlprovision/.MainActivity

Antes de usar o primeiro comando, leia o doc 45 §4: com ele, o trabalho de boot do `nlprovision` (a HOME
de fábrica) deixa de rodar. Há um caminho mais conservador, documentado lá e ainda não aplicado.

Para abrir sem trocar a padrão: `adb shell am start -n com.pfl7560.home/.HomeActivity`.

## Compilar

    bash artifacts/home/build.sh          # APK do zero: artifacts/home/pfl7560-home.apk
    bash artifacts/home/gerar-previas.sh  # prévias 1920x1080 em artifacts/home/previa/

O molde é o do `artifacts/app/`: sem Gradle, com o SDK local (`ANDROID_SDK`, padrão `~/Android/sdk`;
`BUILD_TOOLS` 35.0.0; `PLATAFORMA` android-34), Java 17 (`javac --release 8`), `zip` e `apksigner`. O
`build.sh` confere a paleta (spec × `colors.xml` × `Tema.java`), copia as fontes IBM Plex do kit para
`assets/fontes/` e assina com `assinatura.keystore` (PKCS12, alias `pfl7560home`, senha no script). A chave
não é segredo: só garante que um APK novo instale por cima. O resultado é determinístico. O script **não**
copia nada para o kit (`pendrive-autorun/`); a integração é do coordenador.

`minSdk 28`, `targetSdk 28`, `versionCode 1`. Permissões: `ACCESS_NETWORK_STATE` e `ACCESS_WIFI_STATE`,
ambas normais.

## Código

| Arquivo | Papel |
|---|---|
| `src/.../Desenho.java`, `Icones.java`, `Modelo.java`, `Tema.java`, `Item.java`, `Acoes.java`, `Pintor.java` | Java puro: layout, ícones, estado e navegação do D-pad. O mesmo código no aparelho e nas prévias |
| `src/.../PintorCanvas.java`, `HomeView.java`, `HomeActivity.java` | Android: Canvas, foco e teclas, ciclo de vida |
| `src/.../Abridor.java` | intents de cada cartão (fontes no doc 45 §3) |
| `src/.../Leitor.java` | lista de apps, rede e temperatura, fora da thread da interface |
| `src/.../Guarda.java` | trava anti-laço: duas quedas em 2 min entregam a tela à home de fábrica |
| `previa-src/.../PintorJ2D.java`, `Previa.java` | pintor Java2D e gerador das prévias, só no PC |

Instalação no aparelho: como o app do 9C, só como app do sistema em `/vendor/app/PFL7560Home/PFL7560Home.apk`
(o `pm install` deste firmware recusa apps de fora). Nada disto foi instalado ainda; o que falta provar
está no doc 45 §9.
