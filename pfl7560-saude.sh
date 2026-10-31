#!/usr/bin/env bash
set -u
export LC_ALL=C

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
INI=/vendor/etc/ZYCustom.ini
BP=/vendor/build.prop
RC=/vendor/etc/init/hw/init.bigfish.rc

INI_FIX_MD5=252ab7a72a007a8b79b3fc86bd5c0d19
ESCADA='66000, 67500, 69000, 70000, 71500, 73000'
DEGRAUS='1000,  950,  900,  850,  850,  850'

V='\033[1;32m'; X='\033[1;31m'; A='\033[1;33m'; C='\033[1;36m'; Z='\033[0m'
OK=0; FALHA=0; AVISO=0

pass(){ printf "${V}[OK]${Z}    %-46s %s\n" "$1" "${2:-}"; OK=$((OK+1)); }
fail(){ printf "${X}[FALHA]${Z} %-46s %s\n" "$1" "${2:-}"; FALHA=$((FALHA+1)); }
warn(){ printf "${A}[AVISO]${Z} %-46s %s\n" "$1" "${2:-}"; AVISO=$((AVISO+1)); }
sec(){  printf "\n${C}== %s ==${Z}\n" "$1"; }

sh_(){ timeout 20 "$ADB" -s "$DEV" shell "$@" </dev/null 2>/dev/null | tr -d '\r'; }

conecta(){
  [ -n "$IP" ] || { echo "defina PFL_IP=<ip do projetor>"; exit 2; }
  case "$IP" in *:*) DEV="$IP" ;; *) DEV="$IP:$PORTA" ;; esac
  timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
  local m; m=$(sh_ getprop ro.product.model)
  [ "$m" = "PFL7560" ] || { echo "não e um PFL7560 em $DEV (getprop devolveu '${m:-vazio}')"; exit 2; }
  local u; u=$(sh_ id)
  case "$u" in *"uid=0"*) ROOT=1 ;; *)
    timeout 15 "$ADB" -s "$DEV" root >/dev/null 2>&1; sleep 3
    timeout 10 "$ADB" connect "$DEV" >/dev/null 2>&1
    u=$(sh_ id); case "$u" in *"uid=0"*) ROOT=1 ;; *) ROOT=0 ;; esac ;;
  esac
}

ini_efetivo(){
  local pid cand
  pid=$(sh_ getprop ro.boot.projectid | tr -d ' ')
  for cand in "/atv/ini/ZYCustom_$pid.ini" "/atv/ini/ZYCustom.ini" "$INI"; do
    [ -n "$(sh_ "[ -f '$cand' ] && echo s")" ] && { echo "$cand"; return 0; }
  done
  echo "$INI"
}

