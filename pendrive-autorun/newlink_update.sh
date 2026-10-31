#!/vendor/bin/sh

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
SUITE="$R/data/vendor/pfl7560-suite"
RC_SUITE="$R/vendor/etc/init/pfl7560-suite.rc"
RC_SUITE_NOVO="$R/vendor/etc/pfl7560-suite.rc.new"
ROTULO_PADRAO="u:object_r:vendor_configs_file:s0"
# shellcheck disable=SC2034
APP_PKG="com.pfl7560.verificar"
# shellcheck disable=SC2034
APP_VERSION_CODE="5"
ESPERA_REBOOT=8
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
[ -n "${PFL_RAPIDO:-}" ] && ESPERA_REBOOT=0

INI_MD5_OK="252ab7a72a007a8b79b3fc86bd5c0d19"
INI_MD5_OK_NOTYPEC="bdf5c4640596d1b2f2fb7f62fbadd6e3"
INI_MD5_FABRICA="29d8ba36149413e899563029df078f6d"
INI_MD5_FABRICA_NOTYPEC="ed3f314ca89698cb057a74ef64dca38e"
INI_MD5_ANTERIORES="bbf82dd17d4523b7df8a86bec0e850ce 1ad641ed2dd99e61d8a987a675e9aced 5868d67fd8d47564842494aa8f14c37c"
TERM_SECOES="Thermal BacklightPolicy ThermalPolicy Thermistor_0 Thermistor_1 CoolingFan_0 CoolingFan_1"

# KIT_LISTA_INICIO
KIT_LISTA="252ab7a72a007a8b79b3fc86bd5c0d19  ZYCustom.ini
0dbcf2861f96e24e728342732ce54340  cor.sh
178d812872cb9306c0ae6faeed07184a  lvdsctl
02bedd31ae0e82afd10c41daabf2bd56  nl_camcheck
662acb7ac307699a389e892047f0d883  nl_tela
2983b000f2d8149a6ac94906af112f10  suite.sh
5bffcf69450a5561f52ae60e4ac59c26  suite-boot.sh
8c437a30c525f49136fc3f3194ed2964  suite-pedido.sh
cb9360471adcfcc3cc1e24998afbede4  pfl7560-suite.rc
95aeb3c015dca7fc722b16971a1b9156  pfl7560.apk
8899cc7d36063af3307bfecc91f924c3  pfl7560-home.apk
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

MODEL=$(getprop ro.product.model 2>/dev/null)
if [ "$MODEL" != "PFL7560" ]; then
  LOG "modelo='$MODEL' nao e PFL7560 - abortado por seguranca."
  exit 0
fi

if ! command -v md5sum >/dev/null 2>&1; then
  LOG "[ERRO] md5sum ausente - nao consigo conferir o kit. Abortado (nada foi alterado)."
  exit 1
fi

if [ ! -d "$MP" ]; then
  LOG "[ERRO] mountpoint '$MP' nao existe - abortando (nada foi alterado)."
  exit 1
fi

kit_nomes(){ echo "$KIT_LISTA" | sed -n 's/^[0-9a-f][0-9a-f]*  //p'; }
kit_md5_esperado(){ echo "$KIT_LISTA" | sed -n "s|^\\([0-9a-f][0-9a-f]*\\)  $1\$|\\1|p" | head -1; }
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

