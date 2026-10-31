#!/usr/bin/env bash
# tests/test-camcheck.sh - bloco 7 (C1): o nl_camcheck do HOST (mesmo .c do binario ARM)
# sobre os quadros reais de tests/fixtures/camera/ (YUYV 640x480 e 1280x720, projetor de verdade,
# camera interna, 2026-10-30). Nao fala com o projetor nem com a camera.
#   bash tests/test-camcheck.sh
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

# valores medidos com a janela de colunas 47 a 53% (bloco 8), tolerancia de 2
JEIDA="235 235 235 235 235 231 218 208 196 180 164 140 113 91 72 64"
VESA="235 235 235 232 191 146 104 86 219 211 156 89 184 115 194 128"
confere_valores(){ # "esperados" "obtidos"; 0 se cada par difere <= 2
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
# JEIDA (f1, formato certo): monotona (10 quedas, 0 subidas)
afirma 'confere_valores "$JEIDA" "$(nv f1)"' "escada-f1: niveis fora do prototipo: $(nv f1)"
afirma '[ "$(inv f1)" = "inv_cresc=10 inv_decresc=0" ]' "escada-f1 deveria ser monotona: $(inv f1)"
# VESA (f0, formato errado): fora de ordem
afirma 'confere_valores "$VESA" "$(nv f0)"' "escada-f0: niveis fora do prototipo: $(nv f0)"
afirma '[ "$(inv f0)" = "inv_cresc=9 inv_decresc=3" ]' "escada-f0 deveria ser fora de ordem: $(inv f0)"

# bloco 8: imagem inclinada para a camera (falhava com a janela de 35 a 65%) e quadros
# 1280x720, o tamanho que a captura passou a preferir. Formato certo = monotona;
# formato errado (VESA) = pelo menos 3 inversoes.
caso_bloco8(){ # nome L A inversoes-esperadas
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
# a janela de colunas e estreita (a larga de 35 a 65% achava 9 faixas no quadro inclinado)
afirma 'grep -q "^#define COL_INI_PCT 47$" "$ROOT/artifacts/camcheck/nl_camcheck.c" && grep -q "^#define COL_FIM_PCT 53$" "$ROOT/artifacts/camcheck/nl_camcheck.c"' "janela de colunas diferente de 47 a 53%"

# faixas: N errado nao acha (exit 3, nao grava) -- a calibracao tem 16; escada tem 13 trechos acima do limiar
"$NL" faixas "$(arq calibracao-f1)" 15 "$T/x15.txt" >"$T/o15" 2>&1; rc=$?
afirma '[ "$rc" = 3 ] && [ ! -e "$T/x15.txt" ] && grep -q "achadas: 16" "$T/o15"' "N=15 sobre 16 faixas deveria sair 3, sem arquivo (saiu $rc)"
"$NL" faixas "$(arq escada-f1)" 16 "$T/xe.txt" >"$T/oe" 2>&1; rc=$?
afirma '[ "$rc" = 3 ]' "a escada nao serve para localizar (so a calibracao): esperava 3, saiu $rc"
# erros: arquivo ausente, quadro curto, faixas.txt invalido, faixa fora do quadro, uso
"$NL" faixas "arquivo:$T/nao-existe.yuyv:640:480" 16 "$T/y.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "quadro ausente deveria sair 1"
head -c 1000 "$FIX/escada-f1.yuyv" > "$T/curto.yuyv"
"$NL" niveis "arquivo:$T/curto.yuyv:640:480" "$T/faixas-f1.txt" >/dev/null 2>&1; rc=$?
afirma '[ "$rc" = 1 ]' "quadro curto deveria sair 1"
# quadro de OUTRO tamanho (o de 640x480 lido como 320x480: sobram bytes) e dimensoes absurdas
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

# ---- bloco 9A: geometria (contrato C-geo) ---------------------------------------------
# quadros reais: sai 0, as 7 chaves na ordem do contrato, numeros com ponto, bordas positivas e
# menores que o vao entre as faixas (do faixas.txt), contraste entre 0 e 1
# shellcheck disable=SC2034  # lida dentro do afirma (eval)
GEO_CHAVES="inclinacao_graus trapezio_pct borda_centro_px borda_esq_px borda_dir_px contraste_centro quadro "
geo(){ # sufixo L A [arquivo-de-faixas]: roda faixas+geometria; saida em $T/geo-<sufixo>.txt, rc em _rc
  _q="arquivo:$FIX/calibracao-$1.yuyv:$2:$3"
  "$NL" faixas "$_q" 16 "$T/gfx-$1.txt" >/dev/null 2>&1
  "$NL" geometria "$_q" "${4:-$T/gfx-$1.txt}" >"$T/geo-$1.txt" 2>"$T/geo-$1.err"; _rc=$?
}
chave(){ sed -n "s/^$2=//p" "$T/geo-$1.txt"; }
compara(){ python3 -I -c 'import sys; sys.exit(0 if eval(sys.argv[1]) else 1)' "$1"; }
for c in "f1 640 480" "f0 640 480" "inclinada-f1 640 480" "hd-f1 1280 720" "hd-f0 1280 720"; do
  read -r _n _l _a <<<"$c"     # (o afirma usa $1: nada de parametros posicionais aqui)
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
# a imagem HD (correcao de 4 pontos inclinada) esta mais torta que a do boot anterior
afirma 'compara "abs($(chave hd-f1 inclinacao_graus)) > abs($(chave f1 inclinacao_graus)) + 1"' "calibracao-hd-f1 deveria ter inclinacao maior que calibracao-f1"
# valores medidos em 2026-10-30 (sinal: positivo = faixas descem para a direita no quadro)
afirma 'compara "2.6 < $(chave hd-f1 inclinacao_graus) < 3.1 and 10 < $(chave hd-f1 trapezio_pct) < 15"' "calibracao-hd-f1 fora do medido (2,82 graus, trapezio 12,5%)"
afirma 'compara "0.4 < $(chave f1 inclinacao_graus) < 0.9"' "calibracao-f1 fora do medido (0,64 graus)"

# quadros sinteticos de geometria conhecida: 16 faixas (230 sobre 20), borda em rampa de R px
# (10-90% = 0,8 R), inclinacao A graus, pilha T vezes mais alta na borda direita que na esquerda
sintetico(){ # saida A R T
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
sint_geo(){ # nome A R T
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
# T=1,1 na borda direita: nas janelas (18% e 82%) a razao das alturas e 1,082/1,018 = +6,3%
sint_geo c 0 4 1.1
afirma '[ "$_rc" = 0 ] && compara "5.8 < $(chave sc trapezio_pct) < 6.8 and abs($(chave sc inclinacao_graus)) < 0.1"' "sintetico trapezio 6,3%: valor errado"
afirma 'compara "3.2 <= $(chave sc borda_centro_px) < 3.9"' "sintetico R=4: borda fora de [0,8R, 0,8R+0,7]"
afirma 'compara "0.88 < $(chave sc contraste_centro) < 0.94"' "sintetico: contraste (230-20)/230 = 0,91 fora"

# sem faixas nas tres colunas: sai 3 (escada no lugar da calibracao; quadro preto)
"$NL" geometria "arquivo:$FIX/escada-hd-f1.yuyv:1280:720" "$T/gfx-hd-f1.txt" >/dev/null 2>"$T/g3.err"; rc=$?
afirma '[ "$rc" = 3 ] && grep -q "esperadas 16" "$T/g3.err"' "escada no lugar da calibracao deveria sair 3 (saiu $rc)"
head -c $((1280*720*2)) /dev/zero > "$T/preto.yuyv"
"$NL" geometria "arquivo:$T/preto.yuyv:1280:720" "$T/gfx-hd-f1.txt" >"$T/g3b.out" 2>/dev/null; rc=$?
afirma '[ "$rc" = 3 ] && [ ! -s "$T/g3b.out" ]' "quadro preto deveria sair 3 sem imprimir chaves (saiu $rc)"
# nao conseguiu ler: sai 1
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

# so leitura: o fonte nao tem S_CTRL nem escreve controle
afirma '! grep -q "VIDIOC_S_CTRL\|VIDIOC_S_EXT_CTRLS" "$ROOT/artifacts/camcheck/nl_camcheck.c"' "o nl_camcheck passou a escrever controle da camera"
# o binario ARM do kit e o versionado em artifacts/ sao o mesmo
afirma 'cmp -s "$ROOT/artifacts/camcheck/nl_camcheck" "$ROOT/pendrive-autorun/nl_camcheck"' "pendrive-autorun/nl_camcheck difere de artifacts/camcheck/nl_camcheck"
afirma 'file "$ROOT/pendrive-autorun/nl_camcheck" | grep -q "ELF 32-bit LSB.*ARM"' "pendrive-autorun/nl_camcheck nao e um ELF ARM"
# e e o binario deste .c (bloco 9A mudou o fonte): recompila com o NDK, se houver, e compara
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
