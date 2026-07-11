# 30 - Sprint: validação e higiene do repositório pós-reorganização

Sprint de dívida técnica, separada do roadmap de LCD (doc 29). **Motivo:** o repositório sofreu uma
**reorganização estrutural grande não validada** — a pasta antiga `mod-termica-PFL7560/` (48 arquivos)
foi movida para `docs/` + `artifacts/` + `media/`, e isso foi ao ar junto do trabalho de correção de cor
num único commit. Mover pastas sem validar links/referências/integridade é dívida clássica; esta sprint
paga.

## Estado que originou a sprint (2026-07-11)

| Categoria | Qtd | O quê |
|---|---|---|
| Deletados | 48 | `mod-termica-PFL7560/**` (estrutura antiga) |
| Untracked | ~10 | `docs/`, `artifacts/`, `media/`, `install.sh/bat`, scripts, hashes |
| Modificados | 11 | `README.md`, `INSTALL.md`, `pfl7560-fix.sh`, `pfl7560-menu.sh`, `.gitignore`, etc. |

Ou seja: os docs foram renumerados/movidos e os scripts editados, mas **nada garante que os links e os
caminhos internos acompanharam**.

---

## REPO-S1 — Validar integridade da reorganização

**Objetivo:** garantir que a movimentação `mod-termica-PFL7560/` → `docs/`+`artifacts/`+`media/` não
deixou link quebrado, caminho órfão nem referência ao diretório antigo.

**Escopo / proof-of-work (tudo verificável por comando):**
1. **Zero referências ao caminho antigo:** `grep -rn 'mod-termica-PFL7560' .` (fora de `.git`) = **0**.
2. **Links markdown internos resolvem:** para cada `[texto](caminho)` relativo nos `.md`, o alvo existe.
   (script simples que extrai os links e testa `-f`/`-d`).
3. **Scripts apontam para caminhos novos:** `pfl7560-fix.sh`, `pfl7560-menu.sh`, `install.sh`,
   `install.bat`, `pendrive-autorun/*` não referenciam `mod-termica-*` nem artefatos em local antigo.
4. **Integridade dos artefatos stock:** `make check` / `tests/check-stock-md5.sh` passa (md5 do
   `ZYCustom.ini` stock, `build.prop.STOCK`, `init.bigfish.rc.STOCK`).
5. **Sem órfãos:** todo artefato citado nos docs existe em `artifacts/`; todo doc citado no índice
   (`docs/README.md`) existe.

**Risco:** links quebrados silenciosos (markdown não falha em build). **Esforço:** baixo.
**Entrega:** relatório de validação + correções pontuais dos links/caminhos que falharem.

## REPO-S2 — Revisar o que deve ou não ser versionado

**Objetivo:** confirmar a política de arquivos do repo após a reorganização.
**Escopo:**
- Confirmar que dados do aparelho (`artifacts/diagnostico/`, `evidencias/`, `private/`) seguem
  ignorados (`.gitignore`).
- Confirmar que binários grandes (`firmware/*.bin`, `*.zip`) seguem fora do Git / em LFS.
- Confirmar que lixo de sessão (`.playwright-mcp/`, `.claude/`, `__pycache__/`) está ignorado.
- Avaliar se `artifacts/lcd-color-fix/` (binário `lvdsctl` compilado, se adicionado) deve ir como fonte
  apenas (`.c`) + instrução de build, evitando binário no Git.
**Risco:** vazar dado pessoal (serial do aparelho, IP) — auditar antes de tornar público.
**Esforço:** baixo.

## Ordem

Rodar **REPO-S1** logo após o super commit (valida o que acabou de entrar); **REPO-S2** antes de
qualquer tornada-pública. Ambas independem do roadmap de LCD.
