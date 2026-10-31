# Bloco 9C - app da tela inicial, pendrive, ferramenta de processos e documentos (2026-10-30)

Parte do [bloco 9](2026-10-30-bloco-9-suite-de-boot.md). Roda depois de 9A e 9B integrados (usa os comandos
e caminhos deles). Branch `bloco-9c/app-pendrive-docs`, worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-9c`.

## C1 - App `PFL7560` (APK sem Gradle)

- Fonte em `artifacts/app/` (Java + `AndroidManifest.xml` + recursos), script `artifacts/app/build.sh` com o SDK
  local (fato 10 do bloco 9: `aapt2`, `javac --release 8` contra `platforms/android-34/android.jar`, `d8`,
  `zipalign`, `apksigner`). Chave de assinatura própria e estável em `artifacts/app/assinatura.keystore` (não é
  segredo: só garante que a atualização instala por cima); senha documentada no script.
- Pacote `com.pfl7560.verificar`, `minSdk 28`, `targetSdk 28` (nenhuma permissão: o pedido vai para a pasta
  privada do app). Duas atividades com ícone próprio, ambas com `LAUNCHER` **e** `LEANBACK_LAUNCHER` e `banner`
  (o launcher do projetor pode usar qualquer um; a pesquisa P item 5 diz qual):
  - **Verificar projetor**: grava `pedir-verificacao` em `getDataDir()` (`/data/data/com.pfl7560.verificar/`),
    mostra por 3 s "Verificação pedida. O projetor começa em instantes." e fecha. Se não conseguir gravar, diz
    isso e como resolver.
  - Por que a pasta privada (revisão de segurança de 2026-10-30): em `/sdcard` qualquer app grava o arquivo e
    dispara a suíte (com a rampa ativa). Na pasta privada só o UID do app grava; o vigia root confere que o dono
    do arquivo é o dono da pasta do app (UID >= 10000). O coordenador ajusta o vigia do 9B na integração.
  - **Wi-Fi**: abre `android.settings.WIFI_SETTINGS`; se não resolver, `com.zhiying.settings/.network.WifiSettingActivity`;
    se nada abrir, mostra a mensagem e fecha.
- Ícones e banner gerados (PNG) por script, no estilo das telas (fundo `#0E1116`, traço claro); sem emoji.
- APK em `artifacts/app/pfl7560.apk` e cópia em `pendrive-autorun/pfl7560.apk`; entra na lista de md5 do kit.
- O `newlink_update.sh` instala o APK (`pm install -r`) se ele não estiver instalado ou se a versão for outra;
  falha não para o kit. Teste no `test-kit-pendrive.sh` com stub de `pm`.
- Tecla do controle: só se a pesquisa P achar um caminho de confiança média ou alta; senão, fica registrado
  como não feito, com o porquê.

## C2 - Pendrive

- `install.sh --pendrive <ponto de montagem>` e a opção 5 do `install.bat` copiam o kit novo inteiro (suíte,
  `nl_tela`, `fontes/`, APK) e, com `--com-firmware`, também: o `usb_update.bin` **oficial** do modelo (extraído
  do zip certo em `firmware/`, conferido pelo md5 do doc 42/README do firmware) na raiz, e o nosso `.bin` em
  `firmware-nosso-NAO-GRADUADO/` com um `LEIA-ME` curto (ASCII) dizendo que não está ativo e por quê.
- `tests/preparar-pendrive.sh <dispositivo>`: confere que é removível (`lsblk` RM=1, TRAN=usb), mostra modelo e
  tamanho e **pede confirmação digitada** antes de formatar FAT32 (`mkfs.vfat -F 32 -n PFL7560`), monta, chama o
  `install.sh --pendrive ... --com-firmware`, confere os md5 e desmonta. Nunca formata disco não removível.
- `pendrive-autorun/LEIA-ME.txt` (ASCII, leigo): o que a suíte faz, quando roda (tomada, pendrive, ícone), o
  que aparece na tela, como desligar a suíte (`DESINSTALAR-SUITE.txt`), o firmware de resgate e o risco do
  arranjo com os dois juntos.

## C3 - Processos em segundo plano

`pfl7560-processos.sh` (PC, via adb, só leitura, no estilo dos `pfl7560-*.sh`): com o projetor parado, mede por
60 s a CPU por processo (`top -b` ou `/proc/<pid>/stat` em duas amostras), a carga, os processos em estado D,
e cruza com a temperatura das props (sem `hidebug gtt`). Saída em `evidencias/processos/<data>.txt` e um resumo
legível: os 10 que mais gastam, o que cada um é (quando conhecido), e se algum é candidato a desligar (sem
desligar nada). Harness simples com saída fixa de `top` gravada.

## C4 - Documentos

- `docs/research/44-suite-de-boot.md`: o que é, como instala, gatilhos, etapas, telas, arquivos no aparelho,
  como desligar, limites e o que ficou PROVISÓRIO até o teste.
- `README.md`, `docs/README.md`, `INSTALL.md`, guia 32 e `artifacts/*/README.md`: citam a suíte sem contradizer
  o resto (o repositório não pode se contradizer: rode um `grep` pelas frases antigas sobre o kit de cor).
- Blocos 9, 9A, 9B, 9C: seção "Estado" com o que foi feito, provas e o que falta (teste no aparelho).

## Prova

`make check`, `check-kit`, `check-fix` verdes; `artifacts/app/build.sh` gera o APK do zero e `apksigner verify`
passa; `aapt2 dump badging` mostra as duas atividades com `LAUNCHER` e `LEANBACK_LAUNCHER`;
`tests/preparar-pendrive.sh` recusa disco não removível (teste com `lsblk` falso).
