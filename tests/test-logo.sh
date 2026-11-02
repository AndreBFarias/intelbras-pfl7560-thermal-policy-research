#!/usr/bin/env bash
# Bloco 25: logo automatico do boot.
#   1. nl_logo (artifacts/logo/nl_logo.c) compilado no host: a distorcao e a do gerar-marca.py
#      (pixel a pixel na saida crua, diferenca media pequena no JPEG), as recusas de cantos e as
#      conferencias do LOGO_TABLE / montagem da particao.
#   2. suite-logo.sh sob dash numa raiz falsa: adota, grava (com os backups e a releitura),
#      recusa, devolve a particao quando a releitura nao confere, chave e resgate do pendrive.
# shellcheck disable=SC2016,SC2034,SC2012
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
ARTE="$ROOT/artifacts/tema/marca/logo.jpg"
GERAR="$ROOT/artifacts/tema/gerar-marca.py"
TAM=41943040
export LC_ALL=C
FALHAS=0; TESTES=0; CASO="-"
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

NLH="$TMP/nl_logo"
echo "== nl_logo no host =="
CASO="compila"
cc -O2 -Wall -Wextra -ffp-contract=off -o "$NLH" "$ROOT/artifacts/logo/nl_logo.c" -lm 2>"$TMP/cc.err" \
  || { cat "$TMP/cc.err"; echo "FALHA: nl_logo.c nao compilou no host"; exit 1; }
afirma '[ ! -s "$TMP/cc.err" ]' "avisos do compilador: $(head -3 "$TMP/cc.err")"

CASO="binario do kit"
afirma 'file "$ROOT/artifacts/logo/nl_logo" | grep -q "ELF 32-bit LSB.*ARM.*/system/bin/linker"' "artifacts/logo/nl_logo nao e um ELF ARM do Android"
afirma 'cmp -s "$ROOT/artifacts/logo/nl_logo" "$KIT/nl_logo"' "pendrive-autorun/nl_logo difere de artifacts/logo/nl_logo"
NDK_CC="${NDK_CC:-$HOME/Android/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang}"
if [ -x "$NDK_CC" ]; then
  ( cd "$ROOT" && "$NDK_CC" -O2 -Wall -ffp-contract=off -o "$TMP/nl_logo.arm" artifacts/logo/nl_logo.c -lm ) 2>"$TMP/ndk.err"
  afirma 'cmp -s "$TMP/nl_logo.arm" "$ROOT/artifacts/logo/nl_logo"' "artifacts/logo/nl_logo nao e o binario deste nl_logo.c (recompile como no README): $(head -3 "$TMP/ndk.err")"
else
  echo "  (NDK ausente: reprodutibilidade do ARM nao conferida)"
fi
afirma '[ "$(md5 "$KIT/marca/logo.jpg")" = "$(md5 "$ARTE")" ] && grep -q "^ARTE_MD5=\"$(md5 "$ARTE")\"$" "$KIT/suite-logo.sh" && grep -q "^NL_LOGO_MD5=\"$(md5 "$KIT/nl_logo")\"$" "$KIT/suite-logo.sh"' "md5 do nl_logo ou da arte fora do LOGO_MD5 do suite-logo.sh"

RETO="0,1080 1920,1080 0,0 1920,0"
DONO="95,915 1715,1030 40,25 1775,35"
VELHO="45,930 1715,1015 10,15 1755,20"
TORTO="300,1000 1700,1080 0,0 1920,200"
TORTO2="10,1070 1900,1050 100,30 1850,5"

CASO="cantos"
cantos_rc(){ "$NLH" cantos "$@" >"$TMP/c.out" 2>/dev/null; echo "$?:$(head -1 "$TMP/c.out")"; }
for c in "$RETO" "$DONO" "$VELHO" "$TORTO" "$TORTO2"; do
  # shellcheck disable=SC2086
  afirma '[ "$(cantos_rc $c)" = "0:ok" ]' "cantos validos recusados: $c ($(cantos_rc $c))"
done
while IFS='|' read -r esp c; do
  # shellcheck disable=SC2086
  afirma '[ "$(cantos_rc $c)" = "3:$esp" ]' "cantos '$c': esperado 3:$esp, veio $(cantos_rc $c)"
