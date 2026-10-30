# 37 - O mecanismo do LSADC: defasagem dos anéis de amostras

Síntese de engenharia reversa de **2026-08-18**, feita sobre
`artifacts/re-termico/libhitvservice.so` (capstone 5.0.7, Thumb; `.text` VMA `0x9b110` / offset `0x93110`,
delta `0x8000`; `.data` delta `0x9000`; símbolos locais recuperados do `.gnu_debugdata`, LZMA em offset
`0x36b7fa`; JUMP_SLOT por `readelf -rW`; fronteiras de função pelo `.ARM.exidx`; xrefs por decodificação
exaustiva em cada offset par).

Este é o achado mais importante do projeto até hoje: explica os dois regimes de `LSADC Error` dos
[doc 34](34-escada-brilho-e-fanmonitor.md) e [doc 35](35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md)
com **um único mecanismo**, sem hipótese elétrica, e dá um experimento falsificável de 2 minutos.

**Convenção deste doc:** `PROVADO NO BINÁRIO` = re-executado sobre o `.so` nesta síntese.
`PROVADO NO LOG` = linha literal em arquivo de `evidencias/`. `HIPÓTESE` = explicação plausível ainda não
testada. `NÃO DETERMINADO` = não se sabe, e está dito que não se sabe.

---

## TL;DR — o mecanismo em 5 linhas

1. `RunDaulRigalMode` (`0x1fd168`) só converte a leitura de um sensor em temperatura quando o **anel de
   amostras daquele sensor está cheio** — `m_index == SW_N`, com `SW_N = 10`.
2. `Thermistor::getTemperature` (`0x21d970`) **avança o índice do anel incondicionalmente**, em toda
   chamada, inclusive nas que falham.
3. Se os dois anéis ficarem **defasados** (deslocamento `k != 0`), eles nunca ficam cheios na mesma
   iteração — e a iteração de leitura dupla válida **nunca acontece**.
4. Consequência: `Thermistor_1`, o sensor da óptica, **nunca é avaliado com dado real**: nem `WARNING`
   (70000), nem `EMERGENCY` (75000). Não é proteção lenta; para o sensor que importa é proteção zero.
   (**Correção, 2026-10-29:** o `Thermistor_1`/`gtt1` fica no **bloco dissipador do LED**, não junto da
   óptica, e nenhum sensor mede o polarizador; OPT-S7, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md)
   §3. O mecanismo deste doc não muda.)
5. **Nada no loop normal ressincroniza os índices.** Só `resetBalance` / `startThermalMonitor` fazem
   isso — na prática, **só o reboot**.

---

## 1. A cadeia provada, instrução por instrução

### 1.1. O modo térmico ativo é `RunDaulRigalMode`

`PROVADO NO BINÁRIO.` `artifacts/ZYCustom_390.ini:79` → `THERMAL_MODE = 0x1001`.

```
RunThermalModeMain @ 0x1fcc38
  cmp.w  r0, #0x1000
  sub.w  r0, r0, #0x1000
  0x1fcc54  tbb [pc, r0]          ; tabela em 0x1fcc58 = 0b 20 57 25 ...
  indice 1 -> 0x1fcc98 -> b.w 0x22eea0
    veneer: bx pc / ldr ip,[pc] / add pc,ip,pc   (literal 0xffe69718)
    -> PLT 0x985c8 -> GOT 0x373194
    = _ZN16ZYThermalManager16RunDaulRigalModeEv @ 0x1fd168
```

Isso resolve o conflito entre dois relatórios anteriores a favor da versão acima.

### 1.2. A avaliação só acontece com o anel cheio

`PROVADO NO BINÁRIO.` `RunDaulRigalMode` usa o **`Thermistor*` como se fosse temperatura** quando
exatamente um dos dois anéis está cheio:

```
0x1fd176  bl   0x200d10          ; Thermistor::instance(0)
0x1fd17a  mov  r5, r0            ; r5 := PONTEIRO
0x1fd17c  blx  0x98484           ; Thermistor::getTemperature  (retorno DESCARTADO)
0x1fd182  ldr  r1,[r5,#0xc]      ; m_index
0x1fd184  ldr  r0,[r0,#4]        ; SW_N
0x1fd186  cmp  r1, r0
0x1fd188  bne  0x1fd196          ; anel NAO cheio -> r7=0 e r5 CONTINUA PONTEIRO
0x1fd18c  blx  0x98640 ; mov r5,r0 ; r7=1     ; anel cheio -> r5 := media real
0x1fd19e  mov  r6, r0            ; idem para Thermistor_1 em r6
0x1fd1ac  bne  0x1fd1b8
0x1fd1b8  cmp  r7,#0 / beq.w 0x1fd43e   ; so sai se AMBOS falharam
0x1fd1c6  blx  0x9864c           ; ThermalSense::RunNotify(r4,      r5)
0x1fd1ce  blx  0x9864c           ; ThermalSense::RunNotify(r4+0x1c, r6)
0x1fd244  movw r3,#0x48c         ; linha 1164, prio 4 (INFO)
0x1fd248  str  r6,[sp,#8]        ; "Thermistor_%lu Upset Balance at Temperature:%d!"  <- o PONTEIRO
0x1fd2ae  blx  0x98658           ; ThermalSense::dispatchProcess -> "LSADC Error", linha 1116, prio 6
```

