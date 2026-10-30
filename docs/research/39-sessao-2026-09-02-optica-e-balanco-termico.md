# 39 - Sessão 2026-09-02/03: reparo óptico executado e auditoria do balanço térmico

Sessão longa, com o aparelho **aberto na bancada**, cobrindo: a 3ª troca de polarizador, a limpeza das
Fresnel, a orientação das peças ópticas, e uma **auditoria adversarial do balanço térmico** que corrigiu
seis registros do repositório — dois deles capazes de fazer o dono comprar peça errada.

A geometria do motor óptico e o procedimento de troca estão no
[doc 38](38-motor-optico-e-troca-do-polarizador.md). Este doc registra **o que foi feito** e **o que a
auditoria derrubou**.

**Convenção:** `OBSERVADO` = visto/feito neste aparelho nesta sessão. `PROVADO` = citação literal
verificada em fonte primária. `REFUTADO` = registro anterior do repositório derrubado com evidência.
`ABERTO` = não se sabe, e está dito que não se sabe.

> **CORREÇÕES POSTERIORES (2026-10-29, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md))** —
> o que este doc deixou aberto e já fechou, e o que mudou de leitura:
> - **OPT-S7 FECHADO:** o NTC do `gtt1` (`zysys.env_temp`, coluna `optica_C`) é um termistor encapsulado
>   num olhal parafusado no topo do **bloco dissipador do LED**. Nenhum sensor mede o polarizador/LCD.
>   Onde este doc chama o `gtt1` de "óptica" ou o usa como proxy do polarizador, leia "bloco do LED"
>   (doc 40 §3).
> - **OPT-S6 FECHADO:** 3 ventiladores — os 2 sopradores `DFH8030S` 12 V 0,45 A que a política controla
>   (`gfc` = 2) e 1 axial no exaustor do LED, sem controle. **OPT-S5 FECHADO:** modelo `DFH8030S`
>   `PROVADO` pela etiqueta (doc 40 §4).
> - **A medição da §4.1 ganhou uma segunda, e uma ressalva.** Em 2026-10-29, com pasta térmica nova entre o
>   LED e o bloco, o `gtt1` ficou em 65,8 °C em regime com a sala a 34 °C (delta 31,80 contra 23,63 aqui:
>   +8,17 °C). Mas o `gtt0` lê **abaixo** da sala anotada nas duas sessões, o que põe a âncora de ambiente em
>   dúvida; pela placa como referência a diferença cai para +1,6 °C. Os boots ficaram misturados e esta base
>   pode ter tido ventilador externo. Os +8 °C são compatíveis com a pasta funcionando (mais calor do LED
>   chega ao bloco onde está o NTC). A escada atuou no uso normal (brilho 944-974), e a maior leitura real
>   foi 68,2 °C: continua sem `WARNING` real registrado (doc 40 §2).

---

## 1. O que foi executado

| Ação | Resultado |
|---|---|
| **Troca do polarizador de entrada** (3ª peça; contagem a confirmar) | Peça TD98 136x85 instalada. Drop-in confirmado: mesmo tamanho, mesma espessura, **mesmo eixo** (verificado por sobreposição), sem películas protetoras |
| **Limpeza das duas Fresnel** | **A opacidade saiu por completo.** Era **depósito**, não crazing nem degradação. As Fresnel **não estão danificadas** |
| **Orientação das Fresnel** | Resolvida pelo dono na bancada (OPT-S4 fechado do lado prático) |
| **Inspeção do espelho de projeção** | Sem manchas. Colado de fábrica, nunca removido |
| **Verificação dos ventiladores** | Todos conectados corretamente à placa |
| **POL-S1** | **FECHADO** — ver [doc 38](38-motor-optico-e-troca-do-polarizador.md) |

### 1.1. A limpeza das Fresnel: resultado negativo que virou positivo

O projeto passou por um ciclo de cautela grande antes da limpeza, porque o dono havia usado **álcool
isopropílico** numa limpeza anterior e a peça estava "meio opaca em alguns cantos" — quadro compatível
com *crazing* (microfissuras por solvente sob tensão), que é **irreversível**.

**O resultado empírico encerrou a dúvida: a sujeira saiu e a peça está boa.** Era depósito.

O levantamento, ainda assim, deixou um dado que vale guardar para a próxima vez:

> `PROVADO` (*Polymers* 2023, 15, 1375, "Crazing Initiation and Growth in PMMA under Effects of Alcohol
> and Stress"): PMMA **sem tensão** + álcool **não trinca** — incha e distorce. PMMA **com tensão
> residual** (peça moldada, bordas e raiz dos sulcos) tem a tensão crítica de crazing derrubada de
> **31,4 MPa para 22,8 MPa**: a sensibilidade triplica. **Álcool a 75% causa praticamente o mesmo dano
> que a 95%** — diluir não protege.
>
> `PROVADO`: o próprio fabricante do acrílico (Rohm/Polyvantis) **se contradiz na página oficial** —
> recomenda isopropanol num lugar e proíbe álcool em outro. A tabela que "libera" IPA testa a **10%** e
> em amostra **sem tensão**.
>
> `PROVADO` (Covestro): trocar para policarbonato não resolveria — strain crítico do PC em isopropanol é
> **1,21%**, com "reduções massivas de resistência".
>
> **Proibição unânime em todas as fontes de fabricante:** acetona, amônia (limpa-vidros comum), metanol,
> n-propanol, MEK, tolueno.
>
> **Regra que sobrou:** limpeza a seco (pera de ar + pincel macio) é segura sob qualquer hipótese. A
> **face ranhurada nunca deve ser inundada** — o líquido entra na raiz do sulco por capilaridade, não sai
> por gravidade nem com pano, e o resíduo vira armadilha permanente de poeira **exatamente na feição que
> É a função óptica da peça**. Teste de molhar só é interpretável na **face lisa**.

### 1.2. Orientação do vidro de isolamento térmico

`PROVADO` (`CN109164667A`, texto literal): **face espelhada para o LED, face polarizadora para o LCD**.

```
所述隔热玻璃30的反射镜面301靠近所述LED点光源10…；所述隔热玻璃30的偏光镜面302靠近LCD屏40
```

E a mesma patente dá o **porquê**, que é o argumento que decide independentemente da fonte:
`所述反射镜面301用于反射s极光…减少无用的S极光进入LCD屏40，从而降低LCD屏40的温度` — a face refletora
existe para **devolver a polarização S à cavidade antes de ela ser absorvida**.

**Invertido, a luz atravessa primeiro o filme polarizador** — que absorve ~50% e converte em calor **no
próprio filme** — e só depois encontra o espelho, que já não tem o que reciclar. Ou seja: montar ao
contrário não é só cor errada, **é jogar a carga térmica inteira no filme orgânico**, que é a peça que
este aparelho já consumiu três vezes.

---

## 2. Auditoria do balanço térmico: seis registros do repositório derrubados

Auditoria adversarial sobre 25 afirmações extraídas dos docs 02/03/07/09/27/34/38 e do BRIEF.

### 2.1. Os sopradores são CENTRÍFUGOS, não axiais (`REFUTADO`)

> **Escopo (2026-10-29):** vale para os **2 sopradores** que a política controla. O 3º ventilador, no
> exaustor do dissipador do LED (§2.3), é axial ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3).

