#!/usr/bin/env bash
set -u

ADB="${ADB:-adb}"
IP="${PFL_IP:-}"
INTERVALO="${INTERVALO:-30}"
HORAS="${HORAS:-4}"

WARN_MC=70000
EMERG_MC=75000
ESCADA_MC=66000

[ -n "$IP" ] || { echo "erro: defina PFL_IP=<ip-do-projetor>" >&2; exit 1; }
case "$IP" in *:*) DEV="$IP";; *) DEV="$IP:5555";; esac

OUT="${PFL_OUTDIR:-evidencias/$(date +%Y-%m-%d)}"
mkdir -p "$OUT"
TSV="$OUT/curva-termica-$(date +%H%M%S).tsv"

$ADB connect "$DEV" >/dev/null 2>&1
mdl=$($ADB -s "$DEV" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r')
[ "$mdl" = "PFL7560" ] || { echo "erro: '$mdl' não e PFL7560 em $DEV" >&2; exit 1; }
sh_id(){ timeout 15 "$ADB" -s "$DEV" shell id </dev/null 2>/dev/null | tr -d '\r'; }
case "$(sh_id)" in *"uid=0"*) ;; *)
  timeout 15 "$ADB" -s "$DEV" root >/dev/null 2>&1; sleep 3
  timeout 10 "$ADB" connect "$DEV" >/dev/null 2>&1
  case "$(sh_id)" in *"uid=0"*) ;; *) echo "erro: sem root em $DEV: o hidebug nao responde. Abortei." >&2; exit 1 ;; esac ;;
esac

printf 'ts\tuptime_s\tgtt0_mC\tgtt1_mC\tfan0\tfan1\tbrilho\tevento\n' > "$TSV"
echo "monitorando $DEV a cada ${INTERVALO}s por ${HORAS}h -> $TSV"
echo "(não grava nada, mas sonda o sensor por gtt 0 e gtt 1 em par: use só supervisionado, doc 37; Ctrl+C encerra)"

N=$(( HORAS * 3600 / INTERVALO ))
pico=0
for _ in $(seq 1 "$N"); do
  raw=$(timeout 30 $ADB -s "$DEV" shell \
        "printf 'custom\ngtt 0\ngtt 1\ngfs 0\ngfs 1\ngbri 0\nquit\n' | /vendor/bin/hidebug" \
        </dev/null 2>/dev/null)
  case "$raw" in *"errno = 13"*) echo "aviso: hidebug negou acesso (errno = 13): sem root" >&2 ;; esac
  up=$(timeout 15 $ADB -s "$DEV" shell 'cut -d" " -f1 /proc/uptime' </dev/null 2>/dev/null | tr -d '\r')

  t=$(printf '%s\n' "$raw" | grep -a 'NTC temperature' | grep -aoE '[0-9]+')
  t0=$(printf '%s\n' "$t" | sed -n 1p); t1=$(printf '%s\n' "$t" | sed -n 2p)
  f=$(printf '%s\n' "$raw" | grep -a 'fan speed' | grep -aoE '[0-9]+')
  f0=$(printf '%s\n' "$f" | sed -n 1p); f1=$(printf '%s\n' "$f" | sed -n 2p)
  b=$(printf '%s\n' "$raw" | grep -a 'backlight brightness' | grep -aoE '[0-9]+' | sed -n 1p)

  ev="-"
  if [ -n "${t1:-}" ]; then
    [ "$t1" -gt "$pico" ] 2>/dev/null && pico="$t1"
    if   [ "$t1" -ge "$EMERG_MC" ] 2>/dev/null; then ev="EMERGENCY cruzado (corte imediato)"
    elif [ "$t1" -ge "$WARN_MC" ]  2>/dev/null; then ev="WARNING cruzado (aviso na tela)"
    elif [ "$t1" -ge "$ESCADA_MC" ] 2>/dev/null; then ev="escada de brilho atuando"
    fi
  fi
  [ -n "${b:-}" ] && [ "$b" != "1000" ] 2>/dev/null && ev="$ev; brilho reduzido a $b"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%H:%M:%S)" "${up:-NA}" "${t0:-NA}" "${t1:-NA}" \
    "${f0:-NA}" "${f1:-NA}" "${b:-NA}" "$ev" >> "$TSV"

  sleep "$INTERVALO"
done

echo "fim. pico de gtt1: $((pico / 1000)) C  (WARNING $((WARN_MC / 1000)) C, corte $((EMERG_MC / 1000)) C)"
echo "arquivo: $TSV"
