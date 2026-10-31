#!/vendor/bin/sh

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_VIGIA_VOLTAS
fi
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
HIST="$SUITE/historico-boot.txt"
GATILHO_ARQ="$SUITE/gatilho"
FIM_ARQ="$SUITE/ultimo-fim"
INCOMPLETAS_ARQ="$SUITE/incompletas"
BOOT_LOG="$SUITE/boot.log"
LOCK="$R/dev/pfl7560-suite.lock"
VIGIA_PID="$R/dev/pfl7560-suite.vigia"
VERIF_DIR="$R/data/data/com.pfl7560.verificar"
HOME_DIR="$R/data/data/com.pfl7560.home"
MIDIA="$R/mnt/media_rw"
RTC="$R/sys/class/rtc/rtc0/since_epoch"
PM="$R/proc/msp/pm"
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"

# SUITE_MD5_INICIO
SUITE_MD5="2983b000f2d8149a6ac94906af112f10"
PEDIDO_MD5="8c437a30c525f49136fc3f3194ed2964"
# SUITE_MD5_FIM

MARCA_LIGADO="pfl7560,ligado"
ANO_MIN=2020
INTERVALO_MIN=600
INCOMPLETAS_MAX=2
ESPERA_MONTAGEM=20
HIST_MAX=30
VIGIA_INTERVALO=30
VIGIA_VOLTAS=0
LOG_MAX=200
[ -n "${PFL_RAPIDO:-}" ] && ESPERA_MONTAGEM=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_VIGIA_VOLTAS:-}" ] && VIGIA_VOLTAS="$PFL_VIGIA_VOLTAS"

LOG(){ echo "[PFL7560-suite-boot] $*"; }

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
confere(){ [ -n "$2" ] && arq_seguro "$1" && [ "$(md5_de "$1")" = "$2" ]; }
limpo(){ printf '%s' "$1" | tr '\n\r\t;' '    ' | tr -cd ' -~' | cut -c1-"${2:-120}"; }

ler_sinais(){
  S_BR=$(getprop sys.boot.reason 2>/dev/null)
  S_PBR=$(getprop persist.sys.boot.reason 2>/dev/null)
  S_RBR=$(getprop ro.boot.bootreason 2>/dev/null)
  S_RELOGIO=$(dmesg 2>/dev/null | grep -a 'setting system clock to' | head -1 | sed 's/^.*setting system clock to //')
  S_ANO=$(echo "$S_RELOGIO" | sed -n 's/^\([0-9][0-9][0-9][0-9]\)-.*$/\1/p')
  S_RTC=$(head -n 1 "$RTC" 2>/dev/null | tr -cd '0-9' | cut -c1-20)
  S_PM=$(head -n 12 "$PM" 2>/dev/null)
  S_INC=$(head -n 1 "$INCOMPLETAS_ARQ" 2>/dev/null | tr -cd '0-9' | cut -c1-4)
  S_INC=${S_INC:-0}
}

