# nl_tela - telas da suíte de boot geradas no aparelho (bloco 9A)

Programa ARM (32 bits, NDK r27c) que escreve as telas da suíte de boot (abertura, etapas, final e
resumo) como PNG 1920x1080 RGB, com os valores do momento, para a galeria abrir. Contrato C-tela em
`docs/sprints/2026-10-30-bloco-9-suite-de-boot.md`; exemplos de `campos.txt` em
`tests/fixtures/tela/`.

Fonte: `nl_tela.c` (C, um arquivo) + `terceiros/stb_truetype.h` (v1.26) e
`terceiros/stb_image_write.h` (v1.16), de `nothings/stb`, domínio público ou MIT, sem alteração
(só um bloco de origem no topo). Fontes: `pendrive-autorun/fontes/` (IBM Plex Sans Condensed
Regular, SemiBold e Bold; IBM Plex Mono Regular e SemiBold; `OFL.txt`, a licença, com o "(c)" em
ASCII). Binário do aparelho: `nl_tela` (esta pasta) e a mesma cópia em `pendrive-autorun/nl_tela`
(o kit confere o md5 dela e das fontes antes de copiar).

## Compilar

    # aparelho (ARM): so libc, libm e libdl do Android. Da RAIZ do repositorio, com o caminho
    # relativo: o assert da stb_truetype grava o caminho do cabecalho no binario
    ~/Android/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang \
        -O2 -Wall -o artifacts/tela/nl_tela artifacts/tela/nl_tela.c -lm
    cp artifacts/tela/nl_tela pendrive-autorun/nl_tela
    bash tests/atualizar-md5-kit.sh      # regrava a lista de md5 do kit

    # PC (harness): o MESMO .c
    cc -O2 -Wall -Wextra -o nl_tela artifacts/tela/nl_tela.c -lm

A compilação é reprodutível (o mesmo .c, compilado da raiz como acima, dá o mesmo md5; de
dentro de `artifacts/tela/` o caminho gravado muda e o md5 também). O `tests/test-tela.sh`
recompila com o NDK, se houver, e exige o binário versionado.

## Uso

    nl_tela aviso|resumo <campos.txt> <saida.png> <dir_fontes>

Sai 0 ok; 1 erro (campos.txt ausente, maior que 64 KiB, linha de mais de 1024 bytes, byte zero,
campo inválido, sem fonte, falha ao gravar); 2 uso errado. Em erro não deixa PNG.

`campos.txt`: uma `chave=valor` por linha, ASCII puro. Texto não ASCII vai como `\uXXXX` (BMP),
quebra de linha como `\n`, a barra como `\\`. Linha vazia ou começada por `#` é ignorada; chave
desconhecida (ou do outro modo) também; CRLF serve.

| modo | chaves |
| --- | --- |
| `aviso` | `etapa` (alto, esquerda), `canto` (alto, direita), `titulo` (até 3 linhas), `texto` (parágrafo), `passo=nome\|fila,agora,feito[\|ok,corrigido,atencao,pendente]` (até 6), `rodape`, `tom=normal\|alerta` (alerta pinta o título na cor de atenção) |
| `resumo` | `titulo`, `destaque`, `destaque_estado=ok\|corrigido\|atencao`, `canto`, `grupo` (até 4), `item=rotulo\|valor\|ok,corrigido,atencao,info,pendente` (até 6 por grupo), `dica` (até 3), `rodape` |

`titulo` é obrigatório. Passou do limite (grupos, itens, passos, dicas), item antes do primeiro
grupo ou estado desconhecido: sai 1 com a linha na mensagem.

Decisões onde o contrato deixou escolha:

- Byte não ASCII cru (quem escreveu esqueceu o `\uXXXX`): vira `?`, com aviso em stderr, e a tela
  sai assim mesmo (não vale perder o resumo inteiro por um acento). `\u0000` e substitutos
  (`\uD800`-`\uDFFF`) também viram `?`.
- Texto que não cabe: o valor de item diminui de 34 até 28 px; título e destaque do resumo
  diminuem juntos de 72 até 56 px; o resto (e o que mesmo assim não coube) é cortado com
  reticências e avisado em stderr como `nl_tela: truncado: <campo>: "..."`. Nunca passa da margem.