verifica(){
  local up; up=$(sh_ 'cut -d" " -f1 /proc/uptime')
  printf "${C}aparelho:${Z} %s  ${C}uptime:${Z} %ss  ${C}root:${Z} %s\n" \
    "$DEV" "${up%%.*}" "$([ "${ROOT:-0}" = 1 ] && echo sim || echo NÃO)"

  sec "1. os 3 fixes termicos em /vendor"
  local ini; ini=$(ini_efetivo)
  [ "$ini" = "$INI" ] || warn ".ini efetivo NAO e o de /vendor" "$ini"
  local m; m=$(sh_ "md5sum $ini" | awk '{print $1}')
  [ "$m" = "$INI_FIX_MD5" ] && pass "ZYCustom.ini e o config de correcao" "$m" \
                            || fail "ZYCustom.ini DIVERGENTE" "${m:-ilegivel} (esperado $INI_FIX_MD5; $ini)"

  local w; w=$(sh_ "grep -a wifi_disconnect_on_boot $BP")
  case "$w" in *"=0") pass "Wi-Fi reconecta no boot" "$w" ;;
    "") if [ "${ROOT:-0}" = 1 ]; then fail "build.prop ilegivel" ""; else warn "build.prop exige root" ""; fi ;;
    *)  fail "Wi-Fi NÃO corrigido" "$w" ;; esac

  local x; x=$(sh_ "grep -a -A3 'service xiriservice' $RC | grep -ac disabled")
  [ "${x:-0}" -ge 1 ] && pass "xiriservice silenciado" "disabled no .rc" \
                      || fail "xiriservice ATIVO" "spam de log ~1x/s"

  sec "2. o conserto em si (o mux dos termistores)"
  local ch; ch=$(sh_ "grep -ac 'HW_VIRTUAL_CHANNEL = 1' $ini")
  [ "${ch:-0}" -ge 1 ] && pass "HW_VIRTUAL_CHANNEL = 1 presente" "mux pode comutar" \
                       || fail "mux TRAVADO no canal 0" "protecao volta a ser cega"

  local atv; atv=$(sh_ 'ls /atv/ini/ZYCustom.ini 2>/dev/null')
  [ -z "$atv" ] && pass "sem ZYCustom.ini em /atv/ini" "sem disputa de precedencia" \
                || fail "EXISTE /atv/ini/ZYCustom.ini" "ele VENCE o de /vendor"

  local e; e=$(sh_ "grep -a POLICY_0_THRESHOLD $ini | head -1")
  case "$e" in *"$ESCADA"*) pass "escada de brilho nos limiares certos" "66-73 C" ;;
    *) warn "limiares de brilho inesperados" "$(echo "$e" | tr -s ' ')" ;; esac
  local d; d=$(sh_ "grep -a POLICY_0_BRIGHTNESS $ini | head -1")
  case "$d" in *"$DEGRAUS"*) pass "degraus de brilho 1000..850" "piso 850" ;;
    *) warn "degraus de brilho inesperados" "$(echo "$d" | tr -s ' ')" ;; esac

  sec "3. a protecao esta ENXERGANDO neste boot?"
  local lsadc bal
  lsadc=$(sh_ 'logcat -d' | grep -ac 'LSADC Error')
  bal=$(sh_ 'logcat -d' | grep -ac 'Achieve Balance')
  [ "${lsadc:-0}" -eq 0 ] && pass "sem LSADC Error no buffer" "não prova vivacidade -- use --vivacidade" \
                          || fail "LSADC Error x${lsadc} - PROTECAO CEGA" "WARNING/EMERGENCY não disparam; REINICIE"
  [ "${bal:-0}" -ge 1 ] && pass "loop termico vivo" "Achieve Balance x${bal}" \
                        || warn "nenhum Achieve Balance ainda" "normal nos primeiros ~60s de boot"

  local q f; q=$(sh_ getprop zysys.env_temp | tr -d '℃ '); f=$(sh_ getprop zysys.light_temp | tr -d '℃ ')
  if [ -n "$q" ] && [ -n "$f" ]; then
    if awk -v a="$q" -v b="$f" 'BEGIN{exit !(a-b>5 || b-a>5)}'; then
      pass "os 2 sensores leem valores distintos" "optica ${q}C / placa ${f}C"
    else
      fail "sensores praticamente iguais" "optica ${q}C / placa ${f}C - mux não comutou"
    fi
    awk -v t="$q" 'BEGIN{exit !(t>=70)}' && warn "optica acima do WARNING (70 C)" "${q}C"
  else
    fail "props de temperatura não respondem" "firmware pode estar em LSADC Error"
  fi

  sec "4. formato de cor do painel (LVDS)"
  local fmt; fmt=$(sh_ 'cat /proc/msp/panel' | grep -a lvds_fmt | head -1 | awk -F'[: ]+' '{print tolower($2)}')
  local esp; esp=$(printf '%s' "${PFL_LVDS_ESPERADO:-}" | tr '[:upper:]' '[:lower:]')
  if [ -z "$fmt" ]; then
    warn "lvds_fmt ilegivel em /proc/msp/panel" "formato em uso nao verificado"
  elif [ -n "$esp" ]; then
    [ "$fmt" = "$esp" ] && pass "formato LVDS em uso e o esperado" "$fmt" \
                        || fail "formato LVDS em uso difere do esperado" "em uso $fmt, esperado $esp (PFL_LVDS_ESPERADO)"
  fi
  if [ "${ROOT:-0}" = 1 ]; then
    local b nome; b=$(sh_ 'dd if=/dev/block/by-name/panelparam bs=1 skip=$((168 + 69*768 + 0x5c)) count=1 2>/dev/null | od -An -tu1' | tr -d ' ')
    case "$b" in 0) nome=vesa ;; 1) nome=jeida ;; *) nome="" ;; esac
    if [ -z "$nome" ]; then
      warn "byte 0x5c do perfil 69 = ${b:-?}" "valor fora de 0 (VESA) / 1 (JEIDA)"
    elif [ -z "$fmt" ]; then
      warn "byte 0x5c do perfil 69 = $b ($nome)" "sem o formato em uso para comparar"
    elif [ "$fmt" = "$nome" ]; then
      pass "formato em uso bate com o byte 0x5c gravado" "$fmt (byte=$b), persiste no boot"
    else
      warn "formato em uso ($fmt) difere do byte 0x5c ($nome)" "no proximo boot volta a $nome"
    fi
  else
    warn "panelparam exige root" "não verificado (em uso: ${fmt:-?})"
  fi

  printf "\n${C}resultado:${Z} ${V}%d OK${Z}  ${A}%d aviso(s)${Z}  ${X}%d falha(s)${Z}\n" "$OK" "$AVISO" "$FALHA"
  [ "$FALHA" -eq 0 ]
}

