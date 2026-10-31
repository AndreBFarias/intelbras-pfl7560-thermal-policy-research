#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C TZ=UTC

AQUI="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_SDK:-$HOME/Android/sdk}"
BT="$SDK/build-tools/${BUILD_TOOLS:-35.0.0}"
JAR="$SDK/platforms/${PLATAFORMA:-android-34}/android.jar"
APKSIGNER="${APKSIGNER:-$(command -v apksigner || echo "$BT/apksigner")}"

VERSAO_CODIGO=2
VERSAO_NOME="1.1"
MIN_SDK=28
TARGET_SDK=28
KS="$AQUI/assinatura.keystore"
KS_ALIAS="pfl7560tema"
KS_SENHA="pfl7560tema"
SAIDA="$AQUI/apk"

SOBREPOSICOES="zysetting:PFL7560TemaZYSetting::3 nlprovision:PFL7560TemaNLProvision
  zybluetooth:PFL7560TemaZYBluetooth zyfilemanager:PFL7560TemaZYFileManager::3 tvsettings:PFL7560TemaTvSettings
  higallery:PFL7560TemaHiGallery:1 nlsource:PFL7560TemaNLSource powerservice:PFL7560TemaPowerService
  autofocus:PFL7560TemaAutoFocus zyspeakermodel:PFL7560TemaZYSpeakerModel newlinkservice:PFL7560TemaNewLinkService
  ijkplayer:PFL7560TemaIjkPlayer hivideoplayer:PFL7560TemaHiVideoPlayer:1:3 himusic:PFL7560TemaHiMusic:1
  hipinyinime:PFL7560TemaHiPinyinIME nlhotkeyservice:PFL7560TemaNLHotkeyService zycustomui:PFL7560TemaZYCustomUI::3
  hitvsetting:PFL7560TemaHiTvSetting packageinstaller:PFL7560TemaPackageInstaller
  android:PFL7560TemaAndroid::4"

for f in "$BT/aapt2" "$BT/zipalign" "$JAR" "$KS" "$APKSIGNER"; do
  [ -e "$f" ] || { echo "FALTA: $f" >&2; exit 1; }
done

B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT
mkdir -p "$SAIDA"

for par in $SOBREPOSICOES; do
  IFS=: read -r dir nome min versao <<< "$par"
  min="${min:-$MIN_SDK}"
  versao="${versao:-$VERSAO_CODIGO}"
  echo ">> $nome ($dir, versionCode $versao)"
  if grep -rEn --exclude-dir='layout*' '"@(\+?id|color|drawable|style|dimen|string|layout|mipmap|android:)' "$AQUI/$dir/res"; then
    echo "ERRO: referencia a recurso em $dir/res (so valores literais)" >&2; exit 1
  fi
  molde=()
  if [ -f "$AQUI/$dir/alvo-ids.txt" ]; then
    M="$B/$dir-molde"
    alvo="$(python3 -I "$AQUI/molde-alvo.py" --gerar "$AQUI/$dir" "$M")"
    "$BT/aapt2" compile --dir "$M/res" -o "$M/res.zip"
    "$BT/aapt2" link -o "$M/molde.apk" -I "$JAR" --manifest "$M/AndroidManifest.xml" \
      --stable-ids "$M/ids.txt" "$M/res.zip"
    molde=(-I "$M/molde.apk" --stable-ids "$M/ids.txt" --rename-resources-package "$alvo")
    echo "   layout: molde com os ids de $alvo"
  elif [ -n "$(find "$AQUI/$dir/res" -maxdepth 1 -name 'layout*' -print -quit)" ]; then
    echo "ERRO: $dir tem layout e nao tem alvo-ids.txt (rode o molde-alvo.py)" >&2; exit 1
  fi
  "$BT/aapt2" compile --dir "$AQUI/$dir/res" -o "$B/$dir.zip"
  "$BT/aapt2" link -o "$B/$dir.apk" -I "$JAR" ${molde[@]+"${molde[@]}"} \
    --manifest "$AQUI/$dir/AndroidManifest.xml" \
    --min-sdk-version "$min" --target-sdk-version "$TARGET_SDK" \
    --version-code "$versao" --version-name "$VERSAO_NOME" \
    --no-auto-version "$B/$dir.zip"
  "$BT/zipalign" -f -p 4 "$B/$dir.apk" "$B/$dir-alinhado.apk"
  "$APKSIGNER" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" --ks-pass "pass:$KS_SENHA" \
    --out "$SAIDA/$nome.apk" "$B/$dir-alinhado.apk"
  "$APKSIGNER" verify --verbose "$SAIDA/$nome.apk" | grep -E '^Verified|^Verifies'
  rm -f "$SAIDA/$nome.apk.idsig"
  echo "   $SAIDA/$nome.apk md5 $(md5sum "$SAIDA/$nome.apk" | cut -d' ' -f1)"
done
echo ">> pronto. Confira contra os alvos do firmware:  python3 -I artifacts/overlay/conferir.py <pasta com os APKs alvo>"
