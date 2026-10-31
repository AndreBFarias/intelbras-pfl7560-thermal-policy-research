# nl_camcheck - camera interna do PFL7560 (V4L2, somente leitura)

Programa ARM (32 bits, NDK r27c) que o kit de pendrive e a suite de boot
(`docs/research/44-suite-de-boot.md`) usam para ler a camera
interna (`/dev/video0`, uvcvideo). Nunca escreve controle da camera (sem
`S_CTRL`): exposicao, ganho e balanco de branco ficam como estao.

Fonte: `nl_camcheck.c`. Binario do aparelho: `nl_camcheck` (esta pasta) e a
mesma copia em `pendrive-autorun/nl_camcheck` (o kit confere o md5 dela antes de
cada execucao). Bloco 21: `grab` e a captura usam no maximo 4 buffers mesmo que o
driver de mais, saem 1 se o driver nao der nenhum, e `grab` sai 1 se a gravacao do
quadro ficar incompleta (o `test-camcheck.sh` prova com um driver de mentira).

## Compilar

    # aparelho (ARM)
    ~/Android/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang \
        -O2 -Wall -o nl_camcheck nl_camcheck.c -lm
    cp nl_camcheck ../../pendrive-autorun/nl_camcheck
    bash ../../tests/atualizar-md5-kit.sh      # regrava a lista de md5 do kit

    # PC (harness): o MESMO .c
    cc -O2 -Wall -o nl_camcheck nl_camcheck.c -lm

Depois de trocar o binario, o `NLCAM_MD5` do `pendrive-autorun/cor.sh` tem de
ser o md5 novo (o `make check-kit` reprova se nao for) e a lista do
`newlink_update.sh` tem de ser regravada.

## Comandos

| comando | o que faz |
| --- | --- |
| `info [dev]` | driver, formatos, tamanhos e controles com o valor atual |
| `grab dev MJPG\|YUYV larg alt saida [descarte]` | grava 1 quadro cru (descarta N antes, padrao 10) |
| `faixas dev N saida.txt [descarte]` | captura 1 quadro YUYV (640x480, ou o menor YUYV), acha as faixas claras e exige EXATAMENTE N. Grava `ini fim` por faixa. Sai 0 se achou N, 3 se nao (imprime quantas achou), 1 se nao conseguiu abrir ou ler, ou se o quadro veio marcado com erro, curto ou de outro tamanho |
| `niveis dev faixas.txt [descarte]` | captura 1 quadro e imprime a media do miolo de cada faixa, uma por linha, e `inv_cresc=X inv_decresc=Y` na ultima |
| `geometria dev faixas.txt [descarte]` | (bloco 9A, contrato C-geo) captura 1 quadro com a tela de calibracao e imprime `inclinacao_graus`, `trapezio_pct`, `borda_centro_px`, `borda_esq_px`, `borda_dir_px`, `contraste_centro` e `quadro=LxA`, uma `chave=valor` por linha, nesta ordem, com ponto decimal. Sai 0; 3 se as faixas do `faixas.txt` nao aparecem (em mesmo numero) nas tres colunas; 1 se nao conseguiu ler o quadro ou o `faixas.txt` (ou ele tem menos de 3 faixas, ou faixa fora do quadro) |
| `nitidez dev faixas.txt [descarte]` | (bloco 11) captura 1 quadro com a tela de calibracao e imprime o mapa de nitidez 3x3: `nitidez_r1c1` ... `nitidez_r3c3` (largura de borda 10-90 % em px, linha r de cima para baixo no quadro como ele chega, coluna c da esquerda para a direita) e `quadro=LxA`, uma `chave=valor` por linha, nesta ordem, com ponto decimal. Sai 0; 3 se a imagem ou as faixas do `faixas.txt` nao aparecem nas tres colunas, ou se uma regiao fica sem borda; 1 se nao conseguiu ler o quadro ou o `faixas.txt` (menos de 4 faixas, faixa fora do quadro) |

`descarte` padrao 15 em `faixas` e `niveis`. No lugar de `dev`, vale
`arquivo:<caminho.yuyv>:<L>:<A>` (quadro cru do disco, sem V4L2). O arquivo tem de ter
exatamente `L*A*2` bytes; L e A entre 16 e 4096.

## Como mede (bloco 7)