O [doc 07](07-hardware-upgrade.md#sopradoresventiladores-troca) afirma que o ventilador de fábrica é
**axial 80x80x25** e **recomenda comprar Delta AFB0812SH / AFB0824SH, com link e preço**.

**As fotos do próprio repositório mostram um soprador centrífugo**, sem margem: rotor tipo gaiola de
esquilo com dezenas de pás curtas, carcaça em voluta e **saída tangencial** lateral
(`media/teardown-04-blower-removido.jpg`, `teardown-05-blowers-dfh8025s.jpg`).

**Custo evitado:** 2 ventiladores axiais que não montam (R$ 90–180) mais uma abertura de chassi inútil.

O aviso nº 4 daquela mesma seção já dizia *"só considere blower se, ao abrir, você constatar que a peça é
realmente centrífuga"*. **A ressalva estava certa e a recomendação principal, errada.**

### 2.2. O modelo é `DFH8030S`, não `DFH8025S` (`PROVADO` em foto)

Etiqueta lida em `media/teardown-05-blowers-dfh8025s.jpg`, ampliada e girada:
**`D-FAN` / `DC BRUSHLESS FAN` / `MODEL:DFH8030S` / `DC 12V --- 0,45A` / `Dongguan Xingdong`.**

Duas correções ao registro anterior: o dígito é **30**, não 25 (**80x80x30 mm**), e a marca é **`D-FAN`**
— o `COFN` que o doc 27 registra foi leitura errada do logo.

**Consumo: 5,4 W por unidade, 10,8 W os dois**, num aparelho cuja fonte é de ~240 W (etiqueta, não
medição).

**Importa porque 25 mm e 30 mm não são intercambiáveis no berço** — e porque os candidatos centrífugos
plausíveis do mercado (Delta BFB0812HH, Sunon PMB1208PYB1, San Ace 9BMB) são **80x80x32**, 2 mm mais
grossos. Confirmação na etiqueta física continua valendo como conferência (**OPT-S5**, [ABERTURA]).
**OPT-S5 FECHADO em 2026-10-29:** `DFH8030S`, 12 V, 0,45 A, `PROVADO` pela etiqueta
([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §4).

### 2.3. Há TRÊS ventiladores, não dois (contradição interna; FECHADO em 2026-10-29, OPT-S6)

| Doc | Afirma |
|---|---|
| [`27`](27-teardown-cabo-gnd-ntc.md) | *"Não há Peltier/TEC nem terceiro ventilador — refrigeração é passiva + 2 sopradores"* |
| [`38`](38-motor-optico-e-troca-do-polarizador.md) §1 | LED tem **fan axial próprio**, separado dos dois blowers (`OBSERVADO` na bancada) |

Nenhuma nota reconcilia as duas. O doc 38 é mais recente e é observação direta, mas o total não foi
recontado com o aparelho aberto. **FECHADO em 2026-10-29 (OPT-S6):** são 3, os 2 sopradores controlados e
1 axial no exaustor do LED ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3). **Qualquer conta de vazão, qualquer swap e qualquer furação de chassi
parte de um mapa térmico errado enquanto isso não fechar** (**OPT-S6**).

### 2.4. "O teto do software foi atingido" — `REFUTADO`

Tese tentadora: *o polarizador queimou de novo COM a correção completa ativa, logo o gargalo é hardware.*

O critério do [doc 03](03-causa-raiz-e-limites.md):

> *"Se, com **brilho reduzido**, fans a 100% desde cedo e airflow externo bom, o aparelho **ainda** cozinha
> em 10 min, o gargalo é hardware."*

**É conjuntivo — exige as três condições simultâneas. O brilho nunca foi reduzido.**

Pior: `PROVADO` que de **2026-07-05 a 2026-07-29** a build travou `POLICY_BRIGHTNESS` em `1000`, enquanto
o loop de fábrica mirava **~981**. **Durante 24 dias a correção térmica aumentou a fonte de calor no
polarizador.** A escada de brilho só existe desde 2026-07-29.

**Consequência:** declarar "é hardware" hoje autoriza compra de soprador e furação de chassi — irreversível,
quebra a vedação contra poeira do caminho de luz — sem que o teto do software tenha sido tocado.

### 2.5. O braço experimental dos ventiladores nunca foi rodado (`PROVADO`)

O doc 03 pediu, em julho: *"ler os NTCs ao vivo durante um aquecimento de 10 min, **com e sem fans
forçados a 100%** e com brilho reduzido, para medir quanto cada alavanca realmente move a temperatura."*

| Alavanca | Medida no `gtt1`? |
|---|---|
| **Brilho** | **Sim** — 1000→900 deu `-4,34 °C`, ~0,43 °C por 1% |
| **Ventiladores** | **Não. Nunca.** |

Varredura confirmou: **todo TSV do repositório com coluna de fan tem valor único 1000/1000**. O único
registro com fan diferente (`evidencias/2026-07-09/snapshot-antes.txt`, 555/559) é da config stock, onde
`gtt0 == gtt1 == 26360 mC` — **o sensor estava cego**.

Os `-9,5 °C` que o projeto atribui aos ventiladores são **exclusivamente exaustão**, medidos com o `gtt1`
ainda cego. **Não existe, e nunca existiu, um par `gtt1`(fans 55%) vs `gtt1`(fans 100%).**

É exatamente o dado que discrimina a hipótese do dono ("as ventoinhas são fracas") da hipótese alternativa
("o ar não passa onde precisa").

### 2.6. As três premissas ausentes que invalidam as comparações térmicas

1. **A temperatura ambiente NUNCA foi medida** em nenhuma das quatro medições de exaustão
   (46,7 / 41,9 / 37,2 / 32,9 °C). O protocolo do doc 07 exige (*"Meça o AMBIENTE: anote a temperatura da
   sala"*) e não foi seguido. **Sem T_ambiente, todo delta do repositório mede o dia, não o aparelho.**
2. **O IR foi apontado para a grade plástica**, não para o ar. A grade fica entre o ar quente por dentro e
   a sala por fora, e tem emissividade desconhecida: **lê abaixo do ar real**. Isso infla artificialmente
   o delta `gtt1 - exaustão`.
3. **`termometro-antes.txt` não é medição de 2026-07-09** — a primeira linha do próprio arquivo declara
   outra origem.

### 2.7. O argumento "não é vazão, é acoplamento" — `REBAIXADO`

Argumento usado nesta sessão: *o ar sai a 37 °C e a óptica está a 65 °C; se a vazão fosse o gargalo o ar
sairia mais quente; logo é acoplamento local, não vazão.*

**Não se sustenta como prova.** Três motivos:

- Trata as duas resistências como **em série**, o que só vale se o mesmo ar que sai pela grade for o ar que
  banha o polarizador. A outra metade da própria análise sustenta o oposto (caminhos separados). **As duas
  não podem ser verdade juntas.**
- Depende de T_ambiente, que não existe (§2.6.1).
- Depende da exaustão medida, que está viesada para baixo (§2.6.2). Corrigindo o viés, a razão cai de
  ~2:1 para perto de 1:1.

**Contrapeso honesto, `PROVADO`:** os ventiladores demonstravelmente movem a exaustão — 55%→100% deu
`-9,5 °C`, e ventilação externa auxiliar deu mais `-4,3 °C`. **Vazão não é irrelevante.** O que falta
saber é quanto disso chega ao polarizador.

**Veredito: a hipótese do dono continua viva e não pode ser descartada por raciocínio geométrico.**

### 2.8. Os `71,0 °C` dos logs são injetados, não reais (`PROVADO`)

Em `evidencias/2026-08-17/props-233919.tsv` aparecem leituras de `71,0 °C` com evento `WARNING`. **São do
teste de vivacidade** (`setprop vendor.zy.power.tm.temp 71000`): `gtt0` e `gtt1` marcam `71,0`
**simultaneamente**, o que é fisicamente impossível em sensores que passam horas separados por 30 °C.

**Nunca se observou um `WARNING` real de 70 °C em log neste aparelho.** (Continua valendo em 2026-10-29: a
maior leitura real registrada é 68,2 °C, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §2.
O "alarme de 70 °C" do [doc 34](34-escada-brilho-e-fanmonitor.md) é o relato do dono na tela, sem log.)

### 2.9. O piso de resolução é ~2,3 °C — e filtra quase tudo (`PROVADO`)

Degraus reais medidos do `gtt1`: `61154 / 63421 / 65763` mC — ou seja **2,27 e 2,34 °C**.

Consequências que mudam a leitura de três achados do projeto:

- O `-4,34 °C` da alavanca de brilho são **~2 degraus**. Com ±1 degrau de incerteza, o ganho real fica
  entre ~2 e ~6,5 °C. O `0,43 °C por 1%` é **estimativa de baixa resolução**, não constante medida.
- "Cena escura cozinha a óptica" foi "descartado" com uma diferença de `2,27 °C` — **exatamente um
  degrau**, a menor diferença não nula que o instrumento sabe expressar. **Não decide nada.**
- **Diferença de um degrau nunca é evidência.** Vale para o critério de aceite da troca do polarizador.

---

## 3. O sensor: onde está e o que ele mede

`OBSERVADO` (`media/placa-header-gnd-ntc.jpg`): o header serigrafado **`GND` / `NTC`** é um JST branco de
**2 vias**, com dois fios pretos, na placa `NL-5H039-MAIN`, logo abaixo dos dois conectores `Vfan GND`.

**Dois NTC, um header de 2 vias.** A arquitetura explica: ambos compartilham `HW_LSADC_CHANNEL = 1` e são
alternados pelo mux `BL1551B` no `GPIO4_4`. Logo:

- `gtt0` (~31 °C, frio) é quase certamente **NTC SMD na própria placa** — por isso lê a placa
- `gtt1` (61–65,8 °C, o que o fix destravou) é o que **sai por cabo** até a óptica

**Pendência (OPT-S7): seguir o chicote e registrar onde a ponta termina** — colada na moldura do LCD,
presa num suporte, ou solta no fluxo de ar. Isso decide se o `gtt1` mede a **peça** ou o **ar ao redor**.

> **FECHADO (2026-10-29, OPT-S7):** o fio do conector `NTC GND` termina num olhal de latão parafusado no
> topo do **bloco dissipador do LED**, com dois fios entrando no tubo selado com resina: o `gtt1` mede o
> **dissipador do LED**, não a óptica nem o ar ao redor dela. Nenhum sensor mede o polarizador/LCD
> ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3). O teste do secador abaixo perdeu o
> objetivo original.

**Teste de acoplamento (passivo, 2 min):** com `pfl7560-monitor-props.sh` rodando, aquecer o sensor
localmente (secador em temperatura baixa, à distância). Sobe rápido e volta rápido = bem acoplado; sobe
devagar e pouco = amortecido, e a proteção enxerga tarde.

> **Indício de que o `gtt1` pode subestimar bastante a óptica.** A Fresnel frontal é PMMA, com HDT em
> torno de 82-100 °C. Se o foco desigual (doc 38 §7) for mesmo empeno, a temperatura **local** dela é
> muito maior que os 61-65 °C que o `gtt1` reporta. Isso é argumento **contra** o `gtt1` como proxy da
> óptica — e implica que a escada de brilho pode estar calibrada por um número otimista. `HIPÓTESE`.
> **Confirmado em 2026-10-29:** o `gtt1` não é proxy da óptica; mede o bloco do LED (OPT-S7, doc 40 §3).

---

## 3.5. Por que queima: a cadeia térmica, com números

`ESTIMATIVA` — todos os números abaixo carregam incerteza declarada. Nenhum é medição direta.

| # | Etapa | Valor |
|---|---|---|
| 1 | LED, potência elétrica | **40-90 W** (nunca medido; os 240 W são etiqueta da fonte e incluem áudio 2x12 W, SoC, Wi-Fi e três ventiladores) |
| 2 | Saída óptica | 10-30 W |
| 3 | Após copo + Fresnel traseira (coleta 30-50%) | **3-15 W ópticos** chegam ao pré-polarizador |
| 4 | **O pré-polarizador absorve 58-62%** | **2-9 W viram calor** num filme de dezenas de micra sobre vidro de 1,1 mm |
| 5 | O filme não dissipa pela borda | 9 W numa placa de 1,1 mm x 85 mm poriam o centro ~640 K acima da borda — fisicamente impossível. Sobram as duas faces |
| 6 | `ΔT = P/(h·A)`, com `h_eff` 10-18 W/m²K e A = 0,0231 m² | **15-35 °C acima do ar que toca a placa** |
| 7 | O ar ali **não é o de exaustão** — é ar de cavidade, 60-80 °C | **Filme entre 90 e 105 °C** |

Acima dos ~90 °C onde o `I5-` do filme iodine sublima ([doc 36](../guide/36-lista-de-compras-reparo-optico.md) §3).

### A ancoragem que não depende de nenhuma estimativa

Inverta a conta. **A peça durou ~9 meses.** Filme dye qualificado: `105 °C seco / 1000 h`. Filme iodine
comum: ~80 °C. A ~4 h/dia, cada peça viveu **~1100 h**.

**Uma peça que morre na hora exata da especificação está rodando na temperatura da especificação.**

Conte as horas de uso — é a medição mais barata do dossiê e se faz de cabeça. 2 h/dia → 550 h/peça, e o
aparelho está **acima** do limite. 6 h/dia → 1640 h, e está perto dele.

### A causa raiz não é defeito do exemplar. É a arquitetura.

LCD monopainel transmite **5-7%**. Ou seja: **93-95% da luz tem de morrer em algum lugar.** O ODM pôs um
polarizador absortivo *antes* do painel justamente para que ~58% morram numa placa de vidro solta de
R$ 100 em vez de morrerem no painel.

**A peça é, funcionalmente, um consumível.** Que o painel também tenha ido embora 2x mostra que a placa
não está segurando tudo — a cavidade inteira está quente.

### A evidência mais diagnóstica do dossiê

`OBSERVADO`: a 2ª peça amarelou **homogeneamente**, não em mancha.

- **Mancha localizada** = ponto quente, e ponto quente se resolve **direcionando ar**
- **Amarelamento homogêneo** = **a placa inteira passou do limite**

O que mata é a **média**, e a média é fixada por potência absorvida dividida pelo acoplamento da placa ao
ar que a toca. Isso não elimina o ar como alavanca — mais ar baixa a média — mas **mata a ideia de mirar
um jato no ponto quente**.

---

## 3.6. A proteção nunca protegeu o polarizador, e não pode

`PROVADO` com os dados que o projeto já tem. Não depende de onde o sensor está:

- O filme degradou **por inteiro** enquanto o `gtt1` passou meses entre 61 e 66 °C
- A escada segura brilho `1000` até 66 °C e só chega a `850` em 70 °C. **O aparelho vive em 61-63 °C. No
  uso normal a escada entrega zero** — é margem anti-desligamento, não vida útil de polarizador
  (**desatualizado em 2026-10-29:** com a sala a 34 °C e a pasta nova, o `gtt1` ficou em 65,8 °C e a
  escada atuou no uso normal, brilho 944-974; [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md)
  §2. A conclusão do item se mantém: ela não protege o filme)
- **Nunca se registrou um `WARNING` real de 70 °C.** Os únicos `71,0 °C` do repositório são injetados
  (continua valendo em 2026-10-29: a maior leitura real foi 68,2 °C)
- `70/75` **não são limiares de fábrica** (eram 43/45). Foram escolhidos por este projeto **acima do ponto
  de operação observado** — por construção, nunca disparam em uso normal
- O filme queima em **90-105 °C**. O corte está em **75 °C**, e **num corpo diferente**

**A proteção 70/75 protege o LED e a placa de falha catastrófica. Ela nunca foi, e nunca será, extensão de
vida do polarizador.** Achar o sensor não salva o polarizador — diz se a escada está ancorada em algo real
e se dá para reancorá-la.

**Offset estimado `gtt1` → filme: 25 a 45 °C.** Não é medição: é o cruzamento do modelo (`ΔT = P/hA`) com
a vida observada contra a especificação do filme. Os dois caminhos independentes concordam na faixa do
meio.

---

## 4. A medição que decide, e por que a janela é agora

`PROVADO`: **a linha de base de `gtt1` (61-65,8 °C) foi tomada com o polarizador JÁ AMARELADO.** A peça
nova acabou de entrar.

```bash
# 20 min em regime, tela branca, brilho fixo -- E ANOTE A TEMPERATURA DA SALA
# (o script hoje exige --ambiente e recusa rodar sem ele)
PFL_IP=<ip> ./pfl7560-monitor-props.sh --ambiente <sala_C> --minutos 20
```

| Resultado | Leitura |
|---|---|
| `env_temp` cai **bem abaixo** de 61 °C (mais de 1 degrau, > 2,3 °C) | A peça velha era o gargalo. O loop de realimentação (filme amarelado absorve mais → esquenta mais → amarela mais) é real |
| Fica em 61-65 °C | A peça **não** era o gargalo. A hipótese de vazão/acoplamento ganha força |

**Sem T_ambiente anotado, a medição não vale** — foi o erro das quatro anteriores.

**Não rodar agora significa perder para sempre** a chance de saber se a peça era o gargalo, e cair de volta
na aposta entre R$ 90-240 de sopradores e furar o chassi.

---

## 4.1. MEDIDO em 2026-09-03: a primeira linha de base com ambiente anotado

`OBSERVADO.` Artefato: `evidencias/2026-09-03/props-033635.tsv` (60 amostras, 30 min, `monitor-props.sh`).

| Grandeza | Valor |
|---|---|
| **Ambiente da sala** | **35,1 °C** (informado pelo dono; primeira vez que o projeto anota) |
| Sensor quente (`zysys.env_temp`, `gtt1`; bloco do LED, doc 40 §3) em regime | **58,73 °C** média · min 57,50 · max 59,00 |
| Placa (`zysys.light_temp`) | 28,2 °C, constante |
| **Delta sobre o ambiente** | **23,63 °C** |
| Amostras em regime | **55 de 60**; travado em `59,0` por 18 min seguidos |
| Estado do aparelho | peça de polarizador NOVA, brilho 1000, os 3 fixes ativos, `saude.sh` 12/12 OK |

### O que isto responde

**A peça velha ERA parte do gargalo.** Contra a medição mais recente com a peça amarelada:

| Referência | Óptica | vs hoje | Veredito |
|---|---|---|---|
| 2026-08-17 (doc 35, peça amarelada) | 65,76 °C | **−7,03 °C** | **SUPERA o piso de 4,6 °C — diferença real** |
| 2026-07-29 (doc 34, peça amarelada) | 61,15 °C | −2,42 °C | abaixo do piso; isolado, não conclui |

E o argumento fica **mais forte, não mais fraco**, quando se olha o calendário: as duas medições históricas são de **julho e agosto** (inverno/fim de inverno no Brasil) e a de hoje é de **setembro com a sala a 35,1 °C**. Se o ambiente de então era menor — o provável —, então a queda no **delta** é maior ainda que a queda no valor absoluto.

Confirma a realimentação da §3.5: filme amarelado absorve mais → esquenta mais → amarela mais. Trocar reseta o relógio.

> **Ressalva (2026-10-29, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §2):** a
> conclusão "a peça velha era o gargalo" e a previsão por ambiente abaixo dependem da sala anotada, e o
> `gtt0` leu **abaixo** dela nesta sessão e na de 2026-10-29: a âncora de ambiente está em dúvida. Esta base
> pode também ter tido ventilador externo (o dono não lembra). E o `gtt1` mede o **bloco do LED**, não o
> filme (doc 40 §3): a queda aqui é do bloco, que só reflete o filme de forma indireta. A segunda medição
> (65,8 °C, sala 34 °C, pasta nova) não decide nada sozinha pelos mesmos motivos.

### O achado que ninguém tinha considerado: a SALA é a maior alavanca

Em regime o aparelho controla o **delta sobre o ar que entra**, não a temperatura absoluta. Com delta medido de 23,63 °C, cada grau de ambiente vira **um grau na óptica**:

| Ambiente | Óptica prevista (delta 23,63 °C) |
|---|---|
| **35,1 °C (hoje)** | **58,7 °C** (medido) |
| 30 °C | ~53,6 °C |
| 25 °C | ~48,6 °C |

**Baixar a sala de 35 para 25 °C vale ~10 °C na óptica** — mais que baixar o brilho 15% (5-9 °C estimados) e muito mais que trocar soprador (2-4 °C estimados). **É a única alavanca com número medido em vez de estimado**, e a mais barata de todas.

E há um limite de norma envolvido: o manual especifica **operação de 0 a 40 °C**. A 35,1 °C o aparelho está a **4,9 °C do teto da própria spec**.

> **Consequência retroativa, `HIPÓTESE`:** as duas peças que queimaram viveram em salas de temperatura desconhecida. Se o padrão for verão brasileiro sem ar-condicionado, parte do que este projeto atribuiu a defeito de política térmica é **ambiente somado ao defeito** — o firmware cego tirou a margem e o clima consumiu o resto. Não é desculpa para o defeito de fábrica, que está provado; é um fator que nunca entrou na conta.

### O que isto NÃO responde

- **Não decide vazão vs acoplamento.** O delta de 23,63 °C é a resistência térmica do conjunto; separar as duas parcelas ainda exige o braço de ventilação externa (§5, item 2.2).
- **Não diz a temperatura do filme.** Pelo offset estimado da §3.6 (25-45 °C), o filme estaria hoje entre **84 e 104 °C** — ainda dentro da faixa onde o iodine sublima (~90 °C). Ou seja: **melhorou, e ainda não está seguro.**
- **Não valida o `0,43 °C/%` do brilho.** Continua sendo estimativa de dois degraus de quantização.

---

## 4.2. GATE FECHADO: o firmware CLAMPA o brilho em 750

`PROVADO NO APARELHO (2026-09-03).` Este era o gate aberto desde julho:
[doc 06](06-acesso-adb-e-comandos.md):144 listava como **inferido, não testado em hardware** que
*"`sbri` abaixo de ~750 e aceito pelo LED"*, e [doc 05](05-ZYCustom.ini-proposto.md):55 exigia confirmar
ao vivo antes de gravar. **Confirmado no git (`cd5a80f`) que nunca foi feito.**

Mapeamento completo, pedido contra aplicado:

| `sbri 0 <n>` | `gbri 0` devolveu |
|---|---|
| 700 | **750** |
| 600 | **750** |
| 500 | **750** |
| 300 | **750** |
| 200 | **750** |
| 100 | **750** |

**Clamp rigido em 750** — o piso do `[Backlight] FW_LEVEL = 750, 800, 850, 900, 950, 1000`.

**Não e o LED que recusa: e o firmware que não deixa o comando passar.** A própria ajuda do `hidebug`
documenta a faixa larga e a implementacao satura na curva:

```
sbri    set backlight brightness. eg: sbri 0 500[backlight:0-1, brightness:0-1000]
```

O exemplo oficial usa **500**, um valor que o firmware não aplica.

**Não existe outra via por runtime.** O `help` completo do `hidebug` tem apenas `sbe` (liga/desliga, sem
meio-termo), `sbl` (indice da lista `gbll`, que so vai ate 750) e `sbri` (clampado). **Nenhum comando de
PWM direto.**

### Consequencias

1. **Piso de brilho abaixo de 750 exige editar `FW_LEVEL` no `.ini`** — mudanca persistente, com reboot,
   que muda o md5 e dispara os 13 pontos cravados (o `INI_MD5_OK` do autorun e um **gate** e passaria a
   recusar; o `fix.sh apply` abortaria). E a "fase 2" do doc 05, ainda não executada.
2. **Não da para errar por acidente.** O firmware protege o LED de comando fora da curva — o que
   contextualiza o episodio antigo do `sbl 0` ([doc 34](34-escada-brilho-e-fanmonitor.md)): `sbl` recebe
   valor da lista e `sbri` e cap; caminhos diferentes, e so um clampa com graca.
3. **Um desenho de menor risco, se for editar:** ampliar **so** o `FW_LEVEL` e deixar a escada da politica
   intocada em `1000, 950, 900, 850...`. Os niveis baixos ficam disponiveis para teste manual sem que a
   politica automática passe a usa-los sozinha.

### Observacao parcial do efeito termico (2 pontos, NÃO e medicao)

Com o brilho clampado em 750 (**-25%**), o `gtt1` caiu de `59,0` para `56,4` C em **19 s**. Sao
**2,6 C, um degrau do ADC** — o menor movimento detectavel, na direção certa, e **muito mais rapido do que
o esperado**. A serie foi interrompida em 2 amostras.

**Não conclui nada** e não valida o `0,43 C/%` do doc 34. Se aquele coeficiente for real, 25% deveriam
valer ~10,8 C. Fica como **OPT-S12**.

---

## 4.3. Limitacao registrada: não se consegue exibir imagem por adb neste aparelho

`OBSERVADO.` Tres vias tentadas para poder rodar um teste visual A/B de brilho, **todas falharam**:

| Via | Resultado |
|---|---|
| `am start -a VIEW -d file:///sdcard/x.png -t image/png` | abre `com.hisilicon.higallery/.NetworkHiGallery`, **tela preta** |
| `am start -n com.newlink.filemanager/.gallery.PictureShowActivity` | **o visualizador abre** (controles de navegacao e zoom visiveis no `screencap`), mas **não carrega o arquivo** |
| `content://media/external/images/media/<id>`, apos `MEDIA_SCANNER_SCAN_FILE` | indexado no MediaStore (confirmado por `content query`), mesmo resultado |

`pm resolve-activity -a android.intent.action.VIEW -t image/png` devolve **`No activity found`** — não ha
handler registrado para o tipo, mesmo havendo dois apps com visualizador.

**Consequencia pratica:** qualquer teste que dependa de padrão na tela exige o **controle remoto** do dono
abrindo o arquivo pelo gerenciador. Vale para a sprint 19 (vigia de tela), cujo gate de viabilidade o
[doc 19](../archive/19-sprint-warning-tela.md) dava como *"ja resolvido (`am start ... VIEW`)"* —
**esse gate NÃO se sustenta neste aparelho e precisa ser reaberto** (**OPT-S13**).

---

## 5. Ordem de ataque

### Nível 0 — com o aparelho ABERTO, tudo grátis. A janela fecha ao fechar.

| # | Ação | Esforço | Ganho | Como medir |
|---|---|---|---|---|
| **0.1** | **Teste do lenço/fumaça** nas frestas do bloco óptico, máquina ligada. **O ar entra e sai do túnel onde está o polarizador, sim ou não?** | 10 min | 0 °C — **mas decide a discussão inteira** | Binário: o lenço mexe ou não |
| 0.2 | Seguir o chicote do JST (aparelho **DESLIGADO**) e fotografar onde termina | 20 min | 0 °C | Foto. Fecha OPT-S7 |
| **0.3** | **Limpar filtro, duto, rotores e a cavidade.** Girar cada blower com o dedo | 30 min | **2-6 °C plausíveis, nunca quantificados** | `gtt1` por props, 20 min de regime, antes e depois |
| 0.4 | Paquímetro: espessura da placa, folga placa↔Fresnel e placa↔painel. Luz rasante nas Fresnel | 10 min | 0 °C | A folga define o `h` da fenda |
| 0.5 | **Linha de base do `gtt1` com a peça nova** (OPT-S3), ambiente anotado | 25 min | 0 °C | Quanto do calor vinha da realimentação do filme amarelado |

**O 0.1 nunca foi feito e é a ação de maior valor disponível** — dez segundos resolvem a topologia que o
projeto discute há dois meses sem dado. **O 0.3 é o único item grátis com ganho térmico real**, e também
nunca foi medido. Deveria ter sido sempre o nº 1.

> **Não faça o teste de desplugar o NTC com a placa viva.** Se aquele GND for o retorno comum dos dois
> ramos do mux, desplugar mata os dois canais e não discrimina nada; já existe crosstalk espontâneo
> documentado (uma amostra de `gtt1` leu `31912` mC, o valor do sensor frio); e é mexer em placa de 35 V
> com o caminho óptico aberto.

### Nível 1 — software, reversível, R$ 0. **A maior alavanca honesta da lista.**

**Baixar o TETO de brilho permanentemente** — não a escada. A escada não faz nada em 61-63 °C (em
2026-10-29, a 65,8 °C com a sala a 34 °C, ela atuou de leve: brilho 944-974, doc 40 §2).
`FW_LEVEL` já contém `750`, então não precisa estender curva de LED nenhuma.

| Teto | Potência absorvida | Ganho no filme | Vida |
|---|---|---|---|
| 1000 → **850** | −15% | **5 a 9 °C** | ~1,4-1,8x |
| 1000 → **750** | −25% | **7,5 a 15 °C** | ~1,7-2,8x |

Regra de degradação de orgânico: **~2x de vida a cada 8-10 °C**. É regra de bolso, não constante medida
deste filme — mas a direção é certa e o multiplicador é grande.

**Honestidade sobre o coeficiente:** os `0,43 °C/%` são **dois degraus de quantização**, ±53%. Vale
`0,43 ± 0,23`. E foi medido no `gtt1`, não no filme — no filme provavelmente é **maior**, porque o filme é
quem absorve.

**Custo real:** tela 15-25% mais escura. Num aparelho vendido como "8000 lúmens" que entrega algumas
centenas de ANSI, em quarto escuro, provavelmente imperceptível. **Decisão do dono (BRI-S1).**

### Nível 2 — compras baratas, reversíveis

| # | Item | Custo | Para quê |
|---|---|---|---|
| 2.1 | **Termômetro de bulbo/espeto**, e anotar **ambiente em toda medição** | R$ 20 | Torna interpretável todo número passado e futuro |
| **2.2** | **Ventilador externo na admissão**, como experimento | R$ 30-60 | Já mediu −4,3 °C na exaustão. **No filme: desconhecido — é o teste** |
| 2.3 | **Wattímetro de tomada** | R$ 40 | Fecha o maior buraco do dossiê: ninguém sabe se o LED é 30 W ou 90 W |
| 2.4 | **Termopar tipo K** na borda do vidro, Kapton, fios pelo respiro, gabinete fechado | R$ 30-60 | **É A medição.** Ver protocolo abaixo |

> **Protocolo do termopar (sem ele o número é lixo):** blinde o bead da luz com lingueta refletora, corra
> **≥ 20 mm de fio na isoterma** antes de sair, e faça uma leitura de referência **com o LED apagado** no
> mesmo estado de fan, para dimensionar o viés óptico. Leia o termopar e o `zysys.env_temp` no mesmo
> instante — é isso que mede o offset real da §3.6.

### Nível 3 — invasivo. Só depois do 0.1 e do 2.2.

**3.1 Direcionar ar sobre as DUAS faces da placa.** É onde a física diz que está o ganho: `h_eff` de ~13
para ~30 leva o `ΔT` de ~30 K para ~13 K — **~17 °C a menos no filme, 3-4x a vida.** Maior que qualquer
troca de ventilador.

> **Restrição que muda o projeto do mod:** o ar **pode** passar pelo pré-polarizador (está no caminho de
> **iluminação**, não é conjugado ao plano de imagem — poeira ali é véu difuso, não ponto visível), mas
> **não pode seguir para a face do painel**, que é o plano de imagem. Ar entra e sai na própria fenda.

**3.2 Trocar os blowers — ganho marginal, e digo com todas as letras.** Vazão escala com ~√(pressão);
dobrar `p_max` compra 1,41x → ~3,5 °C no ar misturado → **2-4 °C no filme**, e só **se** ele estiver
acoplado ao fluxo — que é exatamente a pergunta em aberto. **Menos que baixar o brilho 15%, por
R$ 150-300 e trabalho mecânico irreversível.** Último da lista.

**3.3 Wire-grid (refletivo) no lugar do absortivo.** É o único que ataca a causa: absorção de ~58% para
2-5%, de ~5 W para ~0,3 W. Mas: **não existe em catálogo a 136x85 mm** (fabricantes param em ~50 mm); os
~48% refletidos voltam ao copo e, sem despolarização eficiente, são reabsorvidos ali — parte do ganho
reaparece como calor no LED; extinção >1415:1 é **7-70x pior** que dye, com contraste visivelmente pior; e
a versão em filme (COP, 0,19 mm) não fica retida numa guia feita para vidro de 1,1 mm e é especificada
para **60 °C**, abaixo da temperatura já medida.

> **Não pague por "vidro nano de isolamento térmico" esperando corte de IR.** LED branco por fosforização
> quase não emite acima de 800 nm. O único número publicado de eficácia (−4,5 °C, +8% de brilho) vem de
> patente de fabricante sobre um **revestimento dicroico**, não sobre o vidro dopado com ferro dos
> anúncios.

### O que NÃO fazer

**Não rode o braço de redução de vazão** (desligar um blower / obstruir a entrada). A proteção de
ventilador travado é inarmável por software (2 fios, sem FG), o filme degrada muito abaixo do corte de
75 °C, e a peça nova está lá dentro. **Só o braço de AUMENTO** (item 2.2), exigindo **≥ 4,6 °C** (dois
degraus) para chamar de real.

## 6. Pendências

| ID | Sev | Estado | Item |
|---|---|---|---|
| **OPT-S12** | média | **ABERTO** | Efeito termico do brilho 750 vs 1000 não medido ate o regime (so 2 amostras, interrompido). Valida ou refuta o `0,43 C/%` do doc 34. Rodar `pfl7560-teste-brilho.sh --curva 750 --ambiente X --minutos 25` (§4.2) |
| **OPT-S13** | média | **ABERTO** | **Reabrir o gate de viabilidade da sprint 19.** O doc 19 dava `am start ... VIEW` como resolvido; **não funciona neste aparelho** (§4.3). Sem exibir imagem por shell, o vigia de tela precisa de outro mecanismo. **Atenção (2026-10-30):** o kit de pendrive v2 (bloco 5) mostra as telas do teste de cor pela mesma via (`am start ... VIEW`); a etapa E1(e) do [bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md) é o teste que decide |
| ~~OPT-S3~~ | — | **FECHADO (2026-09-03)** | Linha de base medida: **58,73 °C** em regime com ambiente **35,1 °C** (§4.1). Queda real de **7,03 °C** contra a medição de agosto. Artefato: `evidencias/2026-09-03/props-033635.tsv`. Ressalva de âncora de ambiente no [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §2 |
| ~~OPT-S5~~ | — | **FECHADO (2026-10-29)** | `DFH8030S`, 12 V, 0,45 A, centrífugo, `PROVADO` pela etiqueta ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §4). Sem ficha pública (doc 40 §5) |
| ~~OPT-S6~~ | — | **FECHADO (2026-10-29)** | 3 ventiladores: 2 sopradores controlados (`gfc` = 2) + 1 axial no exaustor do LED, sem controle ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3) |
| ~~OPT-S7~~ | — | **FECHADO (2026-10-29)** | O NTC do `gtt1` é um olhal encapsulado no topo do bloco dissipador do LED; nenhum sensor mede o polarizador/LCD ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3) |
| **OPT-S8** | média | **ABERTO** | Rodar o braço dos ventiladores no `gtt1` (§2.5) — o experimento pendente desde 2026-07-05 |
| **OPT-S9** | baixa | **ABERTO** | Refazer as medições de exaustão **com T_ambiente e apontando o IR para o fluxo de ar**, não para a grade (§2.6) |
| **OPT-S1** | média | **ABERTO** | Rota mecânica: o dono desmontou de novo em 2026-09-02 (e em 2026-10-29). **Continua sem transcrição** |
| **OPT-S2** | média | **ABERTO** | Foco desigual. Fresnel **limpas e sem dano** — o suspeito de empeno segue de pé, mas não foi inspecionado com luz rasante |
| ~~OPT-S4~~ | — | **FECHADO na prática** | Orientação das Fresnel resolvida pelo dono na bancada. A contradição documental da §7.1 do doc 38 permanece registrada |
| ~~POL-S1~~ | — | **FECHADO** | Ver [doc 38](38-motor-optico-e-troca-do-polarizador.md) |

