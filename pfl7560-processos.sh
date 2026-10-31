#!/usr/bin/env bash
# pfl7560-processos.sh - quem gasta CPU em segundo plano com o projetor PARADO (bloco 9C).
# SO LEITURA: nada e escrito, desligado ou configurado no aparelho. Sem hidebug nem gtt.
#
# POR QUE: o dono perguntou se processos desnecessarios em segundo plano ajudam a esquentar
# (a carga media fica em ~7 com o projetor parado, mas no Android a carga conta tambem threads
# esperando disco). Esta ferramenta so MEDE; o sensor quente (gtt1, props zysys.env_temp) mede o
# bloco do LED, nao o processador. Ela cruza a CPU com a temperatura lida das props.
#
# COMO MEDE (por padrao 60 s): um "top -b -n 2 -d <s>" (a 2a tela e a CPU media da janela) e, em
# paralelo, a cada 5 s uma leitura de /proc/loadavg, das props zysys.env_temp e zysys.light_temp e
# dos processos em estado D (/proc/<pid>/stat). Tudo por "adb shell", so comandos de leitura.
# Deixe o projetor PARADO: tela inicial, sem video, sem app aberto, sem teste rodando.
#
# SAIDA: evidencias/processos/<data>.txt com o resumo legivel (os 10 que mais gastam, o que cada um
# e quando conhecido, se algum e CANDIDATO a desligar - so um aviso, nada e desligado), seguido dos
# dados brutos. O formato do "top" do Android 9 e o do toybox ("S[%CPU]" no cabecalho): o parser acha
# as colunas pelo cabecalho. PROVISORIO ate rodar no aparelho (tests/fixtures/processos/ tem uma
# saida de exemplo no formato esperado).
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-processos.sh [--segundos 60] [--saida arquivo.txt]
#   ./pfl7560-processos.sh --analisar <top.txt> [--amostras <amostras.txt>] [--saida arquivo.txt]
#       (sem aparelho: le uma saida de top ja gravada; e o que o harness tests/test-processos.sh usa)
set -u
# Locale fixo: o awk (mawk) segue LC_NUMERIC e em pt_BR imprime virgula e le "65.8" como 65
export LC_ALL=C

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
SEG=60
SAIDA=""
TOP_ARQ=""
AMOSTRAS_ARQ=""
INTERVALO="${PFL_INTERVALO:-5}"   # so o harness muda (tests/test-processos.sh)
# PROVISORIO: um processo so e CANDIDATO a desligar se usar pelo menos isto de UM nucleo na
# media da janela (toybox top: 100 % = um nucleo) e nao for essencial (lista abaixo).
CANDIDATO_CPU_PCT=2.0
# nomes (regex estendida, sobre o nome do processo) que nunca viram candidato
ESSENCIAIS='^(init|ueventd|logd|lmkd|vold|netd|zygote|zygote64|servicemanager|hwservicemanager|vndservicemanager|surfaceflinger|system_server|adbd|top|sh|toybox|toolbox|hidebug|logcat|mediaserver|healthd|keystore|installd|android\.hardware\..*|android\.hidl\..*|vendor\..*|com\.newlink\.hisilauncher|kworker.*|ksoftirqd.*|kswapd.*|mmcqd.*|jbd2.*|migration.*|rcu_.*|irq/.*|watchdog.*|cpuhp.*|kthreadd|kblockd|dmcrypt.*|loop[0-9]*)$'

X='\033[1;31m'; A='\033[1;33m'; C='\033[1;36m'; Z='\033[0m'
err(){ printf "${X}[ERRO]${Z}  %s\n" "$*" >&2; }
warn(){ printf "${A}[AVISO]${Z} %s\n" "$*" >&2; }
say(){ printf "${C}%s${Z}\n" "$*" >&2; }

