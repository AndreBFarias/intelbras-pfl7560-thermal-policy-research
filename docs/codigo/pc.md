# Notas do código: scripts do PC (raiz do repositório)

O porquê das decisões dos comandos `pfl7560-*.sh`, dos instaladores e do `Makefile`. Uso de cada comando:
[`README.md`](../../README.md) e [`INSTALL.md`](../../INSTALL.md). Mapa geral: [`../MAPA.md`](../MAPA.md).

Os scripts com ajuda (`install.sh`, `pfl7560-lcd-color.sh`, `pfl7560-marca.sh`, `pfl7560-processos.sh`,
`pfl7560-qualidade.sh`, `pfl7560-vlc.sh`) mantêm o cabeçalho de comentário: a opção de ajuda o imprime com
`sed -n '2,Np' "$0"`, então essas linhas são texto do programa.

## Regras que valem para todos

- **`LC_ALL=C`.** O `awk` (mawk) segue `LC_NUMERIC`: em pt_BR imprime vírgula, lê `65.8` como 65 e compara `2,65`
  como texto. O mesmo TSV dava 7,45 °C em pt_BR e 8,17 °C em C.
- **Trava de modelo** (`ro.product.model == PFL7560`) antes de qualquer coisa: o celular do dono também aparece no
  `adb devices`, e um nó vizinho com a 5555 aberta pendura o `adb`. No `pfl7560-lcd-color.sh` é crítica: ele grava
  num dispositivo de bloco cru, e sem a trava o `dd` escreveria numa partição alheia.
- **`PFL_IP` pode trazer a porta** (`ip:porta`); sem porta, 5555. `PFL_DEV` no `pfl7560-monitor-props.sh` é só alias
  legado: antes era a única variável aceita ali e um `PFL_IP=x` era ignorado em silêncio.
- **Root conferido de verdade:** o `adb root` falha em silêncio e o `hidebug` responde `errno = 13`. Só se diz
  "(root)" se o `id` reler `uid=0`. O `hidebug` vive em `/vendor/bin` e exige root; o `adbd` sobe como
  `uid=2000(shell)`. Sem essa escalada o `pfl7560-autocaptura.sh` gravou 8253 TSVs só com cabeçalho entre
  2026-07-30 e 2026-08-17 (8257 sessões, só 4 amostraram; doc 35 §4).
- **Relock do `/vendor` por `trap EXIT`** em todo caminho que escreve (`pfl7560-fix.sh` desde a sprint 23,
  `pfl7560-evidencias.sh set-thermal` depois): sem ele, qualquer abort deixava o `/vendor` gravável até o reboot.
  `_RELOCK_DEV` é global porque o trap roda fora do escopo do `local`.
- **`INT`/`TERM` com `exit` explícito:** sem ele o handler retorna e o script segue (um Ctrl-C no `--vivacidade`
  ainda injetava os 71000; o `while :` do vigia ficava ininterrompível). Dentro da limpeza, `INT`/`TERM` ficam
  ignorados: um 2º Ctrl-C ali abortaria a limpeza no meio.
- **`gtt` avança o anel de amostras de um termistor só** (doc 37). Os monitores passivos (`saude`, `vigia-lsadc`,
  `monitor-props`, `teste-brilho`) leem só props (`zysys.env_temp` e `zysys.light_temp`, servidas pelo próprio laço
  térmico em ~29 ms, sem tocar o mux) e o `logcat`. Os que sondam (`monitor-termico`, `autocaptura`,
  `evidencias`) usam `gtt 0` e `gtt 1` sempre em par, pontual e supervisionado, nunca como serviço.
- **Nomes invertidos de fábrica:** `env_temp` é o sensor quente (`gtt1`, no bloco do LED); `light_temp` é o frio da
  placa (`gtt0`). Se os dois leem igual, o mux não comutou.
- **`gbri 0` devolve o PWM real**, não o nível lógico: com brilho máximo lê 996, não 1000. Os degraus válidos vêm do
  `gbll`: 750, 800, 850, 900, 950, 1000. Só abaixo de 950 houve queda de verdade.
- **ADC grosso:** degraus de ~2,3 °C. Diferença menor que 4,6 °C (dois degraus) não é evidência; "regime" = N
  amostras seguidas dentro de um degrau.
