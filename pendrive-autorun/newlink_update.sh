#!/vendor/bin/sh
# ---------------------------------------------------------------------------
#  CONVENCAO DE CHARSET (NAO MEXER): este arquivo e ASCII PURO de proposito.
#  Roda no shell do projetor (/vendor/bin/sh, mksh/toybox do Android 9, locale
#  incerto) e vive num pendrive FAT32; acento pt-BR pode virar mojibake ou
#  quebrar o parser do shell. NAO acentuar este arquivo. Convencao fixada na
#  sprint 25 (auditoria de acentuacao) - decisao registrada para o proximo
#  auditor.
# ---------------------------------------------------------------------------
# ============================================================================
#  PFL7560 - KIT UNIVERSAL de pendrive, v2 (termico + wi-fi + xiri + cor + suite)
#
#  Como funciona: o proprio firmware roda /vendor/bin/nl_usb_update.sh a cada
#  boot (gatilho: sys.boot_completed=1). Esse script varre os pendrives e, se
#  achar um "newlink_update.sh" na raiz, EXECUTA ele como ROOT (via exec do
#  init). Por isso aqui roda so o que e CURTO: conferir o kit e a fase termica.
#  A fase de COR (pergunta a pessoa, ate ~90 s) e lancada DESTACADA, a partir de
#  uma copia em /data/vendor/pfl7560-kit (pasta so do root, 0700), pelo cor.sh.
#
#  SUITE (bloco 9B): o kit instala a suite de verificacao em /data/vendor/pfl7560-suite
#  (pasta so do root) e o servico de boot /vendor/etc/init/pfl7560-suite.rc, e lanca
#  a suite no modo pendrive (cor, angulo e foco, temperatura, rampa, resumo) em vez do
#  cor.sh direto. Com DESINSTALAR-SUITE.txt na raiz do pendrive, remove a suite e
#  roda so a fase de cor, como antes. Sem a suite instalada, idem.
#
#  APP (bloco 9C): antes de lancar a suite, o kit poe o pfl7560.apk (da copia conferida em
#  /data/vendor/pfl7560-kit) em /vendor/app/PFL7560 como app do sistema, se faltar ou diferir
#  (o pm install deste firmware recusa apps de fora). Falha de instalacao nunca para o kit. O app grava o pedido de verificacao na pasta privada dele
#  e o vigia do pedido (suite-boot.sh) so liga no boot: o icone passa a valer no boot SEGUINTE.
#
#  Coloque na RAIZ do pendrive (FAT32) tudo o que esta na pasta pendrive-autorun:
#      newlink_update.sh  cor.sh  lvdsctl  nl_camcheck  ZYCustom.ini  LEIA-ME.txt  kit/*.png
#      suite.sh  suite-boot.sh  suite-pedido.sh  pfl7560-suite.rc  (e nl_tela, fontes/ do 9A)
#      pfl7560.apk  (app dos icones "Verificar projetor" e "Wi-Fi", bloco 9C)
#      pfl7560-home.apk  (home nova, bloco 10A)
#      overlay/*.apk  (sobreposicoes de tema Dracula, blocos 13A/16A) e marca/*  (logo e animacao
#      de boot MeowCast): bloco 14
#  Mesmo pendrive para qualquer PFL7560: sem serial, sem arquivo para editar.
#
#  IDEMPOTENTE:
#   - TERMICO: o estado-alvo e o md5 do ZYCustom.ini que o firmware le. Troca
#     (escrita atomica) so se o md5 atual for o de fabrica (dos DOIS modelos: com
#     USB-C V1.0.0.9 e sem USB-C V1.0.0.1) ou o da versao anterior nossa; md5
#     desconhecido = RECUSA. O .ini novo e montado a partir do .ini DO APARELHO,
#     trocando so as secoes termicas pelas do ZYCustom.ini do pendrive: o resto
#     (CONFIG_MODEL inclusive) fica byte a byte. 2a execucao: nada e escrito.
#   - COR: o cor.sh mede a escada de cinzas pela camera interna (nl_camcheck) e,
#     se ela estiver fora de ordem, troca o formato; sem camera ele pergunta olhando
#     a tela e so grava com DUAS teclas; sem tecla nada muda. 2a execucao: nada e
#     escrito e nada reinicia.
#   - Reinicia UMA vez, e so quando a fase termica mudou algo.
#
#  SEGURANCA: o md5 de CADA arquivo do kit e conferido contra a lista embutida
#  abaixo ANTES de qualquer escrita. Divergiu ou faltou = aborta. Este script
#  NUNCA chama hidebug nem gtt (doc 37). Limite honesto: um newlink_update.sh
#  adulterado roda como root e nao ha defesa contra ele.
#  E3b: o cor.sh, o lvdsctl e o nl_camcheck rodam como root, entao ficam so numa pasta do root
#  (nunca em /data/local/tmp, que o usuario shell grava), verificada a cada uso
#  (diretorio real, nao link, dono root); e o md5 do cor.sh e conferido
#  IMEDIATAMENTE antes de cada execucao (restaurar, tela e teste de cor).
# ============================================================================

# ---- ganchos de teste -------------------------------------------------------
# So valem com PFL_TESTE=1 (o harness em tests/ a define). Fora disso TODAS saem
# do ambiente, para que nenhuma seja porta de entrada em producao; R fica vazio.
if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_RAPIDO PFL_DONO PFL_TESTE
fi
R="${PFL_ROOT:-}"
MP="$R/mnt/media_rw/$1"
INI="$R/vendor/etc/ZYCustom.ini"
BP="$R/vendor/build.prop"
RC="$R/vendor/etc/init/hw/init.bigfish.rc"
ATV_INI_DIR="$R/atv/ini"
WORK="$R/data/vendor/pfl7560-kit"
JOURNAL="$WORK/journal"
# suite (bloco 9B): pasta so do root e servico de boot. O .rc e
# montado FORA da pasta que o init le (/vendor/etc/init) e so entra nela por mv.
SUITE="$R/data/vendor/pfl7560-suite"
RC_SUITE="$R/vendor/etc/init/pfl7560-suite.rc"
RC_SUITE_NOVO="$R/vendor/etc/pfl7560-suite.rc.new"
ROTULO_PADRAO="u:object_r:vendor_configs_file:s0"
# app "PFL7560" (bloco 9C): pacote e versionCode do pfl7560.apk da lista (build.sh tem o mesmo
# VERSAO_CODIGO; o harness confere os dois)
# shellcheck disable=SC2034  # so conferidos pelo harness contra o build.sh e o apk
APP_PKG="com.pfl7560.verificar"
# shellcheck disable=SC2034
APP_VERSION_CODE="4"
ESPERA_REBOOT=8
# dono exigido na pasta de trabalho e nos arquivos dela (root = 0)
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
# gancho de teste (so com PFL_TESTE=1): o harness (tests/) zera a espera
[ -n "${PFL_RAPIDO:-}" ] && ESPERA_REBOOT=0

# md5 do ZYCustom.ini. O kit serve a DOIS modelos, que so diferem no CONFIG_MODEL
# do [Global] (doc 42): o com USB-C (V1.0.0.9, KJM_5H039_412) e o sem USB-C
# (V1.0.0.1, KJM_5H039_412_INTELBRAS_NOTYPEC_TP). Para cada .ini conhecido o
# resultado esperado tambem e conhecido; qualquer outro md5 = desconhecido = o kit
# recusa em vez de sobrescrever um mapa que nao conhece.
#   *_OK            corrigido, modelo com USB-C (e o ZYCustom.ini do pendrive)
#   *_OK_NOTYPEC    corrigido, modelo sem USB-C (artifacts/ZYCustom_390.NOTYPEC.ini)
#   *_FABRICA       de fabrica V1.0.0.9 (com USB-C); *_FABRICA_NOTYPEC, o V1.0.0.1
# Versoes anteriores nossas que ja foram para aparelho (todas do modelo com USB-C):
#   bbf82dd1  artifacts/ZYCustom_390.PREV-211927.ini
#   1ad641ed  pendrive-autorun/ZYCustom.ini de 23169d6 a d10f6da (antes da
#             escada; a que o pendrive e o adb levaram, docs 26 e 34)
#   5868d67f  pendrive-autorun/ZYCustom.ini de cd5a80f (escada com os espacos
#             de fim de linha cortados)
INI_MD5_OK="252ab7a72a007a8b79b3fc86bd5c0d19"
INI_MD5_OK_NOTYPEC="bdf5c4640596d1b2f2fb7f62fbadd6e3"
INI_MD5_FABRICA="29d8ba36149413e899563029df078f6d"
INI_MD5_FABRICA_NOTYPEC="ed3f314ca89698cb057a74ef64dca38e"
INI_MD5_ANTERIORES="bbf82dd17d4523b7df8a86bec0e850ce 1ad641ed2dd99e61d8a987a675e9aced 5868d67fd8d47564842494aa8f14c37c"
# secoes que o kit troca no .ini do aparelho (as do ZYCustom.ini do pendrive); o
# resto do arquivo nao e tocado. [Thermal] leva os limites de 70/75 C.
TERM_SECOES="Thermal BacklightPolicy ThermalPolicy Thermistor_0 Thermistor_1 CoolingFan_0 CoolingFan_1"

