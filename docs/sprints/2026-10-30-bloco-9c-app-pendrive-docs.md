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

## Entradas da integração de 9A e 9B e da pesquisa P (coordenador, 2026-10-30)

Isto vale por cima do texto acima quando os dois discordarem.

1. **App.**
   - O pedido vai para `new File(getDataDir(), "pedir-verificacao")`, já integrado no vigia em `3c92cdb`. O
     vigia confere que o dono do arquivo é o UID do app, e um link é recusado.
   - Grave com `FileOutputStream` normal: o arquivo nasce com o dono certo.
   - Não precisa de permissão. `targetSdk 28` basta.
   - Pela pesquisa P §6, o launcher lista só `MAIN` + `LAUNCHER` com `loadIcon`. O `LEANBACK_LAUNCHER` e o
     banner não fazem mal, mas são opcionais: deixe só se custar pouco.
   - O ícone passa a funcionar no boot **seguinte** à instalação, porque o vigia liga no boot. Diga isso na
     tela "Verificação pedida" quando o pedido não for atendido em 60 s? Não: o app não tem como saber. Diga
     isso no LEIA-ME e no doc 44.
2. **Tecla do controle.** Pela pesquisa P §4, não é possível com confiança: o mapa de teclas é fixo, e a única
   ação configurável vem das teclas de fábrica NEWLINK7..9, que o controle comum provavelmente não tem.
   Registre no doc 44 como **não feito, com o porquê**. Não implemente nada para teclas.
3. **Item no menu de configurações.** O menu é do app do fabricante (`com.zhiying.settings`) e não tem ponto de
   extensão conhecido. Registre no doc 44 como **não feito**, com o porquê. O ícone "Verificar projetor" na lista
   de apps cobre o pedido.
4. **Firmware de resgate no pendrive (`--com-firmware`).**
   - O oficial do aparelho do dono é o V1.0.0.9, do `firmware/Software PFL7560.zip`, com o `.bin` de md5
     `28a2f280eee313a4b115567926b2ba4f`. Ele vai na raiz como `usb_update.bin`, conferido pelo md5.
   - **Nunca** use o `firmware/Firmware PFL7560.zip`, que é do modelo sem USB-C (doc 42).
   - O nosso é o `firmware/PFL7560-FIX-escada-NAO-GRADUADO.bin` (md5 `eae3a83db44f790b64b9a5838a27a977`). Ele vai
     em `firmware-nosso-NAO-GRADUADO/` com um `LEIA-ME.txt` ASCII: não está ativo, não foi provado no hardware,
     e só vale com a palavra do dono no momento.
   - Faltando um dos arquivos de origem ou com md5 diferente, a opção falha com mensagem clara e não copia
     pela metade.
   - Teste com `.bin` falsos pequenos, injetando o md5 esperado por variável **só no harness**, no padrão
     `PFL_TESTE`.
5. **Documentação**, que o 9B pediu e cabe aqui:
   - o `DESINSTALAR-SUITE.txt` leva a cópia do backup para o pendrive como
     `suite-panelparam-backup-<serial>.img`;
   - o arquivo `incompletas` e o motivo `interrompida_2x_seguidas` no histórico;
   - o limite conhecido das telas mostradas a partir de `/sdcard/pfl7560-suite`, descrito na seção de
     integração da tarefa 9B;
   - o `INSTALL.md` e o `LEIA-ME.txt` citam `nl_tela` e `fontes/`, e o comentário do `copiar_pendrive` no
     `install.sh` lista o kit inteiro.
6. **O que o teste final no aparelho precisa confirmar.** Junte as listas "só o aparelho confirma" dos relatórios
   do 9A e do 9B, que estão nas seções "Estado" das tarefas 9A e 9B e na seção de integração da 9B. O doc 44
   ganha uma seção "Teste no aparelho" com um roteiro único, em ordem, com o comando de cada passo e o que se
   espera ver. É a lista que o coordenador vai seguir com o dono.

## Estado (2026-10-30)

Feito no branch `bloco-9c/app-pendrive-docs`. Nada rodou no aparelho nem num disco de verdade: tudo é harness com
stubs e arquivos falsos.

- **C1, app:** `artifacts/app/` (fonte Java, manifest, recursos, `build.sh` sem Gradle, `gerar-icones.py`, chave
  estável `assinatura.keystore`, README), APK em `artifacts/app/pfl7560.apk` e a cópia em
  `pendrive-autorun/pfl7560.apk`, na lista de md5 do kit. `com.pfl7560.verificar`, `minSdk 28`, `targetSdk 28`,
  nenhuma permissão. O `newlink_update.sh` instala o APK (`pm install -r`, da cópia conferida em
  `/data/vendor/pfl7560-kit`) antes de lançar a suíte, se ausente ou de versionCode diferente; falha só avisa.
- **C2, pendrive:** `install.sh --pendrive DIR --com-firmware` (usb_update.bin oficial V1.0.0.9 conferido por md5
  e o nosso `.bin` em `firmware-nosso-NAO-GRADUADO/` com `LEIA-ME.txt`; origens conferidas antes de copiar; pasta
  por `PFL_FIRMWARE_DIR`), a pergunta do firmware na opção 5 do `install.bat` (via `install-firmware-pendrive.ps1`),
  `tests/preparar-pendrive.sh` e o `LEIA-ME.txt` do kit (suíte, gatilhos, ícone, `DESINSTALAR-SUITE.txt`, firmware
  de resgate e o risco do arranjo).