PROP_OVERRIDE=vendor.zy.power.tm.temp
INJETADO=71000

vivacidade(){
  local w e ini; ini=$(ini_efetivo)
  w=$(sh_ "grep -a WARNING_VALUE $ini" | grep -ao '[0-9]\{4,\}' | head -1)
  e=$(sh_ "grep -a EMERGENCY_VALUE $ini" | grep -ao '[0-9]\{4,\}' | head -1)
  case "$w" in ''|*[!0-9]*) fail "WARNING_VALUE ilegivel" "não vou injetar"; return 1 ;; esac
  case "$e" in ''|*[!0-9]*) fail "EMERGENCY_VALUE ilegivel" "não vou injetar"; return 1 ;; esac
  if [ -z "$w" ] || [ -z "$e" ] || [ "$INJETADO" -le "$w" ] || [ "$INJETADO" -ge "$e" ]; then
    fail "não vou injetar" "WARNING=${w:-?} EMERGENCY=${e:-?}; $INJETADO precisa ficar entre os dois"
    return 1
  fi
  printf "${C}== teste ativo: a protecao REAGE? ==${Z}\n"
  printf "  injeta %s mC (WARNING=%s, EMERGENCY=%s -- nao desliga o aparelho).\n" "$INJETADO" "$w" "$e"
  printf "  ${A}na tela: o aviso de temperatura aparece e o brilho cai ate 850, voltando sozinho.${Z}\n"
  printf "  dura ~40 s. O override e limpo ao final aconteca o que acontecer.\n\n"

  limpa_override(){
    local i
    for i in 1 2 3; do
      sh_ "setprop $PROP_OVERRIDE ''" >/dev/null 2>&1
      if [ "$(sh_ "getprop ro.product.model")" = "PFL7560" ] \
         && [ -z "$(sh_ "getprop $PROP_OVERRIDE")" ]; then
        return 0
      fi
      sleep 2
    done
    printf "\n${X}[ATENÇÃO]${Z} não confirmei a limpeza do override de temperatura.\n"
    printf "  REINICIE O PROJETOR (o override não sobrevive ao boot), ou rode:\n"
    printf "    adb connect %s && adb -s %s shell setprop %s ''\n" "$DEV" "$DEV" "$PROP_OVERRIDE"
    return 1
  }
  trap 'trap "" INT TERM; limpa_override' EXIT
  trap 'exit 130' INT TERM

  local tmp; tmp=$(mktemp)
  timeout 120 "$ADB" -s "$DEV" shell 'logcat -v time -s ZYThermalManager' </dev/null >"$tmp" 2>&1 &
  local pid=$!
  sleep 5
  sh_ "setprop $PROP_OVERRIDE $INJETADO" >/dev/null
  printf "  injetado; observando 40 s...\n"
  sleep 40
  sh_ "setprop $PROP_OVERRIDE ''" >/dev/null
  printf "  override limpo; observando a recuperação por 25 s...\n"
  sleep 25
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  sed -i 's/\x1b\[[0-9;]*m//g' "$tmp"

  local n_warn desce sobe
  n_warn=$(grep -ac 'Overheat Warning' "$tmp")
  desce=$(grep -a 'Level Change' "$tmp" | grep -a '=> 850!'  | grep -avc '850 => 850!')
  sobe=$(grep -a 'Level Change' "$tmp"  | grep -a '=> 1000!' | grep -avc '1000 => 1000!')

  echo
  [ "${n_warn:-0}" -ge 1 ] && pass "o WARNING disparou" "$n_warn aviso(s) de Overheat" \
                         || fail "o WARNING NÃO disparou" "a protecao NÃO esta reagindo - reinicie o projetor"
  [ "${desce:-0}" -ge 1 ] && pass "a escada de brilho atuou" "alvo caiu para 850 ($desce ticks)" \
                          || fail "a escada NÃO atuou" "o brilho ficou parado apesar do WARNING"
  [ "${sobe:-0}" -ge 1 ] && pass "o brilho voltou sozinho" "alvo de volta em 1000" \
                         || warn "recuperação não capturada" "confira com: adb shell logcat -d | grep 'Level Change'"

  local resto canario
  canario=$(sh_ "getprop ro.product.model")
  resto=$(sh_ "getprop $PROP_OVERRIDE")
  if [ "$canario" != "PFL7560" ]; then
    fail "NÃO CONSEGUI CONFIRMAR a limpeza do override" \
         "aparelho mudo -- REINICIE O PROJETOR AGORA (o override não e persistente)"
  elif [ -z "$resto" ]; then
    pass "override limpo" "confirmado com o aparelho respondendo"
  else
    fail "override AINDA ATIVO" "$resto - rode: adb shell setprop $PROP_OVERRIDE ''"
  fi

  mkdir -p evidencias/vivacidade 2>/dev/null
  local dest="evidencias/vivacidade/$(date +%Y-%m-%d-%H%M%S).log"
  mv "$tmp" "$dest" 2>/dev/null && printf "\n  log do teste: %s\n" "$dest"
  trap - EXIT INT TERM
  [ "${n_warn:-0}" -ge 1 ] && [ "${desce:-0}" -ge 1 ]
}

