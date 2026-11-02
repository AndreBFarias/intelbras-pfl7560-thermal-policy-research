#!/usr/bin/env bash
# shellcheck disable=SC2034
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$ROOT/tests/fixtures/camera"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
NL="$T/nl_camcheck"
FALHAS=0; TESTES=0
afirma(){ TESTES=$((TESTES+1)); if eval "$1"; then :; else FALHAS=$((FALHAS+1)); echo "  FALHA: $2  (cond: $1)"; fi; }
arq(){ echo "arquivo:$FIX/$1.yuyv:640:480"; }

cc -O2 -Wall -Wextra -o "$NL" "$ROOT/artifacts/camcheck/nl_camcheck.c" -lm || { echo "FALHA: nao compilou no host"; exit 1; }
echo "nl_camcheck compilado no host (cc)"

JEIDA="235 235 235 235 235 231 218 208 196 180 164 140 113 91 72 64"
VESA="235 235 235 232 191 146 104 86 219 211 156 89 184 115 194 128"
confere_valores(){
  python3 -I -c '
import sys
a=list(map(int,sys.argv[1].split())); b=list(map(int,sys.argv[2].split()))
sys.exit(0 if len(a)==len(b) and all(abs(x-y)<=2 for x,y in zip(a,b)) else 1)' "$1" "$2"
}

for f in f1 f0; do
  "$NL" faixas "$(arq calibracao-$f)" 16 "$T/faixas-$f.txt" >"$T/out-$f.txt" 2>&1; rc=$?
  afirma '[ "$rc" = 0 ]' "calibracao-$f: faixas deveria sair 0 (saiu $rc): $(cat "$T/out-$f.txt")"
  afirma '[ "$(wc -l < "$T/faixas-$f.txt")" = 16 ]' "calibracao-$f: o arquivo deveria ter 16 linhas"
  afirma 'awk "NF!=2 || \$1>=\$2 {bad=1} END{exit bad}" "$T/faixas-$f.txt"' "calibracao-$f: linha sem 'ini fim' crescente"
  "$NL" niveis "$(arq escada-$f)" "$T/faixas-$f.txt" > "$T/niveis-$f.txt" 2>&1; rc=$?
  afirma '[ "$rc" = 0 ]' "escada-$f: niveis deveria sair 0 (saiu $rc)"
  afirma '[ "$(wc -l < "$T/niveis-$f.txt")" = 17 ]' "escada-$f: esperava 16 niveis + a linha de inversoes"
done
nv(){ head -16 "$T/niveis-$1.txt" | tr '\n' ' '; }
inv(){ tail -1 "$T/niveis-$1.txt"; }
afirma 'confere_valores "$JEIDA" "$(nv f1)"' "escada-f1: niveis fora do prototipo: $(nv f1)"
afirma '[ "$(inv f1)" = "inv_cresc=10 inv_decresc=0" ]' "escada-f1 deveria ser monotona: $(inv f1)"
afirma 'confere_valores "$VESA" "$(nv f0)"' "escada-f0: niveis fora do prototipo: $(nv f0)"
afirma '[ "$(inv f0)" = "inv_cresc=9 inv_decresc=3" ]' "escada-f0 deveria ser fora de ordem: $(inv f0)"

caso_bloco8(){
  _c="arquivo:$FIX/calibracao-$1.yuyv:$2:$3"; _e="arquivo:$FIX/escada-$1.yuyv:$2:$3"
  "$NL" faixas "$_c" 16 "$T/fx-$1.txt" >"$T/ofx-$1" 2>&1; _rc=$?
  afirma '[ "$_rc" = 0 ]' "calibracao-$1 ($2x$3): esperava 16 faixas: $(cat "$T/ofx-$1")"
  "$NL" niveis "$_e" "$T/fx-$1.txt" >"$T/nv-$1" 2>&1
  _inv=$(tail -1 "$T/nv-$1"); _esp="$4"
  afirma '[ "$_inv" = "$_esp" ]' "escada-$1 ($2x$3): esperava '$_esp', veio '$_inv'"
}
caso_bloco8 inclinada-f1 640 480 "inv_cresc=8 inv_decresc=0"
caso_bloco8 hd-f1 1280 720 "inv_cresc=8 inv_decresc=0"
caso_bloco8 hd-f0 1280 720 "inv_cresc=9 inv_decresc=3"
afirma 'grep -q "^#define COL_INI_PCT 47$" "$ROOT/artifacts/camcheck/nl_camcheck.c" && grep -q "^#define COL_FIM_PCT 53$" "$ROOT/artifacts/camcheck/nl_camcheck.c"' "janela de colunas diferente de 47 a 53%"

