#!/usr/bin/env bash
# artifacts/overlay/build.sh - monta as sobreposicoes (RRO) Dracula do bloco 13A, do zero, sem Gradle.
#
#   bash artifacts/overlay/build.sh
#
# Uma sobreposicao por pacote alvo, so recursos (sem classes.dex):
#   zysetting   -> com.zhiying.settings     PFL7560TemaZYSetting.apk
#   nlprovision -> com.newlink.nlprovision  PFL7560TemaNLProvision.apk
#   android     -> android (framework)      PFL7560TemaAndroid.apk   (por ultimo; ver doc 48)
# Passos de cada uma: aapt2 compile + link (-I android.jar) -> zipalign -> apksigner sign ->
# apksigner verify. Saida em artifacts/overlay/apk/. NAO copia para o kit (pendrive-autorun/):
# a integracao e do coordenador.
#
# Os recursos so tem valores literais (nenhuma referencia @...): no Android 9 uma sobreposicao
# nao enxerga recurso que so ela tem, e um id dela cairia no espaco de ids do alvo. Por isso o
# link nao precisa do APK do alvo; quem confere nome e tipo contra o alvo e o conferir.py.
#
# SDK local (sem rede): ANDROID_SDK (padrao ~/Android/sdk), BUILD_TOOLS (35.0.0), PLATAFORMA
# (android-34). Precisa de java (keytool/apksigner) e zip.
#
# Assinatura: chave propria e ESTAVEL, assinatura.keystore (alias pfl7560tema, senha abaixo). Nao e
# segredo: so garante que um APK novo substitua o anterior com a mesma assinatura.
set -euo pipefail
export LC_ALL=C TZ=UTC

AQUI="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_SDK:-$HOME/Android/sdk}"
BT="$SDK/build-tools/${BUILD_TOOLS:-35.0.0}"
JAR="$SDK/platforms/${PLATAFORMA:-android-34}/android.jar"
APKSIGNER="${APKSIGNER:-$(command -v apksigner || echo "$BT/apksigner")}"

VERSAO_CODIGO=1          # inteiro; sobe a cada APK novo
VERSAO_NOME="1.0"
MIN_SDK=28
TARGET_SDK=28
KS="$AQUI/assinatura.keystore"
KS_ALIAS="pfl7560tema"
KS_SENHA="pfl7560tema"   # nao e segredo (ver acima)
SAIDA="$AQUI/apk"

# pasta -> nome do APK (o mesmo nome vira a pasta em /vendor/overlay/<Nome>/<Nome>.apk)
SOBREPOSICOES="zysetting:PFL7560TemaZYSetting nlprovision:PFL7560TemaNLProvision android:PFL7560TemaAndroid"

for f in "$BT/aapt2" "$BT/zipalign" "$JAR" "$KS" "$APKSIGNER"; do
  [ -e "$f" ] || { echo "FALTA: $f" >&2; exit 1; }
done

B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT
mkdir -p "$SAIDA"

for par in $SOBREPOSICOES; do
  dir="${par%%:*}"; nome="${par##*:}"
  echo ">> $nome ($dir)"
  # nenhuma referencia a recurso dentro da sobreposicao (ver o cabecalho)
  if grep -rEn '"@(\+?id|color|drawable|style|dimen|string|layout|mipmap|android:)' "$AQUI/$dir/res"; then
    echo "ERRO: referencia a recurso em $dir/res (so valores literais)" >&2; exit 1
  fi
  "$BT/aapt2" compile --dir "$AQUI/$dir/res" -o "$B/$dir.zip"
  "$BT/aapt2" link -o "$B/$dir.apk" -I "$JAR" --manifest "$AQUI/$dir/AndroidManifest.xml" \
    --min-sdk-version "$MIN_SDK" --target-sdk-version "$TARGET_SDK" \
    --version-code "$VERSAO_CODIGO" --version-name "$VERSAO_NOME" \
    --no-auto-version "$B/$dir.zip"
  "$BT/zipalign" -f -p 4 "$B/$dir.apk" "$B/$dir-alinhado.apk"
  "$APKSIGNER" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" --ks-pass "pass:$KS_SENHA" \
    --out "$SAIDA/$nome.apk" "$B/$dir-alinhado.apk"
  "$APKSIGNER" verify --verbose "$SAIDA/$nome.apk" | grep -E '^Verified|^Verifies'
  rm -f "$SAIDA/$nome.apk.idsig"
  echo "   $SAIDA/$nome.apk md5 $(md5sum "$SAIDA/$nome.apk" | cut -d' ' -f1)"
done
echo ">> pronto. Confira contra os alvos do firmware:  python3 -I artifacts/overlay/conferir.py <pasta com os APKs alvo>"
