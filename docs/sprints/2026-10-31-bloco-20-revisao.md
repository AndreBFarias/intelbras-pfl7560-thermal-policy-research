# Bloco 20 - Revisão final do conjunto (2026-10-31)

Conferência no todo depois dos blocos 9 a 19, sem adb e sem projetor. Branch `bloco-20/revisao`, juntado na
sessão em `6000755`. Este registro saiu do `docs/ESTADO.md`, que passou a guardar só o estado atual.

## O que se achou e corrigiu

- **Código root:** o laço do vigia sem `inotifyd` não tratava o descanso de tela (só o `inotifyd` entregava
  `descanso-inicio`/`descanso-fim`). Corrigido no `suite-boot.sh`, com um caso novo no `test-suite.sh` que
  falhava antes (2 falhas) e passa depois. O aparelho do dono tem `inotifyd`, então ali nada mudava.
- **Docs sem contradição:** doc 44 (estado de uso, vigia nas duas pastas, ícone sempre roda, aviso de
  temperatura com `DPAD_CENTER`, luz pela prop, PATH dos serviços), doc 45 e o README da home (home pela prop
  `vendor.newlink.launcher.package`), doc 48, `INSTALL.md`, `LEIA-ME.txt`, guia 32, `firmware/README.md`,
  READMEs do app e do tema, a seção de estado dos blocos 9 a 19, o índice `docs/README.md` e a seção MeowCast do
  `README.md`.

## Provas

Bateria contada de novo no fim do bloco: `make check-kit` 192 / 94 / 689 / 550 / 86 / 35 / 72 / 42,
`make check-fix` 48, `make check-bin` 124, `make check` verde.

## Estado

Fechado em 2026-10-31. O bloco seguinte é o [21](2026-10-31-bloco-21-limpeza-bugs-bin.md).