"$NL" faixas "$(arq calibracao-f1)" 15 "$T/x15.txt" >"$T/o15" 2>&1; rc=$?
afirma '[ "$rc" = 3 ] && [ ! -e "$T/x15.txt" ] && grep -q "achadas: 16" "$T/o15"' "N=15 sobre 16 faixas deveria sair 3, sem arquivo (saiu $rc)"
"$NL" faixas "$(arq escada-f1)" 16 "$T/xe.txt" >"$T/oe" 2>&1; rc=$?
afirma '[ "$rc" = 3 ]' "a escada nao serve para localizar (so a calibracao): esperava 3, saiu $rc"
"$NL" faixas "arquivo:$T/nao-existe.yuyv:640:480" 16 "$T/y.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "quadro ausente deveria sair 1"
head -c 1000 "$FIX/escada-f1.yuyv" > "$T/curto.yuyv"
"$NL" niveis "arquivo:$T/curto.yuyv:640:480" "$T/faixas-f1.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "quadro curto deveria sair 1"
"$NL" faixas "arquivo:$FIX/calibracao-f1.yuyv:320:480" 16 "$T/w.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ] && [ ! -e "$T/w.txt" ]' "quadro maior que L*A*2 deveria sair 1 (saiu $rc)"
"$NL" niveis "arquivo:$FIX/escada-f1.yuyv:2:2" "$T/faixas-f1.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "quadro 2x2 (sem colunas para o perfil) deveria sair 1 (saiu $rc)"
"$NL" faixas "arquivo:$FIX/escada-f1.yuyv:2147483647:2147483647" 16 "$T/w.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "dimensao absurda deveria sair 1 (saiu $rc)"
printf '1 2\n' > "$T/uma.txt"
"$NL" niveis "$(arq escada-f1)" "$T/uma.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "faixas.txt com uma faixa so deveria sair 1"
printf '0 10\n470 600\n' > "$T/fora.txt"
"$NL" niveis "$(arq escada-f1)" "$T/fora.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "faixa fora do quadro deveria sair 1"
"$NL" niveis "$(arq escada-f1)" "$T/nao-existe.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "faixas.txt ausente deveria sair 1"
"$NL" faixas >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 2 ]' "uso errado deveria sair 2"
"$NL" faixas /dev/nao-existe-video 16 "$T/z.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "dispositivo ausente deveria sair 1 (cai no manual)"

# shellcheck disable=SC2034
GEO_CHAVES="inclinacao_graus trapezio_pct borda_centro_px borda_esq_px borda_dir_px contraste_centro quadro "
geo(){
  _q="arquivo:$FIX/calibracao-$1.yuyv:$2:$3"
  "$NL" faixas "$_q" 16 "$T/gfx-$1.txt" >/dev/null 2>&1
  "$NL" geometria "$_q" "${4:-$T/gfx-$1.txt}" >"$T/geo-$1.txt" 2>"$T/geo-$1.err"; _rc=$?
}
chave(){ sed -n "s/^$2=//p" "$T/geo-$1.txt"; }
compara(){ python3 -I -c 'import sys; sys.exit(0 if eval(sys.argv[1]) else 1)' "$1"; }
for c in "f1 640 480" "f0 640 480" "inclinada-f1 640 480" "hd-f1 1280 720" "hd-f0 1280 720"; do
  read -r _n _l _a <<<"$c"
  geo "$_n" "$_l" "$_a"
  echo "  geometria calibracao-$_n: $(tr '\n' ' ' < "$T/geo-$_n.txt")"
  afirma '[ "$_rc" = 0 ]' "geometria calibracao-$_n deveria sair 0 (saiu $_rc): $(cat "$T/geo-$_n.err")"
  afirma '[ "$(cut -d= -f1 "$T/geo-$_n.txt" | tr "\n" " ")" = "$GEO_CHAVES" ]' "geometria calibracao-$_n: chaves fora do contrato: $(cut -d= -f1 "$T/geo-$_n.txt" | tr '\n' ' ')"
  afirma '[ "$(chave "$_n" quadro)" = "${_l}x${_a}" ]' "geometria calibracao-$_n: quadro errado"
  afirma '[ "$(head -6 "$T/geo-$_n.txt" | grep -cE "^[a-z_]+=-?[0-9]+\.[0-9]+$")" = 6 ]' "geometria calibracao-$_n: numero sem ponto decimal"
  _vao=$(LC_ALL=C awk 'NR>1{g+=$1-pf;n++} {pf=$2} END{printf "%.2f", g/n}' "$T/gfx-$_n.txt")
  for b in borda_centro_px borda_esq_px borda_dir_px; do
    _b=$(chave "$_n" $b)
    afirma 'compara "0 < ${_b:-0} < $_vao"' "geometria calibracao-$_n: $b=$_b fora de (0, vao $_vao)"
  done
  _ct=$(chave "$_n" contraste_centro)
  afirma 'compara "0.5 < ${_ct:-0} < 1"' "geometria calibracao-$_n: contraste_centro=$_ct fora de (0.5, 1)"
