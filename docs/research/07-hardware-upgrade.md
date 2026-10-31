# 07 - Upgrade de hardware e limpeza (pesquisa de suporte)

> Gerado da pesquisa em 2026-07-05. **Antes de comprar qualquer fan: ABRA o aparelho e leia a etiqueta** (tensão 12V/24V, no de fios, seta de fluxo).


## Sopradores/ventiladores (troca)

> ## CORREÇÃO (2026-09-03) — NÃO COMPRE PELA LISTA ABAIXO
>
> **Esta seção inteira parte de uma premissa ERRADA: que o ventilador de fábrica é AXIAL.** Ele é um
> **soprador CENTRÍFUGO (blower)**, verificado nas fotos do próprio repositório
> (`media/teardown-04-blower-removido.jpg` e `teardown-05-sopradores-dfh8030s.jpg`): rotor tipo **gaiola de
> esquilo** com dezenas de pás curtas, **carcaça em voluta** (espiral) e **saída tangencial** lateral. Não
> há hélice axial nem moldura quadrada de 80×80.
>
> **Consequência prática:** o Delta **AFB0812SH / AFB0824SH** e o "cooler 8025 nacional" recomendados
> abaixo, **com link e preço**, são ventiladores axiais e **NÃO montam** neste aparelho. Seguir a
> recomendação compra 2 peças inúteis (R$ 90–180) mais uma abertura de chassi à toa.
>
> **Ironia registrada:** o aviso de compatibilidade nº 4 desta mesma seção já dizia *"só considere blower
> se, ao abrir, você constatar que a peça é realmente centrífuga"*. Abriu-se, e é centrífuga. A ressalva
> estava certa e a recomendação principal, errada.
>
> **Modelo:** a etiqueta lida na foto ampliada diz **`DFH8030S`** (não `DFH8025S`), `DC 12V`, `0,45 A`
> — ou seja, **30 mm de espessura**, não 25, e **5,4 W por unidade**. Leitura de foto ampliada, com
> **confirmação na etiqueta física pendente** (o dígito 25/30 está no limite da resolução). 25 mm e 30 mm
> **não são intercambiáveis** no berço.
>
> **Antes de qualquer compra:** confirmar na etiqueta física o modelo, a tensão e a corrente; e medir o
> berço. Substituto tem de ser **blower centrífugo** de mesma altura, mesmo diâmetro de voluta e mesma
> orientação de saída. Ver [`39-sessao-2026-09-02-optica-e-balanco-termico.md`](39-sessao-2026-09-02-optica-e-balanco-termico.md).
>
> **E antes de trocar qualquer coisa:** o efeito dos ventiladores no sensor quente (`gtt1`)
> **nunca foi medido** — só na exaustão, e com o sensor ainda cego. Trocar soprador hoje é comprar sem
> saber se a vazão é o gargalo. Ver doc 39 §4.
>
> **CORREÇÃO (2026-10-29), [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3 a §5:**
> 1. **Modelo e contagem fechados.** A etiqueta diz `DFH8030S`, `DC 12V`, `0,45 A` (centrífugo). São **3
>    ventiladores**: os 2 sopradores DFH8030S que a política controla (`gfc` = 2) e 1 axial no exaustor do
>    dissipador do LED, sem controle por software (OPT-S6).
> 2. **O `gtt1` não é sensor da óptica:** é um NTC no topo do bloco dissipador do LED (OPT-S7). Nenhum
>    sensor mede o polarizador/LCD.
> 3. **Os números do fan de fábrica abaixo não têm fonte.** Não existe ficha pública do DFH8025S nem do
>    DFH8030S: RPM, CFM e pressão atribuídos a ele são estimativa. E a fonte Amazon citada
>    (`amazon.com/dp/B00BK18KAA`, "8025S 12V 2 fios") é de **outro fabricante** (Skywalking 8025S), não da
>    D-FAN.

**Peça de fábrica:** Fan de fábrica: D-FAN DFH8025S — ventilador AXIAL 80x80x25 mm (o "8025" = 80x80x25mm), NÃO é um soprador centrífugo (blower). Rotor de plástico PBT, moldura de alumínio, rolamento sleeve ou ball, ~3000 RPM, 2 fios (alimentação apenas), faixa de operação -10 a +70°C. Fabricado pela Dongguan Xingdong Electronics. Existe em 12V E em 24V (ambas as versões são vendidas com o mesmo código) — no eBay aparecem unidades 24V 0,15A e 24V 0,32A; a Amazon lista 12V. Como é fan de 2 fios, o controle "PWM 36 kHz" do PFL7560 é feito chaveando a própria linha de alimentação (não há fio de sinal PWM dedicado). CFM/pressão estática não são publicados pelo fabricante, mas para um 8025 sleeve de ~3000 RPM ficam tipicamente na faixa de ~30-35 CFM e ~1,5-3 mmH2O — ou seja, há folga real para upgrade.


### Delta AFB0812SH (12V) — MELHOR DROP-IN se o fan de fábrica for 12V
- **Specs:** 80x80x25,4mm, 12VDC, 4500 RPM, 46,6 CFM, 6,78 mmH2O (~66 Pa) de pressão estática, ~40 dBA, rolamento de esfera. Mesmo footprint 8025.
- **Por que é melhor:** Sobe de ~3000 para 4500 RPM e ~2x o CFM e a pressão estática vs. o DFH8025S, mantendo exatamente o mesmo 80x80x25mm. Bom para sistema com duto (alta pressão estática).
- **Compatibilidade:** Escolha a variante certa de fiação: AFB0812SH = 2 fios (igual à fábrica, ideal p/ PWM na alimentação); -F00 = 3 fios (tach); -TP12 = 4 fios PWM. Para o controle 36 kHz na linha, use a de 2 ou 3 fios; a de 4 fios pode conflitar com o chaveamento da alimentação.
- **Preço:** R$ 45-90 (Fans e Fontes, Net Computadores, Shopee, Mercado Livre)
- **Onde comprar (BR):** fansefontes.com.br; netcomputadores.com.br; Shopee BR; Mercado Livre (busque 'Delta AFB0812SH 80x80x25')

### Delta AFB0824SH (24V) — MELHOR DROP-IN se o fan de fábrica for 24V
- **Specs:** 80x80x25,4mm, 24VDC, 0,16A, 4000 RPM, 46,6 CFM, ~5,5-6,8 mmH2O, ~40 dBA, rolamento de esfera, 2 fios.
- **Por que é melhor:** Mesmo ganho de vazão/pressão da AFB0812SH, porém em 24V e já em versão 2 fios (idêntica à pinagem de fábrica). Se a etiqueta disser 24V, esta é a troca mais segura.
- **Compatibilidade:** 2 fios = casa direto com o esquema de alimentação PWM da fábrica. Confirme 24V na etiqueta antes de comprar.
- **Preço:** R$ 60-120 (importado; nacional é mais raro)
- **Onde comprar (BR):** Mercado Livre / AliExpress (busque 'Delta AFB0824SH'); Amazon (AFB0824SH-F00)

### Sunon PMD1208PMB1 (12V) — MÁXIMA performance, PORÉM 38mm de espessura
- **Specs:** 80x80x38mm, 12VDC, 9,1W, 5700 RPM, 84,1 CFM, 0,74 inH2O (~18,8 mmH2O!), 55 dBA, rolamento MagLev.
- **Por que é melhor:** Pressão estática ~6-10x a do fan original — imbatível para vencer duto restritivo. Linha Sunon PMD é feita justamente para projetores/fontes.
- **Compatibilidade:** ATENÇÃO: é 80x80x38mm (mais grosso que o 8025 original de 25mm). NÃO é drop-in a menos que haja folga de altura no gabinete. Barulhento a 5700 RPM. Só use se couber e se quiser o máximo de pressão.
- **Preço:** R$ 80-160 (importado)
- **Onde comprar (BR):** Mouser/RS Brasil, AliExpress, Mercado Livre (busque 'Sunon PMD1208PMB' ou 'Sunon 80x38 alta pressão')

### Alternativa nacional barata (12V) — cooler 8025 'alta rotação' 5000 RPM
- **Specs:** 80x80x25mm, 12V, ~5000 RPM, ~37 CFM, ~3,2 mmH2O (ex.: modelos RT-080, Nework, Botto Brazil).
- **Por que é melhor:** Ganho modesto sobre o original, custo baixíssimo e disponibilidade imediata no Brasil. Menos pressão estática que o Delta.
- **Compatibilidade:** Confira nº de fios (muitos são 2-3 fios) e sentido de sopro. Qualidade de rolamento inferior à Delta/Sunon.
- **Preço:** R$ 20-60
- **Onde comprar (BR):** Mercado Livre, Eletrogate, Botto Brazil, Copel Eletrônica, Ponto da Eletrônica

**Avisos de compatibilidade:** CRÍTICO — confirme ANTES de comprar, abrindo o aparelho e lendo a etiqueta do próprio fan: (1) TENSÃO: o DFH8025S existe em 12V e em 24V com o mesmo código; um fan 12V ligado em 24V queima e um 24V em 12V não gira direito. Leia '12V' ou '24V' na etiqueta. (2) CONECTOR/FIAÇÃO: a fábrica usa 2 fios (só alimentação). Prefira substitutos de 2 fios; se usar 3 ou 4 fios, os fios extras (tach/PWM) ficam sem uso, e um fan 4-fios PWM pode se comportar mal porque o PFL7560 chaveia a PRÓPRIA alimentação a 36 kHz em vez de mandar sinal PWM separado. Confira também o passo/tipo do plugue (JST). (3) SENTIDO DE ROTAÇÃO E DIREÇÃO DO FLUXO: a seta na moldura indica p/ onde sopra; instalar invertido cozinha o light engine. Confirme a seta de fluxo e o sentido de giro na etiqueta. (4) BLOWER x AXIAL: apesar de o projeto chamar de 'soprador', todas as evidências indicam que o DFH8025S é um fan AXIAL 8025, não um blower centrífugo. Um Delta BFB0512/BFB0812 (blower) NÃO é drop-in — tem footprint e saída de ar totalmente diferentes e exigiria refazer o duto. Só considere blower se, ao abrir, você constatar que a peça é realmente centrífuga. (5) DIMENSÃO: drop-in exige 80x80x25mm; opções de 38mm (Sunon PMD) só cabem se houver folga. (6) RUÍDO/VIDA ÚTIL: subir RPM aumenta ruído; prefira rolamento de esfera (Delta/Sunon) para durabilidade.

**Confiança:** Média-alta na identificação do fan (DFH8025S = axial 80x80x25mm, D-FAN/Xingdong) e nas specs dos substitutos Delta/Sunon (dados de datasheet do fabricante). BAIXA na tensão exata do fan no PFL7560 (12V vs 24V) e no tipo de conector/sentido — esses três pontos NÃO foram confirmados e dependem 100% de abrir o aparelho e ler a etiqueta. CFM/pressão do fan original é estimativa (não publicado).

**Notas:** RESUMO PRÁTICO: O fan de fábrica é um AXIAL 8025 (D-FAN DFH8025S), ~3000 RPM, 2 fios, controlado por PWM na linha de alimentação a 36 kHz — não é um blower centrífugo, apesar do nome do projeto. O melhor upgrade drop-in de mesmo footprint (80x80x25) e maior pressão estática é o Delta AFB0812SH (12V) ou AFB0824SH (24V): ~4500/4000 RPM, 46,6 CFM e ~6-7 mmH2O, roughly dobrando vazão e pressão. Para o extremo de pressão estática em sistema com duto restritivo, o Sunon PMD1208PMB (12V, 84 CFM, ~19 mmH2O) é imbatível, MAS tem 38mm de espessura (não drop-in sem folga) e é barulhento. Antes de qualquer compra, ABRA O PROJETOR e leia na etiqueta do fan: tensão (12V/24V), nº de fios/conector e a seta de sentido do fluxo — nenhuma compatibilidade pode ser afirmada sem isso. Como são 2 unidades, troque as duas juntas para manter balanceamento de fluxo. Dica: pegue variante de 2 fios (mesma pinagem da fábrica) para o controle PWM na alimentação funcionar igual ao original.\n\nFontes: delta-fan.com/products/AFB0812SH.html; delta-fan.com/products/AFB0824SH.html; d-fans.en.made-in-china.com (DFH8025S 80x80x25 axial 3000RPM 12V/24V); ebay.com/itm/155976540893 e /386908379522 (DFH8025S 24V 2 fios); amazon.com/dp/B00BK18KAA (8025S 12V 2 fios); rs-online / mouser (Sunon PMD1208PMB1 80x38 84,1CFM 0,74inH2O); fansefontes.com.br e netcomputadores.com.br (Delta AFB0812SH preço BR); mercadolivre.com.br (cooler 80x80x25 12V alta rotação); intelbras.com.br Datasheet PFL7560.

## Dissipadores para o polarizador/LCD

> **CORREÇÃO (2026-09-02, doc 38).** Duas afirmações desta seção e da seção de limpeza são **descrição
> genérica de categoria vinda de pesquisa web** (fontes ao fim do doc) e **não valem para o PFL7560**,
> verificado com o aparelho aberto:
> 1. **"o polarizador é película laminada sobre o vidro do LCD"** — **errado aqui.** É uma **placa de
>    vidro SEPARADA**, entre a Fresnel traseira e o painel, retida por guias, que sai puxando para cima.
>    Trocável sem tocar no painel.
> 2. **"remover o painel LCD do prisma"** — não há prisma. Prisma é arquitetura **3LCD**; este é painel
>    único e o painel sai como módulo discreto.
>
> Geometria correta e procedimento de troca: [`38-motor-optico-e-troca-do-polarizador.md`](38-motor-optico-e-troca-do-polarizador.md).

**Peça de fábrica:** Ponto que queima no PFL7560 = o POLARIZADOR DE ENTRADA (incidente) e a moldura/vidro do bloco LCD. Nesses projetores LCD de painel único, o polarizador é uma película orgânica (plástico polimérico com iodo/corante) laminada sobre o vidro do LCD. Ele absorve ~50% da luz + infravermelho da lâmpada/LED e converte em calor. Como o filme fica exatamente no caminho óptico e conduz calor muito mal, ele aquece no centro e 'queima' (mancha marrom/amarelada tipo queimadura de cigarro, escurecendo com o tempo). A área ativa (janela transparente por onde passa a luz) NÃO pode ser tocada, coberta nem receber cola/fita. A dissipação só pode ir na moldura metálica/plástica que segura o LCD e na borda do vidro (~2-3 mm fora da área útil), levando o calor para longe, em direção a um fluxo de ar.


### Kit dissipadores de alumínio adesivos pequenos (estilo Raspberry Pi/RAM, 8.8x8.8x5mm, 14x14mm, com fita térmica já aplicada)
- **Specs:** Alumínio anodizado, já vem com fita térmica dupla-face; unidades de 8~14mm ideais para caber na moldura estreita do bloco LCD sem invadir o feixe. Alumínio dissipa bem e é leve.
- **Por que é melhor:** Leve e pequeno o suficiente para colar só na moldura metálica que prende o LCD, fora do caminho óptico. A fita que já acompanha esses kits costuma ser fraca - troque pela fita condutora dedicada abaixo.
- **Compatibilidade:** Colar na moldura/suporte metálico do LCD, NUNCA na janela transparente.
- **Preço:** ~R$ 10 a R$ 25 o kit
- **Onde comprar (BR):** Mercado Livre: https://lista.mercadolivre.com.br/heatsink-pequeno e https://lista.mercadolivre.com.br/dissipador-de-calor-%28t%C3%A9rmico%29-auto%C3%98adesivo

### Kit dissipadores de COBRE pequenos (heatsink cobre tipo Raspberry Pi, ~9x9 a 14x14mm, adesivos)
- **Specs:** Cobre puro, conduz calor ~2x melhor que alumínio; ideal para tirar calor da borda do vidro rapidamente. CUIDADO: cobre é condutor elétrico.
- **Por que é melhor:** Melhor condução que alumínio para espalhar rápido o calor da borda de vidro do polarizador ate uma região ventilada. Use quando há espaco e onde não encoste em contatos elétricos.
- **Compatibilidade:** Só na borda de vidro/moldura; isolar de qualquer contato elétrico (flex/driver).
- **Preço:** ~R$ 15 a R$ 35 o kit
- **Onde comprar (BR):** Mercado Livre: https://lista.mercadolivre.com.br/dissipador-aluminio (buscar 'dissipador cobre raspberry') / AliExpress 'copper heatsink kit'

### Fita dupla-face CONDUTORA TÉRMICA (equivalente 3M 8810 / fita térmica adesiva)
- **Specs:** Fita dupla-face de transferência térmica, tolerância típica -40 a ~120-150C. É o meio de fixação correto entre dissipador e a borda do LCD (melhor que a colinha que vem nos kits).
- **Por que é melhor:** Adesivo pensado para conduzir calor (não só colar). Removível/reposicionável, ao contrário da cola epóxi. Use para prender os dissipadores na moldura.
- **Compatibilidade:** Cortar tiras finas só para a borda; nunca deixar sobrar sobre a área transparente.
- **Preço:** ~R$ 25 a R$ 45 o rolo
- **Onde comprar (BR):** Mercado Livre: https://lista.mercadolivre.com.br/fita-dupla-face-termica-3m e https://lista.mercadolivre.com.br/fita-dupla-face-condutora-termica

### Pad térmico de silicone adesivo 1mm (PowerUP PU-PAD / Cooler Master, ~4.5-6 W/mK, 100x100mm)
- **Specs:** Silicone, condutividade 4.5-15 W/mK, ISOLANTE ELÉTRICO, aguenta ~150-200C. Corta-se com estilete no tamanho exato.
- **Por que é melhor:** Isolante elétrico - única opção segura para preencher o vão entre um dissipador e uma região que tenha trilhas/flex por perto. Acomoda superficies irregulares da moldura.
- **Compatibilidade:** Recortar tiras pequenas para a moldura; jamais sobre pixels ativos.
- **Preço:** ~R$ 30 a R$ 75 a folha 10x10cm
- **Onde comprar (BR):** PowerUP: https://www.powerupinfo.com.br/refrigeracao/thermal-pad/thermal-pad-termico-100x100-x-1.0mm-4.5wwk ; Mercado Livre: https://lista.mercadolivre.com.br/thermal-pad-1mm

### Fita de cobre adesiva (copper foil tape) 10mm x 20m
- **Specs:** Folha de cobre com adesivo condutivo; use como 'moldura' fina em volta da borda do vidro (fora da área útil) para espalhar/conduzir o calor lateralmente ate um dissipador afastado. CONDUTORA - manter longe de contatos.
- **Por que é melhor:** Espalha calor da borda quente do polarizador para uma área maior/mais fria (heat spreader), levando-o para longe do centro e do LCD ate um dissipador ventilado.
- **Compatibilidade:** Só na faixa de vidro fora do feixe; isolar dos contatos elétricos com Kapton.
- **Preço:** ~R$ 25 a R$ 40 o rolo
- **Onde comprar (BR):** Amazon BR: https://www.amazon.com.br/Condutora-Condutividade-Antiest%C3%A1tica-Resist%C3%AAncia-Temperatura/dp/B0DCP1783H ; Mercado Livre: https://lista.mercadolivre.com.br/fita-cobre-condutiva

### Cola térmica Arctic Alumina Thermal Adhesive (epóxi 2 partes, 5g)
- **Specs:** Epóxi de óxido de alumínio + nitreto de boro, ISOLANTE ELÉTRICO (não conduz eletricidade), cura permanente, resiste a ~150C. Fixação definitiva de dissipador quando a fita não segura.
- **Por que é melhor:** Isolante elétrico e boa condução; ideal se precisa colar dissipador de forma permanente e segura perto de eletrônica. Alternativa barata: 'cola pasta adesiva térmica 5g' (~R$ 15, Magazine Luiza) - porém verifique se é isolante.
- **Compatibilidade:** PERMANENTE - só use onde tem certeza; nunca perto/na área óptica.
- **Preço:** ~R$ 90 a R$ 140 (5g)
- **Onde comprar (BR):** WAZ (Belo Horizonte/MG, envia BR): https://www.waz.com.br/adesivo-termico-arctic-alumina-thermal-adhesive-5g-aata-5g-bulk-html/p

### Cooler/ventoinha pequena 5V (blower ou fan 25-40mm) OU base cooler de notebook
- **Specs:** Fluxo de ar direcionado ao bloco óptico/polarizador. A solução mais eficaz de todas para o filme polarizador.
- **Por que é melhor:** O calor está no filme (isolante) no caminho óptico - dissipador passivo na borda faz pouco. Ar movendo sobre o polarizador remove calor onde ele realmente está. Essencial combinar com limpeza do filtro de pó.
- **Compatibilidade:** Direcionar ar sem soprar poeira; não bloquear exaustão existente.
- **Preço:** Ventoinha ~R$ 15 a R$ 40 / base notebook ~R$ 40 a R$ 90
- **Onde comprar (BR):** Mercado Livre 'mini cooler 5v' / 'base cooler notebook'

**Avisos de compatibilidade:** ALERTA CRÍTICO DE ÁREA ATIVA: nunca cole dissipador, fita, pad ou cola sobre a janela transparente do LCD nem sobre a área útil do polarizador. Qualquer material no caminho óptico bloqueia luz, cria sombra/mancha escura na imagem, distorce foco e pode deixar resíduo/embaçado permanente nas optivas por outgassing do adesivo. Só se cola na MOLDURA/borda de vidro fora do feixe.

INSUFICIÊNCIA DA SOLUÇÃO PASSIVA (honestidade): o calor está no próprio filme polarizador, que é isolante térmico. Colar um dissipadorzinho na borda ajuda POUCO a resfriar o centro do filme, e pode ate ser contraproducente se conduzir calor para dentro do vidro do LCD. Dissipadores/pads resolvem bem a moldura, o driver e placas, mas para o polarizador em si as soluções que realmente funcionam são: (1) FLUXO DE AR direcionado (cooler/ventoinha soprando na região do bloco óptico) - de longe o mais eficaz; (2) trocar por um polarizador de vidro/inorgânico ('glass polarizer', suporta bem mais temperatura) - há kits no AliExpress ~R$30; (3) afastar o polarizador do LCD alguns milímetros (montado em vidro próprio) para poder resfria-lo isolado sem transmitir calor ao painel.

RISCO ELÉTRICO: cobre e algumas fitas 'térmicas' são CONDUTORAS - se tocarem os pinos do flex/driver do LCD causam curto. Perto de circuito use somente isolante elétrico (pad de silicone, Kapton, Arctic Alumina). Mantenha fita de cobre longe de contatos.

RISCO MECÂNICO: vidro do LCD e flex são frágeis; peso/tensão de um dissipador ou puxão de fita rígida podem trincar o painel. Use peças leves.

RISCO DE IRREVERSIBILIDADE: cola térmica epóxi (Arctic Alumina) e PERMANENTE - não da para remover sem quebrar a peça. Para algo que pode precisar trocar, prefira fita/pad removível.

RISCO DE PIORAR O AR: dissipador volumoso pode obstruir a passagem de ar e piorar o superaquecimento. Peça pequena + ar > peça grande parada.

**Confiança:** Média-alta. Diagnóstico do polarizador e princípios térmicos: alta confiança. Produtos e faixas de preço: confiança média - os links são páginas de busca/categoria do Mercado Livre/Amazon BR (estoque e preço mudam); confirme dimensões e preço no anúncio antes de comprar. Não consegui uma ficha técnica oficial do 'PFL7560' (aparenta ser projetor LCD genérico/importado de painel único); as recomendações valem para essa classe de aparelho, mas confirme o tamanho físico do seu bloco LCD antes de comprar dissipador.

**Notas:** COMO APLICAR (passo a passo, projetor LCD de painel único tipo PFL7560):

1) IDENTIFIQUE AS ZONAS. No bloco óptico, o LCD e um retangulo de vidro com uma 'janela' central transparente (área ativa = por onde a luz passa) e uma borda opaca de ~2-3 mm + uma moldura/suporte metálico ou plástico. O polarizador de ENTRADA (lado da lâmpada/LED) é o que mais queima. SÓ se trabalha na borda e na moldura.

