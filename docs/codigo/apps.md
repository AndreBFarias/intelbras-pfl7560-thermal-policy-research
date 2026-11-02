# Notas do código: app, home, tema e sobreposições (`artifacts/app`, `home`, `tema`, `overlay`)

O porquê das decisões no código Java, nos `build.sh` e nos geradores em Python. O que cada peça é e como se usa:
os READMEs de [`app`](../../artifacts/app/README.md), [`home`](../../artifacts/home/README.md),
[`tema`](../../artifacts/tema/README.md) e [`overlay`](../../artifacts/overlay/README.md), e os docs
[44](../research/44-suite-de-boot.md), [45](../research/45-home-pfl7560.md) e [48](../research/48-tema-no-sistema.md).
Mapa geral: [`../MAPA.md`](../MAPA.md).

## Os três `build.sh` (app, home, sobreposições)

- **Sem Gradle, do zero:** `aapt2 compile` + `link` → `javac --release 8` → `d8` → dex no zip → `zipalign` →
  `apksigner sign` → `apksigner verify` (as sobreposições não têm dex). SDK local, sem rede: `ANDROID_SDK` (padrão
  `~/Android/sdk`), `BUILD_TOOLS` (35.0.0), `PLATAFORMA` (android-34); java/javac 17, `zip` e `apksigner`.
- **Determinístico:** datas fixas no zip e assinatura RSA sem aleatoriedade; mesmas entradas, mesmo md5.
- **Chave própria e estável** (`assinatura.keystore`; senha no script, não é segredo): só garante que um APK novo
  instale por cima do anterior. Não serve para loja.
- `VERSAO_CODIGO` sobe a cada APK novo (o kit instala por cima quando muda). No app, o `APP_VERSION_CODE` do
  `newlink_update.sh` tem de ser o mesmo (o harness confere). Depois de um APK novo, `bash tests/atualizar-md5-kit.sh`.
- Só o `build.sh` do app copia para o kit; o da home e o das sobreposições não (a integração é do coordenador).
- O app leva só a fonte Bold (o nome do descanso de tela), com a licença; a home leva as cinco do kit em `assets/`.
- A home confere a paleta (`artifacts/tema/dracula.txt`, `res/values/colors.xml` e `Tema.java`) antes de compilar.

## Sobreposições (`artifacts/overlay/build.sh`, `conferir.py`, `molde-alvo.py`)

- **Só valores literais**, nenhuma referência `@...`: no Android 9 uma sobreposição não enxerga recurso que só ela
  tem, e um id dela cairia no espaço de ids do alvo. Por isso o link não precisa do APK do alvo; quem confere nome e
  tipo contra o alvo é o `conferir.py`.
- **Exceção, os layouts (19B):** um layout copiado do alvo cita recursos do alvo, e o XML da sobreposição é lido no
  espaço de ids do **alvo**. Cada referência tem de sair com o número do alvo: o link ganha um molde (APK só de
  nomes, com os ids do alvo, gerado pelo `molde-alvo.py` a partir do `alvo-ids.txt` versionado) como `-I`,
  `--stable-ids` com esses ids e `--rename-resources-package` com o pacote alvo. Nenhum valor do molde entra no APK
  final, só os números.
- **`minSdk` por sobreposição:** com `--min-sdk-version 28` o `aapt2` funde as configurações ≤ 28 na padrão
  (`drawable-v21` → `drawable`, `hdpi-v4` → `hdpi`), e alvos compilados com o `aapt` antigo têm justamente
  `hdpi-v4` e `v21`. A sobreposição precisa da **mesma** configuração do alvo, senão a do alvo ganha; `minSdk 1`
  desliga a fusão (galeria e players HiSilicon).
- **`versionCode` por sobreposição** (4º campo de `SOBREPOSICOES`): 3 nas quatro que ganharam layout no 19B
  (`zysetting`, `zyfilemanager`, `hivideoplayer`, `zycustomui`), 4 na do `android` (imagens no 19B); as outras
  saem com `VERSAO_CODIGO` e o mesmo md5 de antes.
