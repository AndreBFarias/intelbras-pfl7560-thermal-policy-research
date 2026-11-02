#!/vendor/bin/sh

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_CURVAS_VOLTAS PFL_STANDBY_AVISO PFL_STANDBY_TOTAL
fi
LC_ALL=C; export LC_ALL
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
INI="$R/vendor/etc/ZYCustom.ini"
HIDEBUG="$R/vendor/bin/hidebug"
LOCK="$R/dev/pfl7560-suite.lock"
CTRAVA="$R/dev/pfl7560-curvas.trava"
PID_LACO="$R/dev/pfl7560-curvas.pid"
PID_STANDBY="$R/dev/pfl7560-standby.pid"
VENT_ARQ="$SUITE/curva-vent"
LED_ARQ="$SUITE/curva-led"
VENT_DESISTIU="$SUITE/curva-vent.desistiu"
LED_DESISTIU="$SUITE/curva-led.desistiu"
LISTA_ARQ="$SUITE/debloat-aprovados.txt"
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"

NORM_OK="bfc8d66bd6bde87feff69fc572a6fe30"
NORM_OK_NOTYPEC="c917f8faa8f28702a26feb8ffa99fcb7"

FAN_PISO=300
FAN_MAX=1000
TEMP_CHEIA=660
TEMP_LED_LIMITE=700
LED_MIN=850
INTERVALO=5
TOLERANCIA=20
DESISTE_APOS=3
HIST_QUEDA=100
LED_LIM_CANON="66000, 67500, 69000, 70000, 71500, 73000"
LED_BRI_CANON="1000,  950,  900,  850,  850,  850"
STANDBY_AVISO=600
STANDBY_TOTAL=660
VOLTAS=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_CURVAS_VOLTAS:-}" ] && VOLTAS="$PFL_CURVAS_VOLTAS"
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_STANDBY_AVISO:-}" ] && STANDBY_AVISO="$PFL_STANDBY_AVISO"
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_STANDBY_TOTAL:-}" ] && STANDBY_TOTAL="$PFL_STANDBY_TOTAL"

LOG(){ echo "[PFL7560-curvas] $*"; }
limpo(){ printf '%s' "$1" | tr -cd ' -~' | cut -c1-"${2:-40}"; }
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
num(){
  case "$1" in ''|*[!0-9]*|0?*) return 1 ;; esac
  [ "${#1}" -le 6 ]
}
prop(){ setprop "vendor.pfl7560.$1" "$2" 2>/dev/null; }

