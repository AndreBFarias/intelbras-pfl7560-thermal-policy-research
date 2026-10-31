# Bloco 16 - Tema em toda tela e popup, descanso de tela MeowCast (2026-10-31)

Pedido do dono, depois de usar o projetor com o bloco 13:
- "A tela de bluetooth" (ainda fora do tema);
- "Gerenciamento de arquivos falta ficar no tema também";
- "Qualquer outra tela ou subtela tem que tá no nosso tema. Qualquer popup também";
- "Temos o ioscast e o espelhamento de tela. Acho que não precisamos deles também";
- o descanso de tela com a marca MeowCast (o do fabricante mostrava o logo da Intelbras).

O sistema novo se chama **MeowCast**. A marca está em `artifacts/tema/gerar-marca.py`: fundo `#120B1A` e nome
`#9D7AD0` em IBM Plex Sans Condensed Bold. Paleta e tons derivados: `artifacts/tema/dracula.txt` e
`artifacts/tema/README.md`.

## Já feito à mão no aparelho (não refazer; o bloco 14 leva ao kit)

- Sobreposições `PFL7560TemaZYSetting` e `PFL7560TemaNLProvision` ligadas (bloco 13A, doc 48).
- Office (`com.mobisystems.editor.office_registered`), iOSCast (`com.newlink.cast`) e Espelhamento
  (`com.hisilicon.miracast`) desligados com `pm disable-user` (`enabled="3"` no `package-restrictions.xml`).
  Sumiram da lista de apps.
- VLC 3.7.1 em `/vendor/app/VLC`.
- Marca MeowCast no logo de boot (partição `logo`), em `/atv/bootvideo/logo.jpg` e no `bootanimation.zip`.

## 16A - Sobreposições para tudo o que falta (agente Opus)

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-16a`, branch `bloco-16a/overlays`. Arquivos:
`artifacts/overlay/**` e `docs/research/48-tema-no-sistema.md`. Mesmo método do 13A: `recolorir.py`,
`conferir.py`, `build.sh`, sem referência a recurso e só `color`/`drawable` do mesmo tipo que no alvo.

1. **Varredura completa**, em tabela no doc 48: todo pacote com interface no firmware (`/system/app`,
   `/system/priv-app`, `/vendor/app`). Para cada um: o que o dono vê, se já está coberto e qual sobreposição o
   cobre.
2. **Prioridade 1**, o que o dono citou:
   - todas as telas e subtelas do `com.zhiying.settings` que o 13A não mapeou uma a uma: **Bluetooth** (a que o
     dono citou), Projeção, Sistema, Atualização, Outras configurações, e as imagens próprias delas no verde
     antigo;
   - o gerenciador de arquivos (`com.newlink.filemanager`).
3. **Prioridade 2:** `com.android.tv.settings`, `com.hisilicon.higallery` (abre as telas da suíte),
   `com.newlink.nlsource` (entradas HDMI e USB-C), a tela de aviso de USB e qualquer popup de sistema que o
   firmware mostre (procure `SYSTEM_ALERT`, `TYPE_TOAST`, `AlertDialog` e `Toast` nos apps).
4. **Framework** (`android`): só o que for popup visto pelo dono (Toast, diálogos), sempre com a saída de
   emergência do doc 48 §7. Nada de dimensão nem de layout.
5. **Provas:** `conferir.py` "TUDO OK" contra o APK alvo de cada um; `apksigner verify`; prévia antes e depois
   das telas novas em `artifacts/overlay/previa/`. Nada no aparelho.

## 16B - Descanso de tela MeowCast e home sem Espelhamento (agente Sonnet)

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-16b`, branch `bloco-16b/descanso-home`. Arquivos:
`artifacts/app/**`, `artifacts/home/**`, `pendrive-autorun/suite-boot.sh`, `pendrive-autorun/newlink_update.sh`
(só a constante `APP_VERSION_CODE`), `tests/test-suite.sh`, `tests/test-kit-pendrive.sh` e os docs 44 e 45.

1. **Descanso de tela** no app `com.pfl7560.verificar` (`artifacts/app`, `versionCode` + 1 no `build.sh` e no
   `APP_VERSION_CODE` do `newlink_update.sh`):
   - um `DreamService` (`.Descanso`) com `android.permission.BIND_DREAM_SERVICE` e o filtro
     `android.service.dreams.DreamService`;
   - tela inteira no fundo `#120B1A`, com o nome "MeowCast" em `#9D7AD0` (Plex Condensed Bold, se o app levar
     a fonte nos assets; senão `sans-serif-condensed` bold) e, menor e mais apagada, a hora;
   - o conjunto muda de lugar devagar (a cada 60 s, transição suave), para não ficar parado;
   - sem toque, `setInteractive(false)`, `setFullscreen(true)`, sem trabalho pesado.
2. **Ligar o descanso:** o `suite-boot.sh`, em todo boot e com qualquer gatilho, confere com `settings get` e
   põe `settings put secure screensaver_components com.pfl7560.verificar/.Descanso` (e
   `screensaver_default_component`) se for outro. Também confere com `cmd package resolve-activity` /
   `dumpsys` que o serviço existe antes de apontar para ele; sem ele, não mexe. O desinstalar da suíte devolve o
   do fabricante, `com.newlink.screensaver/com.newlink.screensaver.ScreenService`. Testes no harness com stub de
   `settings`.
3. **Home** (`artifacts/home`, `versionCode` + 1):
   - sai o atalho **Espelhamento** (o dono não quer);
   - a fileira Apps já some com os apps desligados (`queryIntentActivities` não traz desligado; confira e cubra
     no `Modelo` com a lista do aparelho).
   Prévias regeneradas e abertas.
4. Copie os dois APKs para `pendrive-autorun/` e rode `bash tests/atualizar-md5-kit.sh`; `make check`,
   `make check-kit` e `make check-fix` verdes; `shellcheck` sem aviso no kit.

## Comum

Nenhum agente fala com o projetor. Stage só por caminho explícito; commits pequenos em pt-BR sem acento, sem
linha de atribuição; push do branch. Kit em ASCII puro. Relatório no schema: feito, provas, commits, provisorio,
desvios, pendente.

## Estado (bloco 20, 2026-10-31)

16A e 16B integrados (merges `a48ab07` e `3d352a2`). O descanso MeowCast está em uso no aparelho e, desde
`76b6f5b`, baixa a luz a 10% enquanto está na tela (doc 44 §14.1). A home (`versionCode` 4) está sem Espelhamento.
Estado em [ESTADO-2026-10-31.md](ESTADO-2026-10-31.md).
