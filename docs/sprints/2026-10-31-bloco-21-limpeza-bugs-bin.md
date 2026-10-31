# Bloco 21 - Limpeza, bugs, repositório fácil de ler e o .bin definitivo (2026-10-31)

Pedido do dono, antes de sair:
- limpeza: organização, informação unificada, repositório mais amigável, README atualizado;
- procura de bugs, melhorias e afins;
- repositório fácil para quem chega (iniciante ou ferramenta): achar dados e arquivos rápido, código sem
  comentários, pouco texto repetido;
- correção: bugs, melhorias, QA, UI e UX, lacunas em aberto, problemas legados e o `.bin` que funcione de vez;
- 8 agentes; no fim, merge e push na `main` e o pendrive com o sistema novo.

Decisões do dono (2026-10-31):
- pendrive: **o nosso `.bin` na raiz** como `usb_update.bin`; o oficial V1.0.0.9 guardado em `resgate-oficial/` no
  pendrive e numa cópia no PC;
- sem comentários em **todo código** (shell, Python, C, Java, Makefile). Antes de tirar, o que o comentário
  explica (o porquê) passa para os docs. Ficam os funcionais: shebang, diretivas do `shellcheck`, `# noqa` e afins.

## Agentes (8, numa rodada só)

| fase | agente | o quê | onde |
|---|---|---|---|
| Procura | A1 | auditoria de organização e docs (plano, sem mexer) | leitura, repo principal |
| Procura | A2 | bugs e lacunas: shell do kit, scripts do PC, testes | leitura, repo principal |
| Procura | A3 | bugs e lacunas: apps, home, tema, câmera, tela, gerador do `.bin` | leitura, repo principal |
| Correção | A4 | corrige o que o A2 achou | worktree `bloco-21a`, branch `bloco-21a/kit` |
| Correção | A5 | corrige o que o A3 achou, inclusive o `.bin` | worktree `bloco-21b`, branch `bloco-21b/apps-bin` |
| Limpeza | A6 | junta 21a e 21b, aplica o plano do A1 | worktree `bloco-21`, branch `bloco-21/integracao` |
| Leitura fácil | A7 | mapa do repositório, comentários para os docs, código sem comentário | worktree `bloco-21` |
| Final | A8 | regressão no todo, corrige | worktree `bloco-21` |

O coordenador junta `bloco-21/integracao` na sessão e na `main`, dá push, gera o `.bin` e grava o pendrive.

## Regras comuns

- Nenhum agente fala com o projetor nem grava o pendrive.
- Stage só por caminho explícito; commits pequenos em pt-BR, sem linha de atribuição; push do branch.
- Kit em ASCII puro; listas de md5 só por `bash tests/atualizar-md5-kit.sh`.
- `make check`, `make check-kit`, `make check-fix` e `make check-bin` verdes; `shellcheck` sem aviso.
- Não aplicar o firmware novo (`Firmware PFL7560.zip`, modelo sem USB-C) na unidade com USB-C.

## Estado

Pronto para integrar (2026-10-31): A1 a A8 terminaram em `bloco-21/integracao`; falta o coordenador juntar na
sessão e na `main`, copiar a S4a para `firmware/` do repositório principal e gravar o pendrive.

- Bateria verde: `make check` OK; `check-kit` 197 / 94 / 690 / 569 / 97 / 35 / 72 / 42; `check-fix` 50;
  `check-bin` 324 (444 com os dois stocks reais); `shellcheck` sem aviso em todos os `.sh` versionados.
- `.bin` para o pendrive: `PFL7560-S4a-NAO-GRADUADO.bin`, md5 `a6e5da14cb3f53b42a457eb92bd91814` (só os 3 fixes, nos
  mesmos blocos do stock), regerado no fim do bloco com o mesmo md5. A S4b (`31702b64…`) só depois de a S4a subir.
- O que mudou, o que falta e o que só o aparelho prova: [`ESTADO.md`](../ESTADO.md).