- **`conferir.py`** (item a item): alvo existe e não há `classes.dex`; todo recurso existe no alvo com o mesmo tipo e
  nome; toda configuração do alvo para o recurso existe na sobreposição; nenhum valor referencia recurso; só cor,
  forma, imagem (`mipmap` também: o gerenciador de arquivos guarda ícones lá) e layout; cada layout é o do alvo
  linha a linha no `aapt2 dump xmltree`, tirando o número da linha e o texto cru `(Raw: "@...")` que o `aapt`
  antigo guarda ao lado de uma referência (o número continua comparado), com só atributos de cor literal
  diferentes. O alvo é achado pelo nome do pacote, não do arquivo.

## `recolorir.py` (imagens do fabricante na paleta Drácula)

- Roda uma vez por firmware, sobre o app desmontado (`apktool d`, que devolve os 9-patch com a borda de marcação);
  a saída entra no git e o `build.sh` não precisa do firmware. Recolore **todas** as variantes que o alvo tem, com o
  mesmo nome e pasta: a sobreposição só ganha na configuração que ela oferece.
- Cada pixel vira a mesma mistura das duas cores-âncora do desenho original, reescrita com as cores Drácula
  correspondentes; o alfa é mantido (ou multiplicado). A borda de 1 px do `.9.png` fica intacta. O destino de uma
  âncora é um token ou, desde o 17A, uma cor literal (o preto do desenho continua preto).
- `.gif` (18): só a paleta de cada quadro muda; quadros, tempos e transparência ficam byte a byte.
- **Âncoras cinzentas são colineares:** um cinza cai no primeiro par que o contém, na ordem da tabela. Por isso os
  tons do corpo vêm antes do preto (teclas do `hipinyinime`, listas do HiMusic).
- O que cada tabela troca, e por quê:

| Tabela | Imagem | Troca |
|---|---|---|
| `zysetting` | moldura de foco das listas (`item_focus*`) | branco → rosa |
| | 4 cartões da tela principal (`pt_*`) | teal → linha, ícone branco → texto |
| | chave Ligado/Desligado (texto pintado) | verde → verde, teal → linha |
| | janela de senha do Wi-Fi | painel preto → linha; campo em foco verde → comentário (o texto do campo é branco fixo); parado branco 20 % → fundo |
| | botões da janela de senha | parado preto com fio branco → fundo com fio comentário; em foco branco → rosa (o texto em foco vem de `color/button_text`, que vira fundo) |
| | modo de imagem e brilho (16A) | miolo laranja do escolhido → rosa |
| | atualização automática (`systemupdate_tip`) | botões em foco azuis → comentário (texto branco 4,7:1) |
| `zybluetooth` | a mesma moldura e a mesma chave do ZYSetting | |
| `zyfilemanager` (`rgtp_ui=1`) | ícones da lista | teal escuro → comentário (3,0:1 no fundo) |
| | "carregando" | verde → rosa (o rosa marca o que está em andamento) |
| `higallery` | miniatura escolhida | moldura branca com brilho azul → rosa |
| `zyspeakermodel` (17A) | fundo (`pt_bg`, 1ª imagem do FlyBanner) | teal → fundo, desenho branco → texto, o preto do celular fica |
| | botões em foco | círculo azul → rosa, ícone branco → fundo (6,0:1; parados ficam brancos) |
| `ijkplayer`, `hivideoplayer` (17A) | barra de controle e botão em foco | azul-marinho translúcido → fundo/linha/comentário; brilho azul → rosa; ícone → texto; a sombra preta fica |
| `himusic` (17A) | fundo em degradê | azul-marinho, azul-claro, laranja e vermelho → fundo, comentário e linha (texto branco 4,7:1 no mais claro) |
| | moldura de foco (9-patch), ponto da barra | azul → rosa; brilho → texto |
| `hipinyinime` (18) | teclas | corpo parado → linha (rótulo branco 9,2:1), sombra preta fica; em foco → comentário (4,7:1) e a sombra vira moldura rosa; Shift aceso verde → verde |
| | barra de candidatos (pinyin) | branca → linha, fio de cima → comentário; candidato em foco laranja → rosa |
| `zycustomui` (18) | pareamento do controle (GIF de tela cheia) | fundo azul → fundo, linha e comentário (texto branco 4,7:1); brilho dos anéis → roxo; controle, branco e LED ficam |
| `android` (19B) | imagens do framework que o HiMusic usa (só `drawable-xhdpi`, doc 48 §12.7) | tocar/pausar: ícone branco → texto; janelas `Theme.Dialog` (preto 90 % com fio `#505050` → fundo com fio comentário) e `Theme.Holo.Dialog` (`#282828` → fundo, realce → linha) |