ini_secoes(){ grep -a -n '^\[' "$1" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\):\[\([^]]*\)\].*$/\1 \2/p'; }
ini_faixa(){
  _ftot=$(grep -a -c '' "$1" 2>/dev/null)
  [ "$(ini_secoes "$1" | grep -c " $2\$")" = 1 ] || return 1
  # shellcheck disable=SC2046
  set -- "$_ftot" "$2" $(ini_secoes "$1" | grep -A1 " $2\$" | tr '\n' ' ')
  [ "$4" = "$2" ] || return 1
  if [ -n "${5:-}" ]; then echo "$3 $(($5-1))"; else echo "$3 $1"; fi
}
ini_linhas(){
  _lf=$(ini_faixa "$1" "$2") || return 1
  _la=${_lf% *}; _lb=${_lf#* }
  # shellcheck disable=SC2013
  for _ln in $(grep -a -n -e "^$3" -e "^$4" "$1" | cut -d: -f1); do
    if [ "$_ln" -ge "$_la" ] && [ "$_ln" -le "$_lb" ]; then printf '%s ' "$_ln"; fi
  done
}
ini_linha(){
  _lr=$(ini_linhas "$1" "$2" "$3" "$3") || return 1
  # shellcheck disable=SC2086
  set -- $_lr
  [ "$#" = 1 ] || return 1
  echo "$1"
}
ini_cortes(){
  _cs=""
  for _ln in $(ini_linhas "$1" BacklightPolicy 'POLICY_[01]_THRESHOLD' 'POLICY_[01]_BRIGHTNESS'); do
    _cs="$_cs -e ${_ln}d"
  done
  [ -n "$_cs" ] || return 1
  echo "$_cs"
}
ini_md5_norm(){
  _cs=$(ini_cortes "$1") || return 1
  # shellcheck disable=SC2086
  sed $_cs "$1" 2>/dev/null | md5sum | cut -d' ' -f1
}
ini_valor(){
  _vl=$(ini_linha "$1" "$2" "$3") || return 1
  sed -n "${_vl}p" "$1" | sed 's/^[^=]*=//; s/;.*$//' | tr -d ' \r'
}
lista_valida(){
  _lo=$1; _lmin=$2; _lmax=$3; _lord=$4; _lult=$5; _lq=0; _lp=""
  for _lv in $(printf '%s' "$6" | tr ',' ' '); do
    num "$_lv" || return 1
    [ "$_lv" -ge "$_lmin" ] && [ "$_lv" -le "$_lmax" ] || return 1
    if [ -n "$_lp" ]; then
      case "$_lord" in
        cresc) [ "$_lv" -ge "$_lp" ] || return 1 ;;
        estrito) [ "$_lv" -gt "$_lp" ] || return 1 ;;
        decresc) [ "$_lv" -le "$_lp" ] || return 1 ;;
      esac
    fi
    _lp=$_lv; _lq=$(( _lq + 1 ))
  done
  [ "$_lq" = "$_lo" ] || return 1
  [ -z "$_lult" ] || [ "$_lp" = "$_lult" ]
}
interp_lin(){
  _ix=$1; _iX=$(printf '%s' "$2" | tr -d ' '); _iY=$(printf '%s' "$3" | tr -d ' ')
  _px=""; _py=""; _ik=1
  while [ "$_ik" -le 6 ]; do
    _cx=$(printf '%s' "$_iX" | cut -d, -f"$_ik"); _cy=$(printf '%s' "$_iY" | cut -d, -f"$_ik")
    if [ "$_ix" -le "$_cx" ]; then
      if [ -z "$_px" ]; then echo "$_cy"; else echo $(( _py + ( _ix - _px ) * ( _cy - _py ) / ( _cx - _px ) )); fi
      return 0
    fi
    _px=$_cx; _py=$_cy; _ik=$(( _ik + 1 ))
  done
  echo "$_py"
}
escada_canon(){ interp_lin "$1" "$LED_LIM_CANON" "$LED_BRI_CANON"; }
led_ponto_ok(){ [ "$2" -le "$(escada_canon "$1")" ]; }
escada_em(){
  _em=$(escada_canon "$(( $1 * 100 ))")
  for _pol in 0 1; do
    _th=$(ini_valor "$INI" BacklightPolicy "POLICY_${_pol}_THRESHOLD" 2>/dev/null) || continue
    _br=$(ini_valor "$INI" BacklightPolicy "POLICY_${_pol}_BRIGHTNESS" 2>/dev/null) || continue
    lista_valida 6 1000 73000 estrito 73000 "$_th" || continue
    lista_valida 6 "$LED_MIN" 1000 decresc "$LED_MIN" "$_br" || continue
    _ev=$(interp_lin "$(( $1 * 100 ))" "$_th" "$_br")
    [ "$_ev" -lt "$_em" ] && _em=$_ev
  done
  echo "$_em"
}
ini_curvas_ok(){
  for _pol in 0 1; do
    _th=$(ini_valor "$1" BacklightPolicy "POLICY_${_pol}_THRESHOLD") || return 1
    _br=$(ini_valor "$1" BacklightPolicy "POLICY_${_pol}_BRIGHTNESS") || return 1
    lista_valida 6 1000 73000 estrito 73000 "$_th" || return 1
    lista_valida 6 "$LED_MIN" 1000 decresc "$LED_MIN" "$_br" || return 1
    case "$_th" in *,70000,71500,73000) ;; *) return 1 ;; esac
    case "$_br" in *,"$LED_MIN","$LED_MIN","$LED_MIN") ;; *) return 1 ;; esac
    _t3=$(printf '%s' "$_th" | cut -d, -f3)
    [ "$_t3" -lt 70000 ] || return 1
    for _ik2 in 1 2 3; do
      led_ponto_ok "$(printf '%s' "$_th" | cut -d, -f"$_ik2" | tr -d ' ')" "$(printf '%s' "$_br" | cut -d, -f"$_ik2" | tr -d ' ')" || return 1
    done
  done
}
ini_base(){
  _nm=$(ini_md5_norm "$1") || return 1
  [ "$_nm" = "$NORM_OK" ] && { echo usbc; return 0; }
  [ "$_nm" = "$NORM_OK_NOTYPEC" ] && { echo notypec; return 0; }
  return 1
}
ini_aceito(){
  ini_base "$1" >/dev/null || return 1
  ini_curvas_ok "$1"
}

