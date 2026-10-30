#!/usr/bin/env bash
# tests/atualizar-md5-kit.sh - bloco 5 (E3)
# Reescreve, em pendrive-autorun/newlink_update.sh, a lista embutida com o md5 de
# CADA arquivo do kit (o que o autorun confere antes de qualquer escrita).
#   bash tests/atualizar-md5-kit.sh           grava a lista
#   bash tests/atualizar-md5-kit.sh --check   so confere; sai !=0 se estiver velha
# Tambem exige que pendrive-autorun/lvdsctl seja byte-identico ao binario
# versionado em artifacts/lcd-color-fix/lvdsctl (md5 178d8128...). Nao toca no aparelho.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
SH="$KIT/newlink_update.sh"
LVDS_MD5="178d812872cb9306c0ae6faeed07184a"

[ -f "$SH" ] || { echo "FALHA: sem $SH"; exit 1; }
if [ "$(md5sum "$ROOT/artifacts/lcd-color-fix/lvdsctl" | cut -d' ' -f1)" != "$LVDS_MD5" ] \
   || [ "$(md5sum "$KIT/lvdsctl" | cut -d' ' -f1)" != "$LVDS_MD5" ]; then
  echo "FALHA: lvdsctl (artifacts ou pendrive-autorun) nao tem o md5 $LVDS_MD5"; exit 1
fi

lista="$(cd "$KIT" && for f in ZYCustom.ini cor.sh lvdsctl kit/*.png; do md5sum "$f"; done)"
novo="$(mktemp)"
awk -v lista="$lista" '
  /^# KIT_LISTA_INICIO/ { print; print "KIT_LISTA=\"" lista; print "\""; pula=1; next }
  /^# KIT_LISTA_FIM/    { pula=0 }
  !pula { print }
' "$SH" > "$novo"

if [ "${1:-}" = "--check" ]; then
  if cmp -s "$novo" "$SH"; then echo "lista md5 do kit em dia"; rm -f "$novo"; exit 0; fi
  echo "FALHA: a lista md5 embutida no newlink_update.sh esta desatualizada (rode tests/atualizar-md5-kit.sh)"
  rm -f "$novo"; exit 1
fi
cat "$novo" > "$SH"   # preserva modo e atributos do arquivo
rm -f "$novo"
echo "lista md5 do kit gravada em $SH"