2) ONDE COLAR (permitido): (a) na moldura metálica que prende o LCD, nas laterais fora do feixe; (b) numa faixa fininha da borda de vidro fora da área útil, usando fita de cobre como espalhador que leva o calor para um dissipador colocado ao lado, longe do caminho de luz. Oriente o dissipador para uma região onde exista ou onde você crie fluxo de ar.

3) ONDE NÃO ENCOSTAR (proibido): área ativa/janela transparente do LCD e do polarizador; pinos/flex do driver; qualquer ponto onde o material invada o cone de luz (gera sombra na tela). Deixe folga de segurança - a luz abre em cone, então mesmo a borda pode estar iluminada; teste projetando uma tela branca e veja se aparece sombra.

4) FIXAÇÃO: prefira fita dupla-face condutora térmica (removível). Perto de eletrônica use pad de silicone (isolante) ou Kapton por baixo. Só use cola epóxi (Arctic Alumina) se precisar de fixação permanente e há isolamento elétrico. Limpe a superficie com álcool isopropílico antes de colar. Pressione firme por ~30s.

5) DIREÇÃO DO CALOR: o objetivo e tirar calor da borda/moldura e leva-lo para LONGE do LCD, ate um ponto ventilado. Não 'aqueca' o LCD conduzindo calor do polarizador para dentro do vidro - por isso ar direto no polarizador supera qualquer dissipador passivo.

