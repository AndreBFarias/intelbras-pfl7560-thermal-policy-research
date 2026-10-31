#!/usr/bin/env bash
# shellcheck disable=SC2016
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export LC_ALL=C
SCRIPT="$ROOT/pfl7560-qualidade.sh"
FALHAS=0; TESTES=0; CASO="-"
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"; mkdir -p "$BIN"

cat > "$BIN/adb" <<'EOF'
#!/bin/sh
printf "%s\n" "adb $*" >> "$T/adb.log"
[ "$1" = "connect" ] && { echo "connected to $2"; exit 0; }
[ "$1" = "-s" ] && shift 2
case "$1" in
  root) [ -f "$T/sem-root" ] || : > "$T/root-ok"; exit 0 ;;
  shell) shift; cmd="$*" ;;
  *) exit 1 ;;
esac
case "$cmd" in
  id) if [ -f "$T/root-ok" ]; then echo "uid=0(root) gid=0(root)"; else echo "uid=2000(shell) gid=2000(shell)"; fi; exit 0 ;;
  "getprop ro.product.model") echo "${MODELO:-PFL7560}"; exit 0 ;;
  *"@@ saida"*)
    for c in gpicm gshr gnr gmemc gdci govs; do
      echo "@@ $c"
      if [ -f "$T/hb-negado" ]; then echo "open /dev/hidebug fail, errno = 13"; continue; fi
      v=$(sed -n "s/^$c=//p" "$T/pq")
      if [ -n "$v" ]; then printf 'picture>%s\r\n%s : %s\r\n' "$c" "$c" "$v"; else echo "picture>unknown command"; fi
    done
    echo "@@ saida"; cat "$T/saida"; exit 0 ;;
  *"| /vendor/bin/hidebug"*)
    s=$(printf "%s\n" "$cmd" | sed -n 's/^printf .picture\\n\(s[a-z]*\) \([0-9]*\)\\nquit\\n. | \/vendor\/bin\/hidebug$/\1 \2/p')
    [ -n "$s" ] || exit 1
    [ -f "$T/trava" ] && exit 0
    g="g${s%% *}"; g="g${g#gs}"; v="${s#* }"
    grep -v "^$g=" "$T/pq" > "$T/pq.novo"; echo "$g=$v" >> "$T/pq.novo"; mv "$T/pq.novo" "$T/pq"
    exit 0 ;;
esac
exit 1
EOF
chmod +x "$BIN/adb"

cenario(){
  CASO="$1"; T="$TMP/c$((TESTES))"; rm -rf "$T"; mkdir -p "$T"
  printf 'gpicm=1\ngshr=75\ngnr=2\ngmemc=3\ngdci=1\ngovs=0\n' > "$T/pq"
  printf '1080P\nfalse\nPhysical size: 1920x1080\n' > "$T/saida"
  : > "$T/adb.log"
}
roda(){
  local entrada="$1"; shift
  printf '%s' "$entrada" | env T="$T" PATH="$BIN:$PATH" PFL_IP="${IP_TESTE-10.0.0.9}" PFL_BACKUPS="$T/bk" ${MODELO:+MODELO="$MODELO"} bash "$SCRIPT" "$@" > "$T/out" 2> "$T/err"; RC=$?
}
pq(){ sed -n "s/^$1=//p" "$T/pq"; }
sets(){ grep -o 'picture\\ns[a-z]* [0-9]*' "$T/adb.log" | sed 's/picture\\n//' | tr '\n' '|'; }
linha(){ grep -E "^  $1 " "$T/out"; }

echo "== so leitura =="
cenario "--lista (sem aparelho)"
roda "" --lista
afirma '[ "$RC" = 0 ] && [ ! -s "$T/adb.log" ]' "rc=$RC adb=$(head -2 "$T/adb.log")"
afirma '[ "$(grep -cE "^(modo|nitidez|nr|memc|dci|overscan|saida) " "$T/out")" = 7 ]' "lista: $(cat "$T/out")"

