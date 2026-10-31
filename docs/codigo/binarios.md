# Notas do código: binários do kit em C (`nl_tela`, `nl_camcheck`, `lvdsctl`)

O porquê das decisões nos três programas em C que vão para o pendrive. Uso, compilação e provas: os READMEs de
[`tela`](../../artifacts/tela/README.md), [`camcheck`](../../artifacts/camcheck/README.md) e
[`lcd-color-fix`](../../artifacts/lcd-color-fix/README.md). Mapa geral: [`../MAPA.md`](../MAPA.md).

Os binários versionados (`artifacts/*/nl_*`, `pendrive-autorun/nl_*`) são compilados destes fontes com o NDK r27c;
`tests/test-tela.sh` e `tests/test-camcheck.sh` recompilam e comparam byte a byte quando o NDK está na máquina.
Compile da raiz, com o caminho relativo: o `assert` da `stb_truetype` grava o caminho no binário.

## `nl_tela.c` (telas da suíte, contrato C-tela)

- `campos.txt` é ASCII puro: texto não ASCII vai como `\uXXXX` (BMP; substituto ou zero viram `?`), quebra como
  `\n`, barra como `\\`. Chave desconhecida, linha vazia ou começada por `#` são ignoradas. Byte não ASCII cru (erro
  de quem escreveu) vira `?` com aviso em stderr, e a tela sai assim mesmo. Texto que não cabe é cortado com
  reticências e avisado (`nl_tela: truncado: ...`), nunca passa da margem; o harness exige zero desses avisos nos
  exemplos do dono.
- Limites: `MAX_ARQ` (64 KiB; um `campos.txt` maior não é da suíte), `MAX_LINHA` (1024 bytes, chave incluída) e
  `MAX_TXT` (caracteres por campo, depois de decodificar).
- **Fontes:** as cinco IBM Plex do kit; a que faltar cai na reserva do sistema (`/system/fonts`: Roboto-Regular,
  Roboto-Bold, DroidSansMono; `NL_TELA_SISTEMA` troca a pasta para o harness). Sem nenhuma para um estilo, sai 1.
- **TTF truncado** (cópia interrompida): a `stb_truetype` não confere offset nenhum e lia fora do buffer (ASan:
  heap-buffer-overflow). O diretório de tabelas é conferido antes (cabe no arquivo, cada tabela também);
  `GetFontOffsetForIndex` lê até o byte 15 numa TTC.
- Os avisos de compilação dos cabeçalhos de terceiros (domínio público) são silenciados só em volta do `#include`.
- **Paleta** (bloco 10B, `artifacts/tema/dracula.txt`) com dois tons derivados por contraste
  ([`tema/README`](../../artifacts/tema/README.md)): `C_SEC` é o comentário clareado (55 % de texto), porque o
  comentário puro dá 3,0:1 no fundo e 1,9:1 no cartão (o clareado dá 7,5:1 e 4,8:1); `C_ATEN_CART` é o vermelho
  clareado (20 % de texto), só sobre o cartão, onde o puro dá 2,9:1 (o clareado dá 3,5:1, para texto de 24 px ou
  mais). O vermelho puro dá 4,5:1 sobre o fundo.
- Mistura de cor em luz linear (gamma certo); quinas por 4×4 amostras.
- **Maiúscula inicial** (pedido do dono): nenhuma frase nem rótulo começa com minúscula; sobe a 1ª letra do texto e a
  1ª depois de quebra, `. `, `! `, `? ` e ` · `. Só a 1ª letra: `0,4° (nivelado)` fica como está.
- O passo em andamento leva contorno rosa: um cartão mais claro que a linha sairia da paleta.
- Título e destaque do resumo diminuem juntos (até 56 px) antes de cortar; o valor de um item diminui até 28 px.
- Só grava em arquivo regular: `remove()` apagaria uma pasta vazia passada por engano.

## `nl_camcheck.c` (câmera interna UVC por V4L2)

- **Só leitura** em relação à câmera: nenhum `S_CTRL` (exposição e balanço de branco ficam como estão).
- **Quadro preferido 1280×720** (vãos entre faixas com o dobro de linhas), senão 640×480, senão o menor YUYV.
  `arquivo:<caminho>:<L>:<A>` lê do disco (o harness do PC); o arquivo tem de ter exatamente `L*A*2` bytes, nem
  menos (curto) nem mais (outro tamanho). Quadro maior que o limite não é da câmera interna (e estouraria `size_t`
  de 32 bits).
- **Janela de colunas de 47 a 53 %** da largura: a de 35 a 65 % falhou no aparelho (bloco 8); a imagem sai
  inclinada para a câmera e, numa janela larga, cada faixa escorre sobre a vizinha e os vãos não escurecem.
- **Inversão** = queda ou subida entre faixas vizinhas maior que 3 % da amplitude; vale a menor entre quedas e
  subidas (o quadro chega espelhado de cima para baixo).
- **Geometria (9A, C-geo):** três janelas (esquerda, centro, direita); cada coluna é lida deslocada pela inclinação
  local, para as faixas ficarem retas e a borda medida não somar o escorrimento. Inclinação positiva = as faixas
  descem para a direita no quadro. Busca na pilha do `faixas.txt` com folga de 1/8 da altura (inclinação e
  trapézio deslocam a pilha nas colunas de fora). Borda = largura 10 a 90 % de cada lado do vão.
- **Nitidez 3×3 (bloco 11):** as colunas saem da largura da imagem projetada **achada** no quadro (ela não ocupa o
  quadro inteiro e muda com a correção de 4 pontos): centros em 10 % e 90 %, largura de 6 %. Imagem achada pelo
  desvio padrão por coluna (dentro, faixas alternam; fora, parede lisa). Mais estreita que 20 % do quadro = não é a
  calibração. Pelo menos 4 faixas (3 grupos de vãos).
- Mapeia só `NBUF=4` buffers, mesmo que o driver devolva mais (com ASan, passar disso estoura a pilha).

## `lvdsctl.c`

- Chama `HiPanelCtrl::SetLvdsFormat` (e as de `swap`, `bit` e `map`) da `libhitvservice.so` por `dlopen`. O
  `SetLvdsFormat` **persiste na hora** na `panelparam` (doc 40 §1). O código de saída não é confiável: quem confirma
  é a releitura do byte. Compilar com `-ldl`.
