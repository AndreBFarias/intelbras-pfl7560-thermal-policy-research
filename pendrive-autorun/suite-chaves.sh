#!/vendor/bin/sh
# suite-chaves.sh - as chaves de ajuste do sistema (bloco 24), lado root.
#
# Cada chave e uma MEDIDA que so o dono liga pela home: "ligada" quer dizer
# "a medida esta aplicada". O estado e lido do aparelho (nunca suposto), a
# escolha do dono fica em $SUITE/chaves.escolhas e o boot reaplica o que ela
# escolheu. Um arquivo no pendrive (DESLIGAR-CHAVES.txt) desliga todas.
#
#   ler                         publica vendor.pfl7560.chaves (um caractere por chave)
#   estado                      imprime a mesma sequencia (nao publica nada)
#   aplicar <id> ligar|desligar aplica, confere pela leitura, guarda a escolha
#   pedido "v1 ler|<id> ligar|<id> desligar"   o que a home manda
#   boot                        reaplica as escolhas (chamado pelo suite-boot.sh)
#   resgate                     desliga todas e grava a escolha 0 em todas
#   pacotes-fora                lista os pacotes de grupos que o dono DESLIGOU
#   ids                         lista os ids na ordem
#
# Caracteres do estado: 1 ligada, 0 desligada, p parcial, - ausente neste
# aparelho, ? ilegivel agora.

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_PM_TENTATIVAS PFL_PM_ESPERA
fi
LC_ALL=C; export LC_ALL
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
ESCOLHAS="$SUITE/chaves.escolhas"
FILA="$SUITE/diario.fila"
DEBLOAT_REVERTIDO="$SUITE/debloat-revertido"
CTRAVA="$R/dev/pfl7560-chaves.trava"
NET="$R/sys/class/net"
USBDEV="$R/sys/bus/usb/devices"
HOME_PKG="com.pfl7560.home"
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
PM_TENTATIVAS=40
PM_ESPERA=3
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_PM_TENTATIVAS:-}" ] && PM_TENTATIVAS="$PFL_PM_TENTATIVAS"
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_PM_ESPERA:-}" ] && PM_ESPERA="$PFL_PM_ESPERA"
FILA_MAX=60

IDS="deb_seg deb_ota deb_hisi deb_lnch deb_vlc log_vplug eth0 wifi_pwr web_cmd keystone pop_disp"
# o pop-up "Dispositivo conectado" (HDMI/USB-C) e do com.zhiying.settings: o
# receptor dele so mostra a janela se vendor.newlink.hisi.hdmiisdialog != 0
POP_PROP="vendor.newlink.hisi.hdmiisdialog"
BP="$R/vendor/build.prop"

LOG(){ echo "[PFL7560-chaves] $*"; }
limpo(){ printf '%s' "$1" | tr '\n\r\t;' '    ' | tr -cd ' -~' | cut -c1-"${2:-40}"; }
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
prop(){ setprop "vendor.pfl7560.$1" "$2" 2>/dev/null; }

id_valido(){
  for _iv in $IDS; do [ "$_iv" = "$1" ] && return 0; done
  return 1
}
# padrao ao instalar: 1 = ligada. So o que o dono aprovou na rodada 1.
padrao_de(){
  case "$1" in
    deb_seg|deb_ota|deb_hisi|deb_lnch|deb_vlc|log_vplug|pop_disp) echo 1 ;;
    *) echo 0 ;;
  esac
}

# ---- pacotes por grupo ----------------------------------------------------
# com.hisilicon.higallery NAO esta no grupo da HiSilicon: e o visor que abre as
# telas de calibracao da suite (suite.sh), desliga-lo quebraria a suite.
pacotes_do(){
  case "$1" in
    deb_seg) echo "com.newlink.autotest com.newlink.factorymenu com.newlink.tvtestingtools com.hikeymasterprovision com.newlink.isuperred.ijkplayerdemo com.android.location.fused" ;;
    deb_ota) echo "com.newlink.service com.newlink.service2" ;;
    deb_hisi) echo "com.hisilicon.android.music com.hisilicon.android.videoplayer com.hisilicon.tvui com.hisilicon.tv.menu" ;;
    deb_lnch) echo "com.newlink.hisilauncher" ;;
    deb_vlc) echo "com.mobisystems.editor.office_registered" ;;
  esac
}
# lista de negacao, vale para qualquer pacote, mesmo que a lista erre um dia
pacote_ok(){
  case "$1" in
    ''|*[!a-zA-Z0-9._]*) return 1 ;;
    com.android.location.fused) return 0 ;;
    android|android.*|com.android.*|com.google.android.gms*|com.google.android.gsf*) return 1 ;;
    com.pfl7560.*|com.zhiying.*) return 1 ;;
    com.hisilicon.higallery|com.hisilicon.tvsetting|com.hisilicon.tvinput*|com.hisilicon.tv.service) return 1 ;;
    com.newlink.screensaver|com.newlink.nlprovision|com.newlink.hotkeysservices|com.newlink.filemanager|com.newlink.nlsource|com.newlink.wtprovision|com.newlink.rmservice) return 1 ;;
  esac
  return 0
}