# md5 de CADA arquivo do kit, relativo a raiz do pendrive. Gerado por
# tests/atualizar-md5-kit.sh (o harness confere que esta em dia). NAO editar a mao.
# KIT_LISTA_INICIO
KIT_LISTA="252ab7a72a007a8b79b3fc86bd5c0d19  ZYCustom.ini
539096ea65bd73683697574a3be5c023  cor.sh
178d812872cb9306c0ae6faeed07184a  lvdsctl
8bf8bae6410b6b289d55e92671870d3b  nl_camcheck
662acb7ac307699a389e892047f0d883  nl_tela
07ef9ae4b8a086cbf339af9698bb3a97  suite.sh
dc63a8daa4fc654a938dac0283e92acb  suite-boot.sh
f04915c87ca4287eb2c003beffca013f  suite-pedido.sh
cb9360471adcfcc3cc1e24998afbede4  pfl7560-suite.rc
2b70e7f67a4c8979c7974e0face601a3  pfl7560.apk
a2eaa639a4687070762d37da7cc3d122  pfl7560-home.apk
acaaefb249632298e6af03c73dbc1c8d  kit/aguarde.png
cedac2a713b8b29dd1b64d77a587b49f  kit/calibracao.png
b9b36dfd2df8eb824ee2d480d70c45a9  kit/corrigida.png
1afd05f32600385e0587acf062262988  kit/erro.png
0afaa2345ab1082d73171003922f5277  kit/escada-1.png
85fc83ce25d4d44a1bb7b7baafc3c090  kit/escada-2.png
7cd6dca3430ab476de9bb4c30b3dd4b5  kit/pronto.png
ab1ca6ffb16e52c7fed90f6db418965b  kit/reiniciando.png
6b63b3f38003b887aa8433d74a873844  fontes/IBMPlexMono-Regular.ttf
be3d5e5c761ef60563c87b9475f5a99d  fontes/IBMPlexMono-SemiBold.ttf
f7c622dca16e1da365a328894f74cbac  fontes/IBMPlexSansCondensed-Bold.ttf
c90afb82696a6873464b6cc8f315f0eb  fontes/IBMPlexSansCondensed-Regular.ttf
9f4dbd7c74436d0d895ccc3689c42490  fontes/IBMPlexSansCondensed-SemiBold.ttf
160cec49299e5d622c5150977bfe188c  fontes/OFL.txt
a540d2378b44e4bbbb696ebe8f914ecc  overlay/PFL7560TemaAutoFocus.apk
bcab5041f46f52cb81fd3360ab178dba  overlay/PFL7560TemaHiGallery.apk
39159a14ba858f499ec7bfd62a51d37f  overlay/PFL7560TemaHiMusic.apk
d4c163b89a64936a00c275bd940a2238  overlay/PFL7560TemaHiPinyinIME.apk
58fa7c9fd6ecd806c142c18687b8c2e0  overlay/PFL7560TemaHiTvSetting.apk
557918569f259b73c4df812557d1adb6  overlay/PFL7560TemaHiVideoPlayer.apk
df73fabe626debddcbe69f0de3f0239a  overlay/PFL7560TemaIjkPlayer.apk
27cad85a351c0d482e17880a9d673125  overlay/PFL7560TemaNLHotkeyService.apk
6d36a5f471a2ff85d4719f21a6dc5cd0  overlay/PFL7560TemaNLProvision.apk
5a60ac5f7d7b68ef47dd04ffb9f39455  overlay/PFL7560TemaNLSource.apk
352aefd8b6fcaec64da980f47f1b8fb6  overlay/PFL7560TemaNewLinkService.apk
b55ae3ac05c47c796b0be4850825d63a  overlay/PFL7560TemaPackageInstaller.apk
6294e2b1a285e8c9e9e4b398f2fb3923  overlay/PFL7560TemaPowerService.apk
1afda9aa85fd24f80827dadf16a8d675  overlay/PFL7560TemaTvSettings.apk
1f102f9136010b5bd76dabb726e2aef0  overlay/PFL7560TemaZYBluetooth.apk
50da8f76e9719f7904b583b8c4cee7bc  overlay/PFL7560TemaZYCustomUI.apk
75be481514660444a0f90cb423d29e82  overlay/PFL7560TemaZYFileManager.apk
e3d36ef64f492794af92f7ccd1ca993a  overlay/PFL7560TemaZYSetting.apk
93fa43136f60237a758fcd5e2bad433a  overlay/PFL7560TemaZYSpeakerModel.apk
463a24b47859e15aaecd477c3a99540a  overlay/PFL7560TemaAndroid.apk
3f33a5898aaaff385d9e6cf42762677a  marca/logo.jpg
85256535f156d25e65af2752de3fb90d  marca/bootanimation.zip
"
# KIT_LISTA_FIM

LOG(){ echo "[PFL7560-fix] $*"; }
LOG "==== autorun iniciado (mountpoint=$1) ===="

# trava de seguranca: so age no PFL7560
MODEL=$(getprop ro.product.model 2>/dev/null)
if [ "$MODEL" != "PFL7560" ]; then
  LOG "modelo='$MODEL' nao e PFL7560 - abortado por seguranca."
  exit 0
fi

# sem md5sum nao ha como conferir o kit: aborta antes de qualquer escrita
if ! command -v md5sum >/dev/null 2>&1; then
  LOG "[ERRO] md5sum ausente - nao consigo conferir o kit. Abortado (nada foi alterado)."
  exit 1
fi

if [ ! -d "$MP" ]; then
  LOG "[ERRO] mountpoint '$MP' nao existe - abortando (nada foi alterado)."
  exit 1
fi

# ---- conferencia do kit ------------------------------------------------------
kit_nomes(){ echo "$KIT_LISTA" | sed -n 's/^[0-9a-f][0-9a-f]*  //p'; }
kit_md5_esperado(){ echo "$KIT_LISTA" | sed -n "s|^\\([0-9a-f][0-9a-f]*\\)  $1\$|\\1|p" | head -1; }
# confere cada arquivo de $2... em $1; devolve !=0 se algum faltar ou divergir
kit_conferir(){
  _base="$1"; shift
  _rc=0
  for _n in "$@"; do
    _esp=$(kit_md5_esperado "$_n")
    _got=$(md5sum "$_base/$_n" 2>/dev/null | cut -d' ' -f1)
    if [ -z "$_esp" ] || [ "$_got" != "$_esp" ]; then
      LOG "[ERRO] kit: '$_n' ausente ou md5 diferente do esperado (achado '$_got', esperado '$_esp')."
      _rc=1
    fi
  done
  return "$_rc"
}