done <<'FIM'
fora_da_tela|0,1080 1921,1080 0,0 1920,0
fora_da_tela|0,1081 1920,1080 0,0 1920,0
nao_convexo|1920,1080 0,1080 0,0 1920,0
nao_convexo|0,1080 1920,1080 1920,0 0,0
nao_convexo|0,1080 1920,1080 0,0 900,600
canto_trocado|0,1080 1920,1080 1000,0 1920,0
area_pequena|700,700 1200,700 700,400 1200,400
formato|0,1080 1920,1080 0,0 1920
formato|0,1080 1920,1080 0,0 a,0
formato|0,1080 1920,1080 0,0 -1,0
formato|0,1080 1920,1080 0,0 12345,0
FIM
afirma '"$NLH" cantos 0,0 >/dev/null 2>&1; [ $? = 2 ]' "cantos com argumentos faltando nao deu uso (2)"

CASO="distorcao igual a do gerar-marca.py"
if python3 -I -c "import PIL" 2>/dev/null; then
  python3 -I - "$GERAR" "$ARTE" "$NLH" "$TMP/px" "$RETO" "$DONO" "$VELHO" "$TORTO" "$TORTO2" >"$TMP/px.out" 2>&1 <<'PY'
import importlib.util, io, os, subprocess, sys
from PIL import Image
gerar, arte, nl, pasta = sys.argv[1:5]
os.makedirs(pasta, exist_ok=True)
spec = importlib.util.spec_from_file_location("gm", gerar)
gm = importlib.util.module_from_spec(spec); spec.loader.exec_module(gm)
im = Image.open(arte).convert("RGB")
entrada = os.path.join(pasta, "in.ppm"); im.save(entrada)
for i, c in enumerate(sys.argv[5:]):
    cantos = c.split()
    sai = os.path.join(pasta, "s%d" % i)
    subprocess.run([nl, "gerar", entrada, *cantos, sai + ".ppm"], check=True)
    subprocess.run([nl, "gerar", arte, *cantos, sai + ".jpg"], check=True)
    ref = gm.distorcida(im, tuple(cantos))
    a = Image.open(sai + ".ppm").tobytes(); b = ref.tobytes()
    cru = sum(1 for x, y in zip(a, b) if x != y) if len(a) == len(b) else -1
    jn = Image.open(sai + ".jpg")
    jr = Image.open(io.BytesIO(gm.jpeg(ref)))
    from PIL import JpegImagePlugin
    amostra = JpegImagePlugin.get_sampling(jn)
    pa = jn.convert("RGB").tobytes(); pb = jr.convert("RGB").tobytes()
    d = [abs(x - y) for x, y in zip(pa, pb)]
    media = sum(d) / len(d)
    print("%d cru=%d media=%.4f max=%d amostra=%d tam=%d dim=%dx%d" % (i, cru, media, max(d), amostra, os.path.getsize(sai + ".jpg"), jn.size[0], jn.size[1]))
PY
  afirma '[ "$(grep -c "cru=0 " "$TMP/px.out")" = 5 ]' "a saida crua do nl_logo difere da do gerar-marca.py (Pillow): $(tr '\n' '|' < "$TMP/px.out")"
  afirma '[ "$(awk "{split(\$3,m,\"=\"); split(\$4,x,\"=\"); if (m[2] < 0.5 && x[2] <= 64) n++} END {print n+0}" "$TMP/px.out")" = 5 ]' "JPEG do nl_logo longe do gerar-marca.py (media >= 0.5 ou max > 64): $(tr '\n' '|' < "$TMP/px.out")"
  afirma '[ "$(grep -c "amostra=0 .*dim=1920x1080" "$TMP/px.out")" = 5 ]' "JPEG do nl_logo nao e 4:4:4 1920x1080: $(tr '\n' '|' < "$TMP/px.out")"
  afirma 'cmp -s "$TMP/px/s0.jpg" "$ARTE"' "cantos retos nao devolvem a arte byte a byte"
  echo "  $(tr '\n' ' ' < "$TMP/px.out")"
else
  falha "sem Pillow (python3 -I -c 'import PIL'): o teste contra o gerar-marca.py nao rodou"
