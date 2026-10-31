#!/usr/bin/env bash
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
SH="$KIT/newlink_update.sh"
SUITE_SH="$KIT/suite.sh"
BOOT_SH="$KIT/suite-boot.sh"
PEDIDO_SH="$KIT/suite-pedido.sh"
LVDS_MD5="178d812872cb9306c0ae6faeed07184a"

for f in "$SH" "$SUITE_SH" "$BOOT_SH" "$PEDIDO_SH"; do
  [ -f "$f" ] || { echo "FALHA: sem $f"; exit 1; }
done
if [ "$(md5sum "$ROOT/artifacts/lcd-color-fix/lvdsctl" | cut -d' ' -f1)" != "$LVDS_MD5" ] \
   || [ "$(md5sum "$KIT/lvdsctl" | cut -d' ' -f1)" != "$LVDS_MD5" ]; then
  echo "FALHA: lvdsctl (artifacts ou pendrive-autorun) nao tem o md5 $LVDS_MD5"; exit 1
fi
if ! cmp -s "$ROOT/artifacts/camcheck/nl_camcheck" "$KIT/nl_camcheck"; then
  echo "FALHA: pendrive-autorun/nl_camcheck difere de artifacts/camcheck/nl_camcheck"; exit 1
fi
NLTELA=""
if [ -e "$KIT/nl_tela" ]; then
  if ! cmp -s "$ROOT/artifacts/tela/nl_tela" "$KIT/nl_tela"; then
    echo "FALHA: pendrive-autorun/nl_tela difere de artifacts/tela/nl_tela"; exit 1
  fi
  NLTELA="nl_tela"
fi
APK=""
if [ -e "$KIT/pfl7560.apk" ]; then
  if ! cmp -s "$ROOT/artifacts/app/pfl7560.apk" "$KIT/pfl7560.apk"; then
    echo "FALHA: pendrive-autorun/pfl7560.apk difere de artifacts/app/pfl7560.apk (rode artifacts/app/build.sh)"; exit 1
  fi
  APK="pfl7560.apk"
fi
if [ -e "$KIT/pfl7560-home.apk" ]; then
  if ! cmp -s "$ROOT/artifacts/home/pfl7560-home.apk" "$KIT/pfl7560-home.apk"; then
    echo "FALHA: pendrive-autorun/pfl7560-home.apk difere de artifacts/home/pfl7560-home.apk (rode artifacts/home/build.sh)"; exit 1
  fi
  APK="$APK pfl7560-home.apk"
fi
FONTES=""
for f in "$KIT"/fontes/*; do [ -f "$f" ] && FONTES="$FONTES fontes/${f##*/}"; done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OVL_FONTE="$ROOT/artifacts/overlay/apk"
MARCA_FONTE="$ROOT/artifacts/tema/marca"
mkdir -p "$TMP/novo/overlay" "$TMP/novo/marca"
OVL_NOMES=""
for f in "$OVL_FONTE"/*.apk; do
  [ -f "$f" ] || continue
  n="${f##*/}"
  case "${n%.apk}" in
    *[!A-Za-z0-9]*) echo "FALHA: nome de sobreposicao fora de [A-Za-z0-9]: $n"; exit 1 ;;
  esac
  [ "$n" = "PFL7560TemaAndroid.apk" ] && continue
  OVL_NOMES="$OVL_NOMES $n"
done
[ -f "$OVL_FONTE/PFL7560TemaAndroid.apk" ] && OVL_NOMES="$OVL_NOMES PFL7560TemaAndroid.apk"
[ -n "$OVL_NOMES" ] || { echo "FALHA: nenhum APK em artifacts/overlay/apk/"; exit 1; }
for n in $OVL_NOMES; do cp "$OVL_FONTE/$n" "$TMP/novo/overlay/$n"; done
MARCA_NOMES="logo.jpg bootanimation.zip"
for n in $MARCA_NOMES; do
  [ -f "$MARCA_FONTE/$n" ] || { echo "FALHA: sem artifacts/tema/marca/$n"; exit 1; }
  cp "$MARCA_FONTE/$n" "$TMP/novo/marca/$n"
done
OVL_LISTA=""; MARCA_LISTA=""
for n in $OVL_NOMES; do OVL_LISTA="$OVL_LISTA overlay/$n"; done
for n in $MARCA_NOMES; do MARCA_LISTA="$MARCA_LISTA marca/$n"; done

