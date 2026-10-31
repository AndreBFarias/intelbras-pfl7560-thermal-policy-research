# 34 - Alarme de 70 °C: diagnóstico, escada de brilho e o FanMonitor desarmado

Sessão de **2026-07-29**, disparada por um evento real: o aparelho exibiu **alarme de 70 °C** e o dono
percebeu que os ventiladores "não pareciam ter ligado", com a sala fria. Tudo abaixo foi medido no
aparelho (adb por Wi-Fi, `94.140.14.52:5555`) ou extraído da `libhitvservice.so` por disassembly.

## TL;DR

- **Os ventiladores não falharam.** Estavam em 100% desde o boot, e continuam. O que não existe é a
  **rampa audível**: o fix fixa `DEFAULT_PWM_DUTY = 1000` e `POLICY_0_SPEED` achatado, então eles nunca
  aceleram — já saem no máximo. A pista sensorial de "o cooler entrou" desapareceu por construção.
- **O alarme de 70 °C é o `WARNING_VALUE` do próprio fix** (de fábrica era 43 °C). Disparo legítimo: só o
  `gtt1` alcança 70 °C. Não houve desligamento de proteção — `ro.boot.bootreason = shutdown,userrequested`.
- **O fix tinha zerado toda resposta graduada.** Fans no teto (sem reserva) + brilho no teto (fonte de
  calor escancarada) + `DEFAULT_PROTECT = 2`. Entre 63 °C e o corte em 75 °C o sistema não tinha
  **nenhum atuador** — só avisar a 70 e cortar a 75.
- **Corrigido com uma escada de brilho ancorada no sensor real** (`gtt1`), piso 850 em 70 °C. Provou-se
  por experimento qual sensor a política lê (ver "Prova da amarração").
- **Descoberta grave e independente: a proteção de ventilador travado está DESARMADA.** O firmware tem
  `[FanMonitor]` com shutdown por fan parado; `MONITOR_MODE` precisa ser `1` e é `0` (`.bss`), porque o
  `ZYCustom.ini` de fábrica **não tem a seção**. Mesmo padrão do bug do mux: proteção existente,
  desligada por omissão de config. **Veredito final mais abaixo (FAN-S1): inarmável por software** — o
  portão `SW_SENSE_TYPE = 0` e os sopradores de 2 fios, sem tacômetro; não é só omissão de config.

