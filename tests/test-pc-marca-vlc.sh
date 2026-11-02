#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2012,SC2034
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export LC_ALL=C
MARCA="$ROOT/pfl7560-marca.sh"
VLC="$ROOT/pfl7560-vlc.sh"
TAM=41943040
FALHAS=0; TESTES=0; CASO="-"
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }
TMP="$(mktemp -d)"
trap 'chmod -R u+rwx "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

novo_cenario(){
  CASO="$1"
  T="$(mktemp -d "$TMP/c.XXXXXX")"
  mkdir -p "$T/bin" "$T/fakebin" "$T/dtmp" "$T/vendor/app" "$T/cwd"
  : > "$T/adb.log"
  cat > "$T/bin/adb" <<'EOF'
#!/bin/bash
echo "adb $*" >> "$T/adb.log"
mapeia(){ sed -e "s#/dev/block/by-name/logo#$T/dev-logo#g" -e "s#/data/local/tmp#$T/dtmp#g" -e "s#/vendor/#$T/vendor/#g"; }
[ "$1" = connect ] && { echo "connected to $2"; exit 0; }
if [ "$1" = -s ]; then shift 2; fi
case "$1" in
  wait-for-device|root) exit 0 ;;
  reboot) exit 0 ;;
  push)
    dst="$(echo "$3" | mapeia)"
    if [ -f "$T/flag-push-corrompe" ]; then head -c 10 "$2" > "$dst"; else cp "$2" "$dst"; fi
    exit 0 ;;
  shell|exec-out)
    modo="$1"; shift
    cmd="$*"
    if [ "$modo" = shell ] && [ "$cmd" = id ]; then echo "uid=0(root) gid=0(root)"; exit 0; fi
    mapped="$(echo "$cmd" | mapeia)"
    if [ "$modo" = exec-out ] && [ -f "$T/flag-backup-curto" ]; then PATH="$T/fakebin:$PATH" sh -c "$mapped" | head -c 1000; exit 0; fi
    PATH="$T/fakebin:$PATH" sh -c "$mapped"
    exit $? ;;
