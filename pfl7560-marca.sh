#!/usr/bin/env bash
# pfl7560-marca.sh - grava a marca MeowCast na particao "logo" (a imagem que o carregador mostra
# antes do Android; bloco 14). Fica FORA do pendrive de proposito: a imagem depende dos 4 cantos
# do keystone de CADA aparelho (o carregador mostra a imagem ja distorcida, porque o keystone
# ainda nao existe nessa hora) e a particao e a do carregador.
#
# O que faz, nesta ordem (qualquer passo falho para tudo e deixa a particao como estava):
#   1. conecta por adb (Wi-Fi), vira root e confere que e um PFL7560;
#   2. le os cantos persist.sys.keystone.{lt,rt,lb,rb} do aparelho;
#   3. gera a imagem com artifacts/tema/gerar-marca.py (numa pasta temporaria, sem tocar nos
#      arquivos versionados);
#   4. BACKUP da particao inteira (40 MB) em backups-projetor/logo/logo-<data>.img, conferido por md5
#      contra a leitura direta do aparelho;
#   5. monta a imagem nova a partir do backup (cabecalho LOGO_TABLE: LOGO_KEY_LEN, 4 bytes no 0x78,
#      passa a valer o tamanho do JPEG novo; o JPEG vai no byte 8192, onde o fabricante o poe) e
#      confere o cabecalho antes de gravar qualquer coisa;
#   6. grava SO essas duas regioes com dd (sem conv, que o toybox recusa), depois de conferir o md5 dos
#      arquivos no aparelho e de a particao ainda ser igual ao backup;
#   7. RELE a particao inteira e confere o md5 contra a imagem esperada.
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-marca.sh [--sim]               gera, faz backup, grava e confere
#   PFL_IP=<ip> ./pfl7560-marca.sh --restaurar <backup.img> [--sim]   devolve a particao inteira
#   ./pfl7560-marca.sh --ajuda
#   --sim (ou PFL_SIM=1) dispensa a pergunta "digite GRAVAR". Vale na proxima ligacao do projetor.
# Precisa de: adb, python3 com Pillow, md5sum.
set -uo pipefail
export LC_ALL=C

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BK="${PFL_BACKUPS:-$HERE/backups-projetor/logo}"
PART=/dev/block/by-name/logo
TMPDEV=/data/local/tmp
TAM_PART=41943040
JPEG_OFF=8192
KEYLEN_OFF=120
MODO=gravar
BACKUP_ARQ=""
SIM="${PFL_SIM:-}"

X='\033[1;31m'; V='\033[1;32m'; C='\033[1;36m'; Z='\033[0m'
err(){ printf "${X}[ERRO]${Z}  %s\n" "$*" >&2; }
ok(){  printf "${V}[OK]${Z}    %s\n" "$*" >&2; }
say(){ printf "${C}>> %s${Z}\n" "$*" >&2; }
ajuda(){ sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --restaurar) MODO=restaurar; BACKUP_ARQ="${2:-}"; [ -n "$BACKUP_ARQ" ] || { err "--restaurar pede o arquivo de backup"; exit 2; }; shift 2 ;;
    --sim) SIM=1; shift ;;
    --ajuda|-h|--help) ajuda; exit 0 ;;
    *) err "argumento desconhecido: $1 (veja --ajuda)"; exit 2 ;;
  esac
done

TMP="$(mktemp -d)"
D=""
LIMPAR_DEV=""
limpa_dev(){ [ -n "$D" ] && [ -n "$LIMPAR_DEV" ] && "$ADB" -s "$D" shell "rm -f $LIMPAR_DEV" >/dev/null 2>&1; return 0; }
trap 'limpa_dev; rm -rf "$TMP"' EXIT

sh_dev(){ "$ADB" -s "$D" shell "$@" 2>/dev/null | tr -d '\r'; }
md5_local(){ md5sum "$1" | cut -d' ' -f1; }
md5_part(){ sh_dev "md5sum $PART" | cut -d' ' -f1; }