trava(){
  _tk=0
  while ! mkdir "$CTRAVA" 2>/dev/null; do
    _tp=$(head -n 1 "$CTRAVA/pid" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
    if [ -z "$_tp" ] || ! kill -0 "$_tp" 2>/dev/null; then rm -rf "$CTRAVA"; continue; fi
    _tk=$(( _tk + 1 ))
    [ "$_tk" -ge 30 ] && return 1
    sleep 1
  done
  echo "$$" > "$CTRAVA/pid"
}
destrava(){ rm -rf "$CTRAVA"; }

fans_aplicar(){
  [ -x "$HIDEBUG" ] || return 1
  printf 'custom\nsfs 0 %s\nsfs 1 %s\nquit\n' "$1" "$1" | timeout 15 "$HIDEBUG" >/dev/null 2>&1
}
fans_ler(){
  [ -x "$HIDEBUG" ] || return 1
  printf 'custom\ngfs 0\ngfs 1\nquit\n' | timeout 15 "$HIDEBUG" 2>/dev/null | grep -a 'fan speed' | grep -aoE '[0-9]+' | head -n 2
}
bri_aplicar(){
  [ -x "$HIDEBUG" ] || return 1
  printf 'custom\nsbri 0 %s\nquit\n' "$1" | timeout 15 "$HIDEBUG" >/dev/null 2>&1
}
bri_ler(){
  [ -x "$HIDEBUG" ] || return 1
  printf 'custom\ngbri 0\nquit\n' | timeout 15 "$HIDEBUG" 2>/dev/null | grep -a 'brightness' | grep -aoE '[0-9]+' | head -n 1
}
perto(){
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -le $(( $2 + TOLERANCIA )) ] && [ "$1" -ge $(( $2 - TOLERANCIA )) ]
}
fans_perto(){
  _fl=$(fans_ler) || return 1
  # shellcheck disable=SC2086
  set -- $_fl
  [ "$#" = 2 ] || return 1
  perto "$1" "$FAN_ALVO" && perto "$2" "$FAN_ALVO"
}

arredonda_50(){
  _r=$(( ( $1 + 49 ) / 50 * 50 ))
  [ "$_r" -lt "$FAN_PISO" ] && _r=$FAN_PISO
  [ "$_r" -gt "$FAN_MAX" ] && _r=$FAN_MAX
  echo "$_r"
}
vent_valida(){
  VT1=; VT2=; VT3=; VT4=; VT5=; VV1=; VV2=; VV3=; VV4=; VV5=
  [ "$#" = 5 ] || return 1
  _pt=0; _pv=0; _n=0
  for _p in "$@"; do
    case "$_p" in *:*:*|:*|*:) return 1 ;; *:*) ;; *) return 1 ;; esac
    _t=${_p%%:*}; _v=${_p#*:}
    num "$_t" && num "$_v" || return 1
    [ "$_t" -ge 25 ] && [ "$_t" -le 66 ] || return 1
    [ "$_v" -ge 30 ] && [ "$_v" -le 100 ] && [ $(( _v % 5 )) = 0 ] || return 1
    [ "$_t" -gt "$_pt" ] && [ "$_v" -ge "$_pv" ] || return 1
    _pt=$_t; _pv=$_v; _n=$(( _n + 1 ))
    eval "VT$_n=\$_t; VV$_n=\$_v"
  done
  [ "$_pv" = 100 ]
}
vent_seg(){
  [ "$VX" -lt $(( $3 * 10 )) ] || return 1
  echo $(( $2 * 10 + ( VX - $1 * 10 ) * ( $4 - $2 ) / ( $3 - $1 ) ))
}
vent_alvo(){
  VX=$1
  if [ "$VX" -ge "$TEMP_CHEIA" ] || [ "$VX" -ge $(( VT5 * 10 )) ]; then echo "$FAN_MAX"; return 0; fi
  if [ "$VX" -le $(( VT1 * 10 )) ]; then arredonda_50 $(( VV1 * 10 )); return 0; fi
  for _k in "$VT1 $VV1 $VT2 $VV2" "$VT2 $VV2 $VT3 $VV3" "$VT3 $VV3 $VT4 $VV4" "$VT4 $VV4 $VT5 $VV5"; do
    # shellcheck disable=SC2086
    _s=$(vent_seg $_k) && { arredonda_50 "$_s"; return 0; }
  done
  echo "$FAN_MAX"
}
vent_carregar(){
  arq_seguro "$VENT_ARQ" || return 1
  _vl=$(head -c 200 "$VENT_ARQ" 2>/dev/null | tr -d '\r\n' | tr -cd 'a-z0-9: ')
  # shellcheck disable=SC2086
  set -- $_vl
  [ "${1:-}" = v1 ] || return 1
  VPERFIL=${2:-}; VMODO=${3:-}
  [ "$#" -ge 3 ] || return 1
  shift 3
  vent_valida "$@"
}