# ---- escolhas do dono -----------------------------------------------------
escolha_de(){
  arq_seguro "$ESCOLHAS" || return 0
  sed -n "s/^$1=\\([01]\\)\$/\\1/p" "$ESCOLHAS" 2>/dev/null | tail -n 1
}
gravar_escolha(){
  dir_seguro "$SUITE" || return 1
  [ -L "$ESCOLHAS" ] && rm -f "$ESCOLHAS"
  (
    umask 077
    { grep -v "^$1=" "$ESCOLHAS" 2>/dev/null; printf '%s=%s\n' "$1" "$2"; } > "$ESCOLHAS.novo"
  ) && mv -f "$ESCOLHAS.novo" "$ESCOLHAS"
}
# 1 se o boot deve deixar a chave ligada, 0 se nao
quer_ligado(){
  _qe=$(escolha_de "$1")
  if [ -n "$_qe" ]; then echo "$_qe"; return 0; fi
  if [ "$1" = "deb_vlc" ] && [ -e "$DEBLOAT_REVERTIDO" ]; then echo 0; return 0; fi
  padrao_de "$1"
}

# ---- leitura do aparelho --------------------------------------------------
PM_OK=0
PM_TODOS=""
PM_DIS=""
carregar_pm(){
  PM_TODOS=$(timeout 15 pm list packages 2>/dev/null)
  if printf '%s\n' "$PM_TODOS" | grep -qx 'package:android'; then
    PM_OK=1
    PM_DIS=$(timeout 15 pm list packages -d 2>/dev/null)
  else
    PM_OK=0
  fi
}
esperar_pm(){
  _pt=1
  while :; do
    carregar_pm
    [ "$PM_OK" = "1" ] && return 0
    [ "$_pt" -ge "$PM_TENTATIVAS" ] && return 1
    _pt=$(( _pt + 1 ))
    sleep "$PM_ESPERA"
  done
}
estado_pacotes(){
  [ "$PM_OK" = "1" ] || { echo '?'; return 0; }
  _ni=0; _nd=0
  for _p in $(pacotes_do "$1"); do
    printf '%s\n' "$PM_TODOS" | grep -qx "package:$_p" || continue
    _ni=$(( _ni + 1 ))
    printf '%s\n' "$PM_DIS" | grep -qx "package:$_p" && _nd=$(( _nd + 1 ))
  done
  if [ "$_ni" = 0 ]; then echo '-'
  elif [ "$_nd" = 0 ]; then echo 0
  elif [ "$_nd" = "$_ni" ]; then echo 1
  else echo p; fi
}
estado_eth0(){
  [ -d "$NET/eth0" ] || { echo '-'; return 0; }
  _fl=$(head -n 1 "$NET/eth0/flags" 2>/dev/null | tr -cd '0-9a-fA-Fx')
  case "$_fl" in '') echo '?'; return 0 ;; esac
  _ult=${_fl#"${_fl%?}"}
  case "$_ult" in
    1|3|5|7|9|b|B|d|D|f|F) echo 0 ;;
    *) echo 1 ;;
  esac
}
# acha o USB do AIC8800 pelo id (nunca pelo 1-3 fixo)
achar_wifi(){
  WIFI_DEV=""
  for _d in "$USBDEV"/*; do
    case "${_d##*/}" in *:*) continue ;; esac
    [ -d "$_d" ] || continue
    _vid=$(head -n 1 "$_d/idVendor" 2>/dev/null | tr -cd '0-9a-fA-F')
    _pid=$(head -n 1 "$_d/idProduct" 2>/dev/null | tr -cd '0-9a-fA-F')
    [ "$_vid" = "a69c" ] || continue
    case "$_pid" in 8d80|8d81) ;; *) continue ;; esac
    WIFI_DEV="$_d"
    return 0
  done
  return 1
}
estado_wifi(){
  achar_wifi || { echo '-'; return 0; }
  _pc=$(head -n 1 "$WIFI_DEV/power/control" 2>/dev/null | tr -cd '[:lower:]')
  case "$_pc" in
    auto) echo 1 ;;
    on) echo 0 ;;
    *) echo '?' ;;
  esac
}
estado_web(){
  _na=0; _ns=0
  for _sv in boa cmdsrv; do
    _st=$(getprop "init.svc.$_sv" 2>/dev/null | tr -cd '[:lower:]')
    case "$_st" in
      '') continue ;;
      stopped) _ns=$(( _ns + 1 )); _na=$(( _na + 1 )) ;;
      *) _na=$(( _na + 1 )) ;;
    esac
  done
  if [ "$_na" = 0 ]; then echo '-'
  elif [ "$_ns" = 0 ]; then echo 0
  elif [ "$_ns" = "$_na" ]; then echo 1
  else echo p; fi
}
estado_de(){
  case "$1" in
    deb_*) estado_pacotes "$1" ;;
    log_vplug)
      _lt=$(getprop log.tag.HI_VPLUGIN 2>/dev/null | tr -cd '[:upper:]')
      if [ "$_lt" = "S" ]; then echo 1; else echo 0; fi ;;
    eth0) estado_eth0 ;;
    wifi_pwr) estado_wifi ;;
    web_cmd) estado_web ;;
    keystone)
      _ks=$(getprop persist.hisi.keystone.enable 2>/dev/null | tr -cd '[:lower:]')
      if [ "$_ks" = "false" ]; then echo 1; else echo 0; fi ;;
    pop_disp)
      _pd=$(getprop "$POP_PROP" 2>/dev/null | tr -cd '0-9')
      if [ -z "$_pd" ]; then echo '-'; elif [ "$_pd" = 0 ]; then echo 1; else echo 0; fi ;;
  esac
}
estado_todos(){
  _need=0
  for _i in $IDS; do case "$_i" in deb_*) _need=1 ;; esac; done
  [ "$_need" = 1 ] && carregar_pm
  _s=""
  for _i in $IDS; do _s="$_s$(estado_de "$_i")"; done
  printf '%s' "$_s"
}
publicar(){
  _e=$(estado_todos)
  prop chaves "$_e"
  printf '%s\n' "$_e"
}
avisar(){
  prop chaves_aviso "$1:$2:$(date +%s 2>/dev/null | tr -cd '0-9')"
  LOG "$1: $2"
}
fila_anotar(){
  dir_seguro "$SUITE" || return 0
  _up=$(cut -d' ' -f1 /proc/uptime 2>/dev/null | cut -d. -f1 | tr -cd '0-9')
  [ -L "$FILA" ] && rm -f "$FILA"
  (
    umask 077
    printf '%s %s %s %s\n' "${_up:-0}" "$1" "$2" "$3" >> "$FILA"
    if [ "$(grep -c '' "$FILA" 2>/dev/null)" -gt "$FILA_MAX" ]; then
      tail -n "$FILA_MAX" "$FILA" > "$FILA.novo" && mv -f "$FILA.novo" "$FILA"
    fi
  )
}