LIMITES DE TEMPERATURA: polarizador orgânico degrada tipicamente a partir de ~80-90C e a mancha aparece com exposição prolongada; meta = manter a superficie abaixo de ~60-70C. Fitas acrílicas/dupla-face: ~-40 a 120-150C. Pads de silicone: ~150-200C (bom). Arctic Alumina: cura permanente, ~150C. Sensores internos do projetor costumam desligar acima de ~85C.

ORDEM DE PRIORIDADE (mais eficaz -> menos): (1) limpar filtro de pó e garantir exaustão livre; (2) ventoinha/cooler soprando ar no bloco óptico/polarizador; (3) trocar por polarizador de vidro/inorgânico de maior temperatura (kit AliExpress ~R$30) ou afastar o polarizador do LCD; (4) só então dissipadores/fita/cobre na moldura como reforco. Se já queimou (mancha marrom fixa), o polarizador precisa ser TROCADO - dissipação não recupera filme queimado.

REALISMO/HONESTIDADE: em muitos desses projetores baratos o polarizador já vem laminado no LCD; separar/trocar da trabalho e há risco de arranhar/trincar o painel (LCD completo ~R$100 no AliExpress). Avalie custo do reparo vs. aparelho. Se optar por só 'gambiarra' térmica, saiba que ela reduz mas não elimina o risco enquanto o ar/temperatura da lâmpada não melhorar.

