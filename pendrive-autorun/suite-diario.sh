#!/vendor/bin/sh
# suite-diario.sh - o diario do projetor (bloco 24), lado root.
#
# Uma linha por minuto com as props e leituras baratas do aparelho, para o PC
# buscar por adb (pfl7560-diario.sh) e o dono ver depois o que aconteceu, mesmo
# com o aparelho desligado e ligado no meio. Dois arquivos que se revezam
# (diario-0.txt e diario-1.txt, ate 256 KB cada): quando o atual enche, o outro
# e zerado e vira o atual. A linha e ASCII, chave=valor, sem espaco nos valores:
#   up dt boot env placa luz load vent led wifi eth mem ch ev
# "ev" traz as mudancas de chave que o suite-chaves.sh anotou na fila
# ($SUITE/diario.fila) desde a ultima linha. Nao usa hidebug, nao usa gtt, nao
# le o logcat: so getprop e arquivos de /proc e /sys.
#
#   iniciar        liga o laco de 1 linha/min (se o dono nao desligou o diario)
#   laco           o laco em si (iniciar o lanca destacado)
#   uma-linha      grava UMA linha agora
#   ligar|desligar o dono liga ou desliga (desligar para o laco; a marca vale no boot)
#   enviar         so MARCA o pedido de envio; quem busca e o PC
#   enviado <data> o PC avisa que buscou (AAAA-MM-DDTHH:MM:SS, hora do PC)
#   pedido "v1 ligar|desligar|enviar|ler"   o que a home manda
#   ler            publica vendor.pfl7560.diario e diario_envio
#   parar          so para o laco (a desinstalacao usa)
#
# Props: vendor.pfl7560.diario = "<1|0>:<bytes>:<pedido 0|1>"
#        vendor.pfl7560.diario_envio = data do ultimo envio ("" = nunca)

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_DIARIO_VOLTAS PFL_DIARIO_INTERVALO PFL_DIARIO_MAX
fi
LC_ALL=C; export LC_ALL
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
DIR="$SUITE/diario"
PONTEIRO="$SUITE/diario.atual"
DESLIGADO="$SUITE/diario.desligado"
VISTO="$SUITE/diario.visto"
FILA="$SUITE/diario.fila"
PEDIDO_ENVIO="$SUITE/diario.envio"
ULTIMO_ENVIO="$SUITE/diario.ultimo-envio"
PIDF="$R/dev/pfl7560-diario.pid"
UPTIME="$R/proc/uptime"
LOADAVG="$R/proc/loadavg"
MEMINFO="$R/proc/meminfo"
BOOTID="$R/proc/sys/kernel/random/boot_id"
NET="$R/sys/class/net"
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
MAX_ARQ=262144
INTERVALO=60
VOLTAS=0
if [ "${PFL_TESTE:-}" = "1" ]; then
  [ -n "${PFL_DIARIO_MAX:-}" ] && MAX_ARQ="$PFL_DIARIO_MAX"
  [ -n "${PFL_DIARIO_INTERVALO:-}" ] && INTERVALO="$PFL_DIARIO_INTERVALO"
  [ -n "${PFL_DIARIO_VOLTAS:-}" ] && VOLTAS="$PFL_DIARIO_VOLTAS"
fi
EV_MAX=5

LOG(){ echo "[PFL7560-diario] $*"; }
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
# um valor da linha: so os caracteres de uma lista, no maximo N, "-" se vazio
campo(){
  _c=$(printf '%s' "$1" | tr -cd "$2" | cut -c1-"$3")
  printf '%s' "${_c:--}"
}
prop(){ setprop "vendor.pfl7560.$1" "$2" 2>/dev/null; }

preparar(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - diario nao mexido."; return 1; }
  if [ -L "$DIR" ]; then rm -f "$DIR"; fi
  if [ ! -d "$DIR" ]; then ( umask 077; mkdir "$DIR" ) 2>/dev/null || return 1; fi
  chmod 700 "$DIR" 2>/dev/null
  dir_seguro "$DIR"
}
tamanho_de(){
  _t=0
  for _f in "$DIR/diario-0.txt" "$DIR/diario-1.txt"; do
    if [ ! -f "$_f" ] || [ -L "$_f" ]; then continue; fi
    _b=$(wc -c < "$_f" 2>/dev/null | tr -cd '0-9')
    _t=$(( _t + ${_b:-0} ))
  done
  printf '%s' "$_t"
}
publicar(){
  _lig=1; [ -e "$DESLIGADO" ] && _lig=0
  _ped=0; [ -e "$PEDIDO_ENVIO" ] && _ped=1
  _env=""
  arq_seguro "$ULTIMO_ENVIO" && _env=$(head -c 40 "$ULTIMO_ENVIO" 2>/dev/null | tr -cd '0-9T:-')
  prop diario "$_lig:$(tamanho_de):$_ped"
  prop diario_envio "$_env"
}

