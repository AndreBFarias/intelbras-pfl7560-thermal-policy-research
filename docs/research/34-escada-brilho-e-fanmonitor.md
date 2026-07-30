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
  desligada por omissão de config.

## Estado medido (aparelho, brilho 1000)

| Grandeza | Valor |
|---|---|
| `gtt0` (placa, sensor frio) | 30,1-31,9 °C |
| `gtt1` (óptica, sensor real) | **61,15 °C** em regime, travado (n=20, variação zero) |
| `gtt1` com screensaver escuro | 63,42 °C |
| fans (`gfs 0/1`) | `1000` / `1000`, `bAbnormal=0`, `gfe`=1/1 |
| `gbri 0` | `1000` |
| `md5` do `ZYCustom.ini` antes | `1ad641ed…` (byte-exato ao fix anterior) |
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

**Conclusão: `[BacklightPolicy]` consome o `gtt1`** — o sensor da óptica, o que o mux destravou. É
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
| até 66 °C | **1000** | patamar normal medido é 61,15-63,42 °C: **zero penalidade no uso normal** |
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

**Por que NÃO foi armado:** `FanSpeedSense::dispatchProcess` (`0x201e70`) compara o valor medido contra
`FULL_VALUE` (limite superior de sanidade) e `STOP_VALUE`, e depois contra `WARNING`/`EMERGENCY`. Com
`FULL_VALUE = 1000000` e um valor medido na escala 0-1000, a razão calculada cairia **abaixo** de
`EMERGENCY` (10000) permanentemente -> risco real de **loop de desligamento no boot**. Não há como
calibrar `FULL_VALUE` por análise estática: precisa do valor de tacômetro real, que só é publicado quando
o monitor roda (galinha-e-ovo).

**Calibração segura em duas etapas (proposta, requer boot supervisionado):**

1. **Etapa observação:** `MONITOR_MODE = 1` com `WARNING_VALUE = 0` e `EMERGENCY_VALUE = 0` (nada pode
   ficar abaixo de zero -> a proteção não pode disparar), `PROTECT_OVERDUE` alto. O monitor roda e
   **publica** `zysys.main_speed`/`sub_speed`. Ler os valores reais com as duas fans girando.
2. **Etapa armar:** com o full-scale real conhecido, definir `FULL_VALUE` correto e
   `WARNING`/`EMERGENCY` como fração dele (ex.: 10% e 1%), e validar em boot supervisionado com o
   pendrive de resgate à mão.

Enquanto isso não for feito: **se um soprador morrer, nada detecta.** Combinado com brilho alto, é
exatamente o mecanismo que destrói polarizador. É o achado de maior severidade desta sessão.

## Outros achados no firmware (não documentados antes)

### `THERMAL_MODE` é seletor de topologia térmica, não um flag

`ZYThermalManager::RunThermalModeMain` (`0x1fcc38`) despacha por jump table `tbb` com **21 entradas
válidas** (`0x1000`-`0x1014`). Resolvendo os veneers Thumb->ARM e as relocações do GOT:

| `THERMAL_MODE` | Função |
|---|---|
| `0x1000` | `RunProtectionMode(size_t)` |
| **`0x1001`** | **`RunDaulRigalMode()`** — valor atual do aparelho |
| `0x1003` | `RunDaulKjmMode()` |
| `0x1010` | `RunTripleChuangRongMode()` |
| `0x1011` | `RunThermoElectricCoolerMode(size_t)` |
| `0x1012` | `RunTripleBoeMode()` |

O `[Global] CONFIG_MODEL` do aparelho é **`KJM_5H039_412`**, mas a topologia térmica roda o modo
**Rigal** (`0x1001`), não o **KJM** (`0x1003`). **Não se afirma que isso está errado** — pode ser escolha
do ODM Newlink para esta placa. Provar exigiria comparar as duas funções e o mapeamento sensor->atuador
de cada uma. Fica registrado como divergência a investigar; **não mexer sem isso.**

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

`zysys.env_temp` = 59,0 °C e `zysys.light_temp` = 31,4 °C. O sensor **quente** (óptica, `gtt1`) é publicado
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
patamar normal. A atuação da escada (queda a 850) foi comprovada pelo experimento da sonda descrito acima.

## Pendências que esta sessão abre

| ID | Severidade | Item |
|---|---|---|
| **FAN-S1** | **alta** | Calibrar e armar o `[FanMonitor]` (2 etapas acima). Hoje fan travada não é detectada. |
| TM-S1 | média | Comparar `RunDaulRigalMode` vs `RunDaulKjmMode` e decidir o `THERMAL_MODE` correto para `CONFIG_MODEL = KJM_*`. |
| ESC-S1 | baixa | Observar a escada em uso real por algumas sessões: confirmar que 850 basta para segurar abaixo de 75 °C no pior caso. |
| PREF-S1 | baixa | Provar a grafia das chaves de `Thermal::Preference` se algum dia forem necessárias. |
