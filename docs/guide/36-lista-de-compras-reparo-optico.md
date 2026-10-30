# 36 - Lista de compras: polarizador, filme e painel de reposição

Peças para o reparo óptico do PFL7560 (painel único LCD 5,8" da família RX058B). Levantamento de
2026-08-17/18, com re-verificação independente das páginas.

> **Preços com validade curta.** Todas as promoções do AliExpress expiram **26/08/2026 23:59 BRT**.
> Depois disso, todo valor desta tabela vira suspeito. Os totais em BRL são preço + imposto estimado +
> frete, como o próprio site declara — e são **soma derivada**, não um número lido pronto da página.

---

## 0. O gate POL-S1 — FECHADO em 2026-09-02

> **Respondido com o aparelho aberto.** Ver [`../research/38-motor-optico-e-troca-do-polarizador.md`](../research/38-motor-optico-e-troca-do-polarizador.md).
>
> 1. **Qual queimou:** o de **entrada** (lado do LED), como previsto na seção 1.
> 2. **Solto ou laminado:** **SOLTO.** É uma **placa de vidro separada**, entre a Fresnel traseira e o
>    painel LCD, retida por guias. **Não é laminado ao vidro do painel** — a compra **não** precisa
>    migrar para o painel completo (seção 4).
> 3. **Medida real:** a peça do **item 1** (vidro de isolamento térmico do TD98, **136x85 mm**) bate
>    **tamanho, espessura e eixo** com a original, verificado por sobreposição. É **drop-in**.
>
> **Consequência para esta lista:** o item 1 está validado no aparelho. O item 4 (painel completo)
> deixa de ser contingência provável e vira sobressalente. Os filmes soltos (itens 2, 3 e 5) continuam
> valendo como material do plano B (vidro cortado + filme) e como **gabarito de eixo** — nunca como
> camada adicional no caminho de luz.
>
> **A medida não é universal na classe "5,8 polegadas"** — o catálogo tem 145x85, 142x92, 136x85,
> 119x74 e 96x60. Em outro exemplar, **sempre comparar com a peça retirada antes de instalar**.

O texto abaixo é o levantamento original de 2026-08-17/18, mantido como registro da pesquisa de peças.

---

## 1. Lado de ENTRADA (o quente — é o que queima)

Em projetor de **painel único** sem reciclagem de polarização, o polarizador de entrada absorve sozinho
mais de metade do feixe bruto, mais o infravermelho, antes de qualquer atenuação. É ele que cozinha.
(Em 3LCD a literatura descreve o oposto — o de saída é o crítico. A regra abaixo vale para **este**
aparelho, não como generalidade.)

| Prio | Peça | Por que | Fonte | Preço BRL | Prazo | Risco |
|---|---|---|---|---|---|---|
| **1** | Vidro polarizador c/ isolamento térmico, 136x85 mm (há variante 145x95) | O vidro IR remove o infravermelho **antes** do filme e funciona como dissipador, impedindo o enrugamento que mata filme solto. Não torna o filme mais resistente — reduz a carga que chega nele | AliExpress `1005009462536295` | **102,64** | 30/08–09/09 | Loja 95,1%, 5.0 (4 aval.), 36 vendidos. **Limite 1 peça.** Não declara dye/iodine nem temperatura |
| **2** | Filme polarizador **dye-type com datasheet**, 200x250 mm | **Único item da lista com spec térmica publicada:** 105 °C seco 500 h; 80 °C/90%RH e 85 °C/85%RH por 500 h; choque −40..85 °C x200. Ataca a **recorrência**, não só o sintoma | 3dlens.com (`high-temperature-polarizer-film`) | **US$ 10** (US$ 11 c/ adesivo) — **frete não cotado** | desconhecido | Preço em USD e **frete não cotado**: o frete decide se vale. Não reverificado por browser |
| **2b** | **PFHDU** (polarization.com), **cinza neutro**, 25x15 cm — a melhor peça da lista inteira | `105 °C seco / 1000 h` (dobro do HP200) **e** lâmpada de mercúrio 400 W / 500 h, que é o modo de falha real. Eficiência >99,90%. O anúncio diz que serve "to repair some projectors with damaged polarizers" | polarization.com | **US$ 26** (~R$ 135) | desconhecido | Frete não cotado; a loja exige conta. **NÃO confundir com o item rotulado "Dye Color" do 3dlens (HPC200 roxo): esse é 90 °C e 81,6% de eficiência** — ver 5.2 |
| **3** | Filme polarizador **refletivo prata**, 200x170 mm | Refletivo rejeita em vez de absorver: esquenta bem menos no lado do LED. Maior área e melhor reputação da lista | AliExpress `1005006326920035` | **39,69** | 29/08–05/09 | Loja 97,9%, **4.9 (69 aval.), 412 vendidos**. **Classe é inferência:** é refletivo de fundo de LCD (polimérico tipo DBEF), **não** wire-grid — substrato polimérico tem instabilidade dimensional perto de 85 °C. Não é peça de alta temperatura |
| **4** | Par polarizada + espelhada, 16x16 cm (TD98) | **Única via rápida:** nacional, 2-3 dias, devolução grátis 30 dias. Todo o resto chega entre 28/08 e 17/09 | Mercado Livre `MLBU3004309065` | **99,90** | 2-3 dias | MercadoLíder Platinum, 4.5 (11 opiniões). **A descrição do anúncio vazou o prompt de IA que a gerou** — a spec de 16x16 cm não é auditada por ninguém. A espelhada é autoadesiva, e cola no lado quente é risco |

---

## 2. Lado de SAÍDA (o frio — degrada devagar)

Serve como sobressalente e, principalmente, como **gabarito de ângulo**.

| Prio | Peça | Por que | Fonte | Preço BRL | Prazo | Risco |
|---|---|---|---|---|---|---|
| **5** | Folha polarizadora linear **0/90°**, 20x30 cm, **sem cola** | Declara ângulo **e** é a única sem adesivo — dá para reposicionar durante o ajuste empírico de 90°, que é o passo que mais se erra | AliExpress `1005008706893868` | **29,54** | 28/08–04/09 | Faixa 380-700 nm = **visível apenas, não bloqueia IR**. Nunca usar no lado quente |
| **6** | Película polarizada **0°**, 13x10 cm | Único anúncio brasileiro que **declara o ângulo**. Barato demais para não ter como referência de eixo | Mercado Livre `MLBU1743247795` | **19,99** | dias | Autoadesiva. 13x10 cm dá só ~1 mm de folga sobre os 129 mm **inferidos** |

---

## 3. A pergunta que decide a compra do filme

Nenhum anúncio de marketplace declara temperatura ou tipo de filme. Mas isso **é** obtível — basta
perguntar com os termos técnicos certos. Mande em inglês (para o app traduzir) com os termos em chinês
(para o vendedor entender):

```
Hi, before ordering I need 2 specs confirmed:

1) Is this polarizer dye-type (染料系偏光片) or iodine-type (碘系偏光片)?
2) What is the heat resistance rating, with the TEST CONDITION?
   For example: 105C dry 500h (耐热 105℃ 500小时), or 80C/90%RH 500h.

My projector's polarizer runs above 70C, so I need the high-temperature
dye-type (耐高温偏光片). If this item is iodine-type, do you sell a
dye-type version? Also: single transmittance (单透过率) and degree of
polarization (偏振度)? And the polarization axis angle (偏振轴角度)?
Thank you.
```

**Como ler a resposta:**

| Resposta | Significado |
|---|---|
| `105℃` ou `染料系` | produto certo |
| só `耐高温` sem número | marketing, não é dye qualificado |
| `碘系`, desconversa, ou foto do anúncio | filme de LCD comum — vai queimar de novo |

**Por que isso importa (mecanismo publicado):** o filme iodine é PVA com poli-iodetos `I3-`/`I5-`; sob
calor o `I5-` sublima acima de ~90 °C, o filme perde a absorção do vermelho e passa a vazar luz. O dye
qualificado tem 105 °C x500 h em datasheet, 105 °C x1000 h no PFHDU, e 115 °C x2000 h no grau
automotivo. O preço da troca é 3 a 5 pontos de transmitância (dye 38-42% contra iodine 42-45%) — ou
seja, imagem levemente menos brilhante em troca de não repetir a queima.

**Teste caseiro, se o vendedor não responder** (inferência de engenharia a partir do mecanismo acima,
**não** procedimento citado por fonte): recorte de 1 cm² em chapa a **105-110 °C por 1-2 h** — dye passa,
iodine avermelha e perde polarização.

---

## 4. Contingência: painel LCD completo

Comprar **apenas** se o gate POL-S1 mostrar polarizador laminado ao painel, ou o próprio LCD danificado.

| Peça | Fonte | Preço BRL | Prazo | Risco LVDS |
|---|---|---|---|---|
| Painel `RX058B-0600` | AliExpress `1005004991633384` | **241,27** | 29/08–08/09 | **nulo** |
| Painel `RX058B-0600` 60 pin (cita TD96/YG620) | AliExpress `1005004991909204` | 245,78 | 29/08–08/09 | **nulo** |

Risco LVDS nulo porque é exatamente o painel já instalado e o firmware **já está em JEIDA** (byte `0x5c`
= 1 no perfil 69 do `panelparam`): é drop-in, sem tocar na partição. Ressalva de loja: reputação 90,8%,
a pior da lista, com poucas avaliações.

> **CORREÇÃO (2026-10-29)** — o "risco LVDS nulo" acima não vale mais. Na 2ª troca de LCD o painel
> instalado é o `FPX-RX058B-4300-V0` `20241101 HT` (o mesmo modelo do de fábrica) e o aparelho está em
> **VESA** (`0x5c` = 0), não em JEIDA ([doc 40](../research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md)
> §1). Um `-0600` comprado hoje provavelmente pede JEIDA, mas **o formato não se deduz do anúncio nem do
> nome**: depois de instalar, faça o teste de cor do [guia 32](32-guia-troca-painel-lcd.md) §3 (kit de
> pendrive ou `wizard`). O risco é **baixo e corrigível por software**, não nulo.

**EVITAR** anúncios "combo" com sufixos `-1300 / -1000 / -1500 / -1800 / -1900 / -0100 / -3400 / -0202`:
sufixo diferente = timing diferente, e o teste com o perfil 72 (`RX058B_4500`) já resultou em **tela
preta**, não em cor errada.

---

## 5. NÃO comprar (verificado, com motivo)

| Item | Motivo |
|---|---|
| AliExpress `1005010263602235` (vidro, R$ 103,17) | Mesmo produto do item 1, R$ 0,53 mais caro, e **as 9 avaliações 5.0 são de outro produto** (filtros de lente). Nota herdada. **Era a recomendação da primeira rodada de pesquisa — foi derrubada** |
| eBay `317584481860` (R$ 98,03) | Declara espessura (1,15 mm), mas avisa que o imposto **não** está incluído. Não é comparável |
| Amazon BR `B0HC8S5VRW` (R$ 96,80) | Mais caro que o filme nacional, entrega 10-17/09, vendedor sem avaliações, devolução 7 dias |
| ML `MLB2104310444` (R$ 179,90) | O anúncio se contradiz: título diz 25x25 cm, descrição diz 17x17 cm. Zero vendas |
| AliExpress `1005010627398359` ("tamanho personalizado") | Não há campo para informar a medida; avaliação reclama de atendimento por IA. Nota 3.5 |
| AliExpress `1005007119347955` (135x78 mm) | Bate quase exato com a medida inferida, mas **não declara isolamento térmico** e restava 1 unidade |
| AliExpress `1005008895024155` (vidro, R$ 137,52) | Nota **1.0** com 1 avaliação, e não foi reverificado em 18/08 |

---

## 5.1. NEGATIVO DEFINITIVO: não existe filme dye-type com spec no AliExpress

Busca dedicada em 2026-08-18, com os termos técnicos em chinês, que a rodada anterior não tinha tentado:

| Termo | Anúncios listados | Resultado |
|---|---|---|
| `耐高温偏光片` (polarizador alta temp.) | 64 | só "vidro com isolamento térmico" genérico |
| `染料系偏光片` (dye-type) | 55 | o motor traduz 染料 como "corante" e devolve pigmento de mica e tintura de cabelo |
| `投影机偏光片` (polarizador de projetor) | 62 | peças OEM Epson/Sony, pequenas demais |
| `耐热偏光片` (resistente ao calor) | 58 | categoria mais rica, **zero número de temperatura** |
| `105℃ 偏光片` | 60 | só capacitores eletrolíticos de 105 °C |

Mais 5 buscas em inglês e português: nenhuma das ~500 listagens declara temperatura, horas de ensaio, ou
`染料系`/`碘系`. As galerias de imagem baixadas do CDN são fotos com régua, sem texto de spec. O melhor
que qualquer anúncio diz é "resistente ao calor" — e isso descreve **o vidro**, não o filme colado nele.

**Limitação registrada:** a página de detalhe do AliExpress está atrás de CAPTCHA
(`mtop.aliexpress.pdp.pc.query` → `punish?action=captcharecaptcha`). Das buscas saem título, preço,
nota e vendas; **não** sai descrição, frete, prazo nem loja. A busca foi interrompida sem contornar a
verificação. `1688.com` exige login Taobao; eBay devolveu 403; Alibaba, 410.

**Conclusão prática:** dentro do AliExpress, spec térmica só se obtém **perguntando ao vendedor**
(seção 3). Não existe anúncio que a publique.

## 5.2. ARMADILHA: comprar pelo rótulo "dye" leva o produto errado

No 3dlens, o item que diz explicitamente **"Dye Color"** é o **HPC200 (roxo)** — e ele é o **pior** da
lista: `90 °C/500 h` e eficiência de polarização de apenas **81,6%** (crossed ≤7%). Instalar isso num
projetor mataria o contraste.

O bom é o **HP200 "neutral gray"**, `105 °C seco/500 h`, eficiência **99,8%**. Quem declara a família
inteira como dye-type é a página de categoria, não o título do produto.

## 5.3. Geometria: 45°/135° muda o tamanho mínimo da folha

O painel de 5,8" 16:9 tem **128,4 x 72,2 mm**. Se o polarizador for montado a **45°/135°** (o padrão em
LCD), o recorte rotacionado precisa caber numa caixa de **141,4 x 141,4 mm** — não em 128 x 73.