- **Temperatura ambiente é obrigatória** nas medições (`--ambiente`): as quatro medições de exaustão históricas
  (46,7 / 41,9 / 37,2 / 32,9 °C) são incomparáveis porque ninguém anotou a sala (doc 39 §2.6).

## `pfl7560-fix.sh`

- Dois modelos (doc 42): o modelo vem do `CONFIG_MODEL` do `.ini` e do `ro.newlink.projectname`. Um sinal presente e
  desconhecido não é compensado pelo outro: recusa. O `build.prop` de um modelo não serve ao outro (`zysys.typec*` e
  o canal de OTA), então o backup do sem USB-C fica em `backups-projetor/notypec/` e o revert só restaura backup do
  modelo do aparelho.
- **Backup anti-envenenamento:** se o md5 do arquivo puxado é o de fábrica, guarda o próprio pull; senão (aparelho já
  corrigido) usa o artefato de fábrica versionado, só depois de conferir que existe, não é vazio e tem o md5 certo.
  Nunca salva a versão modificada como `.STOCK`. Sem backup válido não se toca no `/vendor`.
- A config embutida (`CONFIG_B64`) é conferida pelo md5 do modelo antes do push: protege contra um heredoc
  corrompido numa edição futura.
- `init.bigfish.rc` é boot-crítico: se o pull falhar o temporário fica vazio, e nunca se sobrescreve o `.rc` com
  arquivo vazio.
- Valida os 3 estados relendo do aparelho antes de declarar sucesso e reiniciar (sem falso sucesso parcial).
  Escada: piso 850 em 70 °C (`WARNING_VALUE`); ventiladores a 1000 nos 7 degraus.
- O revert exige os três backups, não vazios e do modelo do aparelho.

## `pfl7560-saude.sh`

- **Só leitura** no modo padrão (props, arquivos, `logcat`): rodar N vezes dá o mesmo resultado. `--idempotencia`
  prova isso com duas passagens; se diferirem, ou o aparelho mudou sozinho ou o verificador tem efeito colateral.
- **`.ini` efetivo:** `/atv/ini/ZYCustom_<projectid>.ini` vence `/atv/ini/ZYCustom.ini`, que vence `/vendor/etc`
  (docs 04, 06, 09). Mesma ordem do `effective_ini` do `pfl7560-evidencias.sh`.
- **Assimetria deliberada no `LSADC Error`:** a presença prova que a proteção cegou; a ausência não prova que está
  viva (o erro aparece em 2 de cada 10 iterações e o buffer do `logcat` dura 60 a 150 s, doc 37). O único teste
  positivo é o `--vivacidade`.
- **Cor:** VESA=0, JEIDA=1 (doc 28 §12). O critério é o formato em uso bater com o byte `0x5c` gravado (senão o
  boot volta a outro formato). `PFL_LVDS_ESPERADO` (vesa|jeida) é opcional.
- **`--vivacidade`:** injeta 71000 m°C, fixo (acima do `WARNING` 70000, abaixo do `EMERGENCY` 75000; o
  `DEFAULT_PROTECT=2` desliga na hora). Só injeta se os limiares lidos agora deixam 71000 entre os dois. `head -1`
  porque um `grep` com duas linhas dava `integer expression expected` e a cadeia de `||` caía no ramo que injeta
  (falha aberta). O `verifica` antes impede a injeção com o `.ini` de fábrica ativo em `/atv` (`EMERGENCY_VALUE =
  45000`); antes, um `echo` no meio destruía o `$?`. A limpeza tenta 3 vezes e confere lendo de volta, com um
  canário: offline, o `getprop` volta vazio, igual a "override limpo". Exclui o no-op `Level Change 1000 => 1000!`
  (299 ocorrências numa vigília passiva), senão "o brilho voltou sozinho" dava sempre.
- `build.prop` é 0600 e a `panelparam` exige root: sem root, o verificador avisa em vez de falhar.

## `pfl7560-vigia-lsadc.sh`

- Mede a taxa de `LSADC Error` por hora de uso, sem sondar: decide entre "foi o observador" e "é um terceiro
  defeito de fábrica" (LSADC-S1). Só `logcat` e `/proc/uptime`.
