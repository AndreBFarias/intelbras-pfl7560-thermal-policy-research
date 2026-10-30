# 38 - O motor óptico por dentro: geometria confirmada e a troca do polarizador

Sessão de **2026-09-02**, com o aparelho **aberto na bancada**. Fecha o **POL-S1**, que estava aberto
desde 2026-08-17 ([doc 35](35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md) §8) e travava a lista de
compras do reparo óptico ([doc 36](../guide/36-lista-de-compras-reparo-optico.md) §0).

**Convenção deste doc** (a mesma do [doc 37](37-mecanismo-lsadc-defasagem-dos-aneis.md)):
`OBSERVADO` = visto neste aparelho, nesta sessão, pelo dono. `PROVADO` = citação literal verificada em
fonte primária. `FORTE` = fonte secundária consistente e reproduzida. `HIPÓTESE` = explicação plausível
ainda não testada.

---

## TL;DR

- **POL-S1 FECHADO.** O polarizador de entrada deste aparelho é uma **placa de vidro separada**, entre a
  Fresnel traseira e o painel LCD. **Não é laminado ao vidro do painel.** A afirmação contrária no
  [doc 07](07-hardware-upgrade.md#dissipadores-para-o-polarizadorlcd) é descrição genérica de categoria e
  **não vale para este aparelho** — corrigida aqui.
- A geometria interna, nunca antes registrada no repositório, está na §1. Bate exatamente com a patente
  `CN109164667A`.
- **Esta é a segunda troca de polarizador do aparelho.** A peça retirada em sessão anterior tem mancha
  marrom localizada; a que estava instalada até hoje está **amarelada de forma homogênea** — modo de
  falha diferente, e é a explicação do aviso de temperatura ter ficado mais frequente (§3).
- A peça de reposição (vidro de isolamento térmico vendido para Thundeal TD98, 136x85 mm) é **drop-in**:
  mesmo tamanho, mesma espessura e **mesmo eixo** da original, verificado por sobreposição (§4).
- Das quatro peças compradas, **duas entram no aparelho e duas não**. O filme refletivo prata fica na
  gaveta, com motivo físico (§6).
- **Nenhuma das peças ataca o foco desigual de um lado.** O suspeito que sobra é a Fresnel frontal (§7).

---

## 1. A geometria do motor óptico (o que faltava no repositório)

`OBSERVADO.` Ordem dos elementos, do LED até a tela:

| # | Elemento | Observação |
|---|---|---|
| 1 | **LED + dissipador aletado** | Fan axial próprio, separado dos dois blowers DFH8025S. **Atualização (2026-10-29):** são 3 ventiladores no total (este + os 2 sopradores, que são `DFH8030S` 12 V 0,45 A); o NTC do `gtt1` fica num olhal no topo deste bloco (OPT-S6 e OPT-S7, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3) |
| 2 | **Placa metálica com pintura branca** | Ao redor do LED; refletor da cavidade (o `光杯` / "light cup" da literatura) |
| 3 | **Lente Fresnel traseira** | Colima o feixe para o painel |
| 4 | **Vidro polarizador de isolamento térmico** | **A peça que queima.** Placa de vidro solta, retida por guias |
| 5 | **Painel LCD RX058B** | Flat de 60 pinos (`1`…`60` serigrafados). Traz os 2 polarizadores próprios laminados |
| 6 | **Lente Fresnel frontal** | Imediatamente à frente do LCD |
| 7 | **Espelho de projeção** | Placa de vidro na diagonal, **colada de fábrica**, nunca removida, sem manchas |
| 8 | **Lente de projeção** | Conjunto cilíndrico |

**Confirmação independente.** `PROVADO.` A patente `CN109164667A` (verificada no HTML bruto) descreve a
mesma pilha, e é literal quanto à posição da peça 4:

```
所述隔热玻璃设置在所述后菲涅尔透镜20和LCD屏40之间
(o vidro de isolamento térmico fica ENTRE a Fresnel traseira e o painel LCD)
```

E `CN113267951A` dá a cadeia: `LED generator -> light cone -> first Fresnel lens -> heat insulation
glass -> LCD display screen -> second Fresnel lens`.

**O painel tem os dois polarizadores próprios.** `PROVADO`, reivindicação 1 da mesma patente:
`所述LCD屏包括第一偏光片、TFT-玻璃、液晶盒、彩色滤光片和第二偏光片`. Ou seja, **há três polarizadores no
caminho**: o do vidro (pré-polarizador, item 4) e os dois laminados no painel.

> **Pista encerrada — não reabrir.** O *resumo* de `CN109164667A` sugere que o filme APCF na Fresnel
> *substituiria* o polarizador do painel (`代替原先LCD屏上APCF偏光片`). A **reivindicação 1 da mesma
> patente mantém os dois polarizadores no painel**. Acreditar no resumo levaria alguém a tentar descolar
> ou raspar o filme do painel — destruindo um painel funcional. O painel **não** se toca.

---

## 2. Correção de dois registros anteriores do repositório

| Registro | Onde | Veredito |
|---|---|---|
| "o polarizador é película orgânica **laminada sobre o vidro do LCD**" | `07-hardware-upgrade.md:45` | **ERRADO para este aparelho.** É placa de vidro separada. A frase vem de pesquisa web genérica (fontes em `07:150`), não de inspeção local |
| "REMOVER o painel LCD **do prisma**" | `07-hardware-upgrade.md:142` | **Contaminação de arquitetura 3LCD.** Este é painel único; não há prisma. O painel sai como módulo discreto |
| "seguir o teardown (doc 27) na ordem inversa para chegar no motor óptico" | `../guide/32-guia-troca-painel-lcd.md:37` | **Referência circular.** O doc 27 para no gabinete e nunca chega ao motor óptico |

---

## 3. O modo de falha real: amarelamento homogêneo, não só mancha

`OBSERVADO.` As duas peças retiradas do aparelho, lado a lado:

| Peça | Estado |
|---|---|
| Primeira (retirada em troca anterior) | **Mancha marrom localizada**, grande, concentrada |
| Segunda (instalada até 2026-09-02) | **Amarelada de forma homogênea**, sem mancha localizada; escurecimento geral |

São **dois estágios do mesmo processo**, não dois defeitos. Mecanismo, do
[doc 36](../guide/36-lista-de-compras-reparo-optico.md) §3: o filme iodine é PVA com poli-iodetos
`I3-`/`I5-`; sob calor o `I5-` sublima e o filme perde a absorção do vermelho, passando a vazar luz
amarela.

**Consequência que fecha o laço do sintoma térmico:** filme amarelado absorve mais energia do que um
filme sadio. Mais absorção → mais calor no próprio filme → mais degradação. É realimentação positiva, e
é a explicação direta de o aviso de temperatura (`WARNING_VALUE = 70000`, o do
[doc 34](34-escada-brilho-e-fanmonitor.md)) ter ficado mais frequente com o tempo.

> **Ressalva (2026-09-03 e 2026-10-29):** "aviso mais frequente" é a percepção do dono; nenhum `WARNING`
> real de 70 °C foi capturado em log ([doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §2.8), e a
> maior leitura real registrada é 68,2 °C ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md)
> §2). O `gtt1` mede o bloco do LED, não o filme (doc 40 §3).

