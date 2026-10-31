#!/vendor/bin/sh
# ---------------------------------------------------------------------------
#  CONVENCAO DE CHARSET (NAO MEXER): ASCII PURO de proposito, como o
#  newlink_update.sh. Roda no /vendor/bin/sh do projetor (mksh/toybox do
#  Android 9) e vive em pendrive FAT32. Sem bashismo.
# ---------------------------------------------------------------------------
# ============================================================================
#  PFL7560 - SUITE DE VERIFICACAO, lancador de boot (bloco 9B)
#
#  Quem chama: o servico pfl7560_suite (/vendor/etc/init/pfl7560-suite.rc), uma vez
#  por boot, em sys.boot_completed=1, como root. Nao recebe argumento.
#
#   1. Registra os sinais deste boot em historico-boot.txt (ultimos 30): data,
#      sys.boot.reason, persist.sys.boot.reason, ro.boot.bootreason, a linha do dmesg
#      "setting system clock to" (ano do relogio no boot), o RTC, /proc/msp/pm e a
#      decisao. E o que o teste final usa para calibrar o gatilho.
#   2. Decide se a suite roda (arquivo gatilho: auto, sempre ou nunca).
#   2b. Reaplica o nivel de luz que o dono escolheu no atalho Luz da home (arquivo luz,
#      bloco 15), com qualquer gatilho: e escolha do dono, nao da suite. Sem o arquivo, nao mexe.
#   2c. Liga o descanso de tela MeowCast (bloco 16B), com qualquer gatilho: confere
#      screensaver_components e screensaver_default_component e aponta os dois para
#      com.pfl7560.verificar/.Descanso se forem outro, mas so com o servico instalado.
#   2d. Liga as sobreposicoes de tema Dracula instaladas em /vendor/overlay e ainda desligadas
#      (cmd overlay enable, com a do android SEMPRE por ultimo) e desliga o Office, o iOSCast e
#      o Espelhamento do fabricante (pm disable-user), conferindo no package-restrictions.xml
#      (bloco 14), com qualquer gatilho.
#   3. Liga o vigia do pedido do app (inotifyd; sem ele, um laco de 30 s).
#   4. Lanca suite.sh tomada destacado, com o md5 dele conferido NA HORA contra o
#      embutido aqui.
#   Fica vivo enquanto o vigia vive (wait): o processo do servico nao termina, entao
#   nada do que ele lancou depende de como o init trata o fim de um oneshot.
#
#  SEGURANCA: a pasta da suite tem de ser so do root (diretorio real, nao link,
#  dono root, 0700); suite.sh e suite-pedido.sh so executam com o md5 embutido.
# ============================================================================

# ---- ganchos de teste -------------------------------------------------------
# So valem com PFL_TESTE=1 (o harness em tests/ a define). Fora disso TODAS saem
# do ambiente, para que nenhuma seja porta de entrada em producao.
if [ "${PFL_TESTE:-}" != "1" ]; then
  # o init sobe o servico de boot com o PATH do /vendor: cmd, pm, am, settings, input,
  # dumpsys e logcat moram em /system/bin (visto no aparelho em 2026-10-31: "exec cmd: No
  # such file or directory" no boot). PATH fixo, com /system antes, em producao.
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
# pastas privadas dos apps: so o UID de cada app grava nela (revisao de seguranca de
# 2026-10-30; em /sdcard qualquer app disparava a suite). Verificar: pedir-verificacao;
# home: luz (o atalho Luz mora na home)
VERIF_DIR="$R/data/data/com.pfl7560.verificar"
HOME_DIR="$R/data/data/com.pfl7560.home"
MIDIA="$R/mnt/media_rw"
RTC="$R/sys/class/rtc/rtc0/since_epoch"
PM="$R/proc/msp/pm"
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"

# md5 do suite.sh e do suite-pedido.sh. Gerados por tests/atualizar-md5-kit.sh (o
# harness confere que estao em dia). NAO editar a mao.
# SUITE_MD5_INICIO
SUITE_MD5="07ef9ae4b8a086cbf339af9698bb3a97"
PEDIDO_MD5="f04915c87ca4287eb2c003beffca013f"
# SUITE_MD5_FIM