led_valida(){
  LT1=; LT2=; LT3=; LB1=; LB2=; LB3=
  [ "$#" = 3 ] || return 1
  _pt=0; _pb=1000; _n=0
  for _p in "$@"; do
    case "$_p" in *:*:*|:*|*:) return 1 ;; *:*) ;; *) return 1 ;; esac
    _t=${_p%%:*}; _b=${_p#*:}
    num "$_t" && num "$_b" || return 1
    [ "$_t" -ge 40 ] && [ "$_t" -le 69 ] || return 1
    [ "$_b" -ge "$LED_MIN" ] && [ "$_b" -le 1000 ] && [ $(( _b % 10 )) = 0 ] || return 1
    [ "$_t" -gt "$_pt" ] && [ "$_b" -le "$_pb" ] || return 1
    led_ponto_ok "$(( _t * 1000 ))" "$_b" || return 1
    _pt=$_t; _pb=$_b; _n=$(( _n + 1 ))
    eval "LT$_n=\$_t; LB$_n=\$_b"
  done
}
led_alvo(){
  if [ "$1" -lt $(( LT1 * 10 )) ]; then echo 1000
  elif [ "$1" -lt $(( LT2 * 10 )) ]; then echo "$LB1"
  elif [ "$1" -lt $(( LT3 * 10 )) ]; then echo "$LB2"
  else echo "$LB3"
  fi
}
led_carregar(){
  arq_seguro "$LED_ARQ" || return 1
  _vl=$(head -c 200 "$LED_ARQ" 2>/dev/null | tr -d '\r\n' | tr -cd 'a-z0-9: ')
  # shellcheck disable=SC2086
  set -- $_vl
  [ "${1:-}" = v1 ] || return 1
  LPERFIL=${2:-}; LMODO=${3:-}
  [ "$#" -ge 3 ] || return 1
  shift 3
  led_valida "$@"
}

le_temp(){
  _tr=$(getprop zysys.env_temp 2>/dev/null)
  case "$_tr" in *-*) return 1 ;; esac
  _tv=$(printf '%s' "$_tr" | tr -cd '0-9.')
  case "$_tv" in ''|.*|*.*.*) return 1 ;; esac
  _ti=${_tv%%.*}
  _tf=0
  case "$_tv" in *.?*) _tf=$(printf '%s' "${_tv#*.}" | cut -c1) ;; esac
  _ti=$(printf '%s' "$_ti" | sed 's/^0*//')
  [ -n "$_ti" ] || _ti=0
  num "$_ti" || [ "$_ti" = 0 ] || return 1
  TEMP10=$(( _ti * 10 + _tf ))
  [ "$TEMP10" -gt 0 ] && [ "$TEMP10" -le 1500 ]
}

escreve_conf(){
  ( umask 077; printf '%s\n' "$2" > "$1.novo" ) && mv -f "$1.novo" "$1"
}

ini_escrever(){
  if [ ! -f "$INI" ] || [ -L "$INI" ]; then LOG "[ERRO] ini: $INI ausente ou link."; return 1; fi
  ini_aceito "$INI" || { LOG "[ERRO] ini: o ZYCustom.ini em uso nao e o do kit (ou variante valida dele) - nada gravado."; return 1; }
  _alvo="$SUITE/ini.novo"
  _sedf="$SUITE/ini.sed"
  rm -f "$_alvo" "$_sedf"
  : > "$_sedf" || return 1
  if [ -n "${W_LIM:-}" ]; then
    for _pol in 0 1; do
      _l1=$(ini_linha "$INI" BacklightPolicy "POLICY_${_pol}_THRESHOLD") || { rm -f "$_sedf"; return 1; }
      _l2=$(ini_linha "$INI" BacklightPolicy "POLICY_${_pol}_BRIGHTNESS") || { rm -f "$_sedf"; return 1; }
      printf '%s\n' "${_l1}s/^\\(POLICY_${_pol}_THRESHOLD *=\\) *[0-9, ]*;/\\1 ${W_LIM};/" "${_l2}s/^\\(POLICY_${_pol}_BRIGHTNESS *=\\) *[0-9, ]*;/\\1  ${W_BRI};/" >> "$_sedf"
    done
  fi
  [ -s "$_sedf" ] || { rm -f "$_sedf"; return 1; }
  sed -f "$_sedf" "$INI" > "$_alvo" || { rm -f "$_alvo" "$_sedf"; return 1; }
  rm -f "$_sedf"
  if ! ini_aceito "$_alvo" || [ "$(ini_md5_norm "$_alvo")" != "$(ini_md5_norm "$INI")" ]; then
    LOG "[ERRO] ini: o arquivo novo nao passou na conferencia - nada gravado."; rm -f "$_alvo"; return 1
  fi
  _m=$(md5_de "$_alvo")
  if [ "$_m" = "$(md5_de "$INI")" ]; then rm -f "$_alvo"; LOG "ini: ja estava com essas curvas"; return 0; fi
  if ! mount -o rw,remount /vendor 2>/dev/null; then LOG "[ERRO] ini: nao consegui abrir /vendor para escrita."; rm -f "$_alvo"; return 1; fi
  _rc=1
  cp "$INI" "$SUITE/ini-antes-curva" 2>/dev/null
  rm -f "$INI.new"
  if cp "$_alvo" "$INI.new" && chmod 644 "$INI.new" && [ "$(md5_de "$INI.new")" = "$_m" ]; then
    if sync && mv "$INI.new" "$INI" && [ "$(md5_de "$INI")" = "$_m" ]; then _rc=0; fi
  fi
  rm -f "$INI.new" "$_alvo"
  mount -o ro,remount /vendor 2>/dev/null
  if [ "$_rc" = 0 ]; then LOG "[OK] ini: curvas gravadas no ZYCustom.ini (md5 $_m; a copia anterior ficou em ini-antes-curva)"; else LOG "[ERRO] ini: a gravacao falhou ou a releitura nao confere."; fi
  return "$_rc"
}

