#!/usr/bin/env bash
# pfl7560-autocaptura.sh - supervisor: detecta o projetor na rede e captura a
# curva termica sozinho, sempre que ele estiver ligado.
#
# POR QUE NÃO udev: udev reage a eventos de kernel de dispositivos LOCAIS (USB,
# block). O PFL7560 fala adb por TCP/Wi-Fi e o USB-C dele não expoe adb (doc 06),
# entao não existe evento de udev para disparar. O equivalente correto pela rede e
# polling supervisionado -- e o que este script faz, rodando como servico de
# usuário do systemd (Restart=always + linger: sobrevive a logout e a reboot).
#
# Não altera NADA no aparelho: so le gtt/gfs/gbri via hidebug.
#
# Uso manual:  ./pfl7560-autocaptura.sh
# Como servico: systemctl --user {start,stop,status} pfl7560-autocaptura
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ADB="${ADB:-adb}"
INTERVALO="${INTERVALO:-30}"      # amostragem com o projetor ligado
BACKOFF="${BACKOFF:-60}"          # espera com o projetor desligado
PORTA=5555

# limiares da build atual (ZYCustom_390.ini), so para rotular a saida
ESCADA_MC=66000; WARN_MC=70000; EMERG_MC=75000

DATA_DIR="$HERE/evidencias"       # gitignored
ESTADO="$DATA_DIR/.autocaptura-ip"
LOG="$DATA_DIR/autocaptura.log"
mkdir -p "$DATA_DIR"

log(){ printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

# confirma que o IP e realmente o projetor (trava de modelo: o celular do dono
# tambem aparece no adb, e um no de rede vizinho com 5555 aberta pendura o adb)
eh_projetor(){
  local dev="$1" m
  m=$(timeout 8 $ADB -s "$dev" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r')
  [ "$m" = "PFL7560" ]
}

tenta_ip(){
  local ip="$1" dev="$ip:$PORTA"
  timeout 4 bash -c "cat < /dev/null > /dev/tcp/$ip/$PORTA" 2>/dev/null || return 1
  timeout 8 $ADB connect "$dev" >/dev/null 2>&1
  if eh_projetor "$dev"; then echo "$dev"; return 0; fi
  timeout 5 $ADB disconnect "$dev" >/dev/null 2>&1   # não envenenar o daemon
  return 1
}

# varre a /24 local por porta 5555 (connect scan: não precisa de root e, sendo a
# sub-rede on-link, não gera trafego roteado para fora da LAN)
descobre(){
  local cache dev
  cache=$(cat "$ESTADO" 2>/dev/null || true)
  if [ -n "$cache" ] && dev=$(tenta_ip "$cache"); then echo "$dev"; return 0; fi

  local iface base
  iface=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
  base=$(ip -4 -o addr show dev "${iface:-lo}" 2>/dev/null | awk '{print $4}' | head -1 | cut -d/ -f1)
  [ -n "$base" ] || return 1
  base="${base%.*}"

  local i
  for i in $(seq 1 254); do
    ( timeout 1 bash -c "cat < /dev/null > /dev/tcp/$base.$i/$PORTA" 2>/dev/null \
        && echo "$base.$i" >> "$ESTADO.cand" ) &
    [ $((i % 48)) -eq 0 ] && wait
  done
  wait

  local ip
  while read -r ip; do
    [ -n "$ip" ] || continue
    if dev=$(tenta_ip "$ip"); then
      printf '%s' "$ip" > "$ESTADO"
      rm -f "$ESTADO.cand"
      echo "$dev"; return 0
    fi
  done < <(sort -u "$ESTADO.cand" 2>/dev/null)
  rm -f "$ESTADO.cand"
  return 1
}

amostra(){  # $1 = dev ; imprime "t0 t1 f0 f1 bri up" ou falha
  local dev="$1" raw up t t0 t1 f f0 f1 b
  raw=$(timeout 25 $ADB -s "$dev" shell \
        "printf 'custom\ngtt 0\ngtt 1\ngfs 0\ngfs 1\ngbri 0\nquit\n' | /vendor/bin/hidebug" \
        </dev/null 2>/dev/null) || return 1
  up=$(timeout 10 $ADB -s "$dev" shell 'cut -d" " -f1 /proc/uptime' </dev/null 2>/dev/null | tr -d '\r')
  t=$(printf '%s\n' "$raw" | grep -a 'NTC temperature' | grep -aoE '[0-9]+')
  t0=$(printf '%s\n' "$t" | sed -n 1p); t1=$(printf '%s\n' "$t" | sed -n 2p)
  [ -n "${t1:-}" ] || return 1
  f=$(printf '%s\n' "$raw" | grep -a 'fan speed' | grep -aoE '[0-9]+')
  f0=$(printf '%s\n' "$f" | sed -n 1p); f1=$(printf '%s\n' "$f" | sed -n 2p)
  b=$(printf '%s\n' "$raw" | grep -a 'backlight brightness' | grep -aoE '[0-9]+' | sed -n 1p)
  printf '%s %s %s %s %s %s' "${t0:-NA}" "$t1" "${f0:-NA}" "${f1:-NA}" "${b:-NA}" "${up:-NA}"
}

log "supervisor iniciado (intervalo=${INTERVALO}s backoff=${BACKOFF}s)"
DEV=""; PICO=0; SESSAO=""

while :; do
  if [ -z "$DEV" ] || ! eh_projetor "$DEV"; then
    if [ -n "$SESSAO" ]; then
      log "sessão encerrada (projetor offline). pico de gtt1: $((PICO / 1000)) C"
      SESSAO=""; PICO=0
    fi
    DEV=$(descobre) || { sleep "$BACKOFF"; continue; }
    log "projetor encontrado em $DEV"
  fi

  if [ -z "$SESSAO" ]; then
    SESSAO="$DATA_DIR/$(date +%Y-%m-%d)/autocaptura-$(date +%H%M%S).tsv"
    mkdir -p "$(dirname "$SESSAO")"
    printf 'ts\tuptime_s\tgtt0_mC\tgtt1_mC\tfan0\tfan1\tbrilho\tevento\n' > "$SESSAO"
    log "sessão iniciada -> $SESSAO"
  fi

  if out=$(amostra "$DEV"); then
    read -r t0 t1 f0 f1 b up <<< "$out"
    [ "$t1" -gt "$PICO" ] 2>/dev/null && PICO="$t1"
    ev="-"
    if   [ "$t1" -ge "$EMERG_MC" ] 2>/dev/null; then ev="EMERGENCY cruzado (corte imediato)"
    elif [ "$t1" -ge "$WARN_MC" ]  2>/dev/null; then ev="WARNING cruzado (aviso na tela)"
    elif [ "$t1" -ge "$ESCADA_MC" ] 2>/dev/null; then ev="escada de brilho atuando"
    fi
    [ "$b" != "1000" ] && [ "$b" != "NA" ] && ev="$ev; brilho $b"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date +%H:%M:%S)" "$up" "$t0" "$t1" "$f0" "$f1" "$b" "$ev" >> "$SESSAO"
    [ "$ev" != "-" ] && log "$ev (gtt1=$((t1 / 1000)) C brilho=$b)"
    sleep "$INTERVALO"
  else
    DEV=""            # perdeu contato: proxima volta redescobre
    sleep 5
  fi
done
