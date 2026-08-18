#!/usr/bin/env bash
# pfl7560-monitor-props.sh - monitoramento PASSIVO da curva termica.
#
# POR QUE NÃO hidebug: os comandos gtt do hidebug forcam comutacao do mux dos
# termistores. As props zysys.env_temp/light_temp sao servidas pelo próprio
# loop termico do firmware (leitura em ~29 ms, sem tocar o mux), entao este
# monitor não pode disparar o "LSADC Error" que cega a protecao.
#
# O QUE ESTE MONITOR NÃO FAZ: detectar o LSADC Error. Uma versao anterior deste
# cabecalho afirmava que "valor congelado por muitos ciclos" servia de detector.
# ISSO E FALSO e foi refutado com dado próprio (doc 35): o ADC e grosso, com
# degraus de ~2,3 C, e ja se observaram 55 ciclos com o mesmo valor num boot de
# zero LSADC Error confirmado. Ficar parado e o comportamento normal.
# Quem detecta o erro de forma confiavel e o logcat -> pfl7560-vigia-lsadc.sh.
#
# ATENÇÃO aos nomes: env_temp e o sensor QUENTE da optica (gtt1); light_temp e
# o frio da placa (gtt0). Os nomes vem invertidos de fabrica.
set -u
D="${PFL_DEV:-94.140.14.52:5555}"
INT="${INTERVALO:-30}"
DUR="${DURACAO:-14400}"
OUT="${1:-evidencias/$(date +%Y-%m-%d)/props-$(date +%H%M%S).tsv}"
mkdir -p "$(dirname "$OUT")"
printf 'ts\tuptime_s\tgtt1_optica_C\tgtt0_placa_C\tcongelado_ciclos\tevento\n' > "$OUT"

FIM=$(( $(date +%s) + DUR )); ANT=""; CONG=0
while [ "$(date +%s)" -lt "$FIM" ]; do
  e=$(timeout 10 adb -s "$D" shell getprop zysys.env_temp </dev/null 2>/dev/null | tr -d '\r℃ ')
  l=$(timeout 10 adb -s "$D" shell getprop zysys.light_temp </dev/null 2>/dev/null | tr -d '\r℃ ')
  up=$(timeout 10 adb -s "$D" shell 'cut -d" " -f1 /proc/uptime' </dev/null 2>/dev/null | tr -d '\r')
  if [ -z "$e" ]; then timeout 10 adb connect "$D" >/dev/null 2>&1; sleep 10; continue; fi

  if [ "$e" = "$ANT" ]; then CONG=$((CONG+1)); else CONG=0; ANT="$e"; fi
  ev="-"
  # limiares da build atual: escada 66, WARNING 70, EMERGENCY 75
  case "$e" in ''|*[!0-9.]*) ;; *)
    awk -v t="$e" 'BEGIN{exit !(t>=75)}' && ev="EMERGENCY"
    [ "$ev" = "-" ] && awk -v t="$e" 'BEGIN{exit !(t>=70)}' && ev="WARNING"
    [ "$ev" = "-" ] && awk -v t="$e" 'BEGIN{exit !(t>=66)}' && ev="escada atuando"
  esac
  # A coluna congelado_ciclos fica no arquivo como informação, mas NÃO vira
  # alarme: o ADC e grosso (degraus medidos de ~2,3 C: 61154 / 63421 / 65763 mC),
  # entao ficar no mesmo degrau por horas e o comportamento normal -- 55 ciclos
  # parados ja foram observados num boot com zero LSADC Error confirmado. Quem
  # detecta o erro de forma confiavel e o logcat, via pfl7560-vigia-lsadc.sh.
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%H:%M:%S)" "${up:-NA}" "$e" "$l" "$CONG" "$ev" >> "$OUT"
  sleep "$INT"
done