# ---- aplicacao ------------------------------------------------------------
# retorno: 0 aplicou, 1 falhou, 2 recusou (nada foi mexido)
aplicar_pacotes(){
  _ap="$2"
  [ "$PM_OK" = "1" ] || carregar_pm
  [ "$PM_OK" = "1" ] || return 1
  if [ "$1" = "deb_lnch" ] && [ "$_ap" = "ligar" ]; then
    printf '%s\n' "$PM_TODOS" | grep -qx "package:$HOME_PKG" || { AVISO_COD="sem-home"; return 2; }
    printf '%s\n' "$PM_DIS" | grep -qx "package:$HOME_PKG" && { AVISO_COD="sem-home"; return 2; }
  fi
  _falha=0
  for _p in $(pacotes_do "$1"); do
    pacote_ok "$_p" || { LOG "$_p recusado pela lista de negacao"; continue; }
    printf '%s\n' "$PM_TODOS" | grep -qx "package:$_p" || continue
    if [ "$_ap" = "ligar" ]; then
      timeout 15 pm disable-user --user 0 "$_p" >/dev/null 2>&1 || _falha=1
    else
      timeout 15 pm enable --user 0 "$_p" >/dev/null 2>&1 || _falha=1
    fi
  done
  carregar_pm
  return "$_falha"
}
aplicar_eth0(){
  [ -d "$NET/eth0" ] || { AVISO_COD="ausente"; return 2; }
  if [ "$1" = "ligar" ]; then _ld=down; else _ld=up; fi
  if command -v ip >/dev/null 2>&1; then
    timeout 15 ip link set eth0 "$_ld" >/dev/null 2>&1 || return 1
  elif command -v ifconfig >/dev/null 2>&1; then
    timeout 15 ifconfig eth0 "$_ld" >/dev/null 2>&1 || return 1
  else
    AVISO_COD="sem-ip"; return 2
  fi
  return 0
}
aplicar_wifi(){
  achar_wifi || { AVISO_COD="ausente"; return 2; }
  if [ "$1" = "ligar" ]; then _pv=auto; else _pv=on; fi
  printf '%s' "$_pv" > "$WIFI_DEV/power/control" 2>/dev/null
}
aplicar_web(){
  if [ "$1" = "ligar" ]; then _sa=stop; else _sa=start; fi
  _fw=0
  for _sv in boa cmdsrv; do
    [ -n "$(getprop "init.svc.$_sv" 2>/dev/null)" ] || continue
    timeout 15 "$_sa" "$_sv" >/dev/null 2>&1 || _fw=1
  done
  return "$_fw"
}
aplicar_chave(){
  AVISO_COD=""
  case "$1" in
    deb_*) aplicar_pacotes "$1" "$2" ;;
    log_vplug)
      if [ "$2" = "ligar" ]; then setprop log.tag.HI_VPLUGIN S 2>/dev/null; else setprop log.tag.HI_VPLUGIN "" 2>/dev/null; fi ;;
    eth0) aplicar_eth0 "$2" ;;
    wifi_pwr) aplicar_wifi "$2" ;;
    web_cmd) aplicar_web "$2" ;;
    keystone)
      if [ "$2" = "ligar" ]; then setprop persist.hisi.keystone.enable false 2>/dev/null; else setprop persist.hisi.keystone.enable true 2>/dev/null; fi ;;
    pop_disp)
      [ "$(estado_de pop_disp)" = "-" ] && return 0
      # nao e persist: o boot reaplica. Desligar devolve o valor do build.prop
      if [ "$2" = "ligar" ]; then setprop "$POP_PROP" 0 2>/dev/null
      else
        _pv=$(sed -n "s/^vendor\\.newlink\\.hisi\\.hdmiisdialog=//p" "$BP" 2>/dev/null | tail -n 1 | tr -cd '0-9' | cut -c1-3)
        case "$_pv" in ''|0) _pv=1 ;; esac
        setprop "$POP_PROP" "$_pv" 2>/dev/null
      fi ;;
  esac
}
# aplica, confere pela leitura e diz o resultado; $3 = guardar | nao
fazer(){
  _alvo=1; [ "$2" = "desligar" ] && _alvo=0
  _antes=$(estado_de "$1")
  aplicar_chave "$1" "$2"; _rc=$?
  _lido=$(estado_de "$1")
  if [ "$_rc" = 2 ]; then
    avisar "$1" "${AVISO_COD:-recusado}"
    fila_anotar "$1" "$2" recusado
    return 2
  fi
  # existia e sumiu com a mudanca (o chip Wi-Fi que cai do barramento ao dormir):
  # escolha 0, para o boot nao repetir; reiniciar devolve o aparelho
  if [ "$_lido" = "-" ] && [ "$_antes" != "-" ]; then
    gravar_escolha "$1" 0
    avisar "$1" sumiu
    fila_anotar "$1" "$2" sumiu
    return 1
  fi
  if [ "$_lido" = "-" ]; then
    [ "$3" = "guardar" ] && gravar_escolha "$1" "$_alvo"
    avisar "$1" ausente
    fila_anotar "$1" "$2" ausente
    return 0
  fi
  if [ "$_lido" = "$_alvo" ]; then
    [ "$3" = "guardar" ] && gravar_escolha "$1" "$_alvo"
    avisar "$1" ok
    fila_anotar "$1" "$2" ok
    return 0
  fi
  avisar "$1" "nao-confere-$_lido"
  fila_anotar "$1" "$2" "falhou"
  return 1
}