> **CORREÇÕES POSTERIORES (2026-09-03 e 2026-10-29)** — leia este doc com elas:
> - **O `gtt1` não é o sensor da óptica.** É um NTC encapsulado num olhal no topo do **bloco dissipador
>   do LED**; nenhum sensor mede o polarizador/LCD (OPT-S7 fechado,
>   [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3). Onde este doc diz "óptica" para o
>   `gtt1`, leia "bloco do LED". A amarração política → `gtt1` provada abaixo continua valendo.
> - **O "patamar normal de 61-63 °C" não é fixo.** Em 2026-10-29, com a sala a 34 °C, o `gtt1` ficou em
>   65,8 °C em regime (pico 68,2) e a escada **atuou no uso normal** (brilho 944-974), com ressalvas de
>   medição ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §2).
> - **O "alarme de 70 °C" desta sessão é o relato do dono, na tela.** Nenhum `WARNING` real de 70 °C foi
>   capturado em log neste aparelho ([doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §2.8); os
>   `71,0 °C` do repositório são injetados pelo teste de vivacidade, e a maior leitura real registrada é
>   68,2 °C (2026-10-29). Por isso o LSADC-S1 segue aberto.
> - **Ventiladores:** são 3 — os 2 sopradores `DFH8030S` (12 V, 0,45 A) que a política controla e 1 axial
>   no exaustor do LED, sem controle (OPT-S6, doc 40 §3).

## Estado medido (aparelho, brilho 1000)

| Grandeza | Valor |
|---|---|
| `gtt0` (placa, sensor frio) | 30,1-31,9 °C |
| `gtt1` (sensor quente, real; fica no bloco do LED, doc 40 §3) | **61,15 °C** em regime, travado (n=20, variação zero) |
| `gtt1` com screensaver escuro | 63,42 °C |
| fans (`gfs 0/1`) | `1000` / `1000`, `bAbnormal=0`, `gfe`=1/1 |
| `gbri 0` | `996` — é o **PWM real**, não o nível lógico; `996` é o que o aparelho lê no máximo (o nível lógico correspondente é `1000`) |
| `md5` do `ZYCustom.ini` antes | `1ad641ed…` (byte-exato ao fix anterior, **pré-escada**) |
| `/atv/ini/ZYCustom.ini` | **não existe** (sem conflito de precedência) |

**Efeito do conteúdo na tela é pequeno:** branco 61,15 °C vs screensaver escuro 63,42 °C = 2,27 °C, que é
exatamente um degrau da histerese do firmware. A hipótese de "cena escura cozinha a óptica" foi
**levantada e descartada** nesta sessão.

## Curva brilho -> temperatura (a alavanca do doc 03, medida)

Mesmo conteúdo na tela, única variável o brilho, cada ponto em regime:

| Brilho | `gtt1` em regime | Delta |
|---|---|---|
| 1000 | 61,15 °C | — |
| 900 | **56,81 °C** | **-4,34 °C** |

≈ **0,43 °C por 1% de brilho**. Extrapolando, 1000 -> 850 compra **~6,5 °C** — mais que a faixa inteira
de 5 °C entre `WARNING` (70) e o corte (75). **A escada consegue evitar o desligamento.**

> Armadilha registrada: `sbl` recebe o **valor** (da lista `gbll`), não o índice. `sbl 0` clampa para o
> piso e aparentemente apaga o LED — numa primeira tentativa isso produziu uma queda falsa de ~26 °C que
> foi erroneamente atribuída ao brilho. Use `sbl 1000` / `sbl 850`, ou `sbri <0-1> <0-1000>`.

## Granularidade do ADC e histerese (por que a margem é curta)

O LSADC tem 8 bits e a curva NTC é logarítmica. Reproduzindo a fórmula do doc 08:

| Região | °C por count |
|---|---|
| 54 °C | 0,51 |
| 61 °C | 0,56 |
| 70 °C | 0,63 |
| 75 °C | 0,69 |

`WARNING` (70 °C) = count **81**; `EMERGENCY` (75 °C) = count **73**. A margem inteira entre avisar e
cortar são **8 counts**. Constantes de histerese no binário: **500 mC** (0,5 °C) e **2500 mC** (2,5 °C) —
é o que produz o jitter de 2,27 °C observado no `gtt1`, e é o que impede a escada de oscilar.

## Prova da amarração sensor <-> política (experimento decisivo)

O `ZYCustom.ini` **não tem chave** ligando política a termistor — está no código. Em vez de supor, rodou-se
uma **config-sonda** por um boot: limiares de `[BacklightPolicy]` numa faixa **entre** os dois sensores
(`40000, 42000, 44000, 46000, 48000, 50000`), brilho descendo `1000 -> 850`.

| Leitura pós-boot | Resultado |
|---|---|
| `gtt0` = 30,07 °C (abaixo de todos os limiares) | se a política lesse este: brilho 1000 |
| `gtt1` = 58,95 °C (acima de todos) | se a política lesse este: brilho no piso |
| **`gbri 0` medido** | **850** |

**Conclusão: `[BacklightPolicy]` consome o `gtt1`** — o sensor quente (bloco do LED, doc 40 §3), o que o mux destravou. É
exatamente o que o doc 08 pediu ("apontar fan-ramp/shutdown para o canal quente") e agora está provado,
não inferido.

## A escada de brilho aplicada

`[BacklightPolicy]`, ambas as políticas (`POLICY_0` e `POLICY_1`), `CLASS = 0` (LINE -> interpolação suave):

```
POLICY_0_THRESHOLD  = 66000, 67500, 69000, 70000, 71500, 73000;
POLICY_0_BRIGHTNESS =  1000,  950,  900,  850,  850,  850;
```

| `gtt1` | Brilho | Racional |
|---|---|---|
| até 66 °C | **1000** | patamar normal medido é 61,15-63,42 °C: **zero penalidade no uso normal**. **Ressalva (2026-10-29):** com a sala a 34 °C o regime foi 65,8 °C e a escada atuou no uso normal (doc 40 §2) |
| 67,5 °C | 950 | começa a cortar calor na fonte |
| 69 °C | 900 | |
| **70 °C** | **850** | coincide com o `WARNING_VALUE`: quando avisa, já está no piso |
| 71,5 °C+ | 850 | piso mantido (limite de `FW_LEVEL`, ver abaixo) |

Na descida volta a 1000 sozinho ao reentrar no patamar normal — a histerese do firmware evita flapping.

**Por que o piso é 850 e não menos:** `[Backlight] FW_LEVEL = 750, 800, 850, 900, 950, 1000`. Abaixo de
750 exigiria estender a curva do LED (doc 05, "fase 2"), o que não foi feito. 850 foi a escolha do dono:
perda máxima de 15% de brilho, e só quando quente.

**Robustez sob incerteza:** o desenho é seguro mesmo se a amarração fosse a outra. Com limiares em 66-73 °C,
um sensor frio (`gtt0` ~31 °C) ficaria abaixo de tudo -> brilho 1000, idêntico ao comportamento anterior.
Não piora nada em nenhum cenário.

**Os ventiladores não foram tocados:** `[ThermalPolicy]` segue achatado em `1000` nos 7 degraus e
`DEFAULT_PWM_DUTY = 1000` nos dois `[CoolingFan_*]`. **100% incondicional, por decisão do dono.**

## O FanMonitor desarmado (achado; NÃO armado nesta sessão)

`ZYConfig::FanMonitor` aceita 9 chaves que o `ZYCustom.ini` de fábrica **não contém**:

```
[FanMonitor]
MONITOR_MODE  FULL_VALUE  STOP_VALUE  WARNING_VALUE  EMERGENCY_VALUE
PROTECT_OVERDUE  DEFAULT_NOTIFY  BACKLIGHT_POWERED  DELAY_DETECTION_MS
```

`ZYThermalManager::RunFanMonitorModeMain` (`0x1fcd0c`) é inequívoco:

```
r1 = MONITOR_MODE
cmp r1, #1
beq <roda o monitor>
bx  lr              ; qualquer outro valor: retorna sem fazer nada
```

Defaults compilados: `FULL_VALUE = 1000000` (`.data`), `WARNING_VALUE = 100000` (`.data`),
`EMERGENCY_VALUE = 10000` (`.data`); **todo o resto em `.bss` = 0**, inclusive `MONITOR_MODE`,
`STOP_VALUE`, `PROTECT_OVERDUE` e `DELAY_DETECTION_MS`.

Confirmação independente em runtime: `RunReportRatio` publica `zysys.main_speed` / `zysys.sub_speed`
(percentual, `valor/10`). No aparelho essas props estão **vazias** — o monitor nunca rodou.

### Semântica decodificada (correção de uma leitura errada minha)

`FanSpeedSense::dispatchProcess` (`0x201e70`) compara o valor medido contra `FULL_VALUE` (teto de
sanidade), `STOP_VALUE` e depois `WARNING`/`EMERGENCY`, sempre no sentido **`limiar >= medido` dispara**
— ou seja, **valor maior = fan mais saudável**:

```
measured > WARNING_VALUE   -> estado 3 (normal)
WARNING_VALUE >= measured  -> escala para a checagem de EMERGENCY
STOP_VALUE    >= measured  -> "CoolingFan_%lu Stop Error!"
```

O formato de report é `%4.2frpm` com divisor float **100,0** (constante em `0x20200c`), logo
**`medido = rpm x 100`**. Com isso os defaults compilados são **coerentes** para este hardware:

| Chave | Valor | Em RPM |
|---|---|---|
| `FULL_VALUE` | 1000000 | 10.000 rpm (teto de sanidade) |
| `WARNING_VALUE` | 100000 | 1.000 rpm |
| `EMERGENCY_VALUE` | 10000 | 100 rpm |
| `STOP_VALUE` | 0 | parado |

Um DFH8025S a 100% gira ~4.000-6.000 rpm (o modelo é `DFH8030S` e não tem ficha pública: a faixa de rpm é estimativa, doc 40 §5) -> medido 400.000-600.000, com folga entre o WARNING e o teto.
**Numa primeira análise eu supus a escala 0-1000 e previ um loop de desligamento; estava errado.**

**Kill switch provado, útil para observação:** o fim de `RunSimplifyFanMonitor` é

```
r0 = PROTECT_OVERDUE
cmp   r0, #0        ; se 0, deixa Z=1
it    ne
cmpne r5, r0        ; so compara se PROTECT_OVERDUE != 0
bhi   <shutdown>    ; bhi exige Z=0 -> com 0 NUNCA e tomado
...
setprop sys.powerctl = "shutdown,fan"
```

Com `PROTECT_OVERDUE = 0` o desligamento é **inalcançável por construção**. `r5` acumula amostras ruins
somadas nas duas fans, então `PROTECT_OVERDUE` é o total tolerado antes de desligar. E
`BACKLIGHT_POWERED != 0` faz o monitor consultar o estado do backlight e **retornar cedo** se ele
responder 0 — para observação isso atrapalha, e o gate não é necessário porque o kill switch já protege.

### Tentativa de observação: NÃO funcionou (resultado negativo, registrado)

Foram feitos **dois boots** com a seção presente (`artifacts/historico/ZYCustom_390.OBSERVACAO-FANMONITOR.ini`),
`MONITOR_MODE = 1`, `PROTECT_OVERDUE = 0`, primeiro com `BACKLIGHT_POWERED = 1` e depois com `0`.
Em nenhum dos dois as props `zysys.main_speed` / `zysys.sub_speed` foram publicadas, e não houve
**nenhuma** linha de log do monitor. A seção estava comprovadamente no arquivo ativo e o serviço
`hwtvmw@1.0-service` reiniciou e releu.

O caminho de chamada existe — `ZYThermalManager::RunThermalMngrMain` (`0x1fcbe0`) faz:

```
r0 = MONITOR_MODE
cmp r0, #1
itt eq
moveq r0, r4
blxeq <thunk 0x98580 = RunSimplifyFanMonitor>
```

Logo `MONITOR_MODE = 1` é **necessário mas não suficiente**: falta o `RunThermalMngrMain` ser agendado.
Imediatamente depois dessa chamada ele lê **outra** variável (`0x36ea30`) e despacha por `0x1000` / `2` /
`1` — o padrão bate com **`[MonotonicTask] TASK_MODE`**, seção que **também não existe no `.ini`**
(confirmado no aparelho: `grep -c MonotonicTask` = 0, `grep -c TASK_MODE` = 0), logo está em `.bss` = 0.

### CAUSA REAL, e duas hipóteses minhas REFUTADAS (investigação em 4 frentes, 2026-07-29)

A explicação abaixo substitui duas afirmações erradas que estavam nesta seção. Ficam registradas as duas,
porque errar de forma rastreável é parte do método.

**REFUTADO 1 — "`MONITOR_MODE = 1` desvia o fluxo e degrada o loop térmico".** `RunThermalMngrMain`
(`0x1fcbe0`) não desvia nada; é uma concatenação de três coisas ortogonais:

```
0x1fcbe4  blx <RunThermalModeMain()>      ; politica termica (THERMAL_MODE) -- SEMPRE roda, primeiro
0x1fcbf0  cmp <MONITOR_MODE>, #1
0x1fcbf6  blxeq <RunSimplifyFanMonitor>   ; ADICIONA, nao substitui
0x1fcc02  despacho por <TASK_MODE>        ; terceira coisa, ortogonal
```

O `blx #0x98574` em `0x1fcbe4` (que numa primeira análise ficou sem resolver) é o `RunThermalModeMain`.
E `RunThermalMngrMain` é chamado de `ZYPowerManager::RunInternalModuleMain` — é o próprio corpo do tick.
O caminho do monitor não escreve atuador nenhum (zero `RunPwmChange`/`RunLineChange`), não dorme, e com o
portão do `SW_SENSE_TYPE` fechado custa ~10 instruções por tick. **Não podia degradar cadência.**

**REFUTADO 2 — "falta o `[MonotonicTask] TASK_MODE` para agendar o monitor".** `TASK_MODE` (GOT
`0x36ea30`, provado por `MonotonicTask::init` escrevendo e `MonotonicTask::dump` imprimindo
`"TASK_MODE = %d"`) não é scheduler: liga um **atuador extra** ao fim do tick — `1` →
`RunMonoFanSpeedMode`, `2` → `RunMonoBrightnesssMode`, `0x1000` → `RunMonoBrightnesssCus1Mode`, qualquer
outro (inclusive `0`) → nada. Esses modos escrevem **os mesmos** PWM e backlight que a política térmica.
**Habilitar `TASK_MODE` criaria dois escritores disputando os mesmos atuadores** — era exatamente o
caminho errado. Pista encerrada.

Também morreram, com prova: `RunFeedbackFanMonitor` (`0xfde91`) é uma função **vazia** (`bx lr`; o
endereço é *identical code folding* com ~80 outros símbolos) e `RunFanMonitorModeMain` (`0x1fcd0d`) é
**código morto** (zero callers). O único caminho vivo é o gate inline acima.

**A CAUSA REAL é um portão de uma linha em `FanSpeedSense::Run()` (`0x201c84`):**

```
0x201c9c  ldr r0,[r5,#4]     ; CoolingFan+4 = &cfg.SW
0x201c9e  ldr r0,[r0,#0xc]   ; SW+0xc = SW_SENSE_TYPE
0x201ca0  cmp r0, #0
0x201ca2  beq 0x201d6c       ; RETORNA sem amostrar, sem logar
```

Nos dois boots de observação a seção **estava** no arquivo (verificado: `grep -c MONITOR_MODE` = 1),
`RunSimplifyFanMonitor` **foi chamado**, a lista de fans **não estava vazia** (2 elementos, populados no
construtor a partir de `CoolingFan:SERIAL_NUM = 2`), o flag `[elem+0x10]` nasce em 1 — e o `Run()` de cada
fan voltou na primeira checagem. Nada amostrado. Cadeia integralmente explicada.

**`[CoolingFan_N]` aceita 6 chaves de sense que a fábrica nunca configurou**, e `SW_SENSE_TYPE` despacha
4 modos (`initCoolingFanSense`, `0x20a648`):

| `SW_SENSE_TYPE` | Log do firmware | Requisito |
|---|---|---|
| **`0`** (ausente = default) | `CoolingFan is unsensible!` | nenhum; impl fica NULL |
| `1` | `CoolingFan is sensed by RD polarity!` | `HW_SENSE_GPIO_NUM` + `HW_SENSE_RD_POLARITY` |
| `2` | `... by FG Level, which depends the LSADC!` | `HW_SENSE_LSADC_CHANNEL` |
| `3` | `... by FG Pulse, which depends the FreqCounter!` | `HW_SENSE_GPIO_NUM` + `FW_SENSE_FG_POLES` + `FW_SENSE_FG_FULL_RPM` |

Com impl NULL, `CoolingFan::getSenseSpeed` (`0x20a7a8`) devolve **`FULL_VALUE + 1`** — sentinela sintética
"saudável", deliberadamente acima do teto de sanidade. É o no-op projetado para placas sem tacômetro.

**E o hardware não tem o sinal:** ampliando `media/teardown-05-sopradores-dfh8030s.jpg`, os sopradores têm
cabo de **2 condutores** (vermelho/preto). Um brushless de 2 fios não tem saída FG. Não existe `/sys/class/pwm`,
`hwmon` nem `thermal`; o DTS tem zero nós de pwm/fan/tach; `/proc/interrupts` não tem linha de GPIO e todas
as linhas que crescem estão explicadas (arch_timer, áudio, GPU, VO, VICAP/VPSS a 60 fps, ehci, mmc).

> A etiqueta parece dizer **`DFH8030S`**, não `DFH8025S` como o doc 27 registra. Não foi possível resolver
> o dígito na resolução disponível — **confirmar na etiqueta física** antes de corrigir o doc 27. Só
> importa para spec de RPM num eventual swap. (Fechado em 2026-10-29: `DFH8030S`, 12 V, 0,45 A, doc 40 §4.)

**Veredito FAN-S1: não é "desarmado por omissão de config" como o bug do mux. É INARMÁVEL por software
neste aparelho.** O firmware traz os 3 modos de tacômetro prontos; falta o fio. A via de correção deixa de
ser config e passa a ser hardware (sopradores de 3 fios com FG roteado a um GPIO livre + as 6 chaves).

**Armadilha nova: armar `SW_SENSE_TYPE` sem a fiação é PIOR que deixar desarmado.** Com o objeto de sense
criado lendo hardware inexistente, a leitura vira `STOP_VALUE` → estado 6 → **+10 no acumulador a cada
avaliação (uma a cada 5 ticks)** → com `PROTECT_OVERDUE != 0`, loop de desligamento garantido. Pior ainda:
`SW_SENSE_TYPE = 2` usaria `HW_SENSE_LSADC_CHANNEL`, e ausente ele cai no **canal 0 do LSADC, o dos
termistores** — mexeria na cadeia de medição de temperatura, contra o espírito da invariante 8.

**Sobre a observação dos "956":** rebaixada de fato estabelecido para **hipótese não confirmada**. A rampa
sobe `(delta>>5)+1` por chamada, então de 926 a 1000 leva 50-75 s — observar 956 no meio dela é normal, e
minha leitura de "travou" provavelmente foi artefato (eu tinha o serviço de autocaptura recém-reiniciado
batendo no `hidebug` em paralelo). Precisa de re-teste controlado contra uma linha de base medida.

Enquanto isso não for feito: **se um soprador morrer, nada detecta.** Combinado com brilho alto, é
exatamente o mecanismo que destrói polarizador. Continua sendo o achado de maior severidade desta sessão.

O aparelho foi **devolvido à config canônica** (`252ab7a7`) ao fim da sessão; a config de observação
fica versionada apenas como artefato, não é o que roda.

## Outros achados no firmware (não documentados antes)

### `THERMAL_MODE` é seletor de topologia térmica, não um flag

`ZYThermalManager::RunThermalModeMain` (`0x1fcc38`) despacha por jump table `tbb` com **21 entradas
válidas** (`0x1000`-`0x1014`). Resolvendo os veneers Thumb->ARM e as relocações do GOT:

Tabela **completa** (bytes do `tbb` em `0x1fcc58`: `0b 20 57 25 57 57 57 57 57 57 57 57 57 57 57 57 2a 2f
3c 41 48`, alvo = base + 2·b):

| `THERMAL_MODE` | Função |
|---|---|
| `0` / `1` / `2` (valores pequenos) | `RunTraditionalMode(this,0)` / `RunSimplifyMode(this,0)` / `RunProtectionMode(this,0)` |
| `0x1000` | `RunTraditionalMode(this,0)` **e** `RunProtectionMode(this,1)` |
| **`0x1001`** | **`RunDaulRigalMode()`** — valor atual do aparelho |
| **`0x1002`** | **`pop {r4,pc}` — NO-OP ABSOLUTO** |
| `0x1003` | `RunDaulKjmMode()` |
| **`0x1004`-`0x100f`** | **`pop {r4,pc}` — NO-OP ABSOLUTO** |
| `0x1010` | `RunTripleChuangRongMode()` |
| `0x1011` | `RunBacklightStatusMonitor()`; `RunThermoElectricCoolerTriditionalMode(this,0)`; `RunThermoElectricCoolerMode(this,1)` |
| `0x1012` | `RunTripleBoeMode()` |
| `0x1013` | `SyncFanStrategyMode()`; `SyncBacklightStrategyMode()`; `RunTraditionalMode(this,0)` |
| `0x1014` | `SyncFanStrategyMode()`; `RunTraditionalMode(this,0)` |

**ARMADILHA CRÍTICA:** `0x1002` e `0x1004`-`0x100f` **não são "default provável" — são retorno imediato,
sem política térmica nenhuma.** Escrever qualquer um deles **desligaria a proteção térmica inteira**
(sem rampa de fan, sem dimming, sem WARNING, sem EMERGENCY), silenciosamente. Nunca alterar `THERMAL_MODE`
sem consultar esta tabela.

**Nenhum modo faz sensoriamento de ventilador.** O monitor é gateado só por `MONITOR_MODE`, em
`RunThermalMngrMain`, ortogonal ao `THERMAL_MODE`. Trocar de modo não ajuda o FAN-S1.

### TM-S1 RESPONDIDO: Rigal vs KJM é refatoração, não topologia — não alterar

O `[Global] CONFIG_MODEL` é `KJM_5H039_412` mas roda `0x1001` (Rigal). Comparados os dois grafos de
chamada: **ambos** fazem `Thermistor::getTemperature()` ×2 → `getAverageTemperature()` ×2 →
`ThermalSense::RunNotify` ×2 → `dispatchProcess` ×2 → `RunProtect` ×2, com as **mesmas** constantes de
histerese (`0x1f4` = 500 mC, `0x9c4` = 2500 mC) nos mesmos offsets. A única divergência é o despachante de
atuação: Rigal usa 4 sobrecargas de `RunThermalDualProcess` (expansão combinatória 2×2 normal/anormal),
KJM usa `RunThermalProcessEx(initializer_list<ProcessChannel>)` (genérico N-canais). **Nenhum dos dois toca
`FanSpeedSense`.** O `.ini` de fábrica e os 4 perfis históricos A/B/C/D todos usam `0x1001`.

**Veredito: divergência benigna. Não há ganho em trocar e há risco. Não alterar.** Ressalva: o mapeamento
sensor→atuador dentro de `RunThermalDualProcess` vs `RunThermalProcessEx` não foi comparado — não é
necessário para nenhuma decisão pendente.

### `[Thermal]` aceita limiares por sensor

Existe `ZYConfig::Thermal::Preference` com `init(HiCfgINI*, char)`, parseando `%c_NAME`,
`%c_WARNING_VALUE`, `%c_EMERGENCY_VALUE`, sob o prefixo de chave `Thermal:` (confirmado: a string é
montada como `"Thermal:"` + char + sufixo). `PREFERS` é um `vector` redimensionado para **exatamente 4**
entradas de 20 bytes, mais um `BASE` de fallback, mais `SUPPRESS_OVERFLOW_ALERT` /
`SUPPRESS_UNDERFLOW_ALERT`. Nada disso é usado pelo `.ini`.

Daria limiar independente ao `gtt0` e ao `gtt1` em vez de um par global. **Não aplicado:** a grafia exata
do índice (`0_WARNING_VALUE` vs `A_WARNING_VALUE`) não foi provada, e o par global 70/75 já cobre o caso
real (só o `gtt1` chega perto). Ganho marginal, risco desnecessário.

### Nomes de propriedade invertidos

`zysys.env_temp` = 59,0 °C e `zysys.light_temp` = 31,4 °C. O sensor **quente** (`gtt1`, no bloco do LED) é publicado
como `env_temp` ("ambiente") e o **frio** (placa, `gtt0`) como `light_temp` ("fonte de luz") — invertido em
relação à física. É provavelmente o `env_temp` que a UI mostra no alarme de tela.

### Políticas que a HAL anuncia e o `.ini` nunca define

`stp` aceita `STANDARD:0 COOLING:1 QUIET:2 FAST:3 MAXSPEED:-1`; `sbp` aceita `CUS1:2`, e existe
`RunMonoBrightnesssCus1Mode`. O `.ini` define `POLICY_NUM = 2` com as duas políticas idênticas. Sem ação
necessária (as fans já estão no máximo incondicional), registrado por completude.

## Proof-of-work desta sessão

```bash
# 1) integridade das copias do config (6 checagens)
make check     # todas OK com INI_FIX_MD5 = 252ab7a72a007a8b79b3fc86bd5c0d19

# 2) estado no aparelho apos aplicar + reboot
adb -s <ip>:5555 shell 'md5sum /vendor/etc/ZYCustom.ini; ls -laZ /vendor/etc/ZYCustom.ini'
#   252ab7a72a007a8b79b3fc86bd5c0d19 · mode 0644 · u:object_r:vendor_configs_file:s0

adb -s <ip>:5555 shell "printf 'custom\ngtt 0\ngtt 1\ngfs 0\ngfs 1\ngbri 0\nquit\n' | /vendor/bin/hidebug"
#   gtt0 ~31 C · gtt1 ~57-63 C · fan 1000/1000 · brightness 1000 (patamar normal, sem penalidade)
```

Verificado no aparelho após reboot: md5 correto, metadados corretos, fans 1000/1000, brilho 1000 no
patamar normal.

### A escada atuando e recuperando (log real, não extrapolação)

Num boot com o chassi já encharcado de calor (vários reboots seguidos), `gtt1` passou de 66 °C, a escada
atuou e o brilho caiu abaixo de 1000. Ao voltar ao patamar normal, o firmware **recupera em rampa**:

```
[RunLineChange:1712] Backlight_0 Level Change 926 => 1000!
[RunLineChange:1715] Backlight_0 Level Up to 929!
... 932 ... 935 ... 938 ... 940 ... 942 ... 944 ... 946 ... 948 ... 950 ... 952 ... 954 ... 956 ...
```

Passos de 2-3 unidades por tick de 2 s, alvo `1000`. Medido no mesmo instante: `gtt1` = 56,81 °C (abaixo
do 1º limiar, logo alvo 1000) e `gbri 0` = 956, em recuperação. **Isto fecha o ESC-S1:** a escada engata
quando esquenta e volta sozinha ao brilho cheio, de forma gradual — sem salto perceptível na tela.
O `RunLineChange` (`CLASS = 0`, LINE) é o que produz essa rampa; com `CLASS = 1` (STEP) seria degrau seco.

## ARMADILHA OPERACIONAL: sondar canais do LSADC direto envenena a proteção térmica até o reboot

Descoberto do jeito ruim, durante esta sessão. **Severidade alta, e é armadilha de quem investiga, não
defeito do produto.**

`Thermistor::getAverageTemperature()` (`0x21d9bc`) devolve a sentinela **`MIN_VALUE - 1`** (= `-40001`) se
**qualquer** amostra do ring de `SW_N = 10` for `< MIN_VALUE`. E `ThermalSense::dispatchProcess` (`0x20116c`)
testa isso **primeiro**, na linha 1116:

```
r0 = MIN_VALUE ; cmp r0, r5 ; ble <caminho normal>
ALOGE("Thermistor_%lu LSADC Error!") ; return 1
```

Os ramos de `WARNING` (`Overheat Warning`) e `EMERGENCY` ficam **a jusante** desse teste. Com a média
envenenada, **não existe avaliação de WARNING nem de EMERGENCY** — a proteção térmica fica cega de novo,
por um caminho diferente do bug do mux.

**Sequência observada:** após um agente sondar os canais do LSADC direto (`0` a `9`, com `4`-`9`
retornando erro), o log passou a acumular `Thermistor_0/1 LSADC Error!` a cada ~2 s, **ininterruptamente**,
com **zero** linhas de `Achieve Balance`. O serviço Android confirmava (`onThermalErrorLsadc`). Duração:
todo o restante daquele boot.

**Discriminação feita (importa para não culpar o fix):**

| Estado | `LSADC Error` | Média válida |
|---|---|---|
| Antes de qualquer escrita minha (config `1ad641ed`, 20:44) | 0 | válidas (`Temperature:61.2!`) |
| Após o sondamento, config canônica `252ab7a7` | 62 e contando | **0** |
| Meu serviço de captura parado por 100 s, mesma config | 62 (continua) | 0 |
| **Reboot limpo, config canônica `252ab7a7` idêntica** | **0** | **válidas (`31.9℃` / `63.4℃`)** |

Ou seja: **não é a escada de brilho, não é a config, e não é o polling de 30 s do monitor** (que rodava em
20:44 com médias válidas). É estado de ADC/mux corrompido pelo sondamento direto, e **um reboot limpa.**

**Regras que decorrem disso:**

1. **Nunca sondar canais do LSADC direto neste aparelho** (nem canais inválidos "só para ver"). Use
   `gtt 0` / `gtt 1`, ou melhor, as props `zysys.light_temp` / `zysys.env_temp` (29 ms, não forçam
   comutação de mux, fidelidade verificada em 0,1 °C contra o `gtt`).
2. Se aparecer `LSADC Error` no log, **reinicie antes de concluir qualquer coisa** — e desconfie de
   instrumentação própria antes de acusar a config.
3. `LSADC Error` no log é sinal de que **a proteção térmica está cega naquele boot**. Vale um check
   explícito no `status` dos instaladores.

## Armadilha metodológica: símbolo exportado não implica código vivo

Neste binário o linker deixou **clones exportados órfãos**. `FanSpeedSense::RunReportRpm`,
`RunReportRatio`, `RunStart` e `RunStop` têm **zero call sites** — o código real foi inlinado dentro de
`dispatchProcess`. E `RunFeedbackFanMonitor` é `bx lr` por *identical code folding* (o mesmo endereço
serve ~80 símbolos, incluindo destrutores). A escala `medido = rpm × 100` foi originalmente deduzida
analisando o `RunReportRatio` — **uma função que nunca executa**. A conclusão sobreviveu porque o
`dispatchProcess` usa as mesmas constantes e o caminho de FG pulse mostra `60.0`/`100.0` de forma
independente, mas o método foi por sorte. **Confirme call sites antes de tirar conclusão de uma função.**

## Pendências que esta sessão abre

| ID | Severidade | Estado | Item |
|---|---|---|---|
| **FAN-S1** | **alta** | **FECHADO como inarmável** | O monitor é **inarmável por software**: portão `SW_SENSE_TYPE = 0` em `FanSpeedSense::Run()`, e os sopradores são de 2 fios (sem FG). Não é omissão de config como o bug do mux. Correção exigiria **hardware** (sopradores de 3 fios + as 6 chaves `*SENSE*`). **Não armar `SW_SENSE_TYPE` sem a fiação — é pior que deixar desarmado.** |
| TM-S1 | média | **FECHADO** | Rigal vs KJM diferem só no despachante de atuação; sensoriamento idêntico. Divergência benigna, **não alterar**. |
| ~~`[MonotonicTask]`~~ | — | **ANULADA** | Pista encerrada: `TASK_MODE` não é scheduler, é atuador extra que disputaria PWM/backlight com a política térmica. |
| **LSADC-S1** | **alta** | **ABERTO, despriorizado** (estado no [doc 37](37-mecanismo-lsadc-defasagem-dos-aneis.md) §11) | Verificar, sob uso real e com o aparelho quente, se o `WARNING` de 70 °C é de fato avaliado (contar `Overheat Warning` vs `LSADC Error` com `gtt1 > 70 °C`). Hoje sabemos que a média fica válida em boot limpo, mas nunca vimos o `Overheat Warning` disparar. Somente leitura. Em 2026-10-29 a maior leitura real foi 68,2 °C: continua sem `WARNING` real registrado. |
| VIGIA-S1 | média | aberto, **premissa REFUTADA** | ~~Ancorar o vigia no hook `sys.boot_completed` que **já existe** no `.rc` stock (`exec … /data/local/nlsu/update_after_boot.sh`)~~ — **`/data/local/nlsu/` NÃO existe neste aparelho** (doc 35 §6; artefato `evidencias/diagnostico-2026-08-17/pos-reboot/artefatos-ausentes.txt`). O hook não tem diretório de destino aqui, então **não** dispensa `.rc` novo em `/vendor` — a ancoragem por `.rc` em `/vendor/etc/init/` volta a ser o caminho, com precedente empírico a favor (foi assim que o `nl_lvds.rc` funcionou). O item em si segue aberto: enquadrar como "resposta graduada esgotou e ainda esquenta", **não** como "detector de fan travada" (não isola a causa: obstrução, ambiente quente e pá quebrada dão a mesma assinatura). Premissa não provada da sprint 19: que o init varre `/vendor/etc/init/*.rc`. |
| **ESC-S1** | baixa | **FECHADO** | Escada verificada atuando e recuperando em rampa, com log (`Level Change 926 => 1000`, subindo 2-3/tick). Falta apenas ver o pior caso de uso real (filme longo) para confirmar que o piso 850 segura abaixo de 75 °C. Em 2026-10-29 atuou no uso normal (brilho 944-974, doc 40 §2). |
| PREF-S1 | baixa | aberto | Provar a grafia das chaves de `Thermal::Preference` se algum dia forem necessárias. |
| **INT-S1** | média | **FECHADO** | Incidente: o pre-commit global apagou trailing whitespace dos `ZYCustom.ini` e derrubou o md5 (quebrando o gate do pendrive). Corrigido com atributo `byte-exact` no `.gitattributes` versionado, honrado pelo hook. |