> **Atualização (2026-10-29):** na abertura seguinte (doc 40) fecharam OPT-S5, S6 e S7; OPT-S1 segue aberto.
>
> **Aparelho FECHADO em 2026-09-03.** As pendências marcadas **[ABERTURA]** (OPT-S1, S5, S6, S7)
> exigem o motor óptico aberto e ficam **estacionadas para a próxima vez que ele for aberto** — não vale
> reabrir só por elas, porque cada desmontagem põe em risco o flat de 60 pinos do painel e o polarizador
> recém-instalado. As demais (OPT-S3, S8, S9) rodam com o aparelho **fechado e em uso**, que é o estado
> atual, e são justamente as de maior valor.

---

## 7. A verdade desconfortável

**Não existe cura definitiva por retrofit. Este aparelho vai consumir pré-polarizador para sempre.**

Três razões, nenhuma opinativa:

1. **Quem resolveu, resolveu por arquitetura** — separação painel/polarizador com vão ventilado,
   polarizador refletivo no lugar do absortivo, revestimento dicroico, motor óptico selado com trocador.
   Está em produtos de fábrica. **Não existe como kit de retrofit.**
2. **Ninguém, em lugar nenhum, tem relato verificável de ter eliminado a recorrência num aparelho
   existente.** O levantamento procurou. O que existe é o oposto: relato de dois aparelhos perdidos
   seguidos pelo mesmo motivo.
