#!/vendor/bin/sh

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_NLCAMCHECK PFL_NLCAMCHECK_MD5 PFL_NLTELA PFL_NLTELA_MD5 PFL_MODO_AUTO PFL_RAPIDO PFL_DONO PFL_TESTE PFL_ESPERA_OK_VOLTAS PFL_VARRE_LIGADA
fi
LC_ALL=C; export LC_ALL
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
WORK="$R/data/vendor/pfl7560-kit"
LOCK="$R/dev/pfl7560-suite.lock"
VIGIA_PID="$R/dev/pfl7560-suite.vigia"
LOGF="$SUITE/ultimo.log"
RES="$SUITE/resultados.txt"
FIM_ARQ="$SUITE/ultimo-fim"
INCOMPLETAS_ARQ="$SUITE/incompletas"
GERA_DIR="$SUITE/tela"
TELA_DIR="$R/sdcard/pfl7560-suite"
PEDIDO_DIR="$R/data/data/com.pfl7560.verificar"
RC_SUITE="$R/vendor/etc/init/pfl7560-suite.rc"
VIDEO="$R/dev/video0"
INI_VENDOR="$R/vendor/etc/ZYCustom.ini"
ATV_INI_DIR="$R/atv/ini"
BP="$R/vendor/build.prop"
PROC_PANEL="$R/proc/msp/panel"
HIDEBUG="$R/vendor/bin/hidebug"
WLAN_ESTADO="$R/sys/class/net/wlan0/operstate"
NLCAM="${PFL_NLCAMCHECK:-$SUITE/nl_camcheck}"
NLTELA="${PFL_NLTELA:-$SUITE/nl_tela}"
DONO_UID=0

# SUITE_LISTA_INICIO
SUITE_LISTA="0dbcf2861f96e24e728342732ce54340  cor.sh
178d812872cb9306c0ae6faeed07184a  lvdsctl
02bedd31ae0e82afd10c41daabf2bd56  nl_camcheck
662acb7ac307699a389e892047f0d883  nl_tela
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
"
# SUITE_LISTA_FIM

lista_md5(){ echo "$SUITE_LISTA" | sed -n "s|^\\([0-9a-f][0-9a-f]*\\)  $1\$|\\1|p" | head -1; }
lista_nomes(){ echo "$SUITE_LISTA" | sed -n 's/^[0-9a-f][0-9a-f]*  //p'; }
COR_MD5=$(lista_md5 cor.sh)
NLCAM_MD5=$(lista_md5 nl_camcheck)
NLTELA_MD5=$(lista_md5 nl_tela)
if [ "${PFL_TESTE:-}" = "1" ]; then
  [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
  [ -n "${PFL_NLCAMCHECK_MD5:-}" ] && NLCAM_MD5="$PFL_NLCAMCHECK_MD5"
  [ -n "${PFL_NLTELA_MD5:-}" ] && NLTELA_MD5="$PFL_NLTELA_MD5"
fi

INI_MD5_OK="252ab7a72a007a8b79b3fc86bd5c0d19"
INI_MD5_OK_NOTYPEC="bdf5c4640596d1b2f2fb7f62fbadd6e3"
ESCADA='66000, 67500, 69000, 70000, 71500, 73000'

TEMPO_ABERTURA=5
TEMPO_TELA=3
TEMPO_RESUMO=20
ESPERA_TIRAR=60
ESPERA_TRAVA=600
AUTOFOCO_INICIO_BOOT=60
AUTOFOCO_INICIO=5
AUTOFOCO_FIM=70
AUTOFOCO_FOLGA=5
RAMPA_ANTES=5
RAMPA_INJETADO=40
RAMPA_DEPOIS=25
if [ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_RAPIDO:-}" ]; then
  TEMPO_ABERTURA=0; TEMPO_TELA=0; ESPERA_TIRAR=0; ESPERA_TRAVA=0
  AUTOFOCO_INICIO_BOOT=0; AUTOFOCO_INICIO=0; AUTOFOCO_FIM=0; AUTOFOCO_FOLGA=0
  RAMPA_ANTES=0; RAMPA_DEPOIS=0
fi

FAIXAS_N=16
CAM_DESCARTE=15
LIMIAR_BORDA_PX_1280=3.5
RAZAO_BORDA=1.6
INCLINACAO_MAX=1.5
TRAPEZIO_MAX=3
FOCO_TENTATIVAS=2
VARRE_PASSO=40
VARRE_LADO=3
VARRE_PAUSA=2
VARRE_CHEGADA=3
VARRE_TOLERANCIA=20
VARRE_GANHO=0.15
MODO_AUTO=1
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_MODO_AUTO:-}" ] && MODO_AUTO="$PFL_MODO_AUTO"
CAM_TENTATIVAS=3
ESPERA_OK_VOLTAS=0
VARRE_LIGADA=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_VARRE_LIGADA:-}" ] && VARRE_LIGADA="$PFL_VARRE_LIGADA"
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_ESPERA_OK_VOLTAS:-}" ] && ESPERA_OK_VOLTAS="$PFL_ESPERA_OK_VOLTAS"
SINAL_INCLINACAO=1
LED_QUENTE=66
RAMPA_LED_MAX=66

DESCANSO_FABRICA="com.newlink.screensaver/com.newlink.screensaver.ScreenService"

PROP_OVERRIDE=vendor.zy.power.tm.temp
INJETADO=71000

LOG(){ echo "[PFL7560-suite] $*"; }

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
confere(){
  _cm=$(lista_md5 "$2")
  [ -n "$_cm" ] && arq_seguro "$1" && [ "$(md5_de "$1")" = "$_cm" ]
}
suite_ok(){
  if dir_seguro "$SUITE"; then
    for _sd in kit fontes; do
      if [ -e "$SUITE/$_sd" ] || [ -L "$SUITE/$_sd" ]; then
        dir_seguro "$SUITE/$_sd" || { LOG "[ERRO] $SUITE/$_sd nao e uma pasta so do root (link?) - NAO vou usar."; return 1; }
      fi
    done
    return 0
  fi
  LOG "[ERRO] $SUITE nao e uma pasta so do root (link, dono errado ou aberta a outros) - NAO vou usar."
  return 1
}

# shellcheck disable=SC1003
limpo(){ printf '%s' "$1" | tr '\n\r\t' '   ' | tr -d '|\\' | tr -cd ' -~' | cut -c1-"${2:-120}"; }
virgula(){ echo "$1" | sed 's/\./,/'; }
um_dec(){ awk -v v="$1" 'BEGIN{printf "%.1f", v}'; }
numero(){ case "$1" in ''|*[!0-9.-]*|*.*.*|?*-*) return 1 ;; esac; [ "$1" != "-" ] && [ "$1" != "." ]; }
maior(){ awk -v a="$1" -v b="$2" 'BEGIN{if (a+0 > b+0) exit 0; exit 1}'; }
abs(){ awk -v a="$1" 'BEGIN{if (a<0) a=-a; print a}'; }

res(){ printf '%s=%s\n' "$1" "$(limpo "$2" 200)" >> "$RES.new"; }

TRAVA_MINHA=0
RAMPA_ATIVA=0
VARRE_ATIVA=0
VARRE_P0=""
LOGCAT_PID=""
pegar_lock(){ mkdir "$LOCK" 2>/dev/null && TRAVA_MINHA=1; }
rampa_limpar(){
  _ri=0
  while [ "$_ri" -lt 3 ]; do
    setprop "$PROP_OVERRIDE" '' 2>/dev/null
    if [ -z "$(getprop "$PROP_OVERRIDE" 2>/dev/null)" ]; then
      RAMPA_ATIVA=0
      LOG "[OK] override de temperatura limpo e conferido"
      return 0
    fi
    _ri=$(( _ri + 1 ))
    sleep 1
  done
  LOG "[ERRO] NAO confirmei a limpeza do override de temperatura: REINICIE O PROJETOR (o override nao sobrevive ao boot)."
  return 1
}
# shellcheck disable=SC2317
sair(){
  trap '' INT TERM HUP
  if [ "$RAMPA_ATIVA" = "1" ]; then
    LOG "saindo com o override de temperatura ativo: limpando"
    if rampa_limpar; then res rampa_limpeza_saida ok; else res rampa_limpeza_saida falhou; fi
  fi
  if [ "$VARRE_ATIVA" = "1" ] && [ -n "$VARRE_P0" ]; then
    LOG "saindo no meio da varredura de foco: devolvendo o motor a $VARRE_P0"
    hb_foco "sfd $VARRE_P0" >/dev/null
    res foco_varredura interrompida
  fi
  parar_logcat
  if [ "$TRAVA_MINHA" = "1" ]; then
    date +%s > "$FIM_ARQ.new" 2>/dev/null && mv -f "$FIM_ARQ.new" "$FIM_ARQ"
    rm -f "$INCOMPLETAS_ARQ"
    if [ -f "$RES.new" ]; then
      res fim "$(date +%s 2>/dev/null)"
      mv -f "$RES.new" "$RES"
    fi
    copiar_log_pendrive
    rmdir "$LOCK" 2>/dev/null
    luz_do_dono
  fi
}
parar_logcat(){
  [ -n "$LOGCAT_PID" ] || return 0
  pkill -P "$LOGCAT_PID" 2>/dev/null
  kill "$LOGCAT_PID" 2>/dev/null
  wait "$LOGCAT_PID" 2>/dev/null
  LOGCAT_PID=""
}
contar_inicio(){
  _ni=$(head -n 1 "$INCOMPLETAS_ARQ" 2>/dev/null | tr -cd '0-9' | cut -c1-4)
  echo $(( ${_ni:-0} + 1 )) > "$INCOMPLETAS_ARQ.new" 2>/dev/null && mv -f "$INCOMPLETAS_ARQ.new" "$INCOMPLETAS_ARQ"
}
copiar_log_pendrive(){
  [ "$MODO" = "pendrive" ] && [ -n "$MP" ] && [ -d "$MP" ] || return 0
  cp "$LOGF" "$MP/newlink_suite.log" 2>/dev/null
  [ -f "$RES" ] && cp "$RES" "$MP/newlink_suite_resultados.txt" 2>/dev/null
  return 0
}