esac
exit 1
EOF
  chmod +x "$T/bin/adb"
  printf '#!/bin/sh\nawk -v k="$1" '"'"'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }'"'"' "$T/props"\n' > "$T/fakebin/getprop"
  printf '#!/bin/sh\necho "blockdev $*" >> "$T/adb.log"; [ "$1" = --getsize64 ] && wc -c < "$T/dev-logo"\n' > "$T/fakebin/blockdev"
  printf '#!/bin/sh\necho "Filesystem 1K-blocks Used Available Use%% Mounted on"\necho "/dev/block/dm-1 300000 100000 ${LIVRE:-$(cat "$T/livre" 2>/dev/null || echo 150000)} 40%% /vendor"\n' > "$T/fakebin/df"
  printf '#!/bin/sh\necho "mount $*" >> "$T/adb.log"\n' > "$T/fakebin/mount"
  printf '#!/bin/sh\ncase "$*" in *of=*) exec /bin/dd "$@" conv=notrunc ;; *) exec /bin/dd "$@" ;; esac\n' > "$T/fakebin/dd"
  printf '#!/bin/sh\nexit 0\n' > "$T/fakebin/chown"
  printf '#!/bin/sh\necho "chcon $*" >> "$T/adb.log"\nexit 0\n' > "$T/fakebin/chcon"
  printf '#!/bin/sh\nif [ -f "$T/flag-sync-corrompe" ] && [ -f "$T/dev-logo" ]; then printf "Z" | dd of="$T/dev-logo" bs=1 seek=20000 conv=notrunc 2>/dev/null; rm -f "$T/flag-sync-corrompe"; fi\nexit 0\n' > "$T/fakebin/sync"
  chmod +x "$T"/fakebin/*
  cat > "$T/props" <<'EOF'
ro.product.model=PFL7560
ro.product.cpu.abilist=armeabi-v7a,armeabi
persist.sys.keystone.lt=95,915
persist.sys.keystone.rt=1715,1030
persist.sys.keystone.lb=40,25
persist.sys.keystone.rb=1775,35
EOF
  export T
}
cria_particao(){
  python3 -I - "$T/dev-logo" "$TAM" <<'PY'
import struct, sys, random
arq, tam = sys.argv[1], int(sys.argv[2])
random.seed(14)
d = bytearray(tam)
d[0:4] = b"###\0"; struct.pack_into("<I", d, 4, 0x7c)
d[8:18] = b"LOGO_TABLE"
struct.pack_into("<I", d, 0x28, 0x50)
d[0x2c:0x2c + 13] = b"LOGO_KEY_FLAG"
struct.pack_into("<I", d, 0x4c, 4); struct.pack_into("<I", d, 0x50, 1)
d[0x54:0x54 + 12] = b"LOGO_KEY_LEN"
struct.pack_into("<I", d, 0x74, 4)
jn = 61192
struct.pack_into("<I", d, 0x78, jn)
d[8192:8192 + jn] = b"\xff\xd8" + bytes(random.getrandbits(8) for _ in range(jn - 4)) + b"\xff\xd9"
d[8192 + jn:8192 + jn + 200000] = bytes(random.getrandbits(8) for _ in range(200000))
open(arq, "wb").write(d)
PY
}
roda(){ ( cd "$T/cwd" && env T="$T" PATH="$T/bin:$PATH" "$@" ) ; }
adb_cmds(){ grep -c "$1" "$T/adb.log" 2>/dev/null || true; }

echo "== pfl7560-marca.sh =="
MARCA_MD5S="$(cd "$ROOT/artifacts/tema/marca" && md5sum ./* | md5sum)"
GERADO="$TMP/gerado"; mkdir -p "$GERADO"
PFL_MARCA_SAIDA="$GERADO" python3 -I "$ROOT/artifacts/tema/gerar-marca.py" "95,915" "1715,1030" "40,25" "1775,35" >/dev/null 2>&1
JPEG_ESP="$GERADO/logo-boot.jpg"

novo_cenario "marca: grava"
cria_particao
ORIG_MD5="$(md5 "$T/dev-logo")"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >"$T/out" 2>"$T/err"; RC=$?
afirma '[ "$RC" = 0 ]' "rc=$RC: $(tail -3 "$T/err" | tr '\n' ' ')"
BKF="$(ls "$T"/bk/logo-*.img 2>/dev/null | head -1)"
afirma '[ -n "$BKF" ] && [ "$(wc -c < "$BKF" | tr -d " ")" = "$TAM" ] && [ "$(md5 "$BKF")" = "$ORIG_MD5" ]' "backup ausente, de tamanho errado ou diferente da particao original"
afirma 'python3 -I - "$T/dev-logo" "$BKF" "$JPEG_ESP" <<PY
import struct, sys
novo = open(sys.argv[1], "rb").read(); velho = open(sys.argv[2], "rb").read(); j = open(sys.argv[3], "rb").read()
assert len(novo) == len(velho)
assert novo[8192:8192 + len(j)] == j, "JPEG novo fora do lugar"
assert struct.unpack_from("<I", novo, 0x78)[0] == len(j), "LOGO_KEY_LEN nao e o tamanho do JPEG"
assert novo[:0x78] == velho[:0x78] and novo[0x7c:8192] == velho[0x7c:8192], "cabecalho mexido"
assert novo[8192 + len(j):] == velho[8192 + len(j):], "dados depois do JPEG mexidos"
PY' "a particao nao ficou como o esperado (so o JPEG no 8192 e o LOGO_KEY_LEN)"
afirma 'grep -q "particao relida e conferida" "$T/err" && grep -q -- "--restaurar" "$T/err"' "sem a conferencia final ou a dica de restaurar"
afirma '[ "$(grep -n "exec-out dd if=/dev/block/by-name/logo" "$T/adb.log" | head -1 | cut -d: -f1)" -lt "$(grep -n "of=/dev/block/by-name/logo" "$T/adb.log" | head -1 | cut -d: -f1)" ]' "gravou antes do backup"
afirma '! grep -q "conv=" "$T/adb.log"' "dd com conv (o toybox recusa)"
afirma '[ "$(grep -c "of=/dev/block/by-name/logo" "$T/adb.log")" = 2 ] && grep -q "of=/dev/block/by-name/logo bs=4096 seek=2" "$T/adb.log" && grep -q "of=/dev/block/by-name/logo bs=1 seek=120" "$T/adb.log"' "esperava dois dd na particao (JPEG no byte 8192 e LOGO_KEY_LEN no 120): $(grep of= "$T/adb.log")"
afirma '! grep -iE "hidebug|gtt|setprop|reboot|settings put" "$T/adb.log"' "comando que nao devia: $(grep -iE 'hidebug|gtt|setprop|reboot' "$T/adb.log" | head -2)"
afirma '[ "$(cd "$ROOT/artifacts/tema/marca" && md5sum ./* | md5sum)" = "$MARCA_MD5S" ]' "os arquivos versionados de artifacts/tema/marca mudaram"
afirma '[ -z "$(ls "$T"/dtmp)" ]' "sobrou arquivo temporario no aparelho: $(ls "$T"/dtmp | tr '\n' ' ')"

CASO="marca: restaurar"
roda env PFL_IP=10.0.0.9 bash "$MARCA" --restaurar "$BKF" --sim >"$T/out" 2>"$T/err"; RC=$?
afirma '[ "$RC" = 0 ] && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ]' "rc=$RC; particao nao voltou ao original: $(tail -2 "$T/err" | tr '\n' ' ')"
afirma '[ -z "$(ls "$T"/dtmp)" ]' "sobrou temporario depois de restaurar"
rm -rf "$T"

novo_cenario "marca: outro modelo"; cria_particao; ORIG_MD5="$(md5 "$T/dev-logo")"
sed -i 's/^ro.product.model=.*/ro.product.model=OUTRO/' "$T/props"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 2 ] && grep -q "NAO e um PFL7560" "$T/err" && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ] && ! grep -q "of=" "$T/adb.log"' "rc=$RC"