- Captura em YUYV 1280x720 (se o driver nao oferecer, 640x480; senao o menor).
- Perfil de linhas: media da luma (bytes pares do YUYV) nas colunas de 47 a 53 %
  da largura. Era 35 a 65 % ate o bloco 8: com a imagem projetada inclinada para a
  camera (correcao de quatro pontos), a janela larga juntava as faixas e achava 9
  ou 11 em vez de 16. Limiar no meio entre o minimo e o maximo; trechos acima dele sao
  as faixas.
- Nivel de cada faixa: media das linhas do miolo (sem 1/4 de cada borda).
- Inversao: diferenca entre faixas vizinhas maior que 3 % da amplitude
  (maximo menos minimo dos niveis). `inv_cresc` conta as quedas (fere a ordem
  crescente); `inv_decresc` conta as subidas. Escada em ordem = uma das duas e 0
  (a camera entrega o quadro espelhado de cima para baixo, por isso o sentido nao
  importa).
- Quadro da camera interna: so luma util (sem cor), espelhado de cima para baixo (nao girado: o texto
  sai legivel da esquerda para a direita), topo da
  escada satura em 235.

## Como mede a geometria (bloco 9A)

- Tres janelas de colunas: esquerda 15 a 21 %, centro 47 a 53 % (a do perfil) e direita 79 a
  85 % da largura. Em cada uma, o perfil de linhas e as faixas claras acima do limiar (meio entre
  o minimo e o maximo) no trecho da pilha do `faixas.txt` com folga de 1/8 da altura para cada
  lado. Cada janela tem de achar o mesmo numero de faixas do `faixas.txt`; senao, sai 3.
- Centro de cada faixa: media das linhas ponderada pelo quanto a luma passa do limiar.
- `inclinacao_graus`: para cada faixa, a reta (minimos quadrados) dos tres centros; media das
  faixas; `atan` em graus. **Sinal: positivo = as faixas descem para a direita no quadro como ele
  chega** (y do quadro cresce para baixo; o quadro da camera interna e espelhado de cima para
  baixo, entao no que se ve na parede o sentido e o oposto. O "abaixe o lado X" fica no
  `suite.sh`, a confirmar no aparelho com uma inclinacao proposital).
- `trapezio_pct`: (altura da pilha a direita / a esquerda - 1) * 100; altura = centro da ultima
  faixa menos o da primeira.
- `borda_*_px`: o perfil de cada janela e refeito com cada coluna deslocada pela inclinacao local
  (as faixas ficam retas e a borda nao soma o escorrimento da inclinacao); em cada vao entre duas
  faixas, a largura 10-90 % da descida e da subida (fracao de linha por interpolacao), medida a
  partir do fundo do vao; media das bordas da janela. Em quadros sinteticos com rampa conhecida
  sai 0,1 a 0,6 px acima do 0,8 x rampa ideal (amostragem e interpolacao): serve para comparar
  quadros entre si, nao como medida absoluta.
- `contraste_centro`: (media do miolo das faixas - media do fundo dos vaos) / media do miolo, na
  coluna central.

Valores dos quadros reais (2026-10-30; `tests/test-camcheck.sh` imprime):

| quadro | inclinacao | trapezio | borda centro / esq / dir | contraste |
| --- | --- | --- | --- | --- |
| `calibracao-f1` (640x480) | 0.64 | 1.7 | 2.90 / 2.62 / 2.84 | 0.89 |
| `calibracao-f0` (640x480, VESA) | 0.64 | 1.7 | 3.02 / 2.95 / 3.00 | 0.72 |
| `calibracao-inclinada-f1` (640x480) | 2.86 | 9.5 | 1.63 / 1.57 / 1.79 | 0.92 |
| `calibracao-hd-f1` (1280x720) | 2.82 | 12.5 | 1.77 / 2.24 / 1.95 | 0.93 |
| `calibracao-hd-f0` (1280x720, VESA) | 2.82 | 12.4 | 3.49 / 3.24 / 4.02 | 0.89 |

Os `-f0` foram capturados com o painel em VESA (cores trocadas): o fundo nao fica preto, os vaos
clareiam e a borda alarga; nao servem de referencia de foco. A borda de 640x480 e a de 1280x720
nao se comparam direto (px de quadros diferentes): os limiares do 9B devem ser por tamanho.

## Como mede a nitidez 3x3 (bloco 11)

