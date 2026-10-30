# nl_camcheck - camera interna do PFL7560 (V4L2, somente leitura)

Programa ARM (32 bits, NDK r27c) que o kit de pendrive usa para ler a camera
interna (`/dev/video0`, uvcvideo). Nunca escreve controle da camera (sem
`S_CTRL`): exposicao, ganho e balanco de branco ficam como estao.

Fonte: `nl_camcheck.c`. Binario do aparelho: `nl_camcheck` (esta pasta) e a
mesma copia em `pendrive-autorun/nl_camcheck` (o kit confere o md5 dela antes de
cada execucao).

## Compilar

    # aparelho (ARM)
    ~/Android/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang \
        -O2 -Wall -o nl_camcheck nl_camcheck.c
    cp nl_camcheck ../../pendrive-autorun/nl_camcheck
    bash ../../tests/atualizar-md5-kit.sh      # regrava a lista de md5 do kit

    # PC (harness): o MESMO .c
    cc -O2 -Wall -o nl_camcheck nl_camcheck.c

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

`descarte` padrao 15 em `faixas` e `niveis`. No lugar de `dev`, vale
`arquivo:<caminho.yuyv>:<L>:<A>` (quadro cru do disco, sem V4L2). O arquivo tem de ter
exatamente `L*A*2` bytes; L e A entre 16 e 4096.

## Como mede (bloco 7)

- Perfil de linhas: media da luma (bytes pares do YUYV) nas colunas de 35 a 65 %
  da largura. Limiar no meio entre o minimo e o maximo; trechos acima dele sao
  as faixas.
- Nivel de cada faixa: media das linhas do miolo (sem 1/4 de cada borda).
- Inversao: diferenca entre faixas vizinhas maior que 3 % da amplitude
  (maximo menos minimo dos niveis). `inv_cresc` conta as quedas (fere a ordem
  crescente); `inv_decresc` conta as subidas. Escada em ordem = uma das duas e 0
  (a camera entrega o quadro girado 180 graus, por isso o sentido nao importa).
- Quadro da camera interna: so luma util (sem cor), girado 180 graus, topo da
  escada satura em 235.

## Provas

- `bash tests/test-camcheck.sh`: o binario do host sobre os 4 quadros reais de
  `tests/fixtures/camera/` (2026-10-30, painel da 3a troca). Calibracao: 16
  faixas nos dois formatos. Escada JEIDA (certo): monotona. Escada VESA
  (errado): fora de ordem.

## Pendente (so no aparelho)

- Rodar o `cor.sh` real via adb a partir de JEIDA (nada escrito) e de VESA
  (termina em JEIDA sozinho), conferindo com `cmp -l` e com a camera. Tarefa do
  coordenador: nenhum agente fala com o projetor.
- A camera ocupada pelo `AutoFocusService` (o kit espera o autofoco antes; se o
  `nl_camcheck` nao abrir o dispositivo, o kit cai no fluxo manual).