# ---- pasta de trabalho so do root (E3b) --------------------------------------
# O cor.sh e o lvdsctl rodam como root a partir de $WORK. Se alguem que nao e root
# pudesse escrever la (ou trocar a pasta por um link), executaria codigo como root.
#  - dir_seguro: diretorio real (nao link), dono root, sem acesso de grupo/outros
#    (o ls pode por '.' ou '+' no fim do modo, por SELinux/ACL);
#  - arq_seguro: arquivo regular (nao link) e de dono root.
dir_seguro(){
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ldn "$1" 2>/dev/null)
  case "$1" in
    d???------|d???------[.+]) [ "$3" = "$DONO_UID" ] ;;
    *) return 1 ;;
  esac
}
arq_seguro(){
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ln "$1" 2>/dev/null)
  [ "$3" = "$DONO_UID" ]
}
trabalho_ok(){
  dir_seguro "$WORK" && return 0
  LOG "[ERRO] $WORK nao e uma pasta so do root (link, dono errado ou aberta a outros) - NAO vou usar nem escrever nela."
  return 1
}
# cria a pasta (0700, do root) se nao existir e confere; uma que ja exista e
# errada NUNCA e consertada nem apagada aqui: recusa.
preparar_trabalho(){
  if [ ! -e "$WORK" ] && [ ! -L "$WORK" ]; then
    mkdir -p "${WORK%/*}" 2>/dev/null
    ( umask 077; mkdir "$WORK" 2>/dev/null ) && chmod 700 "$WORK" 2>/dev/null
  fi
  trabalho_ok
}
# confere os arquivos do kit de $1 (a pasta de trabalho ou a de preparo dentro
# dela): regulares (nao link), do root e com o md5 da lista
conferir_em(){
  _cb="$1"; shift
  _trc=0   # nome proprio: o kit_conferir tambem usa _rc e _n
  for _tn in "$@"; do
    if ! arq_seguro "$_cb/$_tn"; then
      LOG "[ERRO] kit: '$_tn' em $_cb nao e arquivo regular do root (link ou outro dono)."
      _trc=1
    fi
  done
  kit_conferir "$_cb" "$@" || _trc=1
  return "$_trc"
}
trabalho_conferir(){ conferir_em "$WORK" "$@"; }
# IMEDIATAMENTE antes de cada execucao do cor.sh (restaurar, tela, teste): pasta
# so do root, cor.sh regular do root e md5 da lista embutida. O lvdsctl quem
# confere, na hora de executa-lo, e o proprio cor.sh.
cor_pronto(){
  trabalho_ok || return 1
  trabalho_conferir cor.sh
}

# ---- recuperacao: journal de um teste de cor interrompido --------------------
# Roda ANTES de qualquer outra coisa. Usa a copia do cor.sh que ficou em $WORK
# (a que o proprio journal usa), reconferida contra a lista embutida.
if [ -e "$WORK" ] || [ -L "$WORK" ]; then
  trabalho_ok || { LOG "[ERRO] pasta de trabalho recusada - ABORTADO. Nada foi alterado."; exit 1; }
fi
if [ -f "$JOURNAL" ]; then
  LOG "journal de cor pendente: um teste anterior foi interrompido; restaurando o formato original antes de tudo"
  if cor_pronto; then
    sh "$WORK/cor.sh" --restaurar
    if [ "$?" = "3" ]; then
      LOG "restauracao pediu reboot; encerrando por aqui."
      exit 0
    fi
  else
    LOG "[AVISO] cor.sh de recuperacao ausente, link ou com md5 diferente em $WORK; o gancho de boot ou o proximo teste tenta."
  fi
fi

# ---- md5 de cada arquivo do kit ANTES de qualquer escrita --------------------
# shellcheck disable=SC2046
if ! kit_conferir "$MP" $(kit_nomes); then
  LOG "[ERRO] kit incompleto ou adulterado - ABORTADO. Nada foi alterado. Copie de novo TODOS os arquivos da pasta do kit para a raiz do pendrive."
  # unica escrita permitida aqui: a tela de erro, e so se ela propria confere
  if kit_conferir "$MP" kit/erro.png >/dev/null 2>&1; then
    mkdir -p "$R/sdcard/pfl7560-kit" && cp "$MP/kit/erro.png" "$R/sdcard/pfl7560-kit/erro.png" \
      && am start -a android.intent.action.VIEW -d "file:///sdcard/pfl7560-kit/erro.png" -t image/png >/dev/null 2>&1
  fi
  exit 1
fi
LOG "kit conferido: $(kit_nomes | wc -l | tr -dc '0-9') arquivos com md5 certo"

# copia o kit para a pasta so do root (o cor.sh roda de la, destacado). Nao apaga
# o journal nem o backup: so as subpastas (kit/, fontes/) e os arquivos da lista sao trocados.
# A copia vai primeiro para uma pasta de PREPARO dentro de $WORK, e conferida LA
# e so entao cada arquivo vai para o lugar com mv (rename, atomico; um link no
# lugar dele e substituido, nunca seguido). Assim $WORK/cor.sh e $WORK/lvdsctl
# nunca tem, nem por um instante, um arquivo nao conferido: o pendrive pode ser
# alterado em uso (o usuario shell grava nele) e um cor.sh do gancho de boot pode
# estar rodando ao mesmo tempo; ele ve a versao velha ou a nova, as duas conferidas.
# So os arquivos da lista sao copiados.
if ! preparar_trabalho; then
  LOG "[ERRO] pasta de trabalho recusada - abortando (nada foi alterado)."
  exit 1
fi
KIT_COPIA=$(kit_nomes | grep -v '^ZYCustom.ini$')
PREP="$WORK/preparo.$$"
# os executaveis do kit (os que existirem)
KIT_EXEC="cor.sh lvdsctl nl_camcheck nl_tela suite.sh suite-boot.sh suite-pedido.sh"
# subpastas (um nivel) dos nomes da lista: kit, fontes
kit_subpastas(){ echo "$1" | sed -n 's|/.*||p' | sort -u; }
copiar_preparo(){
  rm -rf "$PREP"
  ( umask 077; mkdir "$PREP" ) || return 1
  for _cn in $(kit_subpastas "$KIT_COPIA"); do ( umask 077; mkdir "$PREP/$_cn" ) || return 1; done
  for _cn in $KIT_COPIA; do cp "$MP/$_cn" "$PREP/$_cn" || return 1; done
  for _cn in $KIT_EXEC; do [ -f "$PREP/$_cn" ] && chmod 755 "$PREP/$_cn"; done
  return 0
}
por_no_lugar(){
  for _cn in $(kit_subpastas "$KIT_COPIA"); do
    rm -rf "${WORK:?}/$_cn" && mkdir "$WORK/$_cn" || return 1
  done
  for _cn in $KIT_COPIA; do mv -f "$PREP/$_cn" "$WORK/$_cn" || return 1; done
}
if ! copiar_preparo; then
  rm -rf "$PREP"
  LOG "[ERRO] nao consegui copiar o kit para $WORK - abortando (nada de /vendor foi alterado)."
  exit 1
fi
# shellcheck disable=SC2086  # lista de nomes sem espaco, divisao de proposito
if ! conferir_em "$PREP" $KIT_COPIA || ! por_no_lugar; then
  rm -rf "$PREP"
  LOG "[ERRO] a copia do kit em $WORK nao confere - abortando (nada de /vendor foi alterado)."
  exit 1
fi
rm -rf "$PREP"
# shellcheck disable=SC2086
if ! trabalho_conferir $KIT_COPIA; then
  LOG "[ERRO] a copia do kit em $WORK nao confere - abortando (nada de /vendor foi alterado)."
  exit 1
fi
COR_MD5=$(kit_md5_esperado cor.sh)