idempotencia(){
  local a b
  a=$(verifica | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^\[(OK|FALHA|AVISO)\]' | awk '{print $1, $2, $3}')
  sleep 5
  b=$(verifica | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^\[(OK|FALHA|AVISO)\]' | awk '{print $1, $2, $3}')
  printf "\n${C}== prova de idempotencia ==${Z}\n"
  if [ "$a" = "$b" ]; then
    printf "${V}[OK]${Z}    duas passagens deram o mesmo veredito em todas as checagens\n"
    return 0
  fi
  printf "${X}[FALHA]${Z} as duas passagens divergiram:\n"
  diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") | sed 's/^/        /'
  return 1
}

conecta
case "${1:-}" in
  --idempotencia) idempotencia ;;
  --vivacidade)
    verifica; rc=$?
    if [ "$rc" -ne 0 ]; then
      printf "\n${X}[ABORTADO]${Z} as checagens passivas reprovaram; não vou injetar temperatura.\n"
      printf "  Corrija as FALHAS acima primeiro. A mais grave: um ZYCustom.ini em /atv/ini\n"
      printf "  VENCE o de /vendor e pode ter EMERGENCY=45000 -- 71000 desligaria o aparelho.\n"
      exit 1
    fi
    echo; vivacidade ;;
  "")             verifica ;;
  *) echo "uso: PFL_IP=<ip> $0 [--idempotencia|--vivacidade]"
     echo "  (sem argumento) 12 checagens passivas"
     echo "  --idempotencia  roda 2x e confere que o veredito não muda"
     echo "  --vivacidade    prova ATIVA de que a protecao reage (~65 s, mexe na tela)"
     exit 2 ;;
esac
