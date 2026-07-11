#!/usr/bin/env bash
# ============================================================================
#  pfl7560-evidencias.sh - captura reproduzivel de evidencias (Intelbras PFL7560)
#
#  Qualquer pessoa com um PFL7560 roda este script e obtem o MESMO dossie de
#  prova do defeito de politica termica: leitura dos 2 sensores NTC, curva de
#  aquecimento, ventiladores e o comparativo ANTES (stock) x DEPOIS (corrigido).
#  Descobre o projetor sozinho na rede Wi-Fi (adb TCP 5555) e da o veredito.
#
#  SUBCOMANDOS
#    find                      descobre o projetor na rede e sai
#    status                    diagnostico read-only + veredito STOCK/CORRIGIDO
#    snapshot <antes|depois>   captura pontual (gtt/fans) -> evidencias/<data>/
#    soak <antes|depois> [min] loga NTC+fans por N min (default 10) + le o termometro IR
#    set-thermal <stock|fix>   troca SO o ZYCustom.ini (adb-safe) + reboot
#    report                    consolida antes/depois -> relatorio higienizado
#
#  FLUXO TIPICO (aparelho ja corrigido -> capturar o "antes"):
#    ./pfl7560-evidencias.sh set-thermal stock   # reintroduz o defeito (temporario)
#    ./pfl7560-evidencias.sh soak antes 10        # tela BRANCA 100% no projetor
#    ./pfl7560-evidencias.sh set-thermal fix      # volta ao corrigido
#    ./pfl7560-evidencias.sh soak depois 10
#    ./pfl7560-evidencias.sh report
#
#  SEGURANCA
#   - Conexao por Wi-Fi (adb 5555, ja aberto nesta build userdebug).
#   - Trava universal: so fala com ro.product.model == PFL7560.
#   - set-thermal mexe SO no /vendor/etc/ZYCustom.ini (nunca no build.prop):
#     mantem o Wi-Fi corrigido -> a conexao adb sobrevive ao reboot.
#   - Escrita atomica (.new + confere md5 + mv). Faz backup do .ini atual antes.
#   - NAO toca no bootloader. Reversivel: o stock e a build vivem em artifacts/.
# ============================================================================
set -uo pipefail
PORT=5555

HERE="$(cd "$(dirname "$0")" && pwd)"
ADB="$(command -v adb || true)"; [ -n "$ADB" ] || ADB="$HOME/Android/sdk/platform-tools/adb"
[ -x "$ADB" ] || { echo "ERRO: adb nao encontrado (rode ./install.sh)" >&2; exit 1; }

# caminhos no device (particao /vendor)
INI_VENDOR="/vendor/etc/ZYCustom.ini"
BP="/vendor/build.prop"

# artefatos byte-exatos versionados no repo (fonte de troca stock<->fix)
ART_STOCK="$HERE/artifacts/ZYCustom.ini.ORIGINAL"   # firmware de fabrica
ART_FIX="$HERE/artifacts/ZYCustom_390.ini"          # a build corrigida
MD5_STOCK="29d8ba36149413e899563029df078f6d"
MD5_FIX="1ad641ed2dd99e61d8a987a675e9aced"

# saida do dossie (dados CRUS; gitignored). Um diretorio por dia p/ juntar antes+depois.
OUTDIR="${PFL_OUTDIR:-$HERE/evidencias/$(date +%Y-%m-%d)}"

# sub-rede a varrer: PFL_SUBNET; senao autodetecta pela interface da rota padrao
_DEV="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
SUBNET="${PFL_SUBNET:-$(ip -o -f inet addr show dev "${_DEV:-lo}" 2>/dev/null | awk '{print $4}' | head -1)}"