## `gerar-previa*.py` (folhas de prévia das sobreposições)

- A docstring do módulo é a ajuda (`sys.exit(__doc__)`): fica no código.
- Os geradores de bloco carregam o `gerar-previa.py` como módulo só pelas funções (o `main()` dele só roda como script).
- Valores de fábrica vêm do `aapt2 dump resources` dos APKs do firmware (doc 48). Telas: 1920×1080 a 0,4; dp → px
  na densidade 1,5; o 9-patch é hdpi, desenhado no tamanho de tela e escalado junto.
- O que a sobreposição **não** muda fica com o valor de fábrica na prévia (`ripple_material_light`, o
  `colorAccent` do Material claro, setas e sinal de Wi-Fi), para a prévia não prometer o que o aparelho não mostra.
- O título sem cor no código usa a do tema escuro (`primary_text_dark` → `bright_foreground_dark` →
  `background_light` do framework, que a do `android` troca).

## Tema (`artifacts/tema/*.py`)

- `gerar-fundo.py`: pontilhado ordenado (Bayer 8×8) para o gradiente não ter faixas sem aleatoriedade; o arco tem
  3 px porque no projetor 2 px somem; PNG escrito à mão (só `zlib` e `struct`).
- `gerar-marca.py`: `logo-boot.jpg` sai já distorcida pelos 4 pontos, porque o carregador mostra a imagem antes de o
  keystone existir. Cantos de `persist.sys.keystone.{lt,rt,lb,rb}` (y conta de baixo para cima); sem eles, os do
  projetor do dono em 2026-10-31. `PFL_MARCA_SAIDA` grava fora de `artifacts/` (o `pfl7560-marca.sh` gera numa
  pasta temporária, para não sobrescrever os versionados com os cantos de outro aparelho). O `bootanimation.zip` é
  `ZIP_STORED` (o Android exige zip sem compressão) e com data fixa. Fundo "um roxo bem escuro, quase desligado" e
  o nome no roxo a ~80 % (pedido do dono, 2026-10-31); desenho em 2× e redução para a borda do texto sair limpa.
- `gerar-icones.py` (app): sem emoji, formas simples na paleta; supersampling; saída determinística.

## App `com.pfl7560.verificar` (Java)

- `VerificarActivity`: grava `pedir-verificacao` na pasta privada do app e fecha em 3 s; o vigia root confere que o
  dono do arquivo é o dono da pasta. Sem permissão nenhuma: só este app grava ali.
- `WifiActivity`: a tela de Wi-Fi do sistema; se não resolver, a tela escondida do fabricante
  (`com.zhiying.settings`, aberta na parede em 2026-10-30); se nada abrir, a mensagem.
- `Descanso`: a cada minuto o conjunto desliza para outro lugar (transição de 3 s, 80 % da folga) para não ficar
  parado; um `Handler` de 1 tick por minuto; nome a 160 px em 1920, como na imagem de boot. Pede luz a 10 %
  (`descanso-inicio`) e a volta (`descanso-fim`) numa thread só, para o início chegar sempre antes do fim; sem o
  pedido, a luz só não muda.