preparar_telas(){
  rm -rf "$TELA_DIR" 2>/dev/null
  mkdir -p "$TELA_DIR" 2>/dev/null && chmod 755 "$TELA_DIR" 2>/dev/null
  rm -rf "$GERA_DIR" 2>/dev/null
  ( umask 077; mkdir "$GERA_DIR" 2>/dev/null )
}
nltela_ok(){
  [ -n "$NLTELA_MD5" ] && arq_seguro "$NLTELA" && [ -x "$NLTELA" ] && [ "$(md5_de "$NLTELA")" = "$NLTELA_MD5" ]
}
fontes_conferidas(){
  for _fn in $(lista_nomes | grep '^fontes/'); do
    confere "$SUITE/$_fn" "$_fn" || { LOG "[AVISO] $_fn nao confere (md5, link ou dono): telas geradas desligadas."; return 1; }
  done
  return 0
}
gerar_tela(){
  TELA_GERADA=""
  if ! nltela_ok; then LOG "[AVISO] nl_tela ausente, link, de outro dono ou com md5 diferente - tela $2 estatica."; return 1; fi
  fontes_conferidas || return 1
  dir_seguro "$GERA_DIR" || { LOG "[AVISO] $GERA_DIR nao e pasta so do root - tela $2 estatica."; return 1; }
  _gp="$GERA_DIR/$2.png"
  rm -f "$_gp"
  timeout 30 "$NLTELA" "$1" "$3" "$_gp" "$SUITE/fontes" </dev/null; _grc=$?
  if [ "$_grc" != "0" ] || [ ! -s "$_gp" ]; then LOG "[AVISO] nl_tela $1 $2 falhou (rc=$_grc)."; return 1; fi
  _gd="$TELA_DIR/$2-$RUN_ID.png"
  if ! { cp "$_gp" "$_gd" 2>/dev/null && chmod 644 "$_gd" 2>/dev/null; }; then
    LOG "[AVISO] nao consegui copiar a tela $2 para $TELA_DIR."; return 1
  fi
  TELA_GERADA="$_gd"
}
fechar_alertas(){
  _fa=0
  while [ "$_fa" -lt 4 ]; do
    _fp=$(dumpsys window 2>/dev/null | grep -a 'mCurrentFocus' | head -1 | sed -n 's/.* u0 \([^ }]*\)}.*/\1/p')
    case "$_fp" in ''|*/*) return 0 ;; esac
    if [ "$_fp" = "com.newlink.nlprovision" ]; then
      if [ $(( _fa % 2 )) = 0 ]; then _tk=KEYCODE_DPAD_CENTER; else _tk=KEYCODE_ENTER; fi
      LOG "alerta do sistema ($_fp) na tela: fechando com $_tk (so tem OK)"
      input keyevent "$_tk" >/dev/null 2>&1
    else
      LOG "alerta do sistema ($(limpo "$_fp" 60)) na tela: cancelando com BACK"
      input keyevent KEYCODE_BACK >/dev/null 2>&1
    fi
    sleep 1; _fa=$(( _fa + 1 ))
  done
  LOG "[AVISO] o alerta do sistema nao fechou depois de 4 teclas"
  return 1
}
mostrar_arq(){
  fechar_alertas
  LOG "tela: ${1##*/}"
  _pk=$(cmd package resolve-activity --brief -a android.intent.action.VIEW -d "file://${1#"$R"}" -t image/png 2>/dev/null | tail -1)
  _pk="${_pk%%/*}"
  case "$_pk" in
    ''|android|*[!A-Za-z0-9._]*) _pk="com.hisilicon.higallery" ;;
  esac
  GALERIA="$_pk"
  am force-stop "$_pk" >/dev/null 2>&1
  am start -a android.intent.action.VIEW -d "file://${1#"$R"}" -t image/png >/dev/null 2>&1
  sleep "$TEMPO_TELA"
}
mostrar_estatica(){
  if ! confere "$SUITE/kit/$1.png" "kit/$1.png"; then
    LOG "[AVISO] kit/$1.png ausente, link ou com md5 diferente - tela nao mostrada."
    return 1
  fi
  cp "$SUITE/kit/$1.png" "$TELA_DIR/$1.png" 2>/dev/null && chmod 644 "$TELA_DIR/$1.png" 2>/dev/null
  mostrar_arq "$TELA_DIR/$1.png"
}
tela(){
  if gerar_tela "$1" "$2" "$3"; then mostrar_arq "$TELA_GERADA"; return 0; fi
  [ -n "${4:-}" ] && mostrar_estatica "$4"
  return 1
}
ir_para_inicio(){
  am force-stop "${GALERIA:-com.hisilicon.higallery}" >/dev/null 2>&1
  input keyevent KEYCODE_HOME >/dev/null 2>&1
}
campo(){ printf '%s=%s\n' "$1" "$2" >> "$CAMPOS"; }
novos_campos(){ CAMPOS="$GERA_DIR/$1.txt"; rm -f "$CAMPOS"; : > "$CAMPOS"; }

aguardar_autofoco(){
  _t=0; _viu=0
  while [ "$_t" -lt "$1" ]; do
    [ "$(getprop sys.newlink.auto 2>/dev/null)" = "1" ] && break
    if [ "$2" = "1" ] && [ "$(getprop vendor.focus.camera.is_focused 2>/dev/null)" = "true" ]; then _viu=1; break; fi
    sleep 1; _t=$(( _t + 1 ))
  done
  if [ "$(getprop sys.newlink.auto 2>/dev/null)" = "1" ]; then
    _viu=1; _t=0
    while [ "$_t" -lt "$AUTOFOCO_FIM" ] && [ "$(getprop sys.newlink.auto 2>/dev/null)" = "1" ]; do
      sleep 2; _t=$(( _t + 2 ))
    done
  fi
  sleep "$AUTOFOCO_FOLGA"
  [ "$_viu" = "1" ]
}
disparar_autofoco(){
  if [ "$(getprop sys.newlink.auto 2>/dev/null)" = "1" ]; then
    LOG "autofoco ja em curso: so espero ele terminar"
  else
    LOG "disparando o autofoco (so foco, sem keystone)"
    am startservice -n com.zhiying.autofocus/.AutoFocusService -a com.zhiying.AUTO_FOCUS_SERVICE --ei auto_focus_keystone 0 >/dev/null 2>&1
  fi
  aguardar_autofoco "$AUTOFOCO_INICIO" 0 || LOG "[AVISO] o autofoco nao comecou (o servico recusa com o backlight desligado ou em teste de fabrica)."
}

passos_fila(){
  campo passo "Cor do painel|$1"
  campo passo "\u00c2ngulo, foco e nitidez|$2"
  campo passo "Temperatura|$3"
  campo passo "Teste da prote\u00e7\u00e3o t\u00e9rmica|$4"
}
etapa_abertura(){
  novos_campos abertura
  case "$MODO" in
    tomada)
      case "$MOTIVO_BOOT" in
        gatilho_sempre)
          campo titulo "Verifica\u00e7\u00e3o de todo boot.\nConferindo o projetor."
          campo texto "Antes de voc\u00ea usar, o projetor confere a cor, o foco, a imagem e a temperatura. Leva cerca de 3 minutos." ;;
        desligamento_nao_limpo)
          campo titulo "N\u00e3o desligou direito.\nConferindo o projetor."
          campo texto "O projetor n\u00e3o desligou direito. Antes de voc\u00ea usar, ele confere a cor, o foco, a imagem e a temperatura. Leva cerca de 3 minutos." ;;
        *)
          campo titulo "Voltou a energia.\nConferindo o projetor."
          campo texto "O projetor ficou sem energia. Antes de voc\u00ea usar, ele confere a cor, o foco, a imagem e a temperatura. Leva cerca de 3 minutos." ;;
      esac ;;
    pendrive)
      campo titulo "Pendrive do kit encontrado.\nConferindo o projetor."
      campo texto "A corre\u00e7\u00e3o do kit foi conferida. Agora o projetor confere a cor, o foco, a imagem e a temperatura. Leva cerca de 3 minutos." ;;
    pedido)
      campo titulo "Verifica\u00e7\u00e3o pedida.\nConferindo o projetor."
      campo texto "O projetor confere a cor, o foco, a imagem e a temperatura. Leva cerca de 3 minutos." ;;
  esac
  passos_fila fila fila fila fila
  campo tom normal
  tela aviso abertura "$CAMPOS" aguarde
  sleep "$TEMPO_ABERTURA"
  case "$MODO" in
    tomada|pendrive) aguardar_autofoco "$AUTOFOCO_INICIO_BOOT" 1 && LOG "autofoco de boot terminou" ;;
    *) aguardar_autofoco 0 0 ;;
  esac
}