- **Cobertura é o inimigo:** fora do ar durante um episódio, a taxa sai viesada para baixo. Cada reconexão faz
  backfill do buffer do `logcat`.
- **Identidade do boot** = epoch do host menos o uptime; flutua ±1 s, então variação menor que 60 s é a mesma
  sessão. `BID` e `UPTIME` são globais porque `$(...)` rodaria num subshell.
- **Trava contra duas instâncias:** em 2026-08-18 deram 6,76 h somadas para 2,36 h reais.
- **A janela de cobertura fecha em qualquer saída**, e a órfã fecha no último sinal de vida daquele boot, nunca em
  "agora": em 2026-09-03 isso publicou 386,26 h para 2,65 h reais (145×). As horas são a **união** das janelas.
- **Precursor:** "Upset Balance" é normal; o que importa é valor inválido entrando no laço. Casos vistos:
  `-1296474592` (2026-07-05, precedeu o erro) e `2` m°C (2026-08-17, de sondagem externa pelo `hidebug`). Faixa
  válida: 5 a 120 °C (a antiga, -1000 a 150000, deixava passar o "2 m°C").
- `Level Change X => Y` com X ≠ Y é a escada atuando; ventilador saindo do máximo também é raro. Esses e os erros
  nunca são amostrados; os normais, 1 a cada 20.
- Regra dos três: com zero eventos em h horas, o limite superior de 95 % é 3/h.

## `pfl7560-monitor-props.sh`, `pfl7560-monitor-termico.sh`, `pfl7560-autocaptura.sh`, `pfl7560-teste-brilho.sh`

- `monitor-props`: passivo; não detecta o `LSADC Error` (55 ciclos com o mesmo valor já foram vistos sem erro);
  quem detecta é o vigia. Agrupa por boot (o `boot_id` muda **ou** o uptime cai) e lê o `boot_id` a cada amostra (um
  reboot no meio ficava com o id antigo, 2026-10-29). Marca `override` quando as duas props vêm iguais: o
  `--vivacidade` injeta 71000 nas duas. Linha `LACUNA` = o aparelho sumiu; não é amostra.
- `monitor-termico`: o repouso é ~61 a 63 °C, mas o evento de 2026-07-29 chegou a 70 °C em uso real (doc 34); tela
  estática não reproduz o pior caso.
- `autocaptura`: polling pela rede porque o USB-C não expõe adb e não há evento de udev; serviço de usuário do
  systemd **desabilitado desde 2026-08-18** (cada `gtt` avança o anel). O TSV só nasce com dado de verdade; falha de
  amostragem não é "projetor offline" (o rótulo errado escondeu o bug do root por 18 dias). Leitura de 2 m°C em
  2026-08-17 23:20:44 no meio de uma série em 63421, sete minutos antes do `LSADC Error`: marca e nunca entra no
  pico.
- `teste-brilho`: o `FW_LEVEL` de fábrica para em 750 e estender abaixo é mudança persistente; o script cumpre o gate
  ao vivo. O laço térmico reassume o brilho (abaixo de 66 °C o alvo é 1000 e o `RunLineChange` sobe 2 a 3 por tick
  de 2 s; um `sbri` solto volta em 6 a 8 min): `--piso` usa isso, `--curva` reaplica a cada 15 s
  (`REAPLICA_S`) e registra o `gbri` real. `sbri`, `gbri` e `gbll` são de backlight e não passam pelo
  `getThermalTemp`. O doc 39 §4.2 mostrou depois que o firmware clampa em 750.

## `pfl7560-evidencias.sh`

- `set-thermal` mexe só no `ZYCustom.ini`, nunca no `build.prop`: o Wi-Fi corrigido mantém o adb vivo no reboot.
- A sentinela `NA` dos campos ausentes tem de sobreviver: interpolada no `awk`, `NA/1000` virava 0.0 e puxava a
  média dezenas de graus; testada com `-n` passava, e `$(( NA - NA ))` sob `set -u` encerrava o script.
- `MD5_FIX` acompanha o `.ini` corrigido (CONTRIBUTING, "três cópias").

## `pfl7560-lcd-color.sh`

- Backup automático obrigatório antes de qualquer `lvds ...` (LCD-S2): a `panelparam` persiste a cada escrita. Um
  por dia (o primeiro guarda o estado anterior a qualquer mudança do dia), com o serial no nome (serial ilegível =
  nome único).
