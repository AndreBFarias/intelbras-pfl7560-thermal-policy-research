# 50 - O sensor da `[ThermalPolicy]`: quem lê o quê, como os alvos se combinam e como gravar a curva do dono (2026-11-01)

**Estado em 2026-11-01: pesquisa estática (bloco 25, R1). Nada foi mudado no aparelho.** Pedido na §3 de
[`docs/sprints/2026-11-01-bloco-25-logo-auto-piso-sensor.md`](../sprints/2026-11-01-bloco-25-logo-auto-piso-sensor.md).

Tudo aqui sai do disassembly da `libhitvservice.so` (md5 `4ce869799a82493799be61ff5d922be3`, a mesma dos docs 37 e
49), Thumb, com capstone e os símbolos locais do `.gnu_debugdata`. As chamadas por PLT e os ponteiros da GOT foram
resolvidos decodificando os relocs empacotados APS2 do `.rel.dyn`. Os trechos que sustentam cada afirmação estão em
[`artifacts/re-termico/r1-bloco25-sensor-thermalpolicy.txt`](../../artifacts/re-termico/r1-bloco25-sensor-thermalpolicy.txt).

**O aparelho estava fora da rede nesta sessão** (`adb connect 192.168.1.5:5555` → `No route to host`, duas vezes).
A única leitura do aparelho usada é a coleta de 2026-11-01
([`coleta-2026-11-01/getprop.txt`](../../artifacts/re-termico/coleta-2026-11-01/getprop.txt)): `zysys.env_temp =
65.3℃`, `zysys.light_temp = 31.9℃`, `vendor.zy.power.tm.enable = true`, sem `vendor.zy.power.tm.temp`. Nada
desta pesquisa foi conferido ao vivo.

## 0. Resposta em cinco linhas

1. **São duas políticas e dois sensores:** a `POLICY_0` (`STANDARD`) lê o **Thermistor 0** (placa, `gtt0`,
   publicado como `zysys.light_temp`); a `POLICY_1` (`2ND_STANDARD`) lê o **Thermistor 1** (NTC do bloco do LED,
   `gtt1`, publicado como `zysys.env_temp`). O `env_temp` é exatamente o número que a `POLICY_1` recebe.
2. **Unidade:** m°C inteiro (média do anel de 10 amostras). **Cadência:** uma avaliação a cada ≈ 1,98 s, e o PWM
   anda em rampa até o alvo.
3. **Combinação:** ventilador 0 = **maior** de `POLICY_0(placa)` e `POLICY_1(LED)`; ventilador 1 = **só**
   `POLICY_1(LED)`; brilho = **menor** de `BL_0(placa)` e `BL_1(LED)`. O `sfs` entra em ≤ 200 ms, e a política
   puxa de volta em rampa para o alvo dela.
4. **Sim, uma curva por temperatura gravada no `.ini` vale para os dois ventiladores**, desde que esteja na
   `POLICY_1`. A "política 1" do P2 é a do sensor do LED, que é a que queremos. Com a mesma curva também na
   `POLICY_0`, a placa (≈ 31 °C) fica no piso e não muda nada.
5. **Proposta:** gravar a curva do dono (piso 700, 1000 a partir de 66 °C) igual nas duas políticas, sem linha
   `CLASS`. **Risco principal:** sozinha, a política leva ≈ 1-2 min para subir do piso a 100 %. O laço ao vivo
   continua sendo o atuador rápido; o `.ini` vira a rede de segurança (§5, §6).

## 1. Qual sensor cada política lê

### 1.1 Do sensor até a política

| Passo | Endereço | O que faz |
|---|---|---|
| Construtor do `ZYThermalManager` | `0x1de9e8`-`0x1de9fc` | monta o vetor `ThermalSense` (`this+0x13c`, elemento de `0x1c` bytes) com `sense[i] = {Thermal::find(i), i, 4}`: `sense[0]` = Thermistor 0, `sense[1]` = Thermistor 1 |
| `Thermistor::instance(id)` | `0x200d10` | indexa `m_apObject[id]`, montado na ordem das seções `[Thermistor_N]` do `.ini` |
| `RunDaulRigalMode` (modo `0x1001`, doc 34) | `0x1fd170`-`0x1fd18c` | `T0 = getAverageTemperature()` do `sense[0]` |
| idem | `0x1fd198`-`0x1fd1b0` | `T1 = getAverageTemperature()` do `sense[1]` |
| idem | `0x1fd444`-`0x1fd448` | caminho normal: `RunThermalDualProcess(T0, T1)` |
| `RunThermalDualProcess(int,int)` | `0x203048` | `r5 = T0`, `r7 = T1` (`0x203052`, `0x203054`) |
| idem | `0x20305e`-`0x20306e` | `r6 = fn[this+0x20](T0)`: **política primária × placa** (sem função: 1000, `0x203072`) |
| idem | `0x203076`-`0x203086` | `sb = fn[this+0x40](T1)`: **2ª política × LED** (sem função: 1000, `0x20308a`) |
| idem | `0x20308e`-`0x20309e` | `fp = fn[this+0xa8](T0)`: brilho primário × placa (sem função: 0) |
| idem | `0x2030a6`-`0x2030b6` | `r8 = fn[this+0xc8](T1)`: brilho 2º × LED (sem função: 0) |