fans_segura(){
  fans_aplicar "$FAN_MAX" || LOG "[AVISO] hidebug nao aplicou 1000 nos ventiladores."
}
led_solta(){
  _ls=$LED_MIN
  if le_temp; then _ls=$(escada_em "$TEMP10"); fi
  bri_aplicar "$_ls" || LOG "[AVISO] hidebug nao devolveu o brilho a politica do firmware."
}

parar_vent(){
  rm -f "$VENT_ARQ" "$VENT_DESISTIU"
  fans_segura
}
parar_led(){
  rm -f "$LED_ARQ" "$LED_DESISTIU"
  led_solta
}

laco_vivo(){
  _p=$(head -n 1 "$PID_LACO" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  [ -n "$_p" ] && grep -aq 'pfl7560' "/proc/$_p/cmdline" 2>/dev/null
}
laco_ligar(){
  if laco_vivo; then return 0; fi
  if command -v setsid >/dev/null 2>&1; then
    setsid sh "$SUITE/suite-curvas.sh" laco >>"$SUITE/curvas.log" 2>&1 </dev/null &
  else
    nohup sh "$SUITE/suite-curvas.sh" laco >>"$SUITE/curvas.log" 2>&1 </dev/null &
  fi
  echo "$!" > "$PID_LACO"
  LOG "laco das curvas ligado (pid $!)"
}

estado_props(){
  if [ -e "$VENT_ARQ" ] && vent_carregar; then
    if [ -e "$VENT_DESISTIU" ]; then prop vent "$VPERFIL:desistiu"; else prop vent "$VPERFIL:$VMODO"; fi
  fi
  if [ -e "$LED_ARQ" ] && led_carregar; then
    if [ -e "$LED_DESISTIU" ]; then prop led "$LPERFIL:desistiu"; else prop led "$LPERFIL:$LMODO"; fi
  fi
}

# shellcheck disable=SC2317
sai_laco(){
  rm -f "$PID_LACO"
  if [ -e "$VENT_ARQ" ]; then fans_segura; fi
  if [ -e "$LED_ARQ" ]; then led_solta; fi
}

ciclo_vent(){
  [ -e "$VENT_ARQ" ] || return 0
  [ -e "$VENT_DESISTIU" ] && return 0
  if ! vent_carregar; then
    LOG "[ERRO] curva dos ventiladores guardada e invalida - volto ao padrao (1000)."
    parar_vent; prop vent padrao; prop vent_aviso pedido
    return 0
  fi
  case "$VMODO" in vivo|ambos) ;; *) return 0 ;; esac
  if [ "$TEMP_OK" != 1 ]; then
    FALHA_T=$(( FALHA_T + 1 ))
    fans_segura
    FAN_ATUAL=""
    [ "$FALHA_T" -ge "$DESISTE_APOS" ] && prop vent_aviso temperatura
    return 0
  fi
  FALHA_T=0
  _n=$(vent_alvo "$TEMP10")
  if [ -z "$FAN_ATUAL" ] || [ "$_n" -gt "$FAN_ATUAL" ] || [ "$_n" -le $(( FAN_ATUAL - HIST_QUEDA )) ]; then
    FAN_ATUAL=$_n
  fi
  FAN_ALVO=$FAN_ATUAL
  if fans_perto; then BRIGOU_V=0; prop vent_aviso ""; return 0; fi
  if ! fans_aplicar "$FAN_ALVO"; then
    BRIGOU_V=$(( BRIGOU_V + 1 ))
    [ "$BRIGOU_V" -ge "$DESISTE_APOS" ] && { LOG "[AVISO] hidebug nao responde: ventiladores em 1000 e curva ao vivo desligada."; : > "$VENT_DESISTIU"; prop vent "$VPERFIL:desistiu"; prop vent_aviso hidebug; }
    return 0
  fi
  sleep 1
  if fans_perto; then
    BRIGOU_V=0; prop vent_aviso ""
    return 0
  fi
  BRIGOU_V=$(( BRIGOU_V + 1 ))
  LOG "[AVISO] os ventiladores nao ficaram em $FAN_ALVO (firmware reescreveu? lido: $(limpo "$(fans_ler | tr '\n' ' ')")) - $BRIGOU_V de $DESISTE_APOS."
  if [ "$BRIGOU_V" -ge "$DESISTE_APOS" ]; then
    LOG "[AVISO] o firmware briga com a curva dos ventiladores: desisto da curva ao vivo e deixo em 1000."
    fans_segura
    : > "$VENT_DESISTIU"
    prop vent "$VPERFIL:desistiu"; prop vent_aviso firmware
  fi
}

