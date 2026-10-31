# Bloco 18 - As últimas telas fora do tema (2026-10-31)

O dono autorizou tocar em tudo ("Pode tocar todo o resto"). O 17A deixou de fora, por ler errado uma mensagem
do coordenador como decisão do dono, os itens abaixo. Eles entram agora.

1. `HiPinyinIME`: teclado na tela.
2. `NLHotkeyService`: avisos de tecla de atalho.
3. `ZYCustomUI`: pareamento do controle.
4. `HiTvSetting`: menu de imagem das entradas.
5. `PackageInstaller`: instalador de pacotes.
6. **A sobreposição do `android`** (já ligada no aparelho e provada com reboot em 2026-10-31) ganha o que só ela
   alcança e o doc 48 §11.5 listou: o título vermelho da contagem de desligar, a `ToastActivity` e o aviso de
   USB do `NewLinkService`, os botões de mídia e as listas do `HiMusic`. Sempre só cor e forma; nada de
   dimensão nem de layout. Conferido contra o `framework-res.apk`. Mesmo pacote e mesmo nome
   (`com.pfl7560.tema.android`), `versionCode` + 1.
7. **Decisões já tomadas pelo coordenador**, para não parar:
   - aviso com texto preto fixo no app = painel claro (`texto`), aceito;
   - a contagem de desligar fica com o título no tema pela sobreposição do `android` (item 6).

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-18`, branch `bloco-18/overlays`. Arquivos:
`artifacts/overlay/**` e `docs/research/48-tema-no-sistema.md`. Mesmo método do 13A, 16A e 17A. Depois de gerar,
rode `bash tests/atualizar-md5-kit.sh`: copia para `pendrive-autorun/overlay/` e regenera `KIT_OVERLAYS` e
`KIT_LISTA`. Depois `make check`, `make check-kit` e `make check-fix` verdes.

Provas: `conferir.py` TUDO OK contra cada APK alvo extraído do firmware; `apksigner verify`; prévia antes e
depois em `artifacts/overlay/previa/`. Nada no aparelho. Stage só por caminho explícito; commits pequenos sem
linha de atribuição; push do branch. Relatório no schema: feito, provas, commits, provisorio, desvios,
pendente.

## Estado (bloco 20, 2026-10-31)

Integrado (merge `05d70f1`); ligadas no aparelho. Falta olhar com o controle o teclado na tela, o pareamento do
controle, o menu de imagem de uma entrada HDMI e a contagem de desligar (item 2 de "Só com o dono" em [ESTADO.md](../ESTADO.md)).