| Folha | Cabe a 45°? |
|---|---|
| PFHDU 25x15 cm | sim, 8,6 mm de folga no lado curto — **uma peça por folha** |
| HP200 20x25 cm | sim, folgado |
| Edmund 150x150 mm | apertado: 4 mm de folga por lado |

**Não verificado:** se o polarizador deste aparelho é 45/135 ou 0/90, e a espessura máxima que o slot
aceita (as folhas têm 0,19-0,20 mm). Medir na desmontagem — faz parte do gate POL-S1. (POL-S1 fechou em
2026-09-02 com a peça TD98 drop-in, mesma espessura e mesmo eixo da original por sobreposição; o ângulo em
graus e a folga do slot para filme seguem não medidos.)

## 5.4. As opções com spec declarada (fora do AliExpress)

Cotação USD 1 = BRL 5,2102 (2026-08-17).

| Fornecedor / modelo | Preço | Tamanho | Spec térmica literal | Óptica |
|---|---|---|---|---|
| **polarization.com PFHDU** | US$ 26 (~R$ 135) | 25x15 cm | `105 °C seco / 1000 h`; `80 °C 90%RH / 500 h`; **lâmpada de mercúrio 400 W / 500 h**; choque `-30..85 °C` x1000 | single 38,0%; **>99,90%** |
| **3dlens HP200** | US$ 10 (~R$ 52) | 20x25 cm | `105 °C seco / 500 h`; `80 °C 90%RH / 500 h`; choque `-40..85 °C` x200 | single 42%; 99,8% |
| apioptics AP39DT-006T | US$ 69 + **US$ 163 frete** | 30x48 cm | `105 °C seco` (sem horas) | extinção 9000:1 |
| Edmund XP40HT 150x150 | US$ 58,95 (~R$ 307) | 15x15 cm | `100 °C x 1000 h` | extinção 5000:1 |

