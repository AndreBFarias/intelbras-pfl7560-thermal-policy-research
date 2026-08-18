#!/usr/bin/env bash
# pfl7560-saude.sh - verificacao READ-ONLY do estado da correcao no aparelho.
#
# Responde a UMA pergunta: a correcao esta ativa e a protecao termica esta
# enxergando NESTE boot? Sai com 0 se tudo passa, 1 se algo falha.
#
# POR QUE NÃO USA hidebug: os comandos gtt do hidebug forcam comutacao do mux
# dos termistores, e ha suspeita (doc 35, LSADC-S2) de que sondagem repetida por
# esse caminho dispare o "LSADC Error" que cega a protecao. Este verificador le
# apenas props, arquivos e o logcat -- nada que toque o mux. Rodar em loop e
# seguro.
#
# IDEMPOTENTE POR CONSTRUCAO no modo padrão: não escreve nada no aparelho nem no
# repo, entao rodar N vezes seguidas produz o mesmo resultado.
# EXCECAO: --vivacidade escreve uma propriedade de override de temperatura, faz o
# brilho cair e voltar, e grava um log em evidencias/vivacidade/. Ele limpa o que
# escreveu (trap), mas não e read-only -- por isso e opt-in.
#
# Uso:  PFL_IP=<ip> ./pfl7560-saude.sh                 # 12 checagens passivas
#       PFL_IP=<ip> ./pfl7560-saude.sh --idempotencia  # roda 2x e compara
#       PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade    # prova ATIVA (~65 s, mexe na tela)
set -u

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
INI=/vendor/etc/ZYCustom.ini
BP=/vendor/build.prop
RC=/vendor/etc/init/hw/init.bigfish.rc

# md5 do config de correcao (invariante 9 do VALIDATOR_BRIEF: as 3 copias do
# repo tem de bater com este mesmo valor -- `make check` cobre o lado do repo)
INI_FIX_MD5=252ab7a72a007a8b79b3fc86bd5c0d19
# limiares da build atual, para conferir que o .ini ativo e mesmo o com escada
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
  DEV="$IP:$PORTA"
  timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
  local m; m=$(sh_ getprop ro.product.model)
  [ "$m" = "PFL7560" ] || { echo "não e um PFL7560 em $DEV (getprop devolveu '${m:-vazio}')"; exit 2; }
  # build.prop e 0600 e a particao panelparam exige root; sem root o verificador
  # degrada para avisos em vez de falhar
  local u; u=$(sh_ id)
  case "$u" in *"uid=0"*) ROOT=1 ;; *)
    timeout 15 "$ADB" -s "$DEV" root >/dev/null 2>&1; sleep 3
    timeout 10 "$ADB" connect "$DEV" >/dev/null 2>&1
    u=$(sh_ id); case "$u" in *"uid=0"*) ROOT=1 ;; *) ROOT=0 ;; esac ;;
  esac
}

