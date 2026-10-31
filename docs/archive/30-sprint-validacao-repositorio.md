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

> **Status (verificado 2026-07-12): 4 de 5 checks já PASSAM.** Rodados em modo read-only: os checks 2
> (links), 3 (scripts), 4 (`make check` — 6/6 OK) e 5 (órfãos) passam. Só o check 1 fica PARCIAL por um
> motivo de auto-referência — corrigido abaixo. Esta sprint é curta e não precisa de aparelho.

**Escopo / proof-of-work (tudo verificável por comando):**
1. **Zero referências ao caminho antigo em arquivos versionados** — **exceto este próprio doc**, que cita
   `mod-termica-PFL7560` ao descrever a reorganização (auto-referência histórica legítima). O check
   original (`grep = 0`) era impossível de cumprir sem apagar a própria descrição da sprint. Comando
   correto, que isenta este arquivo:
   ```bash
   git grep -n 'mod-termica-PFL7560' -- ':!docs/research/30-sprint-validacao-repositorio.md'
   # esperado: nenhuma saída (0 hits fora deste doc)
   ```
   Estado atual: **PASSA** (os únicos 4 hits estão neste doc; zero em scripts, `artifacts/`, `private/`).
2. **Links markdown internos resolvem:** para cada link relativo (a forma `[rótulo]` seguida de
   `(destino)`) nos `.md` rastreados, o alvo existe. O checker **deve ignorar exemplos de sintaxe em
   prosa/code-span** — se um exemplo ilustrativo for escrito com a forma completa de link, um checker
   ingênuo o trata como link real e reprova. Por isso esta spec descreve a sintaxe **sem** a colar
   literalmente. Estado atual: **PASSA** (95 links, 0 quebrados reais).
3. **Scripts apontam para caminhos novos:** `pfl7560-fix.sh`, `pfl7560-menu.sh`, `pfl7560-lcd-color.sh`,
   `install.sh`, `install.bat`, `pendrive-autorun/*` não referenciam `mod-termica-*` nem artefatos em
   local antigo. Estado atual: **PASSA** (as únicas ocorrências de "artefatos" são prosa em comentários).
4. **Integridade dos artefatos stock:** `make check` (= `tests/check-stock-md5.sh`) passa. Estado atual:
   **PASSA** — 6 OK: `ZYCustom.ini.ORIGINAL`, `build.prop.STOCK` (`fd8406c4...`), `init.bigfish.rc.STOCK`,
   `ZYCustom_390.ini`, `pendrive-autorun/ZYCustom.ini`, `CONFIG_B64` decodificado. (**Atualização
   (2026-10-30):** 9 OK; entraram os 3 artefatos do modelo sem USB-C, bloco 6, e o `init.bigfish.rc.STOCK`
   ficou byte-exato ao de fábrica, md5 `8f7e02b2…`, T6.4.)
5. **Sem órfãos:** todo doc citado no índice (`docs/README.md`) existe; todo artefato de caminho literal
   `artifacts/...` citado nos docs existe. Método do checker: extrair paths com `grep -oE 'artifacts/[^ )`]+'`
   e testar `-e` cada um. Estado atual: **PASSA**. *Achado lateral (não é FAIL):*
   `docs/disclosure/roteiro-evidencias.md` existe mas não está linkado no índice — opcionalmente
   adicioná-lo à seção "Divulgação responsável" do `docs/README.md`.

**Risco:** links quebrados silenciosos (markdown não falha em build). **Esforço:** baixo.
**Entrega:** as 3 ações pontuais acima (exemplo em crases na linha 29; opcional link do roteiro no índice;
o `git grep` isentando este doc como comando canônico do check 1).

## REPO-S2 — Revisar o que deve ou não ser versionado

**Objetivo:** confirmar a política de arquivos do repo após a reorganização **e resolver os dois
conflitos que bloqueiam a publicação** (não só "confirmar o estado atual").

