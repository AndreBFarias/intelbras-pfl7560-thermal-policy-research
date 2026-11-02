#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$ROOT/tests/fixtures/tela"
FONTES="$ROOT/pendrive-autorun/fontes"
SAIDA="$ROOT/tests/saida/telas"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
NT="$T/nl_tela"
FALHAS=0; TESTES=0
afirma(){ TESTES=$((TESTES+1)); if eval "$1"; then :; else FALHAS=$((FALHAS+1)); echo "  FALHA: $2  (cond: $1)"; fi; }
mkdir -p "$SAIDA" "$T/sem-sistema"
export NL_TELA_SISTEMA="$T/sem-sistema"

cc -O2 -Wall -Wextra -o "$NT" "$ROOT/artifacts/tela/nl_tela.c" -lm 2>"$T/cc.err" || { cat "$T/cc.err"; echo "FALHA: nao compilou no host"; exit 1; }
echo "nl_tela compilado no host (cc -O2 -Wall -Wextra)"
afirma '[ ! -s "$T/cc.err" ]' "a compilacao deu aviso: $(head -5 "$T/cc.err")"

cat > "$T/confere.py" <<'PY'
import sys, zlib, struct
def ler(p):
    d = open(p, 'rb').read()
    if d[:8] != b'\x89PNG\r\n\x1a\n': return None, 'sem assinatura PNG'
    i, idat, ihdr = 8, b'', None
    while i + 12 <= len(d):
        n, t = struct.unpack('>I4s', d[i:i + 8]); c = d[i + 8:i + 8 + n]
        if zlib.crc32(t + c) & 0xffffffff != struct.unpack('>I', d[i + 8 + n:i + 12 + n])[0]:
            return None, 'CRC errado no bloco ' + t.decode('ascii', 'replace')
        if t == b'IHDR': ihdr = struct.unpack('>IIBBBBB', c)
        if t == b'IDAT': idat += c
        i += 12 + n
    if ihdr != (1920, 1080, 8, 2, 0, 0, 0): return None, 'IHDR %r (esperado 1920x1080, 8 bits, RGB)' % (ihdr,)
    raw = zlib.decompress(idat)
    if len(raw) != 1080 * (1 + 1920 * 3): return None, 'dados com %d bytes' % len(raw)
    return raw, None
