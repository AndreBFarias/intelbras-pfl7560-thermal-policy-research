# Bloco 11 - Qualidade de imagem no máximo e foco validado pela câmera (2026-10-31, a fazer)

Pedido do dono: "um teste pra de alguma forma verificar se a qualidade da projeção tá no ultra e otimizar a
resolução e o foco? Esse último eu sinto que não tá dando conta do recado. [...] usarmos a câmera pra
validarmos isso?"

## O que já se mediu (suíte no aparelho, 2026-10-30/31)

- Saída 1920x1080. A câmera captura em 1280x720 e resolve ~1100 px na largura (bloco 8).
- Geometria, 3 rodadas iguais: inclinação 2,84°, trapézio 12,4%. Largura da borda das faixas brancas,
  medida de 10% a 90%:

  | Centro | Esquerda | Direita |
  |---|---|---|
  | 1,96 px | 2,88 a 3,06 px | 1,87 px |

  O lado esquerdo sai cerca de 1,5x mais borrado que o centro e que a direita. É o limite que a suíte usa para
  "foco irregular".
- A correção de 4 pontos está ligada e forte: `lt=95,915 rt=1715,1030 lb=40,25 rb=1775,35`. A imagem é
  reamostrada digitalmente, o que custa nitidez, e mais de um lado do que do outro.
- O autofoco do fabricante (`com.zhiying.autofocus`) roda no boot. Uma vez, ao ser disparado pela suíte, "não
  começou", e o serviço recusa em alguns estados (doc 43 §2).

## Hipóteses a separar (uma variável por vez)

1. O borrão do lado esquerdo vem do **keystone digital** (reamostragem) e não da lente. Prova: medir as bordas
   com os 4 pontos zerados, depois de alinhar o projetor de frente, contra a medida de agora.
2. O **foco ótico** não está no ponto ótimo. Prova: varrer o foco, se houver controle de motor por shell ou
   pela API do AutoFocus (a ler no firmware), medindo a borda no centro em cada passo e ficando com o mínimo.
   Sem controle de motor: autofoco repetido N vezes, guardando a melhor medida.
3. **Ajustes de imagem fora do máximo:** modo de imagem, nitidez, redução de ruído, MEMC, sobrevarredura
   (overscan, que corta e reescala) e saída diferente de 1080p nativo. Prova: ler as props e o
   `/proc/msp/*` (`pq`, `disp`, `vo`) e comparar com o máximo possível. Mudar uma por vez, medindo a borda e o
   contraste pela câmera.

## Entregas

- Um modo `nl_camcheck nitidez` com um padrão melhor que as faixas: grade de linhas finas nos 9 pontos da tela
  (cantos, meios e centro), com a MTF ou a largura de borda por região. Gera um mapa de nitidez 3x3.
- A etapa de imagem da suíte passa a mostrar o mapa: "Foco: centro ok, canto esquerdo borrado", com a dica
  certa ("alinhe o projetor de frente e zere os 4 pontos" ou "foco refeito").
- Um script de PC `pfl7560-qualidade.sh`: lê e mostra os ajustes de imagem, compara com o máximo e só muda
  algo com a palavra do dono.

## Restrições

- Nada de escrever nas props dos 4 pontos nem chamar o `ProjectionService` (doc 43).
- Cada mudança de ajuste é reversível e registrada, com antes e depois medidos pela câmera.

## 11P - Pesquisa (agora, em paralelo ao bloco 10; só leitura, sem aparelho)

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-11p`, branch `bloco-11p/pesquisa`. Entrega só
`docs/research/46-foco-e-qualidade.md`, no formato do doc 43: tabela com comando, fonte (arquivo, classe ou
offset, linha) e confiança, e uma seção "o que não se achou". Firmware em `firmware/Software PFL7560.zip`. Os
scripts da pesquisa P ficaram numa pasta temporária do PC, fora do repositório. Extraia numa pasta temporária
nova e apague os brutos no fim.

Perguntas:
1. **Foco:**
   - O `AutoFocus3` ou outro serviço expõe passos do motor de foco (posição absoluta ou relativa, `+`/`-`)?
     Por intent, prop, `/dev`, `/sys` ou comando do `hidebug`?
   - Como o autofoco decide o ponto: por contraste da câmera? Com que padrão na tela?
   - Dá para pedir "foco fino" ou repetir só a varredura fina?
   - Por que o serviço às vezes "não começa" (doc 43 §2: backlight desligado, teste de fábrica, outra
     condição)?
2. **Ajustes de imagem:**
   - quais existem e onde moram (props, `ZYCustom.db`, PQ do HiSilicon, `/proc/msp/pq`): modo de imagem,
     nitidez, redução de ruído, MEMC, contraste dinâmico, overscan e zoom;
   - qual valor é o "máximo de qualidade" para cada um;
   - como ler e como mudar de forma reversível, sem tocar nos 4 pontos.
3. **Resolução:** a saída para o painel é 1080p nativo sem reescala? O overscan está zerado? Ler `/proc/msp/disp`
   e `vo` no texto do firmware (strings do driver) e as props `persist.display.*`.
4. **Keystone e nitidez:** a correção de 4 pontos é feita em GPU (SurfaceFlinger) ou no hardware de vídeo? Qual
   filtro de reamostragem ela usa? Há como trocar para um filtro mais nítido?
5. O que disso pode virar etapa automática da suíte e o que só deve ser mostrado ao dono.

## Estado (2026-10-31, bloco 19A)

Feito no PC (worktree `bloco-19a`, branch `bloco-19a/foco`); falta só o aparelho.

- `nl_camcheck nitidez`: mapa 3x3 com as regiões tiradas da imagem achada no quadro. ARM recompilado (NDK
  r27c), md5 novo no `cor.sh` e nas listas do kit.
- Suíte, etapa 2: o mapa a cada medida; o item "Nitidez" mostra centro e pior canto ("1,9 · canto 3,1 px") e a
  dica separa as causas (cantos de um lado com os 4 pontos ligados = zerar e alinhar; centro = foco). Com o foco
  ainda ruim depois dos autofocos, a varredura fina do motor pelo `hidebug` (`gfd`, `gfdr`, `sfd`), que volta à
  posição inicial se nada melhorar.
- `pfl7560-qualidade.sh`: lê e compara os ajustes de imagem; muda um por vez com confirmação e `--voltar`.

Desvio do pedido: o valor do item não é "Centro 1,9 px · Pior canto 3,1 px" porque a coluna do resumo cabe
18 caracteres (o `nl_tela` cortaria); o texto inteiro vai na dica.

A conferir no aparelho: doc 44 §16, "PROVISÓRIO". A hipótese 1 (reamostragem contra ótica) ainda pede o dono
zerar os 4 pontos e rodar a suíte de novo, comparando os dois mapas.

## Atualização (bloco 20, 2026-10-31)

Integrado no merge `c8c13e9`. A varredura fina de foco ainda não foi vista no aparelho: é o item 3 de "Só com
o dono no projetor" em [ESTADO.md](../ESTADO.md).