# ---- suite de verificacao (bloco 9B): arquivos ------------------------------------
# A suite roda como root a partir de $SUITE: mesmas regras da pasta de trabalho (so do
# root, 0700; arquivo regular do root com o md5 da lista). Copia a partir de $WORK (ja
# conferida), so o que tem md5 diferente, por uma pasta de preparo DENTRO de $SUITE,
# conferida la, e mv para o lugar; no fim confere tudo. Idempotente: 2a vez nada grava.
suite_nomes(){ kit_nomes | grep -v -e '^ZYCustom.ini$' -e '^pfl7560-suite.rc$' -e '^pfl7560.apk$' -e '^pfl7560-home.apk$' -e '^overlay/' -e '^marca/'; }
# a pasta e as subpastas dela (kit/, fontes/): um arquivo "regular" dentro de uma
# subpasta que e link passaria pelo arq_seguro
suite_dir_ok(){
  if dir_seguro "$SUITE"; then
    for _sd in $(kit_subpastas "$(suite_nomes)"); do
      if [ -e "$SUITE/$_sd" ] || [ -L "$SUITE/$_sd" ]; then
        dir_seguro "$SUITE/$_sd" || { LOG "[ERRO] $SUITE/$_sd nao e uma pasta so do root (link?) - suite NAO instalada."; return 1; }
      fi
    done
    return 0
  fi
  LOG "[ERRO] $SUITE nao e uma pasta so do root (link, dono errado ou aberta a outros) - suite NAO instalada."
  return 1
}
instalar_suite_arquivos(){
  if [ ! -e "$SUITE" ] && [ ! -L "$SUITE" ]; then
    mkdir -p "${SUITE%/*}" 2>/dev/null
    ( umask 077; mkdir "$SUITE" 2>/dev/null ) && chmod 700 "$SUITE" 2>/dev/null
  fi
  suite_dir_ok || return 1
  _ps="$SUITE/preparo.$$"
  rm -rf "$_ps"
  ( umask 077; mkdir "$_ps" ) || return 1
  _mud=""
  for _sn in $(suite_nomes); do
    if arq_seguro "$SUITE/$_sn" && [ "$(md5sum "$SUITE/$_sn" 2>/dev/null | cut -d' ' -f1)" = "$(kit_md5_esperado "$_sn")" ]; then
      continue
    fi
    case "$_sn" in */*) [ -d "$_ps/${_sn%/*}" ] || ( umask 077; mkdir "$_ps/${_sn%/*}" ) || { rm -rf "$_ps"; return 1; } ;; esac
    cp "$WORK/$_sn" "$_ps/$_sn" || { rm -rf "$_ps"; return 1; }
    _mud="$_mud $_sn"
  done
  if [ -n "$_mud" ]; then
    # shellcheck disable=SC2086  # lista de nomes sem espaco, divisao de proposito
    if ! conferir_em "$_ps" $_mud; then rm -rf "$_ps"; return 1; fi
    for _sn in $_mud; do
      case "$_sn" in */*) [ -d "$SUITE/${_sn%/*}" ] || ( umask 077; mkdir "$SUITE/${_sn%/*}" ) || { rm -rf "$_ps"; return 1; } ;; esac
      mv -f "$_ps/$_sn" "$SUITE/$_sn" || { rm -rf "$_ps"; return 1; }
    done
  fi
  rm -rf "$_ps"
  for _sn in $KIT_EXEC; do [ -f "$SUITE/$_sn" ] && chmod 755 "$SUITE/$_sn"; done
  # shellcheck disable=SC2046
  conferir_em "$SUITE" $(suite_nomes) || return 1
  if [ -n "$_mud" ]; then LOG "[OK] suite: arquivos atualizados em $SUITE:$_mud"; else LOG "suite: arquivos ja estavam em dia em $SUITE"; fi
  return 0
}
# servico de boot: o .rc igual ao do kit, 0644, do root e com o rotulo SELinux do
# init.bigfish.rc vizinho (ou vendor_configs_file se o ls -Z nao responder). O brick de
# julho veio de .rc 0664 e sem rotulo (fato 3 do bloco 9).
# shellcheck disable=SC2012  # o ls -Z e o unico leitor de rotulo SELinux do toybox
rotulo_de(){ ls -Z "$1" 2>/dev/null | tr ' ' '\n' | grep '^u:object_r:[a-z0-9_]*:s0$' | head -1; }
rotulo_alvo(){ _ra=$(rotulo_de "$RC"); if [ -n "$_ra" ]; then echo "$_ra"; else echo "$ROTULO_PADRAO"; fi; }
# $1 e o .rc do kit: regular (nao link), igual ao conferido, 0644, do root e com o
# rotulo alvo (quando o ls -Z responde)
rc_conforme(){
  _rcf="$1"
  [ -f "$_rcf" ] && [ ! -L "$_rcf" ] && cmp -s "$WORK/pfl7560-suite.rc" "$_rcf" || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ln "$_rcf" 2>/dev/null)
  case "$1" in -rw-r--r--|-rw-r--r--[.+]) ;; *) return 1 ;; esac
  [ "$3" = "$DONO_UID" ] || return 1
  _rl=$(rotulo_de "$_rcf")
  [ -z "$_rl" ] || [ "$_rl" = "$(rotulo_alvo)" ]
}
suite_rc_ok(){ rc_conforme "$RC_SUITE"; }
# so com o /vendor ja aberto rw (dentro do bloco dos fixes). O .new so entra na pasta
# do init se ja estiver conforme (modo, dono, rotulo); um .rc que mesmo assim fique
# fora do padrao depois do mv e removido: nunca fica um .rc nosso fora do padrao la.
instalar_rc(){
  trabalho_conferir pfl7560-suite.rc || return 1
  _alvo=$(rotulo_alvo)
  rm -f "$RC_SUITE_NOVO"
  if cp "$WORK/pfl7560-suite.rc" "$RC_SUITE_NOVO" && chmod 644 "$RC_SUITE_NOVO" \
     && chown root:root "$RC_SUITE_NOVO" && cmp -s "$WORK/pfl7560-suite.rc" "$RC_SUITE_NOVO"; then
    chcon "$_alvo" "$RC_SUITE_NOVO" 2>/dev/null || LOG "[AVISO] chcon $_alvo falhou no .rc da suite."
    if ! rc_conforme "$RC_SUITE_NOVO"; then
      LOG "[ERRO] suite: o .rc preparado ficou fora do padrao (modo, dono ou rotulo '$(rotulo_de "$RC_SUITE_NOVO")', pedido $_alvo) - NAO instalado."
    elif mv -f "$RC_SUITE_NOVO" "$RC_SUITE" && suite_rc_ok; then
      _rf=$(rotulo_de "$RC_SUITE"); [ -n "$_rf" ] || _rf="(ls -Z nao respondeu; pedido $_alvo)"
      LOG "[OK] suite: servico de boot instalado em $RC_SUITE (0644 root:root, rotulo $_rf); vale no proximo boot"
      return 0
    elif [ -e "$RC_SUITE" ] || [ -L "$RC_SUITE" ]; then
      rm -f "$RC_SUITE"
      LOG "[ERRO] suite: o .rc instalado nao conferiu (modo, dono ou rotulo) - removido."
    fi
  fi
  rm -f "$RC_SUITE_NOVO"
  LOG "[ERRO] suite: nao consegui instalar o servico de boot $RC_SUITE."
  return 1
}
suite_pronta(){ suite_dir_ok && conferir_em "$SUITE" suite.sh; }