fi
afirma '"$NLH" gerar "$ARTE" 1921,1080 1920,1080 0,0 1920,0 "$TMP/x.jpg" >/dev/null 2>&1; [ $? = 3 ] && [ ! -e "$TMP/x.jpg" ]' "gerar com canto fora da tela nao recusou (3) ou deixou arquivo"
head -c 5000 "$ARTE" > "$TMP/cortada.jpg"
# shellcheck disable=SC2086
afirma '! "$NLH" gerar "$TMP/cortada.jpg" $DONO "$TMP/y.jpg" >/dev/null 2>&1 && [ ! -e "$TMP/y.jpg" ]' "gerar com a arte cortada nao falhou ou deixou arquivo"

CASO="particao"
cria_particao(){
  python3 -I - "$1" "$TAM" "$ARTE" <<'PY'
import struct, sys, random
arq, tam, arte = sys.argv[1], int(sys.argv[2]), sys.argv[3]
random.seed(25)
d = bytearray(tam)
d[0:4] = b"###\0"; struct.pack_into("<I", d, 4, 0x7c)
d[8:18] = b"LOGO_TABLE"
struct.pack_into("<I", d, 0x28, 0x50)
d[0x2c:0x2c + 13] = b"LOGO_KEY_FLAG"
struct.pack_into("<I", d, 0x4c, 4); struct.pack_into("<I", d, 0x50, 1)
d[0x54:0x54 + 12] = b"LOGO_KEY_LEN"
struct.pack_into("<I", d, 0x74, 4)
j = open(arte, "rb").read()
struct.pack_into("<I", d, 0x78, len(j))
d[8192:8192 + len(j)] = j
d[8192 + len(j):8192 + len(j) + 300000] = bytes(random.getrandbits(8) for _ in range(300000))
open(arq, "wb").write(d)
PY
}
P="$TMP/part.img"; cria_particao "$P"
JN=$(wc -c < "$ARTE" | tr -d ' ')
afirma '[ "$("$NLH" cabecalho "$P")" = "$JN" ]' "cabecalho nao leu o LOGO_KEY_LEN ($JN)"
afirma '"$NLH" extrair "$P" "$TMP/ext.jpg" && cmp -s "$TMP/ext.jpg" "$ARTE"' "extrair nao devolveu o JPEG gravado"
muta(){ cp "$P" "$TMP/m.img"; python3 -I -c "import sys; f=open(sys.argv[1],'r+b'); f.seek(int(sys.argv[2])); f.write(bytes.fromhex(sys.argv[3]))" "$TMP/m.img" "$1" "$2"; }
while IFS='|' read -r pos hex nome; do
  muta "$pos" "$hex"
  afirma '! "$NLH" cabecalho "$TMP/m.img" >/dev/null 2>&1' "cabecalho aceitou a particao com $nome"
