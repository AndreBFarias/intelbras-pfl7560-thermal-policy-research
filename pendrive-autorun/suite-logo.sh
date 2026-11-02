#!/vendor/bin/sh

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_NLLOGO PFL_NLLOGO_MD5
fi
LC_ALL=C; export LC_ALL
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
LDIR="$R/data/vendor/pfl7560-logo"
TRAB="$LDIR/trabalho"
PART="$R/dev/block/by-name/logo"
NL="$SUITE/nl_logo"
ARTE="$SUITE/marca/logo.jpg"
LOCK="$R/dev/pfl7560-suite.lock"
MARCA_BOOT="$R/dev/pfl7560-logo.boot"
MIDIA="$R/mnt/media_rw"
DESLIGADO="$LDIR/desligado"
REG_CANTOS="$LDIR/cantos"
REG_MD5="$LDIR/jpeg-md5"
REG_HORA="$LDIR/gravado-em"
REG_MOTIVO="$LDIR/motivo"
BK_ULTIMO="$LDIR/ultimo.img"
BK_PRIMEIRO="$LDIR/primeiro.img"
LOG_ARQ="$LDIR/logo.log"
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"

# LOGO_MD5_INICIO
NL_LOGO_MD5="ac5303cab8881c2175622cab10642a66"
ARTE_MD5="3f33a5898aaaff385d9e6cf42762677a"
# LOGO_MD5_FIM
if [ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_NLLOGO:-}" ]; then NL="$PFL_NLLOGO"; NL_LOGO_MD5="${PFL_NLLOGO_MD5:-}"; fi

TAM_PART=41943040
RETO="0,1080 1920,1080 0,0 1920,0"
ESPERA_INICIAL=60
ESPERA_SUITE=30
ESPERA_VOLTAS=40
LOG_MAX=200
[ -n "${PFL_RAPIDO:-}" ] && { ESPERA_INICIAL=0; ESPERA_SUITE=0; }

LOG(){ echo "[PFL7560-logo] $*"; }
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
tam_de(){ wc -c < "$1" 2>/dev/null | tr -dc '0-9'; }
prop(){ setprop "vendor.pfl7560.$1" "$2" 2>/dev/null; }
reg_ler(){ arq_seguro "$1" && head -c 64 "$1" 2>/dev/null | tr -d '\r\n' | tr -cd "$2"; }
reg_gravar(){ ( umask 077; printf '%s\n' "$2" > "$1.novo" ) && mv -f "$1.novo" "$1"; }

logo_dir_ok(){
  if [ ! -e "$LDIR" ] && [ ! -L "$LDIR" ]; then
    ( umask 077; mkdir "$LDIR" 2>/dev/null ) && chmod 700 "$LDIR" 2>/dev/null
  fi
  dir_seguro "$LDIR"
}
ligada(){ [ ! -e "$DESLIGADO" ] && [ ! -L "$DESLIGADO" ]; }
publicar(){
  if ligada; then prop logo ligado; else prop logo desligado; fi
  _pc=$(reg_ler "$REG_CANTOS" '0-9, ')
  prop logo_cantos "${_pc:-desconhecido}"
  prop logo_hora "$(reg_ler "$REG_HORA" '0-9: -')"
  prop logo_motivo "$(reg_ler "$REG_MOTIVO" 'a-z_')"
}
desligar(){
  ( umask 077; : > "$DESLIGADO" )
  [ -n "${1:-}" ] && reg_gravar "$REG_MOTIVO" "$1"
  publicar
}
recusa(){
  LOG "[AVISO] logo NAO gravado ($1): $2"
  reg_gravar "$REG_MOTIVO" "$1"
  rm -rf "$TRAB"
  publicar
}
registrar(){
  reg_gravar "$REG_CANTOS" "$1"
  reg_gravar "$REG_MD5" "$2"
  [ -n "${3:-}" ] && reg_gravar "$REG_HORA" "$3"
  rm -f "$REG_MOTIVO"
  rm -rf "$TRAB"
  publicar
}