say(){  printf '\033[1;36m>> %s\033[0m\n' "$*" >&2; }
ok(){   printf '\033[1;32m[OK] %s\033[0m\n' "$*" >&2; }
warn(){ printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
err(){  printf '\033[1;31m[ERRO] %s\033[0m\n' "$*" >&2; }
hr(){   printf '\033[2m%s\033[0m\n' "------------------------------------------------------------" >&2; }
c2(){   awk "BEGIN{printf \"%.1f\", ${1:-0}/1000}"; }   # miliC -> C

# higieniza stdin (redige IP/MAC/SSID) p/ artefatos publicaveis
sanitize(){
  local ip="${1:-}" ssid="${2:-}"
  sed -E \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<IP-REDIGIDO>/g' \
    -e 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/<MAC-REDIGIDO>/g' \
    ${ssid:+-e "s/${ssid//\//\\/}/<SSID-REDIGIDO>/g"}
}

# ---- descoberta: echo do IP do projetor; !=0 se nao achar ----
discover(){
  [ -n "${PFL_IP:-}" ] && { echo "$PFL_IP"; return 0; }
  [ -n "$SUBNET" ] || { err "nao detectei a sub-rede; informe PFL_IP=<ip>"; return 1; }
  command -v nmap >/dev/null || { err "sem nmap; informe PFL_IP=<ip> (ou rode ./install.sh)"; return 1; }
  say "procurando o PFL7560 na rede ($SUBNET, adb $PORT)..."
  local cands ip m
  cands="$(nmap -n -T4 -p "$PORT" --open -oG - "$SUBNET" 2>/dev/null | awk -v p="$PORT" '$0 ~ p"/open"{print $2}')"
  for ip in $cands; do
    "$ADB" connect "$ip:$PORT" >/dev/null 2>&1
    m="$("$ADB" -s "$ip:$PORT" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n ')"
    [ "$m" = "PFL7560" ] && { echo "$ip"; return 0; }
  done
  err "nao achei um PFL7560 na rede. Projetor no mesmo Wi-Fi do PC? Ou use PFL_IP=<ip>."
  return 1
}

# ---- conecta + root + valida o modelo; echo "ip:port" ----
connect(){
  local ip dev u m; ip="$(discover)" || return 1; dev="$ip:$PORT"
  "$ADB" connect "$dev" >/dev/null 2>&1; "$ADB" -s "$dev" wait-for-device >/dev/null 2>&1 || true
  u="$("$ADB" -s "$dev" shell id 2>/dev/null | grep -oE 'uid=[0-9]+')"
  [ "$u" != "uid=0" ] && { "$ADB" -s "$dev" root >/dev/null 2>&1; sleep 2; "$ADB" connect "$dev" >/dev/null 2>&1; "$ADB" -s "$dev" wait-for-device >/dev/null 2>&1 || true; }
  m="$("$ADB" -s "$dev" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n ')"
  [ "$m" = "PFL7560" ] || { err "dispositivo em $ip NAO e PFL7560 (model='$m'). Abortando."; return 1; }
  ok "conectado ao PFL7560 em $ip (root)"
  echo "$dev"
}

# ---- caminho do .ini efetivo (precedencia /atv > /vendor) ----
effective_ini(){
  local d="$1" pid cand
  pid="$("$ADB" -s "$d" shell getprop ro.boot.projectid 2>/dev/null | tr -d '\r\n ')"
  for cand in "/atv/ini/ZYCustom_$pid.ini" "/atv/ini/ZYCustom.ini" "$INI_VENDOR"; do
    "$ADB" -s "$d" shell "[ -f '$cand' ]" 2>/dev/null && { echo "$cand"; return 0; }
  done
  echo "$INI_VENDOR"
}

# ---- le NTC+fans de uma vez; ecoa "gtt0 gtt1 gtt2 fan0 fan1" (miliC / 0-1000) ----
read_hidebug(){
  local d="$1" raw; local -a t f
  raw="$("$ADB" -s "$d" shell 'printf "custom\ngtc\ngtt 0\ngtt 1\ngtt 2\ngfs 0\ngfs 1\nquit\n" | /vendor/bin/hidebug' 2>/dev/null | tr -d '\r')"
  mapfile -t t < <(printf '%s\n' "$raw" | sed -n 's/.*single NTC temperature:\(-\?[0-9]\+\).*/\1/p')
  mapfile -t f < <(printf '%s\n' "$raw" | sed -n 's/.*fan speed:\([0-9]\+\).*/\1/p')
  # sentinela NA nos ausentes: mantem 5 campos p/ o 'read' nao desalinhar coluna
  echo "${t[0]:-NA} ${t[1]:-NA} ${t[2]:-NA} ${f[0]:-NA} ${f[1]:-NA}"
}

# ---- aguarda o projetor voltar do reboot (boot_completed) e re-root ----
wait_boot(){
  local dev="$1" i=0 bc
  say "aguardando o projetor reiniciar (ate ~150s)..."
  sleep 12
  while [ "$i" -lt 46 ]; do
    "$ADB" connect "$dev" >/dev/null 2>&1
    bc="$("$ADB" -s "$dev" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n ')"
    if [ "$bc" = "1" ]; then
      "$ADB" -s "$dev" root >/dev/null 2>&1; sleep 2; "$ADB" connect "$dev" >/dev/null 2>&1
      "$ADB" -s "$dev" wait-for-device >/dev/null 2>&1 || true
      ok "projetor de volta (boot_completed)"; return 0
    fi
    sleep 3; i=$((i+1))
  done
  err "timeout aguardando o boot. Reconecte e rode 'status' p/ conferir."; return 1
}

cmd_find(){ local ip; ip="$(discover)" || exit 1; ok "PFL7560 em: $ip"; echo "$ip"; }

cmd_status(){
  local d ini pid g0 g1 g2 f0 f1 vch wifi xiri diff verdict
  d="$(connect)" || exit 1
  ini="$(effective_ini "$d")"
  pid="$("$ADB" -s "$d" shell getprop ro.boot.projectid 2>/dev/null | tr -d '\r\n ')"
  read -r g0 g1 g2 f0 f1 <<<"$(read_hidebug "$d")"
  vch="$("$ADB" -s "$d" shell "grep -ac 'HW_VIRTUAL_CHANNEL = 1' '$ini'" 2>/dev/null | tr -d '\r\n ')"
  wifi="$("$ADB" -s "$d" shell "grep -a wifi_disconnect_on_boot '$BP'" 2>/dev/null | tr -d '\r')"
  xiri="$("$ADB" -s "$d" shell getprop init.svc.xiriservice 2>/dev/null | tr -d '\r\n ')"
  hr
  say "DIAGNOSTICO PFL7560 (read-only) - projectid=${pid:-?}"
  say "  .ini efetivo : $ini"
  say "  Sensor NTC0  : $(c2 "$g0") C   (miliC=${g0:-?})"
  say "  Sensor NTC1  : $(c2 "$g1") C   (miliC=${g1:-?})   <- 2o sensor (optica)"
  say "  Ventiladores : ${f0:-?} / ${f1:-?}   (escala 0-1000)"
  say "  Mux 2o sensor: 'HW_VIRTUAL_CHANNEL = 1' -> ${vch:-0} ocorrencia(s)"
  say "  Wi-Fi (boot) : ${wifi:-(nao lido)}"
  say "  xiriservice  : ${xiri:-(desabilitado/ausente)}"
  hr
  diff=0; { [ -n "$g0" ] && [ -n "$g1" ]; } && diff=$(( g1 - g0 ))
  if [ "${vch:-0}" -ge 1 ] 2>/dev/null && [ "$diff" -gt 20000 ]; then
    verdict="CORRIGIDO  (2o sensor ativo: NTC1 le o calor real; fans no maximo)"
    printf '\033[1;32m>> VEREDITO: %s\033[0m\n' "$verdict" >&2
  elif { [ -n "$g0" ] && [ -n "$g1" ]; } && [ "${diff#-}" -lt 3000 ]; then
    verdict="STOCK / DEFEITO  (os 2 sensores leem IGUAL: mux morto, optica cega)"
    printf '\033[1;31m>> VEREDITO: %s\033[0m\n' "$verdict" >&2
  else
    verdict="INDETERMINADO  (estado transitorio/parcial; releia em alguns segundos)"
    printf '\033[1;33m>> VEREDITO: %s\033[0m\n' "$verdict" >&2
  fi
  hr
}

cmd_snapshot(){
  local label="${1:-}" d out
  case "$label" in antes|depois) ;; *) err "uso: $0 snapshot <antes|depois>"; exit 1;; esac
  d="$(connect)" || exit 1
  mkdir -p "$OUTDIR"
  out="$OUTDIR/snapshot-$label.txt"
  {
    echo "# snapshot $label - PFL7560 - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# (miliC/1000 = C; fan speed 0-1000)"
    "$ADB" -s "$d" shell 'printf "custom\ngtc\ngtt 0\ngtt 1\ngtt 2\ngfs 0\ngfs 1\nquit\n" | /vendor/bin/hidebug' 2>/dev/null | tr -d '\r'
  } >"$out"
  ok "snapshot salvo: $out"
  sed 's/^/   /' "$out" >&2
}