# ---- a fila de eventos das chaves ---------------------------------------
# devolve "id:acao:resultado,..." das linhas novas (ate EV_MAX) e marca como vista
eventos(){
  EV="-"
  arq_seguro "$FILA" || return 0
  _ult=$(tail -n 1 "$FILA" 2>/dev/null)
  [ -n "$_ult" ] || return 0
  _vis=""
  arq_seguro "$VISTO" && _vis=$(head -n 1 "$VISTO" 2>/dev/null)
  _n=0
  if [ -n "$_vis" ]; then
    _n=$(grep -nxF -- "$_vis" "$FILA" 2>/dev/null | tail -n 1 | cut -d: -f1 | tr -cd '0-9')
    _n=${_n:-0}
  fi
  [ "$_vis" = "$_ult" ] && return 0
  _lista=""; _q=0; _mais=0
  _novas=$(tail -n +$(( _n + 1 )) "$FILA" 2>/dev/null)
  while read -r _u _id _ac _rs _x; do
    if [ -z "$_rs" ] || [ -n "$_x" ]; then continue; fi
    _q=$(( _q + 1 ))
    if [ "$_q" -le "$EV_MAX" ]; then
      _e="$(campo "$_id" 'a-z0-9_' 12):$(campo "$_ac" 'a-z' 10):$(campo "$_rs" 'a-z0-9-' 12)"
      _lista="${_lista:+$_lista,}$_e"
    else
      _mais=$(( _mais + 1 ))
    fi
  done <<EOF_FILA
$_novas
EOF_FILA
  [ "$_mais" -gt 0 ] && _lista="$_lista,+$_mais"
  [ -n "$_lista" ] && EV="$_lista"
  ( umask 077; printf '%s\n' "$_ult" > "$VISTO.novo" ) && mv -f "$VISTO.novo" "$VISTO"
}
marcar_fila_vista(){
  arq_seguro "$FILA" || { rm -f "$VISTO"; return 0; }
  _ult=$(tail -n 1 "$FILA" 2>/dev/null)
  [ -n "$_ult" ] || { rm -f "$VISTO"; return 0; }
  ( umask 077; printf '%s\n' "$_ult" > "$VISTO.novo" ) && mv -f "$VISTO.novo" "$VISTO"
}