done <<FIM
9|58|LOGO_TABLE trocado
84|00|LOGO_KEY_LEN apagado
120|00000000|LOGO_KEY_LEN zero
120|ffff7f00|LOGO_KEY_LEN maior que a particao
120|$(printf '%08x' $(( JN - 1 )) | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')|LOGO_KEY_LEN um byte curto (sem FFD9 no fim)
200|01|lixo entre o cabecalho e o 8192
8192|0000|JPEG sem FFD8
FIM
head -c $(( TAM - 1 )) "$P" > "$TMP/curta.img"
afirma '! "$NLH" cabecalho "$TMP/curta.img" >/dev/null 2>&1' "cabecalho aceitou particao de tamanho errado"
# shellcheck disable=SC2086
"$NLH" gerar "$ARTE" $DONO "$TMP/novo.jpg" >/dev/null 2>&1
afirma '"$NLH" montar "$P" "$TMP/novo.jpg" "$TMP/mont.img" "$TMP/k.bin" >/dev/null 2>&1' "montar falhou"
afirma 'python3 -I - "$TMP/mont.img" "$P" "$TMP/novo.jpg" "$TMP/k.bin" <<PY
import struct, sys
novo = open(sys.argv[1], "rb").read(); velho = open(sys.argv[2], "rb").read(); j = open(sys.argv[3], "rb").read(); k = open(sys.argv[4], "rb").read()
assert len(novo) == len(velho)
assert novo[8192:8192 + len(j)] == j
assert struct.unpack_from("<I", novo, 0x78)[0] == len(j) and k == struct.pack("<I", len(j))
assert novo[:0x78] == velho[:0x78] and novo[0x7c:8192] == velho[0x7c:8192]
assert novo[8192 + len(j):] == velho[8192 + len(j):]
PY' "a imagem montada nao e a de fora com so o JPEG no 8192 e o LOGO_KEY_LEN trocados"
afirma '[ "$("$NLH" cabecalho "$TMP/mont.img")" = "$(wc -c < "$TMP/novo.jpg" | tr -d " ")" ]' "a imagem montada nao passa no cabecalho com o tamanho do JPEG novo"
for bk in "$ROOT"/backups-projetor/logo/logo-*.img; do
  [ -f "$bk" ] || continue
  afirma '"$NLH" cabecalho "$bk" >/dev/null' "o backup real ${bk##*/} nao passa no cabecalho"
done

echo "== suite-logo.sh sob dash =="
stub(){ printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
novo_cenario(){
  CASO="$1"
  T="$(mktemp -d "$TMP/c.XXXXXX")"
  R="$T/root"; S="$R/data/vendor/pfl7560-suite"; L="$R/data/vendor/pfl7560-logo"; PART="$R/dev/block/by-name/logo"
  PEDH="$R/data/data/com.pfl7560.home"; MP="$R/mnt/media_rw/USB1"
  mkdir -p "$T/bin" "$R/dev/block/by-name" "$R/mnt/media_rw" "$R/data/vendor" "$S/marca" "$PEDH"
  chmod 700 "$S" "$S/marca"
  cp "$KIT/suite-logo.sh" "$KIT/suite-pedido.sh" "$S/"; cp "$ARTE" "$S/marca/logo.jpg"
  cp "$NLH" "$S/nl_logo.host"
  cp "$P" "$PART"; cp "$P" "$T/original.img"
  : > "$T/calls.log"
  cat > "$T/props" <<FIM
ro.product.model=PFL7560
persist.sys.keystone.lt=0,1080
persist.sys.keystone.rt=1920,1080
persist.sys.keystone.lb=0,0
persist.sys.keystone.rb=1920,0
FIM
  stub getprop 'awk -v k="$1" '"'"'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }'"'"' "$T/props"'
  stub setprop 'echo "setprop $1 ${2:-}" >> "$T/calls.log"
awk -v k="$1" '"'"'index($0, k "=") != 1'"'"' "$T/props" > "$T/props.novo"
printf "%s=%s\n" "$1" "${2:-}" >> "$T/props.novo"; mv "$T/props.novo" "$T/props"'
  stub blockdev 'echo "blockdev $*" >> "$T/calls.log"; [ -f "$T/tam-errado" ] && { echo 1234; exit 0; }; [ "$1" = --getsize64 ] && wc -c < "$2"'
  stub dd 'echo "dd $*" >> "$T/calls.log"
case "$*" in *of=*ultimo.img.novo*) [ -f "$T/backup-curto" ] && { head -c 1000 "$PART" > "$L/ultimo.img.novo"; exit 0; } ;; esac
case "$*" in *of=*) exec /bin/dd "$@" conv=notrunc ;; *) exec /bin/dd "$@" ;; esac'
  stub sync 'echo "sync" >> "$T/calls.log"