ajuda(){ sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------- analise
# Le o top (a ULTIMA tela) e as amostras e escreve o resumo legivel em stdout.
# amostras: linhas "A|epoch|carga1 carga5 carga15|env|luz" e "D|pid|nome"
analisar(){
  local top="$1" amostras="${2:-}" norm
  [ -s "$top" ] || { err "top vazio ou inexistente: $top"; return 1; }
  norm="$(mktemp)"
  # 1) normaliza a ultima tela do top: linhas "#META chave=valor" e "P<TAB>pid<TAB>usuario<TAB>estado<TAB>cpu<TAB>nome<TAB>args"
  awk '
    function nome_de(s,   t) {      # primeiro token do ARGS, sem caminho e sem colchetes
      t = s; sub(/ .*/, "", t); sub(/^\[/, "", t); sub(/\]$/, "", t); if (t ~ /^\//) sub(/.*\//, "", t); return t
    }
    /^ *Tasks:/ { tela++; ncpu = 0; idle = ""; usr = ""; sys = ""; cab = 0; nlin = 0; tasks = $0; next }
    tela == 0 { next }
    /%cpu/ && ncpu == 0 {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9.]+%cpu$/) { v = $i; sub(/%cpu/, "", v); ncpu = v / 100 }
        else if ($i ~ /^[0-9.]+%idle$/) { v = $i; sub(/%idle/, "", v); idle = v }
        else if ($i ~ /^[0-9.]+%user$/) { v = $i; sub(/%user/, "", v); usr = v }
        else if ($i ~ /^[0-9.]+%sys$/) { v = $i; sub(/%sys/, "", v); sys = v }
      }
      next
    }
    /PID/ && /(ARGS|NAME|COMMAND)/ && cab == 0 {
      nc = 0
      for (i = 1; i <= NF; i++) {
        if ($i == "S[%CPU]") { col[++nc] = "S"; col[++nc] = "%CPU" } else { col[++nc] = $i }
      }
      cab = nc; next
    }
    cab > 0 && $1 ~ /^[0-9]+$/ {
      nlin++
      pid = $1; usuario = ""; estado = ""; cpu = ""; args = ""
      for (c = 1; c < cab; c++) {
        if (col[c] == "USER") usuario = $c
        else if (col[c] == "S") estado = $c
        else if (col[c] == "%CPU") cpu = $c
      }
      for (c = cab; c <= NF; c++) args = args (c > cab ? " " : "") $c
      L[nlin] = "P\t" pid "\t" usuario "\t" estado "\t" cpu "\t" nome_de(args) "\t" args
    }
    END {
      if (tela == 0 || cab == 0 || nlin == 0) { print "#ERRO sem tela de top reconhecivel" ; exit }
      print "#META ncpu=" (ncpu > 0 ? ncpu : 1) " idle=" idle " user=" usr " sys=" sys " processos=" nlin
      for (i = 1; i <= nlin; i++) print L[i]
    }
  ' "$top" > "$norm"
  if grep -q '^#ERRO' "$norm"; then
    err "nao reconheci uma tela do top em $top (preciso do cabecalho com PID e ARGS e das linhas de processo)."
    rm -f "$norm"; return 1
  fi
  local meta ncpu idle usr sys nproc
  meta="$(sed -n 's/^#META //p' "$norm")"
  ncpu="$(printf '%s' "$meta" | sed -n 's/.*ncpu=\([0-9.]*\).*/\1/p')"
  idle="$(printf '%s' "$meta" | sed -n 's/.*idle=\([0-9.]*\).*/\1/p')"
  usr="$(printf '%s' "$meta" | sed -n 's/.*user=\([0-9.]*\).*/\1/p')"
  sys="$(printf '%s' "$meta" | sed -n 's/.*sys=\([0-9.]*\).*/\1/p')"
  nproc="$(printf '%s' "$meta" | sed -n 's/.*processos=\([0-9]*\).*/\1/p')"

  echo "PFL7560 - processos em segundo plano (so leitura)"
  echo "=================================================="
  echo
  echo "CPU geral na janela (ultima tela do top): $nproc processos, $ncpu nucleo(s)."
  if [ -n "$idle" ]; then
    awk -v i="$idle" -v u="${usr:-0}" -v s="${sys:-0}" -v n="$ncpu" 'BEGIN{
      # o toybox mostra 100 % por nucleo: idle/ncpu e a fracao ociosa do total
      oc = 100 - i / n
      printf "  ocupada: %.1f %% do total (usuario %.1f %%, sistema %.1f %%); ociosa: %.1f %%\n", oc, u / n, s / n, i / n }'
  else
    echo "  (a linha de CPU do top nao veio: so a tabela abaixo)"
  fi
  echo
  echo "Os 10 que mais gastam (CPU em % de UM nucleo; % do total entre parenteses):"
  printf '  %6s  %-6s  %-26s  %-44s  %s\n' "CPU" "PID" "NOME" "O QUE E" "CANDIDATO?"
  grep '^P	' "$norm" | sort -t'	' -k5,5nr -k2,2n | head -10 | awk -F'\t' -v n="$ncpu" -v lim="$CANDIDATO_CPU_PCT" -v ess="$ESSENCIAIS" '
    function desc(nm) {
      if (nm ~ /^(kworker|ksoftirqd|kswapd|mmcqd|jbd2|migration|rcu_|irq\/|watchdog|cpuhp|kthreadd|kblockd)/) return "thread do kernel"
      if (nm == "system_server") return "servidor do Android (essencial)"
      if (nm == "surfaceflinger") return "composicao da tela (essencial)"
      if (nm == "adbd") return "ponte adb (a propria medida passa por ele)"
      if (nm == "top") return "este comando de medida"
      if (nm == "logd") return "log do sistema"
      if (nm == "xiriservice") return "assistente de voz (o kit o desliga no boot)"
      if (nm == "com.zhiying.autofocus") return "autofoco"
      if (nm == "com.newlink.hisetting") return "ajustes do projetor (hisetting)"
      if (nm == "com.newlink.hotkeysservices") return "teclas do controle"
      if (nm == "com.newlink.hisilauncher") return "tela inicial"
      if (nm == "com.hisilicon.miracast") return "espelhamento de tela (miracast)"
      if (nm == "com.hisilicon.higallery") return "galeria"
      if (nm == "com.zhiying.settings") return "configuracoes do fabricante"
      if (nm == "hidebug") return "console de depuracao do firmware"
      return "(nao catalogado)"
    }
    {
      cpu = $5 + 0; nm = $6
      cand = (cpu >= lim && nm !~ ess) ? "SIM: so olhar" : "nao"
      printf "  %5.1f%%  %-6s  %-26s  %-44s  %s  (%.2f %% do total)\n", cpu, $2, substr(nm, 1, 26), desc(nm), cand, cpu / n
    }'
  echo
  echo "  Candidato = usa pelo menos $CANDIDATO_CPU_PCT % de um nucleo na media e nao esta na lista de essenciais."
  echo "  Esta ferramenta NAO desliga nada: ser candidato e so um motivo para olhar com calma."
  echo
  # estado D na ultima tela do top
  local dtop
  dtop="$(grep '^P	' "$norm" | awk -F'\t' '$4 == "D" { printf "%s(%s) ", $6, $2 }')"
  echo "Processos em estado D (esperando disco ou driver):"
  echo "  na ultima tela do top: ${dtop:-nenhum}"
  if [ -n "$amostras" ] && [ -s "$amostras" ]; then
    local na
    na="$(grep -c '^A|' "$amostras")"
    echo "  nas $na amostras (a cada ${INTERVALO} s):"
    if grep -q '^D|' "$amostras"; then
      grep '^D|' "$amostras" | cut -d'|' -f3 | sort | uniq -c | sort -rn | head -10 \
        | awk '{ c = $1; $1 = ""; sub(/^ /, ""); printf "    %-26s visto em D em %d amostra(s)\n", $0, c }'
    else
      echo "    nenhum visto em D"
    fi
    echo
    echo "Carga media e temperatura ao longo da janela (so props, sem hidebug gtt):"
    grep '^A|' "$amostras" | awk -F'|' '
      { split($3, c, " "); l1 = c[1] + 0; e = $4; z = $5
        gsub(/[^0-9.]/, "", e); gsub(/[^0-9.]/, "", z)
        n++
        if (n == 1) { l1a = l1; ea = e; za = z }
        l1b = l1; eb = e; zb = z
        if (e != "") { if (emin == "" || e + 0 < emin) emin = e + 0; if (emax == "" || e + 0 > emax) emax = e + 0 }
        if (z != "") { if (zmin == "" || z + 0 < zmin) zmin = z + 0; if (zmax == "" || z + 0 > zmax) zmax = z + 0 }
      }
      END {
        printf "  carga (1 min): %.2f no inicio, %.2f no fim\n", l1a, l1b
        if (emin != "") printf "  sensor quente (zysys.env_temp, bloco do LED): %s -> %s C  (min %.0f, max %.0f)\n", ea, eb, emin, emax
        if (zmin != "") printf "  placa (zysys.light_temp): %s -> %s C  (min %.0f, max %.0f)\n", za, zb, zmin, zmax
      }'
  else
    echo "  (sem amostras de /proc: so a ultima tela do top)"
  fi
  echo
  echo "Leitura (so o que os numeros dizem):"
  awk -v i="${idle:-}" -v n="$ncpu" -v amostras="$amostras" 'BEGIN{
    if (i == "") { print "  - sem a linha de CPU do top, nao da para dizer quanto da CPU esta ocupada."; exit }
    oc = 100 - i / n
    if (oc < 15) printf "  - CPU ocupada em apenas %.1f %% do total: os processos em segundo plano consomem pouco; sozinhos dificilmente explicam o calor do LED (o sensor quente mede o bloco do LED, nao o processador).\n", oc
    else printf "  - CPU ocupada em %.1f %% do total: ha o que olhar na tabela acima; o calor do SoC soma na caixa, mas o sensor quente continua sendo o do LED.\n", oc
  }'
  if [ -n "$amostras" ] && [ -s "$amostras" ]; then
    local l1 nd
    l1="$(grep '^A|' "$amostras" | tail -1 | cut -d'|' -f3 | cut -d' ' -f1)"
    nd="$(grep '^D|' "$amostras" | cut -d'|' -f3 | sort -u | wc -l | tr -d ' ')"
    awk -v l="${l1:-0}" -v n="$ncpu" -v i="${idle:-100}" -v nd="$nd" 'BEGIN{
      oc = 100 - i / n
      if (l + 0 >= n / 2 && oc < 25 && nd > 0) printf "  - a carga media (%.2f) e alta para uma CPU quase parada e ha %d processo(s) visto(s) em estado D: a carga pode vir de threads esperando disco ou driver, nao de CPU.\n", l, nd
      else if (l + 0 >= n / 2 && oc < 25) printf "  - a carga media (%.2f) e alta para uma CPU quase parada, e nenhum processo foi visto em D nas amostras: a causa nao apareceu nesta medida.\n", l
    }'
  fi
  echo "  - a temperatura medida em ~1 minuto parado quase nao se mexe: isto e um cruzamento, nao uma prova. Para ligar CPU e calor, repita a medida em outras condicoes e compare."
  rm -f "$norm"
}

