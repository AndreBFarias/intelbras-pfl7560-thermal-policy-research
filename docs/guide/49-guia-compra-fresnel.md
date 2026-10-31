# Guia de compra: lentes Fresnel do PFL7560 (2026-10-31)

Preços e disponibilidade vistos em 2026-10-31. Antes de pagar, confira na página do anúncio.

## Antes de comprar

1. **Confira se precisa trocar.** As duas Fresnel foram limpas em 2026-09-02 e estão sem dano
   ([doc 39](../research/39-sessao-2026-09-02-optica-e-balanco-termico.md) §1.1). A troca só se justifica se a
   Fresnel 2 (a da frente, entre o LCD e o espelho) estiver **empenada** pelo calor, a suspeita do foco desigual de
   um lado (OPT-S2). Teste: olhe a lente contra uma luz rasante e procure ondulação.
2. **Meça as duas** com paquímetro ou régua: largura x altura x espessura. Até hoje ninguém mediu. A classe de
   5,8" não tem tamanho único (o polarizador vem em 5 medidas, [doc 38](../research/38-motor-optico-e-troca-do-polarizador.md) §4).
3. **Meça a focal de cada uma** pelo teste do ponto no papel ([doc 38](../research/38-motor-optico-e-troca-do-polarizador.md) §7.1):
   - aponte a lente para o Sol;
   - ache o menor ponto no papel;
   - a distância da lente ao papel é a focal.

   Anote qual focal é a da Fresnel 1 (perto do LED) e qual é a da 2. É isso que decide qual anúncio serve.

Onde fica cada peça: [`media/guia-ordem-pecas-opticas.jpg`](../../media/guia-ordem-pecas-opticas.jpg) e
[`media/guia-motor-optico-angulo.jpg`](../../media/guia-motor-optico-angulo.jpg).

## O padrão do mercado para projetor de 5,8"

Quase todo kit vem como **par de PMMA de 140x90 mm, com focais F185 e F120**. Dá para conferir antes de comprar:
- o 140x90 cobre a área ativa do LCD (cerca de 128x72 mm) e fica perto do polarizador de 136x85;
- nenhum anúncio diz qual das duas lentes é a de 185 e qual é a de 120. Compare com as focais que você mediu.

Variantes vistas: F200/F120, e F185/F130 em 136x82 mm.

## Links

**Brasil:** nenhuma loja com estoque no país tinha a medida certa. Mesmo no Mercado Livre, os anúncios de 140x90 vêm
da China (frete grátis acima de R$ 79, ICMS já estimado). A Shopee bloqueou a busca e não foi vista.

| # | Anúncio | Preço (2026-10-31) | O que tem | Para quê |
|---|---|---|---|---|
| 1 | [AliExpress: par 140x90, F185 e F120](https://pt.aliexpress.com/item/1005003192447718.html) | R$ 34,79 + R$ 8,71 de imposto | "Frontal e traseira", PMMA, nota 5 (2 avaliações) | **O mais barato do padrão.** Diz "semi-acabado"; confirme se vêm 2 lentes |
| 2 | [AliExpress: 2 peças 140x90, 185 e 120 mm](https://pt.aliexpress.com/item/1005003192457274.html) | R$ 78,29 + R$ 19,58 | Par, nota 5 (3 avaliações), 19 vendidos | Mesmo padrão, mais caro |
| 3 | [AliExpress: 1 peça 140x90x2, focal à escolha](https://pt.aliexpress.com/item/32956368441.html) | R$ 30,09 + R$ 7,53 cada | PMMA, focal de 120, 220, 240 ou 330 mm | **Bom para trocar só a Fresnel 2**, ou para escolher a focal medida |
| 4 | [Mercado Livre: 2 peças 140x90x2 PMMA](https://www.mercadolivre.com.br/lente-de-alta-definicao-de-2-ppecas-lente-de-alta-excelente1/p/MLB2027231929) | R$ 68,29, frete grátis | Loja com +500 vendas, devolução em 30 dias | Medida ideal, mas **sem focal** e sem dizer que é Fresnel: pergunte antes |
| 5 | [AliExpress: kit 5 / 5,8 / 7" com suporte](https://pt.aliexpress.com/item/1005004372981797.html) | R$ 81,69 | Par com suporte, nota 4,5 | Só na variação 5,8; medidas em mm não vistas |
| 6 | [Mercado Livre: condensadora 150x150, f=185](https://www.mercadolivre.com.br/lente-condensadora-quadrada-pmma-fresnel-1-peca/up/MLBU4223361113) | R$ 70,69 | PMMA, até 80 °C, vendedor novo | Fresnel 1 cortada no tamanho, se a focal bater |
| 7 | [AliExpress: Fresnel A4 260x180 (lupa)](https://pt.aliexpress.com/item/1005005544391385.html) | R$ 11,10 | Lupa 3x | **Só gabarito ou teste**: não é óptica de projetor |

Fora do Brasil e do AliExpress, para comparar o padrão (preço ou disponibilidade ruins):
[eBay, par F185/F120](https://www.ebay.com/itm/115827402466) (US$ 12,34) e
[Racer.lt, par 150x86 + 140x102](https://www.racer.lt/item/1-pair-diy-universal-5-inch-5-8-inch-fresnel-lens-0-1mm-spacing-for-hd-projector-fpv-goggles-headset-1001.html)
(a única fonte com as medidas da frente e de trás separadas: F185 na frente e F120 atrás).

## Armadilhas

- **"5,8 polegadas" no título é a diagonal do LCD**, não a medida da lente. Só vale o número em mm.
- Títulos chineses misturam medidas. Um anúncio do Mercado Livre diz "300 mm" no título e "260x180" na descrição.
- **Calor:** o PMMA aguenta até cerca de 80 °C. Se a Fresnel 2 empenou, a nova pode empenar igual. Antes, confira
  os sopradores e a correção térmica (`./pfl7560-saude.sh`).
- **Imposto:** compras internacionais pagam 20 % de imposto federal mais ICMS de 17 a 20 %, já estimados na página
  do AliExpress e do Mercado Livre internacional. Prazo de 1 a 6 semanas.

## Ao receber

1. Meça e compare com as antigas: medida e espessura.
2. Faça o teste do ponto no papel em cada lente. Assim você descobre qual é a de 185 e qual é a de 120, e de que
   lado ficam as ranhuras.
3. Monte as ranhuras viradas para o LCD (as duas), sem encostar no painel. Se aparecer um anel prateado na borda da
   imagem, a lente está virada ([doc 38](../research/38-motor-optico-e-troca-do-polarizador.md) §7.1).
4. Guarde as originais: se a nova piorar o foco, elas voltam.