done
afirma 'compara "abs($(chave hd-f1 inclinacao_graus)) > abs($(chave f1 inclinacao_graus)) + 1"' "calibracao-hd-f1 deveria ter inclinacao maior que calibracao-f1"
afirma 'compara "2.6 < $(chave hd-f1 inclinacao_graus) < 3.1 and 10 < $(chave hd-f1 trapezio_pct) < 15"' "calibracao-hd-f1 fora do medido (2,82 graus, trapezio 12,5%)"
afirma 'compara "0.4 < $(chave f1 inclinacao_graus) < 0.9"' "calibracao-f1 fora do medido (0,64 graus)"

sintetico(){
  python3 -I - "$@" <<'PY'
import sys, math
out, A, R, T = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
L, H = 640, 480
t = math.tan(math.radians(A)); passo = H * 0.04; faixa = passo * 0.7
buf = bytearray(L * H * 2)
for x in range(L):
    esc = 1 + (T - 1) * x / (L - 1); base = H * 0.5 + t * (x - L / 2)
    for y in range(H):
        u = (y + 0.5 - base) / esc + 8 * passo; k = math.floor(u / passo); v = 20
        if 0 <= k < 16:
            d = u - k * passo
            if d < faixa: v = 20 + 210 * min(1.0, min(d, faixa - d) * esc / R + 0.5)
            else: v = 20 + 210 * max(0.0, 0.5 - min(d - faixa, passo - d) * esc / R)
        buf[(y * L + x) * 2] = int(round(v)); buf[(y * L + x) * 2 + 1] = 128
open(out, 'wb').write(bytes(buf))
PY
}
sint_geo(){
  sintetico "$T/s-$1.yuyv" "$2" "$3" "$4"
  "$NL" faixas "arquivo:$T/s-$1.yuyv:640:480" 16 "$T/sfx-$1.txt" >/dev/null 2>&1
  "$NL" geometria "arquivo:$T/s-$1.yuyv:640:480" "$T/sfx-$1.txt" >"$T/geo-s$1.txt" 2>&1; _rc=$?
  echo "  geometria sintetico $1 (A=$2 R=$3 T=$4): $(tr '\n' ' ' < "$T/geo-s$1.txt")"
}
sint_geo a 3 3 1
afirma '[ "$_rc" = 0 ] && compara "abs($(chave sa inclinacao_graus) - 3) < 0.05 and abs($(chave sa trapezio_pct)) < 0.3"' "sintetico 3 graus: inclinacao ou trapezio errados"
afirma 'compara "2.4 <= $(chave sa borda_centro_px) < 3.1"' "sintetico R=3: borda fora de [0,8R, 0,8R+0,7]"
sint_geo b -2 2 1
afirma '[ "$_rc" = 0 ] && compara "abs($(chave sb inclinacao_graus) + 2) < 0.05"' "sintetico -2 graus: sinal ou valor errado"
afirma 'compara "1.6 <= $(chave sb borda_esq_px) < 2.3 and 1.6 <= $(chave sb borda_dir_px) < 2.3"' "sintetico R=2: bordas laterais fora de [0,8R, 0,8R+0,7]"
sint_geo c 0 4 1.1
afirma '[ "$_rc" = 0 ] && compara "5.8 < $(chave sc trapezio_pct) < 6.8 and abs($(chave sc inclinacao_graus)) < 0.1"' "sintetico trapezio 6,3%: valor errado"
afirma 'compara "3.2 <= $(chave sc borda_centro_px) < 3.9"' "sintetico R=4: borda fora de [0,8R, 0,8R+0,7]"
afirma 'compara "0.88 < $(chave sc contraste_centro) < 0.94"' "sintetico: contraste (230-20)/230 = 0,91 fora"

