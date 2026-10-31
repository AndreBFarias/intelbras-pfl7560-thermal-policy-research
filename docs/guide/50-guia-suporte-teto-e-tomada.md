# Guia de compra: suporte de teto e tomada com proteção (2026-10-31)

Preços vistos na busca em 2026-10-31. Quase todas as lojas recusaram abrir a página para a pesquisa, então
confira preço, carga e cor no anúncio antes de pagar.

## O que o manual diz do aparelho

Fonte: [manual do PFL7560](https://backend.intelbras.com/sites/default/files/2025-03/Manual_PFL7560_01-24%201.pdf).

- **Fixação no teto:** quatro parafusos **M4 x 10 mm** na base (seção 3.5). A figura mostra só dois pontos; a
  distância entre os furos não está no manual. **Medir** antes de comprar.
- **Fonte externa**, 100-240 V, até 240 W. O peso dela não está no manual.
- **Peso do projetor:** cerca de 4 kg e 18 x 29 x 30 cm, só por guia de terceiros. **Pesar.**
- **Distância da tela:** de 1,81 m (60") a 4,52 m (150").

## Suporte de teto

O suporte precisa de giro e inclinação: é o que deixa o projetor de frente para a parede com o keystone
zerado, o estado de imagem mais nítida ([doc 46](../research/46-foco-e-qualidade.md) §5.3).

| # | Anúncio | Preço | O que tem | Para quê |
|---|---|---|---|---|
| 1 | [ELG PRO100WH, Pichau](https://www.pichau.com.br/suporte-para-projetor-elg-pro100-branco-pro100w) | R$ 125,99 à vista (Extra ~R$ 150, Ponto Frio R$ 173,78) | Branco, 13,5 kg, giro 360°, inclinação ±15°, 15 cm do teto, aço com epóxi | **A escolha.** Folga de 3x sobre o peso |
| 2 | [ELG PRO100, Extra](https://www.extra.com.br/suporte-para-projetor-elg-pro100-branco/p/1562919056) | Não visto | Mesmo modelo, garantia de 3 anos pela loja | Se a Pichau não tiver |
| 3 | [Central Suportes CPR150WH](https://www.extra.com.br/suporte-para-projetor-teto-cpr150wh-branco-central-suportes/p/1563253892) | R$ 103,90 | Branco, giro 360°, inclinação 15°, **carga não informada** | Só se a carga for confirmada |
| 4 | [SP310B universal](https://www.extra.com.br/suporte-para-projetor-universal-sp310b-branco/p/1573136360) | R$ 181,17 | Branco, até 15 kg, inclinação 15°, giro não confirmado | Alternativa |

Não se achou suporte de bandeja à venda no Brasil. **A fonte não vai no suporte:** prenda o corpo dela na laje
ou numa prateleira com abraçadeira, com folga no cabo. Nunca deixe a fonte pendurada pelo cabo, porque o peso
puxa o conector do projetor.

## Tomada com proteção, de 4 a 5 m

Não existe iClamper de 5 m: toda a linha Energia 5 tem cabo de 1 m. Também não se achou filtro com DPS de 5 m em
outra marca.

**A combinação:**
1. Extensão de 5 m com cabo PP **3 x 1,5 mm²**, 10 A e tomada 2P+T, com selo do Inmetro. Exemplo de referência:
   BTicino 2528B (5 m, 3 x 1,5 mm², branca).
2. **iClamper Energia 5 branco** no fim da extensão, perto da fonte do projetor. O DPS protege melhor quanto mais
   perto do aparelho. [KaBuM, versão preta](https://www.kabum.com.br/produto/397138/filtro-de-linha-dps-iclamper-energia-5-5-tomadas-bivolt-preto-21517):
   6 kA, classe III, desconexão térmica, nota 4,9 com 504 avaliações.
3. A conta: 240 W em 127 V dá cerca de 2 A. Os 10 A e 1,5 mm² sobram.

**Não serve:** Intelbras EXT 2005, que tem 5 m mas cabo plano de 2 x 0,75 mm² sem terra.

## Instalação na laje

- 4 parafusos de 6 mm com bucha de nylon de 8 mm na laje de concreto, ou chumbador. Confira a carga da bucha no
  pacote.
- Monte o projetor no suporte com os M4 x 10 do manual. Parafuso mais comprido pode encostar na placa.
- Deixe o projetor centrado com a tela e na altura certa, e depois gire e incline até a imagem ficar
  retangular com os 4 pontos zerados ([doc 46](../research/46-foco-e-qualidade.md) §7).
- Não tape as saídas de ar. A política térmica conta com elas (`./pfl7560-saude.sh`).