conecta(){
  [ -n "$IP" ] || { err "defina PFL_IP=<ip do projetor> (o adb deste aparelho e so por Wi-Fi, TCP 5555)"; exit 2; }
  case "$IP" in *:*) D="$IP" ;; *) D="$IP:$PORTA" ;; esac
  timeout 15 "$ADB" connect "$D" >/dev/null 2>&1
  "$ADB" -s "$D" wait-for-device >/dev/null 2>&1 || true
  local u m
  u="$("$ADB" -s "$D" shell id 2>/dev/null | grep -oE 'uid=[0-9]+' | head -1)"
  if [ "$u" != "uid=0" ]; then
    "$ADB" -s "$D" root >/dev/null 2>&1; sleep 2
    timeout 15 "$ADB" connect "$D" >/dev/null 2>&1
    "$ADB" -s "$D" wait-for-device >/dev/null 2>&1 || true
  fi
  m="$(sh_dev "getprop ro.product.model" | tr -d '\n ')"
  [ "$m" = "PFL7560" ] || { err "o dispositivo em $D NAO e um PFL7560 (modelo '$m') - nada foi feito"; exit 2; }
  u="$("$ADB" -s "$D" shell id 2>/dev/null | grep -oE 'uid=[0-9]+' | head -1)"
  [ "$u" = "uid=0" ] || { err "sem root em $D (id devolveu '${u:-vazio}') - nada foi feito"; exit 2; }
  ok "conectado ao PFL7560 em $D (root)"
}

confirma(){
  [ -n "$SIM" ] && return 0
  [ -t 0 ] || { err "sem terminal para confirmar: use --sim"; exit 2; }
  printf '%s\n' "$1" >&2
  local r; read -r -p "Digite GRAVAR para continuar: " r
  [ "$r" = "GRAVAR" ] || { err "cancelado, nada foi feito"; exit 2; }
}

cabecalho_ok(){
  python3 -I - "$1" "$TAM_PART" "$JPEG_OFF" "$KEYLEN_OFF" <<'PY'
import struct, sys
arq, tam, joff, koff = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
d = open(arq, "rb").read(joff + 16)
import os
if os.path.getsize(arq) != tam:
    sys.exit("tamanho %d, esperado %d" % (os.path.getsize(arq), tam))
if d[0:4] != b"###\0" or d[8:18] != b"LOGO_TABLE" or d[0x54:0x60] != b"LOGO_KEY_LEN":
    sys.exit("cabecalho LOGO_TABLE nao reconhecido (nao e a particao logo conhecida)")
n = struct.unpack_from("<I", d, koff)[0]
if not (0 < n < tam - joff) or d[joff:joff + 2] != b"\xff\xd8":
    sys.exit("LOGO_KEY_LEN=%d ou JPEG no byte %d fora do esperado" % (n, joff))
print(n)
PY
}

backup_particao(){
  local arq="$1" tam m_dev m_loc
  tam="$(sh_dev "blockdev --getsize64 $PART" | tr -dc '0-9')"
  [ "$tam" = "$TAM_PART" ] || { err "a particao $PART tem '${tam:-?}' bytes, esperado $TAM_PART - nada foi feito"; exit 1; }
  say "backup da particao logo (40 MB) em $arq"
  mkdir -p "$(dirname "$arq")" || { err "nao consegui criar $(dirname "$arq")"; exit 1; }
  "$ADB" -s "$D" exec-out "dd if=$PART bs=1048576 2>/dev/null" > "$arq.parcial" 2>/dev/null
  if [ "$(wc -c < "$arq.parcial" | tr -d ' ')" != "$TAM_PART" ]; then
    rm -f "$arq.parcial"; err "o backup veio com tamanho errado - nada foi gravado"; exit 1
  fi
  m_dev="$(md5_part)"; m_loc="$(md5_local "$arq.parcial")"
  if [ -z "$m_dev" ] || [ "$m_dev" != "$m_loc" ]; then
    rm -f "$arq.parcial"; err "o md5 do backup ($m_loc) difere do da particao no aparelho ($m_dev) - nada foi gravado"; exit 1
  fi
  mv "$arq.parcial" "$arq" && ok "backup conferido (md5 $m_loc)"
  BACKUP_MD5="$m_loc"
}