cmd_soak(){
  local label="${1:-}" mins="${2:-10}" d csv start endt now seg g0 g1 g2 f0 f1 temp
  case "$label" in antes|depois) ;; *) err "uso: $0 soak <antes|depois> [minutos]"; exit 1;; esac
  d="$(connect)" || exit 1
  mkdir -p "$OUTDIR"
  csv="$OUTDIR/soak-$label.csv"
  say "SOAK '$label' por ${mins} min. DEIXE UMA TELA 100% BRANCA no projetor (pior caso termico)."
  say "  Ctrl-C interrompe e mantem o que ja foi gravado."
  echo "epoch,seg,ntc0_c,ntc1_c,ntc2_c,fan0,fan1" >"$csv"
  start="$(date +%s)"; endt=$(( start + mins*60 ))
  while :; do
    now="$(date +%s)"; [ "$now" -ge "$endt" ] && break
    read -r g0 g1 g2 f0 f1 <<<"$(read_hidebug "$d")"
    seg=$(( now - start ))
    printf '%s,%s,%s,%s,%s,%s,%s\n' "$now" "$seg" "$(c2 "$g0")" "$(c2 "$g1")" "$(c2 "$g2")" "${f0:-}" "${f1:-}" >>"$csv"
    printf '\r\033[K   t=%3ds  NTC0=%s C  NTC1=%s C  fans=%s/%s' "$seg" "$(c2 "$g0")" "$(c2 "$g1")" "${f0:-?}" "${f1:-?}" >&2
    sleep 2
  done
  printf '\n' >&2
  ok "curva salva: $csv"
  awk -F, 'NR>1{n++;if(a==""||$3<a)a=$3;if($3>b)b=$3;s+=$3;if(c==""||$4<c)c=$4;if($4>e)e=$4;t+=$4}
    END{if(n)printf "   NTC0 min/med/max: %.1f/%.1f/%.1f C\n   NTC1 min/med/max: %.1f/%.1f/%.1f C\n   amostras: %d\n",a,s/n,b,c,t/n,e,n}' "$csv" >&2
  printf '\033[1;33m   >> Aponte o termometro IR na SAIDA DE AR e digite a leitura (C), ou Enter p/ pular: \033[0m' >&2
  read -r temp
  if [ -n "$temp" ]; then
    printf '%s C (saida de ar, termometro IR) - %s\n' "$temp" "$(date '+%Y-%m-%d %H:%M:%S')" >"$OUTDIR/termometro-$label.txt"
    ok "termometro '$label' = $temp C registrado"
  fi
}