# ---- app "PFL7560" (bloco 9C) ---------------------------------------------------------
# O pm install deste firmware recusa QUALQUER app de fora (INSTALL_FAILED_INVALID_INSTALL_LOCATION,
# visto no aparelho em 2026-10-30, com /data/app vazio). O app entra como app do sistema em
# /vendor/app/PFL7560/ (o PackageManager varre o /vendor/app no boot, como faz com o
# KeymasterProvisionDemo de fabrica): 0755/0644, root, rotulo vendor_app_file, dentro da
# MESMA janela rw do /vendor do .rc da suite. Vale no proximo boot. O APK vem de $WORK (ja
# conferido pelo md5 da lista), nunca do pendrive.
# Dois apps do kit, cada um em /vendor/app/<Pasta>/<Pasta>.apk: o "PFL7560" (Verificar
# projetor e Wi-Fi, bloco 9C) e a home nova "PFL7560Home" (bloco 10A). Bloco 14: as
# sobreposicoes de tema entram do mesmo jeito em /vendor/overlay/<Pasta>/<Pasta>.apk (rotulo
# vendor_overlay_file); o $3 e a pasta de /vendor ("app", o padrao, ou "overlay") e o $4 o rotulo.
ROTULO_APP="u:object_r:vendor_app_file:s0"
ROTULO_OVERLAY="u:object_r:vendor_overlay_file:s0"
# $1 = nome no kit (pfl7560.apk), $2 = pasta em /vendor/app (PFL7560) [$3 = app|overlay, $4 = rotulo]
app_conforme(){
  _ab="${3:-app}"; _ar="${4:-$ROTULO_APP}"
  _ad="$R/vendor/$_ab/$2"; _aa="$_ad/$2.apk"
  [ -d "$_ad" ] && [ ! -L "$_ad" ] || return 1
  [ -f "$_aa" ] && [ ! -L "$_aa" ] && cmp -s "$WORK/$1" "$_aa" || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ln "$_aa" 2>/dev/null)
  case "$1" in -rw-r--r--|-rw-r--r--[.+]) ;; *) return 1 ;; esac
  [ "$3" = "$DONO_UID" ] || return 1
  _al=$(rotulo_de "$_aa")
  [ -z "$_al" ] || [ "$_al" = "$_ar" ]
}
# so com o /vendor ja aberto rw. Falha so avisa (devolve !=0): o resto do kit segue.
# $1 = nome no kit, $2 = pasta em /vendor/app [$3 = app|overlay, $4 = rotulo]
instalar_app(){
  _ab="${3:-app}"; _ar="${4:-$ROTULO_APP}"
  _ad="$R/vendor/$_ab/$2"; _aa="$_ad/$2.apk"; _an="$R/vendor/$_ab/.$2.apk.new"
  _at=app; _adesc="app do sistema"
  if [ "$_ab" = "overlay" ]; then _at=overlay; _adesc="sobreposicao do sistema"; fi
  if ! trabalho_ok || ! trabalho_conferir "$1"; then
    LOG "[AVISO] $_at: $1 em $WORK nao confere - NAO foi instalado (o resto do kit segue)."
    return 1
  fi
  # a pasta-mae (/vendor/overlay) vem no firmware; se faltar, nasce como as outras
  if [ ! -d "$R/vendor/$_ab" ]; then
    { mkdir -p "$R/vendor/$_ab" && chmod 755 "$R/vendor/$_ab" && chown root:root "$R/vendor/$_ab"; } 2>/dev/null
    chcon "$_ar" "$R/vendor/$_ab" 2>/dev/null
  fi
  # um link no lugar da pasta e apagado, nunca seguido
  [ -L "$_ad" ] && rm -f "$_ad"
  if ! { mkdir -p "$_ad" && chmod 755 "$_ad" && chown root:root "$_ad"; }; then
    LOG "[AVISO] $_at: nao consegui preparar $_ad - NAO foi instalado (o resto do kit segue)."
    return 1
  fi
  chcon "$_ar" "$_ad" 2>/dev/null || LOG "[AVISO] chcon $_ar falhou na pasta de $_at."
  rm -f "$_an"
  if cp "$WORK/$1" "$_an" && chmod 644 "$_an" && chown root:root "$_an" && cmp -s "$WORK/$1" "$_an"; then
    chcon "$_ar" "$_an" 2>/dev/null || LOG "[AVISO] chcon $_ar falhou no apk."
    if mv -f "$_an" "$_aa" && app_conforme "$1" "$2" "$_ab" "$_ar"; then
      _alf=$(rotulo_de "$_aa"); [ -n "$_alf" ] || _alf="(ls -Z nao respondeu; pedido $_ar)"
      LOG "[OK] $_at: $1 instalado como $_adesc em ${_ad#"$R"} (0644 root, rotulo $_alf). Vale depois do PROXIMO boot."
      return 0
    fi
    rm -f "$_aa"
  fi
  rm -f "$_an"
  LOG "[AVISO] $_at: nao consegui gravar o apk em $_ad - NAO foi instalado (o resto do kit segue)."
  return 1
}
# os apps do kit: "nome-no-kit:Pasta"
KIT_APPS="pfl7560.apk:PFL7560 pfl7560-home.apk:PFL7560Home"
# as sobreposicoes de tema (bloco 14), "nome-no-kit:Pasta", com a do android SEMPRE por ultimo (ela
# entra em todo processo: so depois das dos apps). A lista sai de artifacts/overlay/apk/ pelo
# tests/atualizar-md5-kit.sh; NAO editar a mao.
# KIT_OVERLAYS_INICIO
KIT_OVERLAYS="overlay/PFL7560TemaAutoFocus.apk:PFL7560TemaAutoFocus
overlay/PFL7560TemaHiGallery.apk:PFL7560TemaHiGallery
overlay/PFL7560TemaHiMusic.apk:PFL7560TemaHiMusic
overlay/PFL7560TemaHiPinyinIME.apk:PFL7560TemaHiPinyinIME
overlay/PFL7560TemaHiTvSetting.apk:PFL7560TemaHiTvSetting
overlay/PFL7560TemaHiVideoPlayer.apk:PFL7560TemaHiVideoPlayer
overlay/PFL7560TemaIjkPlayer.apk:PFL7560TemaIjkPlayer
overlay/PFL7560TemaNLHotkeyService.apk:PFL7560TemaNLHotkeyService
overlay/PFL7560TemaNLProvision.apk:PFL7560TemaNLProvision
overlay/PFL7560TemaNLSource.apk:PFL7560TemaNLSource
overlay/PFL7560TemaNewLinkService.apk:PFL7560TemaNewLinkService
overlay/PFL7560TemaPackageInstaller.apk:PFL7560TemaPackageInstaller
overlay/PFL7560TemaPowerService.apk:PFL7560TemaPowerService
overlay/PFL7560TemaTvSettings.apk:PFL7560TemaTvSettings
overlay/PFL7560TemaZYBluetooth.apk:PFL7560TemaZYBluetooth
overlay/PFL7560TemaZYCustomUI.apk:PFL7560TemaZYCustomUI
overlay/PFL7560TemaZYFileManager.apk:PFL7560TemaZYFileManager
overlay/PFL7560TemaZYSetting.apk:PFL7560TemaZYSetting
overlay/PFL7560TemaZYSpeakerModel.apk:PFL7560TemaZYSpeakerModel
overlay/PFL7560TemaAndroid.apk:PFL7560TemaAndroid
"
# KIT_OVERLAYS_FIM
# Home nova (bloco 10A): o HOME do sistema e o assistente com.newlink.nlprovision (prioridade
# 29 no filtro HOME: o set-home-activity NAO vence, visto no aparelho em 2026-10-31). Ele roda o
# trabalho de boot e repassa a HOME ao pacote da prop vendor.newlink.launcher.package (doc 45
# s4). A linha vai no /vendor/build.prop SO com a home instalada e conferida (nunca repassar
# para um app ausente); o desinstalar da suite a tira.
HOME_LINHA="vendor.newlink.launcher.package=com.pfl7560.home"
home_prop_ok(){ grep -qx "$HOME_LINHA" "$BP" 2>/dev/null; }
gravar_home_prop(){
  if ! app_conforme pfl7560-home.apk PFL7560Home; then
    LOG "[AVISO] home: a home nao esta instalada e conferida - a tela inicial continua a de fabrica."
    return 1
  fi
  if cp "$BP" "$BP.new" && sed -i '/^vendor\.newlink\.launcher\.package=/d' "$BP.new" \
     && echo "$HOME_LINHA" >> "$BP.new" && grep -qx "$HOME_LINHA" "$BP.new" && mv "$BP.new" "$BP"; then
    LOG "[OK] home: $HOME_LINHA em ${BP#"$R"} (vale no proximo boot; volta tirando a linha ou com DESINSTALAR-SUITE.txt)"
    return 0
  fi
  rm -f "$BP.new"
  LOG "[AVISO] home: nao consegui gravar a prop da home em $BP - a tela inicial continua a de fabrica."
  return 1
}

