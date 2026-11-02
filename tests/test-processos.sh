#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export LC_ALL=C
SCRIPT="$ROOT/pfl7560-processos.sh"
FIX="$ROOT/tests/fixtures/processos"
FALHAS=0; TESTES=0; CASO="-"
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== analise da saida gravada do top =="
CASO="analise com amostras"
bash "$SCRIPT" --analisar "$FIX/top-android9.txt" --amostras "$FIX/amostras.txt" > "$TMP/r.txt" 2>"$TMP/e.txt"; RC=$?
afirma '[ "$RC" = 0 ]' "rc=$RC: $(cat "$TMP/e.txt")"
afirma '[ "$(grep -cE "^ +[0-9.]+%  [0-9]+ " "$TMP/r.txt")" = 10 ]' "a tabela nao tem exatamente 10 linhas"
ordem="$(grep -E '^ +[0-9.]+%  [0-9]+ ' "$TMP/r.txt" | awk '{print $3}' | tr '\n' ' ')"
afirma '[ "$ordem" = "system_server surfaceflinger com.zhiying.autofocus xiriservice kworker/u8:3 adbd com.newlink.hisetting top logd mmcqd/0 " ]' "ordem dos 10 que mais gastam: $ordem"
afirma '! grep -qE "^ +(19|12|9)\.[05]%" "$TMP/r.txt"' "usou a tela do top desde o boot em vez da ultima (janela)"
afirma 'grep -qE "^ +3.3%  2231 +com.zhiying.autofocus +autofoco +SIM" "$TMP/r.txt" && grep -qE "xiriservice.*SIM" "$TMP/r.txt"' "autofoco e xiriservice deveriam ser candidatos"
afirma 'grep -E "system_server|surfaceflinger|kworker|adbd|logd|top " "$TMP/r.txt" | grep -E "^ +[0-9.]+%  [0-9]+ " | grep -vq SIM' "um processo essencial virou candidato"
afirma 'grep -E "hisetting" "$TMP/r.txt" | grep -q " nao "' "hisetting (1.0 %, abaixo do limite) deveria ser nao"
afirma 'grep -q "ocupada: 5.5 % do total" "$TMP/r.txt" && grep -q "4 nucleo" "$TMP/r.txt"' "CPU geral errada"
afirma 'grep -q "na ultima tela do top: kworker/u8:3(390) jbd2/mmcblk0p13-(95)" "$TMP/r.txt"' "estado D da ultima tela"
afirma 'grep -qE "kworker/u8:3 +visto em D em 4 amostra" "$TMP/r.txt" && grep -qE "jbd2/mmcblk0p13- +visto em D em 2 amostra" "$TMP/r.txt"' "contagem de estado D nas amostras"
afirma 'grep -q "sensor quente (zysys.env_temp, bloco do LED): 36 -> 37 C" "$TMP/r.txt" && grep -q "placa (zysys.light_temp): 30 -> 31 C" "$TMP/r.txt"' "cruzamento com as props"
afirma 'grep -q "CPU ocupada em apenas 5.5" "$TMP/r.txt" && grep -q "estado D" "$TMP/r.txt" && grep -q "NAO desliga nada" "$TMP/r.txt"' "leitura final"

CASO="analise sem amostras"
bash "$SCRIPT" --analisar "$FIX/top-android9.txt" > "$TMP/r2.txt" 2>&1; RC=$?
afirma '[ "$RC" = 0 ] && grep -q "sem amostras" "$TMP/r2.txt" && grep -q "^Os 10 que mais gastam" "$TMP/r2.txt"' "rc=$RC"

CASO="saida em arquivo"
bash "$SCRIPT" --analisar "$FIX/top-android9.txt" --amostras "$FIX/amostras.txt" --saida "$TMP/sub/pasta/saida.txt" >/dev/null 2>&1
afirma 'cmp -s "$TMP/sub/pasta/saida.txt" "$TMP/r.txt"' "arquivo de saida difere do resumo"

CASO="entradas ruins"
printf 'lixo\nsem top\n' > "$TMP/lixo.txt"; : > "$TMP/vazio.txt"
bash "$SCRIPT" --analisar "$TMP/lixo.txt" >/dev/null 2>"$TMP/e.txt"; RC=$?
afirma '[ "$RC" = 1 ] && grep -q "nao reconheci" "$TMP/e.txt"' "lixo: rc=$RC"
bash "$SCRIPT" --analisar "$TMP/vazio.txt" >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 1 ]' "arquivo vazio: rc=$RC"
bash "$SCRIPT" --analisar "$TMP/nao-existe.txt" >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 1 ]' "arquivo inexistente: rc=$RC"
bash "$SCRIPT" --analisar >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 2 ]' "--analisar sem arquivo: rc=$RC"
bash "$SCRIPT" --nada >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 2 ]' "argumento desconhecido: rc=$RC"

