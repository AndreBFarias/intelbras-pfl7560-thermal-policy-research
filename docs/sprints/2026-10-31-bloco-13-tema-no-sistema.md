# Bloco 13 - Drácula no sistema do fabricante e nos ícones da home (2026-10-31)

Pedido do dono, depois de ver a home nova no projetor:
- "os svgs não combinam com o tema" (ícones dos apps na fileira Apps);
- "Esse sim e não tão fora do tema" (o aviso "Dispositivo conectado. Deseja abrir HDMI1?");
- "Dentro das configs segue o tema antigo";
- "Independente do fabricante. Se ele tivesse feito o trabalho direito eu não teria buildado e pago o preço de
  três projetor."

O tema vale para **tudo o que aparece na tela**. A paleta e as fontes são as do bloco 10
(`artifacts/tema/dracula.txt` e `artifacts/tema/README.md`, com os dois tons derivados por contraste).

## Fatos do aparelho (2026-10-31)

- `/vendor/overlay/` existe (`root:shell 0755`, rótulo `u:object_r:vendor_overlay_file:s0`) e já tem
  sobreposições de fábrica (`SysuiDarkTheme`, `DisplayCutoutEmulation*`). O `cmd overlay list` funciona.
- Apps do fabricante:

  | Pacote | Caminho |
  |---|---|
  | `com.zhiying.settings` | `/system/app/ZYSetting` (Configurações, tela de Wi-Fi, e o aviso de HDMI: janela `SYSTEM_ALERT` desse pacote) |
  | `com.newlink.nlprovision` | `/system/priv-app/NLProvision` (o aviso "Temperatura anormal") |
  | `com.android.tv.settings` | `/system/priv-app/TvSettings` |
  | `com.newlink.filemanager` | `/system/app/ZYFileManager` |
  | `com.hisilicon.higallery` | `/system/app/HiGalleryL` |
  | `com.newlink.nlsource` | `/system/app/NLSourcePlayer` |

- App nosso só entra como app do sistema em `/vendor/app` (o `pm install` recusa). A sobreposição vai em
  `/vendor/overlay/<Nome>/<Nome>.apk`.
- A home nova (`com.pfl7560.home`) é a tela inicial pela prop `vendor.newlink.launcher.package` no
  `/vendor/build.prop`. Foi provado no aparelho, sem perda no boot (`evidencias/home-troca/`).

## 13A - Sobreposições (RRO) em Drácula, sem alterar app do fabricante

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-13a`, branch `bloco-13a/overlays`. Arquivos:
`artifacts/overlay/**` (novo) e `docs/research/48-tema-no-sistema.md`.

1. **Pesquisa:** extraia do firmware (`firmware/Software PFL7560.zip`, com os scripts da pesquisa P) os
   recursos de cada app alvo.
   - Use `aapt2 dump resources` ou o apktool já usado. Mapeie `colors`, `styles` e `themes`, os `drawable`
     de fundo, cartão, botão, seleção e foco (inclusive os 9-patch) e os layouts das telas que o dono vê.
   - Prioridade 1, as que ele citou: `com.zhiying.settings`, com as Configurações, a tela de Wi-Fi e o aviso
     "Deseja abrir HDMI1?" (ache a classe e o layout dele).
   - Prioridade 2: o aviso "Temperatura anormal" do `com.newlink.nlprovision`.
   - Prioridade 3: os diálogos e o Toast do framework (`android`), com muito cuidado (ver o item 4).
   - Escreva no doc 48 o mapa de cada alvo: recurso, valor de fábrica e valor Drácula.
2. **Uma sobreposição por pacote alvo.** Só recursos (sem código): `AndroidManifest.xml` com
   `<overlay android:targetPackage="..." android:priority="..."/>`, e `res/values/colors.xml`, `styles` e os
   `drawable` (XML vetorial ou shape; 9-patch novo só se for preciso). Gerado por `artifacts/overlay/build.sh` com
   `aapt2 link --manifest ... -I android.jar` (e o APK do alvo com `-I` quando referenciar recursos dele) e
   assinado com uma chave própria estável.
   - O foco do controle em rosa e os botões "Sim"/"Não" no estilo da home: cartão `linha`, foco rosa, texto
     `texto`.
   - Textos e layout do fabricante ficam como estão: troca só cor, fundo e forma.
3. **Instalação**, só documentada (o coordenador integra ao kit):
   - pasta 0755 e arquivo 0644, root, rótulo `vendor_overlay_file`;
   - **não estática** (sem `isStatic`) nos testes: ligada com `cmd overlay enable <pacote-da-overlay>` e
     desligada com `disable`;
   - depois de provada, pode virar estática.
4. **Segurança, sem exceção.** Uma sobreposição errada do framework pode derrubar a interface no boot.
   - A do `android` só depois de as dos apps estarem provadas, e só com cores e estilos de diálogo. Nada de
     dimensões nem de layouts do framework.
   - Doc 48 com a saída de emergência: o `adbd` sobe antes da interface. `adb root`, depois
     `mount -o rw,remount /vendor`, `rm -rf /vendor/overlay/<Nome>` e reboot. E sempre o
     `cmd overlay disable` antes.
   - Confira com `aapt2 dump resources` que cada recurso sobreposto existe no alvo com o **mesmo tipo**.
5. **Provas no PC:** o `build.sh` gera tudo do zero; `apksigner verify`; o `aapt2 dump` de cada sobreposição
   mostra o `targetPackage` certo e só recursos que existem no alvo (um script confere isso contra o APK do
   alvo extraído); uma folha de prévia com as cores e formas antes e depois por tela (desenhada com os valores,
   não precisa ser captura). Nada no aparelho.

## 13B - Ícones dos apps na home em Drácula

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-13b`, branch `bloco-13b/home-icones`. Arquivos:
`artifacts/home/**` (só) e uma linha no doc 45.

- A fileira **Apps** deixa de usar o ícone original de cada app (`loadIcon`). Todo app ganha um ícone desenhado
  no código, no traço da home (`Icones.java`, contorno 2 px, `texto` ou o acento do tema), sobre o cartão
  `linha`.
- Pacotes conhecidos ganham um desenho próprio, por função: arquivos (`com.newlink.filemanager`), vídeo
  (`VideoPlayer`), música, Cast e espelhamento (`iOSCast`, `com.newlink.cast`), documentos (Office,
  `com.mobisystems.*`), alto-falante Bluetooth, galeria, navegador, loja e jogo. Use a lista que estiver no
  aparelho e na prévia.
- O resto recebe um monograma: a 1ª letra num círculo com a cor do tema, escolhida de forma estável pelo nome
  (`roxo`, `rosa`, `ciano`, `verde`, `laranja`).
- `versionCode` + 1, mesmo `build.sh` e mesma chave. Prévias novas em `artifacts/home/previa/`, abertas e
  conferidas, com a fileira Apps cheia.
- Nada no aparelho. O coordenador copia o APK para o kit e roda o script de md5.

## Comum

- Nenhum agente fala com o projetor. Nada de `git add -A`, `.` ou `--all`; commits pequenos sem linha de
  atribuição; push do branch no fim. Docs em pt-BR com acento; zero emoji. Use a skill `hallmark` no que for
  desenho, mas a paleta do bloco 10 manda.
- Relatório no schema: feito, provas, commits, provisorio, desvios, pendente.
