#!/usr/bin/env bash
# pfl7560-diario.sh - busca o diario do projetor (bloco 24) e guarda no PC, com a hora corrigida.
#
# O aparelho grava 1 linha por minuto (pendrive-autorun/suite-diario.sh) em dois arquivos que se
# revezam, em /data/vendor/pfl7560-suite/diario/. Este script, chamado a cada 2 minutos pela unidade
# systemd --user (systemd/pfl7560-diario.timer), faz o "adb pull" dos dois arquivos, acerta a hora de
# cada linha e junta tudo em logs-projetor/diario-AAAA-MM.txt sem repetir linha.
#
# O RELOGIO: o relogio do projetor nao e confiavel (volta a 1970 ou a data velha quando falta pilha ou
# rede). Cada linha traz o uptime (up) e o id do boot (boot). O PC sabe quando o boot comecou
# (hora do PC agora menos o uptime de agora) e guarda isso em logs-projetor/.boots; a hora da linha e
# inicio do boot + up. Um boot que o PC nunca viu ao vivo usa o relogio do aparelho SO se ele parece
# certo (depois de 2020); senao a linha vai para diario-0000-00.txt, sem hora.
#
# Cada linha guardada: <AAAA-MM-DDTHH:MM:SS> <origem> <linha do aparelho>
#   origem: pc  = inicio do boot visto pelo PC + uptime (a boa)
#           ap  = relogio do aparelho (boot nao visto ao vivo, relogio plausivel)
#           sem = sem hora confiavel
#
# Depois de guardar, avisa o aparelho (suite-diario.sh enviado <data>) para a home mostrar o ultimo envio
# e apagar o pedido de "enviar agora". Nao escreve mais nada no aparelho.
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-diario.sh            # uma busca
#   (a unidade systemd le o PFL_IP de ~/.config/pfl7560/diario.env)
#   Saida: 0 buscou (ou o aparelho esta fora do ar agora: tenta de novo no proximo ciclo),
#          1 falha ao buscar, 2 aparelho errado ou sem PFL_IP.
# Variaveis: ADB, PFL_IP, PFL_DIARIO_DESTINO (padrao: logs-projetor/ ao lado do script).
set -u
export LC_ALL=C

HERE="$(cd "$(dirname "$0")" && pwd)"
ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
DESTINO="${PFL_DIARIO_DESTINO:-$HERE/logs-projetor}"
REMOTO="/data/vendor/pfl7560-suite"
ANO_MIN_EPOCH=1577836800
AGORA_FIXO=""
ESPERA_ROOT=2
if [ "${PFL_TESTE:-}" = "1" ]; then AGORA_FIXO="${PFL_AGORA:-}"; ESPERA_ROOT=0; fi

err(){ printf '[ERRO]  %s\n' "$*" >&2; }
warn(){ printf '[AVISO] %s\n' "$*" >&2; }
say(){ printf '%s\n' "$*"; }