# Gerenciador de arquivos abrindo direto na lista (bloco 14): a prop vendor.nl.filemanage_file=1 no
# /vendor/build.prop, como a da home. O desinstalar da suite a tira.
FM_LINHA="vendor.nl.filemanage_file=1"
fm_prop_ok(){ grep -qx "$FM_LINHA" "$BP" 2>/dev/null; }
gravar_fm_prop(){
  if cp "$BP" "$BP.new" && sed -i '/^vendor\.nl\.filemanage_file=/d' "$BP.new" \
     && echo "$FM_LINHA" >> "$BP.new" && grep -qx "$FM_LINHA" "$BP.new" && mv "$BP.new" "$BP"; then
    LOG "[OK] gerenciador: $FM_LINHA em ${BP#"$R"} (vale no proximo boot; volta com DESINSTALAR-SUITE.txt)"
    return 0
  fi
  rm -f "$BP.new"
  LOG "[AVISO] gerenciador: nao consegui gravar a prop em $BP - o gerenciador continua na pagina inicial de fabrica."
  return 1
}

# Marca MeowCast (bloco 14): o logo e a animacao de boot em /atv/bootvideo. O arquivo de fabrica
# e sobrescrito com cat (preserva dono e rotulo SELinux), depois de guardada UMA vez uma copia
# dele em $SUITE/marca-original; o suite.sh --desinstalar restaura. A imagem da particao
# "logo" (a do carregador) NAO vem por aqui: depende dos cantos de cada aparelho (pfl7560-marca.sh).
MARCA_DESTINO="$R/atv/bootvideo"
MARCA_BACKUP="$SUITE/marca-original"
KIT_MARCA="marca/logo.jpg:logo.jpg marca/bootanimation.zip:bootanimation.zip"
marca_ok(){ [ -f "$MARCA_DESTINO/$2" ] && [ ! -L "$MARCA_DESTINO/$2" ] && cmp -s "$WORK/$1" "$MARCA_DESTINO/$2"; }
# $1 = nome no kit, $2 = arquivo em /atv/bootvideo. Falha so avisa (devolve !=0).
gravar_marca(){
  _md="$MARCA_DESTINO/$2"; _mb="$MARCA_BACKUP/$2"
  if ! trabalho_ok || ! trabalho_conferir "$1"; then
    LOG "[AVISO] marca: $1 em $WORK nao confere - a marca NAO foi gravada (o resto do kit segue)."
    return 1
  fi
  if [ ! -f "$_md" ] || [ -L "$_md" ]; then
    LOG "[AVISO] marca: $_md nao existe como arquivo (ou e link) - nada gravado (o cat criaria um arquivo sem o dono e o rotulo do original)."
    return 1
  fi
  # o original, uma vez so (a 1a vez que o arquivo difere do nosso)
  if [ ! -e "$_mb" ]; then
    if [ ! -e "$MARCA_BACKUP" ] && [ ! -L "$MARCA_BACKUP" ]; then ( umask 077; mkdir "$MARCA_BACKUP" ) 2>/dev/null && chmod 700 "$MARCA_BACKUP"; fi
    if ! dir_seguro "$MARCA_BACKUP" || ! { cp "$_md" "$_mb.new" && chmod 600 "$_mb.new" && cmp -s "$_md" "$_mb.new" && mv -f "$_mb.new" "$_mb"; }; then
      rm -f "$_mb.new"
      LOG "[AVISO] marca: nao consegui guardar o original de $2 em $MARCA_BACKUP - a marca NAO foi gravada."
      return 1
    fi
    LOG "marca: original de $2 guardado em ${MARCA_BACKUP#"$R"}"
  fi
  cat "$WORK/$1" > "$_md" 2>/dev/null
  if [ "$(md5sum "$_md" 2>/dev/null | cut -d' ' -f1)" = "$(kit_md5_esperado "$1")" ]; then
    LOG "[OK] marca: $2 gravado em ${MARCA_DESTINO#"$R"} e conferido por md5 (vale no proximo boot)"
    return 0
  fi
  cat "$_mb" > "$_md" 2>/dev/null
  LOG "[AVISO] marca: $2 nao conferiu depois de gravar - voltei o original (cmp com o backup: $(cmp -s "$_mb" "$_md" && echo igual || echo DIFERENTE))."
  return 1
}

SUITE_INSTALAR=1
if [ -e "$MP/DESINSTALAR-SUITE.txt" ]; then SUITE_INSTALAR=0; fi
SUITE_OK=0
if [ "$SUITE_INSTALAR" = "1" ]; then
  if instalar_suite_arquivos; then
    SUITE_OK=1
  else
    LOG "[ERRO] suite NAO instalada: o kit roda so a fase de cor, como antes."
  fi
fi
# o app entra na janela rw do /vendor, abaixo (antes de lancar a suite e do reboot da fase
# termica). So com a suite instalada: o app so serve a ela.
APP_PEND=0
if [ "$SUITE_OK" = "1" ]; then
  for _ka in $KIT_APPS; do app_conforme "${_ka%%:*}" "${_ka#*:}" || APP_PEND=1; done
  for _ko in $KIT_OVERLAYS; do app_conforme "${_ko%%:*}" "${_ko#*:}" overlay "$ROTULO_OVERLAY" || APP_PEND=1; done
  home_prop_ok || APP_PEND=1
  fm_prop_ok || APP_PEND=1
fi

# ---- estados-alvo (idempotencia) ---------------------------------------------
# termico: o ini em uso tem de ser IDENTICO ao corrigido (md5). Um .ini anterior
# a escada tem o mux mas nao a escada e antes passava como aplicado.
ini_md5(){ md5sum "$INI" 2>/dev/null | cut -d' ' -f1; }
term_ok(){ _m=$(ini_md5); [ -n "$_m" ] && { [ "$_m" = "$INI_MD5_OK" ] || [ "$_m" = "$INI_MD5_OK_NOTYPEC" ]; }; }
# md5 que o .ini corrigido TEM de ter, dado o md5 do .ini do aparelho; vazio =
# aparelho desconhecido (nao e aplicavel)
term_alvo_de(){
  [ -n "$1" ] || return 0
  [ "$1" = "$INI_MD5_FABRICA_NOTYPEC" ] && { echo "$INI_MD5_OK_NOTYPEC"; return 0; }
  [ "$1" = "$INI_MD5_FABRICA" ] && { echo "$INI_MD5_OK"; return 0; }
  for _a in $INI_MD5_ANTERIORES; do
    [ "$1" = "$_a" ] && { echo "$INI_MD5_OK"; return 0; }
  done
  return 0
}