novo_cenario "marca: falta um canto"; cria_particao; ORIG_MD5="$(md5 "$T/dev-logo")"
sed -i '/keystone.rb/d' "$T/props"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "persist.sys.keystone.rb" "$T/err" && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ] && [ ! -d "$T/bk" ]' "rc=$RC; $(tail -2 "$T/err" | tr '\n' ' ')"

novo_cenario "marca: particao de tamanho inesperado"; cria_particao; head -c 1000000 "$T/dev-logo" > "$T/curto"; mv "$T/curto" "$T/dev-logo"; ORIG_MD5="$(md5 "$T/dev-logo")"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "esperado $TAM" "$T/err" && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ] && ! grep -q "of=" "$T/adb.log"' "rc=$RC; $(tail -2 "$T/err" | tr '\n' ' ')"

novo_cenario "marca: cabecalho nao reconhecido"; cria_particao; printf 'XXXX' | dd of="$T/dev-logo" bs=1 seek=8 conv=notrunc 2>/dev/null; ORIG_MD5="$(md5 "$T/dev-logo")"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "LOGO_TABLE nao reconhecido" "$T/err" && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ] && ! grep -q "of=/dev/block" "$T/adb.log"' "rc=$RC; $(tail -2 "$T/err" | tr '\n' ' ')"

novo_cenario "marca: backup curto"; cria_particao; ORIG_MD5="$(md5 "$T/dev-logo")"; : > "$T/flag-backup-curto"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "backup veio com tamanho errado" "$T/err" && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ] && [ -z "$(ls "$T"/bk 2>/dev/null)" ]' "rc=$RC; $(tail -2 "$T/err" | tr '\n' ' ')"

novo_cenario "marca: arquivo corrompido no push"; cria_particao; ORIG_MD5="$(md5 "$T/dev-logo")"; : > "$T/flag-push-corrompe"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "no aparelho nao confere" "$T/err" && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ] && ! grep -q "of=/dev/block" "$T/adb.log"' "rc=$RC; $(tail -2 "$T/err" | tr '\n' ' ')"

novo_cenario "marca: a releitura nao confere"; cria_particao; : > "$T/flag-sync-corrompe"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "releitura NAO confere" "$T/err" && grep -q -- "--restaurar" "$T/err"' "rc=$RC; $(tail -2 "$T/err" | tr '\n' ' ')"

novo_cenario "marca: sem --sim e sem terminal"; cria_particao; ORIG_MD5="$(md5 "$T/dev-logo")"
roda env PFL_IP=10.0.0.9 PFL_BACKUPS="$T/bk" bash "$MARCA" </dev/null >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 2 ] && grep -q "use --sim" "$T/err" && [ "$(md5 "$T/dev-logo")" = "$ORIG_MD5" ] && ! grep -q "of=/dev/block" "$T/adb.log"' "rc=$RC; $(tail -2 "$T/err" | tr '\n' ' ')"