cantos_ler(){
  CANTOS=""
  for _k in lt rt lb rb; do
    _v=$(getprop "persist.sys.keystone.$_k" 2>/dev/null | tr -d '\r\n ' | cut -c1-16)
    case "$_v" in
      [0-9]*,[0-9]*) ;;
      *) return 1 ;;
    esac
    case "$_v" in *[!0-9,]*|*,*,*) return 1 ;; esac
    CANTOS="$CANTOS $_v"
  done
  CANTOS="${CANTOS# }"
}
esperar_suite(){
  sleep "$ESPERA_INICIAL"
  _w=0
  while [ -d "$LOCK" ]; do
    [ "$_w" -ge "$ESPERA_VOLTAS" ] && return 1
    _w=$(( _w + 1 ))
    sleep "$ESPERA_SUITE"
  done
  return 0
}
pendrive_desliga(){
  for _d in "$MIDIA"/*; do
    [ -e "$_d/DESLIGAR-LOGO-AUTO.txt" ] && return 0
  done
  return 1
}

gravar(){
  _jn=$(tam_de "$TRAB/novo.jpg")
  rm -f "$BK_ULTIMO.novo"
  dd if="$PART" of="$BK_ULTIMO.novo" bs=1048576 2>/dev/null
  chmod 600 "$BK_ULTIMO.novo" 2>/dev/null
  _mb=$(md5_de "$BK_ULTIMO.novo")
  if [ "$(tam_de "$BK_ULTIMO.novo")" != "$TAM_PART" ] || [ -z "$_mb" ] || [ "$_mb" != "$(md5_de "$PART")" ]; then
    rm -f "$BK_ULTIMO.novo"; recusa backup "o backup da particao nao confere (tamanho ou md5)"; return 0
  fi
  mv -f "$BK_ULTIMO.novo" "$BK_ULTIMO" || { recusa backup "nao consegui guardar o backup"; return 0; }
  if [ ! -e "$BK_PRIMEIRO" ] && [ ! -L "$BK_PRIMEIRO" ]; then
    rm -f "$BK_PRIMEIRO.novo"
    if cp "$BK_ULTIMO" "$BK_PRIMEIRO.novo" 2>/dev/null && chmod 600 "$BK_PRIMEIRO.novo" && [ "$(md5_de "$BK_PRIMEIRO.novo")" = "$_mb" ]; then
      mv -f "$BK_PRIMEIRO.novo" "$BK_PRIMEIRO" || { recusa primeiro "nao consegui guardar o primeiro backup"; return 0; }
      LOG "primeiro backup da particao guardado (md5 $_mb)"
    else
      rm -f "$BK_PRIMEIRO.novo"; recusa primeiro "nao consegui guardar o primeiro backup"; return 0
    fi
  fi
  arq_seguro "$BK_PRIMEIRO" || { recusa primeiro "o primeiro backup e link ou de outro dono"; return 0; }
  [ "$("$NL" cabecalho "$BK_ULTIMO" 2>/dev/null)" = "$_na" ] || { recusa cabecalho "o backup nao passa na conferencia do LOGO_TABLE"; return 0; }
  if ! "$NL" montar "$BK_ULTIMO" "$TRAB/novo.jpg" "$TRAB/montada.img" "$TRAB/keylen.bin" >/dev/null 2>&1; then
    recusa montar "nao consegui montar a imagem nova"; return 0
  fi
  [ "$("$NL" cabecalho "$TRAB/montada.img" 2>/dev/null)" = "$_jn" ] || { recusa montar "LOGO_KEY_LEN montado difere do JPEG ($_jn)"; return 0; }
  [ "$(tam_de "$TRAB/keylen.bin")" = 4 ] || { recusa montar "keylen.bin sem 4 bytes"; return 0; }
  _me=$(md5_de "$TRAB/montada.img")
  [ -n "$_me" ] || { recusa montar "sem md5 da imagem montada"; return 0; }
  [ "$(md5_de "$PART")" = "$_mb" ] || { recusa mudou "a particao mudou depois do backup"; return 0; }
  [ "$(blockdev --getsize64 "$PART" 2>/dev/null | tr -dc '0-9')" = "$TAM_PART" ] || { recusa particao "a particao nao tem $TAM_PART bytes"; return 0; }
  LOG "gravando o logo novo ($_jn bytes no byte 8192 e LOGO_KEY_LEN no 120) para os cantos $CANTOS"
  dd if="$TRAB/novo.jpg" of="$PART" bs=4096 seek=2 2>/dev/null
  dd if="$TRAB/keylen.bin" of="$PART" bs=1 seek=120 2>/dev/null
  sync
  _ml=$(md5_de "$PART")
  if [ "$_ml" = "$_me" ]; then
    LOG "[OK] particao relida e conferida (md5 $_ml); backups em ${LDIR#"$R"}"
    registrar "$CANTOS" "$_mn" "$(date '+%Y-%m-%d %H:%M' 2>/dev/null)"
    return 0
  fi
  LOG "[ERRO] a releitura NAO confere (lido $_ml, esperado $_me): devolvendo a particao ao backup"
  dd if="$BK_ULTIMO" of="$PART" bs=1048576 2>/dev/null
  sync
  if [ "$(md5_de "$PART")" = "$_mb" ]; then
    LOG "particao devolvida ao backup e conferida; chave desligada"
    rm -rf "$TRAB"
    desligar releitura_devolvido
  else
    LOG "[ERRO] a devolucao tambem NAO confere: restaure pelo PC com ${BK_ULTIMO#"$R"}; chave desligada"
    rm -rf "$TRAB"
    desligar releitura_sem_volta
  fi
  return 0
}

modo_boot(){
  if ! mkdir "$MARCA_BOOT" 2>/dev/null; then LOG "ja rodou neste boot - nada a fazer"; publicar; return 0; fi
  publicar
  if ! ligada; then LOG "chave desligada (home ou pendrive) - nada a fazer"; return 0; fi
  if pendrive_desliga; then LOG "DESLIGAR-LOGO-AUTO.txt no pendrive: chave desligada"; desligar pendrive; return 0; fi
  esperar_suite || { recusa suite_rodando "a suite ainda roda depois da espera"; return 0; }
  [ "$(getprop ro.product.model 2>/dev/null)" = "PFL7560" ] || { recusa modelo "o aparelho nao e um PFL7560"; return 0; }
  confere "$NL" "$NL_LOGO_MD5" || { recusa programa "nl_logo ausente, link, de outro dono ou com md5 diferente"; return 0; }
  confere "$ARTE" "$ARTE_MD5" || { recusa arte "marca/logo.jpg ausente, link, de outro dono ou com md5 diferente"; return 0; }
  cantos_ler || { recusa formato "persist.sys.keystone.* fora do formato x,y"; return 0; }
  [ "$(blockdev --getsize64 "$PART" 2>/dev/null | tr -dc '0-9')" = "$TAM_PART" ] || { recusa particao "a particao logo nao tem $TAM_PART bytes"; return 0; }
  _na=$("$NL" cabecalho "$PART" 2>/dev/null) || { recusa cabecalho "a particao nao passa na conferencia do LOGO_TABLE"; return 0; }
  rm -rf "$TRAB"
  ( umask 077; mkdir "$TRAB" ) || { recusa trabalho "nao consegui criar a pasta de trabalho"; return 0; }
  "$NL" extrair "$PART" "$TRAB/atual.jpg" >/dev/null 2>&1 || { recusa cabecalho "nao consegui ler o JPEG da particao"; return 0; }
  _ma=$(md5_de "$TRAB/atual.jpg")
  _rc=$(reg_ler "$REG_CANTOS" '0-9, ')
  _rm=$(reg_ler "$REG_MD5" '0-9a-f')
  _gc=""
  if [ -n "$_rc" ] && [ -n "$_rm" ] && [ "$_rm" = "$_ma" ]; then _gc="$_rc"
  elif [ "$_ma" = "$ARTE_MD5" ]; then _gc="$RETO"; fi
  if [ "$_gc" = "$CANTOS" ]; then
    LOG "o logo gravado ja e o dos cantos atuais ($CANTOS) - nada a gravar"
    registrar "$CANTOS" "$_ma"
    return 0
  fi
  # shellcheck disable=SC2086
  _mot=$("$NL" cantos $CANTOS 2>/dev/null | head -n 1 | tr -cd 'a-z_' | cut -c1-24)
  if [ "$_mot" != "ok" ]; then recusa "${_mot:-formato}" "cantos recusados: $CANTOS"; return 0; fi
  # shellcheck disable=SC2086
  if ! "$NL" gerar "$ARTE" $CANTOS "$TRAB/novo.jpg" >/dev/null 2>&1; then recusa gerar "nl_logo nao gerou o JPEG para $CANTOS"; return 0; fi
  _mn=$(md5_de "$TRAB/novo.jpg")
  [ -n "$_mn" ] || { recusa gerar "JPEG gerado ilegivel"; return 0; }
  if [ "$_mn" = "$_ma" ]; then
    LOG "a particao ja tem o logo destes cantos ($CANTOS) - nada a gravar"
    registrar "$CANTOS" "$_ma"
    return 0
  fi
  gravar
}

modo_chave(){
  case "${1:-}" in
    ligado) rm -f "$DESLIGADO"; LOG "chave ligada pela home (vale no proximo boot)" ;;
    desligado) ( umask 077; : > "$DESLIGADO" ); LOG "chave desligada pela home" ;;
    *) LOG "[AVISO] pedido de chave invalido"; publicar; return 0 ;;
  esac
  publicar
}

dir_seguro "$SUITE" || { echo "[PFL7560-logo] [ERRO] $SUITE nao e uma pasta so do root - nada feito."; exit 1; }
logo_dir_ok || { echo "[PFL7560-logo] [ERRO] $LDIR nao e uma pasta so do root - nada feito."; prop logo erro; exit 1; }
if [ -f "$LOG_ARQ" ]; then tail -n "$LOG_MAX" "$LOG_ARQ" > "$LOG_ARQ.novo" 2>/dev/null && mv -f "$LOG_ARQ.novo" "$LOG_ARQ"; fi
exec >>"$LOG_ARQ" 2>&1 </dev/null
case "${1:-}" in
  boot) LOG "==== boot $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) ===="; modo_boot ;;
  chave) modo_chave "${2:-}" ;;
  estado) publicar ;;
esac
exit 0
