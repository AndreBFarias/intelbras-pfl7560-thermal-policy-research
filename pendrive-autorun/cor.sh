#!/vendor/bin/sh

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_NLCAMCHECK PFL_NLCAMCHECK_MD5 PFL_MODO_AUTO PFL_RAPIDO PFL_DONO PFL_TESTE
fi
R="${PFL_ROOT:-}"
PP="$R/dev/block/by-name/panelparam"
PROC_PANEL="$R/proc/msp/panel"
WORK="$R/data/vendor/pfl7560-kit"
NLSU="$R/data/local/nlsu"
HOOK="$NLSU/update_after_boot.sh"
LOCK="$R/dev/pfl7560-kit.lock"
LVDSCTL="${PFL_LVDSCTL:-$WORK/lvdsctl}"
NLCAM="${PFL_NLCAMCHECK:-$WORK/nl_camcheck}"
VIDEO="$R/dev/video0"
LVDSCTL_MD5="178d812872cb9306c0ae6faeed07184a"
NLCAM_MD5="02bedd31ae0e82afd10c41daabf2bd56"
DONO_UID=0
MODO_AUTO=1
if [ "${PFL_TESTE:-}" = "1" ]; then
  [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
  [ -n "${PFL_LVDSCTL_MD5:-}" ] && LVDSCTL_MD5="$PFL_LVDSCTL_MD5"
  [ -n "${PFL_NLCAMCHECK_MD5:-}" ] && NLCAM_MD5="$PFL_NLCAMCHECK_MD5"
  [ -n "${PFL_MODO_AUTO:-}" ] && MODO_AUTO="$PFL_MODO_AUTO"
fi
LIBHITV="$R/vendor/lib/libhitvservice.so"
LIBS="/vendor/lib:/system/lib"
JOURNAL="$WORK/journal"
BKP="$WORK/panelparam-original.img"
LOGF="$WORK/cor.log"
SUITE_DIR="$R/data/vendor/pfl7560-suite"
SUITE_MODO=0
COR_RES=erro
COR_FAIXAS="-"

PERFIL_TAM=768
TABELA_BASE=168
LVDS_FMT_OFF=92
PERFIL_MAX=82
PP_TAM=8388608

TEMPO_TECLA=30
TEMPO_ASSENTAR=2
TEMPO_TELA=3
AUTOFOCO_INICIO=60
AUTOFOCO_MAX=70
AUTOFOCO_FOLGA=5
ESPERA_REBOOT=5
[ -n "${PFL_RAPIDO:-}" ] && { TEMPO_ASSENTAR=0; TEMPO_TELA=0; AUTOFOCO_INICIO=0; AUTOFOCO_MAX=0; AUTOFOCO_FOLGA=0; ESPERA_REBOOT=0; }

FAIXAS_N=16
CAM_DESCARTE=15
AMPLITUDE_MIN=40
INV_ERRADO=2

LOG(){ echo "[PFL7560-cor] $*"; }

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
trabalho_ok(){
  dir_seguro "$WORK" && return 0
  LOG "[ERRO] $WORK nao e uma pasta so do root (link, dono errado ou aberta a outros) - NAO vou usar nem escrever."
  return 1
}

pegar_lock(){ mkdir "$LOCK" 2>/dev/null; }
# shellcheck disable=SC2317
soltar_lock(){ rmdir "$LOCK" 2>/dev/null; }

cor_idx(){ awk -F'[:|]' '/cut_idx/{v=$2; gsub(/[^0-9]/,"",v); if(v!=""){print v+0; exit}}' "$PROC_PANEL" 2>/dev/null; }
cor_pnome(){ awk -F'[:|]' '/panel_name/{v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); if(v!=""){print v; exit}}' "$PROC_PANEL" 2>/dev/null; }
cor_nome(){
  _i="$1"; [ -n "$_i" ] || return 1
  dd if="$PP" bs=1 skip=$(( TABELA_BASE + _i * PERFIL_TAM )) count=32 2>/dev/null \
    | tr '\000' '\n' | head -1
}
cor_valor(){
  _i="$1"; [ -n "$_i" ] || return 1
  dd if="$PP" bs=1 skip=$(( TABELA_BASE + _i * PERFIL_TAM + LVDS_FMT_OFF )) count=1 2>/dev/null \
    | od -An -tu1 | tr -dc '0-9'
}
cor_serial(){ getprop ro.serialno 2>/dev/null | tr -dc 'A-Za-z0-9'; }

gravar_fmt(){
  _off="$1"
  if [ "$2" = "1" ]; then
    printf '\001' | dd of="$PP" bs=1 seek="$_off" count=1 conv=notrunc 2>/dev/null
  else
    printf '\000' | dd of="$PP" bs=1 seek="$_off" count=1 conv=notrunc 2>/dev/null
  fi
}

preparar_tela(){
  TELA_DIR="$R/sdcard/pfl7560-kit"
  for _p in "$WORK"/kit/*.png; do
    arq_seguro "$_p" || { LOG "[AVISO] $_p e link ou de outro dono - telas NAO preparadas."; TELA_DIR=""; return 1; }
  done
  rm -rf "$TELA_DIR" 2>/dev/null
  if ! mkdir -p "$TELA_DIR" 2>/dev/null || ! cp "$WORK"/kit/*.png "$TELA_DIR"/ 2>/dev/null; then
    TELA_DIR="$WORK/tela"
    mkdir -p "$TELA_DIR" && cp "$WORK"/kit/*.png "$TELA_DIR"/ 2>/dev/null
  fi
  chmod 755 "$TELA_DIR" 2>/dev/null
  chmod 644 "$TELA_DIR"/*.png 2>/dev/null
}
mostrar(){
  _f="$TELA_DIR/$1.png"
  [ -f "$_f" ] || { LOG "[AVISO] tela $1 ausente em $TELA_DIR"; return 1; }
  LOG "tela: $1"
  _pk=$(cmd package resolve-activity --brief -a android.intent.action.VIEW -d "file://${_f#"$R"}" -t image/png 2>/dev/null | tail -1)
  _pk="${_pk%%/*}"
  case "$_pk" in
    ''|android|*[!A-Za-z0-9._]*) _pk="com.hisilicon.higallery" ;;
  esac
  _fa=0
  while [ "$_fa" -lt 3 ]; do
    _fp=$(dumpsys window 2>/dev/null | grep -a 'mCurrentFocus' | head -1 | sed -n 's/.* u0 \([^ }]*\)}.*/\1/p')
    case "$_fp" in ''|*/*) break ;; esac
    LOG "alerta do sistema ($_fp) na tela: fechando"
    if [ "$_fp" = "com.newlink.nlprovision" ]; then
      if [ $(( _fa % 2 )) = 0 ]; then input keyevent KEYCODE_DPAD_CENTER >/dev/null 2>&1; else input keyevent KEYCODE_ENTER >/dev/null 2>&1; fi
    else input keyevent KEYCODE_BACK >/dev/null 2>&1; fi
    sleep 1; _fa=$(( _fa + 1 ))
  done
  am force-stop "$_pk" >/dev/null 2>&1
  am start -a android.intent.action.VIEW -d "file://${_f#"$R"}" -t image/png >/dev/null 2>&1
  sleep "$TEMPO_TELA"
}

aguardar_autofoco(){
  _t=0
  while [ "$_t" -lt "$AUTOFOCO_INICIO" ] && [ "$(getprop sys.newlink.auto 2>/dev/null)" != "1" ] \
        && [ "$(getprop vendor.focus.camera.is_focused 2>/dev/null)" != "true" ]; do
    sleep 2
    _t=$(( _t + 2 ))
  done
  _t=0
  while [ "$_t" -lt "$AUTOFOCO_MAX" ] && [ "$(getprop sys.newlink.auto 2>/dev/null)" = "1" ]; do
    sleep 2
    _t=$(( _t + 2 ))
  done
  sleep "$AUTOFOCO_FOLGA"
}

esperar_tecla(){
  timeout "$TEMPO_TECLA" getevent -ql 2>/dev/null | grep -q 'EV_KEY.*DOWN'
}

lvdsctl_confere(){
  if arq_seguro "$LVDSCTL" && [ "$(md5_de "$LVDSCTL")" = "$LVDSCTL_MD5" ]; then return 0; fi
  LOG "[ERRO] lvdsctl ($LVDSCTL) ausente, link, de outro dono ou com md5 diferente do esperado - NAO vou executar."
  return 1
}
vivo_disponivel(){ [ -x "$LVDSCTL" ] && [ -f "$LIBHITV" ] && lvdsctl_confere; }
aplicar_vivo(){
  lvdsctl_confere || return 1
  LOG "lvdsctl fmt $1"
  LD_LIBRARY_PATH="$LIBS" timeout 30 "$LVDSCTL" fmt "$1" >/dev/null 2>&1
}

nlcam_confere(){
  if arq_seguro "$NLCAM" && [ -x "$NLCAM" ] && [ "$(md5_de "$NLCAM")" = "$NLCAM_MD5" ]; then return 0; fi
  LOG "[ERRO] nl_camcheck ($NLCAM) ausente, link, de outro dono ou com md5 diferente do esperado - NAO vou executar."
  return 1
}
nlcam_exec(){
  nlcam_confere || return 1
  timeout 30 "$NLCAM" "$@"
}

jornal_gravar(){
  {
    echo "J_IDX=$1"
    echo "J_OFF=$2"
    echo "J_FMT=$3"
    echo "J_MD5=$4"
  } > "$JOURNAL.new" && sync && mv "$JOURNAL.new" "$JOURNAL" && sync
}
jornal_campo(){ sed -n "s/^$1=\\([0-9]*\\)\$/\\1/p" "$JOURNAL" 2>/dev/null | head -1; }
jornal_md5(){ sed -n 's/^J_MD5=\([0-9a-f]*\)$/\1/p' "$JOURNAL" 2>/dev/null | head -1; }
jornal_ler(){
  arq_seguro "$JOURNAL" || return 1
  J_IDX=$(jornal_campo J_IDX); J_OFF=$(jornal_campo J_OFF); J_FMT=$(jornal_campo J_FMT)
  J_MD5=$(jornal_md5)
  [ "${#J_MD5}" = "32" ] || return 1
  case "$J_IDX$J_OFF$J_FMT" in ''|*[!0-9]*) return 1 ;; esac
  [ -n "$J_IDX" ] && [ -n "$J_OFF" ] && [ -n "$J_FMT" ] || return 1
  [ "$J_IDX" -le "$PERFIL_MAX" ] || return 1
  [ "$J_FMT" = "0" ] || [ "$J_FMT" = "1" ] || return 1
  [ "$J_OFF" = "$(( TABELA_BASE + J_IDX * PERFIL_TAM + LVDS_FMT_OFF ))" ]
}

particao_igual_backup(){ cmp -s "$PP" "$BKP"; }
particao_so_difere_no_fmt(){
  _n=$(cmp -l "$PP" "$BKP" 2>/dev/null | head -2 | wc -l | tr -dc '0-9')
  [ -n "$_n" ] && [ "$_n" -le 1 ] || return 1
  [ "$_n" = "0" ] && return 0
  # shellcheck disable=SC2046
  set -- "$1" $(cmp -l "$PP" "$BKP" 2>/dev/null | head -1)
  [ "$2" = "$(( $1 + 1 ))" ]
}
restaurar_trecho(){
  dd if="$BKP" of="$PP" bs=1 skip="$1" seek="$1" count="$2" conv=notrunc 2>/dev/null && sync
}

jornal_e_backup_ok(){
  trabalho_ok || return 1
  jornal_ler || { LOG "[ERRO] journal ilegivel, incoerente, link ou de outro dono - NAO vou escrever."; return 1; }
  arq_seguro "$BKP" || { LOG "[ERRO] backup $BKP ausente, link ou de outro dono - NAO vou escrever."; return 1; }
  _tam=$(wc -c < "$BKP" | tr -dc '0-9')
  [ "$_tam" = "$PP_TAM" ] || { LOG "[ERRO] backup com $_tam bytes (esperado $PP_TAM) - NAO vou escrever."; return 1; }
  [ "$(md5_de "$BKP")" = "$J_MD5" ] || { LOG "[ERRO] md5 do backup diferente do gravado no journal (backup adulterado) - NAO vou escrever."; return 1; }
}
restaurar_formato(){
  jornal_e_backup_ok || return 1
  LOG "restaurando lvds_fmt=$J_FMT no perfil $J_IDX (offset $J_OFF)"
  gravar_fmt "$J_OFF" "$J_FMT" || { LOG "[ERRO] dd de restauracao falhou."; return 1; }
  sync
  if particao_igual_backup; then
    LOG "[OK] formato restaurado: a particao inteira confere com o backup"
    return 0
  fi
  LOG "[AVISO] a particao difere do backup alem do byte - restaurando os $PERFIL_TAM bytes do perfil"
  restaurar_trecho $(( TABELA_BASE + J_IDX * PERFIL_TAM )) "$PERFIL_TAM" \
    || { LOG "[ERRO] restauracao do perfil falhou."; return 1; }
  if particao_igual_backup; then
    LOG "[OK] perfil restaurado do backup e a particao inteira confere"
    return 0
  fi
  LOG "[AVISO] ainda ha diferenca fora do perfil - restaurando a particao inteira do backup"
  if ! { dd if="$BKP" of="$PP" bs=4096 conv=notrunc 2>/dev/null && sync; }; then
    LOG "[ERRO] restauracao da particao falhou."; return 1
  fi
  if particao_igual_backup; then
    LOG "[OK] particao restaurada do backup e conferida"
    return 0
  fi
  LOG "[ERRO] depois de restaurar, a releitura NAO confere. Restaure o backup com ./pfl7560-lcd-color.sh restore."
  return 1
}

reverter(){
  VIVO_OK=0
  jornal_e_backup_ok || return 1
  if vivo_disponivel && aplicar_vivo "$J_FMT"; then VIVO_OK=1; fi
  restaurar_formato || return 1
  rm -f "$JOURNAL"
  if [ -f "$JOURNAL" ]; then
    LOG "[ERRO] formato restaurado e conferido, mas nao consegui apagar $JOURNAL."
    return 1
  fi
  remover_gancho
  return 0
}

nlsu_ok(){
  [ -d "$NLSU" ] && [ ! -L "$NLSU" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ldn "$NLSU" 2>/dev/null)
  case "$1" in
    d????-??-*) [ "$3" = "$DONO_UID" ] ;;
    *) return 1 ;;
  esac
}
gerar_gancho(){
  echo '#!/vendor/bin/sh'
  echo '# pfl7560-kit-gancho: criado pelo kit de pendrive. Restaura o formato LVDS se um'
  echo '# teste de cor foi interrompido e se apaga quando o journal some.'
  echo 'unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_NLCAMCHECK PFL_NLCAMCHECK_MD5 PFL_MODO_AUTO PFL_RAPIDO PFL_DONO PFL_TESTE'
  if [ "${PFL_TESTE:-}" = "1" ]; then
    echo "PFL_TESTE=1; PFL_ROOT='$R'; PFL_RAPIDO='${PFL_RAPIDO:-}'; PFL_DONO='$DONO_UID'; PFL_LVDSCTL='${PFL_LVDSCTL:-}'; PFL_LVDSCTL_MD5='$LVDSCTL_MD5'"
    echo 'export PFL_TESTE PFL_ROOT PFL_RAPIDO PFL_DONO PFL_LVDSCTL PFL_LVDSCTL_MD5'
  fi
  echo "W=\"$WORK\""
  echo "JOURNAL=\"$JOURNAL\""
  echo "DONO=\"$DONO_UID\""
  echo "COR_MD5=\"$COR_MD5\""
  cat <<'FIM'
seguro_dir(){
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  set -- $(ls -ldn "$1" 2>/dev/null)
  case "$1" in
    d???------|d???------[.+]) [ "$3" = "$DONO" ] ;;
    *) return 1 ;;
  esac
}
seguro_arq(){
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  set -- $(ls -ln "$1" 2>/dev/null)
  [ "$3" = "$DONO" ]
}
if [ -f "$JOURNAL" ]; then
  if seguro_dir "$W" && seguro_arq "$W/cor.sh" \
     && [ "$(md5sum "$W/cor.sh" 2>/dev/null | cut -d' ' -f1)" = "$COR_MD5" ]; then
    sh "$W/cor.sh" --restaurar
  else
    echo "[PFL7560-gancho] cor.sh ou a pasta de trabalho nao conferem - NAO vou executar."
  fi
fi
[ -f "$JOURNAL" ] || rm -f "$0"
FIM
}
instalar_gancho(){
  if [ -e "$HOOK" ] || [ -L "$HOOK" ]; then
    if ! { nlsu_ok && [ ! -L "$HOOK" ] && grep -q "pfl7560-kit-gancho" "$HOOK" 2>/dev/null; }; then
      LOG "[AVISO] ja existe $HOOK e nao e nosso (ou a pasta nao e so do root): gancho de recuperacao NAO instalado (a restauracao depende do pendrive no proximo boot)."
      return 0
    fi
  elif [ ! -e "$NLSU" ] && [ ! -L "$NLSU" ]; then
    mkdir -p "${NLSU%/*}" 2>/dev/null
    ( umask 022; mkdir "$NLSU" 2>/dev/null ) && chmod 755 "$NLSU" 2>/dev/null
  fi
  if nlsu_ok && gerar_gancho > "$HOOK.new"; then
    chmod 755 "$HOOK.new" && mv "$HOOK.new" "$HOOK" && sync && LOG "gancho de recuperacao instalado em $HOOK" && return 0
  fi
  rm -f "$HOOK.new" 2>/dev/null
  LOG "[AVISO] nao consegui instalar o gancho de recuperacao em $HOOK (se a pasta existe, ela nao e so do root)."
  return 0
}
remover_gancho(){
  if grep -q "pfl7560-kit-gancho" "$HOOK" 2>/dev/null; then
    rm -f "$HOOK"
    rmdir "$NLSU" 2>/dev/null
  fi
}

preparar_backup(){
  rm -f "$BKP" "$BKP.md5"
  if ! { dd if="$PP" of="$BKP" bs=4096 2>/dev/null && sync && arq_seguro "$BKP" && cmp -s "$BKP" "$PP"; }; then
    LOG "[ERRO] backup do panelparam invalido ou impossivel - NAO vou escrever."
    rm -f "$BKP"
    return 1
  fi
  _tam=$(wc -c < "$BKP" | tr -dc '0-9')
  if [ "$_tam" != "$PP_TAM" ]; then
    LOG "[ERRO] backup com $_tam bytes (esperado $PP_TAM) - NAO vou escrever."
    rm -f "$BKP"
    return 1
  fi
  BKP_MD5=$(md5_de "$BKP")
  if [ "${#BKP_MD5}" != "32" ]; then
    LOG "[ERRO] nao consegui o md5 do backup - NAO vou escrever."
    rm -f "$BKP"
    return 1
  fi
  echo "$BKP_MD5  panelparam-original.img" > "$BKP.md5"
  LOG "[OK] backup do panelparam salvo e conferido com cmp em $BKP"
  _s=$(cor_serial); [ -n "$_s" ] || _s="sem-serial"
  _bd="$MP"
  if [ -z "$MP" ] && [ "$SUITE_MODO" = "1" ] && dir_seguro "$SUITE_DIR"; then _bd="$SUITE_DIR"; fi
  _b="$_bd/panelparam-backup-$_s.img"
  if [ -n "$_bd" ] && [ -d "$_bd" ] && cp "$BKP" "$_b" 2>/dev/null && sync && cmp -s "$_b" "$PP"; then
    md5sum "$_b" > "$_b.md5" 2>/dev/null
    LOG "[OK] copia do backup conferida: $_b"
  else
    rm -f "$_b" "$_b.md5" 2>/dev/null
    LOG "[AVISO] nao consegui copiar o backup para o pendrive (o de $WORK vale)."
  fi
  return 0
}

limpar_trabalho(){
  [ -f "$JOURNAL" ] && return 0
  rm -rf "$WORK"
}
fmt_nome(){ case "$1" in 0) echo VESA ;; 1) echo JEIDA ;; *) echo "?" ;; esac; }
gravar_resultado(){
  [ "$1" = "erro" ] && COR_RES=erro
  dir_seguro "$SUITE_DIR" || { LOG "[ERRO] $SUITE_DIR nao e pasta so do root: resultado NAO gravado."; return 1; }
  _depois=""; [ -n "${CIDX:-}" ] && _depois=$(cor_valor "$CIDX")
  {
    echo "cor_resultado=$COR_RES"
    echo "cor_formato_antes=$(fmt_nome "${CVAL:-}")"
    echo "cor_formato_depois=$(fmt_nome "$_depois")"
    echo "cor_faixas=$COR_FAIXAS"
    echo "cor_painel=$(echo "${PNOME:-}" | tr -cd 'A-Za-z0-9_.-')"
  } > "$SUITE_DIR/cor-resultado.txt.new" && mv -f "$SUITE_DIR/cor-resultado.txt.new" "$SUITE_DIR/cor-resultado.txt"
  LOG "resultado para a suite: cor_resultado=$COR_RES"
}
finalizar(){
  _t="$1"
  if [ "$SUITE_MODO" = "1" ]; then
    gravar_resultado "$_t"
  else
    if [ "$_t" = "pronto" ] && [ -n "$AVISO" ]; then
      LOG "[AVISO] a fase termica nao ficou efetiva (ver o log): mostrando ERRO em vez de PRONTO."
      _t="erro"
    fi
    mostrar "$_t"
  fi
  if [ -n "$MP" ] && [ -d "$MP" ]; then cp "$LOGF" "$MP/newlink_cor.log" 2>/dev/null; fi
  limpar_trabalho
  exit 0
}

medir_escada(){
  _o=$(nlcam_exec niveis "$VIDEO" "$FAIXAS" "$CAM_DESCARTE") || { LOG "[AVISO] nl_camcheck niveis falhou ($1): $_o"; return 1; }
  _ult=$(echo "$_o" | tail -1)
  _ic=$(echo "$_ult" | sed -n 's/^inv_cresc=\([0-9][0-9]*\) inv_decresc=[0-9][0-9]*$/\1/p')
  _id=$(echo "$_ult" | sed -n 's/^inv_cresc=[0-9][0-9]* inv_decresc=\([0-9][0-9]*\)$/\1/p')
  ESC_NIVEIS=$(echo "$_o" | sed '$d' | tr '\n' ' ')
  _nn=$(echo "$_o" | sed '$d' | grep -c '^[0-9][0-9]*$')
  if [ -z "$_ic" ] || [ -z "$_id" ] || [ "$_nn" != "$FAIXAS_N" ]; then
    LOG "[AVISO] saida do nl_camcheck niveis ilegivel ($1): '$_o'"
    return 1
  fi
  ESC_INV="$_ic"; [ "$_id" -lt "$_ic" ] && ESC_INV="$_id"
  _mn=255; _mx=0
  for _v in $ESC_NIVEIS; do
    [ "$_v" -lt "$_mn" ] && _mn="$_v"
    [ "$_v" -gt "$_mx" ] && _mx="$_v"
  done
  ESC_AMPL=$(( _mx - _mn ))
  LOG "escada ($1): niveis= ${ESC_NIVEIS}inv_cresc=$_ic inv_decresc=$_id amplitude=$ESC_AMPL"
  return 0
}

escada_medir(){
  mostrar escada-1
  medir_escada "$1" || { ESC_RES=duvida; return 1; }
  if [ "$ESC_AMPL" -lt "$AMPLITUDE_MIN" ]; then
    LOG "[AVISO] amplitude $ESC_AMPL < $AMPLITUDE_MIN: a camera nao viu a escada (tampada ou escura)."
    ESC_RES=duvida; return 1
  fi
  if [ "$ESC_INV" = "0" ]; then ESC_RES=ordem
  elif [ "$ESC_INV" -ge "$INV_ERRADO" ]; then ESC_RES=errado
  else ESC_RES=duvida; fi
  return 0
}

decidir_por_camera(){
  if [ ! -e "$VIDEO" ]; then LOG "[AVISO] $VIDEO nao existe: modo automatico indisponivel."; return 1; fi
  nlcam_confere || return 1
  FAIXAS="$WORK/faixas.txt"
  rm -f "$FAIXAS"
  mostrar calibracao
  _o=$(nlcam_exec faixas "$VIDEO" "$FAIXAS_N" "$FAIXAS" "$CAM_DESCARTE"); _rc=$?
  if [ "$_rc" != "0" ]; then
    COR_FAIXAS=falhou
    LOG "[AVISO] calibracao pela camera falhou (rc=$_rc: $_o): fluxo manual."
    return 1
  fi
  COR_FAIXAS=$(echo "$_o" | sed -n 's/^faixas achadas: \([0-9][0-9]*\).*$/\1/p' | head -1)
  [ -n "$COR_FAIXAS" ] || COR_FAIXAS="$FAIXAS_N"
  LOG "calibracao: $_o"

  escada_medir "formato atual lvds_fmt=$CVAL" || { LOG "modo automatico sem decisao: a pessoa decide"; return 1; }
  case "$ESC_RES" in
    ordem)
      LOG "[OK] escada em ordem com lvds_fmt=$CVAL: formato certo, nada foi escrito"
      COR_RES=ordem
      finalizar pronto ;;
    duvida)
      LOG "escada com $ESC_INV inversao: sem margem para decidir, nada foi escrito: a pessoa decide"
      return 1 ;;
  esac

  LOG "escada FORA de ordem ($ESC_INV inversoes) com lvds_fmt=$CVAL: tentando lvds_fmt=$NOVO"
  vivo_disponivel || { LOG "[AVISO] lvdsctl ou libhitvservice ausente: nada foi escrito: a pessoa decide"; return 1; }
  preparar_backup || finalizar erro
  jornal_gravar "$CIDX" "$OFF" "$CVAL" "$BKP_MD5" || { LOG "[ERRO] nao consegui gravar o journal - NAO vou escrever."; finalizar erro; }
  instalar_gancho
  LOG "trocando lvds_fmt $CVAL -> $NOVO ao vivo (journal guarda o original)"
  aplicar_vivo "$NOVO"
  if [ "$(cor_valor "$CIDX")" != "$NOVO" ]; then
    LOG "[ERRO] depois do lvdsctl o byte lido e '$(cor_valor "$CIDX")', nao $NOVO - revertendo."
    reverter || LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
    finalizar erro
  fi
  sleep "$TEMPO_ASSENTAR"
  escada_medir "depois da troca para lvds_fmt=$NOVO"

  if [ "$ESC_RES" = "ordem" ]; then
    mostrar corrigida
    if esperar_tecla; then
      LOG "tecla recebida: a pessoa quer desfazer a correcao automatica - revertendo para lvds_fmt=$CVAL"
      if reverter; then
        LOG "[OK] revertido: lvds_fmt=$CVAL"
        [ "$VIVO_OK" = "1" ] || LOG "[AVISO] o lvdsctl nao confirmou a volta ao vivo: o formato original vale a partir do proximo boot."
        COR_RES=manual_mantido
        finalizar pronto
      fi
      LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
      finalizar erro
    fi
    if [ "$(cor_valor "$CIDX")" = "$NOVO" ] && particao_so_difere_no_fmt "$OFF"; then
      LOG "[OK] escada em ordem depois da troca, sem tecla para desfazer: lvds_fmt=$NOVO mantido, relido e a particao confere (so o byte 0x5c mudou)"
      rm -f "$JOURNAL"
      remover_gancho
      COR_RES=corrigido
      finalizar pronto
    fi
    LOG "[ERRO] a releitura nao confirmou (byte ou perfil diferente do esperado) - revertendo."
    reverter || { LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."; finalizar erro; }
    finalizar erro
  fi

  LOG "a troca nao deixou a escada em ordem ($ESC_RES, $ESC_INV inversoes): revertendo para lvds_fmt=$CVAL e caindo no fluxo manual"
  if ! reverter; then
    LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
    finalizar erro
  fi
  if [ "$VIVO_OK" != "1" ]; then
    LOG "[AVISO] o lvdsctl nao confirmou a volta ao vivo: o formato original vale a partir do proximo boot. NAO vou perguntar."
    finalizar erro
  fi
  return 1
}

modo_restaurar(){
  pegar_lock || { LOG "outra instancia em andamento - nada a fazer aqui."; exit 0; }
  trap soltar_lock EXIT
  if [ ! -e "$WORK" ] && [ ! -L "$WORK" ]; then LOG "sem journal - nada a restaurar."; exit 0; fi
  trabalho_ok || exit 1
  [ -f "$JOURNAL" ] || { LOG "sem journal - nada a restaurar."; exit 0; }
  LOG "journal pendente: um teste de cor foi interrompido; devolvendo o formato original"
  if ! reverter; then
    LOG "[ERRO] nao consegui restaurar; o journal fica para a proxima tentativa."
    exit 1
  fi
  rm -rf "$WORK"
  if [ "$VIVO_OK" = "1" ]; then
    LOG "formato original aplicado ao vivo e a particao confere com o backup"
    exit 0
  fi
  LOG "[AVISO] sem lvdsctl utilizavel: reiniciando para o byte restaurado valer"
  sleep "$ESPERA_REBOOT"
  reboot
  exit 3
}

modo_teste(){
  MP="$1"
  AVISO="$2"
  COR_MD5="$3"
  if [ "$4" = "suite" ]; then
    SUITE_MODO=1
    LOGF="$SUITE_DIR/cor.log"
  fi
  if [ "${#COR_MD5}" != "32" ] || [ "$(md5_de "$0")" != "$COR_MD5" ]; then
    LOG "[ERRO] md5 de cor.sh ausente ou diferente do conferido pelo newlink_update.sh - NAO vou escrever."
    exit 1
  fi
  pegar_lock || { LOG "outra instancia em andamento - saindo."; exit 0; }
  trap soltar_lock EXIT
  trabalho_ok || exit 1
  LOG "==== fase de cor iniciada (mountpoint=$MP) ===="

  if [ -f "$JOURNAL" ]; then
    LOG "journal pendente de uma execucao anterior: restaurando antes de qualquer coisa"
    reverter || { LOG "[ERRO] restauracao falhou - NAO vou iniciar outro teste."; finalizar erro; }
    if [ "$VIVO_OK" != "1" ]; then
      LOG "[AVISO] formato original restaurado na particao, mas sem lvdsctl ao vivo: vale no proximo boot. NAO vou iniciar outro teste."
      finalizar erro
    fi
  fi

  preparar_tela
  if [ "$SUITE_MODO" != "1" ]; then
    mostrar aguarde
    aguardar_autofoco
  fi

  CIDX=$(cor_idx); PNOME=$(cor_pnome)
  case "$CIDX" in ''|*[!0-9]*) CIDX="" ;; *) [ "$CIDX" -le "$PERFIL_MAX" ] || CIDX="" ;; esac
  if [ -z "$CIDX" ] || [ -z "$PNOME" ]; then
    LOG "[ERRO] nao consegui ler o perfil de painel (idx='$CIDX' nome_driver='$PNOME') - NAO vou escrever."
    finalizar erro
  fi
  CNOME=$(cor_nome "$CIDX")
  case "$CNOME" in
    "$PNOME"*) ;;
    *) LOG "[ERRO] offset $(( TABELA_BASE + CIDX * PERFIL_TAM )) devolveu '$CNOME' mas o driver diz '$PNOME' - offset errado, NAO vou escrever."
       finalizar erro ;;
  esac
  CVAL=$(cor_valor "$CIDX")
  case "$CVAL" in 0|1) ;; *) LOG "[ERRO] lvds_fmt='$CVAL' (esperado 0 ou 1) - NAO vou escrever."; finalizar erro ;; esac
  OFF=$(( TABELA_BASE + CIDX * PERFIL_TAM + LVDS_FMT_OFF ))
  NOVO=$(( 1 - CVAL ))
  LOG "perfil $CIDX '$PNOME': lvds_fmt=$CVAL (0=VESA, 1=JEIDA)"

  if [ "$MODO_AUTO" = "1" ]; then
    decidir_por_camera
    LOG "modo automatico sem decisao: a pessoa decide (fluxo manual)"
  fi

  mostrar escada-1
  if ! esperar_tecla; then
    LOG "sem tecla em ${TEMPO_TECLA}s: formato mantido ($CVAL), nada foi escrito"
    COR_RES=manual_mantido
    finalizar pronto
  fi
  LOG "tecla recebida: a pessoa viu a escada FORA de ordem"
  mostrar escada-1

  vivo_disponivel || {
    LOG "[ERRO] lvdsctl ou libhitvservice ausente: nao da para testar ao vivo. Nada foi escrito. Use o wizard do PC (pfl7560-lcd-color.sh wizard)."
    finalizar erro
  }
  preparar_backup || finalizar erro
  jornal_gravar "$CIDX" "$OFF" "$CVAL" "$BKP_MD5" || { LOG "[ERRO] nao consegui gravar o journal - NAO vou escrever."; finalizar erro; }
  instalar_gancho

  LOG "trocando lvds_fmt $CVAL -> $NOVO ao vivo (journal guarda o original)"
  aplicar_vivo "$NOVO"
  if [ "$(cor_valor "$CIDX")" != "$NOVO" ]; then
    LOG "[ERRO] depois do lvdsctl o byte lido e '$(cor_valor "$CIDX")', nao $NOVO - revertendo."
    reverter || LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
    finalizar erro
  fi

  sleep "$TEMPO_ASSENTAR"
  mostrar escada-2
  sleep "$TEMPO_ASSENTAR"
  if esperar_tecla; then
    if [ "$(cor_valor "$CIDX")" = "$NOVO" ] && particao_so_difere_no_fmt "$OFF"; then
      LOG "[OK] segunda tecla: lvds_fmt=$NOVO mantido, relido e a particao confere (so o byte 0x5c mudou)"
      rm -f "$JOURNAL"
      remover_gancho
      COR_RES=manual_trocado
      finalizar pronto
    fi
    LOG "[ERRO] a releitura nao confirmou (byte ou perfil diferente do esperado) - revertendo."
  else
    LOG "sem segunda tecla em ${TEMPO_TECLA}s: revertendo para lvds_fmt=$CVAL"
  fi
  if reverter; then
    LOG "[OK] revertido: lvds_fmt=$CVAL"
    [ "$VIVO_OK" = "1" ] || LOG "[AVISO] o lvdsctl nao confirmou a volta ao vivo: o formato original vale a partir do proximo boot."
    COR_RES=manual_mantido
    finalizar pronto
  fi
  LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
  finalizar erro
}

case "$1" in
  --restaurar) modo_restaurar ;;
  --tela) trabalho_ok || exit 1; preparar_tela; mostrar "$2"; exit 0 ;;
  *) modo_teste "$1" "$2" "$3" "${4:-}" ;;
esac
