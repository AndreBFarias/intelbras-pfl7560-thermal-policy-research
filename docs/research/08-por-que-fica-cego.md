# 08 - Por que o software fica cego à temperatura (investigação definitiva)

Confiança: ALTA. Baseado em disassembly do `libhitvservice.so` (função de conversão @0x21dfa8, mux @0x2187d0),
reprodução numérica em Python, e evidência ao vivo do aparelho (ADC bruto + gtt).

## Resposta curta

**Não é a conta.** O firmware converte o ADC em temperatura CORRETAMENTE. A cegueira tem duas causas de
HARDWARE/CONFIG: (B) o **mux está morto** por erro de configuração (lê sempre o mesmo sensor) e (D) esse
**único sensor está fisicamente longe do calor** (lê o ambiente da placa, ~26 °C, mesmo com a saída >43 °C).

## A matemática está certa (descartado bug de fórmula)

Fórmula extraída do binário (fn @0x21dfa8):
```
V     = HW_V_REF * adc / 255           (ADC de 8 bits, fundo de escala 255 — NÃO 1023)
R_ntc = HW_R * V / (HW_V_IN - V)       (divisor com pull-up de 4.7 kΩ)
T_K   = FW_NTC_B / (ln(R_ntc) - FW_NTC_LNa)   (modelo Beta)
T_C   = T_K - 273.15   ->  *1000  ->  clamp [-40000, 120000] mC
```
Verificação com o dado ao vivo: **adc=168 → V=2.174 → R=9.08 kΩ → T=26.36 °C**, que bate com o `gtt` (26.4 °C)
com erro de 0.04 °C. A cadeia é totalmente responsiva: se o NTC sentisse 43 °C, o ADC cairia para **~132** e o
`gtt` mostraria ~43 °C. Ele não cai — fica ~164-168. Logo **a entrada do ADC quase não muda com o calor**.

Tabela de back-solve (o que o ADC daria se o sensor estivesse bem acoplado):
`24.5°C→172 · 26.4°C→168 · 30°C→160 · 40°C→138 · 43°C→132 · 50°C→117 · 60°C→98`.
Observado: fica em ~164-168 → swing minúsculo → **sensor não acoplado ao ar quente**.

## Causa (B): o MUX nunca troca de sensor — erro de config no .ini

- `[Thermistor_0]` e `[Thermistor_1]` estão **ambos** com `HW_LSADC_CHANNEL=1` **e `HW_VIRTUAL_CHANNEL=0`**.
- O `Multiplexer::Run` só comuta o `GPIO4_4` quando o canal-alvo difere do atual (`cmp/beq @0x2187ee`).
  Como as duas tarefas usam o canal virtual 0, o GPIO4_4 fica **preso em LOW** e o `BL1551B` **nunca seleciona
  o segundo ramo**. `FW_DRIVE_TABLE=0b0,0b1` (canal0→LOW, canal1→HIGH) — o 0b1 nunca é escrito.
- Por isso `gtt 0 == gtt 1` **sempre, byte a byte**: é o mesmo sensor físico lido duas vezes (não é a média SW_N=10).

## Causa (D): o sensor lido está desacoplado do calor

O único NTC efetivamente lido fica a ~24-28 °C mesmo com a saída de ar >43 °C. Ele mede a temperatura ambiente
da placa, não o fluxo quente / a óptica.

## Dá pra consertar via .ini?

- **Mexer em `HW_R`/`FW_NTC_B`/`FW_NTC_LNa`/escala: NÃO.** A conta já está certa; não dá pra remapear uma
  informação que o ADC nunca capturou. Forçar "164 → 43 °C" faz cada contagem valer vários graus, estoura o lado
  frio e vira ruído. Baixar `FW_NTC_LNa` só aplica um viés constante (número errado que não acompanha o ar).
- **UMA mudança que VALE testar (grátis, reversível):** em `[Thermistor_1]`, trocar
  **`HW_VIRTUAL_CHANNEL = 0` → `1`**. Isso destrava o mux: o `GPIO4_4` passa a alternar 0b0/0b1 e o `BL1551B`
  passa a rotear o **segundo ramo** para o ADC. **SE** existir um 2º NTC populado **E** ele estiver perto da
  saída de ar/óptica, então `gtt 1` passaria a **enxergar o calor de verdade** — e aí a rampa de fan e o
  shutdown finalmente funcionariam (apontando-os para `gtt 1`).
  - É uma **aposta sobre hardware não confirmado**: o 2º NTC pode não existir ou estar também na parte fria.

## Teste que decide (fazer no deploy da build)

1. Aplicar `HW_VIRTUAL_CHANNEL=1` em `[Thermistor_1]` no override, reiniciar.
2. Ler `gtt 0` vs `gtt 1`. **Sucesso** = `gtt 1` deixa de ser idêntico a `gtt 0` **e sobe** quando sopra ar quente.
3. Se `gtt 1` subir com o calor → apontar fan-ramp/shutdown para o canal quente (firmware volta a "ver").
   Se continuar preso em ~26 °C → 2º NTC não existe/também frio → só resolve no **hardware** (reposicionar/colar
   um NTC na exaustão).

## Implicação para a build

Vale **incluir `HW_VIRTUAL_CHANNEL=1` (Thermistor_1) no override** e checar `gtt 1` no reboot — custo zero,
reversível, e pode ser o conserto real da cegueira. Independente disso, "fans 100% sempre + brilho controlado"
não depende do sensor (roda mais frio incondicionalmente).