ciclo_led(){
  [ -e "$LED_ARQ" ] || return 0
  [ -e "$LED_DESISTIU" ] && return 0
  if ! led_carregar; then
    LOG "[ERRO] curva do LED guardada e invalida - solto o brilho."
    parar_led; prop led padrao; prop led_aviso pedido
    return 0
  fi
  case "$LMODO" in vivo|ambos) ;; *) return 0 ;; esac
  [ "$TEMP_OK" = 1 ] || return 0
  if [ "$TEMP10" -ge "$TEMP_LED_LIMITE" ]; then
    if [ -n "$LED_ATUAL" ]; then led_solta; LED_ATUAL=""; fi
    BRIGOU_L=0
    return 0
  fi
  _n=$(led_alvo "$TEMP10")
  _e=$(escada_em "$TEMP10")
  [ "$_e" -lt "$_n" ] && _n=$_e
  _lido=$(bri_ler)
  if perto "$_lido" "$_n"; then LED_ATUAL=$_n; BRIGOU_L=0; return 0; fi
  if ! bri_aplicar "$_n"; then
    BRIGOU_L=$(( BRIGOU_L + 1 ))
    [ "$BRIGOU_L" -ge "$DESISTE_APOS" ] && { : > "$LED_DESISTIU"; prop led "$LPERFIL:desistiu"; prop led_aviso hidebug; }
    return 0
  fi
  sleep 1
  _lido=$(bri_ler)
  if perto "$_lido" "$_n"; then LED_ATUAL=$_n; BRIGOU_L=0; prop led_aviso ""; return 0; fi
  BRIGOU_L=$(( BRIGOU_L + 1 ))
  LOG "[AVISO] o brilho nao ficou em $_n (lido '$(limpo "$_lido")') - $BRIGOU_L de $DESISTE_APOS."
  if [ "$BRIGOU_L" -ge "$DESISTE_APOS" ]; then
    LOG "[AVISO] o firmware briga com a curva do LED: desisto da curva ao vivo e solto o brilho."
    led_solta
    LED_ATUAL=""
    : > "$LED_DESISTIU"
    prop led "$LPERFIL:desistiu"; prop led_aviso firmware
  fi
}

ativo(){
  { [ -e "$VENT_ARQ" ] && [ ! -e "$VENT_DESISTIU" ]; } || { [ -e "$LED_ARQ" ] && [ ! -e "$LED_DESISTIU" ]; }
}

modo_laco(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - laco nao ligado."; exit 1; }
  echo "$$" > "$PID_LACO"
  trap sai_laco EXIT
  trap 'exit 0' INT TERM HUP
  FALHA_T=0; BRIGOU_V=0; BRIGOU_L=0; FAN_ATUAL=""; LED_ATUAL=""; PAUSADO=0; TEMP_OK=0; TEMP10=0
  VOLTA=0
  estado_props
  while ativo; do
    if [ -d "$LOCK" ]; then
      if [ "$PAUSADO" != 1 ]; then
        LOG "a suite esta rodando (trava): ventiladores em 1000 e brilho solto ate ela terminar."
        [ -e "$VENT_ARQ" ] && fans_segura
        [ -e "$LED_ARQ" ] && led_solta
        FAN_ATUAL=""; LED_ATUAL=""; PAUSADO=1
      fi
    else
      PAUSADO=0
      if le_temp; then TEMP_OK=1; else TEMP_OK=0; fi
      ciclo_vent
      ciclo_led
    fi
    VOLTA=$(( VOLTA + 1 ))
    [ "$VOLTAS" != 0 ] && [ "$VOLTA" -ge "$VOLTAS" ] && break
    sleep "$INTERVALO"
  done
  exit 0
}

pedido_palavras(){
  PALAVRAS=$(printf '%s' "$1" | tr -d '\r\n' | tr -cd 'a-z0-9: ' | cut -c1-200)
}

