# Estado do trabalho (atualizado em 2026-11-01)

Arquivo para abrir sessão nova sem depender da conversa.

## Em voo

| bloco | branch / árvore | workflow | agentes |
|---|---|---|---|
| 24 - diário e chaves na home | `bloco-24` / `../.arvores/bloco24` | `w81cl8669` | D1 Sonnet (tarefas 1-3), D2 Opus (confere) |
| 25 - logo automático, piso 70 %, sensor | `bloco-25` / `../.arvores/bloco25` | `w710bu7bj` (run `wf_88989aa3-7d2`) | R1 pesquisa, I1 implementa, C1 confere (Opus high) |

Os dois blocos mexem na home e no kit: a integração do segundo no `main` vai ter conflito em `versionCode`, APKs e
listas md5. Resolver refazendo os APKs e rodando `bash tests/atualizar-md5-kit.sh`, nunca editando md5 à mão.

## Próximos passos

1. Quando cada workflow voltar: rodada de AskUserQuestion com todas as decisões que os relatos abrirem.
   - Bloco 24: por que o `higallery` ficou fora do grupo HiSilicon (o dono aprovou o grupo inteiro).
2. Integrar no `main` (merge do branch), refazer APKs, `versionCode` e md5, rodar todos os `tests/test-*.sh`.
3. Instalar no aparelho os blocos 23 + 24 + 25. O dono mandou em 2026-11-01: "Quero que você coordene e integre
   e instale até o fim". As decisões que os relatos abrirem continuam indo pelo AskUserQuestion antes de instalar.
   Conferir no aparelho:
   - a leitura do `gfs` (velocidade ou duty);
   - se entra em `Dreaming` no descanso;
   - as chaves de risco (`newlink.service`, launcher);
   - se o keystone zerado persiste no boot;
   - o logo reto no boot (o dono olha).

## Pendentes antigos

- `docs/MAPA.md` (`requirements.txt`) e `docs/codigo/pc.md` (`--dev`, git-lfs).
- Teams congelando com o projetor como monitor: sem causa.
- `escada=ausente` no relatório da suíte (`suite.sh:799`), anotado em `2026-11-01-tarefa-curas-do-doc-49.md`.
- Roteiro de medida do doc 49 (bloco 22): o dono decidiu pular; o uso do dia a dia confirma.

## Regras que não mudam

- Nunca `gtt`, nunca `stp`, nunca logcat contínuo pela rede. Nada gravado no aparelho sem o sim do dono.
- Commit sem `--no-verify`. Os arquivos `byte-exact` do `.gitattributes` passam intactos pelo pre-commit global
  (fonte em `~/.config/zsh/hooks/pre-commit`, instalado em `~/.config/git/hooks/pre-commit`).
- Worktrees novos com `GIT_LFS_SKIP_SMUDGE=1`.