# ---- trava ----------------------------------------------------------------
trava(){
  _tk=0; _tmax="${1:-60}"
  while ! mkdir "$CTRAVA" 2>/dev/null; do
    _tp=$(head -n 1 "$CTRAVA/pid" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
    if [ -z "$_tp" ] || ! kill -0 "$_tp" 2>/dev/null; then rm -rf "$CTRAVA"; continue; fi
    _tk=$(( _tk + 1 ))
    [ "$_tk" -ge "$_tmax" ] && return 1
    sleep 1
  done
  echo "$$" > "$CTRAVA/pid"
}
destrava(){ rm -rf "$CTRAVA"; }

# ---- comandos -------------------------------------------------------------
cmd_boot(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - chaves nao reaplicadas."; return 1; }
  _pm=0
  for _i in $IDS; do
    case "$_i" in deb_*) [ "$(quer_ligado "$_i")" = 1 ] || [ "$(escolha_de "$_i")" = 0 ] && _pm=1 ;; esac
  done
  # espera o pm ANTES da trava: o resgate do pendrive (newlink_update.sh) sobe no
  # mesmo boot_completed e nao pode ficar parado atras desta espera
  if [ "$_pm" = 1 ] && ! esperar_pm; then LOG "[AVISO] o pm nao respondeu em $PM_TENTATIVAS consultas - grupos de apps nao reaplicados."; fi
  trava || { LOG "[AVISO] outra rodada das chaves esta em curso - boot nao reaplicou."; return 0; }
  [ "$PM_OK" = 1 ] && carregar_pm
  for _i in $IDS; do
    # a escolha pode ter mudado enquanto esperavamos (resgate do pendrive)
    _q=$(quer_ligado "$_i"); _e=$(escolha_de "$_i")
    case "$_i" in deb_*) [ "$PM_OK" = 1 ] || continue ;; esac
    _s=$(estado_de "$_i")
    case "$_s" in -|'?') continue ;; esac
    if [ "$_q" = 1 ] && [ "$_s" != 1 ]; then
      fazer "$_i" ligar nao
    elif [ "$_e" = 0 ] && [ "$_s" != 0 ]; then
      fazer "$_i" desligar nao
    fi
  done
  publicar >/dev/null
  destrava
}
cmd_resgate(){
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - resgate nao feito."; return 1; }
  # a escolha 0 vai antes da trava: o boot rele a escolha chave a chave e para de
  # ligar o que faltava, e o proximo boot desliga o que ja estava ligado
  for _i in $IDS; do gravar_escolha "$_i" 0; done
  trava 180 || { LOG "[ERRO] outra rodada das chaves esta em curso - escolhas gravadas em 0, mas nada desligado agora (o proximo boot desliga)."; return 1; }
  LOG "resgate: desligando todas as chaves"
  esperar_pm
  for _i in $IDS; do
    _s=$(estado_de "$_i")
    case "$_s" in 1|p) fazer "$_i" desligar guardar ;; *) gravar_escolha "$_i" 0 ;; esac
  done
  publicar >/dev/null
  destrava
}
cmd_aplicar(){
  id_valido "$1" || { LOG "[ERRO] chave desconhecida: '$(limpo "$1")'"; return 1; }
  case "$2" in ligar|desligar) ;; *) LOG "[ERRO] acao invalida: '$(limpo "$2")'"; return 1 ;; esac
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - nada feito."; return 1; }
  trava || { LOG "[AVISO] outra rodada das chaves esta em curso - pedido adiado."; return 1; }
  case "$1" in deb_*) carregar_pm ;; esac
  fazer "$1" "$2" guardar
  _r=$?
  publicar >/dev/null
  destrava
  return "$_r"
}
cmd_pedido(){
  # shellcheck disable=SC2086
  set -- $1
  [ "${1:-}" = "v1" ] || { LOG "[AVISO] pedido de chave sem v1 - recusado."; return 0; }
  if [ "${2:-}" = "ler" ] && [ "$#" = 2 ]; then publicar >/dev/null; return 0; fi
  [ "$#" = 3 ] || { LOG "[AVISO] pedido de chave mal formado - recusado."; return 0; }
  cmd_aplicar "$2" "$3"
  return 0
}
cmd_pacotes_fora(){
  for _i in $IDS; do
    case "$_i" in deb_*) ;; *) continue ;; esac
    [ "$(quer_ligado "$_i")" = 1 ] && continue
    pacotes_do "$_i" | tr ' ' '\n'
  done
}

case "${1:-}" in
  ler) publicar >/dev/null; exit 0 ;;
  estado) estado_todos; echo; exit 0 ;;
  ids) echo "$IDS"; exit 0 ;;
  aplicar) cmd_aplicar "${2:-}" "${3:-}"; exit $? ;;
  pedido) dir_seguro "$SUITE" || exit 1; exec >>"$SUITE/chaves.log" 2>&1 </dev/null; cmd_pedido "${2:-}"; exit 0 ;;
  boot) cmd_boot; exit $? ;;
  resgate) cmd_resgate; exit $? ;;
  pacotes-fora) cmd_pacotes_fora; exit 0 ;;
  *) echo "uso: suite-chaves.sh ler|estado|ids|aplicar <id> ligar|desligar|pedido <txt>|boot|resgate|pacotes-fora"; exit 2 ;;
esac
