#!/usr/bin/env bash
# pfl7560-monitor-props.sh - monitoramento PASSIVO da curva termica.
#
# POR QUE NÃO hidebug: os comandos gtt do hidebug forcam comutacao do mux dos
# termistores e avancam o anel de amostras de UM termistor so. As props
# zysys.env_temp/light_temp sao servidas pelo próprio loop termico do firmware
# (leitura em ~29 ms, sem tocar o mux), entao este monitor não pode disparar o
# "LSADC Error" que cega a protecao. Ver docs/research/37.
#
# O QUE ESTE MONITOR NÃO FAZ: detectar o LSADC Error. O ADC e grosso, com degraus
# de ~2,3 C, e ja se observaram 55 ciclos com o mesmo valor num boot de zero
# LSADC Error confirmado. Ficar parado e o comportamento normal. Quem detecta o
# erro de forma confiavel e o logcat -> pfl7560-vigia-lsadc.sh.
#
# ATENÇÃO aos nomes: env_temp e o sensor QUENTE da optica (gtt1); light_temp e
# o frio da placa (gtt0). Os nomes vem invertidos de fabrica.
#
# ---------------------------------------------------------------------------
# TEMPERATURA AMBIENTE E OBRIGATORIA (--ambiente).
#   As quatro medicoes de exaustao historicas do projeto (46,7 / 41,9 / 37,2 /
#   32,9 C) sao INCOMPARAVEIS entre si porque ninguem anotou o ambiente. Sem ele
#   um delta mede o dia, não o aparelho. O protocolo do doc 07 sempre exigiu
#   ("Meça o AMBIENTE: anote a temperatura da sala") e nunca foi seguido.
#   Este script recusa rodar sem.
#
# PISO DE SIGNIFICANCIA: ~2,3 C por degrau do ADC. Diferenca menor que 4,6 C
#   (dois degraus) NÃO e evidencia. O resumo repete isso.
# ---------------------------------------------------------------------------
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-monitor-props.sh --ambiente 24.5 [--rotulo "brilho 1000"]
#   PFL_IP=<ip> ./pfl7560-monitor-props.sh --ambiente 24.5 --minutos 30
#   ./pfl7560-monitor-props.sh --resumo <arquivo.tsv> [<arquivo2.tsv>]
set -u

ADB="${ADB:-adb}"
PORTA=5555
# PFL_IP e o padrão de TODO o repo. PFL_DEV fica so como alias legado -- antes
# esta era a UNICA variavel aceita aqui, e um `PFL_IP=x ./monitor-props.sh`
# (o comando que esta nos docs) era ignorado em silencio e caia num IP fixo.
IP="${PFL_IP:-}"
DEV_LEGADO="${PFL_DEV:-}"

INT="${INTERVALO:-30}"
MIN=240
AMB=""
ROTULO=""
OUT=""
# regime = N amostras consecutivas dentro de UM degrau do ADC
REGIME_N="${REGIME_N:-6}"
REGIME_BANDA="${REGIME_BANDA:-2.4}"
PISO_SIG="${PISO_SIG:-4.6}"

V='\033[1;32m'; X='\033[1;31m'; A='\033[1;33m'; C='\033[1;36m'; Z='\033[0m'
err(){ printf "${X}[ERRO]${Z}  %s\n" "$*" >&2; }
warn(){ printf "${A}[AVISO]${Z} %s\n" "$*" >&2; }
say(){ printf "${C}%s${Z}\n" "$*"; }