Fontes: Rafael Play Mobile (diagnóstico polarizador queimado) https://rafaelplaymobile.com/mancha-preta-na-tela-do-projetor-e-sujeira-ou-queimou-veja-como-resolver/ ; kits polarizador https://pt.aliexpress.com/item/1005006534365230.html ; discussão thermal pad vs paste (TI DLP) https://e2e.ti.com/support/dlp-products-group/dlp/f/dlp-products-forum/312330/dmd-heat-sink-pad-vs-paste-failure ; Arctic Alumina (isolante elétrico) https://www.arcticsilver.com/arctic_alumina_thermal_adhesive.htm e WAZ BR https://www.waz.com.br/adesivo-termico-arctic-alumina-thermal-adhesive-5g-aata-5g-bulk-html/p ; pad silicone https://www.powerupinfo.com.br/refrigeracao/thermal-pad/thermal-pad-termico-100x100-x-1.0mm-4.5wwk ; fita cobre https://www.amazon.com.br/Condutora-Condutividade-Antiest%C3%A1tica-Resist%C3%AAncia-Temperatura/dp/B0DCP1783H

## Limpeza e inspeção (filtro, óptica, duto)

**Segurança:** "1) SEMPRE desligue e DESCONECTE DA TOMADA antes de qualquer limpeza; o projetor não funciona/não deve ser mexido energizado. 2) CAPACITORES/FONTE: a fonte e chaveada (100/240V -> 35V 6.85A interno) e retem carga após desligar - aguarde alguns minutos e evite tocar a área da fonte e capacitores ao abrir. 3) NÃO OLHE para a lente/LED com o projetor ligado - a luz pode lesar os olhos (LED de 8000 lumens). 4) NÃO toque a ÁREA ATIVA do LCD nem a face do polarizador - dano permanente e irreversível. 5) CUIDADO com o PARAFUSO DO FILTRO: o manual alerta explicitamente 'não esquecer de recolocar' - filtro/tampa sem parafuso deixa poeira entrar sem filtro. 6) NADA de solventes/químicos (álcool, acetona, etanol, limpadores) na óptica ou carcaça - proibido pelo manual, danifica e infiltra. 7) Abrir o gabinete ANULA A GARANTIA (o manual proibe explicitamente); o filtro (seção 6.2) NÃO exige abrir e não afeta a garantia. 8) Deixe o aparelho ESFRIAR antes de manusear."