cenario "leitura com 5 ajustes fora do maximo"
roda ""
afirma '[ "$RC" = 0 ]' "rc=$RC: $(cat "$T/err")"
afirma 'linha modo | grep -qE "^  modo +1 +0 ou 3 +fora "' "modo: $(linha modo)"
afirma 'linha nitidez | grep -qE "^  nitidez +75 +50 +fora "' "nitidez: $(linha nitidez)"
afirma 'linha nr | grep -qE " 2 +0 +fora " && linha memc | grep -qE " 3 +0 +fora " && linha dci | grep -qE " 1 +0 +fora "' "nr/memc/dci: $(linha nr) $(linha memc) $(linha dci)"
afirma 'linha overscan | grep -qE " 0 +0 +ok "' "overscan: $(linha overscan)"
afirma 'linha saida | grep -qE "^  saida +1080P +1080P +ok +painel 1920x1080"' "saida: $(linha saida)"
afirma 'grep -q "5 ajuste(s) fora do maximo" "$T/out"' "contagem: $(grep fora "$T/out" | tail -1)"
afirma '[ -z "$(sets)" ] && [ "$(pq gshr)" = 75 ]' "mudou algo so lendo: $(sets)"
afirma '[ -z "$(grep -vE "^adb (connect [0-9.:]+|-s [0-9.:]+ (root|shell id|shell getprop ro.product.model|shell for c in gpicm gshr gnr gmemc gdci govs ; do .*@@ saida.*))$" "$T/adb.log")" ]' "comando fora da lista de leitura: $(grep -vE "@@ saida|connect|root|shell id|ro.product.model" "$T/adb.log" | head -2)"
afirma '[ ! -d "$T/bk" ]' "criou backup so lendo"

cenario "leitura com tudo no maximo e a UI em 720p"
printf 'gpicm=3\ngshr=50\ngnr=0\ngmemc=0\ngdci=0\ngovs=0\n' > "$T/pq"
printf '1080P\ntrue\nPhysical size: 1280x720\n' > "$T/saida"
roda ""
afirma '[ "$RC" = 0 ] && linha modo | grep -q " ok " && linha saida | grep -qE " fora +painel 1280x720, persist.display.720p=true"' "saida: $(linha saida)"
afirma 'grep -q "1 ajuste(s) fora do maximo" "$T/out"' "contagem: $(tail -4 "$T/out")"

cenario "leitura sem resposta do hidebug = sem leitura, nada inventado"
: > "$T/pq"
roda ""
afirma '[ "$RC" = 0 ] && [ "$(grep -c "sem leitura" "$T/out")" = 6 ] && linha nitidez | grep -qE " \? "' "saida: $(cat "$T/out")"

echo "== aplicar e voltar =="
cenario "--aplicar nitidez com MUDAR = guarda 75, poe 50 e rele"
roda "MUDAR" --aplicar nitidez
afirma '[ "$RC" = 0 ] && [ "$(pq gshr)" = 50 ]' "rc=$RC gshr=$(pq gshr): $(cat "$T/err")"
afirma '[ "$(head -1 "$T/bk/nitidez.txt")" = 75 ]' "backup: $(cat "$T/bk/nitidez.txt" 2>/dev/null)"
afirma '[ "$(sets)" = "sshr 50|" ]' "comandos de mudanca: $(sets)"
afirma '[ "$(pq gpicm)" = 1 ] && [ "$(pq gnr)" = 2 ]' "mexeu em outro ajuste"
afirma 'grep -q "nitidez = 50 (relido)" "$T/err"' "sem a releitura: $(cat "$T/err")"
echo "gshr=60" >> "$T/pq"; sed -i '/^gshr=50$/d' "$T/pq"
roda "MUDAR" --aplicar nitidez
afirma '[ "$RC" = 0 ] && [ "$(pq gshr)" = 50 ] && [ "$(head -1 "$T/bk/nitidez.txt")" = 75 ]' "rc=$RC gshr=$(pq gshr) backup=$(head -1 "$T/bk/nitidez.txt")"
roda "MUDAR" --voltar nitidez
afirma '[ "$RC" = 0 ] && [ "$(pq gshr)" = 75 ] && [ ! -e "$T/bk/nitidez.txt" ]' "voltar: rc=$RC gshr=$(pq gshr): $(cat "$T/err")"
roda "MUDAR" --voltar nitidez
afirma '[ "$RC" = 1 ] && grep -q "nao ha valor guardado" "$T/err" && [ "$(pq gshr)" = 75 ]' "voltar sem backup: rc=$RC"