3. **A física não é defeito.** 5-7% de transmitância; 93-95% da luz tem de morrer, e nesta arquitetura
   morre no pré-polarizador. Resfriar melhor muda **quanto tempo ele sobrevive**, não o fato de estar
   sendo cozinhado.

### O erro de premissa que este doc corrige: o fix NUNCA foi testado

O projeto vinha assumindo que a correção térmica falhou, porque o polarizador queimou de novo.

**Falso.** A peça retirada em 2026-09-02 foi instalada **antes** de qualquer correção — o amarelamento
homogêneo acumulou majoritariamente com fans a 55% e sensor cego. **As duas peças mortas viveram no
resfriamento de fábrica.**

**A terceira, instalada em 2026-09-02, é a PRIMEIRA que vai viver a vida inteira com o fix ativo.** O
experimento que diz o que a correção compra leva **9 a 24 meses e começou agora**. Anotar a data é parte
do método.

E, para não romantizar: de 2026-07-05 a 07-29 a build travou o brilho em `1000`, acima do alvo real do
loop stock (~981). **Por 24 dias o fix piorou a fonte de calor no polarizador** (§2.4).

### Quanto custa conviver

| Cenário | Intervalo esperado | Peça/ano | Desmontagens/ano |
|---|---|---|---|
| Hoje (nada mudado) | 9-12 meses | R$ 100-137 | 1-1,3 |
| + limpeza + teto 850 | 13-16 meses | R$ 77-95 | ~0,8 |
| + teto 750 | 18-25 meses | R$ 50-68 | ~0,6 |
| + ar direcionado funcionando | 24-36 meses | R$ 34-51 | ~0,4 |