pendrive_presente(){
  for _d in "$MIDIA"/*; do
    [ -f "$_d/newlink_update.sh" ] && return 0
  done
  return 1
}
terminou_ha_pouco(){
  _fim=$(head -n 1 "$FIM_ARQ" 2>/dev/null | tr -cd '0-9' | cut -c1-20)
  _agora=$(date +%s 2>/dev/null | tr -cd '0-9')
  [ -n "$_fim" ] && [ -n "$_agora" ] || return 1
  [ "$_agora" -ge "$_fim" ] && [ $(( _agora - _fim )) -lt "$INTERVALO_MIN" ]
}
decidir(){
  DECISAO=nao; MOTIVO=""
  # shellcheck disable=SC2018
  GATILHO=$(head -1 "$GATILHO_ARQ" 2>/dev/null | tr -cd 'a-z')
  case "$GATILHO" in auto|sempre|nunca) ;; *) GATILHO=auto ;; esac
  if [ "$GATILHO" = "nunca" ]; then MOTIVO=gatilho_nunca; return 0; fi
  if [ "$S_INC" -ge "$INCOMPLETAS_MAX" ]; then MOTIVO="interrompida_${S_INC}x_seguidas"; return 0; fi
  if [ -d "$LOCK" ]; then MOTIVO=trava_ocupada; return 0; fi
  if terminou_ha_pouco; then MOTIVO=terminou_ha_menos_de_10min; return 0; fi
  _t=0
  while :; do
    if pendrive_presente; then MOTIVO=pendrive_do_kit_montado; return 0; fi
    [ "$_t" -ge "$ESPERA_MONTAGEM" ] && break
    sleep 2; _t=$(( _t + 2 ))
  done
  if [ "$GATILHO" = "sempre" ]; then DECISAO=sim; MOTIVO=gatilho_sempre; return 0; fi
  case "$S_PBR|$S_BR" in *"$MARCA_LIGADO"*) DECISAO=sim; MOTIVO=queda_de_energia; return 0 ;; esac
  if [ -n "$S_ANO" ] && [ "$S_ANO" -lt "$ANO_MIN" ]; then DECISAO=sim; MOTIVO=relogio_zerado; return 0; fi
  case "$S_BR" in
    shutdown,*|reboot,*) MOTIVO=desligamento_limpo ;;
    *) DECISAO=sim; MOTIVO=desligamento_nao_limpo ;;
  esac
}

registrar(){
  _l="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null); boot_reason=$(limpo "$S_BR"); persist_boot_reason=$(limpo "$S_PBR"); ro_bootreason=$(limpo "$S_RBR"); relogio_boot=$(limpo "$S_RELOGIO"); ano_boot=$S_ANO; rtc_epoch=$S_RTC; pm=$(limpo "$S_PM" 160); incompletas=$S_INC; gatilho=$GATILHO; decisao=$DECISAO; motivo=$MOTIVO"
  { tail -n $(( HIST_MAX - 1 )) "$HIST" 2>/dev/null; printf '%s\n' "$_l"; } > "$HIST.new" && mv -f "$HIST.new" "$HIST"
}

reaplicar_luz(){
  [ -e "$SUITE/luz" ] || return 0
  if confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
    sh "$SUITE/suite-pedido.sh" aplicar-luz
  else
    LOG "[ERRO] suite-pedido.sh ausente, link, de outro dono ou com md5 diferente - luz NAO reaplicada."
  fi
}

DESCANSO="com.pfl7560.verificar/.Descanso"
descanso_existe(){
  timeout 15 cmd package query-services --components -a android.service.dreams.DreamService 2>/dev/null \
    | grep -q 'com\.pfl7560\.verificar/.*Descanso' && return 0
  timeout 15 dumpsys package com.pfl7560.verificar 2>/dev/null | grep -q 'com\.pfl7560\.verificar/[.a-z0-9]*Descanso'
}
DESCANSO_TENTATIVAS=6
DESCANSO_ESPERA=10
[ -n "${PFL_RAPIDO:-}" ] && DESCANSO_ESPERA=0
ligar_descanso(){
  _dt=1
  until descanso_existe; do
    if [ "$_dt" -ge "$DESCANSO_TENTATIVAS" ]; then
      LOG "descanso: o servico $DESCANSO nao apareceu em $_dt consultas (app nao instalado?) - nada mexido. query-services: '$(timeout 15 cmd package query-services --components -a android.service.dreams.DreamService 2>&1 | tr '\n' ' ' | cut -c1-160)'"
      return 0
    fi
    _dt=$(( _dt + 1 ))
    sleep "$DESCANSO_ESPERA"
  done
  for _k in screensaver_components screensaver_default_component; do
    _v=$(timeout 10 settings get secure "$_k" 2>/dev/null | tr -d '\r')
    if [ "$_v" = "$DESCANSO" ]; then
      LOG "descanso: $_k ja e $DESCANSO"
    elif timeout 10 settings put secure "$_k" "$DESCANSO" >/dev/null 2>&1; then
      LOG "descanso: $_k era '$(limpo "$_v")', agora $DESCANSO"
    else
      LOG "[AVISO] descanso: nao consegui gravar $_k."
    fi
  done
}

OVERLAY_ANDROID="com.pfl7560.tema.android"
overlays_lista(){ timeout 15 cmd overlay list 2>/dev/null | tr -d '\r'; }
ligar_overlays(){
  _on=0
  for _od in "$R/vendor/overlay"/PFL7560Tema*; do [ -d "$_od" ] && _on=$(( _on + 1 )); done
  if [ "$_on" = 0 ]; then LOG "overlay: nenhuma sobreposicao nossa em /vendor/overlay - nada a ligar"; return 0; fi
  _ot=1
  while :; do
    _ol=$(overlays_lista)
    _oc=$(printf '%s\n' "$_ol" | grep -cE '^(\[.\]|---) com\.pfl7560\.tema\.')
    [ "$_oc" -ge "$_on" ] && break
    if [ "$_ot" -ge "$DESCANSO_TENTATIVAS" ]; then
      LOG "[AVISO] overlay: o sistema lista $_oc de $_on sobreposicoes depois de $_ot consultas - ligo as que ele ja lista."
      break
    fi
    _ot=$(( _ot + 1 ))
    sleep "$DESCANSO_ESPERA"
  done
  _off=$(printf '%s\n' "$_ol" | sed -n 's/^\[ \] \(com\.pfl7560\.tema\.[A-Za-z0-9_]*\).*$/\1/p')
  _ordem="$(printf '%s\n' "$_off" | grep -vxF "$OVERLAY_ANDROID") $(printf '%s\n' "$_off" | grep -xF "$OVERLAY_ANDROID")"
  _ofeitas=0
  for _op in $_ordem; do
    if timeout 15 cmd overlay enable "$_op" >/dev/null 2>&1; then
      LOG "overlay: $_op ligada"; _ofeitas=$(( _ofeitas + 1 ))
    else
      LOG "[AVISO] overlay: nao consegui ligar $_op (o resto segue)."
    fi
  done
  [ -n "$_ordem" ] || LOG "overlay: nenhuma desligada para ligar (ou o sistema nao as lista como desligadas)"
  _ol=$(overlays_lista)
  _ostate=$(printf '%s\n' "$_ol" | sed -En 's/^(\[.\]|---) (com\.pfl7560\.tema\.[A-Za-z0-9_]*).*$/\2=\1/p' | tr '\n' ' ')
  LOG "overlay: $_ofeitas ligada(s) neste boot; estado: ${_ostate:-(lista vazia)}"
}

APPS_DESLIGAR="com.mobisystems.editor.office_registered com.newlink.cast com.hisilicon.miracast"
PKG_RESTR="$R/data/system/users/0/package-restrictions.xml"
RESTR_TENTATIVAS=8
RESTR_ESPERA=2
[ -n "${PFL_RAPIDO:-}" ] && RESTR_ESPERA=0
restr_gravado(){ grep -a "name=\"$1\"" "$PKG_RESTR" 2>/dev/null | grep -aq 'enabled="3"'; }
desligar_apps(){
  _pt=1
  until timeout 15 pm list packages 2>/dev/null | grep -qx 'package:android'; do
    if [ "$_pt" -ge "$DESCANSO_TENTATIVAS" ]; then LOG "[AVISO] apps: o pm nao respondeu em $_pt consultas - nada desligado."; return 0; fi
    _pt=$(( _pt + 1 ))
    sleep "$DESCANSO_ESPERA"
  done
  _todos=$(timeout 15 pm list packages 2>/dev/null)
  _dis=$(timeout 15 pm list packages -d 2>/dev/null)
  _novos=""
  for _ap in $APPS_DESLIGAR; do
    if ! printf '%s\n' "$_todos" | grep -qx "package:$_ap"; then
      LOG "apps: $_ap nao esta instalado - nada a desligar"
    elif printf '%s\n' "$_dis" | grep -qx "package:$_ap"; then
      LOG "apps: $_ap ja estava desligado"
    elif timeout 15 pm disable-user --user 0 "$_ap" >/dev/null 2>&1; then
      LOG "apps: $_ap desligado (pm disable-user)"; _novos="$_novos $_ap"
    else
      LOG "[AVISO] apps: nao consegui desligar $_ap."
    fi
  done
  [ -n "$_novos" ] || return 0
  _rt=1
  while :; do
    _falta=""
    for _ap in $_novos; do restr_gravado "$_ap" || _falta="$_falta $_ap"; done
    [ -z "$_falta" ] && { LOG "apps: estado gravado no package-restrictions.xml (enabled=3):$_novos"; return 0; }
    [ "$_rt" -ge "$RESTR_TENTATIVAS" ] && break
    _rt=$(( _rt + 1 ))
    sleep "$RESTR_ESPERA"
  done
  LOG "[AVISO] apps: o package-restrictions.xml ainda nao mostra enabled=3 para:$_falta (o sistema grava com atraso; nao reinicie ja)."
}

vigia_vivo(){
  _p=$(head -n 1 "$VIGIA_PID" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  [ -n "$_p" ] && grep -aq 'pfl7560' "/proc/$_p/cmdline" 2>/dev/null
}
vigia_laco(){
  _v=0
  while :; do
    if [ -f "$VERIF_DIR/pedir-verificacao" ] && confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
      sh "$SUITE/suite-pedido.sh" w "$VERIF_DIR" pedir-verificacao
    fi
    if [ -f "$HOME_DIR/luz" ] && confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
      sh "$SUITE/suite-pedido.sh" w "$HOME_DIR" luz
    fi
    for _dn in descanso-inicio descanso-fim; do
      if [ -f "$VERIF_DIR/$_dn" ] && confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
        sh "$SUITE/suite-pedido.sh" w "$VERIF_DIR" "$_dn"
      fi
    done
    _v=$(( _v + 1 ))
    [ "$VIGIA_VOLTAS" != "0" ] && [ "$_v" -ge "$VIGIA_VOLTAS" ] && break
    sleep "$VIGIA_INTERVALO"
  done
}
ligar_vigia(){
  if vigia_vivo; then LOG "vigia do pedido ja ligado neste boot - nada a fazer"; return 0; fi
  if ! confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
    LOG "[ERRO] suite-pedido.sh ausente, link, de outro dono ou com md5 diferente - vigia NAO ligado."
    return 1
  fi
  _vig=""
  for _pd in "$VERIF_DIR" "$HOME_DIR"; do
    if [ -d "$_pd" ] && [ ! -L "$_pd" ]; then _vig="$_vig $_pd"
    else LOG "[AVISO] pasta do app $_pd ausente (app nao instalado?) ou link - nao vigiada."; fi
  done
  if [ -z "$_vig" ]; then
    LOG "[AVISO] nenhuma pasta de app para vigiar - vigia NAO ligado."
    return 1
  fi
  rm -f "$VERIF_DIR/descanso-inicio" "$VERIF_DIR/descanso-fim" "$SUITE/luz-antes-descanso" 2>/dev/null
  if [ -f "$VERIF_DIR/pedir-verificacao" ]; then
    LOG "pedido pendente de antes do vigia: tratando agora"
    sh "$SUITE/suite-pedido.sh" w "$VERIF_DIR" pedir-verificacao >>"$SUITE/vigia.log" 2>&1 </dev/null
  fi
  if [ -f "$HOME_DIR/luz" ]; then
    LOG "pedido de luz pendente de antes do vigia: tratando agora"
    sh "$SUITE/suite-pedido.sh" w "$HOME_DIR" luz >>"$SUITE/vigia.log" 2>&1 </dev/null
  fi
  if command -v inotifyd >/dev/null 2>&1; then
    # shellcheck disable=SC2046
    inotifyd "$SUITE/suite-pedido.sh" $(for _pd in $_vig; do printf '%s:wwy ' "$_pd"; done) >>"$SUITE/vigia.log" 2>&1 </dev/null &
    _tipo=inotifyd
  else
    vigia_laco >>"$SUITE/vigia.log" 2>&1 </dev/null &
    _tipo="laco de ${VIGIA_INTERVALO}s"
  fi
  echo "$!" > "$VIGIA_PID"
  LOG "vigia do pedido ligado: $_tipo (pid $!)"
}

if ! dir_seguro "$SUITE"; then
  echo "[PFL7560-suite-boot] [ERRO] $SUITE nao e uma pasta so do root (ausente, link, dono errado ou aberta) - nada feito."
  exit 1
fi
if [ -f "$BOOT_LOG" ]; then tail -n "$LOG_MAX" "$BOOT_LOG" > "$BOOT_LOG.new" 2>/dev/null && mv -f "$BOOT_LOG.new" "$BOOT_LOG"; fi
for _f in lancador.log vigia.log; do
  [ -f "$SUITE/$_f" ] && tail -n "$LOG_MAX" "$SUITE/$_f" > "$SUITE/$_f.new" 2>/dev/null && mv -f "$SUITE/$_f.new" "$SUITE/$_f"
done
exec >>"$BOOT_LOG" 2>&1 </dev/null
LOG "==== boot $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) ===="

ler_sinais
decidir
registrar
if [ "$GATILHO" != "nunca" ]; then
  setprop persist.sys.boot.reason "$MARCA_LIGADO"
  LOG "marca $MARCA_LIGADO gravada em persist.sys.boot.reason"
fi
LOG "sys.boot.reason='$S_BR' ano_boot='$S_ANO' gatilho=$GATILHO decisao=$DECISAO motivo=$MOTIVO"

reaplicar_luz
ligar_descanso &
ligar_overlays &
desligar_apps &
ligar_vigia

if [ "$DECISAO" = "sim" ]; then
  if confere "$SUITE/suite.sh" "$SUITE_MD5"; then
    LOG "lancando a suite (suite.sh tomada $MOTIVO) destacada"
    if command -v setsid >/dev/null 2>&1; then
      setsid sh "$SUITE/suite.sh" tomada "$MOTIVO" >>"$SUITE/lancador.log" 2>&1 </dev/null &
    else
      nohup sh "$SUITE/suite.sh" tomada "$MOTIVO" >>"$SUITE/lancador.log" 2>&1 </dev/null &
    fi
  else
    LOG "[ERRO] suite.sh ausente, link, de outro dono ou com md5 diferente do embutido - NAO executado."
  fi
fi
wait
exit 0
