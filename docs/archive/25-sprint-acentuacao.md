# 25 - Sprint: acentuação pt-BR (M8)

Status: **CONCLUÍDA (2026-07-06)**. Era prioridade **BAIXA/MÉDIA** (qualidade editorial; não afeta runtime). Origem:
auditoria [doc 20](20-auditoria-integral-2026-07-06.md).

> **Concluída:** docs 07 e 13 acentuados (verificado accent-only: removendo acentos, antes==depois byte a byte);
> `pfl7560-menu.sh` e `Comment[pt_BR]` do `.desktop` acentuados (sintaxe intacta); `newlink_update.sh` e
> `LEIA-ME.txt` ganharam nota de convenção ASCII (mantidos ASCII de propósito, shell do aparelho / FAT32).

## Objetivo

Padronizar a acentuação pt-BR nos documentos e nas superfícies voltadas ao usuário, sem quebrar o que precisa
ser ASCII por restrição técnica.

## Contexto

O encoding UTF-8 está íntegro (sem mojibake); o problema é texto digitado sem acento. Piores casos:
- `07-hardware-upgrade.md` — mistura acentuado e não-acentuado no MESMO parágrafo (colagem de fontes sem
  revisão).
- `13-auditoria-outros-bugs.md` — corpo quase inteiro sem acento, inclusive títulos.

## Tasks

### T1 — Corrigir os dois piores docs
- Passar um corretor de acentuação em `07-hardware-upgrade.md` e `13-auditoria-outros-bugs.md` (são `.md` lidos
  por humanos, UTF-8, sem restrição de charset). Priorizar o 07.

### T2 — Superfícies do usuário no PC
- Acentuar `pfl7560-menu.sh` (menu interativo) e o campo `Comment[pt_BR]` de `PFL7560-Corrigir.desktop` — rodam
  no PC do usuário, UTF-8, sem desculpa para ASCII.

### T3 — Decidir e DOCUMENTAR a convenção ASCII onde ela é defensável
- `pendrive-autorun/newlink_update.sh` (shell do projetor, locale incerto) e `pendrive-autorun/LEIA-ME.txt`
  (pendrive FAT32) podem ficar ASCII de propósito — mas registrar isso num comentário no topo de cada um, para
  o próximo auditor não reabrir o ponto.

## Proof-of-work esperado (runtime-real)

```bash
# heuristica: palavras comuns que exigem acento aparecendo sem acento nos docs corrigidos
grep -nE '\b(nao|correcao|atencao|protecao|sensores?|termic[ao]|pratic[ao]|otic[ao])\b' \
  docs/07-hardware-upgrade.md docs/13-auditoria-outros-bugs.md
# deve cair para ~0 (fora de blocos de codigo/nomes de arquivo)
```

## Riscos e recuperação

- Só texto. Não tocar em blocos de código, nomes de arquivo, chaves de config nem no `CONFIG_B64`. Nenhum risco
  operacional.
