# 24 - Sprint: perfis seguros (M2)

Status: **CONCLUÍDA (2026-07-06)** — escolhida a opção **T2 (quarentena)**. Origem: auditoria [doc 20](20-auditoria-integral-2026-07-06.md).

> **Decisão T2 (não T1):** ao tentar o T1 (ligar `HW_VIRTUAL_CHANNEL=1` nos perfis), um check adversarial
> revelou que os 4 mantêm `EMERGENCY_VALUE=45000` (stock) — com o sensor real (~59 °C) isso causaria
> **desligamento imediato** (59 > 45). Os perfis são de uma estratégia anterior (reduzir brilho com o sensor
> cego); torná-los seguros exigiria também elevar os limiares, virando outro build. Então foram **movidos para
> `artefatos/historico/perfis/`** com um README de aviso; o único config seguro é `ZYCustom_390.ini`.

## Objetivo

Garantir que nenhum perfil alternativo em `artefatos/perfis/` possa reintroduzir os defeitos de fábrica que a
build final corrigiu.

## Contexto

Os 4 perfis `ZYCustom_390.A/B/C/D.ini` retêm os DOIS defeitos de fábrica:
- ambos os termistores com `HW_VIRTUAL_CHANNEL = 0` (mux morto → proteção térmica **cega**);
- o typo `825. 925` (ponto no lugar de vírgula) no `FW_SPEED_CURVE` do `[CoolingFan_1]`.

Se alguém aplicar um perfil como "tuning alternativo de fan/brilho", reintroduz silenciosamente a cegueira que
cozinhou o polarizador — exatamente o bug central do projeto.

## Tasks

### T1 — Corrigir os defeitos herdados em cada perfil
- Nos 4 perfis: setar `HW_VIRTUAL_CHANNEL = 1` no `[Thermistor_1]` (mantendo `[Thermistor_0] = 0`) e corrigir
  `825. 925` → `825, 925`. Assim os perfis passam a diferir da build final APENAS nas curvas de fan/brilho que
  os tornam "perfis".

### T2 (alternativa a T1) — quarentena dos perfis
- Se os perfis não forem mais usados, mover para `artefatos/historico/perfis/` com um `README` avisando que
  estão **obsoletos e inseguros** (contêm o bug do mux) e apontando para `ZYCustom_390.ini` como o único
  config seguro.

Escolher T1 (se os perfis ainda servem a experimentação) OU T2 (se são só histórico) — decisão da 1ª task.

## Proof-of-work esperado (runtime-real)

```bash
grep -c 'HW_VIRTUAL_CHANNEL = 0' mod-termica-PFL7560/artefatos/perfis/*.ini   # se T1: cada arquivo -> 1 (so o Thermistor_0)
grep -l '825\. 925' mod-termica-PFL7560/artefatos/perfis/*.ini                # se T1: vazio
# se T2: os arquivos nao existem mais em perfis/ e o README de historico avisa
```

## Riscos e recuperação

- Só artefatos de repo. Nenhum risco no aparelho (perfis não são aplicados por nenhum script automaticamente).