**Corolário operacional:** amarelamento homogêneo é sinal de fim de vida do filme **antes** de aparecer
mancha. Não esperar a mancha para trocar.

---

## 4. A peça de reposição e a verificação de compatibilidade

`OBSERVADO.` Peça usada: vidro de isolamento térmico vendido para **Thundeal TD98**, **136x85 mm**
(AliExpress `1005009462536295`, item 1 / prioridade 1 do [doc 36](../guide/36-lista-de-compras-reparo-optico.md)).

Verificação feita antes de instalar, contra a peça original:

| Grandeza | Resultado |
|---|---|
| Comprimento e largura | **iguais** |
| Espessura | **igual** |
| Eixo de polarização | **igual**, verificado por sobreposição |
| Películas protetoras | **não havia** nas peças |

**Veredito: drop-in.** Instalada.

> **Referência dimensional de outra máquina, para contexto.** `PROVADO.` O teardown do **Alliums AP-020**
> (iFixit, guia 175853, passo 6) descreve a peça equivalente como *"A polarizer made of glass substrate,
> located between the LCD screen and the light cup... 145mm long, 85mm wide, 1.1mm thick. Weight: 32g."*
> São **9 mm a mais** no comprimento que a peça deste aparelho. Ou seja: **a medida não é universal
> dentro da classe "5,8 polegadas"** — o catálogo tem 145x85, 142x92, 136x85, 119x74 e 96x60. Sempre
> comparar com a peça retirada antes de instalar. Uma lâmina curta não fica retida nas guias e pode
> sentar sobre o painel.

