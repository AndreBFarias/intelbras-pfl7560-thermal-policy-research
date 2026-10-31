# Bloco 21 - Limpeza, bugs, repositório fácil de ler e o .bin definitivo (2026-10-31)

Pedido do dono, antes de sair:
- limpeza: organização, informação unificada, repositório mais amigável, README atualizado;
- procura de bugs, melhorias e afins;
- repositório fácil para quem chega (iniciante ou ferramenta): achar dados e arquivos rápido, código sem
  comentários, pouco texto repetido;
- correção: bugs, melhorias, QA, UI e UX, lacunas em aberto, problemas legados e o `.bin` que funcione de vez;
- 8 agentes Opus; no fim, merge e push na `main` e o pendrive com o sistema novo.

Decisões do dono (2026-10-31):
- pendrive: **o nosso `.bin` na raiz** como `usb_update.bin`; o oficial V1.0.0.9 guardado em `resgate-oficial/` no
  pendrive e numa cópia no PC;
- sem comentários em **todo código** (shell, Python, C, Java, Makefile). Antes de tirar, o que o comentário
  explica (o porquê) passa para os docs. Ficam os funcionais: shebang, diretivas do `shellcheck`, `# noqa` e afins.

## Agentes (8 Opus, um workflow)

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

Em voo (2026-10-31).