cor_nomes(){ lista_nomes | grep -E '^(cor\.sh|lvdsctl|nl_camcheck|kit/.*)$'; }
preparar_kit(){
  if [ -e "$WORK" ] || [ -L "$WORK" ]; then
    dir_seguro "$WORK" || { LOG "[ERRO] $WORK nao e pasta so do root - NAO vou usar."; return 1; }
  else
    mkdir -p "${WORK%/*}" 2>/dev/null
    ( umask 077; mkdir "$WORK" 2>/dev/null ) && chmod 700 "$WORK" 2>/dev/null
    dir_seguro "$WORK" || { LOG "[ERRO] nao consegui criar $WORK so do root."; return 1; }
  fi
  _prep="$WORK/preparo.$$"
  rm -rf "$_prep"
  ( umask 077; mkdir "$_prep" && mkdir "$_prep/kit" ) || { rm -rf "$_prep"; return 1; }
  for _cn in $(cor_nomes); do
    confere "$SUITE/$_cn" "$_cn" || { LOG "[ERRO] $_cn da pasta da suite nao confere."; rm -rf "$_prep"; return 1; }
    cp "$SUITE/$_cn" "$_prep/$_cn" || { rm -rf "$_prep"; return 1; }
  done
  for _cn in $(cor_nomes); do
    confere "$_prep/$_cn" "$_cn" || { LOG "[ERRO] a copia de $_cn nao confere."; rm -rf "$_prep"; return 1; }
  done
  chmod 755 "$_prep/cor.sh" "$_prep/lvdsctl" "$_prep/nl_camcheck" 2>/dev/null
  if ! { rm -rf "$WORK/kit" && mkdir "$WORK/kit"; }; then rm -rf "$_prep"; return 1; fi
  for _cn in $(cor_nomes); do
    mv -f "$_prep/$_cn" "$WORK/$_cn" || { rm -rf "$_prep"; return 1; }
  done
  rm -rf "$_prep"
}
ler_cor(){ sed -n "s/^$1=\\([A-Za-z0-9_?-]*\\)\$/\\1/p" "$SUITE/cor-resultado.txt" 2>/dev/null | head -1; }
etapa_cor(){
  COR_RES=erro; COR_ANTES="?"; COR_DEPOIS="?"; COR_FAIXAS="-"; COR_PAINEL=""
  rm -f "$SUITE/cor-resultado.txt"
  if ! preparar_kit; then
    LOG "[ERRO] cor: a pasta de trabalho do cor.sh nao ficou pronta - etapa de cor pulada."
  elif ! { dir_seguro "$WORK" && confere "$WORK/cor.sh" cor.sh; }; then
    LOG "[ERRO] cor: cor.sh nao conferiu na hora de executar - NAO executado."
  else
    if [ "$MODO_AUTO" = "1" ] && [ -e "$VIDEO" ] && nlcam_ok && ! ler_faixas_tentando "$SUITE/faixas-cor.txt"; then
      esperar_ok_camera 1
    fi
    fechar_alertas
    LOG "cor: rodando cor.sh no modo suite"
    : > "$SUITE/cor.log"
    sh "$WORK/cor.sh" "$MP" "$AVISO_ARG" "$COR_MD5" suite >>"$SUITE/cor.log" 2>&1 </dev/null
    cat "$SUITE/cor.log"
    if arq_seguro "$SUITE/cor-resultado.txt"; then
      COR_RES=$(ler_cor cor_resultado)
      COR_ANTES=$(ler_cor cor_formato_antes)
      COR_DEPOIS=$(ler_cor cor_formato_depois)
      COR_FAIXAS=$(ler_cor cor_faixas)
      COR_PAINEL=$(ler_cor cor_painel)
    else
      LOG "[ERRO] cor: o cor.sh nao deixou resultado."
    fi
  fi
  case "$COR_RES" in ordem|corrigido|manual_mantido|manual_trocado) ;; *) COR_RES=erro ;; esac
  [ -n "$COR_PAINEL" ] || COR_PAINEL=$(awk -F'[:|]' '/panel_name/{v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); if(v!=""){print v; exit}}' "$PROC_PANEL" 2>/dev/null)
  res cor_resultado "$COR_RES"; res cor_formato_antes "$COR_ANTES"; res cor_formato_depois "$COR_DEPOIS"
  res cor_faixas "$COR_FAIXAS"; res cor_painel "$COR_PAINEL"
  case "$COR_RES" in
    ordem) I_FORMATO="$COR_DEPOIS|ok"; P_COR=ok ;;
    corrigido|manual_trocado) I_FORMATO="$COR_ANTES \u2192 $COR_DEPOIS|corrigido"; P_COR=corrigido ;;
    manual_mantido) I_FORMATO="$COR_DEPOIS|info"; P_COR=ok ;;
    *) I_FORMATO="erro|atencao"; P_COR=atencao
       dica "A confer\u00eancia da cor n\u00e3o terminou: veja o relat\u00f3rio e repita a verifica\u00e7\u00e3o." ;;
  esac
  _pc=$(echo "$COR_PAINEL" | cut -d_ -f1,2)
  I_PAINEL="$(limpo "${_pc:-[a ler]}" 24)|info"
}

nlcam_ok(){
  [ -n "$NLCAM_MD5" ] && arq_seguro "$NLCAM" && [ -x "$NLCAM" ] && [ "$(md5_de "$NLCAM")" = "$NLCAM_MD5" ] && return 0
  LOG "[ERRO] nl_camcheck ($NLCAM) ausente, link, de outro dono ou com md5 diferente - NAO vou executar."
  return 1
}
nlcam_exec(){ nlcam_ok || return 1; timeout 30 "$NLCAM" "$@" </dev/null; }
geo_valor(){ echo "$GEO_SAIDA" | sed -n "s/^$1=\\(-\\{0,1\\}[0-9][0-9]*\\(\\.[0-9]*\\)\\{0,1\\}\\)\$/\\1/p" | head -1; }
ler_faixas_tentando(){
  _ct=1
  while :; do
    rm -f "$1"
    mostrar_estatica calibracao || return 1
    _o=$(nlcam_exec faixas "$VIDEO" "$FAIXAS_N" "$1" "$CAM_DESCARTE"); _rc=$?
    if [ "$_rc" = "0" ]; then LOG "camera: $(limpo "$_o") (tentativa $_ct)"; return 0; fi
    LOG "[AVISO] camera: faixas falhou na tentativa $_ct de $CAM_TENTATIVAS (rc=$_rc: $(limpo "$_o"))"
    [ "$_ct" -ge "$CAM_TENTATIVAS" ] && return 1
    disparar_autofoco
    _ct=$(( _ct + 1 ))
  done
}
esperar_ok_camera(){
  novos_campos camera
  campo titulo "A c\u00e2mera n\u00e3o conseguiu ler a tela."
  campo texto "Confira se nada est\u00e1 na frente da lente da c\u00e2mera ou da imagem e aperte OK no controle para continuar."
  if [ "$1" = "1" ]; then passos_fila agora fila fila fila; else passos_fila "feito|$P_COR" agora fila fila; fi
  campo tom alerta
  tela aviso camera "$CAMPOS"
  LOG "camera sem leitura: esperando uma tecla do controle, sem prazo"
  _eo=0
  until getevent -qlc 3 2>/dev/null | grep -q 'EV_KEY.*DOWN'; do
    _eo=$(( _eo + 1 ))
    if [ "$ESPERA_OK_VOLTAS" != "0" ] && [ "$_eo" -ge "$ESPERA_OK_VOLTAS" ]; then LOG "(teste) espera encerrada"; return 1; fi
    sleep 1
  done
  LOG "tecla recebida: seguindo"
  return 0
}
medir_geo(){
  G_OK=0
  _ff="$SUITE/faixas.txt"
  ler_faixas_tentando "$_ff" || return 1
  GEO_SAIDA=$(nlcam_exec geometria "$VIDEO" "$_ff" "$CAM_DESCARTE"); _rc=$?
  LOG "geometria (rc=$_rc): $(echo "$GEO_SAIDA" | tr '\n' ' ')"
  [ "$_rc" = "0" ] || return 1
  G_INC=$(geo_valor inclinacao_graus); G_TRAP=$(geo_valor trapezio_pct)
  G_BC=$(geo_valor borda_centro_px); G_BE=$(geo_valor borda_esq_px); G_BD=$(geo_valor borda_dir_px)
  G_CONT=$(geo_valor contraste_centro)
  G_L=$(echo "$GEO_SAIDA" | sed -n 's/^quadro=\([0-9][0-9]*\)x[0-9][0-9]*$/\1/p' | head -1)
  for _gv in "$G_INC" "$G_TRAP" "$G_BC" "$G_BE" "$G_BD" "$G_CONT" "$G_L"; do
    numero "$_gv" || { LOG "[AVISO] saida da geometria ilegivel"; return 1; }
  done
  G_LIMIAR=$(awk -v l="$LIMIAR_BORDA_PX_1280" -v w="$G_L" 'BEGIN{printf "%.2f", l*w/1280}')
  G_OK=1
  medir_nitidez "$_ff" || LOG "[AVISO] nitidez 3x3 sem leitura: o item Nitidez usa a borda do centro da geometria"
}
NIT_REGIOES="r1c1 r1c2 r1c3 r2c1 r2c2 r2c3 r3c1 r3c2 r3c3"
nit_valor(){ echo "$NIT_SAIDA" | sed -n "s/^nitidez_$1=\\([0-9][0-9]*\\.[0-9]*\\)\$/\\1/p" | head -1; }
medir_nitidez(){
  NIT_OK=0
  NIT_SAIDA=$(nlcam_exec nitidez "$VIDEO" "$1" "$CAM_DESCARTE"); _rc=$?
  LOG "nitidez (rc=$_rc): $(echo "$NIT_SAIDA" | tr '\n' ' ')"
  [ "$_rc" = "0" ] || return 1
  for _nr in $NIT_REGIOES; do
    numero "$(nit_valor "$_nr")" || { LOG "[AVISO] saida da nitidez ilegivel"; return 1; }
  done
  NIT_OK=1
}
classificar_nitidez(){
  N_C=$(nit_valor r2c2)
  N_E=$(awk -v a="$(nit_valor r1c1)" -v b="$(nit_valor r3c1)" 'BEGIN{print (a+0 > b+0) ? a : b}')
  N_D=$(awk -v a="$(nit_valor r1c3)" -v b="$(nit_valor r3c3)" 'BEGIN{print (a+0 > b+0) ? a : b}')
  if maior "$N_E" "$N_D"; then N_P=$N_E; else N_P=$N_D; fi
  _nlim=$(awk -v c="$N_C" -v r="$RAZAO_BORDA" 'BEGIN{printf "%.2f", c*r}')
  NIT_CAUSA=nenhuma
  if maior "$N_C" "$G_LIMIAR"; then NIT_CAUSA=centro
  elif maior "$N_E" "$_nlim" && maior "$N_D" "$_nlim"; then NIT_CAUSA=cantos
  elif maior "$N_E" "$_nlim"; then NIT_CAUSA=lado_esquerdo
  elif maior "$N_D" "$_nlim"; then NIT_CAUSA=lado_direito
  fi
}