gravar(){
  local cantos lt rt lb rb saida jpeg_n novo esperado
  conecta
  cantos=""
  for k in lt rt lb rb; do
    v="$(sh_dev "getprop persist.sys.keystone.$k" | tr -d '\n ')"
    case "$v" in
      [0-9]*,[0-9]*) ;;
      *) err "persist.sys.keystone.$k='$v' (esperado x,y) - sem os 4 cantos nao gero a imagem"; exit 1 ;;
    esac
    cantos="$cantos $v"
  done
  # shellcheck disable=SC2086
  set -- $cantos; lt="$1"; rt="$2"; lb="$3"; rb="$4"
  ok "cantos do keystone: lt=$lt rt=$rt lb=$lb rb=$rb"
  saida="$TMP/marca"; mkdir -p "$saida"
  PFL_MARCA_SAIDA="$saida" python3 -I "$HERE/artifacts/tema/gerar-marca.py" "$lt" "$rt" "$lb" "$rb" >"$TMP/gerar.log" 2>&1 \
    || { err "gerar-marca.py falhou: $(tail -3 "$TMP/gerar.log" | tr '\n' ' ')"; exit 1; }
  [ -s "$saida/logo-boot.jpg" ] || { err "gerar-marca.py nao gerou logo-boot.jpg"; exit 1; }
  ok "imagem gerada: logo-boot.jpg ($(wc -c < "$saida/logo-boot.jpg" | tr -d ' ') bytes)"

  local bk_arq
  bk_arq="$BK/logo-$(date +%Y%m%d-%H%M%S).img"
  BACKUP_MD5=""
  backup_particao "$bk_arq"
  cabecalho_ok "$bk_arq" >"$TMP/jpeg_atual" 2>"$TMP/cab.err" || { err "$(cat "$TMP/cab.err") - nada foi gravado"; exit 1; }

  novo="$TMP/logo-novo.img"
  python3 -I - "$bk_arq" "$saida/logo-boot.jpg" "$novo" "$JPEG_OFF" "$KEYLEN_OFF" "$TMP/keylen.bin" <<'PY' || { err "nao consegui montar a imagem nova"; exit 1; }
import struct, sys
bk, jpg, out, joff, koff, kfile = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
d = bytearray(open(bk, "rb").read())
j = open(jpg, "rb").read()
if j[:2] != b"\xff\xd8" or j[-2:] != b"\xff\xd9":
    sys.exit("o JPEG novo nao tem SOI/EOI")
if joff + len(j) > len(d):
    sys.exit("o JPEG novo nao cabe na particao")