# ---- .ini por secoes ---------------------------------------------------------
# Monta o .ini corrigido a partir do .ini DO APARELHO ($1) e do corrigido do
# pendrive ($2): as secoes de TERM_SECOES vem do $2, tudo o mais (o cabecalho antes
# da 1a secao, o CONFIG_MODEL, as demais secoes) fica byte a byte como no $1.
# So grep/sed/head/tail/tr (nada de awk) e cortes por numero de linha, que nao
# mexem nos bytes (o arquivo mistura ASCII, chines GBK e mojibake). O chamador
# confere o md5 do resultado contra o esperado: se o shell do aparelho se
# comportar diferente, o resultado nao confere e nada e gravado.
# "linha nome" de cada secao [nome] do arquivo $1
ini_secoes(){ grep -a -n '^\[' "$1" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\):\[\([^]]*\)\].*$/\1 \2/p'; }
# "ini fim" (linhas) da secao $2 do arquivo $1; !=0 se nao existe ou se repete
ini_faixa(){
  _ftot=$(grep -a -c '' "$1" 2>/dev/null)
  [ "$(ini_secoes "$1" | grep -c " $2\$")" = 1 ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- "$_ftot" "$2" $(ini_secoes "$1" | grep -A1 " $2\$" | tr '\n' ' ')
  [ "$4" = "$2" ] || return 1
  if [ -n "${5:-}" ]; then echo "$3 $(($5-1))"; else echo "$3 $1"; fi
}
# acrescenta a $INI_S a secao $1 (linhas $2 a $3 do $INI_A, ou a do $INI_B se termica)
ini_emite(){
  case " $TERM_SECOES " in
    *" $1 "*)
      # shellcheck disable=SC2046
      set -- $(ini_faixa "$INI_B" "$1")
      [ "$#" = 2 ] || return 1
      head -n "$2" "$INI_B" | tail -n "+$1" >> "$INI_S" ;;
    *) head -n "$3" "$INI_A" | tail -n "+$2" >> "$INI_S" ;;
  esac
}
ini_compor(){
  INI_A="$1"; INI_B="$2"; INI_S="$3"
  _ctot=$(grep -a -c '' "$INI_A" 2>/dev/null)
  ini_secoes "$INI_A" > "$INI_S.lista" || return 1
  _cprim=$(sed -n '1s/ .*//p' "$INI_S.lista")
  [ -n "$_cprim" ] && [ -n "$_ctot" ] || return 1
  : > "$INI_S" || return 1
  if [ "$_cprim" -gt 1 ]; then head -n "$((_cprim-1))" "$INI_A" >> "$INI_S" || return 1; fi
  _cini=""; _cnome=""
  while read -r _cl _cn; do
    if [ -n "$_cnome" ]; then ini_emite "$_cnome" "$_cini" "$((_cl-1))" || return 1; fi
    _cini="$_cl"; _cnome="$_cn"
  done < "$INI_S.lista"
  ini_emite "$_cnome" "$_cini" "$_ctot" || return 1
  rm -f "$INI_S.lista"
}
# monta em $WORK/ini.composto o .ini corrigido do aparelho e confere o md5 ($1 =
# esperado; $2 = md5 do .ini do aparelho). Sem o esperado igual, apaga e devolve !=0.
#  - de fabrica (qualquer dos dois modelos): so as secoes termicas, o resto do .ini do
#    aparelho fica como esta (o CONFIG_MODEL de cada modelo e preservado);
#  - versao anterior NOSSA: e um .ini do modelo com USB-C que ja foi corrigido uma vez
#    e que difere do atual ate fora das secoes termicas (espacos de fim de linha), entao
#    troca-se o arquivo inteiro, como sempre foi (o resultado e o mesmo md5 de antes).
term_compor(){
  rm -f "$WORK/ini.composto" "$WORK/ini.composto.lista"
  _anterior=0
  for _a in $INI_MD5_ANTERIORES; do [ "$2" = "$_a" ] && _anterior=1; done
  if [ "$_anterior" = 1 ]; then
    cp "$MP/ZYCustom.ini" "$WORK/ini.composto" 2>/dev/null || _anterior=erro
  else
    ini_compor "$INI" "$MP/ZYCustom.ini" "$WORK/ini.composto" || _anterior=erro
  fi
  if [ "$_anterior" != erro ] && [ "$(md5sum "$WORK/ini.composto" 2>/dev/null | cut -d' ' -f1)" = "$1" ]; then
    return 0
  fi
  rm -f "$WORK/ini.composto" "$WORK/ini.composto.lista"
  return 1
}
wifi_ok(){ [ -f "$BP" ] && grep -q "wifi_disconnect_on_boot=0" "$BP" 2>/dev/null; }
xiri_ok(){ grep -A1 "service xiriservice" "$RC" 2>/dev/null | grep -q "disabled"; }

CHG=0
FAIL=0
AVISO=0   # 1 = a fase termica nao ficou efetiva; a tela final sera ERRO

# /atv/ini/ZYCustom*.ini tem precedencia sobre o /vendor (doc 06): se existir,
# o ini do /vendor nao vale e o kit avisa em vez de dizer que deu certo.
for _f in "$ATV_INI_DIR"/ZYCustom*.ini; do
  if [ -f "$_f" ]; then
    LOG "[AVISO] termico: existe $_f e ele TEM PRECEDENCIA sobre $INI - a correcao termica do /vendor NAO esta valendo. Remova esse arquivo (ver docs/research/06)."
    AVISO=1
  fi
done

TERM_ACAO=0
if term_ok; then
  LOG "termico ja estava ok (md5 do ZYCustom.ini = corrigido)"
else
  TERM_MD5_ATUAL=$(ini_md5)
  TERM_ALVO=$(term_alvo_de "$TERM_MD5_ATUAL")
  if [ -z "$TERM_ALVO" ]; then
    LOG "[ERRO] termico: md5 do ZYCustom.ini em uso ('$(ini_md5)') nao e o de fabrica (V1.0.0.9 $INI_MD5_FABRICA; V1.0.0.1 $INI_MD5_FABRICA_NOTYPEC) nem o de uma versao anterior nossa - NAO vou sobrescrever (firmware diferente?)."
    FAIL=$((FAIL+1))
    AVISO=1
  elif ! term_compor "$TERM_ALVO" "$TERM_MD5_ATUAL"; then
    LOG "[ERRO] termico: nao consegui montar o ZYCustom.ini corrigido a partir do do aparelho (o resultado nao tem o md5 esperado $TERM_ALVO) - NAO vou gravar."
    FAIL=$((FAIL+1))
    AVISO=1
  else
    TERM_ACAO=1
  fi
fi

# O /vendor so e aberto rw se algum dos 3 fixes DE /vendor (ou o .rc da suite) estiver pendente.
# Se so o .rc da suite estiver pendente e o remount falhar, o kit segue sem ele (a suite
# roda pelo pendrive; o servico de boot fica para a proxima vez): o .rc nunca impede a cor.
VENDOR_RW=0
SUITE_RC_PEND=0
if [ "$SUITE_OK" = "1" ] && ! suite_rc_ok; then SUITE_RC_PEND=1; fi
if [ "$TERM_ACAO" = "1" ] || ! wifi_ok || ! xiri_ok; then
  LOG "correcao ausente/incompleta -> aplicando o que faltar no /vendor ..."
  if ! mount -o rw,remount /vendor; then
    LOG "[ERRO] nao consegui remontar /vendor rw (dm-verity/particao ocupada?) - retentar no proximo boot."
    exit 1
  fi
  VENDOR_RW=1
elif [ "$SUITE_RC_PEND" = "1" ] || [ "$APP_PEND" = "1" ]; then
  LOG "servico de boot ou app da suite ausente/diferente -> abrindo o /vendor so para eles ..."
  if mount -o rw,remount /vendor; then
    VENDOR_RW=1
  else
    LOG "[ERRO] nao consegui remontar /vendor rw: servico de boot e app da suite NAO instalados (o resto do kit segue; retentar no proximo boot)."
  fi
fi

# ---- FIX 1: termico (secoes termicas sobre o .ini do aparelho) ----
if [ "$TERM_ACAO" = "1" ]; then
  # salva o stock UMA vez, antes de sobrescrever, e so se o atual for o de fabrica
  # (de qualquer um dos dois modelos)
  if [ ! -f "$INI.STOCK" ] && { [ "$(ini_md5)" = "$INI_MD5_FABRICA" ] || [ "$(ini_md5)" = "$INI_MD5_FABRICA_NOTYPEC" ]; }; then
    cp "$INI" "$INI.STOCK" || LOG "[AVISO] nao consegui salvar $INI.STOCK"
  fi
  # escrita atomica: .new + validacao por md5 + mv + releitura por md5
  if cp "$WORK/ini.composto" "$INI.new" && chmod 644 "$INI.new" \
     && [ "$(md5sum "$INI.new" 2>/dev/null | cut -d' ' -f1)" = "$TERM_ALVO" ]; then
    if mv "$INI.new" "$INI" && term_ok; then
      LOG "[OK] termico: ZYCustom.ini gravado e conferido por md5 (fans 100% sempre, 2o sensor, escada de brilho 1000->850 entre 66C e 70C, shutdown 75C)"
      CHG=1
    else
      LOG "[ERRO] termico: falha no mv final ou a releitura nao confere."
      rm -f "$INI.new"
      FAIL=$((FAIL+1))
      AVISO=1
    fi
  else
    LOG "[ERRO] termico: o .new copiado nao tem o md5 esperado - NAO vou reiniciar."
    rm -f "$INI.new"
    FAIL=$((FAIL+1))
    AVISO=1
  fi
  rm -f "$WORK/ini.composto"
fi

# ---- FIX 2: wi-fi reconecta sozinho apos boot ----
if wifi_ok; then
  LOG "wi-fi ja estava ok (wifi_disconnect_on_boot=0 presente)"
