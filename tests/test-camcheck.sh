#!/usr/bin/env bash
# tests/test-camcheck.sh - bloco 7 (C1): o nl_camcheck do HOST (mesmo .c do binario ARM)
# sobre as 4 quadros reais de tests/fixtures/camera/ (YUYV 640x480, projetor de verdade,
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

cc -O2 -Wall -Wextra -o "$NL" "$ROOT/artifacts/camcheck/nl_camcheck.c" || { echo "FALHA: nao compilou no host"; exit 1; }
echo "nl_camcheck compilado no host (cc)"

# valores do prototipo (spec do bloco 7, item 6), tolerancia de 2
JEIDA="235 235 235 235 235 232 222 210 197 181 164 141 114 91 72 63"
VESA="235 235 235 231 192 148 105 86 220 212 156 90 185 116 195 128"
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

# so leitura: o fonte nao tem S_CTRL nem escreve controle
afirma '! grep -q "VIDIOC_S_CTRL\|VIDIOC_S_EXT_CTRLS" "$ROOT/artifacts/camcheck/nl_camcheck.c"' "o nl_camcheck passou a escrever controle da camera"
# o binario ARM do kit e o versionado em artifacts/ sao o mesmo
afirma 'cmp -s "$ROOT/artifacts/camcheck/nl_camcheck" "$ROOT/pendrive-autorun/nl_camcheck"' "pendrive-autorun/nl_camcheck difere de artifacts/camcheck/nl_camcheck"
afirma 'file "$ROOT/pendrive-autorun/nl_camcheck" | grep -q "ELF 32-bit LSB.*ARM"' "pendrive-autorun/nl_camcheck nao e um ELF ARM"

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
