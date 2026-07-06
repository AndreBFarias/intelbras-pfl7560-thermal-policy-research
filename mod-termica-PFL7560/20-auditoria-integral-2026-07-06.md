# 20 - Auditoria integral e registro de achados (2026-07-06)

Registro da sessão de auditoria completa do projeto: leitura integral de todos os arquivos + auditoria
adversarial multi-lente (12 agentes) + verificação byte-a-byte + confirmação ao vivo no aparelho. O débito
consolidado e priorizado está em [`../VALIDATOR_BRIEF.md`](../VALIDATOR_BRIEF.md) (raiz do repo); as sprints
de conserto são as [21](21-sprint-integridade-backup.md)–[25](25-sprint-acentuacao.md).

## Método

- **Fan-out de leitura (8 agentes):** um por subsistema (fundação técnica, plano/proposta, build/resultados,
  segurança/recuperação/bin, auditoria/sprints, scripts, configs byte-exatas, bin-build/diagnóstico).
- **Auditoria adversarial (4 agentes):** lentes byte-exatidão, segurança-de-scripts, coerência-entre-docs,
  brick/quarentena/acentuação — cada uma verificando contra os arquivos reais, não contra os docs.
- **Verificação independente (o cérebro):** md5/diffs rodados à mão + conexão ao vivo no projetor.

## Confirmação de campo (projetor ligado, 2026-07-06)

Conectado via adb (IP `94.140.14.52`, MAC `38:54:39:a3:6f:34`), leitura pura. **O aparelho está saudável e
a correção segue ativa:**

```
gtt0 = 22,6 C (sensor cego)   |  gtt1 = 52,7 C (sensor REAL vivo)  |  gtt2 = -40001 (canal nao usado)
NTC count = 2   |  fan speed = 1000 / 1000   |  backlight = 996 (~100%)
HW_VIRTUAL_CHANNEL: Thermistor_0 = 0, Thermistor_1 = 1   (mux destravado)
wifi_disconnect_on_boot = 0   |  xiriservice = (nao roda -> disabled)   |  overheat warnings = 0
Wi-Fi = conectado (SSID "Beholder")   |  boot_completed = 1
ZYCustom.ini no device = md5 1ad641ed (a build, byte-exata)
```

`gtt1` a ~52 °C (subindo com o uso, rastreado pelo sensor real) e bem abaixo do WARNING de 70 °C: a proteção
térmica agora enxerga o calor de verdade, que era todo o objetivo do projeto.

## Achados e resoluções de campo (o que a auditoria mudou)

### H1 (ALTA) — backup do `build.prop` quebrado: RESOLVIDO NA CAUSA

`pfl7560-fix.sh:35` declara `BP_STOCK_MD5=fd8406c494c201e468a0401fa082027c`, mas o artefato versionado
`artefatos/build.prop.STOCK` tem md5 `a4b8b38a5d29f793fba17eb15e3241ff`. Como o fallback anti-envenenamento
só aceita o artefato se o md5 casar (`fix.sh:84`), o backup do `build.prop` **sempre aborta** quando o device
já está modificado — que é o estado atual — quebrando `apply`/`revert` em clone fresco.

**Verdade de campo:** puxei o `build.prop` do device (fix aplicado, `wifi=0`, md5 `cf6ee6c6`), reverti a
linha para `wifi=1` e o md5 do stock reconstruído deu **`fd8406c4`** — exatamente a constante. Logo **a
constante está certa; o artefato é que está corrompido.** O diff mostra a causa: a linha 62 do stock real é
`\xc2\xa0` (NBSP) + espaço (`cat -A`: `M-BM- $`); no artefato virou linha vazia (`$`). Um editor com
"trim trailing whitespace" comeu o NBSP+espaço, mudando o md5 de `fd8406c4` para `a4b8b38a`. O `build.prop`
é firmware-genérico (sem serial/MAC/IMEI; só flags tipo `bluetooth_name_MAC=true`), então a versão
byte-exata pode ser versionada. **Conserto: regenerar o artefato para md5 `fd8406c4`** (sprint 21).

### H2 (ALTA) — docs públicos vendem o `.bin` de quarentena como seguro

`relatorio.html` (linhas ~203-206) exibe "Reversível · sem risco de brick" e oferece o `.bin` por pendrive; o
`10-guia-replicacao.md` (Método B, público leigo) anuncia o `.bin` **sem aviso de quarentena** e cabeçalho
"sem risco de brick". O README e o doc 14 têm o aviso; esses dois — os mais expostos a terceiros — não.
**Conserto: sprint 22.**

### Novo achado de campo — drift do `init.bigfish.rc.MOD`

O `init.bigfish.rc` do device (md5 `57fa2139`) difere do artefato `.MOD` (md5 `3663c280`) por **um único byte:
um `\n` final a mais no artefato** (o device não tem newline no fim). O stock reconstruído do device (removendo
a linha `disabled`) bate `0fe1b8fb` perfeitamente com o artefato stock. É cosmético e o `.MOD` não é usado em
runtime (o `fix.sh` gera o resultado on-device a partir do stock + `sed`), mas é uma imprecisão byte-exata —
regenerar junto com a sprint 21.

### Débito médio/baixo (detalhe em VALIDATOR_BRIEF.md)

- **M1** revert depende de `backups-projetor/` que não existe nesta máquina (resolvido em parte pelo H1: com o
  artefato válido, o `apply` recria os backups). **M2** perfis A–D reintroduzem `HW_VIRTUAL_CHANNEL=0` + typo
  (sprint 24). **M3** deploy `/atv/ini` obsoleto ainda ensinado (sprint 22). **M4/M5** atomicidade dos scripts
  (sprint 23). **M6** status do doc 13 e narrativa de brilho do README (sprint 22). **M7** causa do brick não
  isolada empiricamente — alimenta a sprint 18. **M8** acentuação pt-BR docs 07/13 (sprint 25). **B1**
  `INI_FIX_MD5` morto no `fix.sh` (sprint 21). **B2** contagem de docs "01-16"/"01-18" (sprint 22).

## O que continua sólido (não mexer)

Núcleo byte-exato intacto: as 3 cópias do config batem `1ad641ed`; o diff da build é exatamente 10 linhas; o
`init.bigfish.rc.MOD` difere do stock por 1 linha funcional (`disabled`); o `.bin` de quarentena está isolado
(fora do Git, nome-aviso); a recuperação de brick é consistente e testada; o `fix.sh` faz backup fatal +
escrita atômica + validação pré-reboot. A correção no aparelho está viva e medida.
