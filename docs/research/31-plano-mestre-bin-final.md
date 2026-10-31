# 31 - Plano mestre: do estado atual ao `.bin` final

Documento de orientação (não-executado). Junta todas as sprints pendentes num **único caminho crítico**
até o objetivo final do projeto: um firmware `.bin` distribuível, que **boota**, traz a correção térmica
por padrão e avisa o usuário se a proteção não estiver ativa. Escrito para ser seguido por qualquer
executor, humano ou LLM — cada etapa aponta a spec detalhada e diz o que a bloqueia.

Data desta revisão: 2026-07-12.

> **ESTADO EM 2026-10-30** (prevalece sobre o texto de julho abaixo):
> - **BIN-S3b FECHADO (2026-07-29):** build reprodutível, md5 `eae3a83d…`
>   ([`firmware/README.md`](../../firmware/README.md), [`artifacts/bin-build/README.md`](../../artifacts/bin-build/README.md)).
> - **BIN-S4a PENDENTE:** nenhum boot real do `.bin`; ele segue "offline aprovado, hardware não graduado"
>   (parte C do [bloco 4](../sprints/2026-10-29-bloco-4-prova-da-build.md)). BIN-S2b e BIN-S4b pendentes;
>   BIN-S5 é contingência.
> - **O builder serve aos dois modelos** ([bloco 6](../sprints/2026-10-30-bloco-6-licoes-do-firmware-novo.md),
>   T6.2): lê o offset do vendor da tabela do container e recusa `.ini` de outro modelo. Stock V1.0.0.9 →
>   `eae3a83d…`; stock V1.0.0.1 sem USB-C → `0d294cb3…`, **só em software**.
> - **Bloco 21 (2026-10-31):** as builds acima saíram de uso (re-pack com chunks FILL e zeros soltos no slot). O
>   BIN-S4a grava `PFL7560-S4a` (`a6e5da14…`, os 3 fixes nos mesmos blocos do stock) e o BIN-S4b a
>   `PFL7560-S4b-COMPLETO` (`e6b41856…`, realocada, com `.rc`, app, home e sobreposições); [doc 47](47-build-completa.md) §10.
> - **Etapa 3 (vigia de tela) tem o gate de viabilidade reaberto:** o `am start ... VIEW` deu tela preta
>   neste aparelho (**OPT-S13**, [doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3).
> - **A `panelparam` provavelmente vai junto no `.bin`** (ver a correção na §1).

---

## 1. O que é o "`.bin` final perfeito" (definição de pronto)

Um `firmware/PFL7560-FIX.bin` que, flashado por "Atualização local do sistema" num PFL7560 qualquer:

1. **Boota até o launcher** (não trava na logo — o defeito que pôs o protótipo antigo em quarentena);
2. traz os **fixes térmicos ativos por padrão**: 2º sensor destravado (`HW_VIRTUAL_CHANNEL = 1`), fans
   1000/1000, brilho 1000, `WARNING 70 °C` / `EMERGENCY 75 °C`, Wi-Fi reconecta, `xiriservice` silenciado;
3. **embarca o vigia de tela** (sprint 19): se um dia a correção sumir, o aparelho avisa no boot;
4. foi **construído de forma reprodutível** (2 builds → mesmo md5) e **testado em hardware** com o
   pendrive de resgate ao lado.

**O que o `.bin` final NÃO faz:** não corrige cor de painel trocado. O byte `0x5c=JEIDA` **não** entra no
`.bin` universal (quebraria a cor de todo aparelho com painel de fábrica) — a correção de cor é sempre
pós-boot, pelo kit de pendrive ou por `pfl7560-lcd-color.sh`. Ver a decisão de escopo em
[`29-roadmap-troca-lcd.md`](29-roadmap-troca-lcd.md) (LCD-S4).

> **CORREÇÃO (2026-10-29/30):** a `panelparam` **provavelmente está** no container (record 4,
> [doc 41](41-auto-pareamento-camera-e-kit-universal.md) §3 e [doc 42](42-firmware-2026-10-modelo-sem-usbc.md)
> §5), ao contrário do que o doc 29 registrou em 2026-07-12. O `.bin` (de fábrica ou o nosso) leva então
> o perfil 69 com `0x5c` = 0 (VESA): quem tem painel JEIDA precisa refazer o teste de cor depois de
> gravar. A confirmação no aparelho é a etapa E1(b) do [bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md).

---

## 2. Duas trilhas (só uma está no caminho crítico do `.bin`)

```
TRILHA A — TÉRMICA (caminho crítico do .bin final)
  aparelho já corrigido via /vendor  ─  builder pronto  ─  vigia  ─  .bin que boota + avisa

TRILHA B — COR LCD (paralela, NÃO bloqueia o .bin térmico)
  formato LVDS do painel instalado, persistente no aparelho  ─  ferramenta pós-boot (feita)
```

A Trilha B é valiosa e já **funciona no aparelho do dono** (cor corrigida, persistente no reboot), mas é
uma ferramenta pós-boot separada. Não gasta o caminho crítico do `.bin`. Detalhe: doc 29. Desde a 2ª troca
de LCD (2026-10-29) o aparelho do dono está em **VESA**, não em JEIDA
([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §1).

---

## 3. Caminho crítico da Trilha A (ordem por dependência)

Legenda: **[SW]** = só software/docs, sem aparelho, reversível. **[HW]** = requer o aparelho físico e o
kit de resgate; são os pontos em que o dono precisa entrar (testes ao vivo).

| # | Etapa | Tipo | Depende de | Spec |
|---|---|---|---|---|
| 0 | Reconciliar `VALIDATOR_BRIEF.md` + fechar higiene do repo (REPO-S1) | **[SW]** | — | doc 30 + BRIEF |
| 1 | Gerar a build oficial e provar reprodutibilidade (BIN-S3b) — **FEITO em 2026-07-29** | **[SW]** | 0 | doc 18 · BIN-S3b |
| 2 | **GATE:** boot real do `.bin` de delta mínimo (BIN-S4a) — *fecha o achado M7* | **[HW]** | 1 + kit resgate | doc 18 · BIN-S4a |
| 3 | Vigia de tela: desenvolver e validar por adb (sprint 19, todas as WARN-S*) — **gate de viabilidade reaberto (OPT-S13)** | **[HW leve]** | pode ir em paralelo ao 2 | doc 19 + [doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3 |
| 4 | Metadados canônicos dos arquivos novos do vigia no builder (BIN-S2b) | **[SW]** | 3 (lista de arquivos) | doc 18 · BIN-S2b |
| 5 | **GATE de distribuição:** `.bin` com o vigia embarcado (BIN-S4b) | **[HW]** | 2 + 4 | doc 18 · BIN-S4b |
| 6 | Graduar o `.bin` da quarentena na documentação (README, doc 15, BRIEF) | **[SW]** | 5 | — |

**Por que essa ordem (e por que NÃO há ciclo 18↔19):**
- A etapa 2 (BIN-S4a) usa o **delta mínimo** (só os 3 arquivos térmicos) de propósito: se travar, não há
  variável confusa, e o diagnóstico (BIN-S5) é limpo. Ela **não** espera o vigia.
- A etapa 3 (vigia) se desenvolve inteiramente **por adb, reversível**, sem nenhum flash. Ela **decide
  sozinha** onde o vigia mora (arquivo novo em `/vendor/etc/init/`, nunca no `init.bigfish.rc`).
- A etapa 5 (BIN-S4b) é a que **junta** as duas: o `.bin` de distribuição, com o vigia embarcado. Só ela
  precisa das duas coisas prontas. Assim a sprint 19 é pré-requisito **da distribuição**, não do teste de
  boot — o ciclo que a spec antiga sugeria está desfeito.

---

## 4. Os pontos [HW] — onde o dono precisa entrar (testes ao vivo)

Estes são os únicos passos que exigem o aparelho ligado e o risco de brick controlado pelo kit de
resgate. **Nada disso deve ser feito às cegas nem sem avisar o dono.**

- **Etapa 2 — BIN-S4a (o gate decisivo).** Flashar o `.bin` de delta mínimo e ver se boota. É o momento
  que transforma "acho que corrigi os metadados" em "o `.bin` boota, provado". Pré-condição: kit de
  resgate montado (pendrive de fábrica como `usb_update.bin`, separado; PC com adb por Wi-Fi). Passo
  manual que gente esquece: **o flash formata o `/data`** → reconfigurar o Wi-Fi no launcher antes de
  rodar o `status`.
- **Etapa 3 — validação do vigia.** `revert` + reboot → aviso aparece; `apply` + reboot → aviso some.
  Reversível por adb, mas mexe em `/vendor` — fazer com o resgate à mão.
- **Etapa 5 — BIN-S4b.** Segundo flash, agora com o vigia. Mesma disciplina da etapa 2.
- **Contingência — BIN-S5 (só se a etapa 2 falhar).** Precisa de kit UART USB-TTL (115200 8N1) para ler
  o console serial no hang. Ver doc 18 · BIN-S5 e [`../guide/16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md).

Checklist completo de pré-condições e recuperação: doc 18, seção "Pré-requisito absoluto — kit de resgate".

---

## 5. O que já está pronto (para não refazer)

- **A correção térmica em si** — aplicada, validada e persistente no aparelho do dono via `/vendor`
  (docs 14, 26). O `.bin` só empacota isso para quem não usa adb/pendrive.
- **O builder do `.bin`** (`artifacts/bin-build/build_fix_bin.py`) — já faz BIN-S1/S2/S3: lê e carimba
  mode/uid/gid + rótulo SELinux dos 3 arquivos, com gate fatal contra `.rc` group-writable, e valida o
  `checksum1`. Falta só **rodá-lo capturando a prova** (BIN-S3b) e o teste de hardware. (BIN-S3b feito em
  2026-07-29; desde o bloco 6 o builder lê o offset do vendor da tabela e serve aos dois modelos. Falta o
  teste de hardware.)
- **A correção de cor LCD** — resolvida (byte `0x5c`: JEIDA na 1ª troca, VESA na 2ª, doc 40 §1), aplicada
  e persistente; ferramenta `pfl7560-lcd-color.sh` com os 9 subcomandos (doc 28), backup/restore
  endurecidos e integrada ao menu e ao `install.bat` (LCD-S1, `a9d3fa2`), backup obrigatório antes de
  gravar (bloco 1), e o kit de pendrive com o teste da escada de 16 cinzas pela câmera (blocos 5, 7 e 8) e a suíte de verificação de
  boot ([doc 44](44-suite-de-boot.md)) — trilha B, fora do
  caminho crítico.
- **A higiene do repo** — 4 dos 5 checks da REPO-S1 já passam; `make check` 6/6 (doc 30); desde
  2026-10-30, 9 OK (os 3 artefatos do modelo sem USB-C, bloco 6).

---

## 6. Riscos que valem repetir

- **Nunca** flashar nada que não tenha passado o gate de boot em hardware; **nunca** renomear o `.bin` de
  correção para `usb_update.bin` (o resgate é SEMPRE o firmware de fábrica).
- O `.bin` de resgate e o de correção ficam em **pendrives separados**; um power-hold acidental com o
  pendrive errado apaga a correção.
- O vigia (sprint 19) mora em **arquivo `.rc` separado** — editar o `init.bigfish.rc` para isso é
  proibido (ele é boot-crítico e é restaurado pelo `revert`).
- Antes de tornar o repo público: resolver o zip proprietário em LFS e a revisão visual das fotos
  (doc 30 · REPO-S2). LFS não é privacidade.

---

## 7. Resumo em uma frase

O `.bin` final está a **dois testes de hardware** de distância (BIN-S4a e BIN-S4b), com todo o software
já escrito; o caminho é: provar a build offline (BIN-S3b, feito em 2026-07-29) → flashar o delta mínimo e confirmar o boot
(BIN-S4a, que de quebra fecha o achado M7) → fechar o vigia por adb (sprint 19) → embarcá-lo e reflashar
(BIN-S4b) → graduar da quarentena.