dir_seguro(){
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ldn "$1" 2>/dev/null)
  case "$1" in
    d???------|d???------[.+]) [ "$3" = "$DONO_UID" ] ;;
    *) return 1 ;;
  esac
}
arq_seguro(){
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ln "$1" 2>/dev/null)
  [ "$3" = "$DONO_UID" ]
}
trabalho_ok(){
  dir_seguro "$WORK" && return 0
  LOG "[ERRO] $WORK nao e uma pasta so do root (link, dono errado ou aberta a outros) - NAO vou usar nem escrever nela."
  return 1
}
preparar_trabalho(){
  if [ ! -e "$WORK" ] && [ ! -L "$WORK" ]; then
    mkdir -p "${WORK%/*}" 2>/dev/null
    ( umask 077; mkdir "$WORK" 2>/dev/null ) && chmod 700 "$WORK" 2>/dev/null
  fi
  trabalho_ok
}
conferir_em(){
  _cb="$1"; shift
  _trc=0
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
cor_pronto(){
  trabalho_ok || return 1
  trabalho_conferir cor.sh
}

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

# shellcheck disable=SC2046
if ! kit_conferir "$MP" $(kit_nomes); then
  LOG "[ERRO] kit incompleto ou adulterado - ABORTADO. Nada foi alterado. Copie de novo TODOS os arquivos da pasta do kit para a raiz do pendrive."
  if kit_conferir "$MP" kit/erro.png >/dev/null 2>&1; then
    mkdir -p "$R/sdcard/pfl7560-kit" && cp "$MP/kit/erro.png" "$R/sdcard/pfl7560-kit/erro.png" \
      && am start -a android.intent.action.VIEW -d "file:///sdcard/pfl7560-kit/erro.png" -t image/png >/dev/null 2>&1
  fi
  exit 1
fi
LOG "kit conferido: $(kit_nomes | wc -l | tr -dc '0-9') arquivos com md5 certo"

if ! preparar_trabalho; then
  LOG "[ERRO] pasta de trabalho recusada - abortando (nada foi alterado)."
  exit 1
fi
KIT_COPIA=$(kit_nomes | grep -v '^ZYCustom.ini$')
PREP="$WORK/preparo.$$"
KIT_EXEC="cor.sh lvdsctl nl_camcheck nl_tela suite.sh suite-boot.sh suite-pedido.sh"
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
# shellcheck disable=SC2086
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

suite_nomes(){ kit_nomes | grep -v -e '^ZYCustom.ini$' -e '^pfl7560-suite.rc$' -e '^pfl7560.apk$' -e '^pfl7560-home.apk$' -e '^overlay/' -e '^marca/'; }
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
    # shellcheck disable=SC2086
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
# shellcheck disable=SC2012
rotulo_de(){ ls -Z "$1" 2>/dev/null | tr ' ' '\n' | grep '^u:object_r:[a-z0-9_]*:s0$' | head -1; }
rotulo_alvo(){ _ra=$(rotulo_de "$RC"); if [ -n "$_ra" ]; then echo "$_ra"; else echo "$ROTULO_PADRAO"; fi; }
rc_conforme(){
  _rcf="$1"
  [ -f "$_rcf" ] && [ ! -L "$_rcf" ] && cmp -s "$WORK/pfl7560-suite.rc" "$_rcf" || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ln "$_rcf" 2>/dev/null)
  case "$1" in -rw-r--r--|-rw-r--r--[.+]) ;; *) return 1 ;; esac
  [ "$3" = "$DONO_UID" ] || return 1
  _rl=$(rotulo_de "$_rcf")
  [ -z "$_rl" ] || [ "$_rl" = "$(rotulo_alvo)" ]
}
suite_rc_ok(){ rc_conforme "$RC_SUITE"; }
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