### 1.2 Quem é "primária" e quem é "2ª"

- `ThermalPolicy::RunStart` (`0x1feca8`) chama `updatePolicy(enum em this+0)` (`0x1fecbc`), que preenche a função em
  `+0x20`. Depois, nos modos `0x1001`, `0x1003` e `0x1012` (teste de máscara em `0x1fecf0`-`0x1fecfc`), chama
  `update2ndPolicy("2ND_STANDARD")` (string em `0x2a94c8`, carregada em `0x1fed0c`, chamada em `0x1fed2e`), que
  preenche a função em `+0x40`. No modo `0x1012` ainda chama `update3rdPolicy("3RD_STANDARD")`.
- O enum em `this+0` é zerado no construtor (`0x1de95a`): 0 = `STANDARD`.
- `findConfig(ZY_THERMAL_POLICY_E)` (`0x220154`) traduz o enum por uma tabela em `0x36bbb0`, indexada por `e+1`:
  -1 `NONE`, 0 `STANDARD`, 1 `COOLING`, 2 `QUIET`, 3 `FAST`. Com o nome, procura em `ZYConfig::ThermalPolicy::MAPS`,
  que é indexado pelo `POLICY_n_NAME` do `.ini`.

**O casamento é pelo nome, não pelo número `n`:** a primária é a `POLICY_n` cujo `NAME` é `STANDARD` (no `.ini` do
kit, a `POLICY_0`); a 2ª é a de `NAME = 2ND_STANDARD` (a `POLICY_1`). Trocar a ordem das seções no arquivo não
muda nada; trocar o nome muda.

`BacklightPolicy::RunStart` (`0x1fef3c`) é o espelho: `updatePolicy(enum)` em `0x1fef50` e
`update2ndPolicy("2ND_STANDARD")` em `0x1fefc2`, que preenchem `+0x88+0x20 = +0xa8` e `+0x88+0x40 = +0xc8`.

### 1.3 Onde cada temperatura aparece no `getprop`

`ThermalSense::RunReport` (`0x200ca4`) e o `dispatchProcess` (`0x2011de`-`0x201208`) publicam o id 0 em
`zysys.light_temp` (string em `0x29b79a`), o id 1 em `zysys.env_temp` (`0x29b7ab`) e qualquer outro id em
`zysys.screen_temp` (`0x29b7ba`). O valor é `T / 1000.0` (constante float em `0x200cfc`), no formato `"%2.1f℃ "`.

| Sensor | Seção do `.ini` | Doc 34 | Propriedade | Política de ventilador | Política de brilho |
|---|---|---|---|---|---|
| Thermistor 0 (placa, frio) | `[Thermistor_0]` | `gtt0` | `zysys.light_temp` (31,9 °C na coleta) | primária (`STANDARD`, `POLICY_0`) | primária |
| Thermistor 1 (bloco do LED, quente) | `[Thermistor_1]` | `gtt1` | `zysys.env_temp` (65,3 °C na coleta) | 2ª (`2ND_STANDARD`, `POLICY_1`) | 2ª |

**Conferência com a prova do doc 34 §2:** com as duas `[BacklightPolicy]` iguais (limiares 40-50 °C, brilho 1000 →
850), `gtt0 = 30,07 °C` e `gtt1 = 58,95 °C`, o `gbri 0` deu 850. Pela tabela acima, isso é
`min(BL_0(30,07) = 1000, BL_1(58,95) = 850) = 850`. Bate. O doc 34 concluiu "a `[BacklightPolicy]` consome o
`gtt1`"; o refinamento é que **só a 2ª consome o `gtt1`**. A primária lê a placa. Como o brilho fica com o menor, a
escada de 66 °C funciona porque a 2ª tem a mesma escada.

## 2. Unidade e cadência