# shellcheck disable=SC2317
luz_do_dono(){
  arq_seguro "$SUITE/luz" || return 0
  _lz=$(head -c 16 "$SUITE/luz" 2>/dev/null | tr -d '\r\n')
  case "$_lz" in ''|*[!0-9]*) return 0 ;; esac
  [ "${#_lz}" -le 3 ] && [ "$_lz" -ge 10 ] && [ "$_lz" -le 100 ] || return 0
  [ -x "$HIDEBUG" ] || return 0
  printf 'picture\nsbl %s\nquit\n' "$_lz" | timeout 15 "$HIDEBUG" >/dev/null 2>&1
  setprop vendor.pfl7560.luz "$_lz"
  LOG "luz guardada aplicada no fim da suite: $_lz%"
}
hb_foco(){
  case "$1" in
    gfd|gfdr) ;;
    "sfd "*) case "${1#sfd }" in ''|*[!0-9]*) return 1 ;; esac ;;
    *) return 1 ;;
  esac
  [ -x "$HIDEBUG" ] || return 1
  printf 'custom\n%s\nquit\n' "$1" | timeout 15 "$HIDEBUG" 2>/dev/null
}
foco_pos(){ hb_foco gfd | grep -aiE 'focus|distance' | grep -aoE '[0-9]+' | tail -1; }
foco_faixa(){ hb_foco gfdr | grep -a '\[' | grep -aoE '[0-9]+' | head -2 | tr '\n' ' '; }
foco_ir(){
  hb_foco "sfd $1" >/dev/null || return 1
  _vi=0; _vl=""
  while [ "$_vi" -lt "$VARRE_CHEGADA" ]; do
    sleep "$VARRE_PAUSA"
    _vl=$(foco_pos)
    if [ -n "$_vl" ]; then
      _vd=$(( _vl - $1 )); [ "$_vd" -lt 0 ] && _vd=$(( -_vd ))
      [ "$_vd" -le "$VARRE_TOLERANCIA" ] && return 0
    fi
    _vi=$(( _vi + 1 ))
  done
  LOG "[AVISO] varredura: o foco nao chegou a $1 (gfd: ${_vl:-sem resposta})"
  return 1
}
foco_aproximar(){
  _va=$(( $1 - VARRE_PASSO ))
  [ -n "$FOCO_MIN" ] && [ "$_va" -lt "$FOCO_MIN" ] && _va=$FOCO_MIN
  [ "$_va" -lt 0 ] && _va=0
  [ "$_va" != "$1" ] && foco_ir "$_va"
  foco_ir "$1"
}
medir_centro(){
  _vg=$(nlcam_exec geometria "$VIDEO" "$SUITE/faixas.txt" "$CAM_DESCARTE") || return 1
  M_CENTRO=$(echo "$_vg" | sed -n 's/^borda_centro_px=\([0-9][0-9]*\.[0-9]*\)$/\1/p' | head -1)
  numero "$M_CENTRO"
}
varredura_foco(){
  VARRE_P0=""; VARRE_PF=""; VARRE_DEPOIS=""; FOCO_MIN=""; FOCO_MAX=""
  if [ "$VARRE_LIGADA" != "1" ]; then
    LOG "varredura: desligada (o gfd do hidebug mede o que falta o motor andar, nao a posicao; medido em 2026-10-31)"
    VARRE=desligada; return 1
  fi
  if [ "$(getprop sys.newlink.auto 2>/dev/null)" = "1" ]; then
    LOG "varredura: o autofoco esta em curso, o motor fica com ele"; VARRE=pulada; return 1
  fi
  _vp0=$(foco_pos)
  if [ -z "$_vp0" ]; then
    LOG "[AVISO] varredura: o hidebug nao deu a posicao do foco (gfd: $(limpo "$(hb_foco gfd)" 80)); o motor nao foi mexido"
    VARRE=sem_hidebug; return 1
  fi
  VARRE_P0=$_vp0
  _vr=$(foco_faixa)
  _vmn=$(echo "$_vr" | cut -d' ' -f1); _vmx=$(echo "$_vr" | cut -d' ' -f2)
  if [ -n "$_vmn" ] && [ -n "$_vmx" ] && [ "$_vmn" -lt "$_vmx" ]; then FOCO_MIN=$_vmn; FOCO_MAX=$_vmx; fi
  LOG "varredura: foco em $_vp0 (faixa ${FOCO_MIN:-?} a ${FOCO_MAX:-?}), borda do centro $G_BC px; $VARRE_LADO passo(s) de $VARRE_PASSO para cada lado"
  VARRE_ATIVA=1
  _vb=$_vp0; _vbm=$G_BC; _vok=1
  _vk=$(( -VARRE_LADO ))
  while [ "$_vk" -le "$VARRE_LADO" ]; do
    _vp=$(( _vp0 + _vk * VARRE_PASSO )); _vk=$(( _vk + 1 ))
    [ "$_vp" -lt 0 ] && continue
    [ -n "$FOCO_MIN" ] && { [ "$_vp" -lt "$FOCO_MIN" ] || [ "$_vp" -gt "$FOCO_MAX" ]; } && continue
    foco_ir "$_vp" || { _vok=0; break; }
    medir_centro || { LOG "[AVISO] varredura: a camera nao mediu em $_vp"; _vok=0; break; }
    LOG "varredura: foco $_vp, borda do centro $M_CENTRO px"
    if awk -v m="$M_CENTRO" -v b="$_vbm" -v g="$VARRE_GANHO" 'BEGIN{if (m + g <= b) exit 0; exit 1}'; then
      _vb=$_vp; _vbm=$M_CENTRO
    fi
  done
  if [ "$_vok" = "1" ] && [ "$_vb" != "$_vp0" ]; then
    if foco_aproximar "$_vb" && medir_centro && \
       awk -v m="$M_CENTRO" -v b="$G_BC" -v g="$VARRE_GANHO" 'BEGIN{if (m + g <= b) exit 0; exit 1}'; then
      VARRE=melhorou; VARRE_PF=$_vb; VARRE_DEPOIS=$M_CENTRO; VARRE_ATIVA=0
      LOG "varredura: fica em $_vb (borda do centro $G_BC -> $M_CENTRO px)"
      return 0
    fi
    LOG "varredura: a melhora em $_vb nao se confirmou: volto a $_vp0"
  fi
  if [ "$_vok" = "1" ]; then VARRE=sem_ganho; else VARRE=falhou; fi
  foco_aproximar "$_vp0"
  _vl=$(foco_pos)
  if [ -n "$_vl" ] && [ "$(( _vl - _vp0 ))" -le "$VARRE_TOLERANCIA" ] && [ "$(( _vp0 - _vl ))" -le "$VARRE_TOLERANCIA" ]; then
    VARRE_PF=$_vl; VARRE_ATIVA=0
    LOG "varredura: nada melhorou ($VARRE): o foco voltou a $_vp0"
  else
    LOG "[ERRO] varredura: NAO confirmei a volta do foco a $_vp0 (gfd: ${_vl:-sem resposta}); refaca o foco pela tecla do controle"
    VARRE=nao_voltou; VARRE_ATIVA=0
  fi
  return 1
}
foco_ruim(){
  awk -v c="$G_BC" -v e="$G_BE" -v d="$G_BD" -v r="$RAZAO_BORDA" -v l="$G_LIMIAR" \
    'BEGIN{if (e > r*c || d > r*c || c > l || e > l || d > l) exit 0; exit 1}'
}
ler_quatro_pontos(){
  if [ "$(getprop persist.display.720p 2>/dev/null)" = "true" ]; then _z="0,720 1280,720 0,0 1280,0"; else _z="0,1080 1920,1080 0,0 1920,0"; fi
  _lt=$(getprop persist.sys.keystone.lt 2>/dev/null | tr -d ' ')
  _rt=$(getprop persist.sys.keystone.rt 2>/dev/null | tr -d ' ')
  _lb=$(getprop persist.sys.keystone.lb 2>/dev/null | tr -d ' ')
  _rb=$(getprop persist.sys.keystone.rb 2>/dev/null | tr -d ' ')
  res keystone "lt=$_lt rt=$_rt lb=$_lb rb=$_rb"
  if [ -z "$_lt" ] || [ -z "$_rt" ] || [ -z "$_lb" ] || [ -z "$_rb" ]; then QP=a_ler
  elif [ "$_lt $_rt $_lb $_rb" = "$_z" ]; then QP=zerada
  else QP=ligada; fi
  res quatro_pontos "$QP"
}
ler_resolucao(){
  _wm=$(wm size 2>/dev/null)
  _r=$(echo "$_wm" | sed -n 's/^Override size: \([0-9][0-9]*x[0-9][0-9]*\).*$/\1/p' | head -1)
  [ -n "$_r" ] || _r=$(echo "$_wm" | sed -n 's/^Physical size: \([0-9][0-9]*x[0-9][0-9]*\).*$/\1/p' | head -1)
  if [ -z "$_r" ]; then
    case "$(getprop persist.display.720p 2>/dev/null)" in true) _r=1280x720 ;; false) _r=1920x1080 ;; esac
  fi
  res resolucao "$_r"
  if [ -n "$_r" ]; then I_RESOLUCAO="$_r|info"; else I_RESOLUCAO="[a ler]|pendente"; fi
}
ler_modo_projecao(){
  _mm=$(getprop persist.sys.mountingmode 2>/dev/null | tr -cd '0-9')
  _fm=$(getprop persist.sys.fac_flipmode 2>/dev/null | tr -cd '0-9')
  res mountingmode "$_mm"; res fac_flipmode "$_fm"
  case "$_mm" in
    1) I_MODO="normal (1)|info" ;;
    2) I_MODO="espelhada H (2)|info" ;;
    3) I_MODO="girada 180\u00b0 (3)|info" ;;
    4) I_MODO="espelhada V (4)|info" ;;
    *) I_MODO="[a ler]|pendente" ;;
  esac
}
etapa_geometria(){
  I_CAMERA=""; FOCO_N=0; G_OK=0; NIT_OK=0; VARRE=nao_precisou
  ler_resolucao
  ler_quatro_pontos
  ler_modo_projecao
  if [ ! -e "$VIDEO" ]; then
    LOG "[AVISO] $VIDEO nao existe: angulo, foco e nitidez sem leitura."
    res camera ausente
  elif nlcam_ok && { medir_geo || { esperar_ok_camera 2 && medir_geo; }; }; then
    while foco_ruim && [ "$FOCO_N" -lt "$FOCO_TENTATIVAS" ]; do
      FOCO_N=$(( FOCO_N + 1 ))
      LOG "foco ruim (bordas centro/esq/dir $G_BC/$G_BE/$G_BD px, limiar $G_LIMIAR): refazendo o autofoco ($FOCO_N de $FOCO_TENTATIVAS)"
      disparar_autofoco
      medir_geo || break
    done
    if [ "$G_OK" = "1" ] && foco_ruim; then
      LOG "foco ainda ruim depois de $FOCO_N autofoco(s): varredura fina pelo hidebug"
      G_BC_ANTES=$G_BC
      if varredura_foco; then medir_geo; fi
      res foco_varredura "$VARRE"; res foco_pos_inicial "$VARRE_P0"; res foco_pos_final "$VARRE_PF"
      res foco_borda_antes "$G_BC_ANTES"; res foco_borda_depois "$VARRE_DEPOIS"
    else
      res foco_varredura "$VARRE"
    fi
    res camera "$( [ "$G_OK" = 1 ] && echo ok || echo falhou)"
  else
    res camera falhou
  fi
  res foco_tentativas "$FOCO_N"
  if [ "$G_OK" != "1" ]; then
    I_ANGULO="[sem leitura]|pendente"; I_FOCO="[sem leitura]|pendente"; I_NITIDEZ="[sem leitura]|pendente"
    P_GEO=pendente
  else
    res geo_inclinacao_graus "$G_INC"; res geo_trapezio_pct "$G_TRAP"; res geo_borda_centro_px "$G_BC"
    res geo_borda_esq_px "$G_BE"; res geo_borda_dir_px "$G_BD"; res geo_contraste_centro "$G_CONT"
    res geo_quadro_largura "$G_L"; res geo_limiar_borda_px "$G_LIMIAR"
    P_GEO=ok
    _ga=$(abs "$G_INC")
    _gtxt="$(virgula "$(um_dec "$_ga")")\u00b0"
    _conselho=0
    if [ "$QP" = "ligada" ] && { maior "$G_TRAP" "$TRAPEZIO_MAX" || maior "$G_BC" "$G_LIMIAR" || maior "$_ga" "$INCLINACAO_MAX"; }; then _conselho=1; fi
    _dica_nit=0; _dica_qp=0
    if [ "${NIT_OK:-0}" = "1" ]; then
      classificar_nitidez
      for _nr in $NIT_REGIOES; do res "nitidez_$_nr" "$(nit_valor "$_nr")"; done
      res nitidez_centro_px "$N_C"; res nitidez_pior_canto_px "$N_P"; res nitidez_causa "$NIT_CAUSA"
      _nc=$(virgula "$(um_dec "$N_C")"); _np=$(virgula "$(um_dec "$N_P")")
      if [ "${#_nc}" -le 3 ] && [ "${#_np}" -le 3 ]; then _nv="$_nc \u00b7 canto $_np px"; else _nv="$_nc \u00b7 canto $_np"; fi
      case "$NIT_CAUSA" in
        centro)
          I_NITIDEZ="$_nv|atencao"; P_GEO=atencao; _dica_nit=1
          if [ "$FOCO_N" -gt 0 ] || [ "$VARRE" != nao_precisou ]; then
            dica "Centro borrado ($_nc px): foco refeito. Se continuar, limpe a lente e confira a dist\u00e2ncia at\u00e9 a parede."
          else
            dica "Centro borrado ($_nc px): refa\u00e7a o foco pela tecla do controle."
          fi ;;
        lado_esquerdo|lado_direito)
          I_NITIDEZ="$_nv|atencao"; P_GEO=atencao; _dica_nit=1
          if [ "$NIT_CAUSA" = lado_esquerdo ]; then _nl=esquerdo; else _nl=direito; fi
          if [ "$QP" = "ligada" ]; then
            _dica_qp=1
            dica "Cantos do lado $_nl borrados ($_np px; centro $_nc px): zere os 4 pontos e alinhe o projetor de frente."
          else
            dica "Cantos do lado $_nl borrados ($_np px; centro $_nc px): alinhe o projetor de frente para a parede."
          fi ;;
        *)
          if maior "$N_P" "$G_LIMIAR"; then I_NITIDEZ="$_nv|atencao"; P_GEO=atencao; else I_NITIDEZ="$_nv|ok"; fi ;;
      esac
    elif maior "$G_BC" "$G_LIMIAR"; then
      I_NITIDEZ="baixa ($(virgula "$(um_dec "$G_BC")") px)|atencao"; P_GEO=atencao
    else
      I_NITIDEZ="boa ($(virgula "$(um_dec "$G_BC")") px)|ok"
    fi
    if foco_ruim; then
      I_FOCO="irregular|atencao"; P_GEO=atencao
      [ "$_dica_nit" = "1" ] || dica "Foco irregular mesmo depois de $FOCO_N autofoco(s): limpe a lente e confira a dist\u00e2ncia at\u00e9 a parede."
    elif [ "$VARRE" = melhorou ]; then
      I_FOCO="ajuste fino|corrigido"; [ "$P_GEO" = ok ] && P_GEO=corrigido
    elif [ "$FOCO_N" -gt 0 ]; then
      I_FOCO="refeito (${FOCO_N}x)|corrigido"; [ "$P_GEO" = ok ] && P_GEO=corrigido
    else
      I_FOCO="bom|ok"
    fi
    if [ "$_conselho" = "1" ]; then
      I_QP="ligada|atencao"; P_GEO=atencao
      [ "$_dica_qp" = "1" ] || dica "4 pontos ligados e imagem distorcida: alinhe o projetor de frente para a parede e zere os 4 pontos."
    fi
    if maior "$_ga" "$INCLINACAO_MAX"; then
      I_ANGULO="$_gtxt|atencao"; P_GEO=atencao
      if [ "$QP" != "ligada" ]; then
        if awk -v g="$G_INC" -v s="$SINAL_INCLINACAO" 'BEGIN{if (g*s > 0) exit 0; exit 1}'; then _lado=direito; else _lado=esquerdo; fi
        dica "Imagem inclinada $_gtxt: abaixe o lado $_lado do projetor."
      fi
    else
      I_ANGULO="$_gtxt|ok"
    fi
  fi
  case "$QP" in
    zerada) I_QP="zerada|ok" ;;
    ligada) [ -n "${I_QP:-}" ] || I_QP="ligada|info" ;;
    *) I_QP="[a ler]|pendente" ;;
  esac
  if [ "$G_OK" = "1" ] || [ "${COR_FAIXAS:-}" = "$FAIXAS_N" ]; then I_CAMERA="funcionando|ok"
  elif [ ! -e "$VIDEO" ]; then I_CAMERA="ausente|pendente"
  else I_CAMERA="sem leitura|atencao"; fi
}

