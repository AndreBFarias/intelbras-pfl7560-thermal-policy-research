# Bloco 10 - Home nova e tema Drácula (2026-10-31)

Pedido do dono: "disparar dois opus pra criar uma nova home e um novo tema pra background e layout pra tudo.
Gosto da paleta drácula theme". São dois agentes Opus em paralelo, com arquivos disjuntos e este contrato em
comum. O coordenador integra ao kit (md5, instalação) e testa no aparelho com o dono.

## Contrato comum: a paleta Drácula (oficial, draculatheme.com/contribute)

| Token | Hex | Uso |
|---|---|---|
| `fundo` | `#282A36` | fundo de tudo |
| `linha` | `#44475A` | cartões, seleção, linhas |
| `texto` | `#F8F8F2` | texto principal |
| `comentario` | `#6272A4` | texto secundário, rótulos |
| `ciano` | `#8BE9FD` | informação |
| `verde` | `#50FA7B` | ok |
| `laranja` | `#FFB86C` | corrigido |
| `rosa` | `#FF79C6` | foco e destaque (o item selecionado com o controle) |
| `roxo` | `#BD93F9` | acento da marca, títulos de grupo |
| `vermelho` | `#FF5555` | atenção e erro |
| `amarelo` | `#F1FA8C` | pendente |

Mais duas regras:
- **Fontes:** IBM Plex Sans Condensed (títulos e rótulos) e IBM Plex Mono (valores), já no kit em
  `pendrive-autorun/fontes/` (OFL). Nenhuma fonte nova.
- **Texto:** maiúscula no início de frase e de rótulo, pedido do dono, igual ao `nl_tela`. Português com acento
  na tela. Zero emoji.

O tema 10B grava esta tabela em `artifacts/tema/dracula.txt`, uma linha `token=#RRGGBB` por cor. A home 10A
copia os mesmos valores para o `colors.xml` dela. Os dois conferem que os valores batem com esta tabela.

## Fatos do aparelho (medidos em 2026-10-30)

- O HOME do sistema hoje resolve para `com.newlink.nlprovision/.MainActivity`, um assistente que repassa ao
  launcher `com.newlink.hisilauncher` (`/system/app/RGTPLauncher`).
- A pesquisa P (doc 43 §6) leu o launcher de fábrica. A tela inicial é escolhida pelo `WizardAciticity` por
  props de estilo, e os blocos dela são pacotes fixos. A lista de apps vem de
  `queryIntentActivities(MAIN+LAUNCHER)`.
- O `pm install` deste firmware recusa qualquer app de fora. App nosso só entra como app do sistema em
  `/vendor/app/<Nome>/<Nome>.apk`. O app `com.pfl7560.verificar` já foi provado assim: `flags=[ SYSTEM ]`.
- O projetor é 1920x1080, controle remoto com D-pad, OK, BACK e HOME, sem toque.
- As entradas são HDMI 1, HDMI 2 e USB-C. As telas de Wi-Fi, Bluetooth e Configurações são do fabricante
  (`com.zhiying.settings`; Wi-Fi em `com.zhiying.settings/.network.WifiSettingActivity`, ver
  `artifacts/app/`).
- O firmware oficial V1.0.0.9 está em `firmware/Software PFL7560.zip` (Git LFS). Os scripts que a pesquisa P
  usou para extrair e desmontar APKs estão em
  `/tmp/claude-1000/-home-andrefarias-Desenvolvimento-intelbras-pfl7560-thermal-policy-research/a20b0f13-e9aa-4144-beb6-53924ad7357d/scratchpad/pesquisa-scripts/`
  (`extrai.py`, `Desmonta.java`, `dis.py`), com notas em `.../scratchpad/pesquisa/`. Extraia para uma pasta
  nova dentro do scratchpad e apague os brutos no fim.