# Criterios do gatilho "auto" (o historico-boot.txt registra os sinais de cada boot):
#  (m) MARCA. O aparelho nao tem RTC (sem /sys/class/rtc/rtc0) e o motivo do boot
#      repete o do ultimo desligamento limpo, entao nem o relogio nem o motivo contam
#      sozinhos que a energia caiu. A cada boot este script grava MARCA_LIGADO em
#      persist.sys.boot.reason; um desligamento ou reboot limpo a sobrescreve
#      (shutdown,userrequested / reboot,shell). Se ela sobrevive ate o boot seguinte, a
#      energia caiu com o projetor ligado. Provado no aparelho em 2026-10-30: reset sem
#      desligamento (sysrq b) = sys/persist/ro.boot.bootreason "pfl7560,ligado"; reboot
#      limpo com a marca gravada = "reboot,shell" (evidencias/boot-tomada/).
#  (a) o relogio no boot (dmesg) com ano < ANO_MIN = o RTC zerou (sem efeito neste
#      aparelho, que nao tem RTC; mantido para outro hardware);
#  (b) sys.boot.reason sem "shutdown," nem "reboot," = o desligamento nao foi limpo
#      (kernel_panic, vazio, ...).
MARCA_LIGADO="pfl7560,ligado"
ANO_MIN=2020
INTERVALO_MIN=600     # protecao contra laco: a suite terminou ha menos de 10 min = nao roda
INCOMPLETAS_MAX=2     # protecao contra laco: 2 suites seguidas sem chegar ao fim (queda,
                      # travamento ou reboot no meio) = nao roda sozinha ate uma terminar
ESPERA_MONTAGEM=20    # PROVISORIO: espera um pendrive do kit montar antes de decidir
HIST_MAX=30
VIGIA_INTERVALO=30    # laco do vigia sem inotifyd
VIGIA_VOLTAS=0        # 0 = sem fim (producao); o harness limita
LOG_MAX=200
[ -n "${PFL_RAPIDO:-}" ] && ESPERA_MONTAGEM=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_VIGIA_VOLTAS:-}" ] && VIGIA_VOLTAS="$PFL_VIGIA_VOLTAS"

LOG(){ echo "[PFL7560-suite-boot] $*"; }

# ---- seguranca (as mesmas regras do newlink_update.sh e do cor.sh, E3b) -------
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
md5_de(){ md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
# arquivo regular do root, com o md5 esperado ($2), conferido agora
confere(){ [ -n "$2" ] && arq_seguro "$1" && [ "$(md5_de "$1")" = "$2" ]; }
# uma linha ASCII imprimivel, sem ';' (o separador do historico), ate $2 caracteres
limpo(){ printf '%s' "$1" | tr '\n\r\t;' '    ' | tr -cd ' -~' | cut -c1-"${2:-120}"; }

# ---- sinais do boot ----------------------------------------------------------
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

# ---- decisao -----------------------------------------------------------------
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
  # relogio que voltou (RTC zerado) nao bloqueia
  [ "$_agora" -ge "$_fim" ] && [ $(( _agora - _fim )) -lt "$INTERVALO_MIN" ]
}
decidir(){
  DECISAO=nao; MOTIVO=""
  # shellcheck disable=SC2018  # so ASCII de proposito
  GATILHO=$(head -1 "$GATILHO_ARQ" 2>/dev/null | tr -cd 'a-z')
  case "$GATILHO" in auto|sempre|nunca) ;; *) GATILHO=auto ;; esac
  if [ "$GATILHO" = "nunca" ]; then MOTIVO=gatilho_nunca; return 0; fi
  if [ "$S_INC" -ge "$INCOMPLETAS_MAX" ]; then MOTIVO="interrompida_${S_INC}x_seguidas"; return 0; fi
  if [ -d "$LOCK" ]; then MOTIVO=trava_ocupada; return 0; fi
  if terminou_ha_pouco; then MOTIVO=terminou_ha_menos_de_10min; return 0; fi
  # o fluxo do pendrive cobre (newlink_update.sh lanca a suite no modo pendrive)
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
  # printf, nao echo: o echo do sh do aparelho interpreta barra invertida (um \c cortaria a linha)
  { tail -n $(( HIST_MAX - 1 )) "$HIST" 2>/dev/null; printf '%s\n' "$_l"; } > "$HIST.new" && mv -f "$HIST.new" "$HIST"
}