def linhas(raw, w=1920, h=1080, bpp=3):
    st = w * bpp; ant = bytearray(st)
    for y in range(h):
        f = raw[y * (st + 1)]; l = bytearray(raw[y * (st + 1) + 1:(y + 1) * (st + 1)])
        if f == 1:
            for x in range(bpp, st): l[x] = (l[x] + l[x - bpp]) & 255
        elif f == 2: l = bytearray((a + b) & 255 for a, b in zip(l, ant))
        elif f == 3:
            for x in range(st): l[x] = (l[x] + ((l[x - bpp] if x >= bpp else 0) + ant[x]) // 2) & 255
        elif f == 4:
            for x in range(st):
                a = l[x - bpp] if x >= bpp else 0; b = ant[x]; c = ant[x - bpp] if x >= bpp else 0
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                l[x] = (l[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        elif f != 0: raise ValueError('filtro %d' % f)
        yield y, l; ant = l
margens = sys.argv[1] == '--margens'
ruim = 0
for p in sys.argv[2:]:
    raw, erro = ler(p)
    if erro is None and margens:
        fundo = bytes((0x28, 0x2A, 0x36)); fora = []
        for y, l in linhas(raw):
            if y < 50 or y >= 1030:
                if l != fundo * 1920: fora.append('linha %d' % y)
            elif l[:330] != fundo * 110 or l[1810 * 3:] != fundo * 110:
                fora.append('linha %d (lado)' % y)
            if len(fora) > 3: break
        if fora: erro = 'pixel fora das margens: ' + ', '.join(fora[:3])
    if erro: ruim = 1; print('  %s: %s' % (p.rsplit('/', 1)[-1], erro))
sys.exit(ruim)
PY
confere(){ python3 -I "$T/confere.py" --margens "$@"; }
gera(){
  "$NT" "$1" "$2" "$3" "${4:-$FONTES}" 2>"$T/err"; _rc=$?
}

for f in "$FIX"/*.txt; do
  nome=$(basename "$f" .txt); modo=${nome%%-*}
  gera "$modo" "$f" "$SAIDA/$nome.png"
  afirma '[ "$_rc" = 0 ]' "$nome: deveria sair 0 (saiu $_rc): $(cat "$T/err")"
  afirma '[ ! -s "$T/err" ]' "$nome: stderr deveria ficar vazio (truncamento ou aviso): $(cat "$T/err")"
  afirma 'confere "$SAIDA/$nome.png"' "$nome.png invalido ou fora das margens"
  afirma 'file "$SAIDA/$nome.png" | grep -q "PNG image data, 1920 x 1080, 8-bit/color RGB"' "$nome.png: file nao reconhece PNG 1920x1080 RGB"
done
afirma '[ "$(ls "$FIX"/aviso-*.txt | wc -l)" -ge 4 ] && [ "$(ls "$FIX"/resumo-*.txt | wc -l)" -ge 4 ]' "faltam exemplos (4 avisos e 4 resumos)"
for f in "$FIX"/resumo-*.txt; do
  afirma '[ "$(grep -c "^item=" "$f")" = 19 ] && [ "$(grep -c "^grupo=" "$f")" = 4 ]' "$(basename "$f"): o resumo do dono tem 19 itens em 4 grupos"
done
afirma '! grep -v "^#" "$FIX/aviso-abertura-tomada.txt" | grep -qi "pendrive"' "a abertura da tomada nao fala de pendrive"
afirma 'grep -q "tirar o pendrive" "$FIX/aviso-final-pendrive.txt"' "a tela final do pendrive pede para tira-lo"
afirma '! LC_ALL=C grep -qP "[^\x00-\x7F]" "$FIX"/*.txt "$FIX"/estresse/*.txt "$FONTES/OFL.txt"' "arquivo de campos ou OFL.txt com byte nao ASCII"
echo "  exemplos em $SAIDA/"

for f in "$FIX"/estresse/*.txt; do
  nome=$(basename "$f" .txt); modo=${nome%%-*}
  gera "$modo" "$f" "$SAIDA/estresse-$nome.png"
  afirma '[ "$_rc" = 0 ] && grep -q "^nl_tela: truncado: " "$T/err"' "estresse $nome: deveria sair 0 avisando o truncamento (saiu $_rc)"
  afirma 'confere "$SAIDA/estresse-$nome.png"' "estresse $nome: fora das margens"
done
LONGO="muito longo $(printf 'palavra%.0s ' $(seq 1 36))fim"
printf 'titulo=%s\ntexto=%s\netapa=%s\ncanto=%s\npasso=%s|agora\nrodape=%s\n' \
  "$LONGO" "$LONGO" "$LONGO" "$LONGO" "$LONGO" "$LONGO" > "$T/longo-aviso.txt"
gera aviso "$T/longo-aviso.txt" "$T/longo-aviso.png"
afirma '[ "$_rc" = 0 ] && grep -q "truncado: titulo" "$T/err" && grep -q "truncado: texto" "$T/err" && grep -q "truncado: passo" "$T/err"' "aviso longo: deveria truncar titulo, texto e passo (rc $_rc): $(head -3 "$T/err")"
afirma 'confere "$T/longo-aviso.png"' "aviso longo passou da margem"
printf 'titulo=%s\ndestaque=%s\ncanto=%s\ngrupo=%s\nitem=%s|%s|ok\ndica=%s\nrodape=%s\n' \
  "$LONGO" "$LONGO" "$LONGO" "$LONGO" "$LONGO" "$LONGO" "$LONGO" "$LONGO" > "$T/longo-resumo.txt"
gera resumo "$T/longo-resumo.txt" "$T/longo-resumo.png"
afirma '[ "$_rc" = 0 ] && [ "$(grep -c "truncado: " "$T/err")" -ge 6 ]' "resumo longo: deveria truncar os campos (rc $_rc)"
afirma 'confere "$T/longo-resumo.png"' "resumo longo passou da margem"

"$NT" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 2 ]' "sem argumentos deveria sair 2 (saiu $rc)"
"$NT" resumo "$FIX/resumo-correcao.txt" "$T/x.png" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 2 ]' "faltando dir_fontes deveria sair 2 (saiu $rc)"
"$NT" outro "$FIX/resumo-correcao.txt" "$T/x.png" "$FONTES" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 2 ]' "modo desconhecido deveria sair 2 (saiu $rc)"
invalido(){
  printf '%b' "$2" > "$T/inv.txt"; rm -f "$T/inv.png"
  gera "${3:-resumo}" "$T/inv.txt" "$T/inv.png"
  afirma '[ "$_rc" = 1 ] && [ ! -e "$T/inv.png" ] && [ -s "$T/err" ]' "$1: deveria sair 1 com mensagem e sem PNG (saiu $_rc)"
}
gera resumo "$T/nao-existe.txt" "$T/inv.png"
afirma '[ "$_rc" = 1 ]' "campos.txt ausente deveria sair 1 (saiu $_rc)"
invalido "arquivo vazio (sem titulo)" ""
invalido "sem titulo" "grupo=COR\nitem=a|b|ok\n"
invalido "5 grupos" "titulo=x\ngrupo=A\ngrupo=B\ngrupo=C\ngrupo=D\ngrupo=E\n"
invalido "7 itens no grupo" "titulo=x\ngrupo=A\n$(printf 'item=a|b|ok\\n%.0s' 1 2 3 4 5 6 7)"
invalido "4 dicas" "titulo=x\ndica=1\ndica=2\ndica=3\ndica=4\n"
invalido "item antes do grupo" "titulo=x\nitem=a|b|ok\n"
invalido "estado desconhecido" "titulo=x\ngrupo=A\nitem=a|b|otimo\n"
invalido "item sem estado" "titulo=x\ngrupo=A\nitem=a|b\n"
invalido "destaque_estado invalido" "titulo=x\ndestaque_estado=info\n"
invalido "7 passos" "titulo=x\n$(printf 'passo=a|fila\\n%.0s' 1 2 3 4 5 6 7)" aviso
invalido "fase desconhecida" "titulo=x\npasso=a|depois\n" aviso
invalido "resultado info no passo" "titulo=x\npasso=a|feito|info\n" aviso
invalido "tom desconhecido" "titulo=x\ntom=forte\n" aviso
invalido "byte zero" "titulo=x\ncanto=a\0000b\n"
invalido "linha de mais de 1024 bytes" "titulo=$(head -c 1100 /dev/zero | tr '\0' a)\n"
{ echo "titulo=x"; for _ in $(seq 1 700); do echo "# $(head -c 100 /dev/zero | tr '\0' c)"; done; } > "$T/grande.txt"
gera resumo "$T/grande.txt" "$T/inv.png"
afirma '[ "$_rc" = 1 ] && grep -q "maior que" "$T/err"' "campos.txt maior que 64 KiB deveria sair 1 (saiu $_rc)"
gera resumo "$FIX/resumo-correcao.txt" "$T/nao-existe/x.png"
afirma '[ "$_rc" = 1 ] && grep -q "gravar" "$T/err"' "saida em pasta inexistente deveria sair 1 (saiu $_rc)"

md5(){ md5sum "$1" | cut -d' ' -f1; }
um(){ printf 'titulo=%s\ncanto=c\n' "$1" > "$T/e.txt"; gera resumo "$T/e.txt" "$T/$2.png"; }
um 'a\u00e7b' esc-ce; um 'a?b' esc-int; um 'a\u00E7b' esc-maiusc; um 'a\u0000b' esc-zero; um 'a\ud800b' esc-subst
afirma '[ "$(md5 "$T/esc-ce.png")" != "$(md5 "$T/esc-int.png")" ]' "\\u00e7 deveria virar c-cedilha, nao ?"
afirma '[ "$(md5 "$T/esc-ce.png")" = "$(md5 "$T/esc-maiusc.png")" ]' "\\u00E7 e \\u00e7 deveriam ser iguais"
afirma '[ "$(md5 "$T/esc-zero.png")" = "$(md5 "$T/esc-int.png")" ] && [ "$(md5 "$T/esc-subst.png")" = "$(md5 "$T/esc-int.png")" ]' "\\u0000 e substituto deveriam virar ?"
printf 'titulo=a\303\247b\ncanto=c\n' > "$T/cru.txt"
gera resumo "$T/cru.txt" "$T/cru.png"
afirma '[ "$_rc" = 0 ] && grep -q "nao ASCII cru" "$T/err"' "byte nao ASCII cru deveria sair 0 com aviso (saiu $_rc)"
printf 'titulo=a??b\ncanto=c\n' > "$T/cru2.txt"; gera resumo "$T/cru2.txt" "$T/cru2.png"
afirma '[ "$(md5 "$T/cru.png")" = "$(md5 "$T/cru2.png")" ]' "cada byte nao ASCII cru deveria virar um ?"
{ echo "# comentario"; echo "nova_chave=qualquer"; sed 's/$/\r/' "$FIX/resumo-correcao.txt"; echo "sem igual"; } > "$T/extra.txt"
gera resumo "$FIX/resumo-correcao.txt" "$T/base.png"; gera resumo "$T/extra.txt" "$T/extra.png"
afirma '[ "$_rc" = 0 ] && [ "$(md5 "$T/base.png")" = "$(md5 "$T/extra.png")" ]' "chave desconhecida, CRLF ou comentario mudaram a tela"
{ cat "$FIX/resumo-correcao.txt"; echo "passo=x|agora"; echo "texto=y"; } > "$T/outro.txt"
gera resumo "$T/outro.txt" "$T/outro.png"
afirma '[ "$(md5 "$T/base.png")" = "$(md5 "$T/outro.png")" ]' "chave do modo aviso mudou o resumo"

mkdir -p "$T/vazia"
gera resumo "$FIX/resumo-correcao.txt" "$T/f.png" "$T/vazia"
afirma '[ "$_rc" = 1 ] && grep -q "sem fonte" "$T/err" && [ ! -e "$T/f.png" ]' "sem fonte nenhuma deveria sair 1 com mensagem (saiu $_rc)"
mkdir -p "$T/parcial" "$T/sistema"
cp "$FONTES"/IBMPlexSansCondensed-*.ttf "$FONTES/IBMPlexMono-Regular.ttf" "$T/parcial/"
cp "$FONTES/IBMPlexMono-Regular.ttf" "$T/sistema/DroidSansMono.ttf"
NL_TELA_SISTEMA="$T/sistema" "$NT" resumo "$FIX/resumo-correcao.txt" "$T/f.png" "$T/parcial" 2>"$T/err"; rc=$?
afirma '[ "$rc" = 0 ] && grep -q "IBMPlexMono-SemiBold.ttf ausente, usando a reserva" "$T/err" && confere "$T/f.png"' "faltando a Mono SemiBold deveria usar a reserva (saiu $rc): $(cat "$T/err")"
gera resumo "$FIX/resumo-correcao.txt" "$T/f.png" "$T/parcial"
afirma '[ "$_rc" = 1 ] && grep -q "sem fonte para IBMPlexMono-SemiBold.ttf" "$T/err"' "faltando a Mono SemiBold sem reserva deveria sair 1 (saiu $_rc)"
mkdir -p "$T/ruim"; cp "$FONTES"/*.ttf "$T/ruim/"; head -c 4096 /dev/urandom > "$T/ruim/IBMPlexSansCondensed-Bold.ttf"
gera resumo "$FIX/resumo-correcao.txt" "$T/f.png" "$T/ruim"
afirma '[ "$_rc" = 1 ] && grep -q "nao e uma fonte TrueType valida" "$T/err"' "TTF corrompido sem reserva deveria sair 1 (saiu $_rc)"
_tam=$(wc -c < "$FONTES/IBMPlexSansCondensed-Bold.ttf")
for _c in 15 16 1000 100000 $((_tam - 1)); do
  head -c "$_c" "$FONTES/IBMPlexSansCondensed-Bold.ttf" > "$T/ruim/IBMPlexSansCondensed-Bold.ttf"; rm -f "$T/f.png"
  gera resumo "$FIX/resumo-correcao.txt" "$T/f.png" "$T/ruim"
  afirma '[ "$_rc" = 1 ] && grep -q "nao e uma fonte TrueType valida" "$T/err" && [ ! -e "$T/f.png" ]' "TTF truncado em $_c bytes deveria sair 1 com mensagem (saiu $_rc): $(head -2 "$T/err")"
done
cp "$FONTES/IBMPlexSansCondensed-Bold.ttf" "$T/sistema/Roboto-Bold.ttf"
NL_TELA_SISTEMA="$T/sistema" "$NT" resumo "$FIX/resumo-correcao.txt" "$T/f.png" "$T/ruim" 2>"$T/err"; rc=$?
afirma '[ "$rc" = 0 ] && grep -q "IBMPlexSansCondensed-Bold.ttf ausente, usando a reserva" "$T/err" && confere "$T/f.png"' "TTF truncado com reserva deveria usar a reserva (saiu $rc): $(head -2 "$T/err")"
mkdir -p "$T/pasta-saida"
gera resumo "$FIX/resumo-correcao.txt" "$T/pasta-saida"
afirma '[ "$_rc" = 1 ] && [ -d "$T/pasta-saida" ]' "saida apontando para uma pasta deveria sair 1 sem apaga-la (saiu $_rc)"

afirma 'file "$ROOT/artifacts/tela/nl_tela" | grep -q "ELF 32-bit LSB.*ARM.*/system/bin/linker"' "artifacts/tela/nl_tela nao e um ELF ARM do Android"
afirma 'cmp -s "$ROOT/artifacts/tela/nl_tela" "$ROOT/pendrive-autorun/nl_tela"' "pendrive-autorun/nl_tela difere de artifacts/tela/nl_tela"
NDK_CC="${ANDROID_NDK:-$HOME/Android/android-ndk-r27c}/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang"
if [ -x "$NDK_CC" ]; then
  ( cd "$ROOT" && "$NDK_CC" -O2 -Wall -o "$T/nl_tela.arm" artifacts/tela/nl_tela.c -lm ) 2>"$T/ndk.err"
  afirma 'cmp -s "$T/nl_tela.arm" "$ROOT/artifacts/tela/nl_tela"' "artifacts/tela/nl_tela nao e o binario deste nl_tela.c (recompile como no README): $(head -3 "$T/ndk.err")"
else
  echo "  (NDK ausente em $NDK_CC: binario ARM nao recompilado para comparar)"
fi
afirma '[ "$(ls "$FONTES"/*.ttf | wc -l)" = 5 ] && [ -s "$FONTES/OFL.txt" ]' "pendrive-autorun/fontes sem os 5 TTF do C-tela e a OFL.txt"

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
