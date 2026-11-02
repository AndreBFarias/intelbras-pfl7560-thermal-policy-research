# Estado do trabalho (atualizado em 2026-11-01)

Arquivo para abrir sessão nova sem depender da conversa.

## Em voo (2026-11-02)

Blocos 23, 24 e 25 integrados no `main` (`3399c4a`, via branch `integracao`): todos os `tests/test-*.sh` com
0 falha, `make check` ok, `shellcheck` limpo, versionCode 7 nos dois apps. Timer do diário ligado no PC
(`~/.config/pfl7560/diario.env` com `PFL_IP=192.168.1.5`).

Decisões da rodada final (2026-11-02): logo automático com a chave **ligada**; `higallery` fica fora do
`deb_hisi`; curva gravada na `[ThermalPolicy]` vira tarefa do próximo bloco; `DESLIGAR-CHAVES.txt` não desliga o
diário (ok assim).

## Próximos passos

1. Instalar: `./install.sh --pendrive <ponto>` (sem firmware), o dono pluga o pendrive no projetor.
2. Conferir no aparelho (adb, leitura): `/data/vendor/pfl7560-suite/` com os scripts novos, `vendor.pfl7560.chaves`,
   diário gravando, `/data/vendor/pfl7560-logo/logo.log` (backup, gravação, releitura), keystone reto, `gfs`
   (velocidade ou duty), `Dreaming` no descanso, chaves de risco (`newlink.service`, launcher).
3. O dono olha o logo no boot seguinte e testa a home (Curvas, Logo do boot, Ajustes, Diário).

## Pendentes antigos

- `docs/MAPA.md` (`requirements.txt`) e `docs/codigo/pc.md` (`--dev`, git-lfs).
- Teams congelando com o projetor como monitor: sem causa.
- `escada=ausente` no relatório da suíte (`suite.sh:799`), anotado em `2026-11-01-tarefa-curas-do-doc-49.md`.
- Curva do dono gravada nas duas políticas da `[ThermalPolicy]` (doc 50 §proposta): o kit precisa aceitar a
  variante do `.ini`. Decidido para o próximo bloco.
- `le_temp` (`suite-curvas.sh`) não detecta `env_temp` congelado com anéis defasados (doc 37). Achado do R1 no
  bloco 25; vira tarefa do próximo bloco.
- Roteiro de medida do doc 49 (bloco 22): o dono decidiu pular; o uso do dia a dia confirma.

## Regras que não mudam

- Nunca `gtt`, nunca `stp`, nunca logcat contínuo pela rede. Nada gravado no aparelho sem o sim do dono.
- Commit sem `--no-verify`. Os arquivos `byte-exact` do `.gitattributes` passam intactos pelo pre-commit global
  (fonte em `~/.config/zsh/hooks/pre-commit`, instalado em `~/.config/git/hooks/pre-commit`).
- Worktrees novos com `GIT_LFS_SKIP_SMUDGE=1`.
