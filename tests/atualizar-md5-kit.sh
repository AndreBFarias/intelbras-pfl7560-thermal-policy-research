#!/usr/bin/env bash
# tests/atualizar-md5-kit.sh - bloco 5 (E3), suite no bloco 9B
# Reescreve os md5 embutidos no kit, nesta ordem (cada um depende do anterior):
#   1. pendrive-autorun/suite.sh: SUITE_LISTA, o md5 de cada arquivo que a suite executa
#      ou mostra (cor.sh, lvdsctl, nl_camcheck, nl_tela, kit/*.png, fontes/*);
#   2. pendrive-autorun/suite-boot.sh e suite-pedido.sh: o md5 do suite.sh (e, no
#      suite-boot.sh, o do suite-pedido.sh);
#   3. pendrive-autorun/newlink_update.sh: KIT_LISTA, o md5 de CADA arquivo do kit (o que
#      o autorun confere antes de qualquer escrita).
#   bash tests/atualizar-md5-kit.sh           grava as listas
#   bash tests/atualizar-md5-kit.sh --check   so confere; sai !=0 se alguma estiver velha
# Tambem exige que pendrive-autorun/lvdsctl seja byte-identico ao binario
# versionado em artifacts/lcd-color-fix/lvdsctl (md5 178d8128...), e que o
# pendrive-autorun/nl_camcheck (binario ARM da camera, bloco 7) seja byte-identico ao
# versionado em artifacts/camcheck/nl_camcheck. O nl_tela e as fontes (bloco 9A) entram
# nas listas quando existirem em pendrive-autorun/ (e o nl_tela tem de ser igual ao de
# artifacts/tela/nl_tela). O pfl7560.apk (app, bloco 9C) entra so na KIT_LISTA (a suite nao o
# executa; o newlink_update.sh o instala) e tem de ser igual ao de artifacts/app/pfl7560.apk.
# Nao toca no aparelho.
set -u
export LC_ALL=C   # ordem dos nomes (glob) igual em qualquer maquina
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

# troca o miolo entre "# <INICIO>" e "# <FIM>" de $1 pelo texto de $4 (arquivo); saida em $5
troca_bloco(){
  awk -v ini="# $2" -v fim="# $3" -v novo="$4" '
    $0 == ini { print; while ((getline l < novo) > 0) print l; pula=1; next }
    $0 == fim { pula=0 }
    !pula { print }
  ' "$1" > "$5"
}
md5(){ md5sum "$1" | cut -d' ' -f1; }

# 1. SUITE_LISTA (suite.sh)
# shellcheck disable=SC2086  # nomes sem espaco, divisao de proposito
suite_lista="$(cd "$KIT" && for f in cor.sh lvdsctl nl_camcheck $NLTELA kit/*.png $FONTES; do md5sum "$f"; done)"
{ printf 'SUITE_LISTA="%s\n' "$suite_lista"; echo '"'; } > "$TMP/b1"
troca_bloco "$SUITE_SH" SUITE_LISTA_INICIO SUITE_LISTA_FIM "$TMP/b1" "$TMP/suite.sh"

# 2. md5 do suite.sh (o NOVO) no suite-boot.sh e no suite-pedido.sh
m_suite="$(md5 "$TMP/suite.sh")"
echo "SUITE_MD5=\"$m_suite\"" > "$TMP/b2p"
troca_bloco "$PEDIDO_SH" SUITE_MD5_INICIO SUITE_MD5_FIM "$TMP/b2p" "$TMP/suite-pedido.sh"
m_pedido="$(md5 "$TMP/suite-pedido.sh")"
{ echo "SUITE_MD5=\"$m_suite\""; echo "PEDIDO_MD5=\"$m_pedido\""; } > "$TMP/b2b"
troca_bloco "$BOOT_SH" SUITE_MD5_INICIO SUITE_MD5_FIM "$TMP/b2b" "$TMP/suite-boot.sh"

# 3. KIT_LISTA (newlink_update.sh), com os scripts da suite ja regravados
mkdir -p "$TMP/kit"
cp -r "$KIT"/. "$TMP/kit/"
cp "$TMP/suite.sh" "$TMP/suite-boot.sh" "$TMP/suite-pedido.sh" "$TMP/kit/"
# shellcheck disable=SC2086
lista="$(cd "$TMP/kit" && for f in ZYCustom.ini cor.sh lvdsctl nl_camcheck $NLTELA suite.sh suite-boot.sh suite-pedido.sh pfl7560-suite.rc $APK kit/*.png $FONTES; do md5sum "$f"; done)"
{ printf 'KIT_LISTA="%s\n' "$lista"; echo '"'; } > "$TMP/b3"
troca_bloco "$SH" KIT_LISTA_INICIO KIT_LISTA_FIM "$TMP/b3" "$TMP/newlink_update.sh"

if [ "${1:-}" = "--check" ]; then
  rc=0
  for f in suite.sh suite-boot.sh suite-pedido.sh newlink_update.sh; do
    cmp -s "$TMP/$f" "$KIT/$f" || { echo "FALHA: a lista md5 embutida no $f esta desatualizada (rode tests/atualizar-md5-kit.sh)"; rc=1; }
  done
  [ "$rc" = 0 ] && echo "listas md5 do kit e da suite em dia"
  exit "$rc"
fi
for f in suite.sh suite-boot.sh suite-pedido.sh newlink_update.sh; do
  cmp -s "$TMP/$f" "$KIT/$f" || cat "$TMP/$f" > "$KIT/$f"   # cat preserva modo e atributos
done
echo "listas md5 gravadas em suite.sh, suite-boot.sh, suite-pedido.sh e newlink_update.sh"