Símbolos resolvidos nesta síntese: PLT `0x98484` → `_ZN10Thermistor14getTemperatureEv`;
`0x98640` → `getAverageTemperatureEv`; `0x9864c` → `ThermalSense::RunNotifyEi`.

**Casamento exato com o log histórico**, no mesmo milissegundo
(`artifacts/diagnostico/heat.logcat:165-167`, 2026-07-05):

| Linha do log | Origem no binário | Confere |
|---|---|---|
| `RunNotify:977 ... arg3=28223, #0 Temperature:28.2` | `0x1fd1c6` | Thermistor_0 válido |
| `beginBalance:1164 Thermistor_1 Upset Balance at Temperature:-1296474592` | `0x1fd244` (`movw r3,#0x48c` = 1164), `0x1fd242` (`movs r0,#4` = prio I) | ordem, linha e prioridade |
| `dispatchProcess:1116 Thermistor_1 LSADC Error!` | `0x1fd2ae`, `0x201192` (`movs r0,#6` = prio E) | linha e prioridade |

Ordem, número de linha, prioridade e qual termistor: tudo bate.

### 1.3. O anel avança incondicionalmente

`PROVADO NO BINÁRIO.` `Thermistor::getTemperature` @ `0x21d970`:

```
0x21d9ac  str   r3,[r4,#0xc]        ; m_index := i+1     <- INCONDICIONAL
0x21d9ae  str.w r0,[r2,r1,lsl #2]   ; ring[i] := amostra  <- INCONDICIONAL
0x21d9a0-0x21d9a6                   ; m_index percorre 1,2,...,SW_N e volta a 0
```

Os dois `str` estão em **todos** os caminhos, inclusive no de falha. Com `SW_N = 10`
(`artifacts/ZYCustom_390.ini:152`), **`m_index == SW_N` acontece exatamente 1 vez a cada 10 chamadas.**

### 1.4. A aritmética da defasagem

`PROVADO` (aritmética sobre código provado). Em fase, os dois `m_index` batem `SW_N` na mesma iteração:
leitura dupla válida, proteção normal. Com um deslocamento `k != 0`, `idx0 = (n mod 10) + 1` e
`idx1 = ((n+k) mod 10) + 1` **nunca** valem 10 simultaneamente. Consequência mecânica, por 10 iterações
do loop:

| Iterações | O que acontece | Citação |
|---|---|---|
| **8 de 10** | nenhum anel cheio → `beq.w 0x1fd43e`; o loop sai **sem avaliar nada** | `0x1fd1b8` |
| **1 de 10** | Thermistor_0 cheio, Thermistor_1 não → `r6` = ponteiro → `Upset Balance` + `LSADC Error` em Thermistor_1 | `0x1fd1ac`, `0x1fd248` |
| **1 de 10** | Thermistor_1 cheio, Thermistor_0 não → `r5` = ponteiro → `dispatchProcess(r5)` devolve 1 e `0x1fd2b2 cmp r0,#2` / `0x1fd2b4 blo.w 0x1fd43e` **aborta a iteração inteira** — a leitura válida de Thermistor_1 é jogada fora sem ser avaliada | `0x1fd2b2` |

**Consequência dura, PROVADA sob a premissa da defasagem:** enquanto houver `k != 0`, **`Thermistor_1`
— o sensor quente, o que lê 65,8 °C — nunca é avaliado com dado real.** (Ele fica no bloco do LED e não
mede o polarizador, que nenhum sensor mede: doc 40 §3.)
Thermistor_0 (a placa, que fica em ~31 °C) é avaliado em 1 de cada 10 iterações e nunca chega perto de
nenhum limiar.

Isso reproduz os quatro sintomas dos docs 34/35 sem nenhuma hipótese extra:

- erro alternando entre os dois termistores;
- `Achieve Balance` indo a zero (o sense é jogado em `Upset` a cada 10 iterações e nunca estabiliza);
- propriedades sem atualizar (a publicação em `0x2011ca` fica **depois** do `return 1` de
  `dispatchProcess`);
