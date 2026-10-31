# Bloco 17 - Sobreposicoes para o que falta (2026-10-31)

Pedido do dono: "Qualquer outra tela ou subtela tem que ta no nosso tema. Qualquer popup tambem" e "Pode tocar
todo o resto". O 16A deixou marcados como "nao analisado" na varredura (doc 48 s10.1 e s10.9):

- teclado na tela (`HiPinyinIME`);
- avisos de tecla de atalho (`NLHotkeyService`);
- pareamento do controle (`ZYCustomUI`);
- menu de imagem das entradas (`HiTvSetting`);
- `AutoFocus3` (telas e avisos de foco);
- `ZYSpeakerModel` (alto-falante Bluetooth);
- avisos do `NewLinkService`;
- os players (`HiTvPlayer`, `IjkPlayer`, `NLSourcePlayer` se tiver tela propria alem da do 16A);
- o instalador de pacotes (`PackageInstaller`).

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-17a`, branch `bloco-17a/overlays`. Arquivos:
`artifacts/overlay/**` e `docs/research/48-tema-no-sistema.md`. Mesmo metodo do 13A e do 16A (`recolorir.py`,
`conferir.py`, `build.sh`, so `color`/`drawable`/`mipmap` do mesmo tipo do alvo, sem referencia), prioridade
na ordem da lista. O que nao der para cobrir sem mexer em layout ou em codigo vai para o doc 48, com o porque.
A do `android` ja esta ligada no aparelho: o que for framework entra nela, sempre so cor e forma.

Provas: `conferir.py` TUDO OK contra cada APK alvo extraido do firmware; `apksigner verify`; previa antes e
depois em `artifacts/overlay/previa/`. Nada no aparelho.

## Estado (bloco 20, 2026-10-31)

Integrado (merge `1638bb8`); as seis sobreposições estão ligadas no aparelho com as outras (20 ao todo; doc 48
§11). Estado em [ESTADO-2026-10-31.md](ESTADO-2026-10-31.md).