novo_cenario "marca: sem PFL_IP e argumentos ruins"
roda env bash "$MARCA" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 2 ] && grep -q "PFL_IP" "$T/err"' "sem PFL_IP: rc=$RC"
roda env bash "$MARCA" --nada >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 2 ]' "argumento desconhecido: rc=$RC"
roda env PFL_IP=10.0.0.9 bash "$MARCA" --restaurar "$T/nao-existe.img" --sim >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 2 ]' "restaurar arquivo inexistente: rc=$RC"
echo lixo > "$T/lixo.img"
roda env PFL_IP=10.0.0.9 bash "$MARCA" --restaurar "$T/lixo.img" --sim >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 2 ] && grep -q "nao parece o backup" "$T/err"' "restaurar lixo: rc=$RC"

echo "== pfl7560-vlc.sh =="
cria_apk(){
  local f="$T/fix"; mkdir -p "$f/zip/lib/armeabi-v7a" "$f/zip/lib/arm64-v8a"
  head -c 3000 /dev/urandom > "$f/zip/lib/armeabi-v7a/libvlc.so"; head -c 700 /dev/urandom > "$f/zip/lib/armeabi-v7a/libvlcjni.so"
  head -c 900 /dev/urandom > "$f/zip/lib/arm64-v8a/libvlc.so"; echo manifesto > "$f/zip/AndroidManifest.xml"
  ( cd "$f/zip" && python3 -I -c "
import zipfile, sys
with zipfile.ZipFile('../VLC-Android-3.7.1-armeabi-v7a.apk', 'w') as z:
    for n in ['AndroidManifest.xml', 'lib/armeabi-v7a/libvlc.so', 'lib/armeabi-v7a/libvlcjni.so', 'lib/arm64-v8a/libvlc.so']: z.write(n)
" )
  SHA="$(sha256sum "$f/VLC-Android-3.7.1-armeabi-v7a.apk" | cut -d' ' -f1)"
  echo "$SHA *VLC-Android-3.7.1-armeabi-v7a.apk" > "$f/VLC-Android-3.7.1-armeabi-v7a.apk.sha256"
  CERT="aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899"
  printf '#!/bin/sh\nif [ -f "$T/flag-assin-ruim" ]; then echo "DOES NOT VERIFY" >&2; exit 1; fi\necho "Verifies"\necho "Signer #1 certificate DN: CN=teste"\necho "Signer #1 certificate SHA-256 digest: ${CERT_FALSO:-%s}"\n' "$CERT" > "$T/bin/apksigner"
  chmod +x "$T/bin/apksigner"
}
roda_vlc(){ roda env PFL_TESTE=1 PFL_IP=10.0.0.9 PFL_CACHE="$T/cache" PFL_VLC_URL_BASE="file://$T/fix" PFL_VLC_SHA256="$SHA" PFL_VLC_CERT_SHA256="$CERT" "$@" bash "$VLC" "${ARGS[@]}"; }

novo_cenario "vlc: instala"; cria_apk; ARGS=()
roda_vlc >"$T/out" 2>"$T/err"; RC=$?
afirma '[ "$RC" = 0 ]' "rc=$RC: $(tail -3 "$T/err" | tr '\n' ' ')"
afirma 'cmp -s "$T/fix/VLC-Android-3.7.1-armeabi-v7a.apk" "$T/vendor/app/VLC/VLC.apk" && cmp -s "$T/fix/zip/lib/armeabi-v7a/libvlc.so" "$T/vendor/app/VLC/lib/arm/libvlc.so" && cmp -s "$T/fix/zip/lib/armeabi-v7a/libvlcjni.so" "$T/vendor/app/VLC/lib/arm/libvlcjni.so"' "apk ou bibliotecas diferentes: $(ls -lR "$T/vendor/app/VLC" 2>&1 | tr '\n' '|')"
afirma '[ ! -e "$T/vendor/app/VLC/lib/arm/libvlc.so.new" ] && [ -z "$(find "$T/vendor" -name "*.new")" ] && [ ! -e "$T/vendor/app/VLC/lib/arm64-v8a" ]' "sobrou .new ou levou a ABI errada"
afirma 'ls -l "$T/vendor/app/VLC/VLC.apk" | grep -q "^-rw-r--r--" && ls -ld "$T/vendor/app/VLC" "$T/vendor/app/VLC/lib/arm" | grep -c "^drwxr-xr-x" | grep -qx 2' "modo errado"
afirma 'grep -q "chcon u:object_r:vendor_app_file:s0" "$T/adb.log" && grep -q "mount -o rw,remount /vendor" "$T/adb.log" && grep -q "mount -o ro,remount /vendor" "$T/adb.log"' "sem chcon ou sem o remount rw/ro"
afirma '[ "$(adb_cmds "^adb -s 10.0.0.9:5555 reboot")" = 1 ]' "esperava um reboot: $(grep reboot "$T/adb.log")"
afirma '[ -z "$(ls "$T"/dtmp)" ] && ! grep -iE "hidebug|gtt|setprop" "$T/adb.log"' "temporario ou comando que nao devia"
: > "$T/adb.log"
roda_vlc >"$T/out" 2>"$T/err"; RC=$?
afirma '[ "$RC" = 0 ] && grep -q "ja esta em" "$T/err" && [ "$(adb_cmds " push ")" = 0 ] && [ "$(adb_cmds "rw,remount")" = 0 ] && [ "$(adb_cmds reboot)" = 0 ]' "2a execucao mexeu: rc=$RC $(grep -E 'push|remount|reboot' "$T/adb.log" | head -3)"
rm -rf "$T/vendor/app/VLC"; : > "$T/adb.log"; ARGS=(--sem-reiniciar)
roda_vlc >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 0 ] && [ -f "$T/vendor/app/VLC/VLC.apk" ] && [ "$(adb_cmds reboot)" = 0 ]' "--sem-reiniciar: rc=$RC"
: > "$T/adb.log"; ARGS=(--remover)
roda_vlc >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 0 ] && [ ! -e "$T/vendor/app/VLC" ] && [ "$(adb_cmds reboot)" = 1 ] && grep -q "mount -o ro,remount /vendor" "$T/adb.log"' "--remover: rc=$RC"
: > "$T/adb.log"
roda_vlc >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 0 ] && grep -q "nada a remover" "$T/err" && [ "$(adb_cmds reboot)" = 0 ] && [ "$(adb_cmds "rw,remount")" = 0 ]' "--remover sem nada: rc=$RC"