- **só o reboot limpar** — nada no loop normal re-sincroniza os dois `m_index`.

### 1.5. Os dois regimes = duração da defasagem

| Regime | Explicação | Status |
|---|---|---|
| **TRAVADO** (doc 34; doc 35 §2.2) | defasagem permanente: um número **ímpar** de avanços extras em um único termistor. Previsão: ~2 eventos a cada 10 iterações, para sempre, até reboot | efeito **PROVADO**; causa do avanço extra **NÃO DETERMINADO** |
| **TRANSITÓRIO** (`heat.logcat`, 2026-07-05) | defasagem de ~1 iteração: um **par** de avanços extras (um em cada termistor) que cai *entre* a checagem do sensor 0 e a leitura do sensor 1 da mesma iteração; um evento espúrio, fase restaurada na iteração seguinte | **HIPÓTESE 2** (ver §7) |

**O argumento que fecha os dois regimes.** Defasagem permanente prevê ~62 eventos nos 620 s de
`heat.logcat`; observou-se 1. Logo 2026-07-05 **não** foi defasagem permanente. Mas a mesma previsão,
aplicada ao descrito nos docs 34/35 ("a cada ~2 s, nos dois termistores, `Achieve Balance` zero, só o
reboot limpou"), **é exatamente o que a defasagem permanente produz**. O mesmo cálculo que refuta a
hipótese num regime a confirma no outro.

---

## 2. O valor `-1296474592` é um ponteiro, não uma temperatura

`PROVADO NO BINÁRIO.` `-1296474592` = `0xB2B95E20` em complemento de dois (`4294967296 - 1296474592`).
É o conteúdo de `r5`/`r6` quando o `bne` de `0x1fd188` (ou `0x1fd1ac`) desvia: o registrador ainda
carrega o **`Thermistor*` devolvido por `Thermistor::instance()`**, e é ele que vai para o `str` de
`0x1fd248`, dentro do `%d` do `printf`.

Não é temperatura. **Não é sentinela.** A sentinela existe e é outra coisa: `getAverageTemperature`
@ `0x21d9bc` **clampa** qualquer valor fora de faixa em `MIN_VALUE - 1` (`0x21d9dc cmp r0,r2` /
`blt 0x21da04` / `subs r0,r2,#1`), ou seja `-40001`. Um valor de 32 bits arbitrário como
`-1296474592` **não pode** ter saído de `getAverageTemperature`.

Isso mata em definitivo a leitura "lixo do deque do multiplexador vazou para o log" (ver §5).

> **Ressalva honesta.** O *mecanismo* que usa o ponteiro como temperatura está PROVADO. Que aquele
> valor específico seja o endereço do objeto `Thermistor` é inferência de faixa de heap ARM32 — ver
> **HIPÓTESE 3** em §7. Custo para fechar: 5 min com o aparelho no estado
> (`cat /proc/$(pidof hitvservice)/maps`).

---

## 3. Como o `hidebug gtt N` entra no anel

### 3.1. A cadeia, do binder ao `str`

`PROVADO NO BINÁRIO.`

```
binder cus_GetThermalTemp(Parcel&, Parcel&) @ 0x1ddb76
  0x1ddb86  blx 0x974f4  -> GOT 0x372bf8 = ZYThermalManager::getThermalTemp(unsigned long) @ 0x1fbdc4
    0x1fbde8  bl  0x200d10       ; Thermistor::instance(N)
    0x1fbdf2  b.w 0x22ee20       ; veneer, literal 0xffe69654 -> PLT 0x98484
      = Thermistor::getTemperature -> ring[m_index++]   (0x21d9ac / 0x21d9ae)
```

**Cada `gtt N` avança o anel do termistor N e só dele.** É o único caminho externo conhecido capaz de
criar `k != 0`.

Dentro da lib, todos os outros chamadores de `0x98484` — `0x1fcd6c`, `0x1fcf08`, `0x1fd008`, `0x1fd17c`,
`0x1fd1a0`, `0x1fd4e4`, `0x1fd508`, `0x1fda28`, `0x1fda4c`, `0x1fda72`, `0x200f74`, `0x203c54`,
`0x204068` — estão em handlers de `THERMAL_MODE` mutuamente exclusivos pela `tbb` de `0x1fcc54`, ou
avançam os dois anéis **em par**.

### 3.2. Ponto crucial: par preserva a fase, ímpar cria a defasagem

- `gtt 0` **e** `gtt 1` no mesmo par = dois avanços, um em cada anel = **fase preservada**.
- `gtt 0` sozinho (ou qualquer contagem ímpar num só termistor) = **`k != 0`**.

`PROVADO NO LOG (contexto):` `pfl7560-autocaptura.sh:100` emite `gtt 0` e `gtt 1` **em par**. Por isso os
**1060 comandos `gtt`** do corpus histórico produziram **zero** episódios confirmados: a hipótese "sondar
dispara" **nunca foi testada com sondagem ímpar**. Já a sessão do doc 34 sondou os **canais crus 0 a 9**,
o que é assimétrico por construção — e é o único episódio descrito como travado até o reboot.

### 3.3. `gtt 2` é inofensivo

`PROVADO NO BINÁRIO.` Índice inválido cai em `0x1fbdf6`, loga prio 6 na linha `0x81` = 129 e devolve
`MIN_VALUE - 1` em `0x1fbe18`, **sem nunca chamar `getTemperature`**.

Isso explica exatamente por que os `gtt 2` → `-40001` de
`evidencias/2026-07-09/snapshot-antes.txt` e `snapshot-depois.txt` não causaram dano nenhum, e fecha
aquela ponta: **`gtt 2` não avança anel nenhum.**

### 3.4. O elo que ainda falta

`NÃO DETERMINADO:` o trecho `/vendor/bin/hidebug` → binder não foi verificado. Não se desmontou o
binário `hidebug` nem se capturou a transação binder. Custo para fechar: ~20 min (`strings` +
disassembly; o binário já está no aparelho).

---

## 4. Nova ordem de grandeza do risco

`PROVADO NO BINÁRIO — achado colateral de alto valor.` `0x21d992-0x21d996`: o firmware chama
`property_get_int32(<string>, r1)` com `r1` = valor lido do sensor como **default**, e é o **retorno**
que entra no anel (`0x21d9ae`). A string, resolvida do literal pool, é **`vendor.zy.power.tm.temp`**.

Ou seja: essa propriedade **sobrescreve a temperatura de TODOS os termistores**. É um override total da
malha térmica por propriedade de sistema — e, por isso mesmo, o melhor instrumento de teste que existe
(§6).

Dois vizinhos, registrados por completude:

| Propriedade | Estado | Base |
|---|---|---|
| `vendor.zy.power.tm.temp` | **ativa e usada** (override total) | `0x21d992-0x21d996`, `0x21d9ae` |
| `vendor.zy.power.tm.reset` | **inerte** hoje: lida com default 0; o ramo de reset em `0x21df42` só é alcançado por `0x21dec4 beq` quando o contador vale `-1` | `0x21dee8`, `0x21dec4` |
| `vendor.zy.power.tm.loglevel` | existe | `0x21df16` |

---

## 5. Pistas encerradas — não reabrir

Seis alegações de relatórios anteriores (agentes A e C) foram **derrubadas** por verificação direta no
binário. Ficam registradas aqui para que ninguém gaste tempo nelas de novo.

| # | Alegação | Veredito | Código |
|---|---|---|---|
| 1 | **O deque do mux esvazia e trava com `__size_` negativo** | **REFUTADA.** O `dequeue` re-empurra o elemento quando o tamanho pós-`pop` é ≤ 9 (`0x21f018 cmp r2,#9` / `bhi 0x21f054`; repush em `0x21f04a`; `size++` em `0x21f052`). Piso de 10; não esvazia por consumo | `0x21efac-0x21f05c` |
| 2 | **`-1296474592` veio do deque** | **REFUTADA.** O clamp de `0x21da04` impede qualquer lixo de deque de chegar ao log. O valor é um `Thermistor*` (§2) | `0x21d9dc`, `0x21da04` |
| 3 | **`checkAdcValue` "não zera nada"** | **REFUTADA.** `0x21df3c str r0,[r4,#0x10]` grava o retorno de `property_get_int32("vendor.zy.power.tm.reset", 0)` no contador. Zera | `0x21dee8`, `0x21df3c` |
| 4 | **"3 threads disputando o canal 1"** | **REFUTADA.** `SW_CLASS = 3` (`artifacts/ZYCustom_390.ini:151`) → `SenseMuxNtcImpl::getTemperature` @ `0x21e494` **não toca o LSADC**: `ldr r1,[r0,#0x30]` / `cmp #0` / `bge.w 0x21efac` (fila) ou constante de config. A thread térmica consome fila | `0x21e494` |
| 5 | **`and r1,r0,#0xe` desliga o canal 1** | **REFUTADA por aritmética.** `0xE` limpa o **bit 0** = canal 0. O canal 1 é o bit 1 (`HW_LSADC_CHANNEL = 1`, INI:146) e é **preservado** | aritmética |
| 6 | **"`reset` só existe para `SenseSwitcherImpl`; nada restaura"** | **REFUTADA — o erro mais grave dos relatórios anteriores.** Varredura exaustiva de xrefs: `ThermistorHal::LsadcUtils::reset` @ `0x21e0f4` tem **dois** chamadores — `0x21e31e` (Switcher) e **`0x21df68` (`b.w`), dentro de `SenseNtcImpl::checkAdcValue` @ `0x21deb0..0x21dfa8`**, que é o caminho vivo deste aparelho (`0x21dd86 bl 0x21deb0`, chamador único). **Existe recuperação de ADC no fluxo normal** | `0x21df68`, `0x21e0f4` |
| 7 | **Regime travado causado por `SetLSADCKey` com `getConfig` falhando** | **SEM BASE FACTUAL.** O fall-through é real no código, mas nenhum artefato do episódio existe. Hipótese de segunda ordem, sem prioridade | — |

### 5.1. Duas premissas dos docs anteriores também caem

`PROVADO NO LOG.`

- `evidencias/diagnostico-2026-08-17/logcat-full.txt` **não contém nenhum `LSADC Error`** (0 ocorrências;
  12 `Achieve Balance`). As 18 linhas com essa string em `evidencias/2026-08-17/props-233919.tsv` são
  texto do próprio `pfl7560-monitor-props.sh:41`, não do firmware.
- O que aquele log contém é `[checkAdcValue:86] ADC Value keep 0xa4 over 600 times` (linha 1346) e
  `0x60` (linha 1461); e `0x58` em `evidencias/diagnostico-2026-08-18/logcat-verificacao.txt:1040`.
  Prioridade 5 = WARN (`0x21dede movs r0,#5`), linha 86 (`0x21dece movs r3,#0x56`). São
  600 × 100 ms = **60 s de ADC bruto imóvel**, num ADC de 8 bits com degrau de ~2,3 °C: **não é falha**,
  é platô térmico. Coerente com o doc 35 §2.4, que já havia derrubado "valor congelado = erro".

---

## 6. O teste de vivacidade: EXECUTADO E PASSOU (2026-08-18)

Este é o único teste **positivo** da proteção que o projeto tem. Ele não procura o erro; ele pergunta ao
firmware se a política **reage**.

### 6.1. O que foi feito

```
adb shell setprop vendor.zy.power.tm.temp 71000   # WARNING=70000, EMERGENCY=75000
# ~40 s com 'logcat -v time -s ZYThermalManager' gravando em arquivo
adb shell setprop vendor.zy.power.tm.temp ''      # limpar SEMPRE
# ~25 s observando a recuperacao
```

Implementado como a função `vivacidade()` de `pfl7560-saude.sh:163-216`, com trava dura: o script lê
`WARNING_VALUE` e `EMERGENCY_VALUE` do `.ini` **do aparelho, naquele momento**, e **aborta** se `71000`
não ficar estritamente entre os dois. A limpeza do override está num `trap EXIT INT TERM`.

### 6.2. Resultado medido

`PROVADO NO LOG.` Evidências:
`evidencias/vivacidade/2026-08-18-011628.log` (410 linhas) e
`evidencias/diagnostico-2026-08-18/teste-vivacidade.txt` (rodada anterior, mesmo procedimento).

| Grandeza | `vivacidade/2026-08-18-011628.log` | `diagnostico-2026-08-18/teste-vivacidade.txt` |
|---|---|---|
| `Overheat Warning` | **39** | 23 |
| `LSADC Error` | **0** | 0 |
| Escada de brilho — alvo | `Level Change ... => 850` (20 ticks) | `Level Change 1000 => 850` (primeiro tick) |
| Recuperação — alvo | `Level Change ... => 1000` (22 ticks) | — |
| Rampa real do PWM na descida | `990 → 981 → 972 → ... → 877` | `990 → 981 → ... → 914` |
| Rampa real na subida | `914 → 917 → 920` (subindo quando a captura terminou) | — |
| Notificações à UI | 7 × `PostMsg ... argStr=#N Thermal Over Heat!` | 4 |
| `getprop vendor.zy.power.tm.temp` ao final | vazio (checado por `pfl7560-saude.sh:207`) | idem |

Linhas literais do primeiro disparo (`teste-vivacidade.txt`):

```
08-18 01:11:04.463 I/ZYThermalManager: [beginBalance:1164] Thermistor_1 Upset Balance at Temperature:70476!
08-18 01:11:04.464 W/ZYThermalManager: [dispatchProcess:1125] Thermistor_1 Overheat Warning Temperature: 70476!
08-18 01:11:04.465 D/ZYThermalManager: [RunLineChange:1712] Backlight_0 Level Change 1000 => 850!
08-18 01:11:04.465 D/ZYThermalManager: [RunLineChange:1718] Backlight_0 Level Down to 990!
08-18 01:11:06.456 W/ZYThermalManager: [dispatchProcess:1125] Thermistor_0 Overheat Warning Temperature: 71000!
```

**Veredito: a proteção estava viva naquele boot.** O `WARNING` disparou, a escada de brilho atuou até o
piso 850, o brilho voltou sozinho em rampa e o override saiu limpo.

### 6.3. O detalhe que confirma o anel de 10

`PROVADO NO LOG + aritmética.` O **primeiro** aviso não saiu com o valor injetado. Saiu com **`70476`**,
não `71000` — porque o que a política avalia é a **média do anel de `SW_N = 10`**, que sobe
gradualmente à medida que as amostras injetadas substituem as reais.

O `gtt1` real imediatamente antes da injeção era `65763` (linha
`RunNotify:977 ... arg3=65763, argStr=#1 Temperature:65.8!`, 01:10:54.507). E:

```
(9 x 71000 + 1 x 65763) / 10 = 704763 / 10 = 70476,3  ->  70476
```

Casamento exato com o valor logado. O mesmo aparece **espelhado** no
`vivacidade/2026-08-18-011628.log`: lá o `70476` é o **último** aviso (01:16:03.856), quando a média
estava **descendo** depois do override limpo, e o `gtt1` real voltou a `64826` logo em seguida
(01:16:15.816).

> `NÃO DETERMINADO:` a composição exata do anel naquele instante. A igualdade acima é consistência
> aritmética forte com `SW_N = 10`, não prova do estado do anel amostra a amostra.

Detalhe secundário, coerente com o doc 34: no `vivacidade/2026-08-18-011628.log` a escada **já havia
começado a descer antes do primeiro `Overheat Warning`** (`Level Change 968 => 850`), porque
`POLICY_0_THRESHOLD` começa em `66000` e o `gtt1` passou por `67219` / `67947` durante a subida. A
escada de brilho age **antes** do WARNING, exatamente como projetada.

### 6.4. AVISO DE SEGURANÇA — leia antes de rodar

1. **NUNCA injetar `>= 75000`.** `EMERGENCY_VALUE = 75000` e `DEFAULT_PROTECT = 2`
   (`artifacts/ZYCustom_390.ini:84`), e `2` é **desligamento imediato**. `76000` desliga o aparelho na
   hora. O `71000` é fixo no script de propósito; **não torne esse valor configurável.**
2. `71000` dispara a escada de brilho e o aviso de temperatura na tela. É **reversível** ao limpar a
   propriedade — e a limpeza tem de estar num `trap`, não no fim feliz do script.
3. **Sempre** limpar: `adb shell setprop vendor.zy.power.tm.temp ''`.
4. `NÃO DETERMINADO` antes da primeira execução (e agora respondido pela própria execução): se o
   contexto SELinux do shell permitia escrever `vendor.zy.power.*`. Se um `setprop` falhar
   silenciosamente em outro aparelho, o teste é **inconclusivo, não negativo**.

---

## 7. Por que `grep -c 'LSADC Error'` é um detector FRACO

`install.bat:99` e o `INSTALL.md` usavam a contagem de `LSADC Error` no logcat como **o** check de saúde
(corrigido em 2026-08-18: os dois agora apontam o teste de vivacidade como a prova que decide e tratam o
grep só como sinal positivo). Pela §1.4, esse detector é **estruturalmente incapaz**:

| Detector | Por que falha / funciona |
|---|---|
| `logcat -d \| grep -c 'LSADC Error'` | O erro aparece em **2 de cada 10 iterações** do loop. O ring buffer do logcat mede-se em **60-150 s** neste aparelho. Zero ocorrências não prova que a proteção está viva — prova que você não olhou tempo suficiente, ou que o buffer rolou |
| `setprop vendor.zy.power.tm.temp 71000` (§6) | Pergunta **ativa**. Se o `Overheat Warning` sair, a proteção está viva **agora**, sem margem para dúvida. Se não sair, está cega **naquele boot** — reinicie antes de continuar usando |

O `grep` continua útil como sinal **positivo** (se aparecer `LSADC Error`, algo está errado de fato); o
que ele não é, é prova de ausência.

---

## 8. O experimento decisivo pendente (LSADC-S2)

O item de maior alavanca do projeto inteiro. **Custo: 2 minutos e 1 reboot.**

### 8.1. Procedimento

Boot limpo, com log gravando em arquivo, emitir **UM ÚNICO `gtt 0`** — nunca o par — e observar 3 min.

```bash
# pre-registrar antes de rodar, congelado em arquivo
adb shell 'logcat -v time -s ZYThermalManager' > evidencias/lsadc/P2-$(date +%Y%m%d-%H%M%S).log &
adb shell "printf 'custom\ngtt 0\nquit\n' | /vendor/bin/hidebug"    # IMPAR, so o 0
# observar 3 min, depois: PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade  (o teste da secao 6)
adb reboot
```

### 8.2. Braços e previsões (pré-registrar; reboot obrigatório entre braços)

| Braço | Ação | Previsão se a defasagem for a causa |
|---|---|---|
| **P0** controle | boot limpo, nada, 3 min de log | zero `LSADC Error`, `Achieve Balance` normal |
| **P1** par | `gtt 0; gtt 1` juntos, 1 vez, 3 min de log | zero, ou no máximo 1 evento isolado com recuperação |
| **P2** ímpar | **`gtt 0` sozinho**, 1 vez, 3 min de log | `Thermistor_1 Upset Balance` + `LSADC Error` repetindo, `Achieve Balance` = 0, **sem recuperação até o reboot** |
| **P3** confirmação | rodar o teste de vivacidade (§6) logo após P2 | **ausência** de `Overheat Warning` — a proteção está cega |

**Previsão numérica de P2:** ~**2 eventos a cada 10 iterações** do loop, indefinidamente, até o reboot.
Um único P2 positivo **encerra a investigação** e decide o reparo. Um P2 negativo **mata a hipótese
central** e libera as ~30 h de campanha passiva (doc 35, LSADC-S1) como próxima rota.

### 8.3. Riscos a registrar antes de rodar

- Naquele boot **a proteção da óptica fica cega**. Fazer com o **aparelho frio**, **brilho baixo**, e
  **reiniciar imediatamente** ao terminar.
- P3 depende de o `setprop` ser permitido ao shell; se falhar, P3 é inconclusivo, não negativo.
- Qualquer `hidebug` extra contamina o braço. Um comando, um braço, um reboot.
- Se `LSADC Error` aparecer, **reinicie antes de concluir qualquer coisa** (regra do doc 34).

---

## 9. Regras operacionais que decorrem deste doc

1. **Pare de sondar com `hidebug`.** O serviço `pfl7560-autocaptura` já foi desabilitado em 2026-08-18
   (doc 35 §5.1); mantenha assim. É o único caminho externo **provado no binário** capaz de avançar o
   anel de um termistor sozinho.
2. **Se precisar sondar: sempre `gtt 0` e `gtt 1` no mesmo par, nessa ordem. Nunca um só. Nunca canais
   crus.**
3. **Não deixe o adb conectado durante o uso normal.** Custo zero, e é o único confundidor ainda não
   controlado.
4. **Use o teste de vivacidade (§6) no lugar do `grep 'LSADC Error'`** como check de saúde.
5. **Na dúvida, reboot.** É a única operação provadamente capaz de re-sincronizar os dois `m_index`.
   Um reboot custa 40 s; um boot cego custa horas de motor óptico quente (bloco do LED a 65,8 °C) com
   nenhum limiar sendo avaliado.
6. **Não compre peça com base nesta evidência.** Falha simultânea nos dois sensores, cura por reboot e
   valor de 32 bits arbitrário (em vez de saturação de um ADC de 8 bits) são todos **incompatíveis com
   defeito mecânico**. O doc 27 já havia excluído a causa elétrica no chicote.

---

## 10. As três hipóteses deste doc (o que ainda NÃO é fato)

| ID | Afirmação | Por que não é PROVADO | Custo para fechar |
|---|---|---|---|
| **HIPÓTESE 1** | Sondagem **ímpar** (`gtt 0` sozinho, canais crus) é o que produz `k != 0` em campo — e é por isso que os 1060 `gtt` **em par** do histórico nunca causaram episódio | A cadeia `gtt N` → anel está provada, mas **nunca se emitiu um `gtt` ímpar deliberadamente**. A correlação atual é de `n = 1`, e o elo `hidebug` → binder não foi verificado | 2 min + 1 reboot (§8) |
| **HIPÓTESE 2** | O transitório de 2026-07-05 (`heat.logcat:167`) foi uma defasagem de **~1 iteração**: um par de avanços que caiu *entre* a checagem do sensor 0 e a leitura do sensor 1 da mesma iteração, com a fase se restaurando sozinha | É a única construção que explica 1 evento isolado com recuperação em 9,9 s sem contradizer a previsão de frequência — mas é a única testada, não a única possível | depende de §8; se P2 der positivo, fica provável e continua HIPÓTESE |
| **HIPÓTESE 3** | O valor `-1296474592` / `0xB2B95E20` é especificamente o **endereço do objeto `Thermistor`** | O mecanismo que passa um `Thermistor*` como `%d` está PROVADO NO BINÁRIO; que aquele valor seja o ponteiro é inferência de faixa de heap ARM32, sem o mapa de memória do processo | 5 min com o aparelho no estado: `cat /proc/$(pidof hitvservice)/maps` |

---

## 11. Pendências

| ID | Severidade | Estado | Item |
|---|---|---|---|
| **LSADC-S2** | **alta** | **ABERTO — prioridade máxima** | Executar os braços P0/P1/P2/P3 de §8. Previsão numérica pré-registrada: ~2 eventos a cada 10 iterações em P2, sem recuperação até reboot. Custo 2 min + 1 reboot |
| **LSADC-S1** | alta | **ABERTO, despriorizado** | Campanha passiva de ~30 h (doc 35). **Só se justifica DEPOIS que LSADC-S2 der negativo.** Gastar 10 dias de coleta antes de gastar 2 minutos de provocação é a decisão errada |
| **LSADC-S4** | média | **FECHADO (2026-08-18)** | Feito: `INSTALL.md`, `install.bat` (`:do_saude`), `README.md` e o proof-of-work do doc 35 agora apontam `./pfl7560-saude.sh --vivacidade` como a prova que decide, e mantêm o `grep -c 'LSADC Error'` só como sinal **positivo** (§7). Resta o próprio `pfl7560-saude.sh:106`, cuja linha de veredito ainda diz "protecao enxergando" para zero ocorrências |
| **LSADC-S5** | média | **NOVO** | Fechar o elo `/vendor/bin/hidebug` → binder `cus_GetThermalTemp` (§3.4). ~20 min de `strings` + disassembly; o binário já está no aparelho |
| **LSADC-S6** | baixa | **NOVO** | Confirmar HIPÓTESE 3 com `cat /proc/$(pidof hitvservice)/maps` durante um episódio (§10) |
| **LSADC-S7** | baixa | **NOVO, NÃO FAZER AINDA** | Armar `vendor.zy.power.tm.reset = -1` arma o auto-reset do LSADC (`0x21dec4` → `0x21df42` → `0x21e0f4`). **Mas** durante platô térmico normal isso dispararia um reset a cada ~60 s, e o LSADC é compartilhado com o teclado. Efeito colateral desconhecido. **Não fazer antes de LSADC-S2** |
| **LSADC-S8** | baixa | **NOVO** | Procurar tombstone em `/data/tombstones`: o deque do mux pode ser lido com `map begin = NULL` antes do primeiro `setEnable` (`this+0x30` nasce 0 pelos `vst1.32` de `0x21dc6c`/`0x21dc74`, e 0 é `>= 0`). Produziria SIGSEGV do `hitvservice`, não valor espúrio. Nunca foi procurado |
| ~~LSADC-S3~~ | — | **DESCARTADA** (doc 35) | Causa elétrica no chicote GND/NTC. Excluída pelo doc 27 e reforçada por §9.6 |

---

## 12. Proof-of-work

```bash
# 1) a protecao esta viva AGORA? (teste ativo, ~65 s, mexe no brilho e volta sozinho)
#    tem de ser --vivacidade: o script nu so roda as 12 checagens passivas e NAO
#    mostra WARNING nenhum.
PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade
#   esperado: "o WARNING disparou", "a escada de brilho atuou", "override limpo"
#   o log vai para evidencias/vivacidade/<data>.log

# 2) reproducao dos enderecos deste doc
python3 - <<'EOF'
import capstone
f = open('artifacts/re-termico/libhitvservice.so','rb').read()
md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
for vma in (0x1fd168, 0x21d970, 0x1fbdc4, 0x1fcc38):
    off = vma - 0x8000
    for i in md.disasm(f[off:off+0x60], vma):
        print(f'{i.address:#x}\t{i.mnemonic}\t{i.op_str}')
    print('---')
EOF

# 3) contagens do teste de vivacidade (as da tabela da secao 6.2)
grep -c 'Overheat Warning' evidencias/vivacidade/2026-08-18-011628.log     # 39
grep -c 'LSADC Error'      evidencias/vivacidade/2026-08-18-011628.log     # 0
grep -c 'Overheat Warning' evidencias/diagnostico-2026-08-18/teste-vivacidade.txt  # 23

# 4) a aritmetica do anel de 10 (secao 6.3)
python3 -c "print((9*71000 + 65763)//10)"   # 70476, igual ao primeiro aviso logado
```