ROTULO_APP="u:object_r:vendor_app_file:s0"
ROTULO_OVERLAY="u:object_r:vendor_overlay_file:s0"
app_conforme(){
  _ab="${3:-app}"; _ar="${4:-$ROTULO_APP}"
  _ad="$R/vendor/$_ab/$2"; _aa="$_ad/$2.apk"
  [ -d "$_ad" ] && [ ! -L "$_ad" ] || return 1
  [ -f "$_aa" ] && [ ! -L "$_aa" ] && cmp -s "$WORK/$1" "$_aa" || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ln "$_aa" 2>/dev/null)
  case "$1" in -rw-r--r--|-rw-r--r--[.+]) ;; *) return 1 ;; esac
  [ "$3" = "$DONO_UID" ] || return 1
  _al=$(rotulo_de "$_aa")
  [ -z "$_al" ] || [ "$_al" = "$_ar" ]
}
instalar_app(){
  _ab="${3:-app}"; _ar="${4:-$ROTULO_APP}"
  _ad="$R/vendor/$_ab/$2"; _aa="$_ad/$2.apk"; _an="$R/vendor/$_ab/.$2.apk.new"
  _at=app; _adesc="app do sistema"
  if [ "$_ab" = "overlay" ]; then _at=overlay; _adesc="sobreposicao do sistema"; fi
  if ! trabalho_ok || ! trabalho_conferir "$1"; then
    LOG "[AVISO] $_at: $1 em $WORK nao confere - NAO foi instalado (o resto do kit segue)."
    return 1
  fi
  if [ ! -d "$R/vendor/$_ab" ]; then
    { mkdir -p "$R/vendor/$_ab" && chmod 755 "$R/vendor/$_ab" && chown root:root "$R/vendor/$_ab"; } 2>/dev/null
    chcon "$_ar" "$R/vendor/$_ab" 2>/dev/null
  fi
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
KIT_APPS="pfl7560.apk:PFL7560 pfl7560-home.apk:PFL7560Home"
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
HOME_LINHA="vendor.newlink.launcher.package=com.pfl7560.home"
home_prop_ok(){ grep -qx "$HOME_LINHA" "$BP" 2>/dev/null; }
gravar_home_prop(){
  if ! app_conforme pfl7560-home.apk PFL7560Home; then
    LOG "[AVISO] home: a home nao esta instalada e conferida - a tela inicial continua a de fabrica."
    return 1
  fi
  if cp "$BP" "$BP.new" && sed -i '/^vendor\.newlink\.launcher\.package=/d' "$BP.new" \
     && echo "$HOME_LINHA" >> "$BP.new" && grep -qx "$HOME_LINHA" "$BP.new" && sync && mv "$BP.new" "$BP"; then
    LOG "[OK] home: $HOME_LINHA em ${BP#"$R"} (vale no proximo boot; volta tirando a linha ou com DESINSTALAR-SUITE.txt)"
    return 0
  fi
  rm -f "$BP.new"
  LOG "[AVISO] home: nao consegui gravar a prop da home em $BP - a tela inicial continua a de fabrica."
  return 1
}

FM_LINHA="vendor.nl.filemanage_file=1"
fm_prop_ok(){ grep -qx "$FM_LINHA" "$BP" 2>/dev/null; }
gravar_fm_prop(){
  if cp "$BP" "$BP.new" && sed -i '/^vendor\.nl\.filemanage_file=/d' "$BP.new" \
     && echo "$FM_LINHA" >> "$BP.new" && grep -qx "$FM_LINHA" "$BP.new" && sync && mv "$BP.new" "$BP"; then
    LOG "[OK] gerenciador: $FM_LINHA em ${BP#"$R"} (vale no proximo boot; volta com DESINSTALAR-SUITE.txt)"
    return 0
  fi
  rm -f "$BP.new"
  LOG "[AVISO] gerenciador: nao consegui gravar a prop em $BP - o gerenciador continua na pagina inicial de fabrica."
  return 1
}

MARCA_DESTINO="$R/atv/bootvideo"
MARCA_BACKUP="$SUITE/marca-original"
KIT_MARCA="marca/logo.jpg:logo.jpg marca/bootanimation.zip:bootanimation.zip"
marca_ok(){ [ -f "$MARCA_DESTINO/$2" ] && [ ! -L "$MARCA_DESTINO/$2" ] && cmp -s "$WORK/$1" "$MARCA_DESTINO/$2"; }
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
APP_PEND=0
if [ "$SUITE_OK" = "1" ]; then
  for _ka in $KIT_APPS; do app_conforme "${_ka%%:*}" "${_ka#*:}" || APP_PEND=1; done
  for _ko in $KIT_OVERLAYS; do app_conforme "${_ko%%:*}" "${_ko#*:}" overlay "$ROTULO_OVERLAY" || APP_PEND=1; done
  home_prop_ok || APP_PEND=1
  fm_prop_ok || APP_PEND=1
fi

ini_md5(){ md5sum "$INI" 2>/dev/null | cut -d' ' -f1; }
term_ok(){ _m=$(ini_md5); [ -n "$_m" ] && { [ "$_m" = "$INI_MD5_OK" ] || [ "$_m" = "$INI_MD5_OK_NOTYPEC" ]; }; }
term_alvo_de(){
  [ -n "$1" ] || return 0
  [ "$1" = "$INI_MD5_FABRICA_NOTYPEC" ] && { echo "$INI_MD5_OK_NOTYPEC"; return 0; }
  [ "$1" = "$INI_MD5_FABRICA" ] && { echo "$INI_MD5_OK"; return 0; }
  for _a in $INI_MD5_ANTERIORES; do
    [ "$1" = "$_a" ] && { echo "$INI_MD5_OK"; return 0; }
  done
  return 0
}

ini_secoes(){ grep -a -n '^\[' "$1" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\):\[\([^]]*\)\].*$/\1 \2/p'; }
ini_faixa(){
  _ftot=$(grep -a -c '' "$1" 2>/dev/null)
  [ "$(ini_secoes "$1" | grep -c " $2\$")" = 1 ] || return 1
  # shellcheck disable=SC2046
  set -- "$_ftot" "$2" $(ini_secoes "$1" | grep -A1 " $2\$" | tr '\n' ' ')
  [ "$4" = "$2" ] || return 1
  if [ -n "${5:-}" ]; then echo "$3 $(($5-1))"; else echo "$3 $1"; fi
}
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
AVISO=0

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

