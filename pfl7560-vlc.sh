#!/usr/bin/env bash
# pfl7560-vlc.sh - instala o VLC para Android 3.7.1 como app do sistema em /vendor/app/VLC (bloco 14).
# Fica FORA do pendrive e do git: o APK tem 47 MB (mais ~44 MB de bibliotecas nativas) e e do
# VideoLAN. O script baixa do site oficial e so instala o que passar em TODAS as conferencias:
#   1. o sha256 do arquivo baixado = o sha256 PUBLICADO pelo VideoLAN (get.videolan.org/.../*.sha256)
#      = o sha256 fixado aqui (VLC_SHA256);
#   2. a assinatura do APK (apksigner, v2/v3) confere e o certificado e o do VideoLAN (SHA-256 fixado
#      aqui: VLC_CERT_SHA256);
#   3. o APK traz as bibliotecas lib/armeabi-v7a/*.so.
# Depois: conecta por adb (Wi-Fi), vira root, confere que e um PFL7560 com ABI armeabi-v7a e que ha
# espaco no /vendor; abre o /vendor rw; grava /vendor/app/VLC/VLC.apk e as .so em
# /vendor/app/VLC/lib/arm/ (cada arquivo como .new, conferido por md5 no aparelho e so entao movido;
# pastas 0755, arquivos 0644, root, rotulo vendor_app_file); fecha o /vendor e reinicia (o
# PackageManager so varre o /vendor/app no boot; o pm install deste firmware recusa app de fora).
# Idempotente: se tudo ja esta la igual, nada e gravado e nada reinicia.
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-vlc.sh [--sem-reiniciar]
#   PFL_IP=<ip> ./pfl7560-vlc.sh --remover [--sem-reiniciar]     apaga /vendor/app/VLC e reinicia
#   ./pfl7560-vlc.sh --ajuda
# O que baixa fica em backups-projetor/vlc/ (fora do git; PFL_CACHE muda a pasta).
# Precisa de: adb, curl, unzip, apksigner (build-tools do Android SDK) ou keytool, sha256sum, md5sum.
set -uo pipefail
export LC_ALL=C

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="${PFL_CACHE:-$HERE/backups-projetor/vlc}"
VERSAO=3.7.1
ARQ="VLC-Android-$VERSAO-armeabi-v7a.apk"
URL_BASE="https://get.videolan.org/vlc-android/$VERSAO"
# fixados: o sha256 do APK armeabi-v7a 3.7.1 (47073346 bytes) e o SHA-256 do certificado do VideoLAN
# (CN=Jean-Baptiste Kempf, O=VideoLAN Mobile, L=Paris, C=FR), lidos em 2026-10-31
VLC_SHA256="a6a7f940e4bd190c9a70f3f0dc97c1c402c10200af20edac7a1d452b24abd8a0"
VLC_CERT_SHA256="c8768d2cea0c4b622e419b4b4715981946821e4ebc035fb41776cad395a7f68e"
# so o harness (tests/test-pc-marca-vlc.sh) muda a origem e os fixados, e so com PFL_TESTE=1
if [ "${PFL_TESTE:-}" = "1" ]; then
  URL_BASE="${PFL_VLC_URL_BASE:-$URL_BASE}"
  VLC_SHA256="${PFL_VLC_SHA256:-$VLC_SHA256}"
  VLC_CERT_SHA256="${PFL_VLC_CERT_SHA256:-$VLC_CERT_SHA256}"
fi
DEST=/vendor/app/VLC
ROTULO=u:object_r:vendor_app_file:s0
TMPDEV=/data/local/tmp
MODO=instalar
REINICIAR=1

X='\033[1;31m'; V='\033[1;32m'; C='\033[1;36m'; Z='\033[0m'
err(){ printf "${X}[ERRO]${Z}  %s\n" "$*" >&2; }
ok(){  printf "${V}[OK]${Z}    %s\n" "$*" >&2; }
say(){ printf "${C}>> %s${Z}\n" "$*" >&2; }
ajuda(){ sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --remover) MODO=remover; shift ;;
    --sem-reiniciar) REINICIAR=0; shift ;;
    --ajuda|-h|--help) ajuda; exit 0 ;;
    *) err "argumento desconhecido: $1 (veja --ajuda)"; exit 2 ;;
  esac
done

TMP="$(mktemp -d)"
D=""
RELOCK=0
volta_ro(){ [ "$RELOCK" = 1 ] && [ -n "$D" ] && "$ADB" -s "$D" shell "mount -o ro,remount /vendor" >/dev/null 2>&1; RELOCK=0; return 0; }
limpa_dev(){ [ -n "$D" ] && "$ADB" -s "$D" shell "rm -rf $TMPDEV/pfl-vlc" >/dev/null 2>&1; return 0; }
trap 'volta_ro; limpa_dev; rm -rf "$TMP"' EXIT