### A pergunta de peça que precede tudo

**O vidro instalado em 2026-09-02 não declara dye nem iodine nem temperatura.** Se for iodine, queima de
novo em ~9 meses independentemente do que se faça no ar. **Perguntar ao vendedor custa zero** — o roteiro
com os termos em chinês está no [doc 36](../guide/36-lista-de-compras-reparo-optico.md) §3.

O **PFHDU** (US$ 26, ~R$ 135, `105 °C seco / 1000 h`, ensaio de lâmpada de mercúrio 400 W / 500 h,
eficiência >99,90%) é a **única peça da lista com especificação térmica publicada** e a que ataca a
recorrência. **Ressalva pesada:** é folha de filme 25x15 cm, rende **uma peça**, e a guia do chassi quer
vidro de 1,1 mm — significa **laminar filme em vidro portador**, com eixo certo e sem bolha. Laminação
malfeita é pior que a peça atual.

### Veredito

**É conserto, não enxugar gelo — mas o conserto é estender o intervalo de 2 a 4x, não eliminá-lo.** A meta
honesta é sair de "cirurgia anual" para "a cada 2-3 anos", e fazer a peça custar R$ 135 com especificação
em vez de R$ 102 na loteria.

**O caminho mais barato para lá é o mais chato: baixar o brilho e limpar o duto.** Tudo o mais é mais caro
e menos certo.

