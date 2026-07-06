# 22 - Sprint: sincronização da documentação pública (H2 + M3 + M6 + B2)

Status: **PRONTA PARA EXECUÇÃO**. Prioridade **ALTA** (H2 é risco de segurança para terceiros). Origem:
auditoria [doc 20](20-auditoria-integral-2026-07-06.md). Fecha o achado crítico #1 da
[doc 17](17-auditoria-e-hardening.md) ("sincronizar toda a documentação antes de qualquer publicação").

## Objetivo

Fazer toda a camada de documentação voltada a terceiros/leigos refletir o estado real: `.bin` em quarentena
(NÃO seguro), método definitivo é `/vendor` (não `/atv/ini`), e status/números consistentes.

## Tasks

### T1 (H2) — `relatorio.html`: remover o `.bin` como caminho seguro
- Trocar "Reversível · sem risco de brick" e a oferta do `.bin` por pendrive por um aviso de quarentena
  (o `.bin` foi testado e TRAVA O BOOT — ver docs 16/18). Remover a menção ao override `/atv`.

### T2 (H2) — `10-guia-replicacao.md`: avisar a quarentena no Método B
- Reescrever a seção "Método B — via .bin por pendrive": o `.bin` existe, foi testado e BRICA; usar apenas
  os métodos `/vendor` (adb/pendrive). Ajustar o cabeçalho "sem risco de brick" para valer só do Método A.
- Atualizar a linha do índice `mod-termica-PFL7560/README.md` que diz "aplicarem (adb + .bin)".

### T3 (M3) — marcar o deploy `/atv/ini` como SUPERADO
- Em `09-build-final-e-resultados.md` (seção Deploy) e `10-guia-replicacao.md` (Método A), adicionar nota
  "SUPERADO — o método definitivo é edição direta do /vendor via pfl7560-fix.sh; ver doc 14".
- Corrigir a linha de status do índice `mod-termica-PFL7560/README.md:14` de "override em /atv/ini" para
  "edição direta do /vendor via pfl7560-fix.sh (reversível); ver 14".
- Registrar no doc 14 se o override antigo `/atv/ini/ZYCustom_390.ini` foi removido do aparelho (o `/atv` tem
  precedência sobre o `/vendor` — dois mecanismos ativos seria armadilha).

### T4 (M6) — status e narrativa
- `13-auditoria-outros-bugs.md`: mudar o status do fix Wi-Fi de "POSSIVEL" e do xiri de "opcional" para
  "FEITO (fix2/fix3, ver doc 14)", preservando o texto de diagnóstico.
- `README.md` (raiz), linha do brilho: a de fábrica rodava a **100%** (sensor cego lê ~26 °C, abaixo do 1º
  degrau de dimming) — não "represado". Corrigir e explicar no doc 09 por que a build travou o brilho em 1000
  (compensado por fans máx + shutdown 75 °C), em vez da recomendação original do doc 03 de reduzir brilho.

### T5 (B2) — contagens de docs
- `12-seguranca-e-recuperacao.md`: "(01-16)" → "(01-20)" ou `*.md`.
- `README.md` (raiz): "01..18-*.md" → "01..20-*.md".
- Adicionar no `18-sprint-bin-futuro.md` a dependência declarada da sprint 19 (o `.bin` deve embarcar o vigia).

## Proof-of-work esperado (runtime-real)

```bash
grep -rniE 'sem risco de brick|\.bin por pendrive|/atv/ini' mod-termica-PFL7560/relatorio.html mod-termica-PFL7560/10-guia-replicacao.md
# so devem sobrar ocorrencias JUNTO de aviso de quarentena/SUPERADO (revisao manual do diff)
grep -rn 'POSSIVEL\|opcional' mod-termica-PFL7560/13-auditoria-outros-bugs.md   # status atualizado
```

## Riscos e recuperação

- Só edita documentação. Nenhum risco operacional. Validar por leitura do diff (achado é de coerência, não de
  runtime).
