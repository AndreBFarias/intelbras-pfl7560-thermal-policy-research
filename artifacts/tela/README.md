# nl_tela - telas da suite de boot geradas no aparelho (bloco 9A)

Programa ARM (32 bits, NDK r27c) que escreve as telas da suite de boot (abertura, etapas, final e
resumo) como PNG 1920x1080 RGB, com os valores do momento, para a galeria abrir. Contrato C-tela em
`docs/sprints/2026-10-30-bloco-9-suite-de-boot.md`; exemplos de `campos.txt` em
`tests/fixtures/tela/`.

Fonte: `nl_tela.c` (C, um arquivo) + `terceiros/stb_truetype.h` (v1.26) e
`terceiros/stb_image_write.h` (v1.16), de `nothings/stb`, dominio publico ou MIT, sem alteracao
(so um bloco de origem no topo). Fontes: `pendrive-autorun/fontes/` (IBM Plex Sans Condensed
Regular, SemiBold e Bold; IBM Plex Mono Regular e SemiBold; `OFL.txt`, a licenca, com o "(c)" em
ASCII). Binario do aparelho: `nl_tela` (esta pasta) e a mesma copia em `pendrive-autorun/nl_tela`
(o kit confere o md5 dela e das fontes antes de copiar).

## Compilar

    # aparelho (ARM): so libc, libm e libdl do Android
    ~/Android/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang \
        -O2 -Wall -o nl_tela nl_tela.c -lm
    cp nl_tela ../../pendrive-autorun/nl_tela
    bash ../../tests/atualizar-md5-kit.sh      # regrava a lista de md5 do kit

    # PC (harness): o MESMO .c
    cc -O2 -Wall -Wextra -o nl_tela nl_tela.c -lm

A compilacao e reprodutivel (o mesmo .c da o mesmo md5).

## Uso

    nl_tela aviso|resumo <campos.txt> <saida.png> <dir_fontes>

Sai 0 ok; 1 erro (campos.txt ausente, maior que 64 KiB, linha de mais de 1024 bytes, byte zero,
campo invalido, sem fonte, falha ao gravar); 2 uso errado. Em erro nao deixa PNG.

`campos.txt`: uma `chave=valor` por linha, ASCII puro. Texto nao ASCII vai como `\uXXXX` (BMP),
quebra de linha como `\n`, a barra como `\\`. Linha vazia ou comecada por `#` e ignorada; chave
desconhecida (ou do outro modo) tambem; CRLF serve.

| modo | chaves |
| --- | --- |
| `aviso` | `etapa` (alto, esquerda), `canto` (alto, direita), `titulo` (ate 3 linhas), `texto` (paragrafo), `passo=nome\|fila,agora,feito[\|ok,corrigido,atencao,pendente]` (ate 6), `rodape`, `tom=normal\|alerta` (alerta pinta o titulo na cor de atencao) |
| `resumo` | `titulo`, `destaque`, `destaque_estado=ok\|corrigido\|atencao`, `canto`, `grupo` (ate 4), `item=rotulo\|valor\|ok,corrigido,atencao,info,pendente` (ate 6 por grupo), `dica` (ate 3), `rodape` |

`titulo` e obrigatorio. Passou do limite (grupos, itens, passos, dicas), item antes do primeiro
grupo ou estado desconhecido: sai 1 com a linha na mensagem.

Decisoes onde o contrato deixou escolha:

- Byte nao ASCII cru (quem escreveu esqueceu o `\uXXXX`): vira `?`, com aviso em stderr, e a tela
  sai assim mesmo (nao vale perder o resumo inteiro por um acento). `\u0000` e substitutos
  (`\uD800`-`\uDFFF`) tambem viram `?`.
- Texto que nao cabe: o valor de item diminui de 34 ate 28 px; titulo e destaque do resumo
  diminuem juntos de 72 ate 56 px; o resto (e o que mesmo assim nao coube) e cortado com
  reticencias e avisado em stderr como `nl_tela: truncado: <campo>: "..."`. Nunca passa da margem.
