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
#   wizard                  guia VESA<->JEIDA (e eixos avancados) com backup automatico + watchdog
#   backup [arq]            salva a particao panelparam (default: panelparam.backup.img) + .md5
#   restore <arq>           regrava a particao panelparam a partir de um backup (com read-back)
#
set -euo pipefail

ADB="${ADB:-adb}"
PFL_IP="${PFL_IP:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ASSETS="$HERE/artifacts/lcd-color-fix"
LIBS="/vendor/lib:/system/lib:/vendor/lib/hw"
PART="/dev/block/by-name/panelparam"
PART_SIZE_FALLBACK=8388608   # 8 MiB (8M(panelparam) no /proc/cmdline; doc 28)
WIZ_TIMEOUT="${WIZ_TIMEOUT:-25}"   # seg sem resposta = assume tela preta e reverte

die() { echo "erro: $*" >&2; exit 1; }
[ -d "$ASSETS" ] || die "assets nao encontrados em $ASSETS"

connect() {
  [ -n "$PFL_IP" ] && "$ADB" connect "$PFL_IP" >/dev/null 2>&1 || true
  DEV="${PFL_IP:-$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
  [ -n "${DEV:-}" ] || die "nenhum device adb (defina PFL_IP ou conecte um device)"
  "$ADB" -s "$DEV" root >/dev/null 2>&1 || true
  sleep 1
  [ -n "$PFL_IP" ] && "$ADB" connect "$PFL_IP" >/dev/null 2>&1 || true
  # TRAVA DE MODELO -- este script grava em /dev/block/by-name/panelparam, um
  # dispositivo de bloco CRU. Sem esta guarda, um `adb devices` com o celular do
  # dono plugado faz o DEV cair em qualquer aparelho conectado e o dd escreve
  # numa particao alheia. Todos os outros scripts do repo ja tinham esta trava.
  local m; m="$("$ADB" -s "$DEV" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n ')"
  [ "$m" = "PFL7560" ] || die "dispositivo em '$DEV' NÃO e PFL7560 (model='${m:-vazio}'). Abortado."
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

# tamanho real (bytes) da particao panelparam, lido do sysfs do device; fallback 8 MiB
part_size() {
  local name sect
  name="$(sh_ "readlink $PART 2>/dev/null" | tr -d '\r' | sed 's#.*/##')" || return 1
  [ -n "$name" ] || return 1
  sect="$(sh_ "cat /sys/class/block/$name/size 2>/dev/null" | tr -d '\r')" || return 1
  case "$sect" in ''|*[!0-9]*) return 1 ;; esac
  echo $(( sect * 512 ))
}

