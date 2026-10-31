#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C TZ=UTC

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
SDK="${ANDROID_SDK:-$HOME/Android/sdk}"
BT="$SDK/build-tools/${BUILD_TOOLS:-35.0.0}"
JAR="$SDK/platforms/${PLATAFORMA:-android-34}/android.jar"
APKSIGNER="${APKSIGNER:-$(command -v apksigner || echo "$BT/apksigner")}"

VERSAO_CODIGO=5
VERSAO_NOME="1.0"
MIN_SDK=28
TARGET_SDK=28
KS="$AQUI/assinatura.keystore"
KS_ALIAS="pfl7560"
KS_SENHA="pfl7560app"
SAIDA="$AQUI/pfl7560.apk"
FONTES="$RAIZ/pendrive-autorun/fontes"
COPIA_KIT="$RAIZ/pendrive-autorun/pfl7560.apk"

for f in "$BT/aapt2" "$BT/d8" "$BT/zipalign" "$JAR" "$KS" "$APKSIGNER" \
         "$FONTES/IBMPlexSansCondensed-Bold.ttf" "$FONTES/OFL.txt"; do
  [ -e "$f" ] || { echo "FALTA: $f" >&2; exit 1; }
done
for c in javac zip; do command -v "$c" >/dev/null || { echo "FALTA o comando $c" >&2; exit 1; }; done

B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT
mkdir -p "$B/gen" "$B/classes" "$B/dex" "$B/assets/fontes"
cp "$FONTES/IBMPlexSansCondensed-Bold.ttf" "$FONTES/OFL.txt" "$B/assets/fontes/"
touch -d '2026-01-01 00:00:00' "$B/assets/fontes/"*

echo ">> recursos (aapt2 compile + link)"
"$BT/aapt2" compile --dir "$AQUI/res" -o "$B/res.zip"
"$BT/aapt2" link -o "$B/base.apk" -I "$JAR" --manifest "$AQUI/AndroidManifest.xml" \
  --min-sdk-version "$MIN_SDK" --target-sdk-version "$TARGET_SDK" \
  --version-code "$VERSAO_CODIGO" --version-name "$VERSAO_NOME" \
  -A "$B/assets" --java "$B/gen" "$B/res.zip"

echo ">> java (javac --release 8)"
find "$AQUI/src" "$B/gen" -name '*.java' | sort > "$B/fontes.txt"
javac --release 8 -Xlint:-options -encoding UTF-8 -classpath "$JAR" -d "$B/classes" @"$B/fontes.txt"

echo ">> dex (d8)"
find "$B/classes" -name '*.class' | sort > "$B/classes.txt"
"$BT/d8" --min-api "$MIN_SDK" --lib "$JAR" --output "$B/dex" @"$B/classes.txt"

echo ">> APK (dex no zip, zipalign, assinatura)"
touch -d '2026-01-01 00:00:00' "$B/dex/classes.dex"
( cd "$B/dex" && zip -q -X -j "$B/base.apk" classes.dex )
"$BT/zipalign" -f -p 4 "$B/base.apk" "$B/alinhado.apk"
"$APKSIGNER" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" --ks-pass "pass:$KS_SENHA" \
  --out "$B/pfl7560.apk" "$B/alinhado.apk"
"$APKSIGNER" verify --verbose "$B/pfl7560.apk"

cp "$B/pfl7560.apk" "$SAIDA"
cp "$SAIDA" "$COPIA_KIT"
echo ">> pronto: $SAIDA (md5 $(md5sum "$SAIDA" | cut -d' ' -f1)); copia em $COPIA_KIT"
echo ">> agora: bash tests/atualizar-md5-kit.sh"
