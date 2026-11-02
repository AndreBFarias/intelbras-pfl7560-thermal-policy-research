#!/bin/sh
# preflight-flash.sh - pre-voo do flash da S6 (bloco 28, doc 47 s12 e s14). So le: nao grava nada, nem no
# pendrive nem no PC. Recusa (sai 1) se QUALQUER item falhar:
#   1. usb_update.bin na raiz do pendrive = a S6 aprovada (md5 do firmware/PFL7560-S6-COMPLETO-NAO-GRADUADO.bin.md5);
#   2. build_fix_bin.py --verificar desse usb_update.bin contra o stock, com o conteudo-s5.txt, APROVADO;
#   3. kit do pendrive compativel com o .rc da S5: o newlink_update.sh dele aceita este .rc (RC_S5_MD5) e
#      todos os arquivos da KIT_LISTA dele estao la com o md5 certo; sem DESINSTALAR-SUITE.txt;
#   4. backup do aparelho presente no PC (fora do pendrive): /data/vendor/pfl7560-* e o shared_prefs da home,
#      soltos ou no pfl-backup.tar;
#   5. stock de resgate (V1.0.0.9 com USB-C, md5 28a2f280...) guardado fora do pendrive.
#
# uso: sh firmware/preflight-flash.sh <pendrive> --backup <pasta> --resgate <PFL7560.bin do stock>
# Sai 0 aprovado; 1 recusado; 2 uso errado.
LC_ALL=C
export LC_ALL

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
STOCK_MD5="28a2f280eee313a4b115567926b2ba4f"
MD5_ARQ="$RAIZ/firmware/PFL7560-S6-COMPLETO-NAO-GRADUADO.bin.md5"
MANIFESTO="$RAIZ/artifacts/bin-build/conteudo-s5.txt"
RC_S5="$RAIZ/artifacts/bin-build/s5/pfl7560-suite.rc"
VERIFICAR=""
if [ "${PFL_TESTE:-}" = 1 ]; then
  # so o tests/test-preflight-flash.sh: troca o md5 esperado e o comando do verificador
  STOCK_MD5="${PFL_STOCK_MD5:-$STOCK_MD5}"
  MD5_ARQ="${PFL_S5_MD5_ARQ:-$MD5_ARQ}"
  VERIFICAR="${PFL_VERIFICAR:-}"
fi

uso(){ echo "uso: sh $0 <pendrive> --backup <pasta> --resgate <PFL7560.bin do stock>" >&2; exit 2; }

PEN=""; BACKUP=""; RESGATE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --backup) [ "$#" -ge 2 ] || uso; BACKUP="$2"; shift 2 ;;
    --resgate) [ "$#" -ge 2 ] || uso; RESGATE="$2"; shift 2 ;;
    -*) uso ;;
    *) [ -z "$PEN" ] || uso; PEN="$1"; shift ;;
  esac
done
if [ -z "$PEN" ] || [ -z "$BACKUP" ] || [ -z "$RESGATE" ]; then uso; fi

