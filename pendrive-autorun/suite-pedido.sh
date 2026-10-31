#!/vendor/bin/sh

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_APP_UID_MIN
fi
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
FIM_ARQ="$SUITE/ultimo-fim"
LOCK="$R/dev/pfl7560-suite.lock"
VERIF_DIR="$R/data/data/com.pfl7560.verificar"
HOME_DIR="$R/data/data/com.pfl7560.home"
PEDIDO_DIR="$VERIF_DIR"
LUZ_ARQ="$SUITE/luz"
HIDEBUG="$R/vendor/bin/hidebug"
INTERVALO_MIN=600
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
APP_UID_MIN=10000
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_APP_UID_MIN:-}" ] && APP_UID_MIN="$PFL_APP_UID_MIN"

# SUITE_MD5_INICIO
SUITE_MD5="1d2f122c967fbf86b2ef07f956de0a36"
# SUITE_MD5_FIM

LOG(){ echo "[PFL7560-suite-pedido] $*"; }
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
md5_de(){ md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
pasta_do_app(){
  [ -d "$PEDIDO_DIR" ] && [ ! -L "$PEDIDO_DIR" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ldn "$PEDIDO_DIR" 2>/dev/null); _du="${3:-}"; _dg="${4:-}"
  case "$_du" in ''|*[!0-9]*) return 1 ;; esac
  case "$_dg" in ''|*[!0-9]*) return 1 ;; esac
  [ "$_du" -ge "$APP_UID_MIN" ]
}
pedido_do_app(){
  pasta_do_app || return 1
  [ -f "$PEDIDO_DIR/$1" ] && [ ! -L "$PEDIDO_DIR/$1" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ln "$PEDIDO_DIR/$1" 2>/dev/null); _fu="${3:-}"
  [ "$_fu" = "$_du" ]
}
terminou_ha_pouco(){
  _fim=$(head -n 1 "$FIM_ARQ" 2>/dev/null | tr -cd '0-9' | cut -c1-20)
  _agora=$(date +%s 2>/dev/null | tr -cd '0-9')
  [ -n "$_fim" ] && [ -n "$_agora" ] || return 1
  [ "$_agora" -ge "$_fim" ] && [ $(( _agora - _fim )) -lt "$INTERVALO_MIN" ]
}

luz_valida(){
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#1}" -le 3 ] || return 1
  _n=$(printf '%s' "$1" | sed 's/^0*//')
  [ -n "$_n" ] && [ "$_n" -ge 10 ] && [ "$_n" -le 100 ] || return 1
  printf '%s' "$_n"
}
limpo(){ printf '%s' "$1" | tr -cd ' -~' | cut -c1-20; }
escrever_luz_atual(){
  setprop vendor.pfl7560.luz "$1"
}
ler_pedido_luz(){
  LUZ_BRUTO=""
  _lp="$SUITE/luz.pedido"
  rm -f "$_lp"
  dir_seguro "$SUITE" || return 1
  mv -f "$PEDIDO_DIR/luz" "$_lp" 2>/dev/null || return 1
  if [ ! -f "$_lp" ] || [ -L "$_lp" ]; then rm -f "$_lp"; return 1; fi
  # shellcheck disable=SC2046
  set -- $(ls -ln "$_lp" 2>/dev/null)
  if [ "${3:-}" != "$_du" ]; then rm -f "$_lp"; return 1; fi
  LUZ_BRUTO=$(timeout 2 head -c 16 "$_lp" 2>/dev/null | tr -d '\r\n')
  rm -f "$_lp"
  return 0
}
ler_gbl(){ printf 'picture\ngbl\nquit\n' | timeout 15 "$HIDEBUG" 2>/dev/null | sed -n 's/^.*backlight:\([0-9]*\).*$/\1/p' | head -n 1; }
aplicar_luz(){
  if [ ! -x "$HIDEBUG" ]; then LOG "[AVISO] hidebug ausente - luz $1 nao aplicada."; return 1; fi
  printf 'picture\nsbl %s\nquit\n' "$1" | timeout 15 "$HIDEBUG" >/dev/null 2>&1
  _k=0
  while :; do
    _lido=$(ler_gbl)
    [ "$_lido" = "$1" ] && break
    _k=$(( _k + 1 ))
    [ "$_k" -ge 3 ] && break
    sleep 1
  done
  if [ "$_lido" = "$1" ]; then
    LOG "luz $1% aplicada (o gbl confere)"
  else
    LOG "[AVISO] luz $1% pedida, mas o gbl leu '$(limpo "$_lido")'"
  fi
  case "$_lido" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#_lido}" -le 3 ] || return 1
  escrever_luz_atual "$_lido"
}
tratar_luz(){
  if ! _v=$(luz_valida "$1"); then
    LOG "[AVISO] pedido de luz recusado (conteudo '$(limpo "$1")': so 10 a 100, so digitos)."
    return 0
  fi
  ( umask 077; printf '%s\n' "$_v" > "$LUZ_ARQ.novo" ) && mv -f "$LUZ_ARQ.novo" "$LUZ_ARQ"
  if [ -d "$LOCK" ]; then LOG "a suite esta rodando (trava): luz $_v% guardada, aplica no fim da suite ou no proximo boot."; return 0; fi
  aplicar_luz "$_v"
}