ini_efetivo(){
  _pid=$(getprop ro.boot.projectid 2>/dev/null | tr -cd 'A-Za-z0-9_')
  for _ic in "$ATV_INI_DIR/ZYCustom_$_pid.ini" "$ATV_INI_DIR/ZYCustom.ini" "$INI_VENDOR"; do
    [ -f "$_ic" ] && { echo "$_ic"; return 0; }
  done
  echo "$INI_VENDOR"
}
graus(){ getprop "$1" 2>/dev/null | tr -cd '0-9.' | cut -c1-8; }
etapa_temperatura(){
  novos_campos etapa3
  campo etapa "Etapa 3 de 4 \u00b7 temperatura"
  campo titulo "Temperatura"
  campo texto "Lendo os sensores do LED e da placa, a ventoinha e o brilho. Nada \u00e9 alterado."
  passos_fila "feito|$P_COR" "feito|$P_GEO" agora fila
  campo tom normal
  tela aviso etapa3 "$CAMPOS"

  T_LED=$(graus zysys.env_temp); T_PLACA=$(graus zysys.light_temp)
  res temp_led_c "$T_LED"; res temp_placa_c "$T_PLACA"
  _hb=$(printf 'custom\ngfs 0\ngfs 1\ngbri 0\nquit\n' | timeout 15 "$HIDEBUG" 2>/dev/null)
  _f=$(echo "$_hb" | grep -a 'fan speed' | grep -aoE '[0-9]+')
  F0=$(echo "$_f" | sed -n 1p); F1=$(echo "$_f" | sed -n 2p)
  BRILHO=$(echo "$_hb" | grep -a 'backlight brightness' | grep -aoE '[0-9]+' | sed -n 1p)
  res ventoinha_0 "$F0"; res ventoinha_1 "$F1"; res brilho "$BRILHO"

  INI_EF=$(ini_efetivo)
  INI_EF_MD5=$(md5_de "$INI_EF")
  res ini_efetivo "${INI_EF#"$R"}"; res ini_md5 "$INI_EF_MD5"
  if grep -a POLICY_0_THRESHOLD "$INI_EF" 2>/dev/null | head -1 | grep -q "$ESCADA"; then ESC=presente; else ESC=ausente; fi
  res escada "$ESC"
  if [ "$INI_EF_MD5" = "$INI_MD5_OK" ] || [ "$INI_EF_MD5" = "$INI_MD5_OK_NOTYPEC" ]; then
    TERMICA=ativa; I_TERM="ativa|ok"
  elif [ "$INI_EF" != "$INI_VENDOR" ]; then
    TERMICA=anulada; I_TERM="anulada em /atv|atencao"
    dica "Corre\u00e7\u00e3o t\u00e9rmica anulada por um ZYCustom em /atv/ini: remova esse arquivo (doc 06)."
  else
    TERMICA=ausente; I_TERM="n\u00e3o aplicada|atencao"
    dica "Corre\u00e7\u00e3o t\u00e9rmica n\u00e3o aplicada: rode o kit de corre\u00e7\u00e3o de novo."
  fi
  res correcao_termica "$TERMICA"

  P_TEMP=ok
  if numero "$T_LED"; then
    if maior "$T_LED" "$LED_QUENTE" || [ "$(um_dec "$T_LED")" = "$(um_dec "$LED_QUENTE")" ]; then
      I_LED="$(virgula "$(um_dec "$T_LED")") \u00b0C|atencao"; P_TEMP=atencao
      dica "LED quente ($(virgula "$(um_dec "$T_LED")") \u00b0C): deixe as entradas e sa\u00eddas de ar livres e o lugar ventilado."
    else
      I_LED="$(virgula "$(um_dec "$T_LED")") \u00b0C|ok"
    fi
  else
    I_LED="[a ler]|pendente"
  fi
  if numero "$T_PLACA"; then I_PLACA="$(virgula "$(um_dec "$T_PLACA")") \u00b0C|ok"; else I_PLACA="[a ler]|pendente"; fi
  if numero "$BRILHO"; then I_BRILHO="$BRILHO|info"; else I_BRILHO="[a ler]|pendente"; fi
  if numero "$F0" && numero "$F1"; then
    if [ "$F0" = "0" ] || [ "$F1" = "0" ]; then
      I_VENT="$F0 / $F1 parada|atencao"; P_TEMP=atencao
      dica "Uma ventoinha est\u00e1 parada: desligue o projetor e procure a assist\u00eancia."
    else
      I_VENT="$F0 / $F1|ok"
    fi
  else
    I_VENT="[a ler]|pendente"
  fi
  [ "$TERMICA" = "ativa" ] || P_TEMP=atencao
}