## Home `com.pfl7560.home` (Java)

- **Nunca trava o boot:** o `onCreate` só monta a View; apps, rede e temperatura são lidos numa thread à parte;
  exceção vira fileira vazia ou campo omitido. Um desenho que falha deixa o fundo e o próximo quadro tenta de novo.
- **`Guarda`:** cada queda é anotada antes de o Android matar o processo (`commit`, não `apply`). Duas quedas em 2
  minutos = entrega a tela ao launcher de fábrica (`WizardAciticity`, que tem HOME, logo e é exportada) e sai.
- **`Desenho` é Java puro**, o mesmo no aparelho (`PintorCanvas`) e nas prévias do PC (`PintorJ2D`). Direção:
  painel de instrumento, calmo; uma cor de destaque (rosa no foco: anel de 5 px, ícone rosa, cartão cheio); roxo só
  nos títulos de grupo e nos dois pontos do relógio; sem sombra, sem gradiente nos cartões, sem animação. Exceção:
  o monograma do app sem desenho usa um dos 5 acentos, estável pelo pacote (bloco 13B). Grade de 24 px de vão,
  margens de 112 px; o topo das maiúsculas da Plex Mono (0,698 em) em y = 136.
- `Pintor`: ângulos em graus, 0 = 3 horas, sentido horário (o do Android); o Java2D conta no anti-horário e o
  `PintorJ2D` converte. Fonte faltando cai na do sistema, nunca quebra.
- `Icones`: grade 64×64, traço de 4/64 com pontas redondas, nada de imagem baixada. O desenho do app sai do nome do
  pacote, nunca do ícone dele; a ordem das regras importa (o alto-falante Bluetooth antes das genéricas, o Cast antes
  do vídeo). A cor do monograma usa `String.hashCode`, especificado pela linguagem: igual em qualquer JVM.
- `Abridor`: os mesmos intents do launcher de fábrica V1.0.0.9 (doc 45 tem a fonte de cada um); entrada de vídeo
  como `MainActivityBx.selectHSSource` (NLSourcePlayer com o extra int `SourceName`). Nunca lança exceção.
- `Leitor`: a lista negra de apps é a do launcher de fábrica (`RGTPLauncher`, `AppUtils.<clinit>`, doc 43 §6) mais
  os nossos; os desligados pelo dono ficam em `Modelo.OCULTOS`, para sumirem mesmo que voltem a ligar. O Android 9
  esconde o SSID do `WifiInfo` sem permissão de localização; o `extraInfo` da rede ativa ainda o traz. A
  temperatura é `zysys.env_temp` (o `gtt1`, no bloco do LED, doc 40 §3), `null` se o SELinux não deixar ler.
  `SystemProperties.get` por reflexão (API escondida, liberada para targetSdk 28). USB-C: `zysys.typec_count > 0`
  ou `zysys.source.typec1` (o V1.0.0.1 não tem nenhuma).
- **Luz:** a home grava só os dígitos no arquivo `luz` da pasta dela; o root aplica e publica o valor em
  `vendor.pfl7560.luz`, que a home relê depois de um tempo. O root não escreve na pasta do app (revisão de
  segurança). Sem aviso no OK: o nível marcado no painel já mostra (pedido do dono).
- `Modelo`: hora em 24 h e data em português sem depender do idioma do aparelho; `comUsbC = false` mostra só as
  duas HDMI.
- `Tema`: os 11 valores da paleta; dois derivados por contraste (texto secundário `#BEBEBD`: o comentário puro dá
  3,0:1 no fundo, este dá 7,7:1).
- `Previa` (PC): hora e data fixas; apps do firmware V1.0.0.9 com MAIN+LAUNCHER, menos a lista de exclusão; "MinhaRede" e os apps "(exemplo)" são de exemplo; 59 °C é a média do sensor do LED em regime (doc 40). Também confere
  a navegação do D-pad.
