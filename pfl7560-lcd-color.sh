#!/usr/bin/env bash
#
# pfl7560-lcd-color.sh - diagnostico e correcao de cor apos troca do micro-painel LCD
#
# Contexto: trocar o painel RX058B por variante de sufixo diferente (ex.: -4300 -> -0600)
# quebra a cor dos meios-tons por mapeamento LVDS divergente (VESA vs JEIDA).
# Este script projeta os padroes de teste e aplica/reverte o formato LVDS. Cada
# aplicacao GRAVA o byte lvds_fmt na particao panelparam (persiste no boot), por
# isso todo comando que grava faz backup antes e aborta se o backup falhar.
# Detalhes: docs/research/28-troca-painel-rx058b-diagnostico-cor.md
#
# Uso:
#   PFL_IP=192.168.x.x ./pfl7560-lcd-color.sh <comando>
#   (sem PFL_IP, usa o primeiro device adb conectado)
#
# Comandos:
#   status                  mostra o formato LVDS atual (/proc/msp/panel)
#   jeida                   aplica LVDS JEIDA  (o -0600 da 1a troca)     [grava na panelparam]
#   vesa                    aplica LVDS VESA   (painel de fabrica e o da 2a troca) [grava na panelparam]
#   swap <0-5> | bit <0-1>  ajustes finos (experimental; pede confirmacao; grava na panelparam)
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

# 1 so depois de um backup validado desta execucao; o lvds() recusa gravar sem isso
BACKUP_OK=0

status() { sh_ "cat /proc/msp/panel 2>/dev/null | grep -iE 'panel_name|lvds_fmt|bit_width|intf_enable|power_on'"; }

lvds() {   # lvds <fmt|swap|bit|map> <valor>   (GRAVA na panelparam: exige backup feito)
  [ "$BACKUP_OK" = "1" ] || die "lvds sem backup do panelparam - abortado antes de gravar"
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

# backup do dia antes de gravar na panelparam: um por dia basta (o do primeiro uso
# do dia, que guarda o estado anterior a qualquer mudanca desse dia, e mantido).
# Aborta se o backup falhar.
backup_antes() {
  local bk md5
  bk="panelparam.backup-$(date +%Y%m%d).img"
  if [ -f "$bk" ] && [ -f "$bk.md5" ] && [ "$(md5sum "$bk" | awk '{print $1}')" = "$(cat "$bk.md5")" ]; then
    echo ">> backup do dia ja existe e confere: $bk"
  else
    echo ">> backup de seguranca do panelparam antes de gravar..."
    md5="$(do_backup "$bk")" || die "backup do panelparam falhou - NAO vou gravar"
    echo "   backup: $bk (md5 $md5) - 'restore $bk' desfaz."
  fi
  BACKUP_OK=1
}

# confirmacao explicita (sem terminal = nao confirma)
confirma() {   # confirma <aviso>
  local r=""
  echo "$1"
  read -r -p "Continuar? [s/N] " r || r=""
  [ "${r,,}" = "s" ] || die "cancelado - nada foi gravado"
}

case "${1:-help}" in
  status)  connect; status ;;
  jeida)   connect; backup_antes; lvds fmt 1; echo "--- estado ---"; status ;;
  vesa)    connect; backup_antes; lvds fmt 0; echo "--- estado ---"; status ;;
  swap)    v="${2:?valor 0-5}"; connect
           confirma "swap e experimental e GRAVA na panelparam; pode apagar a tela."
           backup_antes; lvds swap "$v"; status ;;
  bit)     v="${2:?valor 0-1}"; connect
           confirma "bit e experimental e GRAVA na panelparam; pode apagar a tela."
           backup_antes; lvds bit "$v"; status ;;
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
    BACKUP_OK=1
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

    # formato em uso antes do wizard: base dos eixos avancados se nenhum for aceito
    case "$(status | grep -ai lvds_fmt | head -1 | tr -d '\r' | tr '[:upper:]' '[:lower:]')" in
      *jeida*) BASE_FMT=1; BASE_NOME=JEIDA ;;
      *vesa*)  BASE_FMT=0; BASE_NOME=VESA ;;
      *)       BASE_FMT="";  BASE_NOME="formato atual" ;;
    esac

    # ordem: os dois formatos LVDS (nunca apagam a tela; um deles e o certo para o painel)
    ask "JEIDA (o -0600 da 1a troca)" fmt 1 seguro || \
    ask "VESA (painel de fabrica e o da 2a troca)"  fmt 0 seguro || {
      echo
      echo "Nem VESA nem JEIDA resolveram. Vou tentar os eixos AVANCADOS (podem apagar a tela)."
      for s in 0 1 2 3 4 5; do
        # REAFIRMA a base (o formato em uso antes do wizard) a cada iteracao: um
        # timeout-risco anterior pode ter revertido para fmt 0, entao sem isto o
        # teste seria outro formato + swap (rotulo errado).
        [ -n "$BASE_FMT" ] && { lvds fmt "$BASE_FMT" >/dev/null 2>&1 || true; }
        ask "$BASE_NOME + swap $s" swap "$s" risco && break
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