# ------------------------------------------------------------------ resumo
# Le um ou mais TSV e imprime a media EM REGIME de cada um. Com dois arquivos,
# compara e aplica o piso de significancia.
resumo(){
  [ $# -ge 1 ] || { err "uso: $0 --resumo <a.tsv> [b.tsv]"; exit 2; }
  local f
  for f in "$@"; do
    [ -s "$f" ] || { err "vazio ou inexistente: $f"; exit 1; }
    awk -F'\t' -v arq="$f" '
      NR>1 && $10=="SIM" { n++; s+=$7; if(mn==""||$7<mn)mn=$7; if($7>mx)mx=$7; amb=$6; rot=$4 }
      NR>1 { tot++ }
      END{
        printf "  %s\n", arq
        printf "    rotulo: %s   ambiente: %s C   amostras: %d (em regime: %d)\n", (rot==""?"-":rot), (amb==""?"?":amb), tot, n+0
        if(n>0) printf "    optica em regime: media %.2f C   min %.2f   max %.2f   (delta sobre amb: %.2f)\n", s/n, mn, mx, s/n-amb
        else    printf "    NÃO atingiu regime -- nao use este arquivo para comparar\n"
      }' "$f"
  done
  if [ $# -eq 2 ]; then
    printf "\n"
    awk -F'\t' -v piso="$PISO_SIG" '
      FNR==1 { fi++ }
      FNR>1 && $10=="SIM" { n[fi]++; s[fi]+=$7; a[fi]=$6 }
      END{
        if(n[1]==0 || n[2]==0){ print "  comparacao impossivel: algum arquivo não atingiu regime"; exit }
        m1=s[1]/n[1]; m2=s[2]/n[2]; d=m1-m2; ad=(d<0?-d:d)
        # delta normalizado pelo ambiente: e ele que torna dois dias comparaveis
        dn=(m1-a[1])-(m2-a[2]); adn=(dn<0?-dn:dn)
        printf "  delta bruto            : %.2f C\n", d
        printf "  delta sobre o ambiente : %.2f C   <- use ESTE\n", dn
        if(adn < piso) printf "  VEREDITO: %.2f C esta ABAIXO do piso de %.1f C (dois degraus do ADC). NAO e evidencia.\n", adn, piso
        else           printf "  VEREDITO: %.2f C supera o piso de %.1f C. Diferenca real.\n", adn, piso
      }' "$1" "$2"
  fi
}

# ------------------------------------------------------------------ coleta
conecta(){
  if [ -z "$IP" ] && [ -n "$DEV_LEGADO" ]; then
    warn "PFL_DEV esta obsoleto; use PFL_IP. Seguindo com '$DEV_LEGADO'."
    DEV="$DEV_LEGADO"
  else
    [ -n "$IP" ] || { err "defina PFL_IP=<ip do projetor>"; exit 2; }
    DEV="$IP:$PORTA"
  fi
  timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
  # trava de modelo: sem ela o monitor coletava horas de dado de qualquer
  # aparelho que respondesse naquele endereco, e o TSV não registrava de quem era
  local m; m=$(timeout 15 "$ADB" -s "$DEV" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r\n ')
  [ "$m" = "PFL7560" ] || { err "não e um PFL7560 em $DEV (model='${m:-vazio}')"; exit 2; }
}

coleta(){
  case "$AMB" in ''|*[!0-9.]*) err "--ambiente e OBRIGATORIO e numerico (ex.: 24.5). Veja o cabecalho."; exit 2 ;; esac
  conecta
  local dir="evidencias/$(date +%Y-%m-%d)"
  OUT="${OUT:-$dir/props-$(date +%H%M%S).tsv}"
  mkdir -p "$(dirname "$OUT")"
  # ts com DATA (não so hora): captura que cruza a meia-noite ficava ambigua.
  # boot_id separa series de boots diferentes; t_rel_s permite alinhar curvas.
  printf 'ts\tboot_id\tt_rel_s\trotulo\tuptime_s\tambiente_C\toptica_C\tplaca_C\tdelta_amb\tregime\n' > "$OUT"

  say "monitor passivo iniciado"
  printf "  destino : %s\n  ambiente: %s C   rotulo: %s\n  amostra : %ss   duracao: %s min\n\n" \
    "$OUT" "$AMB" "${ROTULO:--}" "$INT" "$MIN"

  local t0 fim hist n_reg regime bid
  t0=$(date +%s); fim=$(( t0 + MIN * 60 )); hist=""; regime="nao"
  bid=$(timeout 10 "$ADB" -s "$DEV" shell 'cat /proc/sys/kernel/random/boot_id' </dev/null 2>/dev/null | tr -d '\r-' | cut -c1-10)
  while [ "$(date +%s)" -lt "$fim" ]; do
    local e l up
    e=$(timeout 10 "$ADB" -s "$DEV" shell getprop zysys.env_temp   </dev/null 2>/dev/null | tr -d '\r℃ ')
    l=$(timeout 10 "$ADB" -s "$DEV" shell getprop zysys.light_temp </dev/null 2>/dev/null | tr -d '\r℃ ')
    up=$(timeout 10 "$ADB" -s "$DEV" shell 'cut -d" " -f1 /proc/uptime' </dev/null 2>/dev/null | tr -d '\r')
    if [ -z "$e" ]; then
      warn "props não responderam - reconectando"
      timeout 10 "$ADB" connect "$DEV" >/dev/null 2>&1; sleep 10; continue
    fi
    # ALERTA: o --vivacidade do saude.sh injeta 71000 mC em
    # vendor.zy.power.tm.temp e isso aparece nas DUAS props ao mesmo tempo.
    # Sem esta marca, o valor injetado entrava no TSV como leitura real.
    local ov=""
    [ -n "$l" ] && [ "$e" = "$l" ] && ov="OVERRIDE?"

    local d; d=$(awk -v a="$e" -v b="$AMB" 'BEGIN{printf "%.2f", a-b}')
    hist="$hist $e"
    hist=$(printf '%s' "$hist" | awk -v k="$REGIME_N" '{n=NF;s="";for(i=(n>k?n-k+1:1);i<=n;i++)s=s" "$i;print s}')
    n_reg=$(printf '%s' "$hist" | wc -w)
    if [ "$n_reg" -ge "$REGIME_N" ]; then
      regime=$(printf '%s' "$hist" | awk -v b="$REGIME_BANDA" '{mn=$1;mx=$1;for(i=1;i<=NF;i++){if($i<mn)mn=$i;if($i>mx)mx=$i}print (mx-mn<=b)?"SIM":"não"}')
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "${bid:-NA}" "$(( $(date +%s) - t0 ))" "${ROTULO:--}" \
      "${up:-NA}" "$AMB" "$e" "${l:-NA}" "$d" "$regime" >> "$OUT"
    printf "  %s  optica %s C  placa %s  delta_amb %s  regime=%s %s\n" \
      "$(date +%H:%M:%S)" "$e" "${l:-?}" "$d" "$regime" "$ov"
    sleep "$INT"
  done
  printf '\n'; say "== resumo =="; resumo "$OUT"
  cat <<TXT

  Para comparar com outra condicao (mesma cena, mesmo tempo de regime):
    $0 --resumo <este.tsv> <outro.tsv>
  O piso de significancia e ${PISO_SIG} C -- abaixo disso e quantizacao do ADC, nao efeito.
TXT
}

# -------------------------------------------------------------------- main
MODO=coleta
while [ $# -gt 0 ]; do
  case "$1" in
    --resumo)   shift; resumo "$@"; exit 0 ;;
    --ambiente) AMB="${2:-}"; shift 2 || shift ;;
    --rotulo)   ROTULO="${2:-}"; shift 2 || shift ;;
    --minutos)  MIN="${2:-240}"; shift 2 || shift ;;
    --saida)    OUT="${2:-}"; shift 2 || shift ;;
    -h|--help)  MODO=ajuda; shift ;;
    *) err "argumento desconhecido: $1"; MODO=ajuda; break ;;
  esac
done

if [ "$MODO" = "ajuda" ]; then
  cat <<'TXT'
uso:
  PFL_IP=<ip> ./pfl7560-monitor-props.sh --ambiente 24.5 [--rotulo "brilho 1000"] [--minutos 30]
      Coleta passiva da curva termica. --ambiente e OBRIGATORIO.

  ./pfl7560-monitor-props.sh --resumo a.tsv [b.tsv]
      Media em regime de cada arquivo. Com dois, compara pelo delta sobre o
      ambiente e aplica o piso de significancia de 4,6 C.

variaveis: INTERVALO (30) REGIME_N (6) REGIME_BANDA (2.4) PISO_SIG (4.6)
TXT
  exit 1
fi
coleta