if [ "${1:-}" = "aplicar-luz" ]; then
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - luz nao reaplicada."; exit 1; }
  [ -e "$LUZ_ARQ" ] || exit 0
  arq_seguro "$LUZ_ARQ" || { LOG "[AVISO] $LUZ_ARQ e link ou de outro dono - ignorado."; exit 0; }
  _b=$(head -c 16 "$LUZ_ARQ" 2>/dev/null | tr -d '\r\n')
  if ! _v=$(luz_valida "$_b"); then LOG "[AVISO] luz guardada invalida ('$(limpo "$_b")') - nao reaplicada."; exit 0; fi
  LOG "reaplicando a luz guardada: $_v%"
  aplicar_luz "$_v"
  exit 0
fi

DESCANSO_LUZ=10
ANTES_ARQ="$SUITE/luz-antes-descanso"
luz_guardada(){
  _b=""
  arq_seguro "$LUZ_ARQ" && _b=$(head -c 16 "$LUZ_ARQ" 2>/dev/null | tr -d '\r\n')
  luz_valida "$_b" || printf '100'
}
tratar_descanso(){
  if [ -d "$LOCK" ]; then LOG "a suite esta rodando (trava): descanso $1 sem efeito na luz."; return 0; fi
  if [ ! -x "$HIDEBUG" ]; then LOG "[AVISO] hidebug ausente - descanso $1 sem efeito na luz."; return 0; fi
  if [ "$1" = "inicio" ]; then
    if [ ! -e "$ANTES_ARQ" ] && [ ! -L "$ANTES_ARQ" ] && _a=$(luz_valida "$(ler_gbl)"); then
      ( umask 077; printf '%s\n' "$_a" > "$ANTES_ARQ.novo" ) && mv -f "$ANTES_ARQ.novo" "$ANTES_ARQ"
    fi
    _dv="$DESCANSO_LUZ"
  else
    _dv=""
    arq_seguro "$ANTES_ARQ" && _dv=$(luz_valida "$(head -c 16 "$ANTES_ARQ" 2>/dev/null | tr -d '\r\n')")
    rm -f "$ANTES_ARQ"
    [ -n "$_dv" ] || _dv=$(luz_guardada)
  fi
  printf 'picture\nsbl %s\nquit\n' "$_dv" | timeout 15 "$HIDEBUG" >/dev/null 2>&1
  if [ "$1" = "inicio" ]; then LOG "descanso na tela: luz a $_dv% (o nivel do dono continua guardado)"
  else LOG "descanso terminou: luz de volta a $_dv%"; fi
}

NOME="${3:-}"
case "$NOME" in
  pedir-verificacao|descanso-inicio|descanso-fim) PEDIDO_DIR="$VERIF_DIR" ;;
  luz) PEDIDO_DIR="$HOME_DIR" ;;
  *) exit 0 ;;
esac
[ "${2%/}" = "$PEDIDO_DIR" ] || exit 0
case "${1:-}" in *w*|*y*) ;; *) exit 0 ;; esac
DO_APP=0
pedido_do_app "$NOME" && DO_APP=1
LUZ_BRUTO=""
if [ "$NOME" = "luz" ] && [ "$DO_APP" = "1" ]; then
  ler_pedido_luz || DO_APP=0
fi
rm -f "$PEDIDO_DIR/$NOME"
if ! dir_seguro "$SUITE"; then
  echo "[PFL7560-suite-pedido] [ERRO] $SUITE nao e uma pasta so do root - pedido ignorado."
  exit 1
fi
exec >>"$SUITE/vigia.log" 2>&1 </dev/null
LOG "pedido de $NOME recebido ($(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null))"
if [ -e "$PEDIDO_DIR/$NOME" ] || [ -L "$PEDIDO_DIR/$NOME" ]; then
  LOG "[AVISO] nao consegui apagar o pedido $PEDIDO_DIR/$NOME - pedido ignorado."
  exit 0
fi
if [ "$DO_APP" != "1" ]; then LOG "[AVISO] o pedido nao veio do app (dono do arquivo nao e o da pasta do app) - ignorado."; exit 0; fi
if [ "$NOME" = "luz" ]; then tratar_luz "$LUZ_BRUTO"; exit 0; fi
case "$NOME" in descanso-*) tratar_descanso "${NOME#descanso-}"; exit 0 ;; esac
if [ -d "$LOCK" ]; then LOG "a suite ja esta rodando (trava) - pedido ignorado."; exit 0; fi
if terminou_ha_pouco; then LOG "a suite terminou ha menos de 10 min, mas o pedido e do dono: roda."; fi
if ! { arq_seguro "$SUITE/suite.sh" && [ "$(md5_de "$SUITE/suite.sh")" = "$SUITE_MD5" ]; }; then
  LOG "[ERRO] suite.sh ausente, link, de outro dono ou com md5 diferente do embutido - NAO executado."
  exit 1
fi
LOG "lancando a suite (suite.sh pedido) destacada"
if command -v setsid >/dev/null 2>&1; then
  setsid sh "$SUITE/suite.sh" pedido >>"$SUITE/lancador.log" 2>&1 </dev/null &
else
  nohup sh "$SUITE/suite.sh" pedido >>"$SUITE/lancador.log" 2>&1 </dev/null &
fi
exit 0
