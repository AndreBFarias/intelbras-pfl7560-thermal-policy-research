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