if [ "$TERM_ACAO" = "1" ]; then
  if [ ! -f "$INI.STOCK" ] && { [ "$(ini_md5)" = "$INI_MD5_FABRICA" ] || [ "$(ini_md5)" = "$INI_MD5_FABRICA_NOTYPEC" ]; }; then
    cp "$INI" "$INI.STOCK" || LOG "[AVISO] nao consegui salvar $INI.STOCK"
  fi
  if cp "$WORK/ini.composto" "$INI.new" && chmod 644 "$INI.new" \
     && [ "$(md5sum "$INI.new" 2>/dev/null | cut -d' ' -f1)" = "$TERM_ALVO" ]; then
    if sync && mv "$INI.new" "$INI" && term_ok; then
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

if wifi_ok; then
  LOG "wi-fi ja estava ok (wifi_disconnect_on_boot=0 presente)"
else
  if [ ! -f "$BP.STOCK" ]; then
    cp "$BP" "$BP.STOCK" || LOG "[AVISO] nao consegui salvar $BP.STOCK"
  fi
  if cp "$BP" "$BP.new" && sed -i "s/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/" "$BP.new" \
     && grep -q "wifi_disconnect_on_boot=0" "$BP.new" && sync && mv "$BP.new" "$BP"; then
    LOG "[OK] wi-fi: wifi_disconnect_on_boot=0"
    CHG=1
  else
    LOG "[ERRO] wi-fi: falha ao editar wifi_disconnect_on_boot em $BP"
    rm -f "$BP.new"
    FAIL=$((FAIL+1))
  fi
fi

if xiri_ok; then
  LOG "xiri ja estava desabilitado"
else
  if [ ! -f "$RC.STOCK" ]; then
    cp "$RC" "$RC.STOCK" || LOG "[AVISO] nao consegui salvar $RC.STOCK"
  fi
  if cp "$RC" "$RC.new" \
     && sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$RC.new" \
     && grep -A1 "service xiriservice" "$RC.new" | grep -q "disabled" \
     && sync && mv "$RC.new" "$RC"; then
    LOG "[OK] xiri: xiriservice desabilitado (fim do spam de log)"
    CHG=1
  else
    LOG "[ERRO] xiri: falha ao desabilitar xiriservice em $RC"
    rm -f "$RC.new"
    FAIL=$((FAIL+1))
  fi
fi

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
  for _km in $KIT_MARCA; do
    if marca_ok "${_km%%:*}" "${_km#*:}"; then
      LOG "marca: ${_km#*:} ja estava igual ao do kit"
    else
      gravar_marca "${_km%%:*}" "${_km#*:}"
    fi
  done
fi

sync
if [ "$VENDOR_RW" = "1" ]; then
  mount -o ro,remount /vendor 2>/dev/null
fi

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

if [ "$AVISO" = "1" ]; then AVISO_ARG="termica-falhou"; else AVISO_ARG=""; fi
if ! cor_pronto; then
  LOG "[ERRO] cor.sh nao conferiu na hora de executar - a fase de cor NAO foi lancada (nada foi escrito na panelparam)."
  exit 1
fi
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