> **Status (verificado 2026-07-12):** o básico está OK — `private/`, `evidencias/`,
> `artifacts/diagnostico/`, `.playwright-mcp/`, `__pycache__/` estão ignorados; nenhum `*.bin` rastreado;
> o zip do firmware está em Git LFS (pointer de 134 bytes no git); a auditoria de texto rastreado **não**
> achou IP real, MAC real, serial do aparelho, e-mail pessoal ou SSID (só placeholders). **Restam dois
> pontos ALTOS que a versão anterior desta spec não enxergava** (ela só "confirmava o estado", mas o
> estado atual é perigoso para um repo que vai ser público).

**Escopo:**
- **[ALTA — bloqueia "tornar público"] Zip proprietário da Intelbras vs repo público.** O
  `firmware/Software PFL7560.zip` (826 MB, firmware oficial) está rastreado via Git LFS, com aviso
  "NÃO redistribua em repositório público" no `firmware/README.md` — **conflito direto** com o plano do
  `README.md` de tornar o repo público após a janela de disclosure. **LFS não é privacidade:** o pointer
  está no histórico e o objeto vai junto num remote público. Antes de publicar, **decidir e executar
  uma** das opções:
  1. **Remover o zip do LFS E do histórico** (`git filter-repo` / `git lfs migrate` para expurgar), ou
  2. **Manter o backup só num remote privado** e publicar um repo separado sem o zip.
  Deixar como está = redistribuir firmware proprietário publicamente. Registrar a decisão.
- **[ALTA] E-mail pessoal no histórico de commits.** Os commits estão assinados como
  `[REDACTED]` — ficará público ao publicar. Decidir: aceitar, ou reescrever o histórico / usar
  e-mail `noreply` do GitHub daqui em diante.
- **[média] Decisão sobre o binário `lvdsctl` (já versionado, não só "avaliar").** O ELF ARM
  `artifacts/lcd-color-fix/lvdsctl` (6,3 KB, não-stripped) está no Git ao lado do `.c`. Virar decisão com
  critério: **manter** exige md5 fixado + versão do NDK e flags de build documentadas no README de
  `artifacts/lcd-color-fix/` (para o binário ser reproduzível/auditável); **senão, remover** (`git rm
  --cached`) e versionar só o `.c` + instrução de build, adicionando regra no `.gitignore`.
- **[ALTA — bloqueia "tornar público"] Auditoria visual das fotos — FEITA (2026-07-12).** Revisão das 8
  imagens de `media/`: **2 publicáveis, 6 exigem redação/crop, nenhuma para expurgo total.** Checklist
  por foto em [`../../media/README.md`](../../media/README.md) (seção "Auditoria de privacidade
  pré-publicação"). **Achado crítico:** `teardown-01-base-cabo-solto.jpg` expõe o **número de série + o
  código de barras** do aparelho totalmente legíveis — redigir antes de publicar (guardar a cópia não
  redigida fora do Git, só para o destino jurídico/CDC). Riscos secundários: data-matrix (possível
  MAC/serial) em 3 fotos de placa; partes do corpo de pessoa/ambiente em 3 fotos. As fotos ainda **não**
  foram redigidas — é ação manual (edição de imagem) do dono antes do push público. Os arquivos do
  checklist de evidências (`termometro-*`, `hidebug-gtt-*.png`, etc.) ainda não existem; quando forem
  capturados, os prints `hidebug-gtt-*.png` precisam de nova auditoria (SSID/IP na janela do PC).
- Confirmar `referencia/` no `.gitignore` (hoje só os PDFs caem em `*.pdf`; qualquer não-PDF colocado lá
  seria rastreado por acidente) — adicionar `referencia/` explícito.
- Confirmar que `artifacts/diagnostico/`, `evidencias/`, `private/`, `.playwright-mcp/`, `__pycache__/`
  seguem ignorados (já OK).
**Risco:** vazar dado pessoal (foto com etiqueta) ou redistribuir firmware proprietário — **auditar e
resolver** antes de tornar público. **Esforço:** baixo (decisões) + médio (se optar por reescrever
histórico do zip).

## Ordem

Rodar **REPO-S1** logo após o super commit (valida o que acabou de entrar); **REPO-S2** antes de
qualquer tornada-pública. Ambas independem do roadmap de LCD.