sh_dev(){ "$ADB" -s "$D" shell "$@" 2>/dev/null | tr -d '\r'; }
md5_local(){ md5sum "$1" | cut -d' ' -f1; }
md5_dev(){ sh_dev "md5sum '$1' 2>/dev/null" | cut -d' ' -f1; }

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

abre_vendor(){
  sh_dev "mount -o rw,remount /vendor" >/dev/null
  RELOCK=1
  # o remount "funciona" em silencio se nao gravou: prova de escrita
  if [ "$(sh_dev "touch /vendor/app/.pfl-teste-rw && echo sim; rm -f /vendor/app/.pfl-teste-rw")" != "sim" ]; then
    err "nao consegui abrir o /vendor para escrita - nada foi gravado"; exit 1
  fi
}

# ---------------------------------------------------------------- instalar
baixa_e_confere(){
  mkdir -p "$CACHE" || { err "nao consegui criar $CACHE"; exit 1; }
  local pub
  if [ ! -s "$CACHE/$ARQ" ] || [ "$(sha256sum "$CACHE/$ARQ" | cut -d' ' -f1)" != "$VLC_SHA256" ]; then
    say "baixando $URL_BASE/$ARQ (47 MB)"
    rm -f "$CACHE/$ARQ.parcial"
    curl -fL --retry 3 -o "$CACHE/$ARQ.parcial" "$URL_BASE/$ARQ" 2>"$TMP/curl.err" \
      || { rm -f "$CACHE/$ARQ.parcial"; err "download falhou: $(tail -1 "$TMP/curl.err")"; exit 1; }
    mv "$CACHE/$ARQ.parcial" "$CACHE/$ARQ"
  else
    say "usando o APK ja baixado em $CACHE/$ARQ"
  fi
  pub="$(curl -fsL --retry 3 "$URL_BASE/$ARQ.sha256" 2>/dev/null | tr -d '\r' | head -1 | cut -d' ' -f1)"
  if [ -z "$pub" ]; then err "nao consegui ler o sha256 publicado em $URL_BASE/$ARQ.sha256 - nada foi instalado"; exit 1; fi
  APK_SHA="$(sha256sum "$CACHE/$ARQ" | cut -d' ' -f1)"
  if [ "$APK_SHA" != "$pub" ]; then err "sha256 do arquivo baixado ($APK_SHA) difere do publicado pelo VideoLAN ($pub) - apagado, nada foi instalado"; rm -f "$CACHE/$ARQ"; exit 1; fi
  if [ "$APK_SHA" != "$VLC_SHA256" ]; then err "sha256 ($APK_SHA) difere do fixado neste script ($VLC_SHA256) - apagado, nada foi instalado"; rm -f "$CACHE/$ARQ"; exit 1; fi
  ok "sha256 confere (arquivo = publicado = fixado): $APK_SHA"
}

confere_assinatura(){
  local cert="" ap
  ap="$(command -v apksigner || true)"
  # shellcheck disable=SC2012  # nomes sem espaco; o ls so acha o apksigner do SDK local
  [ -n "$ap" ] || ap="$(ls "${ANDROID_SDK:-$HOME/Android/sdk}"/build-tools/*/apksigner 2>/dev/null | tail -1)"
  if [ -n "$ap" ]; then
    "$ap" verify --print-certs "$CACHE/$ARQ" >"$TMP/assin.txt" 2>&1 \
      || { err "apksigner recusou a assinatura de $ARQ - nada foi instalado"; exit 1; }
    cert="$(sed -n 's/^Signer #1 certificate SHA-256 digest: *//p' "$TMP/assin.txt" | head -1 | tr -d ' :' | tr 'A-F' 'a-f')"
  elif command -v keytool >/dev/null 2>&1; then
    cert="$(keytool -printcert -jarfile "$CACHE/$ARQ" 2>/dev/null | sed -n 's/^ *SHA256: *//p' | head -1 | tr -d ' :' | tr 'A-F' 'a-f')"
  else
    err "sem apksigner nem keytool: nao consigo conferir a assinatura - nada foi instalado"; exit 1
  fi
  if [ -z "$cert" ] || [ "$cert" != "$VLC_CERT_SHA256" ]; then
    err "certificado do APK ('${cert:-vazio}') nao e o do VideoLAN ($VLC_CERT_SHA256) - nada foi instalado"; exit 1
  fi
  ok "assinatura confere; certificado do VideoLAN ($cert)"
}

extrai_libs(){
  mkdir -p "$TMP/x"
  unzip -o -q "$CACHE/$ARQ" 'lib/armeabi-v7a/*.so' -d "$TMP/x" 2>/dev/null
  # shellcheck disable=SC2012  # nomes de .so sem espaco
  LIBS="$(cd "$TMP/x/lib/armeabi-v7a" 2>/dev/null && ls ./*.so 2>/dev/null | sed 's|^\./||')"
  [ -n "$LIBS" ] || { err "o APK nao traz lib/armeabi-v7a/*.so - nada foi instalado"; exit 1; }
  ok "bibliotecas armeabi-v7a no APK: $(echo "$LIBS" | wc -l | tr -d ' ') ($(echo "$LIBS" | tr '\n' ' '))"
}