**Ferramentas:** Chave Phillips (para o parafuso da tampa do filtro e os parafusos do gabinete); Pincel/escova macia SECA para o filtro e poeira interna solta; Pera de ar (air blower) manual - preferível a ar comprimido em lata perto do LCD; Pano incluso na caixa OU pano de limpeza de óculos seco/microfibra limpa (lente e câmera de foco); Aspirador de pó em baixa potência (opcional, para poeira solta no duto/pas do soprador, sempre pelo lado externo); Flanela levemente umedecida com ÁGUA - somente para a carcaça externa; Câmera/celular para fotografar a orientação das peças antes de desmontar; Recipiente para separar os parafusos por posição (base vs I/O vs filtro)

**Passos:**
1. FILTRO DE POEIRA (rotina a cada 6 meses; a cada 3 meses em ambiente empoeirado). Passo 1 - Desligue o projetor, TIRE DA TOMADA e deixe esfriar (10-15 min). O filtro fica na PARTE INFERIOR da carcaça, junto da 'Entrada de ar' (item 3 da Vista inferior do manual). Passo 2 - Com uma chave Phillips, remova o parafuso da tampa do filtro. Passo 3 - Pressione a trava da tampa e puxe a tampa. Passo 4 - Retire o filtro do suporte. Passo 5 - Limpe SOMENTE com pincel/escova macia SECA (ou aspirador em baixa potência, pelo lado externo); não use água nem sopro que empurre poeira para dentro do gabinete. Passo 6 - Recoloque o filtro no suporte, encaixe a tampa ate a trava clicar e RECOLOQUE O PARAFUSO (o manual alerta em nota: 'não esquecer de colocar o parafuso' - filtro solto deixa entrar poeira sem filtrar e desalinha o fluxo).
2. ABRIR A CARCAÇA COM SEGURANÇA (procedimento AVANCADO, só se o filtro não resolveu manchas/poeira interna). AVISO: o manual proibe abrir ('Nunca abra o seu produto... implica em perda do direito a garantia') - fazer isso ANULA A GARANTIA e e por conta e risco. Passo 1 - Desligue e DESCONECTE DA TOMADA; a fonte e chaveada (entrada 100/240V, saída interna 35V 6.85A) e retem carga: aguarde vários minutos antes de tocar a placa, evite a área da fonte/capacitores. Passo 2 - Vire o projetor, remova os 4 parafusos que prendem o gabinete (nas laterais/base; há também os 4 pontos de fixação em suporte na base). Guarde os parafusos separados por posição (tamanhos diferentes - base vs I/O). Passo 3 - Separe a metade do gabinete com cuidado; solte conectores/flat cables da placa e do soprador com delicadeza, sem puxar pelos fios. Passo 4 - Fotografe cada etapa e a orientação de cada peça antes de remover - o motor óptico e sensível a orientação.
3. CAMINHO ÓPTICO - O QUE PODE E O QUE NÃO PODE. Motor óptico deste modelo: LCD TFT de painel único com POLARIZADOR (o teardown local confirma; a falha clássica desse conjunto e o polarizador superaquecer e gerar MANCHAS na tela / perda de brilho). PODE (com muito cuidado): soprar poeira solta com pera de ar (air blower) manual; passar pincel de lente MACIO nas superficies de VIDRO externas do bloco óptico e nas lentes; a regra e 'menos e mais' - prefira soprar/escovar a esfregar. NÃO PODE: tocar/esfregar a ÁREA ATIVA (região da imagem) do LCD e a face do POLARIZADOR - o revestimento descasca e o dano é permanente; REMOVER o painel LCD do prisma - perde-se o alinhamento calibrado de fábrica e não se recupera sem equipamento; usar cotonete/Q-tip (solta fibras que aparecem projetadas); usar QUALQUER solvente/químico (álcool, acetona, etanol, limpadores) - o manual proibe: danificam e infiltram, e etcham/mancham a óptica. Se precisar remover polarizadores para limpar, marque a posição/orientação de cada um antes (mas isso já é serviço de técnico).
4. LENTE E CÂMERA DE FOCO. Conforme o manual (seção 6.1): com o projetor DESLIGADO, use SOMENTE o pano incluso na caixa OU um pano de limpeza de óculos SECO, de forma cuidadosa. Limpe a lente frontal com movimento leve do centro para a borda. Use O MESMO pano seco para limpar a lente da CÂMERA DE FOCO (o pontinho ao lado da lente, item 2 da Vista frontal - e ela que faz foco/keystone automáticos; suja, o foco automático falha). Nada de água, spray ou solvente na lente. (Nota: guias de fabricantes preferem caneta-lente/microfibra dedicada a pano de óculos comum; sigo aqui a recomendação explícita do manual Intelbras, mas se tiver uma caneta de lente/pano microfibra limpo e macio, e igualmente seguro e ate preferível.)
5. REMONTAGEM. Passo 1 - Antes de fechar, confirme que nenhum flat cable ficou solto e que o painel/polarizador não foi tocado na área ativa. Passo 2 - Reconecte todos os conectores do soprador e da placa na mesma orientação (use as fotos). Passo 3 - Encaixe as metades do gabinete sem prensar fios; recoloque os 4 parafusos do gabinete em suas posições originais (não troque tamanhos). Passo 4 - RECOLOQUE o parafuso da tampa do FILTRO se você mexeu nele. Passo 5 - Reconecte a energia, ligue e verifique: imagem sem manchas novas, foco automático funcionando, e - importante - confira que os sopradores estão girando e o ar sai quente pela lateral (grade). Passo 6 - Deixe rodar 10-15 min observando se não há desligamento por superaquecimento (o firmware desliga em ~45 C de emergência).