verifica(){
  local up; up=$(sh_ 'cut -d" " -f1 /proc/uptime')
  printf "${C}aparelho:${Z} %s  ${C}uptime:${Z} %ss  ${C}root:${Z} %s\n" \
    "$DEV" "${up%%.*}" "$([ "${ROOT:-0}" = 1 ] && echo sim || echo NÃO)"

  sec "1. os 3 fixes termicos em /vendor"
  local m; m=$(sh_ "md5sum $INI" | awk '{print $1}')
  [ "$m" = "$INI_FIX_MD5" ] && pass "ZYCustom.ini e o config de correcao" "$m" \
                            || fail "ZYCustom.ini DIVERGENTE" "${m:-ilegivel} (esperado $INI_FIX_MD5)"

  local w; w=$(sh_ "grep -a wifi_disconnect_on_boot $BP")
  case "$w" in *"=0") pass "Wi-Fi reconecta no boot" "$w" ;;
    "") if [ "${ROOT:-0}" = 1 ]; then fail "build.prop ilegivel" ""; else warn "build.prop exige root" ""; fi ;;
    *)  fail "Wi-Fi NÃO corrigido" "$w" ;; esac

  local x; x=$(sh_ "grep -a -A3 'service xiriservice' $RC | grep -ac disabled")
  [ "${x:-0}" -ge 1 ] && pass "xiriservice silenciado" "disabled no .rc" \
                      || fail "xiriservice ATIVO" "spam de log ~1x/s"

  sec "2. o conserto em si (o mux dos termistores)"
  local ch; ch=$(sh_ "grep -ac 'HW_VIRTUAL_CHANNEL = 1' $INI")
  [ "${ch:-0}" -ge 1 ] && pass "HW_VIRTUAL_CHANNEL = 1 presente" "mux pode comutar" \
                       || fail "mux TRAVADO no canal 0" "protecao volta a ser cega"

  # /atv/ini tem precedencia sobre /vendor/etc: um ZYCustom.ini la anula o fix
  local atv; atv=$(sh_ 'ls /atv/ini/ZYCustom.ini 2>/dev/null')
  [ -z "$atv" ] && pass "sem ZYCustom.ini em /atv/ini" "sem disputa de precedencia" \
                || fail "EXISTE /atv/ini/ZYCustom.ini" "ele VENCE o de /vendor"

  local e; e=$(sh_ "grep -a POLICY_0_THRESHOLD $INI | head -1")
  case "$e" in *"$ESCADA"*) pass "escada de brilho nos limiares certos" "66-73 C" ;;
    *) warn "limiares de brilho inesperados" "$(echo "$e" | tr -s ' ')" ;; esac
  local d; d=$(sh_ "grep -a POLICY_0_BRIGHTNESS $INI | head -1")
  case "$d" in *"$DEGRAUS"*) pass "degraus de brilho 1000..850" "piso 850" ;;
    *) warn "degraus de brilho inesperados" "$(echo "$d" | tr -s ' ')" ;; esac

  sec "3. a protecao esta ENXERGANDO neste boot?"
  # este e o teste que o doc 35 mostrou ser o que realmente importa: a config
  # pode estar perfeita e a protecao estar cega mesmo assim
  local lsadc bal
  lsadc=$(sh_ 'logcat -d' | grep -ac 'LSADC Error')
  bal=$(sh_ 'logcat -d' | grep -ac 'Achieve Balance')
  # ASSIMETRIA DELIBERADA: a presenca do erro PROVA que a protecao cegou, mas a
  # ausencia NÃO prova que ela esta viva -- o erro so aparece em 2 de cada 10
  # iteracoes do loop e o ring do logcat dura 60-150 s (doc 37). Por isso o lado
  # negativo e FALHA e o lado positivo e apenas ausencia de sinal ruim, com o
  # ponteiro para o único teste positivo que existe.
  [ "${lsadc:-0}" -eq 0 ] && pass "sem LSADC Error no buffer" "não prova vivacidade -- use --vivacidade" \
                          || fail "LSADC Error x${lsadc} - PROTECAO CEGA" "WARNING/EMERGENCY não disparam; REINICIE"
  [ "${bal:-0}" -ge 1 ] && pass "loop termico vivo" "Achieve Balance x${bal}" \
                        || warn "nenhum Achieve Balance ainda" "normal nos primeiros ~60s de boot"

  # env_temp = sensor QUENTE da optica (gtt1); light_temp = frio da placa (gtt0).
  # Os nomes vem invertidos de fabrica. Se os dois lerem igual, o mux não comutou.
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

  sec "4. correcao de cor do painel trocado (JEIDA)"
  local fmt; fmt=$(sh_ 'cat /proc/msp/panel' | grep -a lvds_fmt | head -1 | awk -F'[: ]+' '{print $2}')
  [ "$fmt" = "jeida" ] && pass "runtime em JEIDA" "painel -0600 com cor correta" \
                       || warn "runtime em '${fmt:-?}'" "correto so se o painel for o -4300 de fabrica"
  if [ "${ROOT:-0}" = 1 ]; then
    local b; b=$(sh_ 'dd if=/dev/block/by-name/panelparam bs=1 skip=$((168 + 69*768 + 0x5c)) count=1 2>/dev/null | od -An -tu1' | tr -d ' ')
    [ "$b" = "1" ] && pass "JEIDA gravado no panelparam" "persiste no boot nativamente" \
                   || warn "byte 0x5c do perfil 69 = ${b:-?}" "sem persistencia nativa"
  else
    warn "panelparam exige root" "não verificado"
  fi

  printf "\n${C}resultado:${Z} ${V}%d OK${Z}  ${A}%d aviso(s)${Z}  ${X}%d falha(s)${Z}\n" "$OK" "$AVISO" "$FALHA"
  [ "$FALHA" -eq 0 ]
}