modo_pedido_vent(){
  pedido_palavras "$1"
  # shellcheck disable=SC2086
  set -- $PALAVRAS
  _ver=${1:-}; _perfil=${2:-}; _modo=${3:-}
  if [ "$#" -ge 3 ]; then shift 3; else set --; fi
  case "$_ver|$_modo" in
    v1\|vivo|v1\|gravar|v1\|ambos) ;;
    *) LOG "[AVISO] pedido de curva dos ventiladores recusado (formato '$(limpo "$PALAVRAS" 60)') - ventiladores em 1000."
       trava || exit 1
       parar_vent; prop vent padrao; prop vent_aviso pedido
       destrava; exit 0 ;;
  esac
  case "$_perfil" in silencioso|balanceado|agressivo|manual) ;; *)
    LOG "[AVISO] perfil '$(limpo "$_perfil" 20)' desconhecido - ventiladores em 1000."
    trava || exit 1
    parar_vent; prop vent padrao; prop vent_aviso pedido
    destrava; exit 0 ;;
  esac
  if ! vent_valida "$@"; then
    LOG "[AVISO] curva dos ventiladores recusada (fora das travas: 25 a 66 C, 30 a 100 por cento de 5 em 5, nao decrescente, 100 por cento no ultimo ponto) - ventiladores em 1000."
    trava || exit 1
    parar_vent; prop vent padrao; prop vent_aviso pedido
    destrava; exit 0
  fi
  if [ "$_perfil" = agressivo ]; then
    for _vv in "$VV1" "$VV2" "$VV3" "$VV4" "$VV5"; do
      if [ "$_vv" != 100 ]; then
        LOG "[AVISO] perfil agressivo precisa ser 100 por cento em todos os pontos - ventiladores em 1000."
        trava || exit 1
        parar_vent; prop vent padrao; prop vent_aviso pedido
        destrava; exit 0
      fi
    done
  fi
  trava || { LOG "[ERRO] nao peguei a trava das curvas."; exit 1; }
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root."; destrava; exit 1; }
  prop vent_aviso ""
  if [ "$_perfil" = agressivo ]; then
    parar_vent
    prop vent "agressivo:$_modo"
  else
    case "$_modo" in
      gravar) parar_vent; prop vent padrao ;;
      *)
        rm -f "$VENT_DESISTIU"
        escreve_conf "$VENT_ARQ" "v1 $_perfil vivo $VT1:$VV1 $VT2:$VV2 $VT3:$VV3 $VT4:$VV4 $VT5:$VV5"
        prop vent "$_perfil:vivo"
        laco_ligar ;;
    esac
    case "$_modo" in gravar|ambos)
      LOG "[AVISO] a curva dos ventiladores nao e gravada no ZYCustom.ini: FW_SPEED_CURVE e a tabela velocidade->duty do firmware, nao uma curva por temperatura (doc 49 sec. 4.3). Ini intacto."
      prop vent_aviso gravar ;;
    esac
  fi
  LOG "curva dos ventiladores: perfil $_perfil, modo $_modo"
  destrava
  exit 0
}

modo_pedido_led(){
  pedido_palavras "$1"
  # shellcheck disable=SC2086
  set -- $PALAVRAS
  _ver=${1:-}; _perfil=${2:-}; _modo=${3:-}
  if [ "$#" -ge 3 ]; then shift 3; else set --; fi
  case "$_ver|$_modo" in
    v1\|vivo|v1\|gravar|v1\|ambos) ;;
    *) LOG "[AVISO] pedido de curva do LED recusado (formato '$(limpo "$PALAVRAS" 60)') - brilho solto."
       trava || exit 1
       parar_led; prop led padrao; prop led_aviso pedido
       destrava; exit 0 ;;
  esac
  case "$_perfil" in padrao|silencioso|manual) ;; *)
    LOG "[AVISO] perfil '$(limpo "$_perfil" 20)' desconhecido - brilho solto."
    trava || exit 1
    parar_led; prop led padrao; prop led_aviso pedido
    destrava; exit 0 ;;
  esac
  if [ "$_perfil" != padrao ] && ! led_valida "$@"; then
    LOG "[AVISO] curva do LED recusada (fora das travas: 40 a 69 C, 850 a 1000 de 10 em 10, nao crescente, nunca acima da escada do firmware de 66 C; 70 e 75 C intocaveis) - brilho solto."
    trava || exit 1
    parar_led; prop led padrao; prop led_aviso pedido
    destrava; exit 0
  fi
  trava || { LOG "[ERRO] nao peguei a trava das curvas."; exit 1; }
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root."; destrava; exit 1; }
  prop led_aviso ""
  _ini=ok
  case "$_modo" in gravar|ambos)
    if [ "$_perfil" = padrao ]; then
      W_LIM="$LED_LIM_CANON"; W_BRI="$LED_BRI_CANON"
    else
      W_LIM="$(( LT1 * 1000 )), $(( LT2 * 1000 )), $(( LT3 * 1000 )), 70000, 71500, 73000"
      W_BRI=$(printf '%4d, %4d, %4d, %4d, %4d, %4d' "$LB1" "$LB2" "$LB3" "$LED_MIN" "$LED_MIN" "$LED_MIN")
    fi
    ini_escrever || _ini=falhou
    W_LIM=""; W_BRI=""
  ;; esac
  if [ "$_perfil" = padrao ]; then
    parar_led
    prop led "padrao:$_modo"
  else
    case "$_modo" in
      gravar) parar_led; if [ "$_ini" = ok ]; then prop led "$_perfil:gravada"; else prop led padrao; fi ;;
      *)
        rm -f "$LED_DESISTIU"
        escreve_conf "$LED_ARQ" "v1 $_perfil $_modo $LT1:$LB1 $LT2:$LB2 $LT3:$LB3"
        prop led "$_perfil:$_modo"
        laco_ligar ;;
    esac
  fi
  [ "$_ini" = ok ] || prop led_aviso ini
  LOG "curva do LED: perfil $_perfil, modo $_modo, ini $_ini"
  destrava
  exit 0
}

