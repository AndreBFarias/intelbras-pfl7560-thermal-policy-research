#!/usr/bin/env bash
#
# pfl7560-lcd-color.sh - diagnostico e correcao de cor apos troca do micro-painel LCD
#
# Contexto: trocar o painel RX058B por variante de sufixo diferente (ex.: -4300 -> -0600)
# quebra a cor dos meios-tons por mapeamento LVDS divergente (VESA vs JEIDA).
# Este script projeta os padroes de teste e aplica/reverte o formato LVDS ao vivo.
# Detalhes: docs/research/28-troca-painel-rx058b-diagnostico-cor.md
#
# Uso:
#   PFL_IP=192.168.x.x ./pfl7560-lcd-color.sh <comando>
#   (sem PFL_IP, usa o primeiro device adb conectado)
#
# Comandos:
#   status                  mostra o formato LVDS atual (/proc/msp/panel)
#   jeida                   aplica LVDS JEIDA  (corrige o RX058B-0600)   [ao vivo + persiste]
#   vesa                    aplica LVDS VESA   (padrao do RX058B-4300)   [reverter]
#   swap <0-5> | bit <0-1>  ajustes finos (experimental; so se jeida/vesa nao bastar)
#   test <padrao>           projeta um padrao de teste (barras|gamma|bits|nitidez|resolucao|help)
#   wizard                  guia VESA<->JEIDA projetando o gamma e perguntando (leigo)
#   backup [arq]            salva a particao panelparam (default: panelparam.backup.img)
#   restore <arq>           regrava a particao panelparam a partir de um backup
#
set -euo pipefail

ADB="${ADB:-adb}"
PFL_IP="${PFL_IP:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ASSETS="$HERE/artifacts/lcd-color-fix"
LIBS="/vendor/lib:/system/lib:/vendor/lib/hw"
PART="/dev/block/by-name/panelparam"

die() { echo "erro: $*" >&2; exit 1; }
[ -d "$ASSETS" ] || die "assets nao encontrados em $ASSETS"

connect() {
  [ -n "$PFL_IP" ] && "$ADB" connect "$PFL_IP" >/dev/null 2>&1 || true
  DEV="${PFL_IP:-$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
  [ -n "${DEV:-}" ] || die "nenhum device adb (defina PFL_IP ou conecte um device)"
  "$ADB" -s "$DEV" root >/dev/null 2>&1 || true
  sleep 1
  [ -n "$PFL_IP" ] && "$ADB" connect "$PFL_IP" >/dev/null 2>&1 || true
}
sh_() { "$ADB" -s "$DEV" shell "$@"; }

status() { sh_ "cat /proc/msp/panel 2>/dev/null | grep -iE 'panel_name|lvds_fmt|bit_width|intf_enable|power_on'"; }

lvds() {   # lvds <fmt|swap|bit|map> <valor>
  "$ADB" -s "$DEV" push "$ASSETS/lvdsctl" /data/local/tmp/lvdsctl >/dev/null
  sh_ "chmod 755 /data/local/tmp/lvdsctl"
  sh_ "cd /data/local/tmp && LD_LIBRARY_PATH=$LIBS ./lvdsctl $1 $2"
}

show() {   # show <arquivo.png>
  local f="$ASSETS/$1"
  [ -f "$f" ] || die "padrao nao encontrado: $1"
  "$ADB" -s "$DEV" push "$f" /sdcard/lcdtest.png >/dev/null
  sh_ "am force-stop com.hisilicon.higallery" >/dev/null 2>&1 || true
  sleep 1
  sh_ "am start -a android.intent.action.VIEW -d file:///sdcard/lcdtest.png -t image/png" >/dev/null
  echo "projetado: $1"
}

case "${1:-help}" in
  status)  connect; status ;;
  jeida)   connect; lvds fmt 1; echo "--- estado ---"; status ;;
  vesa)    connect; lvds fmt 0; echo "--- estado ---"; status ;;
  swap)    connect; lvds swap "${2:?valor 0-5}"; status ;;
  bit)     connect; lvds bit  "${2:?valor 0-1}"; status ;;
  test)
    connect
    case "${2:-help}" in
      barras)    show teste-cor-barras.png ;;
      gamma)     show gamma-test.png ;;
      bits)      show bits-test.png ;;
      nitidez)   show nitidez.png ;;
      resolucao) show resolucao.png ;;
      *) echo "padroes: barras (swap de canal) | gamma (meios-tons) | bits (mapa de bits) | nitidez | resolucao" ;;
    esac ;;
  wizard)
    connect
    show gamma-test.png
    echo "Aplicando JEIDA (correcao do RX058B-0600)..."; lvds fmt 1 >/dev/null; show gamma-test.png
    read -r -p "Os quadrados de cinza estao NEUTROS (sem verde/rosa)? [s/N] " r
    if [ "${r,,}" = "s" ]; then echo "OK - JEIDA aplicado e persistido."; else
      echo "Revertendo para VESA..."; lvds fmt 0 >/dev/null; show gamma-test.png
      echo "Se com VESA ficou certo, use './pfl7560-lcd-color.sh vesa'. Se nenhum, teste swap 0..5."
    fi
    status ;;
  backup)
    connect; out="${2:-panelparam.backup.img}"
    "$ADB" -s "$DEV" exec-out "dd if=$PART 2>/dev/null" > "$out"
    echo "backup salvo: $out ($(wc -c <"$out") bytes)" ;;
  restore)
    connect; [ -f "${2:-}" ] || die "informe o arquivo de backup"
    "$ADB" -s "$DEV" push "$2" /sdcard/pp.img >/dev/null
    sh_ "dd if=/sdcard/pp.img of=$PART bs=4096 2>/dev/null; sync"
    echo "panelparam restaurado de $2 (reinicie para aplicar)" ;;
  *)
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