valor_ini(){ grep -a "$1" "$INI_EF" 2>/dev/null | grep -ao '[0-9]\{4,\}' | head -1; }
etapa_rampa(){
  RAMPA=pulada; I_RAMPA="n\u00e3o testada|pendente"; P_RAMPA=pendente
  _w=$(valor_ini WARNING_VALUE); _e=$(valor_ini EMERGENCY_VALUE)
  res rampa_warning "$_w"; res rampa_emergency "$_e"
  _motivo=""
  case "$_w$_e" in ''|*[!0-9]*) _motivo="WARNING/EMERGENCY ilegiveis" ;; esac
  [ -z "$_w" ] || [ -z "$_e" ] && _motivo="WARNING/EMERGENCY ilegiveis"
  if [ -z "$_motivo" ] && { [ "$INJETADO" -le "$_w" ] || [ "$INJETADO" -ge "$_e" ]; }; then
    _motivo="71000 fora de WARNING=$_w..EMERGENCY=$_e"
  fi
  if [ -z "$_motivo" ] && [ "$TERMICA" != "ativa" ]; then _motivo="ini efetivo nao e o corrigido"; fi
  if [ -z "$_motivo" ] && ! { numero "$T_LED" && ! maior "$T_LED" "$RAMPA_LED_MAX" && [ "$(um_dec "$T_LED")" != "$(um_dec "$RAMPA_LED_MAX")" ]; }; then
    _motivo="LED quente ou ilegivel"
  fi
  if [ -n "$_motivo" ]; then
    LOG "[AVISO] rampa: NAO vou injetar ($_motivo)."
    res rampa pulada; res rampa_motivo "$_motivo"
    return 0
  fi

  novos_campos etapa4
  campo etapa "Etapa 4 de 4 \u00b7 prote\u00e7\u00e3o t\u00e9rmica"
  campo titulo "A imagem vai escurecer\npor cerca de 1 minuto."
  campo texto "\u00c9 o teste de que a prote\u00e7\u00e3o contra calor est\u00e1 funcionando: o projetor finge estar quente, baixa o brilho e volta sozinho. Pode aparecer um aviso de temperatura: faz parte do teste e ele fecha sozinho."
  passos_fila "feito|$P_COR" "feito|$P_GEO" "feito|$P_TEMP" agora
  campo tom alerta
  tela aviso etapa4 "$CAMPOS"

  _lc="$SUITE/rampa-logcat.txt"
  rm -f "$_lc"
  timeout 120 logcat -v time -T 1 -s ZYThermalManager > "$_lc" 2>&1 </dev/null &
  LOGCAT_PID=$!
  sleep "$RAMPA_ANTES"
  LOG "rampa: injetando $INJETADO mC (WARNING=$_w, EMERGENCY=$_e) por ${RAMPA_INJETADO}s"
  RAMPA_ATIVA=1
  setprop "$PROP_OVERRIDE" "$INJETADO"
  sleep "$RAMPA_INJETADO"
  if rampa_limpar; then _limpo=ok; else _limpo=falhou; fi
  sleep "$RAMPA_DEPOIS"
  fechar_alertas
  parar_logcat
  _nw=$(grep -ac 'Overheat Warning' "$_lc" 2>/dev/null)
  _desce=$(grep -a 'Level Change' "$_lc" 2>/dev/null | grep -a '=> 850!' | grep -avc '850 => 850!')
  _sobe=$(grep -a 'Level Change' "$_lc" 2>/dev/null | grep -a '=> 1000!' | grep -avc '1000 => 1000!')
  res rampa_warn "${_nw:-0}"; res rampa_desce "${_desce:-0}"; res rampa_sobe "${_sobe:-0}"; res rampa_limpeza "$_limpo"
  if [ "$_limpo" != "ok" ]; then
    RAMPA=limpeza_falhou; I_RAMPA="limpeza falhou|atencao"; P_RAMPA=atencao
    dica "Reinicie o projetor agora: o teste t\u00e9rmico n\u00e3o confirmou a limpeza."
  elif [ "${_nw:-0}" -ge 1 ] && [ "${_desce:-0}" -ge 1 ]; then
    RAMPA=reagiu; P_RAMPA=ok
    if [ "${_sobe:-0}" -ge 1 ]; then I_RAMPA="reagiu e voltou|ok"; else I_RAMPA="reagiu|ok"; fi
  else
    RAMPA=nao_reagiu; I_RAMPA="n\u00e3o reagiu|atencao"; P_RAMPA=atencao
    dica "A prote\u00e7\u00e3o t\u00e9rmica n\u00e3o reagiu ao teste: reinicie o projetor e verifique de novo."
  fi
  res rampa "$RAMPA"
  LOG "rampa: $RAMPA (Overheat Warning=${_nw:-0}, desceu=${_desce:-0}, voltou=${_sobe:-0}, limpeza=$_limpo)"
}