# TESTE ATIVO DE VIVACIDADE.
#
# Por que ele existe: contar "LSADC Error" no logcat e um detector FRACO. O erro
# so aparece em 2 de cada 10 iteracoes do loop termico, entao a ausencia dele num
# buffer curto não prova que a protecao esta viva -- prova apenas que voce não
# olhou tempo suficiente.
#
# Este teste pergunta direto ao firmware: injeta uma temperatura acima do
# WARNING pela propriedade de override e ve se a politica REAGE. Se reagir, a
# protecao esta viva agora, sem margem para duvida.
#
# SEGURANCA:
#  - 71000 mC fica ACIMA do WARNING (70000) e ABAIXO do EMERGENCY (75000).
#    O valor e fixo no codigo de proposito: DEFAULT_PROTECT = 2 significa
#    "desligamento imediato", entao injetar 76000 desligaria o aparelho na hora.
#    Nunca torne este valor configuravel.
#  - A limpeza do override esta num trap EXIT/INT/TERM: sai como sair, limpa.
#  - Efeito visivel: o brilho cai ate 850 e volta sozinho em rampa, e o aviso de
#    temperatura aparece na tela. Dura cerca de 40 s.
PROP_OVERRIDE=vendor.zy.power.tm.temp
INJETADO=71000

vivacidade(){
  local w e
  w=$(sh_ "grep -a WARNING_VALUE $INI" | grep -ao '[0-9]\{4,\}')
  e=$(sh_ "grep -a EMERGENCY_VALUE $INI" | grep -ao '[0-9]\{4,\}')
  # trava dura: so injeta se o valor ficar mesmo entre os dois limiares do
  # aparelho, lidos AGORA. Se o .ini tiver outros limiares, aborta.
  if [ -z "$w" ] || [ -z "$e" ] || [ "$INJETADO" -le "$w" ] || [ "$INJETADO" -ge "$e" ]; then
    fail "não vou injetar" "WARNING=${w:-?} EMERGENCY=${e:-?}; $INJETADO precisa ficar entre os dois"
    return 1
  fi
  printf "${C}== teste ativo: a protecao REAGE? ==${Z}\n"
  printf "  injeta %s mC (WARNING=%s, EMERGENCY=%s -- nao desliga o aparelho).\n" "$INJETADO" "$w" "$e"
  printf "  ${A}na tela: o aviso de temperatura aparece e o brilho cai ate 850, voltando sozinho.${Z}\n"
  printf "  dura ~40 s. O override e limpo ao final aconteca o que acontecer.\n\n"

  limpa_override(){ sh_ "setprop $PROP_OVERRIDE ''" >/dev/null 2>&1; }
  trap limpa_override EXIT INT TERM

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
  desce=$(grep -a 'Level Change' "$tmp" | grep -ac '=> 850!')
  sobe=$(grep -a 'Level Change' "$tmp" | grep -ac '=> 1000!')

  echo
  [ "${n_warn:-0}" -ge 1 ] && pass "o WARNING disparou" "$n_warn aviso(s) de Overheat" \
                         || fail "o WARNING NÃO disparou" "a protecao NÃO esta reagindo - reinicie o projetor"
  [ "${desce:-0}" -ge 1 ] && pass "a escada de brilho atuou" "alvo caiu para 850 ($desce ticks)" \
                          || fail "a escada NÃO atuou" "o brilho ficou parado apesar do WARNING"
  [ "${sobe:-0}" -ge 1 ] && pass "o brilho voltou sozinho" "alvo de volta em 1000" \
                         || warn "recuperação não capturada" "confira com: adb shell logcat -d | grep 'Level Change'"

  local resto; resto=$(sh_ "getprop $PROP_OVERRIDE")
  [ -z "$resto" ] && pass "override limpo" "aparelho de volta ao normal" \
                  || fail "override AINDA ATIVO" "$resto - rode: adb shell setprop $PROP_OVERRIDE ''"

  mkdir -p evidencias/vivacidade 2>/dev/null
  local dest="evidencias/vivacidade/$(date +%Y-%m-%d-%H%M%S).log"
  mv "$tmp" "$dest" 2>/dev/null && printf "\n  log do teste: %s\n" "$dest"
  trap - EXIT INT TERM
  [ "${n_warn:-0}" -ge 1 ] && [ "${desce:-0}" -ge 1 ]
}

# Prova de idempotencia: duas passagens seguidas tem de dar exatamente o mesmo
# veredito. Se diferirem, ou o aparelho mudou de estado sozinho (achado!) ou
# este verificador tem efeito colateral (bug dele).
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
  --vivacidade)   verifica; echo; vivacidade ;;
  "")             verifica ;;
  *) echo "uso: PFL_IP=<ip> $0 [--idempotencia|--vivacidade]"
     echo "  (sem argumento) 12 checagens passivas"
     echo "  --idempotencia  roda 2x e confere que o veredito não muda"
     echo "  --vivacidade    prova ATIVA de que a protecao reage (~65 s, mexe na tela)"
     exit 2 ;;
esac