# 0 = tudo la e igual
ja_instalado(){
  [ "$(md5_dev "$DEST/VLC.apk")" = "$(md5_local "$CACHE/$ARQ")" ] || return 1
  local l
  for l in $LIBS; do
    [ "$(md5_dev "$DEST/lib/arm/$l")" = "$(md5_local "$TMP/x/lib/armeabi-v7a/$l")" ] || return 1
  done
  return 0
}

confere_espaco(){
  local precisa=0 l livre
  precisa=$(( $(wc -c < "$CACHE/$ARQ") ))
  for l in $LIBS; do precisa=$(( precisa + $(wc -c < "$TMP/x/lib/armeabi-v7a/$l") )); done
  livre="$(sh_dev "df -k /vendor | tail -1" | awk '{ for (i = NF; i > 0; i--) if ($i ~ /^[0-9]+$/) { print $i; exit } }')"   # a ultima coluna numerica e a "Available""
  if [ -z "$livre" ]; then say "[AVISO] nao consegui ler o espaco livre do /vendor (df) - sigo; a conferencia por md5 pega uma gravacao truncada"; return 0; fi
  if [ $(( livre * 1024 )) -lt $(( precisa + precisa / 10 )) ]; then
    err "o /vendor tem $livre KB livres e a instalacao pede cerca de $(( precisa / 1024 )) KB - nada foi gravado"; exit 1
  fi
  ok "espaco no /vendor: $livre KB livres para cerca de $(( precisa / 1024 )) KB"
}

grava_arquivo(){ # $1 = origem local, $2 = destino no aparelho
  local m
  m="$(md5_local "$1")"
  "$ADB" -s "$D" push "$1" "$2.new" >/dev/null 2>&1
  if [ "$(md5_dev "$2.new")" != "$m" ]; then sh_dev "rm -f '$2.new'" >/dev/null; err "$2: o md5 no aparelho nao confere - nada foi movido para o lugar"; exit 1; fi
  sh_dev "chmod 644 '$2.new' && chown root:root '$2.new' && chcon $ROTULO '$2.new'; mv -f '$2.new' '$2'" >/dev/null
  if [ "$(md5_dev "$2")" != "$m" ]; then err "$2 nao confere depois do mv"; exit 1; fi
}

instalar(){
  baixa_e_confere
  confere_assinatura
  extrai_libs
  conecta
  local abi l
  abi="$(sh_dev "getprop ro.product.cpu.abilist" | tr -d '\n ')"
  case "$abi" in
    "") say "[AVISO] ro.product.cpu.abilist vazio: sigo, mas o VLC aqui e o armeabi-v7a" ;;
    *armeabi-v7a*) ;;
    *) err "o aparelho nao lista armeabi-v7a (abilist '$abi') - nada foi feito"; exit 2 ;;
  esac
  if ja_instalado; then ok "o VLC $VERSAO ja esta em $DEST, igual ao baixado - nada a fazer"; return 0; fi
  abre_vendor
  confere_espaco
  say "gravando em $DEST"
  sh_dev "mkdir -p $DEST/lib/arm && chmod 755 $DEST $DEST/lib $DEST/lib/arm && chown root:root $DEST $DEST/lib $DEST/lib/arm && chcon $ROTULO $DEST $DEST/lib $DEST/lib/arm" >/dev/null
  grava_arquivo "$CACHE/$ARQ" "$DEST/VLC.apk"
  for l in $LIBS; do grava_arquivo "$TMP/x/lib/armeabi-v7a/$l" "$DEST/lib/arm/$l"; done
  sh_dev "sync" >/dev/null
  ja_instalado || { err "a conferencia final por md5 falhou"; exit 1; }
  ok "VLC $VERSAO gravado e conferido por md5 em $DEST ($(echo "$LIBS" | wc -l | tr -d ' ') bibliotecas)"
  volta_ro
  reinicia
  say "depois de reiniciar: adb shell pm list packages org.videolan.vlc deve listar o pacote"
}

remover(){
  conecta
  if [ "$(sh_dev "[ -e $DEST ] && echo sim")" != "sim" ]; then ok "$DEST nao existe - nada a remover"; return 0; fi
  abre_vendor
  sh_dev "rm -rf $DEST; sync" >/dev/null
  if [ "$(sh_dev "[ -e $DEST ] && echo sim")" = "sim" ]; then err "nao consegui apagar $DEST"; exit 1; fi
  ok "$DEST removido"
  volta_ro
  reinicia
}

reinicia(){
  if [ "$REINICIAR" = 1 ]; then say "reiniciando o projetor (o PackageManager varre o /vendor/app no boot)"; "$ADB" -s "$D" reboot >/dev/null 2>&1; else say "sem reiniciar: o VLC so vale depois do proximo boot"; fi
}

case "$MODO" in
  instalar) instalar ;;
  remover) remover ;;
esac