- Fonte: falta uma das cinco em `<dir_fontes>` -> usa a reserva do sistema (`/system/fonts`:
  `Roboto-Regular.ttf` para Regular, `Roboto-Bold.ttf` para SemiBold e Bold, `DroidSansMono.ttf`
  para as Mono), com aviso; sem as duas, sai 1. A reserva tambem empresta glifo que a Plex nao
  tem; sem glifo em nenhuma, `?`. `NL_TELA_SISTEMA=<pasta>` troca a pasta da reserva (harness).

## Visual

Paleta e tamanhos do C-tela: fundo `#0E1116`, cartoes `#171B21` com cantos de 10 px, texto
`#F2F3F5`, secundario `#A9AFB8`, fio `#2A3038`; ok `#6FD6A6`, corrigido `#F2B451`, atencao
`#F07560`, info = texto (ponto cinza), pendente = secundario (ponto vazado). Margem lateral 110 px.
Mistura de cor em luz linear (sRGB correto) para o antisserrilhado.

- `aviso`: linha de cima Mono 26 (etapa e canto), titulo Bold 100, texto Regular 40 secundario (ate
  1400 px de largura), passos numa fileira de cartoes acima do rodape (4 colunas; 5 ou 6 passos,
  uma por passo), com numero, estado (ponto + palavra) e nome SemiBold 34 em ate 2 linhas; o passo
  em andamento tem o cartao mais claro. Rodape Mono 24.
- `resumo`: titulo + destaque Bold 72 na mesma linha (destaque na cor do estado), canto Mono 24 a
  direita na mesma linha de base; quatro cartoes de grupo com a mesma altura de linha
  (rotulo do grupo SemiBold 30 espacado; por item: fio, rotulo Regular 26 secundario com o ponto
  de estado de 12 px a direita, valor Mono SemiBold 34 na cor do estado); faixa de dicas (Regular
  28, marcador na cor de atencao) logo abaixo dos cartoes; rodape Mono 24. A altura da linha se ajusta ao espaco
  (ate 116 px; com 6 itens e 3 dicas, cerca de 88).

Diferencas em relacao ao texto do C-tela, por legibilidade: o titulo do `aviso` e 100 px (o canvas
usava 104; o 72 do contrato e o do resumo); o canto do resumo e Mono 24 (o canvas usava 28), para
sobrar linha para titulo + destaque; a margem de cima e de baixo do resumo e 72 / 66 px, para
caberem 6 itens e 3 dicas.

## Provas

- `bash tests/test-tela.sh` (no `make check-kit`): compila no host sem aviso, gera os 9 exemplos
  de `tests/fixtures/tela/` (abertura tomada, abertura pendrive, etapa de temperatura, final do
  pendrive, alerta; resumo com os 19 itens do dono: tudo certo, uma correcao, atencoes com 3 dicas,
  pendentes) sem nenhum aviso em stderr e confere cada PNG em python puro (assinatura, CRC, IHDR
  1920x1080 8 bits RGB, dados completos, nenhum pixel fora do fundo nas margens: 110 px dos lados,
  50 em cima e embaixo). Depois: o caso no limite e textos longos demais (cortam, avisam, nao
  passam da margem), usos e entradas invalidas (saem 2 e 1, sem PNG), escapes (`\u00e7`,
  maiusculas, `\u0000`, substituto), byte cru, chave desconhecida, CRLF e comentario (mesmo PNG),
  fonte ausente (reserva ou sai 1), TTF corrompido, binario ARM igual nas duas pastas.
- PNG de exemplo para olhar: `tests/saida/telas/` (fora do git), gerados a cada execucao.

## Pendente (aparelho)

- Rodar o binario ARM no projetor (galeria abrindo o PNG gerado; tempo de geracao).