ler_sistema(){
  _fw=$(getprop ro.zhiying.version 2>/dev/null)
  res firmware "$_fw"
  if [ -n "$_fw" ]; then I_FW="$(limpo "$_fw" 30)|info"; else I_FW="[a ler]|pendente"; fi
  _wf=0; grep -q "wifi_disconnect_on_boot=0" "$BP" 2>/dev/null && _wf=1
  # shellcheck disable=SC2018
  _ws=$(head -n 1 "$WLAN_ESTADO" 2>/dev/null | tr -cd 'a-z')
  res wifi_reconecta "$_wf"; res wifi_estado "$_ws"
  if [ "$_wf" != "1" ]; then I_WIFI="n\u00e3o reconecta|atencao"
  elif [ "$_ws" = "up" ]; then I_WIFI="conectado|ok"
  else I_WIFI="desconectado|info"; fi
  case "$MODO" in
    tomada)
      case "$MOTIVO_BOOT" in
        gatilho_sempre) _mb="gatilho sempre" ;;
        desligamento_nao_limpo) _mb="n\u00e3o desligou bem" ;;
        relogio_zerado) _mb="rel\u00f3gio zerado" ;;
        *) _mb="queda de energia" ;;
      esac ;;
    pendrive) _mb="pendrive do kit" ;;
    *) _mb="verifica\u00e7\u00e3o pedida" ;;
  esac
  MOTIVO_TXT="$_mb"
  I_MOTIVO="$_mb|info"
  res motivo "$MODO $MOTIVO_BOOT"; res sys_boot_reason "$(getprop sys.boot.reason 2>/dev/null)"
  DATA_HORA=$(date '+%d/%m/%Y %H:%M' 2>/dev/null)
  I_DATA="$(limpo "$DATA_HORA" 20)|info"
}

dica(){ printf '%s\n' "$1" >> "$SUITE/dicas.tmp"; }
item(){
  campo item "$1|$2"
  printf '%s\n' "${2##*|}" >> "$SUITE/estados.tmp"
  N_ITENS=$(( N_ITENS + 1 ))
}
etapa_resumo(){
  ler_sistema
  N_ITENS=0
  : > "$SUITE/estados.tmp"
  novos_campos resumo
  campo grupo COR
  item "Formato do painel" "$I_FORMATO"
  item "C\u00e2mera" "$I_CAMERA"
  item "Painel" "$I_PAINEL"
  campo grupo IMAGEM
  item "Resolu\u00e7\u00e3o" "$I_RESOLUCAO"
  item "\u00c2ngulo" "$I_ANGULO"
  item "Foco" "$I_FOCO"
  item "Nitidez" "$I_NITIDEZ"
  item "4 pontos" "$I_QP"
  item "Modo de proje\u00e7\u00e3o" "$I_MODO"
  campo grupo TEMPERATURA
  item "LED" "$I_LED"
  item "Placa" "$I_PLACA"
  item "Brilho" "$I_BRILHO"
  item "Ventoinha" "$I_VENT"
  item "Rampa t\u00e9rmica" "$I_RAMPA"
  campo grupo SISTEMA
  item "Firmware" "$I_FW"
  item "Corre\u00e7\u00e3o t\u00e9rmica" "$I_TERM"
  item "Wi-Fi" "$I_WIFI"
  item "Motivo do boot" "$I_MOTIVO"
  item "Data e hora" "$I_DATA"
  N_CORR=$(grep -c '^corrigido$' "$SUITE/estados.tmp")
  N_ATEN=$(grep -c '^atencao$' "$SUITE/estados.tmp")
  res itens "$N_ITENS"; res correcoes "$N_CORR"; res atencoes "$N_ATEN"
  _c2="$GERA_DIR/resumo.cab"
  {
    if [ "$N_ATEN" -gt 0 ]; then
      printf '%s\n' "titulo=Aten\u00e7\u00e3o."
      if [ "$N_ATEN" = 1 ]; then printf '%s\n' "destaque=1 ponto pede cuidado."; else printf '%s\n' "destaque=$N_ATEN pontos pedem cuidado."; fi
      printf '%s\n' "destaque_estado=atencao"
    elif [ "$N_CORR" -gt 0 ]; then
      printf '%s\n' "titulo=Tudo certo."
      if [ "$N_CORR" = 1 ]; then printf '%s\n' "destaque=1 corre\u00e7\u00e3o feita."; else printf '%s\n' "destaque=$N_CORR corre\u00e7\u00f5es feitas."; fi
      printf '%s\n' "destaque_estado=corrigido"
    else
      printf '%s\n' "titulo=Tudo certo."
    fi
    printf '%s\n' "canto=fecha sozinho em $TEMPO_RESUMO s \u00b7 qualquer tecla fecha"
    cat "$CAMPOS"
    head -n 3 "$SUITE/dicas.tmp" 2>/dev/null | while IFS= read -r _d; do printf 'dica=%s\n' "$_d"; done
    printf '%s\n' "rodape=$MOTIVO_TXT \u00b7 $(limpo "$DATA_HORA" 20) \u00b7 relat\u00f3rio em /data/vendor/pfl7560-suite/ultimo.log"
  } > "$_c2"
  mv -f "$_c2" "$CAMPOS"
  res dicas "$(grep -c '' "$SUITE/dicas.tmp" 2>/dev/null)"
  LOG "resumo: $N_ITENS itens, $N_CORR correcao(oes), $N_ATEN atencao(oes)"
  if tela resumo resumo "$CAMPOS"; then
    if timeout "$TEMPO_RESUMO" getevent -qlc 3 2>/dev/null | grep -q 'EV_KEY.*DOWN'; then LOG "resumo fechado por tecla"; fi
  else
    LOG "[AVISO] resumo sem tela gerada: o resultado esta em $RES"
  fi
}
etapa_final_pendrive(){
  [ -f "$RES.new" ] && cp "$RES.new" "$RES" 2>/dev/null
  copiar_log_pendrive
  novos_campos final
  campo titulo "Pode tirar o pendrive."
  if [ "$AVISO_ARG" = "termica-falhou" ]; then
    campo texto "A verifica\u00e7\u00e3o terminou, mas parte da corre\u00e7\u00e3o do kit falhou: veja o newlink_update.log no pendrive."
  else
    campo texto "A verifica\u00e7\u00e3o terminou. O resultado ficou salvo no projetor e no pendrive (newlink_suite.log)."
  fi
  passos_fila "feito|$P_COR" "feito|$P_GEO" "feito|$P_TEMP" "feito|$P_RAMPA"
  campo rodape "volta \u00e0 tela inicial quando o pendrive sair"
  if [ "$AVISO_ARG" = "termica-falhou" ]; then campo tom alerta; else campo tom normal; fi
  if [ "$COR_RES" = "erro" ] || [ "$AVISO_ARG" = "termica-falhou" ]; then _est=erro; else _est=pronto; fi
  tela aviso final "$CAMPOS" "$_est"
  _t=0
  while [ "$_t" -lt "$ESPERA_TIRAR" ] && [ -f "$MP/newlink_update.sh" ]; do
    sleep 2; _t=$(( _t + 2 ))
  done
}