# ---- luz (bloco 15) ------------------------------------------------------------
# o suite-pedido.sh (md5 conferido) faz tudo: valida o arquivo, aplica pelo hidebug, confere
# com gbl e devolve o valor ao app. A gravacao do sbl pelo fabricante e atrasada e nao
# confiavel (um reboot logo depois perde o valor), por isso a reaplicacao em todo boot.
reaplicar_luz(){
  [ -e "$SUITE/luz" ] || return 0
  if confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
    sh "$SUITE/suite-pedido.sh" aplicar-luz
  else
    LOG "[ERRO] suite-pedido.sh ausente, link, de outro dono ou com md5 diferente - luz NAO reaplicada."
  fi
}

# ---- descanso de tela MeowCast (bloco 16B) ---------------------------------------
# O servico e o .Descanso do app com.pfl7560.verificar. So se aponta para ele se o sistema o
# enxerga como DreamService (cmd package query-services, e dumpsys package como reserva); sem
# ele (app ausente, firmware sem o comando) nao se mexe em nada. O suite.sh --desinstalar
# devolve o do fabricante (com.newlink.screensaver/.ScreenService).
DESCANSO="com.pfl7560.verificar/.Descanso"
descanso_existe(){
  timeout 15 cmd package query-services --components -a android.service.dreams.DreamService 2>/dev/null \
    | grep -q 'com\.pfl7560\.verificar/.*Descanso' && return 0
  timeout 15 dumpsys package com.pfl7560.verificar 2>/dev/null | grep -q 'com\.pfl7560\.verificar/[.a-z0-9]*Descanso'
}
# Ate DESCANSO_TENTATIVAS consultas, DESCANSO_ESPERA s entre elas, em segundo plano (o
# PackageManager pode estar ocupado logo no boot). O "nao existe" visto no aparelho em
# 2026-10-31 era outra coisa: o PATH do servico sem /system/bin (ver o topo do script).
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

# ---- sobreposicoes de tema (bloco 14) --------------------------------------------
# O kit (newlink_update.sh) grava os APKs em /vendor/overlay/<Nome>/; o PackageManager so os varre
# no boot e o "cmd overlay enable" precisa do system_server, por isso a ligacao mora aqui, uma
# vez por boot. So liga as que o sistema lista como desligadas ("[ ] com.pfl7560.tema.<x>"); as
# que ja estao ligadas ("[x]") nao sao tocadas e o estado delas persiste em overlays.xml.
# A do android (framework: entra em todo processo) vai por ULTIMO. Como no descanso, o
# PackageManager pode ainda processar os APKs quando o boot termina: ate DESCANSO_TENTATIVAS
# consultas, esperando todas as pastas aparecerem na lista. Roda em segundo plano.
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

# ---- apps do fabricante desligados (bloco 14) --------------------------------------
# Office (editor), iOSCast e Espelhamento: pm disable-user --user 0, uma vez por boot, so nos que
# estao ligados. O PackageManager grava o estado com atraso (uns 10 s), entao depois de desligar
# espera aparecer enabled="3" no package-restrictions.xml (ate 8 leituras de 2 s) e registra se
# gravou; um reboot antes disso perderia o estado. O suite.sh --desinstalar religa (pm enable).
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