"$NL" geometria "arquivo:$FIX/escada-hd-f1.yuyv:1280:720" "$T/gfx-hd-f1.txt" >/dev/null 2>"$T/g3.err"; rc=$?
afirma '[ "$rc" = 3 ] && grep -q "esperadas 16" "$T/g3.err"' "escada no lugar da calibracao deveria sair 3 (saiu $rc)"
head -c $((1280*720*2)) /dev/zero > "$T/preto.yuyv"
"$NL" geometria "arquivo:$T/preto.yuyv:1280:720" "$T/gfx-hd-f1.txt" >"$T/g3b.out" 2>/dev/null; rc=$?
afirma '[ "$rc" = 3 ] && [ ! -s "$T/g3b.out" ]' "quadro preto deveria sair 3 sem imprimir chaves (saiu $rc)"
"$NL" geometria "arquivo:$T/nao-existe.yuyv:640:480" "$T/gfx-f1.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "geometria com quadro ausente deveria sair 1 (saiu $rc)"
"$NL" geometria "$(arq calibracao-f1)" "$T/nao-existe.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "geometria com faixas.txt ausente deveria sair 1 (saiu $rc)"
printf '10 20\n30 40\n' > "$T/duas.txt"
"$NL" geometria "$(arq calibracao-f1)" "$T/duas.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "geometria com 2 faixas so deveria sair 1 (saiu $rc)"
printf '10 20\n30 40\n470 600\n' > "$T/fora3.txt"
"$NL" geometria "$(arq calibracao-f1)" "$T/fora3.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "geometria com faixa fora do quadro deveria sair 1 (saiu $rc)"
"$NL" geometria /dev/nao-existe-video "$T/gfx-f1.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "geometria com dispositivo ausente deveria sair 1 (saiu $rc)"
"$NL" geometria "$(arq calibracao-f1)" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 2 ]' "geometria sem faixas.txt e uso errado: deveria sair 2 (saiu $rc)"

# shellcheck disable=SC2034
NIT_CHAVES="nitidez_r1c1 nitidez_r1c2 nitidez_r1c3 nitidez_r2c1 nitidez_r2c2 nitidez_r2c3 nitidez_r3c1 nitidez_r3c2 nitidez_r3c3 quadro "
nit(){
  "$NL" nitidez "arquivo:$FIX/calibracao-$1.yuyv:$2:$3" "$T/gfx-$1.txt" >"$T/nit-$1.txt" 2>"$T/nit-$1.err"; _rc=$?
}
nv3(){ sed -n "s/^nitidez_$2=//p" "$T/nit-$1.txt"; }
for c in "f1 640 480" "f0 640 480" "inclinada-f1 640 480" "hd-f1 1280 720" "hd-f0 1280 720"; do
  read -r _n _l _a <<<"$c"
  nit "$_n" "$_l" "$_a"
  echo "  nitidez calibracao-$_n: $(tr '\n' ' ' < "$T/nit-$_n.txt")"
  afirma '[ "$_rc" = 0 ]' "nitidez calibracao-$_n deveria sair 0 (saiu $_rc): $(cat "$T/nit-$_n.err")"
  afirma '[ "$(cut -d= -f1 "$T/nit-$_n.txt" | tr "\n" " ")" = "$NIT_CHAVES" ]' "nitidez calibracao-$_n: chaves fora do contrato: $(cut -d= -f1 "$T/nit-$_n.txt" | tr '\n' ' ')"
  afirma '[ "$(sed -n "s/^quadro=//p" "$T/nit-$_n.txt")" = "${_l}x${_a}" ]' "nitidez calibracao-$_n: quadro errado"
  afirma '[ "$(head -9 "$T/nit-$_n.txt" | grep -cE "^nitidez_r[1-3]c[1-3]=[0-9]+\.[0-9]{2}$")" = 9 ]' "nitidez calibracao-$_n: numero fora do formato"
  _vao=$(LC_ALL=C awk 'NR>1{g+=$1-pf;n++} {pf=$2} END{printf "%.2f", g/n}' "$T/gfx-$_n.txt")
  for r in r1c1 r1c2 r1c3 r2c1 r2c2 r2c3 r3c1 r3c2 r3c3; do
    _v=$(nv3 "$_n" $r)
    afirma 'compara "0 < ${_v:-0} < $_vao"' "nitidez calibracao-$_n: $r=$_v fora de (0, vao $_vao)"
  done