> **CORREÇÃO (2026-10-29):** são 3 ventiladores (2 sopradores DFH8030S controlados + 1 axial no exaustor do
> LED, sem controle), não 2 DFH8025S ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3).

**O que inspecionar:** "DUTO E SOPRADOR (inspeção): o modelo tem 2 sopradores (blowers) DFH8025S puxando ar pela 'Entrada de ar' inferior (onde fica o filtro) e expelindo pela grade lateral. Inspecione: (1) POEIRA ACUMULADA nas pas/rotor de cada blower - poeira nas palhetas desbalanceia e reduz vazão; limpe com pincel seco/aspirador leve, girando o rotor com o dedo, sem forcar o eixo. (2) OBSTRUÇÃO no duto entre a entrada inferior, os sopradores e a saída lateral - cotão/pelos formam 'tampão'. (3) ENTRADA de ar (base) e SAÍDA (grade lateral) desbloqueadas - o manual proibe bloquear as áreas de ventilação; mantenha 15-20 cm livres e nunca sobre superficie macia/móvel que tape a base. (4) Sinais de superaquecimento passado: manchas na tela, perda de brilho - indicam que o polarizador já sofreu (a entrada de ar entupida e a causa-raiz apontada no teardown; os NTCs ficam perto da óptica e o firmware faz dimming a partir de 27 C e desliga em 45 C). (5) Rotor travado/ruído anormal do fan - o firmware desliga por 'fan monitor' se detectar fan anormal; um blower que não gira exige troca."

**Notas:** "Guia entregue em 5 blocos (steps): (1) filtro de poeira, (2) abrir a carcaça, (3) caminho óptico LCD/polarizador/prisma, (4) lente e câmera de foco, (5) remontagem; mais a inspeção de duto/soprador (whatToInspect) e a segurança (safety). SUPOSIÇÕES E TRADEOFFS que exponho ao usuário: (a) O manual só cobre oficialmente a limpeza do FILTRO (chave Phillips, sem abrir) e da LENTE/câmera com pano seco - isso e o procedimento SEGURO e recomendado, resolve a maioria dos casos de superaquecimento/manchas e NÃO anula garantia. (b) Abrir o gabinete para limpar o caminho óptico e o soprador e um procedimento AVANCADO que o manual proibe e que ANULA A GARANTIA - só vale a pena se já houver manchas/poeira interna e o aparelho estiver fora de garantia; incluído por pedido explícito, com todos os avisos. (c) O motor óptico foi tratado como LCD TFT com polarizador (spec oficial Intelbras + teardown local); o firmware genérico 'bigfish' também carrega chaves de DLP, mas adotamos LCD. (d) Há um conflito de fontes na limpeza da lente: o manual Intelbras recomenda pano de óculos seco, enquanto guias de fabricantes (XGIMI) desaconselham pano de óculos comum e preferem caneta-lente/microfibra; segui o manual mas sinalizei que microfibra limpa dedicada e igualmente segura. (e) Causa-raiz mais provável de manchas neste modelo, segundo o teardown local: entrada de ar/filtro obstruidos -> superaquecimento do polarizador; por isso a limpeza de filtro + inspeção de fluxo de ar e a ação de maior impacto. Cadência do manual: filtro a cada 6 meses (a cada 3 meses em ambiente muito empoeirado)."

**Fontes:** Manual do usuário Intelbras PFL7560 (local): referencia/Manual_PFL7560_03-26_site_0.pdf - seção 'Cuidados e segurança' (p.3), seção 6 'Limpeza do projetor' 6.1 Lente e 6.2 Filtro de poeira (p.11), Vista inferior/Entrada de ar (p.8), Especificações técnicas (p.5); Teardown de hardware local (específico deste aparelho): docs/01-teardown-tecnico.md e 02-sistema-térmico-atual.md - confirma SoC HiSilicon Hi3751 V553, ODM Newlink, motor LCD TFT com polarizador, 2x soprador DFH8025S, sensores NTC perto da óptica e limiares térmicos; https://lushprojects.com/blog/2010/06/cleaning-a-projector/ - método de abrir e limpar óptica/LCD, marcar orientação, pincel macio melhor que ar comprimido para poeira incrustada; https://www.avsforum.com/threads/attention-lcd-owners-fix-your-color-uniformity-problems-by-cleaning.572889/ - mantra 'less is more', não remover os LCDs, risco de descascar o revestimento do polarizador; https://www.avsforum.com/threads/any-way-to-diy-cleaning-of-dirty-internal-optics.1369211/ - evitar cotonetes (fibras), sem solventes, panos de trama fechada; https://global.xgimi.com/blogs/tips-tutorials/how-to-maintain-and-clean-your-projector - limpeza de filtro, ventilação/fan, evitar toalha de papel e materiais raspantes na lente; https://www.ifixit.com/Guide/Polarizer+Replacement+for+Tri-LCD+Projectors/147913 - referência de parafusos por tamanho e cuidado ao levantar a tampa do bloco óptico sem arranhar polarizadores

## Resfriamento externo (sem abrir)

**Segurança:** NÃO abrir o projetor (o manual alerta que abrir/trocar peças danifica e perde a garantia) - todas as medidas aqui são externas. NUNCA soprar ar contra as saídas laterais de exaustão: isso prende o ar quente dentro e PIORA o superaquecimento; sopre apenas na entrada inferior. Nunca apoiar o projetor sobre pano, tapete, almofada ou mesa lisa colada - bloqueia a entrada de ar de baixo. Ao medir com termômetro de espeto, medir o fluxo de ar, não encostar na carcaça quente. Manter faixa de operação 0-40 C. Limpar o filtro inferior antes de tudo (a cada 3 meses em ambiente com poeira) - filtro entupido é a maior causa de sobreaquecimento e nenhuma medida externa compensa.

**Ferramentas:** Base ventilada de notebook que o usuário já possui (grátis) - insuflar ar frio na entrada inferior; Mini ventilador USB de mesa 2-10W, ~R$ 29-58 (Mercado Livre 'mini ventilador USB'); Mini soprador/turbo USB-C para jato dirigido, ~R$ 50-80 (Mercado Livre 'mini soprador de ar turbo' / Amazon.com.br); Cooler de notebook dedicado: Oberon OR-SP252 (~R$44), C3Tech NBC-70BK (6 fans, -8C), C3Tech NBC-300BK (5 fans, 65 CFM); Termômetro infravermelho aponta-e-lê ou termômetro de espeto de cozinha para o protocolo de medição; Calços/pés de borracha adesivos (5-10 mm) para elevar o projetor e criar câmara de ar (plenum) sob a entrada

