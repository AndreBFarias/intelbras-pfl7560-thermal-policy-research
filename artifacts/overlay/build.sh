#!/usr/bin/env bash
# artifacts/overlay/build.sh - monta as sobreposicoes (RRO) Dracula dos blocos 13A, 16A, 17A e 18, do zero, sem Gradle.
#
#   bash artifacts/overlay/build.sh
#
# Uma sobreposicao por pacote alvo, so recursos (sem classes.dex):
#   zysetting     -> com.zhiying.settings          PFL7560TemaZYSetting.apk
#   nlprovision   -> com.newlink.nlprovision       PFL7560TemaNLProvision.apk
#   zybluetooth   -> com.example.bluetoothsetting  PFL7560TemaZYBluetooth.apk     (16A)
#   zyfilemanager -> com.newlink.filemanager       PFL7560TemaZYFileManager.apk   (16A)
#   tvsettings    -> com.android.tv.settings       PFL7560TemaTvSettings.apk      (16A)
#   higallery     -> com.hisilicon.higallery       PFL7560TemaHiGallery.apk       (16A)
#   nlsource      -> com.newlink.nlsource          PFL7560TemaNLSource.apk        (16A)
#   powerservice  -> com.zhiying.powerservice      PFL7560TemaPowerService.apk    (16A)
#   autofocus     -> com.zhiying.autofocus         PFL7560TemaAutoFocus.apk       (17A)
#   zyspeakermodel -> com.zhiying.bluetoothmodelservice PFL7560TemaZYSpeakerModel.apk (17A)
#   newlinkservice -> com.newlink.service          PFL7560TemaNewLinkService.apk  (17A)
#   ijkplayer     -> com.newlink.isuperred.ijkplayerdemo PFL7560TemaIjkPlayer.apk (17A)
#   hivideoplayer -> com.hisilicon.android.videoplayer PFL7560TemaHiVideoPlayer.apk (17A)
#   himusic       -> com.hisilicon.android.music   PFL7560TemaHiMusic.apk         (17A)
#   hipinyinime   -> com.hisilicon.android.inputmethod.remote PFL7560TemaHiPinyinIME.apk (18)
#   nlhotkeyservice -> com.newlink.hotkeysservices PFL7560TemaNLHotkeyService.apk (18)
#   zycustomui    -> com.zhiying.sourceui          PFL7560TemaZYCustomUI.apk      (18)
#   hitvsetting   -> com.hisilicon.tvsetting       PFL7560TemaHiTvSetting.apk     (18)
#   packageinstaller -> com.android.packageinstaller PFL7560TemaPackageInstaller.apk (18)
#   android       -> android (framework)           PFL7560TemaAndroid.apk   (por ultimo; ver doc 48)
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

VERSAO_CODIGO=2          # inteiro; sobe a cada APK novo (2: bloco 16A). Por sobreposicao: 4o campo abaixo
VERSAO_NOME="1.1"
MIN_SDK=28
TARGET_SDK=28
KS="$AQUI/assinatura.keystore"
KS_ALIAS="pfl7560tema"
KS_SENHA="pfl7560tema"   # nao e segredo (ver acima)
SAIDA="$AQUI/apk"

# pasta -> nome do APK (o mesmo nome vira a pasta em /vendor/overlay/<Nome>/<Nome>.apk)[:minSdk].
# O minSdk opcional existe por causa da galeria: com --min-sdk-version 28 o aapt2 funde as
# configuracoes com versao <= 28 na padrao (drawable-v21 -> drawable, hdpi-v4 -> hdpi), e o alvo
# (compilado com aapt antigo) tem justamente hdpi-v4 e v21. A sobreposicao precisa da MESMA
# configuracao do alvo, senao a do alvo ganha (conferir.py, item 3). minSdk 1 desliga a fusao.
# 17A: o mesmo vale para os players HiSilicon (drawable-nodpi-v4, drawable-hdpi-v4).
# Bloco 18: um 4o campo opcional da o versionCode daquela sobreposicao (pasta:Nome:minSdk:versao;
# minSdk vazio = o padrao). So a do android usa (3: ganhou cores no bloco 18); as outras continuam
# com VERSAO_CODIGO e saem com o mesmo md5 de antes.
SOBREPOSICOES="zysetting:PFL7560TemaZYSetting nlprovision:PFL7560TemaNLProvision
  zybluetooth:PFL7560TemaZYBluetooth zyfilemanager:PFL7560TemaZYFileManager tvsettings:PFL7560TemaTvSettings
  higallery:PFL7560TemaHiGallery:1 nlsource:PFL7560TemaNLSource powerservice:PFL7560TemaPowerService
  autofocus:PFL7560TemaAutoFocus zyspeakermodel:PFL7560TemaZYSpeakerModel newlinkservice:PFL7560TemaNewLinkService
  ijkplayer:PFL7560TemaIjkPlayer hivideoplayer:PFL7560TemaHiVideoPlayer:1 himusic:PFL7560TemaHiMusic:1
  hipinyinime:PFL7560TemaHiPinyinIME nlhotkeyservice:PFL7560TemaNLHotkeyService zycustomui:PFL7560TemaZYCustomUI
  hitvsetting:PFL7560TemaHiTvSetting packageinstaller:PFL7560TemaPackageInstaller
  android:PFL7560TemaAndroid::3"

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
  # nenhuma referencia a recurso dentro da sobreposicao (ver o cabecalho)
  if grep -rEn '"@(\+?id|color|drawable|style|dimen|string|layout|mipmap|android:)' "$AQUI/$dir/res"; then
    echo "ERRO: referencia a recurso em $dir/res (so valores literais)" >&2; exit 1
  fi
  "$BT/aapt2" compile --dir "$AQUI/$dir/res" -o "$B/$dir.zip"
  "$BT/aapt2" link -o "$B/$dir.apk" -I "$JAR" --manifest "$AQUI/$dir/AndroidManifest.xml" \
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