done
med_col(){ python3 -I -c 'import sys; v=[float(x) for x in sys.argv[1:]]; print("%.3f" % (sum(v)/len(v)))' "$(nv3 "$1" "r1$2")" "$(nv3 "$1" "r2$2")" "$(nv3 "$1" "r3$2")"; }
afirma 'compara "$(med_col hd-f1 c1) > 1.3 * $(med_col hd-f1 c2) and $(med_col hd-f1 c3) < 1.3 * $(med_col hd-f1 c2)"' "calibracao-hd-f1: esquerda $(med_col hd-f1 c1), meio $(med_col hd-f1 c2), direita $(med_col hd-f1 c3)"
for r in r1c1 r1c2 r1c3 r2c1 r2c3 r3c1 r3c2 r3c3; do
  afirma 'compara "0.8 < $(nv3 f1 $r) / $(nv3 f1 r2c2) < 1.2"' "calibracao-f1: $r=$(nv3 f1 $r) longe do centro $(nv3 f1 r2c2)"
done
afirma '! grep -q "GEO_JAN" <(sed -n "/^static int nitidez_cmd/,/^}/p" "$ROOT/artifacts/camcheck/nl_camcheck.c")' "a nitidez usa as janelas fixas da geometria"

sint_nit(){
  python3 -I - "$@" <<'PY'
import sys, math
out, A, Re, Rr, Rb = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
L, H = 640, 480; x0, x1 = 64, 544
t = math.tan(math.radians(A)); passo = H * 0.04; faixa = passo * 0.7
buf = bytearray(L * H * 2)
for x in range(L):
    base = H * 0.5 + t * (x - L / 2); R0 = Re if (x - x0) < (x1 - x0) / 3 else Rr
    for y in range(H):
        if x < x0: v = 100
        elif x >= x1: v = 15
        else:
            u = y + 0.5 - base + 8 * passo; k = math.floor(u / passo); v = 20
            R = R0 * (1 + (Rb - 1) * min(1.0, max(0.0, u / (16 * passo))))
            if 0 <= k < 16:
                d = u - k * passo
                if d < faixa: v = 20 + 210 * min(1.0, min(d, faixa - d) / R + 0.5)
                else: v = 20 + 210 * max(0.0, 0.5 - min(d - faixa, passo - d) / R)
        buf[(y * L + x) * 2] = int(round(v)); buf[(y * L + x) * 2 + 1] = 128
open(out, 'wb').write(bytes(buf))
PY
}
sn(){
  sint_nit "$T/n-$1.yuyv" "$2" "$3" "$4" "$5"
  "$NL" faixas "arquivo:$T/n-$1.yuyv:640:480" 16 "$T/nfx-$1.txt" >/dev/null 2>&1
  "$NL" nitidez "arquivo:$T/n-$1.yuyv:640:480" "$T/nfx-$1.txt" >"$T/nit-s$1.txt" 2>&1; _rc=$?
  echo "  nitidez sintetico $1 (A=$2 Re=$3 Rr=$4 Rb=$5): $(tr '\n' ' ' < "$T/nit-s$1.txt")"
}
sn a 2 4 2 1
afirma '[ "$_rc" = 0 ]' "sintetico a: rc=$_rc: $(cat "$T/nit-sa.txt")"
for r in r1c1 r2c1 r3c1; do afirma 'compara "3.2 <= $(nv3 sa $r) < 3.9"' "sintetico a: $r=$(nv3 sa $r) fora de [0,8x4, +0,7]"; done
for r in r1c2 r2c2 r3c2 r1c3 r2c3 r3c3; do afirma 'compara "1.6 <= $(nv3 sa $r) < 2.3"' "sintetico a: $r=$(nv3 sa $r) fora de [0,8x2, +0,7]"; done
sn b -1.5 2 2 2
afirma '[ "$_rc" = 0 ]' "sintetico b: rc=$_rc: $(cat "$T/nit-sb.txt")"
for c in c1 c2 c3; do
  afirma 'compara "$(nv3 sb r1$c) + 0.3 < $(nv3 sb r2$c) and $(nv3 sb r2$c) + 0.3 < $(nv3 sb r3$c)"' "sintetico b: coluna $c sem a ordem r1 < r2 < r3: $(nv3 sb r1$c) $(nv3 sb r2$c) $(nv3 sb r3$c)"