- **Unidade:** inteiro em m°C. Os limiares do `.ini` são m°C (`66000` = 66 °C), comparados direto com `T0`/`T1`
  no lambda LINE (`0x21fc08`). O `getprop` mostra a mesma grandeza dividida por 1000 (§1.3).
- **O valor é a média do anel de 10 amostras** (`SW_N = 10`). Cada amostra é
  `property_get_int32("vendor.zy.power.tm.temp", leitura real)` (`0x21d992`-`0x21d996`, string em `0x29e625`).
  **Se essa propriedade existir, ela substitui toda leitura.** Ela não existe na coleta de 2026-11-01.
- **Cadência (P2, doc 49 §4):** uma passada do `Main` ≈ 33 ms × 6 módulos ≈ 198 ms. A política só avalia com o anel
  cheio: **uma avaliação a cada ≈ 1,98 s**.
- **Depois do alvo vem a rampa** (`RunPwmChange`, `0x202094`, doc 49 §4.1): sobe `((alvo − x) >> 4) + 1` por
  avaliação (`0x202104`) e desce `((x − alvo) >> 5) + 1` (`0x20212a`). Só escreve no PWM se `|x − pwm| ≥ 10`
  (`0x202148`-`0x202158`).

## 3. Como o alvo combina com a `[BacklightPolicy]` e com o `sfs`

### 3.1 Dentro de `RunThermalDualProcess`

| Atuador | Regra | Endereço |
|---|---|---|
| `CoolingFan_0` | `max(POLICY_0(T_placa), POLICY_1(T_LED))` → `calcSpeedCurve` → limita a `[100, 1000]`, `bMax = duty ≥ 950` → `RunPwmChange` | `0x2030d2`, `0x2030da`, `0x2030e0`-`0x203104`, `0x20310c` |
| `CoolingFan_1` | `POLICY_1(T_LED)` sozinha, mesma cadeia | `0x203128`, `0x20312a`, `0x20315c` |
| Brilho | `min(BL_0(T_placa), BL_1(T_LED))` → `calcBrightnessCurve` → `RunLineChange` ou `RunStepChange` | `0x203176` |

As duas tabelas (ventilador e brilho) são **independentes**: nenhuma lê a saída da outra. O único elo é físico (mais
ventilador esfria o LED, e o LED mais frio sobe o brilho pela escada).

### 3.2 Com o `sfs`

- `sfs` e `POLICY_n_SPEED` falam a **mesma escala** (velocidade, eixo `FW_SPEED_CURVE`): os dois passam por
  `CoolingFan::calcSpeedCurve` antes de virar duty (`sfs`: `updateSpeed`, `0x2023aa`, doc 49 §4.1; política:
  `0x2030da` e `0x20312a`). O "70 %" do kit (`sfs 700`) é o mesmo número que `POLICY_n_SPEED = 700`.
- O `sfs` entra em ≤ 200 ms (pendente aplicado na passada Common, doc 49 §4.0) e grava o duty no estado da
  política. Na avaliação seguinte (≤ 2 s), o `RunPwmChange` anda desse duty em direção ao alvo da política. **Só há
  briga quando os dois alvos diferem.** Hoje o `.ini` do kit tem `POLICY_*_SPEED = 1000` em todos os degraus, então
  a política puxa todo `sfs` de volta a 1000 em ≈ 2 min (doc 49 §4.1).

### 3.3 Velocidade → duty com as tabelas atuais

Interpolação de `FW_SPEED_CURVE = 500, 575, 650, 725, 825, 925, 1000` contra `FW_PWM_DUTY` de cada ventilador
(`[CoolingFan_0]` = `200, 350, 475, 600, 725, 850, 1000`; `[CoolingFan_1]` = `325, 450, 575, 725, 875, 875, 1000`):

| Velocidade (`sfs` / `POLICY_n_SPEED`) | Duty do ventilador 0 | Duty do ventilador 1 |
|---|---|---|
| 700 | 558 | 675 |
| 750 | 631 | 762 |
| 800 | 693 | 837 |
| 850 | 756 | 875 |
| 900 | 818 | 875 |
| 950 | 900 | 916 |
| 1000 | 1000 | 1000 |

## 4. A curva gravada vale para os dois ventiladores?

**Sim, se estiver na `POLICY_1` (`2ND_STANDARD`).** O P2 leu certo o código (`0x203128 mov r1, sb`: o ventilador 1
segue só a "política 1"). O que faltava saber é que a "política 1" é a do **sensor do LED** (§1). Então:

- curva na `POLICY_1` → ventilador 1 = `curva(T_LED)`;
- ventilador 0 = `max(POLICY_0(T_placa), curva(T_LED))`. Com a **mesma curva na `POLICY_0`**, a placa (≈ 31 °C na
  coleta, abaixo do primeiro limiar) dá o piso (o lambda devolve `Y[0]` para `T ≤ X[0]`), que é ≤ `curva(T_LED)`.
  Resultado: **ventilador 0 = ventilador 1 = curva(T_LED)** em velocidade (os duties diferem pela tabela da §3.3).

Se a `POLICY_0` ficasse em 1000 fixo, o ventilador 0 ficaria em 1000 para sempre, e só o ventilador 1 seguiria a
curva.

## 5. Proposta: gravar a curva do dono na `[ThermalPolicy]`

### 5.1 Regras de escrita (do parser e do algoritmo)

- `ZYConfig::ThermalPolicy::init` (`0x1cb6cc`) lê `POLICY_NUM` (`0x1cb6ee`) e, para cada `n`, `POLICY_n_NAME`
  (`0x1cb838`), `CLASS` (`0x1cb85e`), `THRESHOLD` (`0x1cb884`), `THRESHOLD2` (`0x1cb932`) e `SPEED` (`0x1cb9e0`).
  O `CLASS` vai por `ParseInt` com padrão 0 (`0xa0370 movs r2, #0`): **sem a linha `CLASS`, vale 0 = LINE**, que é o
  que o `.ini` do kit já faz.
- `createAlgorithm` (`0x22048c`): CLASS 0 = interpolação linear (X = `THRESHOLD`, Y = `SPEED`, padrão 1000;
  `0x2204b6`-`0x22053e`), 1 = degrau constante (`0x220558`), 2 = histerese com `THRESHOLD2` (`0x2205ea`).
- O lambda LINE (`0x21fc08`): X vazio → 1000; `T ≥ X[último]` → `Y[último]`; `T ≤ X[0]` → `Y[0]`; entre dois
  pontos, `Y[i] + (T − X[i]) · (Y[i+1] − Y[i]) / (X[i+1] − X[i])`. **Não confere se `SPEED` tem o mesmo tamanho de
  `THRESHOLD`.**
- O `.ini` é lido quando o serviço sobe: o único chamador de `ThermalPolicy::init` é `ZYConfig::ZYConfig(HiCfgINI*)`
  (`0x1da1d6`). **A curva gravada só vale no próximo boot.**

### 5.2 O bloco

Mesma curva nas duas políticas, nomes intactos, sem `CLASS`:

- `THRESHOLD` em m°C, estritamente crescente, último ≤ 66000.
- `SPEED` em velocidade (% × 10), primeiro = 700 (o piso), último = 1000, mesmo número de pontos.

Exemplo com os cinco pontos que o kit aceita (`vent_valida`; os números aqui são ilustração, a curva é a que o dono
escolher):

```
POLICY_NUM = 2;
POLICY_0_NAME      = STANDARD;
POLICY_0_THRESHOLD = 50000, 55000, 60000, 63000, 66000;
POLICY_0_SPEED     =   700,   750,   800,   900,  1000;
POLICY_1_NAME      = 2ND_STANDARD;
POLICY_1_THRESHOLD = 50000, 55000, 60000, 63000, 66000;
POLICY_1_SPEED     =   700,   750,   800,   900,  1000;
```