---

## 5. Procedimento de troca (consolidado)

### 5.1. Acesso

`FORTE` (chassi equivalente, iFixit AP-020, guia 175853): tampa de lente e filtros → parafusos do fundo
(1 PH1 + 6 PH0) → tampa superior, soltando os conectores ZIF → **placa-mãe** (5 PH0 e todos os ZIF
frontais) → tampas do caminho de luz (10 PH0, **direita primeiro, depois a esquerda**).

> **Armadilha literal da fonte, que costuma ser omitida:** ao virar a placa-mãe há **dois cabos na face
> de trás** (botão de força e o segundo fan). Soltar antes de levantar.

`PROVADO` (mesmo guia, passo 6): com o caminho de luz aberto, **LCD, polarizador e light cup saem
puxando para cima** — as instruções literais são `Pull up to remove the LCD / the polarizer / the light
cup`. O vidro é retido por **guias laterais moldadas**, encaixe deslizante vertical.

**Neste aparelho o desmonte já foi feito duas vezes pelo dono** (uma troca de painel e duas de
polarizador). A rota mecânica exata deste chassi ainda não foi transcrita — é a lacuna que resta.

### 5.2. Determinar o eixo (a peça velha é o gabarito)

`PROVADO` (legenda oficial de vídeo de reparo, 14:26-14:57): sobrepor a peça nova sobre a velha contra
luz difusa e girar.

- Sobreposição fica **escura/preta** → rotação errada
- Sobreposição fica **clara/transparente** → orientação correta

**Procure o escuro máximo, não o claro.** Perto de 90° a intensidade cai com o quadrado do desvio (lei
de Malus, `I = I0·cos²θ`), então o mínimo é muito mais fácil de localizar a olho: 3° de erro já produzem
vazamento visível. Achado o mínimo, girar exatos 90°. Marcar com fita antes de soltar.

A extinção nunca é perfeita — sobra um roxo/azul escuro. Isso é normal (razão de extinção real de
10.000 a 100.000), não indica peça ruim.

**Referência absoluta de graça, se não houver peça velha:** óculos de sol polarizado têm eixo de
transmissão **vertical** por projeto.

### 5.3. Qual face vai para o LED

As fontes se contradizem: a patente diz face espelhada para o LED e face polarizadora para o LCD
(`反射镜面301靠近LED点光源10 … 偏光镜面302靠近LCD屏40`); parte dos anúncios diz o contrário.

**Desempate empírico deste aparelho:** na peça retirada, **a face mais amarelada/queimada é a que estava
voltada para o feixe**. Replicar.

### 5.4. Verificar antes de fechar

Ligar com o gabinete ainda aberto e olhar a imagem:

| Sintoma | Causa | Ação |
|---|---|---|
| Cor normal | certo | fechar |
| **Imagem tipo negativo fotográfico**, sem cor | eixo 90° errado | girar a peça 90° |
| Tudo amarelado / perfil de cor invertido | face trocada | virar a peça |

`FORTE`: o sintoma de eixo errado é **imagem negativa, não tela preta** — girar 90° um dos polarizadores
tira o par de cruzado para paralelo e inverte o modo do painel. Tela totalmente preta só acontece
cruzando dois polarizadores na mão, em bancada.

### 5.5. Plano B, se a medida não bater

`PROVADO` (relatos de reparo): **não raspar o filme do vidro original** — ele é quebradiço, lasca, e há
relatos de trincar o vidro. Álcool isopropílico "mal funciona" no adesivo.

Alternativa que funcionou para terceiros: levar a placa velha a uma vidraçaria, mandar cortar vidro nas
medidas exatas e aplicar filme novo nele, fixado com **tiras estreitas de fita transparente nas bordas**.
Folha polarizadora solta vem com liner nos dois lados e **apenas um lado é adesivo**.

---

## 6. Veredito das quatro peças compradas