# backup validado: exige tamanho == particao e grava <arq>.md5. Retorna o md5 no stdout.
do_backup() {   # do_backup <arq>
  local out="$1" psz got md5
  psz="$(part_size)" || psz="$PART_SIZE_FALLBACK"
  "$ADB" -s "$DEV" exec-out "dd if=$PART 2>/dev/null" > "$out"
  got=$(wc -c <"$out")
  [ "$got" = "$psz" ] || { rm -f "$out"; die "backup INVALIDO: $got bytes != $psz da particao (dd truncado?) - nao confio nesse backup"; }
  md5="$(md5sum "$out" | awk '{print $1}')"
  echo "$md5" > "$out.md5"
  echo "$md5"
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
    # O wizard testa formatos AO VIVO e depende do watchdog 'read -t'. Com stdin
    # nao-tty (pipe, < /dev/null, cron) o 'read -t' retorna na hora por EOF e o
    # watchdog nao protege - varreria os formatos em rajada. Exige terminal.
    [ -t 0 ] || die "o wizard e interativo (precisa de terminal). Use 'jeida'/'vesa'/'backup'/'restore' direto."
    # BACKUP AUTOMATICO OBRIGATORIO antes de qualquer mutacao (LCD-S2).
    # O panelparam persiste a cada 'lvds ...'; sem backup, um formato ruim
    # poderia deixar o aparelho bootando cego. Aborta se o backup falhar.
    BK="${WIZ_BACKUP:-panelparam.wizard.img}"
    echo ">> backup de seguranca do panelparam antes de mexer..."
    WANT_MD5="$(do_backup "$BK")"
    echo "   backup: $BK (md5 $WANT_MD5) - guarde-o; 'restore $BK' desfaz tudo."
    echo
    echo "Vou testar formatos AO VIVO. Se a tela ficar PRETA e voce nao responder"
    echo "em ${WIZ_TIMEOUT}s, eu reverto sozinho e sigo para o proximo. Ctrl-C aborta."
    echo

    ok=""
    # ask <label> <axis> <valor> <seguro|risco>
    ask() {   # retorna 0 se o usuario aceitou este formato
      local label="$1" axis="$2" val="$3" risco="$4" r
      echo ">> testando: $label"
      lvds "$axis" "$val" >/dev/null 2>&1 || true   # adb nao propaga exit code confiavel; o gate e visual
      show gamma-test.png >/dev/null 2>&1 || true
      if read -t "$WIZ_TIMEOUT" -r -p "   Os cinzas estao NEUTROS (sem verde/rosa)? [s/N] " r; then
        [ "${r,,}" = "s" ] && { ok="$label"; return 0; }
      else
        echo
        if [ "$risco" = "risco" ]; then
          echo "   (sem resposta -> assumo tela preta; volto a um estado visivel)"
          # volta ao estado visivel conhecido: VESA + swap 0 + 8bit (defaults do -4300)
          lvds fmt 0  >/dev/null 2>&1 || true
          lvds swap 0 >/dev/null 2>&1 || true
          lvds bit 1  >/dev/null 2>&1 || true
        fi
      fi
      return 1
    }

    # ordem: os dois formatos LVDS (nunca apagam a tela; um deles e o certo p/ o -0600/-4300)
    ask "JEIDA (corrige o RX058B-0600)" fmt 1 seguro || \
    ask "VESA (padrao do RX058B-4300)"  fmt 0 seguro || {
      echo
      echo "Nem VESA nem JEIDA resolveram. Vou tentar os eixos AVANCADOS (podem apagar a tela)."
      for s in 0 1 2 3 4 5; do
        # REAFIRMA a base JEIDA a cada iteracao: um timeout-risco anterior pode ter
        # revertido para fmt 0, entao sem isto o teste seria VESA+swap (rotulo errado).
        lvds fmt 1 >/dev/null 2>&1 || true
        ask "JEIDA + swap $s" swap "$s" risco && break
      done
    }

    echo
    if [ -n "$ok" ]; then
      echo "Formato aceito na tela: $ok."
      echo "Estado real gravado no painel (persiste no boot) -- confira 'lvds_fmt' abaixo:"
      echo "Para desfazer: ./pfl7560-lcd-color.sh restore $BK"
    else
      echo "Nenhum formato foi aceito. Restaurando o panelparam do backup ($BK)..."
      "$0" restore "$BK" || die "restore automatico falhou - rode manualmente: $0 restore $BK"
      echo "panelparam restaurado ao estado inicial. Reinicie o aparelho."
    fi
    echo "--- estado ---"; status ;;

  backup)
    connect; out="${2:-panelparam.backup.img}"
    md5="$(do_backup "$out")"
    echo "backup salvo: $out ($(wc -c <"$out") bytes, md5 $md5) [+ $out.md5]" ;;

  restore)
    connect; bk="${2:-}"
    [ -f "$bk" ] || die "informe o arquivo de backup existente"
    psz="$(part_size)" || psz="$PART_SIZE_FALLBACK"
    got=$(wc -c <"$bk")
    [ "$got" = "$psz" ] || die "backup tem $got bytes != $psz da particao - NAO vou gravar (backup errado/truncado)"
    want="$(md5sum "$bk" | awk '{print $1}')"
    "$ADB" -s "$DEV" push "$bk" /sdcard/pp.img >/dev/null
    # confere o md5 do arquivo empurrado ANTES de tocar na particao
    rmd5="$(sh_ "md5sum /sdcard/pp.img 2>/dev/null" | awk '{print $1}' | tr -d '\r')"
    [ "$want" = "$rmd5" ] || { sh_ "rm -f /sdcard/pp.img" >/dev/null 2>&1 || true; die "md5 divergente apos push ($want != $rmd5) - abortado, particao intacta"; }
    # grava conferindo sucesso por sentinela (adb shell nao propaga exit code de forma confiavel)
    res="$(sh_ "dd if=/sdcard/pp.img of=$PART bs=4096 2>/dev/null && sync && echo DDOK" || true)"
    echo "$res" | grep -q DDOK || die "dd de restauracao FALHOU - a particao pode estar parcial; regrave IMEDIATAMENTE ($0 restore $bk) antes de reiniciar"
    # read-back: le a particao inteira de volta e compara md5
    back="$(sh_ "dd if=$PART 2>/dev/null | md5sum" | awk '{print $1}' | tr -d '\r')"
    sh_ "rm -f /sdcard/pp.img" >/dev/null 2>&1 || true
    [ "$want" = "$back" ] || die "read-back divergente ($want != $back) - gravacao suspeita; regrave ($0 restore $bk) antes de reiniciar"
    echo "panelparam restaurado de $bk e verificado por read-back (md5 $want). reinicie para aplicar." ;;

  *)
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