- As regioes saem da imagem achada no quadro, nao de janelas fixas: em cada coluna do quadro, o
  desvio padrao da luma no trecho da pilha (o do `faixas.txt`, com a folga de 1/8 da altura). Dentro
  da imagem as faixas alternam claro e escuro; fora, a parede e lisa (acesa ou nao). Limiar na metade
  do maior desvio (media movel de 9 colunas); a imagem e o trecho acima dele que contem o meio do
  quadro. Imagem achada mais estreita que 20 % do quadro: sai 3.
- Tres colunas de 6 % da largura da imagem achada, centradas em 10, 50 e 90 % dela. Em cada uma, as
  faixas (tem de achar as N do `faixas.txt`), a inclinacao local (como na geometria) e o perfil
  endireitado. Os N-1 vaos viram tres grupos, de cima para baixo no quadro: o grupo do vao k e
  `k*3/(N-1)` (16 faixas: 5, 5 e 5 vaos). A nitidez da regiao e a media das larguras 10-90 % das
  bordas dos vaos do grupo, a mesma medida da geometria.
- O quadro da camera vem espelhado de cima para baixo: a linha r1 do quadro e a de BAIXO na parede.
  As colunas nao sao espelhadas (c1 = esquerda na parede).
- A camera nao esta no eixo da lente (doc 46 s5.4): o mapa compara-se contra ele mesmo (antes e
  depois), nao em valor absoluto.

Mapas dos quadros reais (px; linha a linha, c1 c2 c3):

| quadro | r1 | r2 | r3 |
| --- | --- | --- | --- |
| `calibracao-f1` (640x480, imagem alem do quadro) | 2.73 2.98 2.95 | 2.82 2.88 2.82 | 2.50 2.85 2.81 |
| `calibracao-inclinada-f1` (640x480, imagem de x 0 a 615) | 1.60 1.69 1.84 | 1.62 1.57 1.75 | 1.64 1.59 1.79 |
| `calibracao-hd-f1` (1280x720, imagem de x 102 a 1080) | 3.22 1.75 2.00 | 2.27 1.51 1.79 | 1.83 1.65 1.93 |

No `calibracao-hd-f1` (4 pontos ligados, o caso do dono) a coluna da esquerda sai ~1,5x mais
borrada que a do meio, pior no canto r1c1 (de baixo na parede), como a suite mediu no aparelho.

## Provas

- Nitidez 3x3 (bloco 11): as 10 chaves em ordem nos 5 quadros reais, cada regiao entre 0 e o vao; o
  `calibracao-hd-f1` com a esquerda > 1,3x o meio e o `calibracao-f1` plano (+-20 %); quadros
  sinteticos com a imagem dentro do quadro (parede acesa de um lado), a esquerda com o dobro da
  rampa (c1 = 0,8 x 4, o resto 0,8 x 2) e a rampa crescendo para baixo (r1 < r2 < r3); escada e
  quadro preto saem 3; quadro, `faixas.txt` (ou menos de 4 faixas) e dispositivo ausentes saem 1.

- `bash tests/test-camcheck.sh`: o binario do host sobre os quadros reais de
  `tests/fixtures/camera/` (2026-10-30, painel da 3a troca): 640x480 (`*-f0`, `*-f1`),
  640x480 com a imagem inclinada (`*-inclinada-f1`) e 1280x720 (`*-hd-f0`, `*-hd-f1`). Calibracao: 16
  faixas nos dois formatos. Escada JEIDA (certo): monotona. Escada VESA
  (errado): fora de ordem.
- Geometria (bloco 9A): as 7 chaves em ordem nos 5 quadros reais, bordas positivas e menores que
  o vao, `calibracao-hd-f1` mais inclinado que `calibracao-f1`; quadros sinteticos de inclinacao
  (3 e -2 graus, erro < 0,05), trapezio (6,3 %) e rampa conhecidos; escada no lugar da calibracao
  e quadro preto saem 3; quadro, `faixas.txt` ou dispositivo ausentes saem 1.

## Provado no aparelho (2026-10-30, bloco 8)

- VESA gravado a mao, reboot, kit real via adb: 16 faixas, escada fora de ordem
  (3 inversoes), troca para JEIDA, escada em ordem, particao `4899eefc` (so o byte
  0x5c mudou). Reboot de novo: JEIDA persistiu e o kit nao escreveu nada.

## Pendente

- A camera ocupada pelo `AutoFocusService` (o kit espera o autofoco antes; se o
  `nl_camcheck` nao abrir o dispositivo, o kit cai no fluxo manual).