Efeito: abaixo de 50 °C no LED, piso 700 (duty 558/675); de 66 °C para cima, alvo 1000 nos dois. Com isso o alvo da
política coincide com o do laço ao vivo do kit, e a política para de desfazer o `sfs` (doc 49 §4.1: "para segurar
um `sfs`, o alvo da política tem que ser igual ao pedido").

### 5.3 O papel de cada um

- **Laço ao vivo (`sfs`, `suite-curvas.sh`)**: o atuador rápido. Manda 1000 na hora em que o LED passa de 66 °C.
- **Curva no `.ini`**: a rede de segurança. Vale quando o laço não está rodando (kit desligado, `suite` morta,
  aparelho sem pendrive), e deixa de puxar o `sfs` de volta para 1000.

## 6. Riscos

1. **Subida lenta só pela política.** Do piso a 100 % em degrau, a rampa leva 60 avaliações (≈ 119 s, PWM final
   992, 28 escritas) no ventilador 0 e 56 (≈ 111 s, final 999) no ventilador 1. Até 95 %: ≈ 63 s e ≈ 55 s. A
   descida de 1000 ao piso leva ≈ 202 s e ≈ 182 s. (Simulação da fórmula de `0x202104`/`0x20212a` com o limiar de
   escrita de `0x202148`, a 1,98 s por avaliação.) Na prática a curva sobe aos poucos e o PWM acompanha parte do
   caminho, então o degrau é o pior caso. Se o laço ao vivo estiver parado, **100 % em 66 °C vira ≈ 100 % em 66 °C +
   1-2 min**. Mitigação possível: antecipar o ponto de 1000 (por exemplo, 64 °C). **Decisão do dono.**
2. **O duty final pode ficar em 99,2-99,9 %**, não 100 %, pelo limiar de escrita `|x − pwm| ≥ 10`.
3. **Anel defasado ou LSADC Error congela a política no último duty** (doc 37): a avaliação normal não roda e
   ventiladores e brilho ficam onde estavam. Hoje, com 1000 fixo, o congelamento é sempre em 1000 e não aparece.
   **Com a curva, pode congelar no piso.** Nesse estado o `env_temp` também para de ser atualizado (é publicado
   depois do teste de erro), então o laço do kit lê um valor velho.
4. **`THRESHOLD` e `SPEED` de tamanhos diferentes:** o lambda lê `Y[i]` sem conferir o tamanho; um `SPEED` mais curto
   leva a leitura fora do vetor. Limiar repetido zera o divisor `X[i+1] − X[i]`. O gerador tem que garantir os dois.
5. **Troca de política pela interface:** se algo chamar `setThermalPolicy`/`cus_SetThermalPolicy` com
   `COOLING`/`QUIET`/`FAST`/`NONE` (`RunCheckAndUpdate`, `0x1fc8dc` → `updatePolicy`), o nome não existe no `.ini`
   (`"No Define Value of %s"`) e vale o `FALLBACK` (`0x9f4e8`-`0x9f51a`: vetores vazios), que dá 1000 ao ventilador 0
   (`0x21fc4a`). É seguro. INFERIDO: a 2ª política continua sendo a `2ND_STANDARD`, porque esse caminho chama
   `updatePolicy`, que preenche a primária. A troca também zera os anéis de todos os
   termistores (`updatePolicy`, `0x1ff36a`-`0x1ff38e`).
6. **Pequena briga com o arredondamento do laço:** o kit arredonda o alvo **para cima**, em múltiplos de 50
   (`arredonda_50`); o lambda LINE trunca a interpolação exata. Entre dois pontos, o alvo da política pode ficar
   até < 50 abaixo do `sfs`, e a política puxa o duty para baixo devagar (`>> 5`). INFERIDO: fica limitado a essa
   diferença, porque nos pontos da curva os dois coincidem.
7. **`vendor.zy.power.tm.temp`** substitui toda leitura de temperatura (§2). Se algum dia for definida, a curva
   passa a seguir esse número.
8. **O kit hoje rejeita esse `.ini`:** a validação por md5 (`NORM_OK`, `ini_aceito` em `suite-curvas.sh`) e o aviso
   da linha 578 ("a curva dos ventiladores nao e gravada no ZYCustom.ini") teriam que mudar. É trabalho de outro
   bloco, não deste documento.

## 7. O que ficou INFERIDO

- **`setPwmMode`:** que `bMax`/`bAbnormal` (`0x202196`-`0x2021c2`) alternam entre PWM e GPIO em nível alto. Não muda
  a resposta.
- **Duty inicial 1000:** `FanSpeedControl::RunStart` (`0x1fee50`) só chama `updateSpeed` quando `THERMAL_MODE == −1`;
  que o duty de partida venha de `DEFAULT_PWM_DUTY = 1000` está no doc 34 ("100 % desde o boot"), não neste
  disassembly.
- **Leitura única do `.ini`:** provado um só chamador de `ThermalPolicy::init` (`0x1da1d6`). Que nada recarregue o
  `.ini` sem reiniciar o serviço não foi varrido em toda a lib.
- **Briga limitada com o arredondamento** (risco 6).
- **Se alguma tela do sistema chama `setThermalPolicy`:** o caminho existe por binder; quem chama, não foi visto.
- **Nada foi conferido ao vivo:** o aparelho estava fora da rede. Previsão verificável quando voltar, só leitura:
  `getprop zysys.env_temp` deve bater com o `gtt1` e `zysys.light_temp` com o `gtt0` (doc 34), e um `logcat -d`
  curto não deve mostrar `No Define Value of STANDARD` nem `of 2ND_STANDARD`.

## 8. Achado fora do escopo (uma linha)

- `le_temp` (`suite-curvas.sh`) lê `zysys.env_temp` sem detectar valor velho: com os anéis defasados (doc 37) a
  propriedade congela e o laço segue decidindo com ela.