## 10A - Home nova (`com.pfl7560.home`)

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-10a`, branch `bloco-10a/home`. Arquivos só em
`artifacts/home/` (novo) e `docs/research/45-home-pfl7560.md`.

1. **Pesquisa curta**, escrita no doc 45 com fonte e confiança, como no doc 43. Leia o `RGTPLauncher` e o
   `nlprovision` do firmware e descubra:
   - o intent exato com que o launcher de fábrica abre HDMI 1, HDMI 2 e USB-C (`HiTvPlayer` /
     `HiExternalTvInput`?), Bluetooth, Wi-Fi, Configurações, Espelhamento (`Miracast`/`HBCastNew`) e o seletor
     de imagem/projeção;
   - se o `nlprovision` como HOME faz algo além de repassar (primeira configuração?) que a home nova não pode
     quebrar.
   Sem resposta firme, use o caminho mais conservador e registre.
2. **App** no mesmo padrão do `artifacts/app/`: Java, sem Gradle, `build.sh` com o SDK local, chave própria
   estável, minSdk 28 e targetSdk 28, sem permissões perigosas.
   - Atividade `HOME` + `DEFAULT` + `LAUNCHER` (`android:launchMode="singleTask"`, `stateNotNeeded`).
   - 1920x1080, só D-pad: foco visível em rosa, nada que dependa de toque.
3. **Layout**, decidido com a skill `hallmark` (o CLAUDE.md manda; o dono pediu "bonita, organizada e limpa").
   Precisa ter:
   - relógio e data grandes;
   - uma fileira de **Entradas** (HDMI 1, HDMI 2, USB-C);
   - uma fileira de **Atalhos**: Verificar projetor (abre `com.pfl7560.verificar/.VerificarActivity`), Wi-Fi,
     Bluetooth, Imagem, Configurações e Espelhamento;
   - uma fileira de **Apps**: `MAIN+LAUNCHER` sem os nossos nem os de sistema inúteis; use a lista negra do
     launcher de fábrica (doc 43 §6) e ordene pelo nome;
   - uma linha discreta de estado: Wi-Fi (nome da rede ou "Sem rede"), temperatura do LED se legível sem
     root, e "Última verificação" se houver como ler sem root (senão, omita).
   - Ícones desenhados no código (vetor ou `Canvas`), no traço do tema. Nada de ícone baixado.
4. **Segurança**, sem exceção:
   - a home nunca é a única. A de fábrica continua instalada, e a nossa só vira padrão com
     `cmd package set-home-activity com.pfl7560.home/.HomeActivity`;
   - volta com `cmd package set-home-activity com.newlink.nlprovision/.MainActivity`;
   - documente os dois comandos no README do app e no doc 45;
   - a home nunca trava o boot: sem trabalho pesado no `onCreate`, e lista de apps em segundo plano;
   - exceção capturada vira fileira vazia, nunca um crash em laço.
5. **Prova**:
   - `artifacts/home/build.sh` gera o APK do zero; `apksigner verify` passa;
   - `aapt2 dump badging` mostra a atividade com HOME;
   - capturas de tela 1920x1080 da home renderizada no PC, gravadas em `artifacts/home/previa/`. Use
     layoutlib se for viável. Senão, um renderizador Java do mesmo layout (Canvas → PNG) que use o MESMO código de
     desenho do app. Se nenhum dos dois der, descreva e entregue um mock HTML fiel em
     `artifacts/home/previa/home.html`.
   Não instale nada no aparelho.

## 10B - Tema Drácula para "tudo o que é nosso"

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-10b`, branch `bloco-10b/tema`. Arquivos:
`artifacts/tema/` (novo), `artifacts/tela/nl_tela.c` (só as cores e o que o tema pedir de layout),
`artifacts/app/` (ícones, banners e cores do app Verificar/Wi-Fi), `pendrive-autorun/kit/*.png` (as telas
estáticas do kit, se forem regeradas por script: ache o gerador; se não houver, NÃO as toque e registre),
`tests/test-tela.sh`, `tests/fixtures/tela/`.

1. `artifacts/tema/dracula.txt` (a tabela acima) e `artifacts/tema/README.md`: o que cada token significa em
   cada tela.
2. **Telas da suíte (`nl_tela`) em Drácula**:
   - fundo `fundo`, cartões `linha`, texto `texto`/`comentario`;
   - estados: ok `verde`, corrigido `laranja`, atenção `vermelho`, info `ciano`, pendente `amarelo`;
   - título de grupo em `roxo`;
   - a tela de alerta usa `vermelho` com moderação.
   Ajuste o layout só no que o tema exigir. Mantenha o contrato C-tela (campos e modos), zero truncamento nos
   exemplos do dono e a regra das maiúsculas já implementada. Recompile o binário ARM com o comando do
   `artifacts/tela/README.md`, copie para `pendrive-autorun/nl_tela` e rode `bash tests/atualizar-md5-kit.sh`.
3. **Plano de fundo:** um PNG 1920x1080 em `artifacts/tema/fundo-dracula.png`, gerado por script em
   `artifacts/tema/gerar-fundo.py` (Python puro, `-I`, sem dependência fora da biblioteca padrão; reprodutível).
   Sóbrio e sem texto: um gradiente sutil `fundo` → `linha` com um detalhe em `roxo`. Serve para a home 10A e
   como papel de parede. Descubra e documente como pôr como papel de parede do sistema (por exemplo
   `cmd wallpaper` ou `WallpaperManager` pelo app). Não aplique.
4. **App Verificar/Wi-Fi** com ícones e banners em Drácula: o gerador `gerar-icones.py` já existe; mude as cores
   para os tokens e reconstrua o APK com o `build.sh`, mesma chave e mesmo `versionCode` + 1 em
   `VERSAO_CODIGO` E em `APP_VERSION_CODE` do `pendrive-autorun/newlink_update.sh`, que o harness confere. Copie
   o APK para `pendrive-autorun/pfl7560.apk` e rode o script de md5.
5. **Canvas** para o dono ver: atualize as prévias em `tests/saida/telas/` (geradas pelo `test-tela.sh`) e
   gere uma folha de contato `artifacts/tema/previa/telas.png` com as telas da suíte lado a lado. **Não publique**
   artifact: o coordenador mostra.
6. **Prova**: `make check`, `make check-kit` e `make check-fix` verdes; `shellcheck`; os PNG abertos e
   conferidos por você, para que nada fique cortado nem tenha contraste baixo (texto `comentario` sobre `fundo`
   é o pior caso: confira o contraste e, se ficar abaixo de 4,5:1 em texto pequeno, use `texto` com opacidade
   ou um tom acima, registrando).

## Comum aos dois

- Nenhum agente fala com o projetor (sem adb). Nada de `git add -A`, `.` ou `--all`; commits pequenos sem
  linha de atribuição; push do branch no fim.
- Kit em `pendrive-autorun/`: ASCII puro, md5 só pelo script. Docs em pt-BR com acento.
- Relatório no schema: feito, provas, commits, provisorio, desvios, pendente.

## Estado (bloco 20, 2026-10-31)

10A e 10B integrados (merges `9f3eeba` e `67619ed`). A home MeowCast (`versionCode` 4) é a tela inicial do
projetor do dono pela linha `vendor.newlink.launcher.package` no `/vendor/build.prop`, que o kit grava: o
`set-home-activity` previsto aqui não vence o `nlprovision` (prioridade 29 no HOME; doc 45). Estado em [ESTADO.md](../ESTADO.md).