# ---- a linha --------------------------------------------------------------
montar_linha(){
  _up=$(cut -d' ' -f1 "$UPTIME" 2>/dev/null | cut -d. -f1)
  _dt=$(date +%s 2>/dev/null)
  _bt=$(head -n 1 "$BOOTID" 2>/dev/null | tr -d '-')
  _ld=$(cut -d' ' -f1 "$LOADAVG" 2>/dev/null)
  _mm=$(sed -n 's/^MemAvailable: *\([0-9]*\) kB.*$/\1/p' "$MEMINFO" 2>/dev/null | head -n 1)
  _wf=$(head -n 1 "$NET/wlan0/operstate" 2>/dev/null)
  _et=$(head -n 1 "$NET/eth0/operstate" 2>/dev/null)
  eventos
  printf 'up=%s dt=%s boot=%s env=%s placa=%s luz=%s load=%s vent=%s led=%s wifi=%s eth=%s mem=%s ch=%s ev=%s' \
    "$(campo "$_up" 0-9 10)" "$(campo "$_dt" 0-9 12)" "$(campo "$_bt" 0-9a-f 8)" \
    "$(campo "$(getprop zysys.env_temp 2>/dev/null)" 0-9. 6)" "$(campo "$(getprop zysys.light_temp 2>/dev/null)" 0-9. 6)" \
    "$(campo "$(getprop vendor.pfl7560.luz 2>/dev/null)" 0-9 3)" "$(campo "$_ld" 0-9. 6)" \
    "$(campo "$(getprop vendor.pfl7560.vent 2>/dev/null)" 'a-z0-9:_' 20)" "$(campo "$(getprop vendor.pfl7560.led 2>/dev/null)" 'a-z0-9:_' 20)" \
    "$(campo "$_wf" a-z 8)" "$(campo "$_et" a-z 8)" "$(campo "$_mm" 0-9 9)" \
    "$(campo "$(getprop vendor.pfl7560.chaves 2>/dev/null)" '01p?-' 16)" "$EV"
}
gravar_linha(){
  _a=$(head -c 2 "$PONTEIRO" 2>/dev/null | tr -cd '01' | cut -c1)
  _a=${_a:-0}
  _arq="$DIR/diario-$_a.txt"
  [ -L "$_arq" ] && rm -f "$_arq"
  _t=$(wc -c < "$_arq" 2>/dev/null | tr -cd '0-9')
  _t=${_t:-0}
  if [ $(( _t + ${#1} + 1 )) -gt "$MAX_ARQ" ] && [ "$_t" -gt 0 ]; then
    _a=$(( 1 - _a ))
    _arq="$DIR/diario-$_a.txt"
    [ -L "$_arq" ] && rm -f "$_arq"
    ( umask 077; : > "$_arq" )
    ( umask 077; printf '%s\n' "$_a" > "$PONTEIRO.novo" ) && mv -f "$PONTEIRO.novo" "$PONTEIRO"
  fi
  ( umask 077; printf '%s\n' "$1" >> "$_arq" )
}

cmd_uma_linha(){
  [ -e "$DESLIGADO" ] && return 0
  preparar || return 1
  _linha=$(montar_linha)
  gravar_linha "$_linha"
  publicar
}

# ---- o laco ---------------------------------------------------------------
laco_vivo(){
  _p=$(head -n 1 "$PIDF" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  [ -n "$_p" ] && grep -aq 'suite-diario' "/proc/$_p/cmdline" 2>/dev/null
}
cmd_laco(){
  dir_seguro "$SUITE" || exit 1
  if laco_vivo && [ "$(head -n 1 "$PIDF" 2>/dev/null | tr -cd '0-9')" != "$$" ]; then
    LOG "ja existe um laco vivo - este sai"
    exit 0
  fi
  echo "$$" > "$PIDF"
  _v=0
  while :; do
    [ -e "$DESLIGADO" ] && break
    cmd_uma_linha
    _v=$(( _v + 1 ))
    [ "$VOLTAS" != "0" ] && [ "$_v" -ge "$VOLTAS" ] && break
    sleep "$INTERVALO"
  done
  [ "$(head -n 1 "$PIDF" 2>/dev/null | tr -cd '0-9')" = "$$" ] && rm -f "$PIDF"
}
cmd_iniciar(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - diario nao ligado."; return 1; }
  if [ -e "$DESLIGADO" ]; then LOG "diario desligado pelo dono - laco nao lancado"; publicar; return 0; fi
  if laco_vivo; then LOG "laco do diario ja vivo - nada a fazer"; publicar; return 0; fi
  if command -v setsid >/dev/null 2>&1; then
    setsid sh "$SUITE/suite-diario.sh" laco >>"$SUITE/diario.log" 2>&1 </dev/null &
  else
    nohup sh "$SUITE/suite-diario.sh" laco >>"$SUITE/diario.log" 2>&1 </dev/null &
  fi
  echo "$!" > "$PIDF"
  LOG "laco do diario lancado (pid $!)"
}
cmd_parar(){
  _p=$(head -n 1 "$PIDF" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  if [ -n "$_p" ] && grep -aq 'suite-diario' "/proc/$_p/cmdline" 2>/dev/null; then kill "$_p" 2>/dev/null; fi
  rm -f "$PIDF"
}

# ---- o dono ---------------------------------------------------------------
cmd_ligar(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - nada feito."; return 1; }
  rm -f "$DESLIGADO"
  marcar_fila_vista
  cmd_iniciar
  publicar
}
cmd_desligar(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - nada feito."; return 1; }
  ( umask 077; : > "$DESLIGADO" )
  cmd_parar
  publicar
}
cmd_enviar(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - nada feito."; return 1; }
  [ -L "$PEDIDO_ENVIO" ] && rm -f "$PEDIDO_ENVIO"
  ( umask 077; date +%s > "$PEDIDO_ENVIO" )
  publicar
}
cmd_enviado(){
  dir_seguro "$SUITE" || return 1
  if [ "${#1}" != 19 ] || ! printf '%s' "$1" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'; then
    LOG "[AVISO] data de envio invalida ('$(printf '%s' "$1" | tr -cd ' -~' | cut -c1-24)') - ignorada."
    return 1
  fi
  [ -L "$ULTIMO_ENVIO" ] && rm -f "$ULTIMO_ENVIO"
  ( umask 077; printf '%s\n' "$1" > "$ULTIMO_ENVIO.novo" ) && mv -f "$ULTIMO_ENVIO.novo" "$ULTIMO_ENVIO"
  rm -f "$PEDIDO_ENVIO"
  publicar
}
cmd_pedido(){
  # shellcheck disable=SC2086
  set -- $1
  if [ "${1:-}" != "v1" ] || [ "$#" != 2 ]; then LOG "[AVISO] pedido do diario mal formado - recusado."; return 0; fi
  case "$2" in
    ligar) cmd_ligar ;;
    desligar) cmd_desligar ;;
    enviar) cmd_enviar ;;
    ler) publicar ;;
    *) LOG "[AVISO] pedido do diario desconhecido - recusado." ;;
  esac
  return 0
}

case "${1:-}" in
  iniciar) cmd_iniciar; exit $? ;;
  laco) cmd_laco; exit 0 ;;
  uma-linha) cmd_uma_linha; exit $? ;;
  ligar) cmd_ligar; exit $? ;;
  desligar) cmd_desligar; exit $? ;;
  enviar) cmd_enviar; exit $? ;;
  enviado) cmd_enviado "${2:-}"; exit $? ;;
  ler) publicar; exit 0 ;;
  parar) cmd_parar; exit 0 ;;
  pedido) dir_seguro "$SUITE" || exit 1; exec >>"$SUITE/diario.log" 2>&1 </dev/null; cmd_pedido "${2:-}"; exit 0 ;;
  *) echo "uso: suite-diario.sh iniciar|laco|uma-linha|ligar|desligar|enviar|enviado <data>|ler|parar|pedido <txt>"; exit 2 ;;
esac