---

## 7.1. O que NÃO fecha (dizer isto a quem discutir números)

1. **Ambiente nunca medido** nas quatro leituras de exaustão. Sem ele não há `ΔT`, não há vazão, não há
   °C/W. Os "16 CFM" e a "razão 2:1" **não têm base**.
2. **Potência real nunca medida.** 240 W é etiqueta. A repartição LED/placa é desconhecida — por isso a
   potência absorvida no filme carrega **fator 4,5 de incerteza** (2-9 W).
3. **37,2 °C é plástico, não ar.** A subtração `gtt1 − exaustão` mistura duas escalas.
4. **Posição física do `gtt1` desconhecida.** Toda conclusão ancorada nele carrega offset desconhecido.
   **Resolvido em 2026-10-29:** ele fica no bloco dissipador do LED (OPT-S7, doc 40 §3); o offset até o
   filme continua desconhecido, porque nenhum sensor mede o polarizador.
5. **Contagem de ventiladores em aberto:** doc 27 diz 2, doc 38 viu um terceiro (axial do LED) na
   bancada, e o `.ini` fecha em 2 porque `SERIAL_NUM` conta só os **controlados**. São provavelmente
   **3, com 2 controlados**. **Confirmado em 2026-10-29 (OPT-S6):** 3, com 2 controlados.