modo_desinstalar(){
  _drc=0
  LOG "desinstalando a suite"
  if [ -n "${1:-}" ] && [ -d "$1" ] && dir_seguro "$SUITE"; then
    for _bk in "$SUITE"/panelparam-backup-*.img; do
      arq_seguro "$_bk" || continue
      _bn="suite-${_bk##*/}"
      if cp "$_bk" "$1/$_bn" 2>/dev/null && sync && cmp -s "$_bk" "$1/$_bn"; then
        ( cd "$1" && md5sum "$_bn" > "$_bn.md5" ) 2>/dev/null
        LOG "[OK] copia do backup do panelparam levada para o pendrive: $_bn"
      else
        rm -f "$1/$_bn" 2>/dev/null
        LOG "[AVISO] nao consegui levar ${_bk##*/} para o pendrive: ela sai com a pasta da suite."
      fi
    done
  fi
  timeout 5 setprop ctl.stop pfl7560_suite 2>/dev/null
  _vp=$(head -n 1 "$VIGIA_PID" 2>/dev/null | tr -cd '0-9' | cut -c1-10)
  if [ -n "$_vp" ] && grep -aq 'pfl7560' "/proc/$_vp/cmdline" 2>/dev/null; then
    kill "$_vp" 2>/dev/null && LOG "vigia (pid $_vp) encerrado"
  fi
  rm -f "$VIGIA_PID"
  [ -L "$LOCK" ] || rmdir "$LOCK" 2>/dev/null
  if [ -n "$(getprop "$PROP_OVERRIDE" 2>/dev/null)" ]; then
    LOG "override de temperatura ativo depois de parar o servico: limpando"
    rampa_limpar || _drc=1
  fi
  _ovl=$(timeout 15 cmd overlay list 2>/dev/null | tr -d '\r' | sed -n 's/^\[x\] \(com\.pfl7560\.tema\.[A-Za-z0-9_]*\).*$/\1/p')
  for _op in $(printf '%s\n' "$_ovl" | grep -xF com.pfl7560.tema.android) $(printf '%s\n' "$_ovl" | grep -vxF com.pfl7560.tema.android); do
    if timeout 15 cmd overlay disable "$_op" >/dev/null 2>&1; then LOG "[OK] sobreposicao $_op desligada"; else LOG "[AVISO] nao consegui desligar a sobreposicao $_op."; fi
  done
  _hl=0; grep -q '^vendor\.newlink\.launcher\.package=com\.pfl7560\.home$' "$BP" 2>/dev/null && _hl=1
  _fl=0; grep -q '^vendor\.nl\.filemanage_file=1$' "$BP" 2>/dev/null && _fl=1
  _ov=""
  for _od in "$R/vendor/overlay"/PFL7560Tema*; do
    if [ -e "$_od" ] || [ -L "$_od" ]; then _ov="$_ov $_od"; fi
  done
  if [ -e "$RC_SUITE" ] || [ -L "$RC_SUITE" ] || [ "$_hl" = "1" ] || [ "$_fl" = "1" ] || [ -n "$_ov" ]; then
    if mount -o rw,remount /vendor; then
      rm -f "$RC_SUITE"
      if [ "$_hl" = "1" ]; then
        cp "$BP" "$BP.new" && sed -i '/^vendor\.newlink\.launcher\.package=com\.pfl7560\.home$/d' "$BP.new" && sync && mv "$BP.new" "$BP"
        rm -f "$BP.new"
      fi
      if [ "$_fl" = "1" ]; then
        cp "$BP" "$BP.new" && sed -i '/^vendor\.nl\.filemanage_file=1$/d' "$BP.new" && sync && mv "$BP.new" "$BP"
        rm -f "$BP.new"
      fi
      for _od in $_ov; do rm -rf "$_od"; done
      sync
      mount -o ro,remount /vendor 2>/dev/null
    fi
    if [ -e "$RC_SUITE" ] || [ -L "$RC_SUITE" ]; then LOG "[ERRO] nao consegui remover $RC_SUITE."; _drc=1; else LOG "[OK] servico de boot removido"; fi
    if grep -q '^vendor\.newlink\.launcher\.package=com\.pfl7560\.home$' "$BP" 2>/dev/null; then LOG "[ERRO] nao consegui tirar a home nova do build.prop."; _drc=1
    elif [ "$_hl" = "1" ]; then LOG "[OK] home nova desligada (a de fabrica volta no proximo boot)"; fi
    if grep -q '^vendor\.nl\.filemanage_file=1$' "$BP" 2>/dev/null; then LOG "[ERRO] nao consegui tirar a prop do gerenciador de arquivos do build.prop."; _drc=1
    elif [ "$_fl" = "1" ]; then LOG "[OK] gerenciador de arquivos: prop tirada (a pagina inicial de fabrica volta no proximo boot)"; fi
    if [ -n "$_ov" ]; then
      _ovsobra=""
      for _od in $_ov; do if [ -e "$_od" ] || [ -L "$_od" ]; then _ovsobra="$_ovsobra $_od"; fi; done
      if [ -n "$_ovsobra" ]; then LOG "[ERRO] nao consegui remover as sobreposicoes:$_ovsobra"; _drc=1; else LOG "[OK] sobreposicoes de tema removidas de /vendor/overlay"; fi
    fi
  fi
  _dis=$(timeout 15 pm list packages -d 2>/dev/null)
  for _ap in com.mobisystems.editor.office_registered com.newlink.cast com.hisilicon.miracast; do
    if printf '%s\n' "$_dis" | grep -qx "package:$_ap"; then
      if timeout 15 pm enable --user 0 "$_ap" >/dev/null 2>&1; then LOG "[OK] app $_ap religado (pm enable)"; else LOG "[AVISO] nao consegui religar $_ap."; _drc=1; fi
    fi
  done
  _mrc=0
  for _mn in logo.jpg bootanimation.zip; do
    _mb="$SUITE/marca-original/$_mn"; _md="$R/atv/bootvideo/$_mn"
    if [ ! -f "$_mb" ] || [ -L "$_mb" ]; then continue; fi
    if [ -f "$_md" ] && [ ! -L "$_md" ] && cat "$_mb" > "$_md" 2>/dev/null && cmp -s "$_mb" "$_md"; then
      LOG "[OK] marca: $_mn de fabrica restaurado em /atv/bootvideo"
    else
      LOG "[ERRO] marca: nao consegui restaurar $_mn (o backup fica em $_mb)."; _mrc=1; _drc=1
    fi
  done
  for _k in screensaver_components screensaver_default_component; do
    case "$(timeout 10 settings get secure "$_k" 2>/dev/null)" in
      com.pfl7560.verificar/*)
        if timeout 10 settings put secure "$_k" "$DESCANSO_FABRICA" >/dev/null 2>&1; then
          LOG "[OK] descanso de tela: $_k voltou ao do fabricante"
        else
          LOG "[AVISO] nao consegui devolver $_k ao do fabricante ($DESCANSO_FABRICA)."; _drc=1
        fi ;;
    esac
  done
  [ "$(getprop persist.sys.boot.reason 2>/dev/null)" = "pfl7560,ligado" ] && setprop persist.sys.boot.reason ""
  for _dd in "$SUITE" "$TELA_DIR"; do
    if [ "$_dd" = "$SUITE" ] && [ "$_mrc" = "1" ]; then LOG "a pasta da suite FICA (tem o backup da marca de fabrica)."; continue; fi
    if [ -L "$_dd" ]; then rm -f "$_dd"; elif [ -e "$_dd" ]; then rm -rf "$_dd"; fi
    if [ -e "$_dd" ] || [ -L "$_dd" ]; then LOG "[ERRO] nao consegui remover $_dd."; _drc=1; fi
  done
  [ -L "$PEDIDO_DIR" ] || rm -f "$PEDIDO_DIR/pedir-verificacao" "$PEDIDO_DIR/descanso-inicio" "$PEDIDO_DIR/descanso-fim" 2>/dev/null
  [ -L "$R/data/data/com.pfl7560.home" ] || rm -f "$R/data/data/com.pfl7560.home/luz" 2>/dev/null
  [ "$_drc" = "0" ] && LOG "[OK] suite removida (servico, pasta, pedido e vigia)"
  exit "$_drc"
}

MODO="${1:-}"
MP=""
AVISO_ARG=""
MOTIVO_BOOT=""
case "$MODO" in
  --desinstalar) modo_desinstalar "${2:-}" ;;
  tomada) MOTIVO_BOOT=$(echo "${2:-}" | tr -cd 'a-z_') ;;
  pedido) ;;
  pendrive)
    MP="${2:-}"; AVISO_ARG="${3:-}"
    [ "$AVISO_ARG" = "termica-falhou" ] || AVISO_ARG=""
    if [ -z "$MP" ] || [ ! -d "$MP" ]; then LOG "[ERRO] modo pendrive sem mountpoint valido ('$MP')."; exit 2; fi ;;
  *) echo "uso: suite.sh tomada [motivo] | pedido | pendrive <mountpoint> [termica-falhou] | --desinstalar"; exit 2 ;;
esac

suite_ok || exit 1
if ! pegar_lock; then
  if [ "$MODO" != "pendrive" ]; then LOG "outra suite em andamento (trava) - saindo."; exit 0; fi
  LOG "outra suite em andamento: o modo pendrive espera ela terminar (ate ${ESPERA_TRAVA}s)"
  _t=0
  while ! pegar_lock; do
    [ "$_t" -ge "$ESPERA_TRAVA" ] && { LOG "a outra suite nao terminou - saindo."; exit 0; }
    sleep 5; _t=$(( _t + 5 ))
  done
fi
trap sair EXIT
trap 'exit 130' INT TERM HUP
contar_inicio
rm -f "$LOGF"
exec >"$LOGF" 2>&1 </dev/null
RUN_ID=$(date +%s 2>/dev/null | tr -cd '0-9')
[ -n "$RUN_ID" ] || RUN_ID=$$
LOG "==== suite iniciada: modo=$MODO $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) ===="
rm -f "$RES.new" "$SUITE/dicas.tmp" "$SUITE/estados.tmp"
: > "$RES.new"; : > "$SUITE/dicas.tmp"
res modo "$MODO"; res inicio "$RUN_ID"
P_COR=fila; P_GEO=fila; P_TEMP=fila; P_RAMPA=fila; I_QP=""; QP=a_ler; TERMICA=""
preparar_telas
etapa_abertura
etapa_cor
etapa_geometria
etapa_temperatura
etapa_rampa
etapa_resumo
[ "$MODO" = "pendrive" ] && etapa_final_pendrive
ir_para_inicio
rm -f "$SUITE/dicas.tmp" "$SUITE/estados.tmp"
LOG "==== suite terminada ===="
exit 0