case "${1:-}" in -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
[ $# -eq 0 ] || { err "uso: $0 (sem argumentos; o aparelho vem de PFL_IP)"; exit 2; }
[ -n "$IP" ] || { err "defina PFL_IP (o IP do projetor)"; exit 2; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
DEV="$IP:$PORTA"

adbs(){ timeout 20 "$ADB" -s "$DEV" "$@" </dev/null; }

timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
modelo="$(adbs shell getprop ro.product.model 2>/dev/null | tr -d '\r\n ')"
if [ -z "$modelo" ]; then
  say "projetor fora do ar agora ($DEV): tento de novo no proximo ciclo"
  exit 0
fi
[ "$modelo" = "PFL7560" ] || { err "nao e um PFL7560 em $DEV (model='$modelo')"; exit 2; }

uid="$(adbs shell id 2>/dev/null | tr -d '\r' | sed -n 's/^\(uid=[0-9]*\).*/\1/p')"
if [ "$uid" != "uid=0" ]; then
  timeout 15 "$ADB" -s "$DEV" root >/dev/null 2>&1 </dev/null
  sleep "$ESPERA_ROOT"
  timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
  uid="$(adbs shell id 2>/dev/null | tr -d '\r' | sed -n 's/^\(uid=[0-9]*\).*/\1/p')"
fi
[ "$uid" = "uid=0" ] || { err "sem root em $DEV (id devolveu '${uid:-vazio}'): nao consigo ler $REMOTO"; exit 1; }

# uptime e id do boot de agora, lidos juntos; a hora do PC logo em seguida
estado="$(adbs shell 'cut -d" " -f1 /proc/uptime | cut -d. -f1; head -n 1 /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r')"
agora="${AGORA_FIXO:-$(date +%s)}"
up_agora="$(printf '%s\n' "$estado" | sed -n '1p' | tr -cd '0-9')"
boot_agora="$(printf '%s\n' "$estado" | sed -n '2p' | tr -d '-' | tr -cd '0-9a-f' | cut -c1-8)"

n=0
for f in diario-0.txt diario-1.txt; do
  if timeout 60 "$ADB" -s "$DEV" pull "$REMOTO/diario/$f" "$W/$f" >/dev/null 2>&1 </dev/null && [ -s "$W/$f" ]; then n=$((n+1)); fi
done
if [ "$n" = 0 ]; then
  say "o aparelho ainda nao tem diario em $REMOTO/diario/ (desligado na home, ou recem-instalado)"
  exit 0
fi

# so linhas completas e no formato; a ultima pode estar sendo escrita
grep -ah '^up=[0-9]* dt=[0-9]* boot=[0-9a-f]* .* ev=[A-Za-z0-9:,+_-]*$' "$W"/diario-?.txt 2>/dev/null | sort -u > "$W/novas"
if [ ! -s "$W/novas" ]; then
  warn "os arquivos do diario vieram sem nenhuma linha no formato"
  exit 1
fi

mkdir -p "$DESTINO" || { err "nao consegui criar $DESTINO"; exit 1; }
BOOTS="$DESTINO/.boots"
touch "$BOOTS"

# o inicio de cada boot visto ao vivo: o menor (agora - up) de todas as vistas
if [ -n "$boot_agora" ] && [ -n "$up_agora" ]; then
  inicio=$(( agora - up_agora ))
  awk -v b="$boot_agora" -v i="$inicio" '
    $1 == b { achou = 1; if (i + 0 < $2 + 0) $2 = i }
    { print $1, $2 }
    END { if (!achou) print b, i }' "$BOOTS" > "$W/boots" && cat "$W/boots" > "$BOOTS"
fi

# linhas ja guardadas: o arquivo sem hora e os dois meses mais novos bastam (o aparelho guarda ~2 dias)
: > "$W/ja"
{ [ -f "$DESTINO/diario-0000-00.txt" ] && echo "$DESTINO/diario-0000-00.txt"
  find "$DESTINO" -maxdepth 1 -name 'diario-????-??.txt' ! -name 'diario-0000-00.txt' | sort | tail -n 2
} > "$W/ja-lista"
while read -r m; do cat "$m" >> "$W/ja"; done < "$W/ja-lista"

# hora de cada linha: epoch, origem, boot, up, linha
awk -v ano_min="$ANO_MIN_EPOCH" '
  FILENAME == ARGV[1] { ini[$1] = $2; next }
  {
    b = ""; u = ""; d = ""
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^boot=/) b = substr($i, 6)
      else if ($i ~ /^up=/) u = substr($i, 4)
      else if ($i ~ /^dt=/) d = substr($i, 4)
    }
    if (b in ini) { t = ini[b] + u; o = "pc" }
    else if (d + 0 >= ano_min) { t = d; o = "ap" }
    else { t = 0; o = "sem" }
    print t, o, b, u, $0
  }' "$BOOTS" "$W/novas" > "$W/datadas"

# epoch -> AAAA-MM-DDTHH:MM:SS (uma chamada so do date)
if [ "$(awk '$1 > 0' "$W/datadas" | wc -l)" -gt 0 ]; then
  awk '{ print "@" $1 }' "$W/datadas" | date -f - '+%Y-%m-%dT%H:%M:%S' > "$W/iso" 2>/dev/null
  if [ "$(wc -l < "$W/iso")" != "$(wc -l < "$W/datadas")" ]; then
    err "o date nao converteu todas as horas"; exit 1
  fi
else
  : > "$W/iso"
  awk '{ print "0000-00-00T00:00:00" }' "$W/datadas" > "$W/iso"
fi
# as linhas "sem" ganham a data zero
paste -d' ' "$W/iso" "$W/datadas" | awk '{ if ($2 == 0 || $3 == "sem") $1 = "0000-00-00T00:00:00"; print }' > "$W/com-iso"

# chave de repeticao: boot + up
awk '
  function chave(    i, b, u) {
    b = ""; u = ""
    for (i = 1; i <= NF; i++) { if ($i ~ /^boot=/) b = substr($i, 6); else if ($i ~ /^up=/) u = substr($i, 4) }
    return b ":" u
  }
  FILENAME == ARGV[1] { vistas[chave()] = 1; next }
  {
    # entrada: iso epoch origem boot up linha...  -> saida: iso origem linha...
    k = $4 ":" $5
    if (k in vistas) next
    vistas[k] = 1
    $2 = ""; $4 = ""; $5 = ""
    sub(/^ +/, "", $0)
    gsub(/  +/, " ", $0)
    print
  }' "$W/ja" "$W/com-iso" > "$W/gravar"

novas_n="$(wc -l < "$W/gravar")"
if [ "$novas_n" -gt 0 ]; then
  # cada linha vai para o arquivo do mes dela
  cut -c1-7 "$W/gravar" | sort -u > "$W/meses"
  while read -r mes; do
    arq="$DESTINO/diario-$mes.txt"
    grep -a "^$mes" "$W/gravar" >> "$arq"
    # ordem por hora, depois boot e uptime; estavel para o que e igual
    sort -s -k1,1 "$arq" -o "$arq"
  done < "$W/meses"
fi
say "diario: $novas_n linha(s) nova(s) em $DESTINO (aparelho: $(wc -l < "$W/novas") linhas lidas)"

adbs shell "sh $REMOTO/suite-diario.sh enviado $(date '+%Y-%m-%dT%H:%M:%S')" >/dev/null 2>&1 \
  || warn "nao consegui avisar o aparelho do envio (a home continua com a data antiga)"
exit 0