cmd_set_thermal(){
  local target="${1:-}" art md5 d ini ts bkp l r
  case "$target" in
    stock) art="$ART_STOCK"; md5="$MD5_STOCK" ;;
    fix)   art="$ART_FIX";   md5="$MD5_FIX" ;;
    *) err "uso: $0 set-thermal <stock|fix>"; exit 1 ;;
  esac
  [ -f "$art" ] || { err "artefato ausente: $art"; exit 1; }
  l="$(md5sum "$art" | awk '{print $1}')"
  [ "$l" = "$md5" ] || { err "md5 do artefato '$art' ($l) != esperado ($md5). Abortando."; exit 1; }
  if [ "$target" = "stock" ]; then
    warn "set-thermal STOCK reintroduz o DEFEITO termico (mux morto, fans lentos, dimming)."
    warn "A optica vai esquentar. Use so p/ capturar a evidencia 'antes'; volte com 'set-thermal fix'."
    warn "Wi-Fi/xiri NAO sao tocados (adb sobrevive ao reboot)."
  fi
  d="$(connect)" || exit 1
  ini="$(effective_ini "$d")"
  mkdir -p "$OUTDIR/backups"
  ts="$(date +%Y%m%d-%H%M%S)"; bkp="$OUTDIR/backups/ZYCustom.ini.PRE-$ts"
  say "backup do .ini atual do device -> $bkp"
  "$ADB" -s "$d" pull "$ini" "$bkp" >/dev/null 2>&1 || { err "falha ao puxar $ini p/ backup - abortando"; exit 1; }
  [ -s "$bkp" ] || { err "backup veio vazio - abortando (nao vou gravar)"; exit 1; }
  say "remontando /vendor rw"; "$ADB" -s "$d" remount >/dev/null 2>&1
  say "gravando ZYCustom.ini [$target] em $ini (atomico)"
  "$ADB" -s "$d" push "$art" "$ini.new" >/dev/null 2>&1
  r="$("$ADB" -s "$d" shell "md5sum '$ini.new'" 2>/dev/null | awk '{print $1}')"
  if [ "$l" = "$r" ]; then
    "$ADB" -s "$d" shell "chmod 644 '$ini.new' && mv '$ini.new' '$ini'"
  else
    "$ADB" -s "$d" shell "rm -f '$ini.new'" >/dev/null 2>&1
    err "md5 divergente ao gravar $ini (l=$l r=$r) - original intacto"; exit 1
  fi
  r="$("$ADB" -s "$d" shell "md5sum '$ini'" 2>/dev/null | awk '{print $1}')"
  [ "$r" = "$md5" ] || { err "validacao pos-escrita falhou (md5 $r != $md5)"; exit 1; }
  ok "ZYCustom.ini [$target] confirmado no device (md5 $md5)"
  "$ADB" -s "$d" shell sync
  say "reiniciando p/ ativar a nova politica termica"
  "$ADB" -s "$d" reboot >/dev/null 2>&1 || true
  wait_boot "$d" || exit 1
  ok "set-thermal $target aplicado. Rode 'status' p/ confirmar o veredito."
}