recusa_vlc(){
  ESP_MSG="$1"; ESP_RC="$2"
  roda_vlc >"$T/out" 2>"$T/err"; RC=$?
  afirma '[ "$RC" = "$ESP_RC" ] && grep -q "$ESP_MSG" "$T/err"' "rc=$RC (esperado $ESP_RC), mensagem '$(tail -1 "$T/err")'"
  afirma '[ ! -e "$T/vendor/app/VLC" ] && [ "$(adb_cmds " push ")" = 0 ] && [ "$(adb_cmds reboot)" = 0 ]' "gravou ou reiniciou apesar da recusa"
}
novo_cenario "vlc: sha256 publicado difere do arquivo"; cria_apk; ARGS=()
echo "0000000000000000000000000000000000000000000000000000000000000000 *x" > "$T/fix/VLC-Android-3.7.1-armeabi-v7a.apk.sha256"
recusa_vlc "difere do publicado" 1
afirma '[ ! -e "$T/cache/VLC-Android-3.7.1-armeabi-v7a.apk" ]' "deixou no cache o arquivo recusado"
novo_cenario "vlc: sha256 fixado difere"; cria_apk; ARGS=(); SHA_REAL="$SHA"; SHA="1111111111111111111111111111111111111111111111111111111111111111"
echo "$SHA_REAL *x" > "$T/fix/VLC-Android-3.7.1-armeabi-v7a.apk.sha256"
recusa_vlc "difere do fixado" 1
novo_cenario "vlc: assinatura recusada"; cria_apk; ARGS=(); : > "$T/flag-assin-ruim"
recusa_vlc "apksigner recusou" 1
novo_cenario "vlc: certificado de outro"; cria_apk; ARGS=()
roda_vlc CERT_FALSO=deadbeef >"$T/out" 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "nao e o do VideoLAN" "$T/err" && [ ! -e "$T/vendor/app/VLC" ]' "rc=$RC"
novo_cenario "vlc: APK sem as bibliotecas armeabi-v7a"; cria_apk; ARGS=()
( cd "$T/fix/zip" && python3 -I -c "
import zipfile
with zipfile.ZipFile('../VLC-Android-3.7.1-armeabi-v7a.apk', 'w') as z: z.write('AndroidManifest.xml')
" )
SHA="$(sha256sum "$T/fix/VLC-Android-3.7.1-armeabi-v7a.apk" | cut -d' ' -f1)"; echo "$SHA *x" > "$T/fix/VLC-Android-3.7.1-armeabi-v7a.apk.sha256"
recusa_vlc "nao traz lib/armeabi-v7a" 1
novo_cenario "vlc: outro modelo"; cria_apk; ARGS=(); sed -i 's/^ro.product.model=.*/ro.product.model=OUTRO/' "$T/props"
recusa_vlc "NAO e um PFL7560" 2
novo_cenario "vlc: aparelho sem armeabi-v7a"; cria_apk; ARGS=(); sed -i 's/^ro.product.cpu.abilist=.*/ro.product.cpu.abilist=arm64-v8a/' "$T/props"
recusa_vlc "nao lista armeabi-v7a" 2
novo_cenario "vlc: sem espaco no /vendor"; cria_apk; ARGS=(); echo 0 > "$T/livre"
recusa_vlc "livres" 1
novo_cenario "vlc: arquivo corrompido no push"; cria_apk; ARGS=(); : > "$T/flag-push-corrompe"
roda_vlc >"$T/out" 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "md5 no aparelho nao confere" "$T/err" && [ ! -e "$T/vendor/app/VLC/VLC.apk" ] && grep -q "mount -o ro,remount /vendor" "$T/adb.log"' "rc=$RC; /vendor nao fechou ou o apk foi movido: $(tail -1 "$T/err")"
if [ "$(id -u)" != 0 ]; then
  novo_cenario "vlc: /vendor que nao abre para escrita"; cria_apk; ARGS=(); chmod 555 "$T/vendor/app"
  recusa_vlc "nao consegui abrir o /vendor" 1
  chmod 755 "$T/vendor/app"
fi
novo_cenario "vlc: sem PFL_TESTE as variaveis de teste sao ignoradas (URL e sha oficiais)"; cria_apk
printf '#!/bin/sh\necho "curl $*" >> "$T/adb.log"\nexit 22\n' > "$T/bin/curl"; chmod +x "$T/bin/curl"
roda env PFL_IP=10.0.0.9 PFL_CACHE="$T/cache" PFL_VLC_URL_BASE="file://$T/fix" PFL_VLC_SHA256="$SHA" bash "$VLC" >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "https://get.videolan.org/vlc-android/3.7.1/VLC-Android-3.7.1-armeabi-v7a.apk" "$T/adb.log" && ! grep -q "file://" "$T/adb.log"' "rc=$RC; $(grep curl "$T/adb.log" | head -2)"
rm -f "$T/bin/curl"
afirma 'grep -q "^VLC_SHA256=\"a6a7f940e4bd190c9a70f3f0dc97c1c402c10200af20edac7a1d452b24abd8a0\"" "$VLC" && grep -q "^VLC_CERT_SHA256=\"c8768d2cea0c4b622e419b4b4715981946821e4ebc035fb41776cad395a7f68e\"" "$VLC"' "os valores fixados do spec mudaram"
roda env bash "$VLC" --nada >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 2 ]' "argumento desconhecido: rc=$RC"
roda env PFL_TESTE=1 PFL_CACHE="$T/cache" PFL_VLC_URL_BASE="file://$T/fix" PFL_VLC_SHA256="$SHA" PFL_VLC_CERT_SHA256="$CERT" bash "$VLC" >/dev/null 2>"$T/err"; RC=$?
afirma '[ "$RC" = 2 ] && grep -q "PFL_IP" "$T/err"' "sem PFL_IP: rc=$RC"

CASO="estaticos"
for f in "$MARCA" "$VLC"; do
  afirma 'bash -n "$f"' "bash -n $(basename "$f")"
  afirma '[ -x "$f" ]' "$(basename "$f") sem +x"
  afirma 'head -1 "$f" | grep -qx "#!/usr/bin/env bash"' "shebang de $(basename "$f")"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -E "(shell|exec-out)[^#]*(hidebug|gtt|setprop|settings put)"' "$(basename "$f") manda hidebug/gtt/setprop ao aparelho"
  afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$f")" ]' "$(basename "$f") tem byte fora de ASCII"
  if command -v shellcheck >/dev/null 2>&1; then afirma 'shellcheck "$f"' "shellcheck $(basename "$f")"; fi
done
if command -v shellcheck >/dev/null 2>&1; then afirma 'shellcheck "$ROOT/tests/test-pc-marca-vlc.sh"' "shellcheck do harness"; else echo "  (shellcheck ausente: etapa pulada)"; fi
afirma 'python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$ROOT/artifacts/tema/gerar-marca.py"' "gerar-marca.py nao compila"

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