standby_cancelar(){
  _p=$(head -n 1 "$PID_STANDBY" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  if [ -n "$_p" ] && grep -aq 'pfl7560' "/proc/$_p/cmdline" 2>/dev/null; then kill "$_p" 2>/dev/null; fi
  rm -f "$PID_STANDBY"
  prop standby ""
}
sonhando(){ timeout 10 dumpsys power 2>/dev/null | grep -aq 'mWakefulness=Dreaming'; }
standby_desiste(){
  LOG "o descanso nao esta mais na tela (dumpsys power sem Dreaming): standby cancelado, nada feito."
  rm -f "$PID_STANDBY"; prop standby ""
  exit 0
}
standby_vigia(){
  echo "$$" > "$PID_STANDBY"
  trap 'rm -f "$PID_STANDBY"; exit 0' INT TERM HUP
  _s=0
  while [ "$_s" -lt "$STANDBY_AVISO" ]; do sleep 5; _s=$(( _s + 5 )); done
  sonhando || standby_desiste
  prop standby aviso
  LOG "descanso ativo ha $STANDBY_AVISO s: aviso de standby na tela"
  while [ "$_s" -lt "$STANDBY_TOTAL" ]; do sleep 5; _s=$(( _s + 5 )); done
  if [ -d "$LOCK" ]; then
    LOG "a suite esta rodando (trava): standby adiado, nada feito."
    rm -f "$PID_STANDBY"; prop standby ""
    exit 0
  fi
  sonhando || standby_desiste
  prop standby agora
  LOG "standby pelo descanso: KEYCODE_POWER, o mesmo do botao do controle (doc 49 sec. 4.4: desliga o aparelho)"
  input keyevent KEYCODE_POWER >/dev/null 2>&1
  rm -f "$PID_STANDBY"
  sleep 2
  prop standby ""
  exit 0
}
standby_inicio(){
  standby_cancelar
  if command -v setsid >/dev/null 2>&1; then
    setsid sh "$SUITE/suite-curvas.sh" standby-vigia >>"$SUITE/curvas.log" 2>&1 </dev/null &
  else
    nohup sh "$SUITE/suite-curvas.sh" standby-vigia >>"$SUITE/curvas.log" 2>&1 </dev/null &
  fi
  echo "$!" > "$PID_STANDBY"
  LOG "vigia do standby ligado (pid $!): aviso aos $STANDBY_AVISO s, standby aos $STANDBY_TOTAL s"
}

lista_debloat(){
  arq_seguro "$LISTA_ARQ" || return 1
  sed 's/#.*$//' "$LISTA_ARQ" 2>/dev/null | tr -d '\r \t' | grep -E '^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$' \
    | grep -v -E '^(android\.|com\.android\.|com\.google\.android\.(gms|gsf)|com\.pfl7560\.|com\.zhiying\.)' | head -n 40
}
debloat_reverter(){
  _lista=$(lista_debloat) || { LOG "debloat: lista ausente ou insegura - nada a religar."; return 0; }
  _dis=$(timeout 15 pm list packages -d 2>/dev/null)
  for _ap in $_lista; do
    if printf '%s\n' "$_dis" | grep -qx "package:$_ap"; then
      if timeout 15 pm enable --user 0 "$_ap" >/dev/null 2>&1; then LOG "debloat: $_ap religado (pm enable)"; else LOG "[AVISO] debloat: nao consegui religar $_ap."; fi
    fi
  done
}

case "${1:-}" in
  ini-ok) ini_aceito "${2:-}"; exit $? ;;
  ini-base) ini_base "${2:-}"; exit $? ;;
  ini-norm) ini_md5_norm "${2:-}"; exit $? ;;
  debloat-lista) lista_debloat; exit $? ;;
  debloat-reverter) debloat_reverter; exit 0 ;;
esac

dir_seguro "$SUITE" || { echo "[PFL7560-curvas] [ERRO] $SUITE nao e uma pasta so do root - nada feito."; exit 1; }
exec >>"$SUITE/curvas.log" 2>&1 </dev/null
case "${1:-}" in
  laco) modo_laco ;;
  pedido)
    case "${2:-}" in
      vent) modo_pedido_vent "${3:-}" ;;
      led) modo_pedido_led "${3:-}" ;;
    esac
    exit 0 ;;
  boot)
    prop standby ""
    rm -f "$PID_STANDBY"
    estado_props
    if ativo; then laco_ligar; fi
    exit 0 ;;
  parar)
    trava || exit 1
    parar_vent; parar_led; prop vent padrao; prop led padrao
    destrava
    exit 0 ;;
  standby-inicio) standby_inicio; exit 0 ;;
  standby-cancelar) standby_cancelar; exit 0 ;;
  standby-vigia) standby_vigia ;;
esac
exit 0