# ---------------------------------------------------------------- coleta
conecta(){
  [ -n "$IP" ] || { err "defina PFL_IP=<ip do projetor>"; exit 2; }
  case "$IP" in *:*) DEV="$IP" ;; *) DEV="$IP:$PORTA" ;; esac   # PFL_IP pode ja trazer a porta
  timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
  local m; m=$(timeout 15 "$ADB" -s "$DEV" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r\n ')
  [ "$m" = "PFL7560" ] || { err "nao e um PFL7560 em $DEV (model='${m:-vazio}')"; exit 2; }
}
# uma amostra: so leitura. Linha A|epoch|carga|env|luz e uma linha D|pid|nome por processo em estado D
amostra(){
  local saida
  # shellcheck disable=SC2016  # o comando roda no aparelho: as expansoes sao de la
  saida="$(timeout 20 "$ADB" -s "$DEV" shell 'cat /proc/loadavg; getprop zysys.env_temp; getprop zysys.light_temp; for f in $(grep -l ") D " /proc/[0-9]*/stat 2>/dev/null); do p=${f#/proc/}; p=${p%/stat}; echo "D $p $(cat /proc/$p/comm 2>/dev/null)"; done' </dev/null 2>/dev/null | tr -d '\r')"
  [ -n "$saida" ] || return 1
  printf '%s\n' "$saida" | awk -v t="$(date +%s)" '
    NR == 1 { split($0, c, " "); carga = c[1] " " c[2] " " c[3]; next }
    NR == 2 { env = $0; next }
    NR == 3 { luz = $0; printf "A|%s|%s|%s|%s\n", t, carga, env, luz; next }
    $1 == "D" { p = $2; $1 = ""; $2 = ""; sub(/^ +/, ""); printf "D|%s|%s\n", p, $0 }'
}
coleta(){
  case "$SEG" in ''|*[!0-9]*) err "--segundos precisa ser um numero inteiro"; exit 2 ;; esac
  [ "$SEG" -ge 10 ] || { err "--segundos precisa ser pelo menos 10"; exit 2; }
  conecta
  local dia dir tmp fim n falhas=0
  dia="$(date +%Y-%m-%d_%H%M%S)"
  dir="evidencias/processos"
  SAIDA="${SAIDA:-$dir/$dia.txt}"
  mkdir -p "$(dirname "$SAIDA")"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  say "medindo por ${SEG} s: deixe o projetor PARADO (tela inicial, sem video, sem app aberto)"
  # top em segundo plano (a 2a tela e a media da janela) e as amostras de /proc na frente
  ( timeout $((SEG + 40)) "$ADB" -s "$DEV" shell top -b -n 2 -d "$SEG" </dev/null 2>/dev/null | tr -d '\r' > "$tmp/top.txt" ) &
  local top_pid=$!
  : > "$tmp/amostras.txt"
  fim=$(( $(date +%s) + SEG ))
  n=0
  while [ "$(date +%s)" -lt "$fim" ]; do
    if amostra >> "$tmp/amostras.txt"; then n=$((n + 1)); else falhas=$((falhas + 1)); fi
    [ "$falhas" -ge 5 ] && { warn "o aparelho parou de responder (5 falhas): encerrando a medida"; break; }
    sleep "$INTERVALO"
  done
  wait "$top_pid" 2>/dev/null
  [ -s "$tmp/top.txt" ] || { err "o top nao devolveu nada (o aparelho respondeu?)"; exit 1; }
  {
    analisar "$tmp/top.txt" "$tmp/amostras.txt" || exit 1
    echo
    echo "---- dados brutos: ultima tela do top (a 2a, media da janela) ----"
    awk '/^ *Tasks:/ { n++; t = "" } { t = t $0 "\n" } END { printf "%s", t }' "$tmp/top.txt"
    echo "---- dados brutos: amostras (A|epoch|carga|env|luz  e  D|pid|nome) ----"
    cat "$tmp/amostras.txt"
  } > "$SAIDA" || exit 1
  sed -n '1,/^---- dados brutos/p' "$SAIDA" | sed '$d'
  say "salvo em $SAIDA"
}

# -------------------------------------------------------------------- main
MODO=coleta
while [ $# -gt 0 ]; do
  case "$1" in
    --segundos) SEG="${2:-}"; shift 2 || shift ;;
    --saida) SAIDA="${2:-}"; shift 2 || shift ;;
    --analisar) MODO=analisar; TOP_ARQ="${2:-}"; shift 2 || shift ;;
    --amostras) AMOSTRAS_ARQ="${2:-}"; shift 2 || shift ;;
    -h|--help|--ajuda) ajuda; exit 0 ;;
    *) err "argumento desconhecido: $1"; ajuda; exit 2 ;;
  esac
done
if [ "$MODO" = "analisar" ]; then
  [ -n "$TOP_ARQ" ] || { err "--analisar precisa do arquivo do top"; exit 2; }
  if [ -n "$SAIDA" ]; then
    mkdir -p "$(dirname "$SAIDA")"
    analisar "$TOP_ARQ" "$AMOSTRAS_ARQ" | tee "$SAIDA"
    exit "${PIPESTATUS[0]}"
  fi
  analisar "$TOP_ARQ" "$AMOSTRAS_ARQ"
  exit $?
fi
coleta