O **PFHDU** é o único que declara resistência a **fluxo luminoso** (lâmpada de mercúrio 400 W por 500 h)
— que é exatamente o modo de falha do polarizador de entrada de um projetor, e não apenas calor seco.

**Frete não cotado** para PFHDU, HP200 e Edmund; só o apioptics deu cotação (UPS, 2,4x o valor da peça).
Nenhuma inclui tributo de importação brasileiro.

## 6. Negativos verificados (valem como resultado)

- **Vidro polarizador com corte de IR real (BG39/QB39) não existe no varejo no tamanho do painel.** Os
  IR-cut de verdade param em 40x40 mm ou 70 mm redondo — tamanho de câmera. O rótulo genérico
  "isolamento térmico" dos vidros de TD98 é o único marcador disponível nesta faixa.
- **Amazon BR retorna zero resultados para `RX058B`.** Painel só via AliExpress.
- **Mercado Livre não tem** o painel RX058B nem vidro polarizador acima de ~4,5".
- **O `RX058B-4300` original (o de fábrica) não apareceu à venda** em AliExpress, eBay, Amazon ou
  Alibaba. Isso é "não apareceu nas buscas feitas", **não** prova de que não exista.

---

## 7. O que continua sem resposta

- ~~**A medida real do polarizador**~~ — respondida (POL-S1 fechado em 2026-09-02): a peça TD98 136x85 mm
  tem a mesma medida e espessura da original ([doc 38](../research/38-motor-optico-e-troca-do-polarizador.md) §4).
- **O ângulo de polarização** dos vidros: nenhum anúncio declara. A montagem é empírica, girando a peça
  até a imagem ficar mais clara (nunca preta). Os itens 5 e 6 existem para servir de referência de eixo.
- **Frete internacional dos filmes dye** (itens 2 e 2b): não cotado. É o que decide se a única opção com
  spec térmica publicada é viável.
- **Se o vidro "isolamento térmico" é vidro com revestimento IR ou filme laminado em vidro** — muda a
  durabilidade e nenhum vendedor esclarece.
- **A classe do filme refletivo (item 3)**: inferida como polimérico tipo DBEF, não confirmada.

## 8. Procedência deste levantamento

Duas rodadas independentes de pesquisa com browser real (Playwright), a segunda revisando a primeira.
Marketplaces bloqueiam scraping (Mercado Livre devolve 403 a `curl`; AliExpress serve só shell JS e a
busca caiu em CAPTCHA), então a cobertura de catálogo **não é exaustiva** — pode existir opção melhor que
não apareceu. Links de Mercado Livre só resolvem no formato `/<slug>/up/<id>`; os IDs sozinhos dão 404.