| Peça | Papel | Entra no aparelho? |
|---|---|---|
| **Vidro isolamento térmico 136x85 (TD98)** | Substituição do item 4 da §1 | **Sim.** É a peça do reparo |
| **Painel LCD RX058B-0600** | Sobressalente / contingência | Só se o painel atual estiver danificado. Cor já resolvida (JEIDA no `panelparam`). **Atualização (2026-10-29):** na 2ª troca de LCD o painel instalado é um `-4300` e o aparelho está em **VESA**; qualquer painel novo passa pelo teste de cor do [guia 32](../guide/32-guia-troca-painel-lcd.md) §3 ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §1) |
| **Folha polarizada linear 0/90°, 20x30 cm** | **Instrumento de medida de eixo** + material do plano B (§5.5) | **Não** no caminho de luz: 380-700 nm, não bloqueia IR |
| **Filme refletivo prata 200x170 mm** | — | **Não. Fica na gaveta** |

**Por que o refletivo prata não entra, com todas as letras.** É filme polimérico multicamada tipo DBEF,
com instabilidade dimensional perto de **85 °C** — exatamente a faixa onde o problema deste aparelho
acontece. Instalá-lo seria repor o mesmo modo de falha com prazo de validade mais curto. O único
mecanismo pelo qual um pré-polarizador refletivo reduziria calor total é **rejeitar em vez de absorver**,
e isso exige **wire-grid sobre vidro** — que é outra peça, não esta.

**E a regra geral que decorre da §1:** o caminho já tem três polarizadores. Acrescentar um quarto não
esfria nada — polarizador **absorve**, e o que absorve vira calor. Filme polarizador só entra como
**substituto** de um existente, nunca como camada adicional.

---

## 7. O que este reparo NÃO resolve: o foco desigual

`OBSERVADO` (queixa de 2026-09-02): a imagem está com foco estranho **de um lado só**.

Nenhuma das quatro peças ataca isso, e é honesto dizer por quê: **foco é geometria depois do painel**.
Um elemento plano no lado da iluminação (itens 2, 3 e 4 da §1) não desfoca imagem.

Suspeitos, em ordem:

1. **Lente Fresnel frontal empenada** (`HIPÓTESE`, a mais forte). Fresnel dessa classe é acrílico/PMMA, e
   PMMA empena com calor. Deformação de um lado dá foco desigual daquele lado. Inspecionar com **luz
   rasante** procurando ondulação. **Sobre a orientação, ver §7.1 — a nota anterior deste doc ("face
   ranhurada voltada para a lâmpada") era ambígua e não é conclusiva.**

### 7.1. Orientação das duas Fresnel — OPT-S4 (fechado na prática em 2026-09-03)

> **Atualização (2026-09-03):** OPT-S4 **FECHADO na prática** — o dono resolveu a orientação na bancada
> ([doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §1). A contradição entre as fontes abaixo
> continua registrada.

`CORREÇÃO (2026-09-03).` A versão anterior deste doc dizia "face ranhurada voltada para a lâmpada",
frase herdada de um teardown do TD96. Ela é **ambígua na bancada** (não diz de qual das duas lentes fala)
e a questão **não está resolvida**. O levantamento encontrou fontes primárias em contradição direta:

| Fonte | Fresnel traseira | Fresnel frontal |
|---|---|---|
| **`CN109164667A`** — a única patente cuja pilha bate item a item com este aparelho (LED pontual + copo + Fresnel + vidro térmico + LCD + Fresnel + lente, sem fly-eye) | **dentes para o LED** (`LED点光源靠近后菲涅尔透镜的凸透镜202的一面`; o vidro térmico cola na face **plana** `平面镜201`) | **dentes para a lente** (reivindicação 9) |
| **`CN218974761U`** | dentes para o LCD | — |
| **`CN119165714A`** (mesma posição da frontal) | — | **dentes para o LCD** (`菲涅尔透镜的齿面朝向LCD光阀`) |
| **Regra de fabricante** (Fresnel Technologies; Edmund Optics) | dentes para o LCD | dentes para o LCD |

**Por que a regra de fabricante não decide.** Ela é `PROVADA` como regra — *"the grooved side toward the
longer conjugate"*, e no caso colimador *"the best optical results are obtained when the grooved side
faces the longer conjugate"*. Mas a própria Fresnel Technologies chama isso de *"the optically preferred
case"* e cataloga lentes moldadas ao contrário. **É convenção de projeto do molde, não lei física.** Se a
peça foi moldada `grooves-in`, montar "pela regra" é que está errado — e a aparência não revela qual
prescrição o molde usou.

**Teste que decide, na bancada, sem fonte externa (5 min).** Com a lente na mão, apontar para o Sol ou uma
luminária a mais de 20 m e projetar o ponto num papel. Achar o menor ponto e anotar a distância (é a
focal). **Virar a lente e repetir.** A orientação que dá o ponto **menor e mais limpo, sem anel prateado
na coroa externa**, é o lado que o molde quer virado para o feixe colimado. Depois mapear contra a
geometria do chassi: se a focal medida da traseira bater com a distância LED→Fresnel, o lado colimado
dela é o do LCD.

O **anel prateado** é o sinal diagnóstico: `PROVADO` (Fresnel Technologies) — montada ao contrário, a
coroa externa sofre reflexão interna total, *"easily observed as an apparent 'silvering' of the outer
portion"*, e a porção além de ~f/1 fica inútil.

**Duas regras que valem independentemente da fonte:**

1. **Face ranhurada não apoia contra vidro nem contra o painel.** Se um dos sentidos põe as facetas em
   contato com o vidro térmico ou com o polarizador, esse sentido está errado.
2. **Montar como estava vence toda a teoria acima.** Foto do desmonte, marca de contato no berço, resíduo
   de espuma ou poeira incrustada só de um lado — qualquer uma dessas evidências tem precedência.

**Custo de errar:** as duas Fresnel são óptica de iluminação e de campo — **nenhuma forma imagem**.
Inverter **não borra**; produz queda de luz **rotacionalmente simétrica** (vinheta igual nos 4 cantos) e
perda de eficiência, que uma fonte comparável (`CN114047664A`) quantifica acima de **20%**. Ou seja:
errar é barato em risco e **caro em detecção** — dá para perder 20% de luz e nunca perceber. Por isso
**não vale "montar e ver"**; vale acertar antes de fechar.

> **Não usar brilho absoluto antes/depois como critério.** Este aparelho tem escada de brilho e política
> térmica ativas ([doc 34](34-escada-brilho-e-fanmonitor.md)) — ele muda o brilho sozinho. A única
> métrica válida por foto é a razão **canto/centro dentro do mesmo quadro**, com 20 min em regime e o
> mesmo degrau de brilho nas duas capturas.

**E inversão de Fresnel NÃO explica o foco desigual de um lado** (§7): o sintoma dela é simétrico. A
queixa é assimétrica, o que mantém empeno de PMMA e tilt como suspeitos.
2. **Assento do painel no berço** — painel torto ou empenado.
3. **Tilt da lente de projeção.**

O espelho de projeção (item 7) foi inspecionado nesta sessão e está **sem manchas**; é colado de fábrica
e nunca foi removido.

---

## 8. A causa raiz, e o erro nº 1 de quem troca a peça

`PROVADO` (relatos convergentes de reparo): quem troca só o polarizador vê a peça nova queimar em
**cerca de um ano**. Há relato de dois aparelhos perdidos seguidos pelo mesmo motivo.

Este aparelho já está na **segunda troca**. Antes de fechar o gabinete:

1. Limpar filtro e duto (havia resíduo visível no chassi ao redor do bloco óptico)
2. **Girar os dois blowers com o dedo e comparar** — se um estiver duro ou ruidoso, é a causa
3. Confirmar exaustão lateral livre

**Nada no firmware avisa se um soprador morrer.** O FAN-S1 está fechado como **inarmável por software**
neste aparelho ([doc 34](34-escada-brilho-e-fanmonitor.md)): portão `SW_SENSE_TYPE = 0` em
`FanSpeedSense::Run()` e sopradores de 2 fios, sem saída FG. Um blower morrendo produz exatamente a
assinatura "aviso de calor mais frequente", sem nenhum alarme específico.

---

## 9. Proof-of-work

```bash
# linha de base ANTES e DEPOIS da troca, mesmas condicoes (brilho, conteudo, 20 min em regime):
PFL_IP=<ip> ./pfl7560-saude.sh

# a protecao reage? (~65 s, mexe no brilho e volta sozinho)
PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade

# a cor continua correta apos mexer no caminho optico. Desde a 2a troca de LCD
# (2026-10-29, painel -4300) o esperado e vesa; com o -0600 da 1a troca era jeida (doc 40 s1):
PFL_IP=<ip> ./pfl7560-lcd-color.sh status    # esperado hoje: lvds_fmt: vesa
```

**Critério de aceite da troca:** a temperatura da óptica em regime tem de **cair** contra a linha de base
medida antes. Se não cair, a peça não era o gargalo e o problema é fluxo de ar.

> **Ressalva (2026-10-29):** o único número disponível é o do `gtt1`, que mede o **bloco dissipador do
> LED**, não o polarizador (OPT-S7, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3).
> Ele só capta o efeito do filme de forma indireta. Para medir o filme, só um termopar na peça
> ([doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §5, item 2.4).

> **Não usar "não desligou" como critério.** A política térmica deste aparelho só enxerga por causa do
> fix do mux, e a proteção de ventilador está desarmada de fábrica. Ausência de desligamento não prova
> nada aqui — o número do `gtt1` prova.

---

## 10. Pendências que este doc abre e fecha

> **Estado em 2026-10-30** (a coluna "Estado" abaixo já reflete): OPT-S3 e OPT-S4 fecharam em 2026-09-03
> ([doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §6); OPT-S1, OPT-S2 e ART-S1 seguem abertos.

| ID | Severidade | Estado | Item |
|---|---|---|---|
| ~~**POL-S1**~~ | — | **FECHADO (2026-09-02)** | Polarizador é **placa de vidro separada** entre a Fresnel traseira e o LCD, **não laminado**. Medida e eixo iguais aos da peça TD98 136x85. Gate da lista de compras liberado |
| **OPT-S1** | média | **ABERTO** | Transcrever a rota mecânica **deste** chassi (parafusos, ordem, o que é clipe e o que é cola). O dono já desmontou 3 vezes; nada foi anotado. É a última lacuna do §5.1 |
| **OPT-S2** | média | **ABERTO** | Caracterizar o **foco desigual** (§7). Inspecionar a Fresnel frontal com luz rasante antes de fechar |
| ~~OPT-S3~~ | — | **FECHADO (2026-09-03)** | Medir a linha de base de `gtt1` em regime antes/depois da troca e registrar em `evidencias/`. Feito: 58,73 °C com a sala a 35,1 °C ([doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.1), com a ressalva de âncora do [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §2 |
| ~~OPT-S4~~ | — | **FECHADO na prática (2026-09-03)** | **Orientação das duas Fresnel** (§7.1): fontes primárias em contradição direta; a regra de fabricante é convenção de molde, não lei. Resolver pelo teste do ponto no papel e **registrar com foto** a orientação adotada. Errar custa até ~20% de luz sem sintoma perceptível |
| **ART-S1** | média | aberto | Artefato/faixas ainda não caracterizado ([doc 35](35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md)) |

---

## 11. Fontes

**Primárias, verificadas literalmente no HTML bruto:**

- `CN109164667A` — pilha do motor óptico; posição do vidro de isolamento térmico; os dois polarizadores
  do painel; orientação das faces
- `CN113267951A` — cadeia `LED -> light cone -> first Fresnel -> heat insulation glass -> LCD -> second
  Fresnel`
- iFixit guia **175853** (Alliums AP-020, 1LCD de 5,8") — sequência de abertura e passo 6 com as
  dimensões e o `Pull up to remove the polarizer`

**Secundárias:**

- Fórum técnico `znds.com/tv-1148658-1-1.html` — pilha listada da lente para trás, e as duas Fresnel
- Vídeo `youtube.com/watch?v=nYwwLUuSZK8` — **Thundeal TD98**, `Замена поляризационно-отражающего стекла`
  (troca do vidro polarizador-refletor). Existe procedimento publicado para o TD98 sob outro nome
- Legendas oficiais de vídeos de reparo — método do eixo por sobreposição; sintoma de imagem negativa;
  liner e adesivo da folha solta

**Observação direta:** o dono, com o aparelho aberto na bancada em 2026-09-02.

> **Limitação honesta.** Toda fonte web acima descreve **outro aparelho** da mesma classe. O que vale
> para o PFL7560 é o que está marcado `OBSERVADO` — a geometria da §1, as medidas da §4 e o estado das
> peças da §3. O resto é contexto que se mostrou consistente, não planta deste chassi.