6. **Medir sempre por props (`zysys.env_temp`), nunca por `gtt` ímpar** — `gtt` avança o anel de um
   termistor só, e anéis defasados nunca ficam cheios juntos ([doc 37](37-mecanismo-lsadc-defasagem-dos-aneis.md)).
   Se precisar de `gtt`, sempre **em par**, sem interrupção.
7. **Piso de resolução: ~2,3 °C por degrau.** **Não chamar de real nada abaixo de 4,6 °C** (dois degraus).

---

## 8. Proof-of-work

```bash
# 1) linha de base com a peca nova (OPT-S3) -- a temperatura da sala e obrigatoria
PFL_IP=<ip> ./pfl7560-monitor-props.sh --ambiente <sala_C>

# 2) estado geral da correcao (12 checagens passivas)
PFL_IP=<ip> ./pfl7560-saude.sh

# 3) a protecao reage? (~65 s, mexe no brilho e volta sozinho)
PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade

# 4) a cor sobreviveu ao manuseio do caminho optico. Em 2026-09-03 (painel -0600) era jeida;
#    desde a 2a troca de LCD (2026-10-29, painel -4300) o esperado e vesa (doc 40 s1)
PFL_IP=<ip> ./pfl7560-lcd-color.sh status     # esperado hoje: lvds_fmt: vesa

# 5) integridade dos artefatos byte-exatos (offline)
make check                                     # 9 OK desde 2026-10-30 (6 em 2026-09-03)
```

**Critério de aceite da troca:** `gtt1` em regime tem de cair **mais que um degrau** (> 2,3 °C) contra a
linha de base, nas **mesmas condições e com T_ambiente anotado**. Um degrau não conta. (Lembrando: o
`gtt1` mede o bloco do LED, não o filme; doc 40 §3.)

**Nunca usar "não desligou" como critério** — a proteção deste aparelho só enxerga por causa do fix do mux
e o monitor de ventilador está desarmado de fábrica ([doc 34](34-escada-brilho-e-fanmonitor.md), FAN-S1).
