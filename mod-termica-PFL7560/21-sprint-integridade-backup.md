# 21 - Sprint: integridade byte-exata do backup/restore (H1 + init.rc MOD + B1)

Status: **PRONTA PARA EXECUÇÃO**. Prioridade **ALTA** (a ferramenta principal `pfl7560-fix.sh` está hoje
inoperante em clone fresco). Origem: auditoria [doc 20](20-auditoria-integral-2026-07-06.md).

## Objetivo

Restaurar a garantia de que os artefatos stock versionados são byte-exatos e que o `apply`/`revert` do
`pfl7560-fix.sh` volta a funcionar, com um teste automatizado que impede a classe inteira do bug de voltar.

## Contexto (verdade de campo — não recomeçar do zero)

- **O stock real do `build.prop` tem md5 `fd8406c494c201e468a0401fa082027c`** (a constante `BP_STOCK_MD5` no
  `fix.sh:35` está CERTA). Confirmado ao vivo: `build.prop` do device com `wifi=0` (md5 `cf6ee6c6`), revertido
  para `wifi=1`, dá `fd8406c4`.
- **O artefato `artefatos/build.prop.STOCK` está corrompido** (md5 `a4b8b38a`): perdeu o NBSP+espaço da linha
  62 (`cat -A` do stock real: `M-BM- $`; do artefato: `$`). Um "trim trailing whitespace" de editor causou.
- O arquivo byte-exato correto já foi reconstruído do device e está em
  `scratchpad/build.prop.STOCK_RECONSTRUIDO` (md5 `fd8406c4`), firmware-genérico (sem dado pessoal).
- **`init.bigfish.rc.MOD`** (md5 `3663c280`) difere do device (`57fa2139`) só por um `\n` final a mais; o stock
  reconstruído do device bate `0fe1b8fb`. Cosmético, mas regenerar para byte-exatidão.
- `INI_FIX_MD5=1ad641ed...` (`fix.sh:34`) é variável morta — o `CONFIG_B64` decodificado não é validado antes
  do push (o pendrive faz essa checagem; o `fix.sh` não).

## Tasks

### T1 — Regenerar `build.prop.STOCK` byte-exato
- Substituir `mod-termica-PFL7560/artefatos/build.prop.STOCK` por um arquivo cujo md5 seja `fd8406c4` (usar o
  `scratchpad/build.prop.STOCK_RECONSTRUIDO`). Confirmar que a linha 62 volta a ter `\xc2\xa0` + espaço.

### T2 — Regenerar `init.bigfish.rc.MOD` byte-exato (opcional, cosmético)
- Recriar o `.MOD` = stock (`0fe1b8fb`) + linha `    disabled` após `service xiriservice`, SEM `\n` final extra,
  de modo a bater com o que o `fix.sh` produz on-device.

### T3 — Teste `make check` das constantes stock
- Adicionar um script (ex.: `tests/check-stock-md5.sh` + alvo `make check`) que valida:
  - `md5(artefatos/ZYCustom.ini.ORIGINAL) == INI_STOCK_MD5` (`29d8ba36`)
  - `md5(artefatos/build.prop.STOCK) == BP_STOCK_MD5` (`fd8406c4`)
  - `md5(artefatos/init.bigfish.rc.STOCK) == RC_STOCK_MD5` (`0fe1b8fb`)
  - `md5(artefatos/ZYCustom_390.ini) == md5(pendrive-autorun/ZYCustom.ini) == INI_FIX_MD5` (`1ad641ed`)
  - `md5(base64 -d do CONFIG_B64 no fix.sh) == 1ad641ed`
- As constantes são lidas do próprio `fix.sh` (grep), não redigitadas, para o teste não envelhecer.

### T4 — Ativar `INI_FIX_MD5` no `cmd_apply`
- Após decodificar o `CONFIG_B64`, abortar se `[ "$l" != "$INI_FIX_MD5" ]` (defesa contra corrupção do heredoc
  numa edição futura do script).

## Proof-of-work esperado (runtime-real)

```bash
md5sum mod-termica-PFL7560/artefatos/build.prop.STOCK      # == fd8406c494c201e468a0401fa082027c
make check                                                 # todas as linhas: OK
# e, com o projetor ligado, o apply volta a passar do backup:
PFL_IP=94.140.14.52 ./pfl7560-fix.sh status                # segue lendo (sanidade da conexao)
```

## Riscos e recuperação

- Mudança só em artefatos de repo + `fix.sh` (NÃO toca o aparelho). Risco de brick: nenhum.
- Não alterar a constante `BP_STOCK_MD5` (ela está certa) — o erro é o artefato.
- Depois desta sprint, `apply` num clone fresco recria `backups-projetor/` a partir dos artefatos válidos,
  fechando o M1 (revert dependia desses backups).
