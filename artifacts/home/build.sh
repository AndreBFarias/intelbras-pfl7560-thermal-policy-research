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
KS_ALIAS="pfl7560home"
KS_SENHA="pfl7560home"
SAIDA="$AQUI/pfl7560-home.apk"
FONTES="$RAIZ/pendrive-autorun/fontes"
PALETA="$RAIZ/artifacts/tema/dracula.txt"

for f in "$BT/aapt2" "$BT/d8" "$BT/zipalign" "$JAR" "$KS" "$APKSIGNER" "$PALETA" \
         "$FONTES/IBMPlexSansCondensed-Regular.ttf" "$FONTES/IBMPlexSansCondensed-SemiBold.ttf" \
         "$FONTES/IBMPlexSansCondensed-Bold.ttf" "$FONTES/IBMPlexMono-Regular.ttf" \
         "$FONTES/IBMPlexMono-SemiBold.ttf" "$FONTES/OFL.txt"; do
  [ -e "$f" ] || { echo "FALTA: $f" >&2; exit 1; }
done
for c in javac zip; do command -v "$c" >/dev/null || { echo "FALTA o comando $c" >&2; exit 1; }; done

echo ">> paleta (artifacts/tema/dracula.txt x colors.xml x Tema.java)"
TOKENS="$(sed -nE 's/^([a-z]+)=#([0-9A-Fa-f]{6})$/\1 \2/p' "$PALETA")"
[ "$(printf '%s\n' "$TOKENS" | wc -l)" -eq 11 ] || { echo "ERRO: $PALETA nao tem os 11 tokens" >&2; exit 1; }
while read -r nome hex; do
  hex="${hex^^}"
  grep -q "<color name=\"$nome\">#FF$hex</color>" "$AQUI/res/values/colors.xml" \
    || { echo "ERRO: colors.xml difere da paleta em $nome (#$hex)" >&2; exit 1; }
  grep -q "int ${nome^^} = 0xFF$hex;" "$AQUI/src/com/pfl7560/home/Tema.java" \
    || { echo "ERRO: Tema.java difere da paleta em $nome (#$hex)" >&2; exit 1; }
done <<< "$TOKENS"
echo "   11 tokens iguais"

B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT
mkdir -p "$B/gen" "$B/classes" "$B/dex" "$B/assets/fontes"
cp "$FONTES"/IBMPlex*.ttf "$FONTES/OFL.txt" "$B/assets/fontes/"
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
  --out "$B/home.apk" "$B/alinhado.apk"
"$APKSIGNER" verify --verbose "$B/home.apk"

cp "$B/home.apk" "$SAIDA"
echo ">> pronto: $SAIDA (md5 $(md5sum "$SAIDA" | cut -d' ' -f1))"