- **C3, processos:** `pfl7560-processos.sh` (só leitura, por adb; `top -b -n 2 -d 60` mais uma amostra a cada 5 s de
  `/proc/loadavg`, das props e dos processos em D), com resumo e dados brutos em `evidencias/processos/<data>.txt`.
- **C4, documentos:** `docs/research/44-suite-de-boot.md` (com a seção "Teste no aparelho" em roteiro único e
  ordenado), `README.md`, `docs/README.md`, `INSTALL.md`, guia 32, os `artifacts/*/README.md` e esta seção e as dos
  blocos 9, 9A e 9B. Frases velhas sobre o kit de cor corrigidas fora de `docs/sprints` e do doc 43 (guia 32 com as
  "metades", `INSTALL.md` com o "PRONTO", docs 29 e 31, a linha do bloco 7 no `docs/README.md`).

Provas (2026-10-30): `make check` (9 artefatos byte-exatos), `make check-fix` (48 verificações) e `make check-kit`
verdes, sem falha: `test-camcheck` 95, `test-tela` 94, `test-kit-pendrive` 547 (131 numa execução só dos estáticos,
do instalador e dos casos do app), `test-suite` 373, `test-preparar-pendrive` 78, `test-processos` 35, listas de md5 em dia. `bash -n` e
`dash -n` limpos nos `.sh` mexidos; `shellcheck` sem aviso novo (`-s sh` limpo no `newlink_update.sh`; no
`test-kit-pendrive.sh` só entraram notas SC2016 do padrão `afirma '...'`, como as 320 de antes).
`artifacts/app/build.sh` gera o APK do zero (md5 igual a cada execução), `apksigner verify` passa e
`aapt2 dump badging` mostra as duas atividades com `LAUNCHER` e `LEANBACK_LAUNCHER`. `install.sh --com-firmware` rodou
uma vez com os arquivos **de verdade** (zip oficial do repo e o `.bin` nosso do repositório principal) numa pasta
temporária: `usb_update.bin` com o md5 `28a2f280…` e a pasta do nosso com o md5 `eae3a83d…`, em 29 s.

Desvios do texto do spec:

1. **Tecla do controle e item no menu de configurações:** não feitos, com o porquê no doc 44 seção 10 (como mandam as
   entradas da integração).
2. **`install.bat` chama um `.ps1`** (`install-firmware-pendrive.ps1`) em vez de embutir o PowerShell: o escape do
   `cmd` para aquele código seria frágil. Nem o `.bat` nem o `.ps1` rodaram (não há Windows aqui); o harness confere
   só o texto, a ordem (origens conferidas antes de copiar o kit) e que os md5 do `.ps1` e do `install.sh` são os mesmos.
3. **`tests/preparar-pendrive.sh` formata exatamente o dispositivo informado** (disco inteiro, sem tabela, ou a
   partição): não cria tabela MBR. É o `mkfs.vfat -F 32 -n PFL7560` literal do spec.
4. **O APK vai na `KIT_LISTA` mas não na `SUITE_LISTA`** nem na pasta da suíte (a suíte não o executa); o
   `newlink_update.sh` o instala da pasta de trabalho do kit. O `APP_VERSION_CODE` do `newlink_update.sh` é uma constante
   à mão, igual ao `VERSAO_CODIGO` do `build.sh` (o harness confere os dois e o `aapt2 dump badging`).
5. **`LEANBACK_LAUNCHER` e banner ficaram** (custaram pouco), como o texto original do 9C pedia e a integração
   permitia.
6. **O `apksigner` assinou só no esquema v3** (com `minSdk 28` ele dispensa o v2; o Android 9 verifica v3). O
   `verify` passa; a instalação no aparelho é o teste.
7. **A saída de `top` do harness do `pfl7560-processos.sh` foi escrita à mão**, no formato do toybox do Android 9 que
   o parser espera (`S[%CPU]` no cabeçalho), e **não gravada do aparelho**, que não pode ser tocado neste bloco. O
   parser acha as colunas pelo cabeçalho, mas o formato real é PROVISÓRIO (passo 14 do roteiro).
8. O `pfl7560-processos.sh` aceita `PFL_INTERVALO` (intervalo das amostras) só para o harness: é ferramenta do PC,
   fora do kit, então a regra do `PFL_TESTE` do kit não se aplica.

PROVISÓRIO (depende do aparelho): `pm install -r` como root dentro do `exec` do init e os dois ícones na lista de apps;
o pedido do app chegando ao vigia e a recusa do arquivo de outro dono (o harness não monta); o formato real do `top`;
`tests/preparar-pendrive.sh` num pendrive de verdade e o `install.bat` com o `.ps1` no Windows; o gatilho da tomada e
tudo o que está na seção 11 do doc 44.

Anotado para o próximo bloco, sem fazer: o `DESINSTALAR-SUITE.txt` não desinstala o app (`adb uninstall` está no
doc 44); o piso `$n -lt 14` do `install.bat` ficou velho (a lista tem mais entradas) e não protege mais.
Pendente: o roteiro "Teste no aparelho" (doc 44, seção 12), pelo coordenador com o dono.
