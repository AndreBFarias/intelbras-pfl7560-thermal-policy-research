# Perfis experimentais (HISTÓRICO — NÃO APLICAR)

Estes 4 `ZYCustom_390.{A,B,C,D}.ini` são artefatos de pesquisa de uma estratégia **anterior e diferente** da
build final: reduzir o **brilho** para cortar calor na fonte, com o sensor térmico ainda **cego** (mux não
destravado). Ficam aqui só como registro. **Não aplique nenhum deles no aparelho.**

## O que cada um era (registro)

| Perfil | Brilho (`POLICY_BRIGHTNESS`) | Fans (`POLICY_SPEED`) | Ideia |
|---|---|---|---|
| A | `1000..750` (curva stock) | `1000` flat | fans no talo, brilho na curva de fábrica |
| B | `750` flat | `1000` flat | brilho fixo baixo (750) |
| C | `850..750` | `800..1000` (rampa) | brilho médio + fans em rampa |
| D | `600` flat | `1000` flat | brilho bem baixo (600), máximo corte de calor |

Todos mantêm `WARNING_VALUE = 43000` / `EMERGENCY_VALUE = 45000` (stock) e `HW_VIRTUAL_CHANNEL = 0` nos dois
termistores (mux **não** destravado).

## Por que são INSEGUROS (as duas armadilhas)

1. **Como estão (mux desligado):** `HW_VIRTUAL_CHANNEL = 0` mantém o defeito de configuração de fábrica — o 2º sensor nunca é lido, a
   proteção térmica fica **cega**, e a óptica pode cozinhar sem o firmware perceber. É exatamente o defeito que o
   projeto conserta.
2. **Se alguém "consertar" só o mux (`= 1`) neles:** o sensor real passa a ler ~59 °C, mas o `EMERGENCY_VALUE`
   continua 45000 (45 °C) → `59 > 45` → **desligamento imediato** de proteção. Ligar o mux exige **também** elevar
   `WARNING/EMERGENCY` (a build final usa 70000/75000). Meia-correção brica o uso (nuisance shutdown).

## O único config seguro e atual

`../../ZYCustom_390.ini` (a **build final**, md5 `252ab7a7…`): mux destravado (`HW_VIRTUAL_CHANNEL = 1` no
`[Thermistor_1]`) **+** `WARNING/EMERGENCY = 70000/75000` **+** fans fixos em 1000 **+** brilho com escada
1000→850 entre 66 °C e 73 °C (1000 no uso normal, perda máxima de 15% e só quando quente) **+** typo do
`FW_SPEED_CURVE` corrigido. É o que está no aparelho e o que os métodos `/vendor` aplicam.