cenario "--aplicar modo vai ao padrao (0); --aplicar memc"
roda "MUDAR" --aplicar modo
afirma '[ "$RC" = 0 ] && [ "$(pq gpicm)" = 0 ] && [ "$(head -1 "$T/bk/modo.txt")" = 1 ]' "modo: rc=$RC $(pq gpicm)"
roda "MUDAR" --aplicar memc
afirma '[ "$RC" = 0 ] && [ "$(pq gmemc)" = 0 ] && [ "$(sets)" = "spicm 0|smemc 0|" ]' "memc: rc=$RC $(sets)"

cenario "--aplicar sem a palavra = nada muda"
for resp in "" "sim" "mudar"; do
  roda "$resp" --aplicar nitidez
  afirma '[ "$RC" = 2 ] && [ "$(pq gshr)" = 75 ] && [ -z "$(sets)" ] && [ ! -e "$T/bk/nitidez.txt" ]' "resposta '$resp': rc=$RC gshr=$(pq gshr) $(sets)"
done

cenario "--aplicar com o ajuste ja no sugerido = nada a mudar, sem pergunta"
roda "" --aplicar overscan
afirma '[ "$RC" = 0 ] && grep -q "ja esta em 0" "$T/err" && [ -z "$(sets)" ]' "rc=$RC: $(cat "$T/err")"

cenario "--aplicar sem ler o valor atual = recusa"
grep -v '^gnr=' "$T/pq" > "$T/pq.n"; mv "$T/pq.n" "$T/pq"
roda "MUDAR" --aplicar nr
afirma '[ "$RC" = 1 ] && grep -q "nao li o valor atual de nr" "$T/err" && [ -z "$(sets)" ] && [ ! -d "$T/bk" ]' "rc=$RC: $(cat "$T/err")"

cenario "--aplicar e o aparelho nao muda = erro, o antigo fica guardado"
: > "$T/trava"
roda "MUDAR" --aplicar dci
afirma '[ "$RC" = 1 ] && grep -q "dci: pedi 0 e o aparelho releu .1." "$T/err" && [ "$(head -1 "$T/bk/dci.txt")" = 1 ]' "rc=$RC: $(cat "$T/err")"

echo "== recusas =="
cenario "argumentos"
roda "" --aplicar
afirma '[ "$RC" = 2 ]' "--aplicar sem nome: rc=$RC"
roda "" --aplicar foco
afirma '[ "$RC" = 2 ] && grep -q "ajuste desconhecido: foco" "$T/err" && [ ! -s "$T/adb.log" ]' "ajuste desconhecido: rc=$RC"
roda "" --nada
afirma '[ "$RC" = 2 ]' "argumento desconhecido: rc=$RC"

cenario "conexao"
IP_TESTE="" roda ""
afirma '[ "$RC" = 2 ] && grep -q "PFL_IP" "$T/err" && [ ! -s "$T/adb.log" ]' "sem PFL_IP: rc=$RC"
MODELO=OUTRO roda ""
afirma '[ "$RC" = 2 ] && grep -q "NAO e um PFL7560" "$T/err" && ! grep -q "@@" "$T/adb.log"' "outro modelo: rc=$RC"
rm -f "$T/root-ok"; : > "$T/sem-root"
roda "MUDAR" --aplicar nitidez
afirma '[ "$RC" = 2 ] && grep -q "sem root" "$T/err" && [ "$(pq gshr)" = 75 ]' "sem root: rc=$RC"
rm -f "$T/sem-root"; : > "$T/hb-negado"
roda ""
afirma '[ "$RC" = 1 ] && grep -q "errno = 13" "$T/err"' "hidebug negado: rc=$RC"

echo "== estaticos =="
CASO="estaticos"
afirma 'bash -n "$SCRIPT"' "bash -n"
afirma '[ -x "$SCRIPT" ]' "sem +x"
afirma '! grep -vE "^[[:space:]]*#" "$SCRIPT" | grep -qE "gtt|sfd|gfd|snk|setprop|/proc/msp/(gpio|pq)|ProjectionService"' "o script cita comando proibido fora de comentario"
if command -v shellcheck >/dev/null 2>&1; then afirma 'shellcheck "$SCRIPT"' "shellcheck"; else echo "  (shellcheck ausente: etapa pulada)"; fi

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