- O assistente exige terminal: com stdin que não é tty, o `read -t` volta na hora por EOF e varreria os formatos em
  rajada. Reafirma a base a cada iteração (um timeout anterior pode ter voltado a `fmt 0`).
- `adb shell` não propaga código de saída confiável: sucesso por sentinela e releitura da partição inteira por md5.
  Tamanho padrão 8 MiB (`8M(panelparam)` no `/proc/cmdline`, doc 28).

## `pfl7560-marca.sh`, `pfl7560-vlc.sh`, `pfl7560-processos.sh`, `pfl7560-qualidade.sh`

- `marca`: partição `logo` de 40 MiB (lida em 2026-10-31), JPEG no byte 8192, `LOGO_KEY_LEN` (LE32) em 0x78. Os
  arquivos só seguem se o md5 de lá bater, e a partição tem de ser ainda a do backup.
- `vlc`: o sha256 do APK armeabi-v7a 3.7.1 (47073346 bytes) e o SHA-256 do certificado do VideoLAN, lidos em
  2026-10-31. O remount "funciona" em silêncio sem gravar: há prova de escrita. Espaço pela última coluna numérica
  do `df` ("Available").
- `processos`: `PFL_INTERVALO` só o harness muda.

## Instaladores

- `install.sh --pendrive`: copia o kit e confere cada arquivo contra a `KIT_LISTA` embutida no `newlink_update.sh`
  (a mesma que o aparelho confere). O `newlink_update.sh` não está na lista (não pode conter o próprio md5) e o
  `LEIA-ME.txt` também não: os dois são comparados byte a byte com a origem.
- `install.sh --com-firmware` (decisão do dono, bloco 21): o nosso `.bin` vai na raiz como `usb_update.bin`; o
  oficial V1.0.0.9 (`Software PFL7560.zip`, md5 do `.bin` `28a2f280…`) vai em `resgate-oficial/PFL7560.bin` com um
  LEIA-ME. Nunca o `Firmware PFL7560.zip` (sem USB-C). Tudo é conferido antes de copiar e de novo depois; a pasta
  do arranjo antigo (`firmware-nosso-NAO-GRADUADO/`) sai do pendrive.
- `install.bat`: grava o `.ini` e o `build.prop` do V1.0.0.9, então só segue com o `CONFIG_MODEL` **e** o
  `ro.newlink.projectname` do V1.0.0.9 (um aparelho sem USB-C que já levou esse `.ini` tem o `CONFIG_MODEL`
  rebaixado, mas não o projectname). Escritas atômicas; no revert, falha do `mv` marca `RVOK=0` e não reinicia; sem
  `!` na conferência final (com `EnableDelayedExpansion` o `cmd.exe` corromperia o `!`). Backup diário da
  `panelparam` com o serial no nome, como no script do Linux.
- `install-firmware-pendrive.ps1`: o equivalente do `--com-firmware` no Windows, chamado pela opção 5 do
  `install.bat`. Falha no meio da cópia remove o firmware do pendrive.

## `Makefile`

- `check-kit` roda o kit e a suíte com aparelho de mentira, o `nl_camcheck` e o `nl_tela` do host, as listas de
  md5, o pendrive com firmware e os scripts do PC com `adb` de mentira.
- `check-bin`: com `PFL_STOCK_ANTIGO=<PFL7560.bin V1.0.0.9>` e `PFL_STOCK_NOVO=<PFL7560.bin V1.0.0.1>` roda também
  com os stocks de verdade (só leitura; 1,3 GB cada; o antigo roda o `conteudo.txt` e apaga o `.bin` de teste).

## Provisório (o aparelho confirma)

| Arquivo | Constante ou função | O que falta | Doc |
|---|---|---|---|
| `pfl7560-processos.sh` | `CANDIDATO_CPU_PCT=2.0` | o limiar de CPU (um núcleo = 100 %) para sugerir desligar | 44 §11 |
| `pfl7560-processos.sh` | parser do `top` | o formato do `top` do toybox (`S[%CPU]`) | 44 §11 |
| `pfl7560-qualidade.sh` | `valor` | o último número da resposta do `hidebug` no módulo `picture` | 44 §16 |