cmd_report(){
  local sa="$OUTDIR/soak-antes.csv" sd="$OUTDIR/soak-depois.csv" rep="$OUTDIR/relatorio-antes-depois.md"
  [ -f "$sa" ] || warn "sem soak-antes.csv em $OUTDIR (rode: soak antes)"
  [ -f "$sd" ] || warn "sem soak-depois.csv em $OUTDIR (rode: soak depois)"
  stat(){ [ -f "$1" ] && awk -F, 'NR>1{n++;s0+=$3;if($3>x0)x0=$3;s1+=$4;if($4>x1)x1=$4;sf+=$6}
    END{if(n)printf "%.1f|%.1f|%.1f|%.1f|%d",s0/n,x0,s1/n,x1,(sf/n)}' "$1" || echo "-|-|-|-|-"; }
  local a b ta tb; a="$(stat "$sa")"; b="$(stat "$sd")"
  ta="$( [ -f "$OUTDIR/termometro-antes.txt" ] && cat "$OUTDIR/termometro-antes.txt" || echo '(nao medido)')"
  tb="$( [ -f "$OUTDIR/termometro-depois.txt" ] && cat "$OUTDIR/termometro-depois.txt" || echo '(nao medido)')"
  {
    echo "# PFL7560 - comparativo termico ANTES (stock) x DEPOIS (corrigido)"
    echo
    echo "Gerado em $(date '+%Y-%m-%d %H:%M:%S'). Dados: leitura ao vivo dos NTC via /vendor/bin/hidebug."
    echo "Carga: tela branca 100%. Metodo reproduzivel: pfl7560-evidencias.sh (soak)."
    echo
    echo "| Metrica | ANTES (stock) | DEPOIS (corrigido) |"
    echo "|---|---|---|"
    printf '| NTC0 medio / pico (C) | %s / %s | %s / %s |\n' "$(echo "$a"|cut -d'|' -f1)" "$(echo "$a"|cut -d'|' -f2)" "$(echo "$b"|cut -d'|' -f1)" "$(echo "$b"|cut -d'|' -f2)"
    printf '| NTC1 (2o sensor) medio / pico (C) | %s / %s | %s / %s |\n' "$(echo "$a"|cut -d'|' -f3)" "$(echo "$a"|cut -d'|' -f4)" "$(echo "$b"|cut -d'|' -f3)" "$(echo "$b"|cut -d'|' -f4)"
    printf '| Ventilador medio (0-1000) | %s | %s |\n' "$(echo "$a"|cut -d'|' -f5)" "$(echo "$b"|cut -d'|' -f5)"
    printf '| Saida de ar (termometro IR) | %s | %s |\n' "$ta" "$tb"
    echo
    echo "**Leitura:** no stock os dois NTC ficam colados (mux morto, sensor cego) e os fans"
    echo "quase nao sobem; apos a correcao o NTC1 revela o calor real da optica e os fans vao a 1000."
  } | sanitize "" "" >"$rep"
  ok "relatorio gerado (higienizado): $rep"
  say "arquivos crus em $OUTDIR/ (gitignored). Revise e copie os higienizados p/ media/."
}

case "${1:-status}" in
  find)         cmd_find ;;
  status)       cmd_status ;;
  snapshot)     shift; cmd_snapshot "$@" ;;
  soak)         shift; cmd_soak "$@" ;;
  set-thermal)  shift; cmd_set_thermal "$@" ;;
  report)       cmd_report ;;
  *) echo "uso: $0 [find|status|snapshot <antes|depois>|soak <antes|depois> [min]|set-thermal <stock|fix>|report]"; exit 1 ;;
esac
