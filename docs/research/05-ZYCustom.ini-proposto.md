# 05 - Proposta de `ZYCustom.ini` (build agressiva) - RASCUNHO PROVISORIO

Status: **provisório.** Os valores de fan são seguros (domínio 0-1000 conhecido). Os de brilho ficam,
por ora, no domínio validado (750-1000). Os limiares de desligamento **devem ser calibrados com o
diagnóstico ao vivo** (`gtt`) antes de baixar. Base: `artifacts/ZYCustom.ini.ORIGINAL`.

Convenção: temperatura em miliC (43000 = 43 C); velocidade/brilho em por-mil (1000 = 100%).

---

## Mudança 1 - Fans mais agressivos `[ThermalPolicy]`  (prioridade MEDIA, risco baixo)

Objetivo: nunca ficar preguiçoso; 100% bem antes do teto de 36 C; piso alto.

STOCK:
```
POLICY_0_THRESHOLD = 25000, 27000, 29000, 31000, 33000, 35000, 36000
POLICY_0_SPEED     =   500,   575,   650,   725,   825,   925,  1000
```
PROPOSTO (aplicar igual em POLICY_0 e POLICY_1):
```
POLICY_0_THRESHOLD = 24000, 26000, 28000, 30000, 32000, 34000, 36000
POLICY_0_SPEED     =   750,   850,   950,  1000,  1000,  1000,  1000
```
Efeito: piso 75% (vs 50%), 100% já a 30 C (vs 36 C).

## Mudança 2 - Fans fortes no boot/idle `[CoolingFan_0/1]`  (risco baixo)

STOCK: `DEFAULT_PWM_DUTY = 200` (Fan_0) e `= 150` (Fan_1).
PROPOSTO: `DEFAULT_PWM_DUTY = 500` em ambos (fan já girando forte antes da política assumir).
Manter `FW_PWM_DUTY`/`FW_SPEED_CURVE` como estão (corrigir o typo `825. 925` -> `825, 925` no Fan_1).

## Mudança 3 - Brilho mais baixo/dimming mais cedo `[BacklightPolicy]`  (prioridade ALTA - corta calor na FONTE)

Objetivo: reduzir a luz que aquece o polarizador. Esta é a alavanca que mais protege a óptica.

STOCK:
```
POLICY_0_THRESHOLD  = 27000, 29000, 31000, 33000, 35000, 36000
POLICY_0_BRIGHTNESS =  1000,   950,   900,   850,   800,   750
```
PROPOSTO - fase 1 (domínio validado 750-1000; aplicar em POLICY_0 e POLICY_1):
```
POLICY_0_THRESHOLD  = 25000, 27000, 29000, 31000, 33000, 35000
POLICY_0_BRIGHTNESS =   900,   850,   800,   775,   750,   750
```
Efeito: teto 90% mesmo a frio (vs 100%), dimming começa a 25 C, piso 75%.

PROPOSTO - fase 2 (EXPERIMENTAL, precisa validar com `sbl` ao vivo antes de gravar):
Para ir abaixo de 75%, é preciso estender a curva do LED em `[Backlight]`:
```
FW_LEVEL            = 600, 650, 700, 750, 800, 850, 900, 950, 1000
FW_BRIGHTNESS_CURVE = 600, 650, 700, 750, 800, 850, 900, 950, 1000
```
e então usar BRIGHTNESS até ~600-650. **Só fazer isso após confirmar via `sbl 0 600` que o LED aceita e a imagem fica ok.**
Alternativa a testar: baixar `[Backlight] DEFAULT_PWM_DUTY` de 1000 para ~800 como teto global (validar interação com a política).

## Mudança 4 - Desligar antes (rede de segurança) `[Thermal]`  (prioridade ALTA, CALIBRAR)

O comportamento "se chegar em X graus, desliga" JA EXISTE: `EMERGENCY_VALUE` + `DEFAULT_PROTECT=2`.
Só precisamos escolher o X certo — e X depende de quanto o NTC lê quando a óptica já está no limite.

> **Ressalva (2026-10-29):** o NTC quente (`gtt1`) fica no bloco dissipador do LED, não na óptica, e
> nenhum sensor mede o polarizador/LCD (OPT-S7, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md)
> §3). O X escolhido (70/75 °C) protege o LED e a placa, não o filme
> ([doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §3.6).

STOCK (manter até o diagnóstico):
```
WARNING_VALUE   = 43000   ; 43 C
EMERGENCY_VALUE = 45000   ; 45 C -> desliga imediato
DEFAULT_PROTECT = 2
```
PROPOSTO: **não baixar no chute.** Rodar o `gtt` durante um aquecimento até o ponto em que você hoje considera
"quente demais / risco de dano", anotar a leitura do NTC nesse ponto, e definir:
```
WARNING_VALUE   = (leitura_no_ponto_de_alerta)
EMERGENCY_VALUE = (leitura_no_ponto_de_risco)
DEFAULT_PROTECT = 2
```
Isso dá o desligamento protetivo que você quer, sem nuisance shutdown por um valor arbitrário.

---

## Resumo de impacto esperado

| Mudança | Alvo | Ganho p/ a óptica |
|---|---|---|
| 3 (brilho) | fonte de calor | ALTO - menos luz = menos calor no polarizador |
| 4 (shutdown calibrado) | dano catastrófico | ALTO - impede a "queima" mesmo que o resto falhe |
| 1 (fans agressivos) | remoção de calor | MEDIO - limitado pelo hardware do soprador |
| 2 (fan idle forte) | aquecimento inicial | BAIXO/MEDIO - evita subir quente nos primeiros minutos |

## Aviso

Não gravar nada antes de: (1) caminho de recuperação de brick confirmado, (2) `adb`/tier de deploy definido pela
pesquisa de viabilidade, (3) diagnóstico `gtt` feito. Ver `04-plano-de-build-e-riscos.md`. Sempre manter backup do
`ZYCustom.ini` original do próprio aparelho (`adb pull`).