- Fonte: falta uma das cinco em `<dir_fontes>` -> usa a reserva do sistema (`/system/fonts`:
  `Roboto-Regular.ttf` para Regular, `Roboto-Bold.ttf` para SemiBold e Bold, `DroidSansMono.ttf`
  para as Mono), com aviso; sem as duas, sai 1. A reserva também empresta glifo que a Plex não
  tem; sem glifo em nenhuma, `?`. `NL_TELA_SISTEMA=<pasta>` troca a pasta da reserva (harness).

## Visual

Paleta Drácula (bloco 10B; tokens em `artifacts/tema/dracula.txt`, papel de cada um em
`artifacts/tema/README.md`): fundo `#282A36`, cartões `#44475A` (linha) com cantos de 10 px, texto
`#F8F8F2`, secundário `#B4BCCF` (o comentário `#6272A4` clareado, por contraste), fio `#6272A4`; ok
`#50FA7B`, corrigido `#FFB86C`, atenção `#FF5555` sobre o fundo e `#FE7674` sobre o cartão, info
`#8BE9FD`, pendente `#F1FA8C` (ponto vazado); etapa do aviso e título de grupo em roxo `#BD93F9`; o
passo em andamento tem contorno rosa `#FF79C6`. Margem lateral 110 px.
Mistura de cor em luz linear (sRGB correto) para o antisserrilhado.

- `aviso`: linha de cima Mono 26 (etapa e canto), título Bold 100, texto Regular 40 secundário (até
  1400 px de largura), passos numa fileira de cartões acima do rodapé (4 colunas; 5 ou 6 passos,
  uma por passo), com número, estado (ponto + palavra) e nome SemiBold 34 em até 2 linhas; o passo
  em andamento tem contorno rosa de 3 px. Rodapé Mono 24.
- `resumo`: título + destaque Bold 72 na mesma linha (destaque na cor do estado), canto Mono 24 a
  direita na mesma linha de base; quatro cartões de grupo com a mesma altura de linha
  (rotulo do grupo SemiBold 30 espaçado, em roxo; por item: fio, rotulo Regular 26 secundário com o ponto
  de estado de 12 px a direita, valor Mono SemiBold 34 na cor do estado); faixa de dicas (Regular
  28, marcador na cor de atenção) logo abaixo dos cartões; rodapé Mono 24. A altura da linha se ajusta ao espaço
  (até 116 px; com 6 itens e 3 dicas, cerca de 88).

Diferenças em relação ao texto do C-tela, por legibilidade: o título do `aviso` é 100 px (o canvas
usava 104; o 72 do contrato é o do resumo); o canto do resumo é Mono 24 (o canvas usava 28), para
sobrar linha para título + destaque; a margem de cima e de baixo do resumo é 72 / 66 px, para
caberem 6 itens e 3 dicas.

## Provas

- `bash tests/test-tela.sh` (no `make check-kit`): compila no host sem aviso, gera os 9 exemplos
  de `tests/fixtures/tela/` (abertura tomada, abertura pendrive, etapa de temperatura, final do
  pendrive, alerta; resumo com os 19 itens do dono: tudo certo, uma correção, atenções com 3 dicas,
  pendentes) sem nenhum aviso em stderr e confere cada PNG em python puro (assinatura, CRC, IHDR
  1920x1080 8 bits RGB, dados completos, nenhum pixel fora do fundo nas margens: 110 px dos lados,
  50 em cima e embaixo). Depois: o caso no limite e textos longos demais (cortam, avisam, não
  passam da margem), usos e entradas inválidas (saem 2 e 1, sem PNG), escapes (`\u00e7`,
  maiúsculas, `\u0000`, substituto), byte cru, chave desconhecida, CRLF e comentário (mesmo PNG),
  fonte ausente (reserva ou sai 1), TTF corrompido ou truncado (o diretório de tabelas é
  conferido antes da stb_truetype, que não confere offset; truncado sem reserva sai 1, com
  reserva cai nela), saída que é uma pasta (sai 1 sem apagá-la), binário ARM igual nas duas
  pastas e igual ao recompilado do .c (se houver NDK).
- PNG de exemplo para olhar: `tests/saida/telas/` (fora do git), gerados a cada execução.

## No aparelho

Roda no projetor com a suíte desde o bloco 9A (a suíte está em `docs/research/44-suite-de-boot.md`). O que
ainda falta conferir no aparelho está em [`docs/ESTADO.md`](../../docs/ESTADO.md).