# ---- vigia do pedido do app --------------------------------------------------
vigia_vivo(){
  _p=$(head -n 1 "$VIGIA_PID" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  [ -n "$_p" ] && grep -aq 'pfl7560' "/proc/$_p/cmdline" 2>/dev/null
}
# laco sem inotifyd: confere o suite-pedido.sh a cada volta, imediatamente antes de usar
vigia_laco(){
  _v=0
  while :; do
    if [ -f "$VERIF_DIR/pedir-verificacao" ] && confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
      sh "$SUITE/suite-pedido.sh" w "$VERIF_DIR" pedir-verificacao
    fi
    if [ -f "$HOME_DIR/luz" ] && confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
      sh "$SUITE/suite-pedido.sh" w "$HOME_DIR" luz
    fi
    # o descanso de tela (bloco 16B) tambem: inicio antes do fim (os dois numa volta = o
    # descanso ja saiu da tela e a luz fica no nivel do dono)
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
  # as pastas que existem (app instalado) e nao sao link
  _vig=""
  for _pd in "$VERIF_DIR" "$HOME_DIR"; do
    if [ -d "$_pd" ] && [ ! -L "$_pd" ]; then _vig="$_vig $_pd"
    else LOG "[AVISO] pasta do app $_pd ausente (app nao instalado?) ou link - nao vigiada."; fi
  done
  if [ -z "$_vig" ]; then
    LOG "[AVISO] nenhuma pasta de app para vigiar - vigia NAO ligado."
    return 1
  fi
  # sinais velhos do descanso de tela nao valem: o boot ja reaplicou o nivel do dono
  rm -f "$VERIF_DIR/descanso-inicio" "$VERIF_DIR/descanso-fim" "$SUITE/luz-antes-descanso" 2>/dev/null
  # um pedido que ja estava na pasta (feito antes do vigia ligar) nao gera evento de
  # criacao: e tratado agora, uma vez
  if [ -f "$VERIF_DIR/pedir-verificacao" ]; then
    LOG "pedido pendente de antes do vigia: tratando agora"
    sh "$SUITE/suite-pedido.sh" w "$VERIF_DIR" pedir-verificacao >>"$SUITE/vigia.log" 2>&1 </dev/null
  fi
  if [ -f "$HOME_DIR/luz" ]; then
    LOG "pedido de luz pendente de antes do vigia: tratando agora"
    sh "$SUITE/suite-pedido.sh" w "$HOME_DIR" luz >>"$SUITE/vigia.log" 2>&1 </dev/null
  fi
  # inotifyd executa o suite-pedido.sh a cada evento: w = escrita fechada (o app terminou
  # de gravar), y = movido para dentro. O inotifyd do toybox do aparelho IGNORA a 1a letra
  # da mascara (visto em 2026-10-30: ":wy" vigiava so "y"; ":n" dava Invalid argument;
  # ":nwy" entregava "w"). Por isso ":wwy": com ou sem o defeito, a mascara e w + y.
  # O suite-pedido.sh fica na pasta so do root, conferida acima.
  if command -v inotifyd >/dev/null 2>&1; then
    # shellcheck disable=SC2046  # uma "pasta:wwy" por pasta, divisao de proposito
    inotifyd "$SUITE/suite-pedido.sh" $(for _pd in $_vig; do printf '%s:wwy ' "$_pd"; done) >>"$SUITE/vigia.log" 2>&1 </dev/null &
    _tipo=inotifyd
  else
    vigia_laco >>"$SUITE/vigia.log" 2>&1 </dev/null &
    _tipo="laco de ${VIGIA_INTERVALO}s"
  fi
  echo "$!" > "$VIGIA_PID"
  LOG "vigia do pedido ligado: $_tipo (pid $!)"
}

# ============================================================================
if ! dir_seguro "$SUITE"; then
  echo "[PFL7560-suite-boot] [ERRO] $SUITE nao e uma pasta so do root (ausente, link, dono errado ou aberta) - nada feito."
  exit 1
fi
# log proprio (a saida de um servico do init vai para /dev/null)
if [ -f "$BOOT_LOG" ]; then tail -n "$LOG_MAX" "$BOOT_LOG" > "$BOOT_LOG.new" 2>/dev/null && mv -f "$BOOT_LOG.new" "$BOOT_LOG"; fi
for _f in lancador.log vigia.log; do
  [ -f "$SUITE/$_f" ] && tail -n "$LOG_MAX" "$SUITE/$_f" > "$SUITE/$_f.new" 2>/dev/null && mv -f "$SUITE/$_f.new" "$SUITE/$_f"
done
exec >>"$BOOT_LOG" 2>&1 </dev/null
LOG "==== boot $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) ===="

ler_sinais
decidir
registrar
# a marca do criterio (m), DEPOIS de ler os sinais deste boot (gatilho nunca = nao mexe)
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
  # ULTIMA conferencia antes de executar: arquivo regular do root e o md5 embutido
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