echo "== coleta com adb de mentira =="
BIN="$TMP/bin"; mkdir -p "$BIN"
cat > "$BIN/adb" <<'EOF'
#!/bin/sh
echo "adb $*" >> "$T/adb.log"
case "$*" in
  connect*) echo "connected"; exit 0 ;;
  *"getprop ro.product.model"*) echo "${MODELO:-PFL7560}"; exit 0 ;;
  *" top "*) cat "$FIX/top-android9.txt"; exit 0 ;;
  *"cat /proc/loadavg"*) printf '7.20 7.29 6.90 1/412 5555\n36\xe2\x84\x83\n30\xe2\x84\x83\nD 390 kworker/u8:3\n'; exit 0 ;;
esac
exit 1
EOF
chmod +x "$BIN/adb"
roda(){ ( cd "$TMP/cwd" && env T="$TMP" FIX="$FIX" PATH="$BIN:$PATH" "$@" ) ; }
mkdir -p "$TMP/cwd"
CASO="coleta ok"
: > "$TMP/adb.log"
roda env PFL_IP=10.0.0.9 PFL_INTERVALO=1 bash "$SCRIPT" --segundos 10 > "$TMP/c.out" 2>"$TMP/c.err"; RC=$?
afirma '[ "$RC" = 0 ]' "rc=$RC: $(tail -3 "$TMP/c.err" | tr '\n' ' ')"
arq="$(ls "$TMP"/cwd/evidencias/processos/*.txt 2>/dev/null | head -1)"
afirma '[ -n "$arq" ] && [ "$(ls "$TMP"/cwd/evidencias/processos/*.txt | wc -l | tr -d " ")" = 1 ]' "nao gravou exatamente um arquivo em evidencias/processos/"
afirma 'grep -q "^Os 10 que mais gastam" "$arq" && grep -q "^---- dados brutos: ultima tela do top" "$arq" && grep -q "^A|" "$arq"' "arquivo sem o resumo e os dados brutos"
afirma '[ "$(grep -c "^A|" "$arq")" -ge 5 ] && grep -q "kworker/u8:3 .*visto em D" "$arq"' "poucas amostras ou sem o estado D: $(grep -c '^A|' "$arq") amostras"
afirma 'grep -q "^Os 10 que mais gastam" "$TMP/c.out"' "o resumo nao foi para a tela"
afirma 'grep -q "adb -s 10.0.0.9:5555 shell top -b -n 2 -d 10" "$TMP/adb.log"' "nao chamou o top com a janela pedida: $(grep top "$TMP/adb.log" | head -1)"
afirma '[ "$(grep -vE "^adb (connect|-s [0-9.:]+ shell (getprop ro.product.model|top -b -n 2 -d 10|cat /proc/loadavg))" "$TMP/adb.log" | wc -l | tr -d " ")" = 0 ]' "comando fora da lista de leitura: $(grep -vE '^adb (connect|-s [0-9.:]+ shell (getprop ro.product.model|top -b -n 2 -d 10|cat /proc/loadavg))' "$TMP/adb.log" | head -2)"

CASO="coleta com --saida"
roda env PFL_IP=10.0.0.9 PFL_INTERVALO=1 bash "$SCRIPT" --segundos 10 --saida "$TMP/fora/res.txt" >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 0 ] && [ -s "$TMP/fora/res.txt" ]' "rc=$RC"

CASO="coleta: recusas"
roda env bash "$SCRIPT" --segundos 10 >/dev/null 2>"$TMP/e.txt"; RC=$?
afirma '[ "$RC" = 2 ] && grep -q "PFL_IP" "$TMP/e.txt"' "sem PFL_IP: rc=$RC"
roda env PFL_IP=10.0.0.9 MODELO=OUTRO bash "$SCRIPT" --segundos 10 >/dev/null 2>"$TMP/e.txt"; RC=$?
afirma '[ "$RC" = 2 ] && grep -q "nao e um PFL7560" "$TMP/e.txt"' "outro modelo: rc=$RC"
roda env PFL_IP=10.0.0.9 bash "$SCRIPT" --segundos 5 >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 2 ]' "janela de 5 s: rc=$RC"
roda env PFL_IP=10.0.0.9 bash "$SCRIPT" --segundos abc >/dev/null 2>&1; RC=$?
afirma '[ "$RC" = 2 ]' "janela nao numerica: rc=$RC"

CASO="estaticos"
afirma 'bash -n "$SCRIPT"' "bash -n"
afirma '! grep -vE "^[[:space:]]*#" "$SCRIPT" | grep -E "shell[^#]*(hidebug|gtt|setprop|reboot)"' "o script manda hidebug/gtt/setprop/reboot ao aparelho"
afirma '[ -x "$SCRIPT" ]' "sem +x"
if command -v shellcheck >/dev/null 2>&1; then afirma 'shellcheck "$SCRIPT"' "shellcheck"; else echo "  (shellcheck ausente: etapa pulada)"; fi

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