done
"$NL" nitidez "arquivo:$FIX/escada-hd-f1.yuyv:1280:720" "$T/gfx-hd-f1.txt" >"$T/n3.out" 2>"$T/n3.err"; rc=$?
afirma '[ "$rc" = 3 ] && [ ! -s "$T/n3.out" ]' "nitidez com a escada deveria sair 3 sem chaves (saiu $rc): $(cat "$T/n3.err")"
"$NL" nitidez "arquivo:$T/preto.yuyv:1280:720" "$T/gfx-hd-f1.txt" >"$T/n3b.out" 2>/dev/null; rc=$?
afirma '[ "$rc" = 3 ] && [ ! -s "$T/n3b.out" ]' "nitidez com quadro preto deveria sair 3 (saiu $rc)"
"$NL" nitidez "arquivo:$T/nao-existe.yuyv:640:480" "$T/gfx-f1.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "nitidez com quadro ausente deveria sair 1 (saiu $rc)"
"$NL" nitidez "$(arq calibracao-f1)" "$T/nao-existe.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "nitidez com faixas.txt ausente deveria sair 1 (saiu $rc)"
printf '10 20\n30 40\n50 60\n' > "$T/tres.txt"
"$NL" nitidez "$(arq calibracao-f1)" "$T/tres.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "nitidez com 3 faixas (menos de 3 vaos) deveria sair 1 (saiu $rc)"
"$NL" nitidez "$(arq calibracao-f1)" "$T/fora3.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "nitidez com faixa fora do quadro deveria sair 1 (saiu $rc)"
"$NL" nitidez /dev/nao-existe-video "$T/gfx-f1.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "nitidez com dispositivo ausente deveria sair 1 (saiu $rc)"
"$NL" nitidez "$(arq calibracao-f1)" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 2 ]' "nitidez sem faixas.txt: deveria sair 2 (saiu $rc)"