d[joff:joff + len(j)] = j
struct.pack_into("<I", d, koff, len(j))
open(out, "wb").write(d)
open(kfile, "wb").write(struct.pack("<I", len(j)))
PY
  esperado="$(md5_local "$novo")"
  jpeg_n="$(wc -c < "$saida/logo-boot.jpg" | tr -d ' ')"
  cabecalho_ok "$novo" >"$TMP/jpeg_novo" 2>"$TMP/cab.err" || { err "a imagem montada nao passa na conferencia: $(cat "$TMP/cab.err") - nada foi gravado"; exit 1; }
  [ "$(cat "$TMP/jpeg_novo")" = "$jpeg_n" ] || { err "LOGO_KEY_LEN montado ($(cat "$TMP/jpeg_novo")) difere do JPEG ($jpeg_n) - nada foi gravado"; exit 1; }

  confirma "Vou gravar o JPEG novo ($jpeg_n bytes, no byte $JPEG_OFF) e o LOGO_KEY_LEN (byte $KEYLEN_OFF) na particao $PART do $D. Backup em $bk_arq."

  LIMPAR_DEV="$TMPDEV/pfl-logo-boot.jpg $TMPDEV/pfl-logo-keylen.bin"
  "$ADB" -s "$D" push "$saida/logo-boot.jpg" "$TMPDEV/pfl-logo-boot.jpg" >/dev/null 2>&1
  "$ADB" -s "$D" push "$TMP/keylen.bin" "$TMPDEV/pfl-logo-keylen.bin" >/dev/null 2>&1
  [ "$(sh_dev "md5sum $TMPDEV/pfl-logo-boot.jpg" | cut -d' ' -f1)" = "$(md5_local "$saida/logo-boot.jpg")" ] \
    || { err "o JPEG no aparelho nao confere (md5) - nada foi gravado"; exit 1; }
  [ "$(sh_dev "md5sum $TMPDEV/pfl-logo-keylen.bin" | cut -d' ' -f1)" = "$(md5_local "$TMP/keylen.bin")" ] \
    || { err "o LOGO_KEY_LEN no aparelho nao confere (md5) - nada foi gravado"; exit 1; }
  [ "$(md5_part)" = "$BACKUP_MD5" ] || { err "a particao mudou depois do backup - nada foi gravado"; exit 1; }

  say "gravando (dd na particao logo)"
  sh_dev "dd if=$TMPDEV/pfl-logo-boot.jpg of=$PART bs=4096 seek=$((JPEG_OFF / 4096))" >/dev/null
  sh_dev "dd if=$TMPDEV/pfl-logo-keylen.bin of=$PART bs=1 seek=$KEYLEN_OFF" >/dev/null
  sh_dev "sync" >/dev/null
  local lido; lido="$(md5_part)"
  if [ "$lido" = "$esperado" ]; then
    ok "particao relida e conferida (md5 $lido). A imagem nova vale na proxima ligacao do projetor."
    ok "para desfazer: PFL_IP=$IP ./pfl7560-marca.sh --restaurar $bk_arq"
    return 0
  fi
  err "a releitura NAO confere (lido $lido, esperado $esperado). Restaure ja: PFL_IP=$IP ./pfl7560-marca.sh --restaurar $bk_arq"
  exit 1
}

restaurar(){
  local arq="$1" m
  [ -f "$arq" ] || { err "backup nao encontrado: $arq"; exit 2; }
  cabecalho_ok "$arq" >/dev/null 2>"$TMP/cab.err" || { err "$arq nao parece o backup da particao logo: $(cat "$TMP/cab.err") - nada foi feito"; exit 2; }
  conecta
  [ "$(sh_dev "blockdev --getsize64 $PART" | tr -dc '0-9')" = "$TAM_PART" ] || { err "a particao $PART nao tem $TAM_PART bytes - nada foi feito"; exit 1; }
  m="$(md5_local "$arq")"
  confirma "Vou devolver a particao $PART do $D ao conteudo de $arq (md5 $m), inteira."
  LIMPAR_DEV="$TMPDEV/pfl-logo-restaura.img"
  "$ADB" -s "$D" push "$arq" "$TMPDEV/pfl-logo-restaura.img" >/dev/null 2>&1
  [ "$(sh_dev "md5sum $TMPDEV/pfl-logo-restaura.img" | cut -d' ' -f1)" = "$m" ] \
    || { err "o arquivo no aparelho nao confere (md5) - nada foi gravado"; exit 1; }
  say "gravando a particao inteira (dd)"
  sh_dev "dd if=$TMPDEV/pfl-logo-restaura.img of=$PART bs=1048576" >/dev/null
  sh_dev "sync" >/dev/null
  if [ "$(md5_part)" = "$m" ]; then ok "particao restaurada e conferida (md5 $m)"; return 0; fi
  err "a releitura NAO confere com o backup (md5 $m). Repita --restaurar."
  exit 1
}

case "$MODO" in
  gravar) gravar ;;
  restaurar) restaurar "$BACKUP_ARQ" ;;
esac