FALHAS=0
ok(){ printf '[OK] %s\n' "$*"; }
falha(){ printf '[FALHA] %s\n' "$*"; FALHAS=$((FALHAS + 1)); }
md5(){ md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
real(){ ( cd "$1" 2>/dev/null && pwd -P ); }
real_arq(){ _d="$(real "$(dirname "$1")")" && [ -n "$_d" ] && printf '%s/%s\n' "$_d" "$(basename "$1")"; }
# dentro <caminho real> <pasta real>: o caminho fica na pasta (ou e ela)
dentro(){ case "$1/" in "$2"/*) return 0 ;; esac; return 1; }
# no_pendrive <caminho real>: dentro da pasta do pendrive, ou no mesmo sistema de arquivos quando ela e um ponto
# de montagem (outro caminho para o mesmo pendrive)
no_pendrive(){
  dentro "$1" "$PEN_REAL" && return 0
  if [ "$PEN_MONTADO" = 1 ] && [ "$(stat -c %d "$1" 2>/dev/null)" = "$(stat -c %d "$PEN_REAL")" ]; then return 0; fi
  return 1
}

PEN_REAL="$(real "$PEN")"
if [ -z "$PEN_REAL" ] || [ ! -d "$PEN_REAL" ]; then
  echo "[FALHA] '$PEN' nao e uma pasta (informe o ponto de montagem do pendrive)"
  echo "PRE-VOO RECUSADO: o pendrive nao foi achado"
  exit 1
fi
PEN_MONTADO=0
if command -v mountpoint >/dev/null 2>&1 && mountpoint -q "$PEN_REAL"; then PEN_MONTADO=1; fi
echo "pre-voo do flash da S6: pendrive $PEN_REAL$([ "$PEN_MONTADO" = 1 ] && echo ' (ponto de montagem)')"

# 1. usb_update.bin = a S6 aprovada
BIN="$PEN_REAL/usb_update.bin"
S5_MD5=""
if [ -f "$MD5_ARQ" ]; then
  S5_MD5="$(sed -n 's/^\([0-9a-f]\{32\}\)  PFL7560-S6-COMPLETO-NAO-GRADUADO\.bin$/\1/p' "$MD5_ARQ" | head -1)"
fi
BIN_OK=0
if [ -z "$S5_MD5" ]; then
  falha "1. sem o md5 da S6 aprovada em $MD5_ARQ"
elif [ -L "$BIN" ] || [ ! -f "$BIN" ]; then
  falha "1. usb_update.bin ausente na raiz do pendrive, ou e um link"
else
  m="$(md5 "$BIN")"
  if [ "$m" = "$S5_MD5" ]; then
    ok "1. usb_update.bin = a S6 aprovada (md5 $m)"; BIN_OK=1
  else
    falha "1. usb_update.bin tem md5 ${m:-?}, a S6 aprovada e $S5_MD5"
  fi
fi

# 5. stock de resgate fora do pendrive (vem antes do 2: o verificador precisa dele)
RES_OK=0
RES_REAL="$(real_arq "$RESGATE")"
if [ -z "$RES_REAL" ] || [ -L "$RESGATE" ] || [ ! -f "$RES_REAL" ]; then
  falha "5. stock de resgate '$RESGATE' ausente ou e um link"
elif no_pendrive "$RES_REAL"; then
  falha "5. o stock de resgate esta no pendrive do flash ($RES_REAL): guarde-o no PC ou noutro pendrive"
else
  m="$(md5 "$RES_REAL")"
  if [ "$m" = "$STOCK_MD5" ]; then
    ok "5. stock de resgate fora do pendrive: $RES_REAL (md5 $m)"; RES_OK=1
  else
    falha "5. stock de resgate com md5 ${m:-?}, o V1.0.0.9 com USB-C e $STOCK_MD5"
  fi
fi

# 2. verificar_bin
if [ "$BIN_OK" != 1 ] || [ "$RES_OK" != 1 ]; then
  falha "2. verificar_bin nao rodou (precisa do usb_update.bin da S6 e do stock conferidos)"
else
  echo "   verificando o usb_update.bin contra o stock (leva um ou dois minutos)..."
  if [ -n "$VERIFICAR" ]; then
    saida="$($VERIFICAR "$BIN" "$RES_REAL" "$MANIFESTO" 2>&1)"; rc=$?
  else
    saida="$(python3 "$RAIZ/artifacts/bin-build/build_fix_bin.py" --verificar "$BIN" "$RES_REAL" --conteudo "$MANIFESTO" 2>&1)"; rc=$?
  fi
  if [ "$rc" = 0 ] && printf '%s\n' "$saida" | tail -1 | grep -q ' APROVADO$'; then
    ok "2. verificar_bin APROVADO (conteudo-s5.txt: records 6 e 14, o resto igual ao stock)"
  else
    falha "2. verificar_bin reprovou (rc=$rc): $(printf '%s\n' "$saida" | grep -v '^\[verificar\]' | head -3 | tr '\n' '|')"
  fi
fi

# 3. kit do pendrive compativel com o .rc da S5
NL="$PEN_REAL/newlink_update.sh"
if [ -L "$NL" ] || [ ! -f "$NL" ]; then
  falha "3. sem newlink_update.sh na raiz do pendrive (o kit nao esta la)"
else
  rc_kit="$(sed -n 's/^RC_S5_MD5="\([0-9a-f]\{32\}\)"$/\1/p' "$NL" | head -1)"
  rc_s5="$(md5 "$RC_S5")"
  if [ -z "$rc_kit" ]; then
    falha "3. o kit do pendrive e anterior ao bloco 26 (sem RC_S5_MD5): trocaria o .rc da S5 pelo dele e a semente pararia"
  elif [ "$rc_kit" != "$rc_s5" ]; then
    falha "3. o kit do pendrive aceita outro .rc da S5 (RC_S5_MD5 $rc_kit, o desta S5 e $rc_s5)"
  else
    ok "3. o kit do pendrive aceita o .rc da S5 (RC_S5_MD5 $rc_kit)"
  fi
  lista="$(sed -n '/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p' "$NL" | sed -n 's/^\(KIT_LISTA="\)\{0,1\}\([0-9a-f]\{32\}\)  \(.*\)$/\2  \3/p')"
  if [ -z "$lista" ]; then
    falha "3. sem a KIT_LISTA no newlink_update.sh do pendrive"
  else
    total=0; ruins=""
    while read -r h n; do
      [ -n "$n" ] || continue
      total=$((total + 1))
      if [ -L "$PEN_REAL/$n" ] || [ "$(md5 "$PEN_REAL/$n")" != "$h" ]; then ruins="$ruins $n"; fi
    done <<LISTA
$lista
LISTA
    if [ -z "$ruins" ]; then
      ok "3. kit do pendrive inteiro: $total arquivos da KIT_LISTA conferidos"
    else
      falha "3. arquivos do kit ausentes ou com md5 diferente da KIT_LISTA:$(printf '%s' "$ruins" | cut -c1-300)"
    fi
  fi
  if [ -e "$PEN_REAL/DESINSTALAR-SUITE.txt" ]; then
    falha "3. o pendrive tem DESINSTALAR-SUITE.txt: plugado depois do flash, ele tiraria a suite e a semente"
  fi
fi

# 4. backup do aparelho no PC: a pasta tem os arquivos soltos ou o pfl-backup.tar puxado do aparelho (doc 47 s12).
# Exige ao menos um arquivo nao vazio de data/vendor/pfl7560-*/ e a pasta data/data/com.pfl7560.home/shared_prefs
# (vazia vale: a home pode nao ter gravado escolha nenhuma)
PREFS='data/data/com.pfl7560.home/shared_prefs'
BK_REAL="$(real "$BACKUP")"
if [ -z "$BK_REAL" ]; then
  falha "4. pasta de backup '$BACKUP' ausente"
elif no_pendrive "$BK_REAL"; then
  falha "4. o backup esta no pendrive do flash ($BK_REAL): ele tem de estar no PC"
else
  n_vendor="$(find "$BK_REAL" -path '*data/vendor/pfl7560-*/*' -type f -size +0 2>/dev/null | wc -l | tr -d ' ')"
  n_prefs="$(find "$BK_REAL" -path "*$PREFS" -type d 2>/dev/null | wc -l | tr -d ' ')"
  tars=0; tar_ruim=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    tars=$((tars + 1))
    if ! lst="$(tar tvf "$t" 2>/dev/null)"; then tar_ruim="$tar_ruim $(basename "$t")"; continue; fi
    n_vendor=$((n_vendor + $(printf '%s\n' "$lst" | awk '$1 ~ /^-/ && $3 > 0 && $6 ~ /^(\.\/)?data\/vendor\/pfl7560-[^\/]*\/./' | wc -l)))
    n_prefs=$((n_prefs + $(printf '%s\n' "$lst" | awk -v p="$PREFS" '{ n = $6; sub(/^\.\//, "", n) } n == p || n == p "/" || index(n, p "/") == 1' | wc -l)))
  done <<TARS
$(find "$BK_REAL" -name '*.tar' -type f 2>/dev/null | sort)
TARS
  if [ -n "$tar_ruim" ]; then
    falha "4. tar de backup ilegivel em $BK_REAL:$tar_ruim"
  elif [ "$n_vendor" -gt 0 ] && [ "$n_prefs" -gt 0 ]; then
    ok "4. backup no PC: $BK_REAL ($n_vendor arquivos de /data/vendor/pfl7560-*, shared_prefs da home presente; $tars tar)"
  else
    falha "4. backup incompleto em $BK_REAL: $n_vendor arquivos nao vazios de /data/vendor/pfl7560-* e $n_prefs entradas de /$PREFS (precisa dos dois)"
  fi
fi

if [ "$FALHAS" = 0 ]; then
  echo "PRE-VOO APROVADO: o pendrive pode ir para o flash (com o sim do dono)"
  exit 0
fi
echo "PRE-VOO RECUSADO: $FALHAS item(ns) falharam. Nao grave."
exit 1