cat > "$T/falso.c" <<'FIM'
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
int __real_open(const char *p, int fl, ...);
int __real_ioctl(int fd, unsigned long req, ...);
static int falso = -1, fila = 0;
#define TAM (640 * 480 * 2)
int __wrap_open(const char *p, int fl, ...) {
  if (strcmp(p, "/dev/video-falso") != 0) return __real_open(p, fl, 0);
  falso = memfd_create("v4l2", 0);
  if (falso >= 0 && ftruncate(falso, 16L * TAM) != 0) return -1;
  return falso;
}
int __wrap_ioctl(int fd, unsigned long req, ...) {
  va_list ap; va_start(ap, req); void *arg = va_arg(ap, void *); va_end(ap);
  if (fd != falso) return __real_ioctl(fd, req, arg);
  if (req == VIDIOC_ENUM_FRAMESIZES) { errno = EINVAL; return -1; }
  if (req == VIDIOC_S_FMT) { struct v4l2_format *f = arg; f->fmt.pix.bytesperline = f->fmt.pix.width * 2; return 0; }
  if (req == VIDIOC_REQBUFS) { ((struct v4l2_requestbuffers *)arg)->count = atoi(getenv("FALSO_COUNT")); return 0; }
  if (req == VIDIOC_QUERYBUF) { struct v4l2_buffer *b = arg; b->length = TAM; b->m.offset = b->index * TAM; return 0; }
  if (req == VIDIOC_QBUF) { fila++; return 0; }
  if (req == VIDIOC_DQBUF) {
    if (fila == 0) { errno = EINVAL; return -1; }
    struct v4l2_buffer *b = arg; fila--; b->index = 0; b->bytesused = TAM; b->length = TAM; b->flags = 0; return 0;
  }
  return 0;
}
FIM
if cc -O1 -g -fsanitize=address -Wl,--wrap=open,--wrap=ioctl -o "$T/nl_falso" \
     "$ROOT/artifacts/camcheck/nl_camcheck.c" "$T/falso.c" -lm 2>"$T/falso.err"; then
  export ASAN_OPTIONS=detect_leaks=0
  FALSO_COUNT=8 "$T/nl_falso" grab /dev/video-falso YUYV 640 480 "$T/q8.yuyv" 2 >"$T/g8" 2>&1; rc=$?
  afirma '[ "$rc" = 0 ] && [ "$(wc -c < "$T/q8.yuyv")" = 614400 ]' "grab com 8 buffers do driver: rc=$rc $(grep -m1 -o 'ERROR: AddressSanitizer: [a-z-]*' "$T/g8")"
  FALSO_COUNT=8 "$T/nl_falso" faixas /dev/video-falso 16 "$T/f8.txt" 2 >"$T/c8" 2>&1; rc=$?
  afirma '[ "$rc" = 3 ] && ! grep -q AddressSanitizer "$T/c8"' "faixas com 8 buffers do driver: rc=$rc (quadro liso: esperava 3)"
  FALSO_COUNT=0 "$T/nl_falso" grab /dev/video-falso YUYV 640 480 "$T/q0.yuyv" 2 >"$T/g0" 2>&1; rc=$?
  afirma '[ "$rc" = 1 ] && grep -q "nenhum buffer" "$T/g0" && [ ! -e "$T/q0.yuyv" ]' "grab sem buffer do driver: rc=$rc $(tail -1 "$T/g0")"
  FALSO_COUNT=0 "$T/nl_falso" faixas /dev/video-falso 16 "$T/f0.txt" 2 >"$T/c0" 2>&1; rc=$?
  afirma '[ "$rc" = 1 ] && grep -q "nenhum buffer" "$T/c0"' "faixas sem buffer do driver: rc=$rc $(tail -1 "$T/c0")"
  FALSO_COUNT=4 "$T/nl_falso" grab /dev/video-falso YUYV 640 480 /dev/full 2 >"$T/gf" 2>&1; rc=$?
  afirma '[ "$rc" = 1 ] && ! grep -q "^gravado" "$T/gf"' "grab em /dev/full deveria sair 1 (saiu $rc): $(tail -1 "$T/gf")"
  unset ASAN_OPTIONS
else
  echo "  (sem ASan no cc do host: driver de mentira pulado) $(head -1 "$T/falso.err")"
fi

afirma '! grep -q "VIDIOC_S_CTRL\|VIDIOC_S_EXT_CTRLS" "$ROOT/artifacts/camcheck/nl_camcheck.c"' "o nl_camcheck passou a escrever controle da camera"
afirma 'cmp -s "$ROOT/artifacts/camcheck/nl_camcheck" "$ROOT/pendrive-autorun/nl_camcheck"' "pendrive-autorun/nl_camcheck difere de artifacts/camcheck/nl_camcheck"
afirma 'file "$ROOT/pendrive-autorun/nl_camcheck" | grep -q "ELF 32-bit LSB.*ARM"' "pendrive-autorun/nl_camcheck nao e um ELF ARM"
NDK_CC="${ANDROID_NDK:-$HOME/Android/android-ndk-r27c}/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang"
if [ -x "$NDK_CC" ]; then
  ( cd "$ROOT" && "$NDK_CC" -O2 -Wall -o "$T/nl_camcheck.arm" artifacts/camcheck/nl_camcheck.c -lm ) 2>"$T/ndk.err"
  afirma 'cmp -s "$T/nl_camcheck.arm" "$ROOT/artifacts/camcheck/nl_camcheck"' "artifacts/camcheck/nl_camcheck nao e o binario deste nl_camcheck.c: $(head -3 "$T/ndk.err")"
else
  echo "  (NDK ausente em $NDK_CC: binario ARM nao recompilado para comparar)"
fi

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
