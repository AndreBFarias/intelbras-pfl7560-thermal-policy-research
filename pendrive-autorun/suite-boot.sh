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
PEDIDO_DIR="$R/data/media/0/pfl7560"
MIDIA="$R/mnt/media_rw"
RTC="$R/sys/class/rtc/rtc0/since_epoch"
PM="$R/proc/msp/pm"
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"

# md5 do suite.sh e do suite-pedido.sh. Gerados por tests/atualizar-md5-kit.sh (o
# harness confere que estao em dia). NAO editar a mao.
# SUITE_MD5_INICIO
SUITE_MD5="0a0efcd0c3239556fb0944f6eb86c025"
PEDIDO_MD5="39b5a9df715c15a08ea030855fb541fe"
# SUITE_MD5_FIM

# PROVISORIO (teste final no aparelho, bloco 9 item 2): os dois criterios do gatilho
# "auto". Nao foi medido o que o aparelho mostra depois de faltar energia com ele
# ligado; o historico-boot.txt registra os sinais de cada boot para calibrar.
#  (a) o relogio no boot (dmesg) com ano < ANO_MIN = o RTC zerou = ficou sem energia;
#  (b) sys.boot.reason sem "shutdown," nem "reboot," = o desligamento nao foi limpo
#      (botao = shutdown,userrequested; adb reboot -p = shutdown,shell).
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

# ---- vigia do pedido do app --------------------------------------------------
vigia_vivo(){
  _p=$(head -n 1 "$VIGIA_PID" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  [ -n "$_p" ] && grep -aq 'pfl7560' "/proc/$_p/cmdline" 2>/dev/null
}
# laco sem inotifyd: confere o suite-pedido.sh a cada volta, imediatamente antes de usar
vigia_laco(){
  _v=0
  while :; do
    if [ -f "$PEDIDO_DIR/pedir-verificacao" ] && confere "$SUITE/suite-pedido.sh" "$PEDIDO_MD5"; then
      sh "$SUITE/suite-pedido.sh" w "$PEDIDO_DIR" pedir-verificacao
    fi
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
  if [ ! -d "$PEDIDO_DIR" ] || [ -L "$PEDIDO_DIR" ]; then
    LOG "[ERRO] pasta do pedido $PEDIDO_DIR ausente ou link - vigia NAO ligado."
    return 1
  fi
  # inotifyd executa o suite-pedido.sh a cada evento (w = escrita fechada, y = movido
  # para dentro); o suite-pedido.sh fica na pasta so do root, conferida acima.
  if command -v inotifyd >/dev/null 2>&1; then
    inotifyd "$SUITE/suite-pedido.sh" "$PEDIDO_DIR:wy" >>"$SUITE/vigia.log" 2>&1 </dev/null &
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
LOG "sys.boot.reason='$S_BR' ano_boot='$S_ANO' gatilho=$GATILHO decisao=$DECISAO motivo=$MOTIVO"

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