**Passos:**
1. Padronize condições: mesma sala/brilho/conteúdo; anote a temperatura ambiente; deixe o projetor 30 min ligado para estabilizar.
2. Meça a temperatura do ar na saída lateral a 2-3 cm (termômetro IR ou espeto no fluxo de ar, sem encostar na carcaça); registre como linha de base e calcule o Delta = T_saida - T_ambiente.
3. Aplique UMA medida por vez (ex.: ligar a base ventilada) e aguarde 15-20 min para reestabilizar.
4. Meça de novo no mesmo ponto e compare o Delta; se caiu, a medida ajudou.
5. Repita isoladamente para cada medida (base -> base+mini USB -> elevação -> ambiente mais frio), anotando tudo numa tabela.
6. Fique com as combinações de menor Delta com menor custo/ruído; sem termômetro use o teste da mão a 3 cm por 5 s comparando antes/depois.

**O que inspecionar:** Manual PFL7560 seção 3.5 Vista inferior (item 3 = entrada de ar; itens 1-2 = ajuste de altura frontal; item 4 = fixação em suporte), seção 3.3 Vistas laterais (saídas dos alto-falantes/exaustão lateral), seção de limpeza (filtro na parte de baixo, aviso de obstrução/sobreaquecimento, limpeza a cada 3 meses), especificações (operação 0-40 C; dimensões 28,83 x 18,04 x 29,6 cm).

**Notas:** GUIA DE RESFRIAMENTO EXTERNO — Projetor Intelbras PFL7560 (sem abrir o aparelho)

DADOS CONFIRMADOS NO MANUAL (referencia/Manual_PFL7560_03-26_site_0.pdf)
- Seção 3.5 "Vista inferior": item 3 = ENTRADA DE AR na parte de baixo; itens 1 e 2 = apoio/trava de ajuste de altura (pé frontal); item 4 = pontos de fixação em suporte.
- Seção 3.3 "Vistas laterais": as aberturas nas laterais incluem as saídas dos alto-falantes; é por onde sai o ar quente (exaustão lateral).
- O FILTRO fica na parte de baixo, junto à entrada de ar (removível com chave/parafuso). O manual (seção de limpeza) alerta: "A obstrução da entrada de ar ou exaustor pode afetar a ventilação e o resfriamento... sobreaquecimento... manchas na tela, perda de potência luminosa" e recomenda limpeza a cada 3 meses em ambientes com poeira.
- Temperatura de operação especificada: 0 °C a 40 °C. Dimensões: 28,83 (L) x 18,04 (A) x 29,6 (P) cm.
- REGRA DE OURO: como a entrada é embaixo, o projetor NÃO pode ficar apoiado direto em superfície lisa/mesa que "tape" as fendas inferiores, nem sobre pano/tecido. Ele precisa de vão livre embaixo. Antes de qualquer melhoria, limpe o filtro inferior — filtro sujo é a causa nº1 de superaquecimento e nenhuma medida externa compensa filtro entupido.

PRINCÍPIO GERAL: você quer EMPURRAR ar frio para dentro da entrada (embaixo) e NUNCA obstruir/soprar contra as saídas laterais (o ar quente precisa escapar). Fluxo desejado: ar frio entra por baixo → atravessa o aparelho → sai quente pelas laterais → longe do projetor.

============================================================
(1) COMO POSICIONAR A BASE VENTILADA DE NOTEBOOK
============================================================
Objetivo: usar os coolers da base para insuflar (empurrar) ar frio na entrada inferior do projetor, sem tapar as laterais.

- Confirme a direção do fluxo da base: a maioria das bases de notebook SOPRA PARA CIMA (ventiladores puxam ar de baixo e jogam para cima, contra o notebook). Isso é exatamente o que você quer: coloque o projetor EM CIMA da base, com a entrada de ar inferior do projetor alinhada sobre os ventiladores da base. Teste com a mão sobre a grade da base para sentir se o ar sai para cima; se sair, está certo.
- Alinhe os coolers da base com a área central/traseira da base do projetor, onde ficam as fendas de entrada. Evite que a moldura elevada da base fique tapando as fendas — se necessário, apoie o projetor sobre os cantos/pés e deixe o miolo vazado sobre os ventiladores.
- Mantenha os PÉS DE BORRACHA do projetor apoiados (não deixe a base inferior colada na malha da base do notebook). Se a base for muito plana, use 2 calços finos (rolhas, tampinhas, pés de borracha adesivos de 5–10 mm) nos cantos do projetor para criar um "plenum" (câmara de ar) entre a base ventilada e a entrada — assim o ar soprado se espalha e entra melhor, em vez de bater e voltar.
- NÃO cubra as laterais: a base do notebook costuma ter batentes/apoios nas bordas para o notebook não escorregar. Posicione o projetor de forma que esses batentes NÃO fiquem na frente das saídas laterais de ar quente. Deixe as duas laterais totalmente abertas ao ambiente.
- Ligue a base na velocidade máxima (ou regule pelo controle, se tiver). Bases boas movem ar de sobra para um aparelho desse porte.
- Custo: R$ 0 (você já tem). É a PRIMEIRA e mais barata melhoria — faça e meça antes de comprar qualquer coisa.

============================================================
(2) VENTILADOR/COOLER EXTERNO USB APONTADO PARA A ENTRADA
============================================================
Só compre se, após medir (protocolo abaixo), a base sozinha não baixar o suficiente a temperatura de saída. Opções do mais barato/prático ao mais robusto:

OPÇÃO A — Mini ventilador USB de mesa (mais simples, ~R$ 30–60)
- Um mini ventilador USB (2–3 velocidades, 2–10 W) posicionado ao lado do projetor, soprando ar do ambiente por baixo/na direção da entrada inferior. Alimente pela própria porta USB-A do projetor ou por um carregador de celular.
- Onde comprar: Mercado Livre ("mini ventilador USB", a partir de ~R$ 29–58) — https://lista.mercadolivre.com.br/mini-ventilador-usb
- Cuidado: aponte para a ENTRADA (baixo), nunca contra as saídas laterais. Soprar contra a exaustão prende o ar quente dentro do aparelho e PIORA.

OPÇÃO B — Mini soprador/turbo USB (jato concentrado, ~R$ 50–80)
- Modelos "mini soprador turbo" (recarregável USB-C, jato forte/direcionado) são ótimos para empurrar um fluxo concentrado exatamente na fenda de entrada, quando há pouco espaço embaixo.
- Onde: Mercado Livre "mini soprador de ar turbo" — https://lista.mercadolivre.com.br/mini-soprador-de-ar-turbo ; Amazon.com.br (Mini Soprador Ventilador Turbo USB-C).
- Contra: alguns são a bateria (autonomia curta) e barulhentos no máximo. Prefira os que funcionam ligados no cabo continuamente.