troca_bloco(){
  awk -v ini="# $2" -v fim="# $3" -v novo="$4" '
    $0 == ini { print; while ((getline l < novo) > 0) print l; pula=1; next }
    $0 == fim { pula=0 }
    !pula { print }
  ' "$1" > "$5"
}
md5(){ md5sum "$1" | cut -d' ' -f1; }

# shellcheck disable=SC2086
suite_lista="$(cd "$KIT" && for f in cor.sh lvdsctl nl_camcheck $NLTELA kit/*.png $FONTES; do md5sum "$f"; done)"
{ printf 'SUITE_LISTA="%s\n' "$suite_lista"; echo '"'; } > "$TMP/b1"
troca_bloco "$SUITE_SH" SUITE_LISTA_INICIO SUITE_LISTA_FIM "$TMP/b1" "$TMP/suite.sh"

m_suite="$(md5 "$TMP/suite.sh")"
echo "SUITE_MD5=\"$m_suite\"" > "$TMP/b2p"
troca_bloco "$PEDIDO_SH" SUITE_MD5_INICIO SUITE_MD5_FIM "$TMP/b2p" "$TMP/suite-pedido.sh"
m_pedido="$(md5 "$TMP/suite-pedido.sh")"
{ echo "SUITE_MD5=\"$m_suite\""; echo "PEDIDO_MD5=\"$m_pedido\""; } > "$TMP/b2b"
troca_bloco "$BOOT_SH" SUITE_MD5_INICIO SUITE_MD5_FIM "$TMP/b2b" "$TMP/suite-boot.sh"

{ printf 'KIT_OVERLAYS="'
  for n in $OVL_NOMES; do printf 'overlay/%s:%s\n' "$n" "${n%.apk}"; done
  echo '"'; } > "$TMP/b4"
troca_bloco "$SH" KIT_OVERLAYS_INICIO KIT_OVERLAYS_FIM "$TMP/b4" "$TMP/newlink_update.ovl.sh"
mkdir -p "$TMP/kit"
cp -r "$KIT"/. "$TMP/kit/"
rm -rf "$TMP/kit/overlay" "$TMP/kit/marca"
cp -r "$TMP/novo/overlay" "$TMP/novo/marca" "$TMP/kit/"
cp "$TMP/suite.sh" "$TMP/suite-boot.sh" "$TMP/suite-pedido.sh" "$TMP/kit/"
# shellcheck disable=SC2086
lista="$(cd "$TMP/kit" && for f in ZYCustom.ini cor.sh lvdsctl nl_camcheck $NLTELA suite.sh suite-boot.sh suite-pedido.sh pfl7560-suite.rc $APK kit/*.png $FONTES $OVL_LISTA $MARCA_LISTA; do md5sum "$f"; done)"
{ printf 'KIT_LISTA="%s\n' "$lista"; echo '"'; } > "$TMP/b3"
troca_bloco "$TMP/newlink_update.ovl.sh" KIT_LISTA_INICIO KIT_LISTA_FIM "$TMP/b3" "$TMP/newlink_update.sh"

if [ "${1:-}" = "--check" ]; then
  rc=0
  for f in suite.sh suite-boot.sh suite-pedido.sh newlink_update.sh; do
    cmp -s "$TMP/$f" "$KIT/$f" || { echo "FALHA: a lista md5 embutida no $f esta desatualizada (rode tests/atualizar-md5-kit.sh)"; rc=1; }
  done
  for d in overlay marca; do
    if ! diff -r "$TMP/novo/$d" "$KIT/$d" >/dev/null 2>&1; then
      echo "FALHA: pendrive-autorun/$d difere de artifacts/ (rode tests/atualizar-md5-kit.sh)"; rc=1
    fi
  done
  [ "$rc" = 0 ] && echo "listas md5 do kit e da suite em dia"
  exit "$rc"
fi
for f in suite.sh suite-boot.sh suite-pedido.sh newlink_update.sh; do
  cmp -s "$TMP/$f" "$KIT/$f" || cat "$TMP/$f" > "$KIT/$f"
done
for d in overlay marca; do
  mkdir -p "$KIT/$d"
  for f in "$KIT/$d"/*; do [ -f "$f" ] && [ ! -e "$TMP/novo/$d/${f##*/}" ] && rm -f "$f"; done
  for f in "$TMP/novo/$d"/*; do cmp -s "$f" "$KIT/$d/${f##*/}" || cp "$f" "$KIT/$d/${f##*/}"; done
done
echo "listas md5 gravadas em suite.sh, suite-boot.sh, suite-pedido.sh e newlink_update.sh; overlay/ e marca/ do kit em dia"