if [ -f "$T/sync-corrompe" ]; then printf "Z" | /bin/dd of="$PART" bs=1 seek=20000 conv=notrunc 2>/dev/null; [ -f "$T/sync-sempre" ] || rm -f "$T/sync-corrompe"; fi
exit 0'
  stub sleep 'exit 0'
  export T PART L
}
amb(){ env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_RAPIDO=1 PFL_ROOT="$R" PFL_NLLOGO="${NL_TESTE:-$S/nl_logo.host}" PFL_NLLOGO_MD5="${NL_MD5_TESTE:-$(md5 "$S/nl_logo.host")}" PFL_APP_UID_MIN=0 PATH="$T/bin:$PATH" "$@"; }
roda_logo(){ amb dash "$S/suite-logo.sh" "$@" > "$T/out" 2>&1; RC=$?; }
novo_boot(){ rmdir "$R/dev/pfl7560-logo.boot" 2>/dev/null; }
prop_de(){ awk -v k="vendor.pfl7560.$1" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' "$T/props"; }
cantos(){ local k; for k in lt rt lb rb; do awk -v k="persist.sys.keystone.$k" 'index($0, k "=") != 1' "$T/props" > "$T/p" && mv "$T/p" "$T/props"; done
  printf 'persist.sys.keystone.lt=%s\npersist.sys.keystone.rt=%s\npersist.sys.keystone.lb=%s\npersist.sys.keystone.rb=%s\n' "$1" "$2" "$3" "$4" >> "$T/props"; }
escritas(){ grep -c "^dd .*of=$PART" "$T/calls.log" || true; }
log(){ cat "$L/logo.log" 2>/dev/null; }
intacta(){ cmp -s "$PART" "$T/original.img"; }
modo(){ stat -c %a "$1" 2>/dev/null; }
so_jpeg_e_keylen(){
  python3 -I - "$PART" "$T/original.img" "$1" <<'PY'
import struct, sys
novo = open(sys.argv[1], "rb").read(); velho = open(sys.argv[2], "rb").read(); j = open(sys.argv[3], "rb").read()
assert len(novo) == len(velho) == 41943040
assert novo[8192:8192 + len(j)] == j
assert struct.unpack_from("<I", novo, 0x78)[0] == len(j)
assert novo[:0x78] == velho[:0x78] and novo[0x7c:8192] == velho[0x7c:8192]
assert novo[8192 + len(j):] == velho[8192 + len(j):]
PY
}
limpa(){ if [ -n "${DEBUG_KEEP:-}" ]; then echo "  (mantido: $T)"; else rm -rf "$T"; fi; }

novo_cenario "cantos retos e a arte reta na particao = adota, nao escreve nada"
roda_logo boot
afirma '[ "$RC" = 0 ] && [ "$(escritas)" = 0 ] && intacta' "escreveu com os cantos retos: $(grep '^dd' "$T/calls.log" | tr '\n' '|')"
afirma '[ "$(cat "$L/cantos")" = "$RETO" ] && [ "$(cat "$L/jpeg-md5")" = "$(md5 "$ARTE")" ] && [ ! -e "$L/motivo" ]' "nao registrou a adocao: $(ls "$L")"
afirma '[ "$(prop_de logo)" = ligado ] && [ "$(prop_de logo_cantos)" = "$RETO" ] && [ -z "$(prop_de logo_motivo)" ]' "props: logo='$(prop_de logo)' cantos='$(prop_de logo_cantos)'"
afirma '[ "$(modo "$L")" = 700 ] && [ "$(modo "$L/cantos")" = 600 ] && [ ! -e "$L/ultimo.img" ] && [ ! -e "$L/trabalho" ]' "pasta do logo: modo $(modo "$L"), $(ls "$L" | tr '\n' ' ')"
limpa

novo_cenario "cantos mudaram = backup, grava so o JPEG no 8192 e o LOGO_KEY_LEN, rele e confere"
# shellcheck disable=SC2086
cantos $DONO
# shellcheck disable=SC2086
"$NLH" gerar "$ARTE" $DONO "$T/esperado.jpg" >/dev/null 2>&1
roda_logo boot
afirma '[ "$RC" = 0 ] && so_jpeg_e_keylen "$T/esperado.jpg"' "a particao nao ficou com o JPEG dos cantos e o LOGO_KEY_LEN: $(tail -3 "$L/logo.log" | tr '\n' '|')"
afirma 'cmp -s "$L/ultimo.img" "$T/original.img" && cmp -s "$L/primeiro.img" "$T/original.img" && [ "$(modo "$L/ultimo.img")" = 600 ] && [ "$(modo "$L/primeiro.img")" = 600 ]' "backups errados: $(ls -l "$L" | tr '\n' '|')"
afirma '[ "$(grep -n "of=$L/ultimo.img.novo" "$T/calls.log" | head -1 | cut -d: -f1)" -lt "$(grep -n "of=$PART" "$T/calls.log" | head -1 | cut -d: -f1)" ]' "gravou antes do backup"
afirma '[ "$(escritas)" = 2 ] && grep -q "^dd if=.*novo.jpg of=$PART bs=4096 seek=2$" "$T/calls.log" && grep -q "^dd if=.*keylen.bin of=$PART bs=1 seek=120$" "$T/calls.log"' "o dd na particao nao e o do pfl7560-marca.sh: $(grep "of=$PART" "$T/calls.log" | tr '\n' '|')"
afirma '! grep -q "conv=" "$T/calls.log"' "dd com conv (o toybox recusa)"
afirma '[ "$(cat "$L/cantos")" = "$DONO" ] && [ "$(prop_de logo_cantos)" = "$DONO" ] && [ -n "$(prop_de logo_hora)" ] && [ -z "$(prop_de logo_motivo)" ] && grep -q "particao relida e conferida" "$L/logo.log"' "registro: cantos='$(cat "$L/cantos")' hora='$(prop_de logo_hora)' motivo='$(prop_de logo_motivo)'"
afirma '[ ! -e "$L/trabalho" ]' "a pasta de trabalho sobrou"
cp "$PART" "$T/depois1.img"
roda_logo boot
afirma '[ "$(escritas)" = 2 ] && grep -q "ja rodou neste boot" "$L/logo.log"' "rodou duas vezes no mesmo boot"
novo_boot; roda_logo boot
afirma '[ "$(escritas)" = 2 ] && grep -q "ja e o dos cantos atuais" "$L/logo.log"' "regravou com os mesmos cantos no boot seguinte"
novo_boot
# shellcheck disable=SC2086
cantos $TORTO
roda_logo boot
afirma '[ "$(escritas)" = 4 ] && cmp -s "$L/primeiro.img" "$T/original.img" && cmp -s "$L/ultimo.img" "$T/depois1.img" && [ "$(cat "$L/cantos")" = "$TORTO" ]' "segunda gravacao: o primeiro backup tem de ficar, o ultimo tem de ser o de antes desta"
novo_boot
# shellcheck disable=SC2086
cantos $RETO
roda_logo boot
afirma '[ "$(escritas)" = 6 ] && "$NLH" extrair "$PART" "$T/volta.jpg" >/dev/null && cmp -s "$T/volta.jpg" "$ARTE" && [ "$(cat "$L/cantos")" = "$RETO" ]' "voltar aos cantos retos nao devolveu a arte reta byte a byte"
limpa

novo_cenario "a particao ja tem o logo destes cantos sem registro = adota sem escrever"
# shellcheck disable=SC2086
cantos $DONO
# shellcheck disable=SC2086
"$NLH" gerar "$ARTE" $DONO "$T/esperado.jpg" >/dev/null 2>&1
"$NLH" montar "$PART" "$T/esperado.jpg" "$T/m.img" "$T/k.bin" >/dev/null 2>&1 && cp "$T/m.img" "$PART" && cp "$PART" "$T/original.img"
roda_logo boot
afirma '[ "$(escritas)" = 0 ] && intacta && [ "$(cat "$L/cantos")" = "$DONO" ] && grep -q "ja tem o logo destes cantos" "$L/logo.log"' "escreveu ou nao adotou: $(tail -2 "$L/logo.log" | tr '\n' '|')"
limpa

while IFS='|' read -r motivo c; do
  novo_cenario "cantos recusados ($motivo) = nao grava, registra o motivo"
  # shellcheck disable=SC2086
  cantos $c
  roda_logo boot
  afirma '[ "$(escritas)" = 0 ] && intacta && [ "$(cat "$L/motivo" 2>/dev/null)" = "$motivo" ] && [ "$(prop_de logo_motivo)" = "$motivo" ] && [ ! -e "$L/ultimo.img" ]' "cantos '$c': motivo='$(cat "$L/motivo" 2>/dev/null)' escritas=$(escritas)"
  afirma '[ "$(prop_de logo)" = ligado ] && [ ! -e "$L/trabalho" ]' "a recusa desligou a chave ou deixou a pasta de trabalho"
  limpa
done <<'FIM'
fora_da_tela|0,1080 1920,1080 0,0 1921,0
nao_convexo|1920,1080 0,1080 0,0 1920,0
canto_trocado|0,1080 1920,1080 1000,0 1920,0
area_pequena|700,700 1200,700 700,400 1200,400
formato|0,1080 1920,1080 0,0 abc
formato|0,1080 1920,1080 0,0 1920,0,5
FIM

while IFS='|' read -r motivo prep; do
  novo_cenario "conferencia antes de escrever falha ($motivo) = nao grava"
  # shellcheck disable=SC2086
  cantos $DONO
  NL_MD5_TESTE=""; NL_TESTE=""
  eval "$prep"
  roda_logo boot
  afirma '[ "$(escritas)" = 0 ] && intacta && [ "$(cat "$L/motivo" 2>/dev/null)" = "$motivo" ]' "$motivo: motivo='$(cat "$L/motivo" 2>/dev/null)' escritas=$(escritas) $(tail -2 "$L/logo.log" | tr '\n' '|')"
  NL_MD5_TESTE=""; NL_TESTE=""
  limpa
done <<'FIM'
programa|NL_MD5_TESTE=00000000000000000000000000000000
programa|NL_TESTE="$S/nao-existe"
arte|echo x >> "$S/marca/logo.jpg"
arte|rm "$S/marca/logo.jpg"
modelo|sed -i "s/^ro.product.model=.*/ro.product.model=PFL7000/" "$T/props"
particao|: > "$T/tam-errado"
cabecalho|printf X | /bin/dd of="$PART" bs=1 seek=9 conv=notrunc 2>/dev/null; cp "$PART" "$T/original.img"
suite_rodando|mkdir "$R/dev/pfl7560-suite.lock"
backup|: > "$T/backup-curto"
FIM

novo_cenario "releitura nao confere = devolve o backup, confere, desliga a chave"
# shellcheck disable=SC2086
cantos $DONO
: > "$T/sync-corrompe"
roda_logo boot
afirma 'intacta && [ "$(cat "$L/motivo")" = releitura_devolvido ] && [ -e "$L/desligado" ] && [ "$(prop_de logo)" = desligado ]' "nao devolveu: motivo='$(cat "$L/motivo" 2>/dev/null)' $(tail -3 "$L/logo.log" | tr '\n' '|')"
afirma 'grep -q "^dd if=$L/ultimo.img of=$PART bs=1048576$" "$T/calls.log"' "a devolucao nao foi o dd do backup inteiro"
novo_boot; rm -f "$T/sync-corrompe"; : > "$T/c0"; cp "$T/calls.log" "$T/c0"
roda_logo boot
afirma '[ "$(escritas)" = "$(grep -c "^dd .*of=$PART" "$T/c0")" ] && grep -q "chave desligada" "$L/logo.log"' "com a chave desligada pela falha, escreveu no boot seguinte"
limpa

novo_cenario "releitura e devolucao nao conferem = diz que restaure pelo PC, desliga a chave"
# shellcheck disable=SC2086
cantos $DONO
: > "$T/sync-corrompe"; : > "$T/sync-sempre"
roda_logo boot
afirma '[ "$(cat "$L/motivo")" = releitura_sem_volta ] && [ -e "$L/desligado" ] && cmp -s "$L/ultimo.img" "$T/original.img" && grep -q "restaure pelo PC" "$L/logo.log"' "motivo='$(cat "$L/motivo" 2>/dev/null)'"
limpa

novo_cenario "chave desligada pela home = nao grava; ligada de novo = grava no boot seguinte"
# shellcheck disable=SC2086
cantos $DONO
roda_logo chave desligado
afirma '[ -e "$L/desligado" ] && [ "$(prop_de logo)" = desligado ]' "a chave nao desligou"
roda_logo boot
afirma '[ "$(escritas)" = 0 ] && intacta' "gravou com a chave desligada"
roda_logo chave talvez
afirma '[ -e "$L/desligado" ] && grep -q "pedido de chave invalido" "$L/logo.log"' "pedido invalido mexeu na chave"
roda_logo chave ligado
afirma '[ ! -e "$L/desligado" ] && [ "$(prop_de logo)" = ligado ]' "a chave nao religou"
novo_boot; roda_logo boot
afirma '[ "$(escritas)" = 2 ] && [ "$(cat "$L/cantos")" = "$DONO" ]' "nao gravou depois de religar"
limpa

novo_cenario "DESLIGAR-LOGO-AUTO.txt no pendrive montado no boot = chave desligada, nada gravado"
# shellcheck disable=SC2086
cantos $DONO
mkdir -p "$MP"; : > "$MP/DESLIGAR-LOGO-AUTO.txt"
roda_logo boot
afirma '[ "$(escritas)" = 0 ] && intacta && [ -e "$L/desligado" ] && [ "$(cat "$L/motivo")" = pendrive ] && [ "$(prop_de logo_motivo)" = pendrive ]' "o arquivo de resgate nao desligou"
limpa

novo_cenario "pasta do logo aberta a outros ou link = nada feito"
mkdir -p "$L"; chmod 755 "$L"
# shellcheck disable=SC2086
cantos $DONO
roda_logo boot
afirma '[ "$RC" = 1 ] && [ "$(escritas)" = 0 ] && intacta && [ "$(prop_de logo)" = erro ]' "rodou com a pasta aberta: rc=$RC"
rm -rf "$L"; ln -s "$T" "$L"
roda_logo boot
afirma '[ "$RC" = 1 ] && [ "$(escritas)" = 0 ] && intacta' "rodou com a pasta sendo link: rc=$RC"
limpa

novo_cenario "registro adulterado (md5 nao bate com a particao) = gera e grava de novo, sem confiar no registro"
# shellcheck disable=SC2086
cantos $DONO
mkdir -p "$L"; chmod 700 "$L"
printf '%s\n' "$DONO" > "$L/cantos"; printf 'ffffffffffffffffffffffffffffffff\n' > "$L/jpeg-md5"
roda_logo boot
afirma '[ "$(escritas)" = 2 ] && grep -q "particao relida e conferida" "$L/logo.log"' "confiou num registro que nao bate com a particao"
limpa

novo_cenario "pedido logo-auto da home pelo suite-pedido.sh = chave mexida pelo suite-logo.sh conferido"
printf 'desligado\n' > "$PEDH/logo-auto"
LOGO_MD5_EMB=$(sed -n 's/^LOGO_MD5="\(.*\)"$/\1/p' "$S/suite-pedido.sh")
afirma '[ "$LOGO_MD5_EMB" = "$(md5 "$KIT/suite-logo.sh")" ]' "LOGO_MD5 do suite-pedido.sh nao e o do suite-logo.sh do kit"
amb dash "$S/suite-pedido.sh" w "$PEDH" logo-auto > "$T/out" 2>&1
afirma '[ -e "$L/desligado" ] && [ "$(prop_de logo)" = desligado ] && [ ! -e "$PEDH/logo-auto" ]' "o pedido da home nao desligou: $(tail -3 "$S/vigia.log" | tr '\n' '|')"
printf 'ligado' > "$PEDH/logo-auto"
amb dash "$S/suite-pedido.sh" w "$PEDH" logo-auto > "$T/out" 2>&1
afirma '[ ! -e "$L/desligado" ] && [ "$(prop_de logo)" = ligado ]' "o pedido da home nao religou"
printf 'rm -rf /' > "$PEDH/logo-auto"
amb dash "$S/suite-pedido.sh" w "$PEDH" logo-auto > "$T/out" 2>&1
afirma '[ ! -e "$L/desligado" ] && grep -q "pedido de logo-auto recusado" "$S/vigia.log"' "pedido invalido nao foi recusado"
echo "# x" >> "$S/suite-logo.sh"; printf 'desligado' > "$PEDH/logo-auto"
amb dash "$S/suite-pedido.sh" w "$PEDH" logo-auto > "$T/out" 2>&1
afirma '[ ! -e "$L/desligado" ] && grep -q "suite-logo.sh ausente, link, de outro dono ou com md5 diferente" "$S/vigia.log"' "rodou um suite-logo.sh adulterado"
limpa

CASO="estaticos"
afirma '! LC_ALL=C grep -nP "[^\x00-\x7F]" "$KIT/suite-logo.sh"' "suite-logo.sh com byte nao ASCII"
afirma '[ -z "$(grep -n "^[[:space:]]*#" "$KIT/suite-logo.sh" | grep -v "^1:#!/vendor/bin/sh$" | grep -v "# shellcheck " | grep -v "# LOGO_MD5_INICIO$" | grep -v "# LOGO_MD5_FIM$")" ]' "suite-logo.sh com comentario"
afirma '! grep -vE "^[[:space:]]*#" "$KIT/suite-logo.sh" | grep -qwE "gtt|stp|sfs|sbri|sbl|hidebug|logcat|reboot|settings|pm|svc|input"' "suite-logo.sh cita comando proibido"
afirma 'shellcheck -s sh "$KIT/suite-logo.sh"' "shellcheck no suite-logo.sh"
afirma '[ "$(grep -c "of=\"\$PART\"" "$KIT/suite-logo.sh")" = 3 ]' "o suite-logo.sh escreve na particao em mais lugares do que os 3 conhecidos (JPEG, LOGO_KEY_LEN, devolucao)"
afirma 'grep -q "^  PATH=\"/system/bin:/system/xbin:/vendor/bin:/vendor/xbin\"; export PATH$" "$KIT/suite-logo.sh"' "suite-logo.sh sem o PATH fixo"

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