OPÇÃO C — Segunda base/cooler de notebook dedicado como insuflador (melhor custo-benefício de fluxo, ~R$ 44–120)
- Coolers com muitos ventiladores movem muito ar e são feitos para ligar direto no USB. Referências no BR:
  • Oberon OR-SP252 — silencioso, compacto, a partir de ~R$ 44 (Mercado Livre).
  • C3Tech NBC-70BK — 6 ventiladores, reduz ~8 °C em notebooks gamer (bom fluxo).
  • C3Tech NBC-300BK — 5 ventiladores, ~65 CFM, ruído 26–30 dBA.
- Onde: Mercado Livre (https://lista.mercadolivre.com.br/cooler-notebook), Leroy Merlin, lojas de informática.
- Uso: como "cama de ar" adicional sob o projetor OU de lado soprando para a entrada.

RECOMENDAÇÃO: comece pela base que você já tem (grátis). Se precisar de reforço, a Opção A (mini USB de mesa) é a melhor relação custo/benefício. Opção B só se o vão embaixo for muito apertado e você precisar de jato dirigido.

============================================================
(3) ORIENTAÇÃO / ELEVAÇÃO PARA MELHOR CONVECÇÃO
============================================================
- ELEVE o projetor: deixe um vão de ar livre embaixo (mín. ~3–5 cm) para a entrada inferior "respirar" mesmo sem ventilador. Use a própria base ventilada, ou um suporte vazado, ou 4 pés/calços nos cantos. Nunca sobre mesa lisa colada, nunca sobre tapete/pano/almofada (bloqueia a entrada).
- Não incline demais: mantenha o projetor o mais nivelado possível (o ajuste de altura frontal só o necessário para o keystone). Inclinações grandes bagunçam o fluxo interno e o caminho da luz.
- Convecção natural ajuda: como o ar quente sobe e a exaustão é lateral, deixe as laterais totalmente desobstruídas e com "céu aberto" acima. Não coloque objetos, nem outro equipamento quente (receiver, notebook, roteador) encostados nas laterais ou logo acima.
- Oriente o aparelho de modo que as saídas laterais NÃO apontem para uma parede próxima nem para um canto — o ar quente recircula e volta a ser puxado pela entrada.

============================================================
(4) AMBIENTE
============================================================
- Temperatura da sala: faixa de operação do PFL7560 é 0–40 °C, mas o resfriamento é mais eficiente entre ~18–24 °C. Em dias quentes, use ar-condicionado/ventilador de ambiente ou a hora mais fresca. Cada grau a menos na sala vira grau a menos na saída.
- Não encaixote: nunca dentro de móvel fechado, rack fechado, prateleira apertada ou nicho. O calor fica preso.
- Distância de paredes e objetos: deixe no mínimo 20–30 cm livres em volta de TODAS as aberturas; o ideal é ~50 cm de folga ao redor, especialmente nas laterais (saídas) e embaixo (entrada).
- Sol e fontes de calor: fora da luz solar direta e longe de outros aparelhos que esquentam.
- Poeira: ambiente empoeirado entope o filtro inferior rápido → limpe a cada 3 meses (manual). Filtro/entrada limpos valem mais que qualquer ventilador extra.
- Modo Eco/brilho: se o menu tiver modo econômico/brilho reduzido, ele diminui o calor gerado — use quando o ambiente permitir.

============================================================
(5) PROTOCOLO DE TESTE (mede se cada medida realmente ajuda)
============================================================
Ideia: medir a temperatura do AR QUENTE que sai pela lateral, em condições iguais, antes e depois de cada mudança. Uma medida de cada vez (senão você não sabe o que funcionou).

Instrumento: termômetro comum de cozinha/culinária (espeto) ou termômetro infravermelho aponta-e-lê (~R$ 30–60, "termômetro infravermelho" no ML). Sem termômetro, use o teste da mão (menos preciso, mas serve para comparar).

PASSO A PASSO:
1) Padronize as condições: mesma sala, mesma temperatura ambiente (anote-a), mesmo conteúdo/brilho na tela, mesmo tempo ligado. Deixe o projetor aquecer por 30 min antes de medir (regime estável).
2) Meça o AMBIENTE: anote a temperatura da sala (T_ambiente).
3) Meça a SAÍDA (linha de base): a ~2–3 cm da saída lateral de ar quente, meça a temperatura do ar. Com IR, aponte para a grade de saída. Com termômetro de espeto, segure a ponta no fluxo de ar (não encoste na carcaça). Anote T_saida_base. O que importa é o DELTA = T_saida − T_ambiente (isola o efeito do dia estar mais quente/frio).
4) Aplique UMA medida (ex.: ligar a base ventilada). Espere 15–20 min para reestabilizar.
5) Meça de novo no mesmo ponto. Anote. Compare o DELTA novo com o de base. Se o delta caiu (ex.: de 22 °C acima do ambiente para 16 °C acima), a medida ajudou.
6) Repita para cada medida isolada (base sozinha → base + mini USB → elevação maior → etc.), sempre uma de cada vez, para saber quanto cada uma contribui.
7) Registre numa tabelinha: [Medida | T_ambiente | T_saida | Delta]. Fique com as combinações que dão o menor delta com o menor custo/ruído.

Teste da MÃO (sem termômetro): ponha a mão a ~3 cm da saída lateral por 5 s. Classifique: morno / quente / "não aguento". Compare a mesma sensação antes e depois. Menos científico, mas detecta melhoras grandes.

Alvo prático: quanto menor a temperatura de saída (e menor o delta sobre o ambiente), melhor. Se o aparelho parar de desligar sozinho / sumirem manchas na tela / o brilho se manter, o objetivo térmico foi atingido.

SEQUÊNCIA RECOMENDADA (barato primeiro): (a) limpar filtro inferior → (b) elevar com vão de ar + laterais livres + afastar de paredes → (c) ligar a base ventilada que você já tem → medir → (d) só se preciso, comprar mini ventilador/soprador USB → medir de novo.

**Fontes:** referencia/Manual_PFL7560_03-26_site_0.pdf (seções 3.3 Vistas laterais, 3.5 Vista inferior, limpeza/filtro, especificações); https://aurzen.com/pt/blogs/news-discoveries/how-to-prevent-overheating-in-your-projector; https://blog.vrbrasil.com/5-fatores-superaquecimento-do-projetor/; https://techminuto.com.br/melhores-bases-para-notebook/; https://lista.mercadolivre.com.br/cooler-notebook; https://lista.mercadolivre.com.br/mini-ventilador-usb; https://lista.mercadolivre.com.br/mini-soprador-de-ar-turbo; https://www.amazon.com.br/Mini-Soprador-Ventilador-Turbo-Recarreg%C3%A1vel/dp/B0F64M837G