else
  if [ ! -f "$BP.STOCK" ]; then
    cp "$BP" "$BP.STOCK" || LOG "[AVISO] nao consegui salvar $BP.STOCK"
  fi
  if cp "$BP" "$BP.new" && sed -i "s/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/" "$BP.new" \
     && grep -q "wifi_disconnect_on_boot=0" "$BP.new" && mv "$BP.new" "$BP"; then
    LOG "[OK] wi-fi: wifi_disconnect_on_boot=0"
    CHG=1
  else
    LOG "[ERRO] wi-fi: falha ao editar wifi_disconnect_on_boot em $BP"
    rm -f "$BP.new"
    FAIL=$((FAIL+1))
  fi
fi

# ---- FIX 3: silencia o spam do xiriservice ----
if xiri_ok; then
  LOG "xiri ja estava desabilitado"
else
  # BOOT-CRITICO: nunca sed -i no arquivo vivo; edita .new e so entao mv
  if [ ! -f "$RC.STOCK" ]; then
    cp "$RC" "$RC.STOCK" || LOG "[AVISO] nao consegui salvar $RC.STOCK"
  fi
  if cp "$RC" "$RC.new" \
     && sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$RC.new" \
     && grep -A1 "service xiriservice" "$RC.new" | grep -q "disabled" \
     && mv "$RC.new" "$RC"; then
    LOG "[OK] xiri: xiriservice desabilitado (fim do spam de log)"
    CHG=1
  else
    LOG "[ERRO] xiri: falha ao desabilitar xiriservice em $RC"
    rm -f "$RC.new"
    FAIL=$((FAIL+1))
  fi
fi

# ---- servico de boot da suite (nao exige reboot: vale no proximo boot) ----
if [ "$SUITE_OK" = "1" ]; then
  if [ "$SUITE_RC_PEND" = "0" ]; then
    LOG "suite: servico de boot ja estava instalado"
  elif [ "$VENDOR_RW" = "1" ]; then
    instalar_rc
  fi
  for _ka in $KIT_APPS; do
    if app_conforme "${_ka%%:*}" "${_ka#*:}"; then
      LOG "app: ${_ka%%:*} ja estava em /vendor/app/${_ka#*:} (igual ao do kit)"
    elif [ "$VENDOR_RW" = "1" ]; then
      instalar_app "${_ka%%:*}" "${_ka#*:}"
    fi
  done
  for _ko in $KIT_OVERLAYS; do
    if app_conforme "${_ko%%:*}" "${_ko#*:}" overlay "$ROTULO_OVERLAY"; then
      LOG "overlay: ${_ko%%:*} ja estava em /vendor/overlay/${_ko#*:} (igual ao do kit)"
    elif [ "$VENDOR_RW" = "1" ]; then
      instalar_app "${_ko%%:*}" "${_ko#*:}" overlay "$ROTULO_OVERLAY"
    fi
  done
  if home_prop_ok; then
    LOG "home: a prop da home ja estava no build.prop"
  elif [ "$VENDOR_RW" = "1" ]; then
    gravar_home_prop
  fi
  if fm_prop_ok; then
    LOG "gerenciador: a prop do gerenciador ja estava no build.prop"
  elif [ "$VENDOR_RW" = "1" ]; then
    gravar_fm_prop
  fi
  # a marca nao e do /vendor: nao precisa da janela rw, so da suite instalada (o backup mora nela)
  for _km in $KIT_MARCA; do
    if marca_ok "${_km%%:*}" "${_km#*:}"; then
      LOG "marca: ${_km#*:} ja estava igual ao do kit"
    else
      gravar_marca "${_km%%:*}" "${_km#*:}"
    fi
  done
fi

sync
# fecha o /vendor em TODOS os ramos, inclusive no de reboot - antes ele ficava
# gravavel durante os 8 s de sleep.
if [ "$VENDOR_RW" = "1" ]; then
  mount -o ro,remount /vendor 2>/dev/null
fi

# ---- desinstalar a suite (DESINSTALAR-SUITE.txt na raiz do pendrive) ----
if [ "$SUITE_INSTALAR" = "0" ]; then
  LOG "DESINSTALAR-SUITE.txt no pendrive: removendo a suite (servico, pasta, pedido e vigia)"
  if trabalho_ok && trabalho_conferir suite.sh; then
    sh "$WORK/suite.sh" --desinstalar "$MP"
  else
    LOG "[ERRO] suite.sh nao conferiu na hora de executar - a suite NAO foi removida."
  fi
fi

if [ "$CHG" = "1" ] && [ "$FAIL" = "0" ]; then
  LOG "==== CORRECAO APLICADA COM SUCESSO! reiniciando em 8s para ativar ===="
  # a fase de cor roda no boot seguinte, com o pendrive ainda plugado. A tela e so
  # cosmetica: se o cor.sh nao conferir na hora, nao executa e o reboot segue.
  if cor_pronto; then
    sh "$WORK/cor.sh" --tela reiniciando
  else
    LOG "[ERRO] cor.sh nao conferiu na hora de executar - tela de reinicio dispensada (a correcao ja foi aplicada)."
  fi
  sleep "$ESPERA_REBOOT"
  reboot
  exit 0
fi
if [ "$FAIL" != "0" ]; then
  LOG "==== [PARCIAL] $FAIL fix(es) falharam - reexecute o pendrive (reinicie o projetor). ===="
  AVISO=1
else
  LOG "==== fixes de /vendor ja estavam ok; nada a reiniciar. ===="
fi

# ---- SUITE ou FASE DE COR (destacada do exec do init) --------------------------
# PREMISSA NAO CONFIRMADA (doc 41): o init processa o 'exec' de forma bloqueante
# (inferido do AOSP), entao a pergunta de ate ~90 s nao pode rodar aqui dentro;
# lancamos a suite (ou o cor.sh) destacada (setsid, ou nohup se nao houver) com log
# proprio, que ela copia para o pendrive no fim. E o unico ponto que depende disso.
# Segunda premissa, do mesmo ponto: ao fim do exec o init NAO mata o grupo de
# processos do servico temporario (oneshot) e o processo destacado sobrevive. Se
# matar, a fase de cor morre no inicio: sem journal ainda, nada foi escrito.
if [ "$AVISO" = "1" ]; then AVISO_ARG="termica-falhou"; else AVISO_ARG=""; fi
# O cor.sh recebe o md5 que a lista embutida manda (COR_MD5): e o que o gancho de
# boot dele vai embutir. A conferencia abaixo vale para os dois caminhos: com o cor.sh
# da pasta de trabalho divergente, algo mexe numa pasta so do root e nada e lancado.
if ! cor_pronto; then
  LOG "[ERRO] cor.sh nao conferiu na hora de executar - a fase de cor NAO foi lancada (nada foi escrito na panelparam)."
  exit 1
fi
# a suite (bloco 9B) faz a cor (cor.sh no modo suite) e o resto; e a ULTIMA conferencia
# antes de executar o suite.sh
if [ "$SUITE_OK" = "1" ] && suite_pronta; then
  LOG "lancando a suite (suite.sh pendrive) destacada; log em $SUITE/ultimo.log e, no fim, newlink_suite.log e newlink_cor.log no pendrive"
  if command -v setsid >/dev/null 2>&1; then
    setsid sh "$SUITE/suite.sh" pendrive "$MP" "$AVISO_ARG" >>"$SUITE/lancador.log" 2>&1 </dev/null &
  else
    nohup sh "$SUITE/suite.sh" pendrive "$MP" "$AVISO_ARG" >>"$SUITE/lancador.log" 2>&1 </dev/null &
  fi
  exit 0
fi
[ "$SUITE_INSTALAR" = "1" ] && LOG "[AVISO] a suite nao esta pronta: lancando so a fase de cor."
LOG "lancando a fase de cor (cor.sh) destacada; log em $WORK/cor.log e, no fim, newlink_cor.log no pendrive"
if command -v setsid >/dev/null 2>&1; then
  setsid sh "$WORK/cor.sh" "$MP" "$AVISO_ARG" "$COR_MD5" >>"$WORK/cor.log" 2>&1 </dev/null &
else
  nohup sh "$WORK/cor.sh" "$MP" "$AVISO_ARG" "$COR_MD5" >>"$WORK/cor.log" 2>&1 </dev/null &
fi
exit 0
