# 02 - Sistema térmico ATUAL (stock V1.0.0.9)

Todos os valores abaixo foram lidos e conferidos manualmente em
`artifacts/ZYCustom.ini.ORIGINAL` (`/vendor/etc/ZYCustom.ini`, 11.878 bytes).
Temperaturas em milésimos de grau C (miliC); velocidades e brilho em por-mil (0-1000 = 0-100%).

## Sensores

- 2x termistor NTC **`ZL103SAF`** (10k), seções `[Thermistor_0]` e `[Thermistor_1]`.
- Lidos por **um único canal do LSADC** da HiSilicon (`HW_LSADC_CHANNEL=1`), multiplexados por um
  mux analógico **`BL1551B`** no `GPIO4_4` (`[Multiplexer] DEFAULT_SWITCH_DELAY_MS=200`).
- Modelo Beta/Steinhart: `FW_NTC_B=3345.646939`, `FW_NTC_LNa=-8.964791936`, faixa -40..120 C.
- **Não há sensor de CPU/GPU/DDR.** Os NTCs são sensores de placa/ar perto da óptica.

> **CORREÇÃO (2026-10-29)** — onde o NTC fica de verdade: o 2º termistor (`gtt1`) é um NTC encapsulado
> num olhal parafusado no topo do **bloco dissipador do LED**; mede o dissipador do LED, não o
> polarizador nem o LCD, e **nenhum sensor do aparelho mede o polarizador/LCD** (OPT-S7 fechado,
> [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3). Onde este doc fala em sensor
> "perto da óptica", leia "no bloco do LED".

- Leitura em runtime via HAL `cus`: `gtt <0-2>` (GetThermalTemp), `gtc` (GetThermalCount).

## Curva dos coolers - `[ThermalPolicy]`

2 sopradores, PWM 36 kHz. O `.ini` chama a curva de `FW_DFH8025S`, mas a etiqueta diz `DFH8030S`, e há um
3º ventilador fora da política ([doc 07](07-hardware-upgrade.md#sopradoresventiladores-troca)).
`POLICY_NUM=2`, mas as 2 políticas são idênticas
(`STANDARD` e `2ND_STANDARD`); os modos `COOLING/QUIET/FAST/NONE` que a HAL anuncia NAO estão configurados.

| Temp NTC (C) | 25 | 27 | 29 | 31 | 33 | 35 | 36 |
|---|---|---|---|---|---|---|---|
| Velocidade comandada (por-mil) | 500 | 575 | 650 | 725 | 825 | 925 | **1000** |

A velocidade comandada passa pela tabela de cada fan (`FW_SPEED_CURVE` -> `FW_PWM_DUTY`):

- `[CoolingFan_0]` `DEFAULT_PWM_DUTY=200`; `FW_PWM_DUTY = 200,350,475,600,725,850,1000`
- `[CoolingFan_1]` `DEFAULT_PWM_DUTY=150`; `FW_PWM_DUTY = 325,450,575,725,875,875,1000`
  (a linha `FW_SPEED_CURVE` do Fan_1 tem um typo literal `825. 925`)

Leitura/escrita em runtime via HAL `cus`: `sfs <fan 0-1> <0-1000>` (SetFanSpeed), `gfs` (GetFanSpeed), `gfc` (GetFanCount).

**Interpretação:** os fans já saem de 50% a 25 C e saturam em **100% a 36 C**. Acima de 36 C não há mais fan a dar.

## Dimming da fonte de luz - `[BacklightPolicy]` / `[Backlight]`

Reduz o brilho do LED conforme a temperatura sobe (proteção da óptica). `POLICY_0` = `POLICY_1` (iguais).

| Temp NTC (C) | 27 | 29 | 31 | 33 | 35 | 36 |
|---|---|---|---|---|---|---|
| Brilho (por-mil) | 1000 | 950 | 900 | 850 | 800 | **750** |

- `[Backlight]` `HW_PWM_NUM=5`, `SW_BRI_CTRL=2` (PWM_DUTY), `DEFAULT_PWM_FREQUENCY=1800`, `DEFAULT_PWM_DUTY=1000`, `FW_NAME=T6`.
- Runtime via HAL `cus`: `sbl`/`gbl` (Set/GetBacklightLevel).

**Interpretação:** quando frio, roda a 100% de brilho (calor máximo na óptica). Só desce (até 75%) quando já quente.

## Proteção / desligamento - `[Thermal]`

```
THERMAL_MODE    = 0x1001
MAX_VALUE       = 120000   ; 120 C
MIN_VALUE       = -40000
WARNING_VALUE   =  43000   ; 43 C  -> aviso de superaquecimento
EMERGENCY_VALUE =  45000   ; 45 C  -> emergência
DEFAULT_PROTECT = 2        ; 0:off 1:on 2:desliga IMEDIATAMENTE
BACKLIGHT_EN    = Y        ; amarra a fonte de luz na proteção
```

Além disso, o HAL tem intertravamento de segurança (strings literais):
- `"Dangerous operation if enable backlight with Fan off"`
- `"Dangerous operation if disable fan with Backlight on"`
- `FanMonitor` -> `"shutdown by reason fan monitor"` se detectar fan travado/anormal.
- Sequência de emergência: `"[1]. setup gpio to mute audio device & set led on"`, `"[2]. set panel power off"`.

## Resumo do que é editável (alvos da build)

| Parâmetro | Seção | Efeito | Prioridade p/ salvar a óptica |
|---|---|---|---|
| `POLICY_0_BRIGHTNESS` (teto e piso) | `[BacklightPolicy]` | limita o brilho -> corta calor na FONTE | **ALTA** |
| `POLICY_0_THRESHOLD` (dimming) | `[BacklightPolicy]` | dimming começa mais cedo | ALTA |
| `POLICY_0_SPEED` / `POLICY_0_THRESHOLD` | `[ThermalPolicy]` | fans a 100% mais cedo, piso mais alto | MEDIA |
| `DEFAULT_PWM_DUTY` | `[CoolingFan_0/1]` | fan já forte no boot/idle | MEDIA |
| `WARNING_VALUE` / `EMERGENCY_VALUE` | `[Thermal]` | desligar antes (rede de segurança) | ALTA (mas calibrar com dados) |

Proposta concreta de valores: ver [doc 05](../archive/05-ZYCustom.ini-proposto.md), arquivado.
