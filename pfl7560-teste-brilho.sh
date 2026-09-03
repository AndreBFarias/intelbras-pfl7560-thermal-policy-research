#!/usr/bin/env bash
# pfl7560-teste-brilho.sh - mapeia o PISO REAL do LED e mede o ganho termico por
# nivel de brilho, AO VIVO e sem gravar nada no aparelho.
#
# POR QUE ELE EXISTE
#   O `[Backlight] FW_LEVEL` de fabrica para em 750. Estender a curva abaixo
#   disso e uma mudanca de config PERSISTENTE, e o repositorio marca isso como
#   gate nunca cumprido: docs/research/06-acesso-adb-e-comandos.md:144 lista
#   "que `sbri` abaixo de ~750 e aceito pelo LED" como INFERIDO, não testado em
#   hardware; docs/research/05-ZYCustom.ini-proposto.md:55 exige confirmar ao
#   vivo antes de gravar. Este script cumpre esse gate.
#
# O QUE ELE NÃO FAZ
#   Não escreve em /vendor. Nao toca no panelparam. Nao reinicia. Tudo o que ele
#   muda e estado de RUNTIME, que o próprio firmware desfaz sozinho -- e que o
#   `trap` desfaz na saida, aconteca o que acontecer.
#
# SEGURANCA TERMICA (doc 37)
#   NÃO usa `gtt`. O mecanismo do LSADC Error e a defasagem dos aneis de
#   amostras, causada por sondagem IMPAR de termistor. Este script le temperatura
#   apenas por PROPS (zysys.env_temp / zysys.light_temp), que sao servidas pelo
#   próprio loop termico e não comutam o mux. Os comandos de hidebug usados aqui
#   (`sbri`, `gbri`, `gbll`) sao de BACKLIGHT: não passam por
#   ZYThermalManager::getThermalTemp e não avancam anel de termistor nenhum.
#
# A ARMADILHA QUE DEFINE O DESENHO (doc 06:96)
#   O loop termico REASSUME o brilho. Abaixo de 66 C o alvo da politica e 1000 e
#   o RunLineChange sobe 2-3 unidades por tick de 2 s -- um `sbri` solto e
#   revertido sozinho em ~6-8 min. Por isso:
#     --piso  (visual, segundos)  deixa o loop reverter, e ate usa isso
#     --curva (termico, minutos)  REAPLICA o nivel periodicamente e PROVA que
#                                 segurou, registrando o `gbri` real em cada amostra
#
# ATENÇÃO aos nomes das props: env_temp e o sensor QUENTE da optica (gtt1);
# light_temp e o frio da placa (gtt0). Vem invertidos de fabrica.
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-teste-brilho.sh --piso [--ambiente 24.5]
#   PFL_IP=<ip> ./pfl7560-teste-brilho.sh --curva 750 --ambiente 24.5 [--minutos 25]
#   PFL_IP=<ip> ./pfl7560-teste-brilho.sh --niveis        # so lista gbll e sai
set -u

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"

# Degraus varridos pelo --piso, do seguro para o desconhecido. 750 e o piso de
# fabrica (FW_LEVEL); tudo abaixo disso e o territorio que este teste mapeia.
DEGRAUS_PISO="1000 900 800 750 700 650 600 550 500 450 400"
# de quanto em quanto tempo o --curva reaplica o nivel (o loop sobe 2-3/2s, entao
# 15 s deixa a deriva em ~20 unidades no pior caso)
REAPLICA_S="${REAPLICA_S:-15}"
INTERVALO_S="${INTERVALO_S:-30}"
# regime = N amostras consecutivas dentro de UM degrau do ADC (~2,3 C)
REGIME_N="${REGIME_N:-6}"
REGIME_BANDA="${REGIME_BANDA:-2.4}"

V='\033[1;32m'; X='\033[1;31m'; A='\033[1;33m'; C='\033[1;36m'; Z='\033[0m'
say(){ printf "${C}%s${Z}\n" "$*"; }
ok(){  printf "${V}[OK]${Z}    %s\n" "$*"; }
warn(){ printf "${A}[AVISO]${Z} %s\n" "$*"; }
err(){ printf "${X}[ERRO]${Z}  %s\n" "$*"; }

sh_(){ timeout 20 "$ADB" -s "$DEV" shell "$@" </dev/null 2>/dev/null | tr -d '\r'; }

# uma sessão de hidebug por chamada. NUNCA emitir `gtt` aqui (ver cabecalho).
hid(){
  local cmds="$1"
  timeout 25 "$ADB" -s "$DEV" shell "printf 'custom\n${cmds}\nquit\n' | /vendor/bin/hidebug" \
    </dev/null 2>/dev/null | tr -d '\r'
}

conecta(){
  [ -n "$IP" ] || { err "defina PFL_IP=<ip do projetor>"; exit 2; }
  DEV="$IP:$PORTA"
  timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
  local m; m=$(sh_ getprop ro.product.model)
  [ "$m" = "PFL7560" ] || { err "não e um PFL7560 em $DEV (getprop devolveu '${m:-vazio}')"; exit 2; }
  # hidebug vive em /vendor/bin e exige root; o adbd sobe como uid=2000(shell).
  # Sem esta escalada TODA amostragem falha em silencio (bug histórico do
  # autocaptura: 8253 TSVs so-cabecalho, doc 35 seção 4).
  local u; u=$(sh_ id)
  case "$u" in *"uid=0"*) ;; *)
    timeout 15 "$ADB" -s "$DEV" root >/dev/null 2>&1; sleep 3
    timeout 10 "$ADB" connect "$DEV" >/dev/null 2>&1
    u=$(sh_ id)
    case "$u" in *"uid=0"*) ;; *) err "sem root: hidebug não responde. Abortei."; exit 2 ;; esac ;;
  esac
  ok "conectado ao PFL7560 em $IP (root)"
}

# brilho REAL aplicado (PWM). Le no maximo 996 quando o alvo logico e 1000 --
# não comparar com 1000 (doc 35 seção 4, item 5).
le_bri(){ hid 'gbri 0' | grep -a -i 'brightness' | grep -aoE '[0-9]+' | sed -n 1p; }
le_optica(){ sh_ getprop zysys.env_temp   | tr -d '℃ '; }
le_placa(){  sh_ getprop zysys.light_temp | tr -d '℃ '; }

RESTAURAR=0
restaura(){
  [ "$RESTAURAR" = "1" ] || return 0
  printf '\n'; say "restaurando brilho automático..."
  hid 'sbri 0 1000' >/dev/null 2>&1
  # o loop termico reassume o controle sozinho; o sbri acima so encurta a rampa
  ok "brilho devolvido ao controle da politica termica"
}
trap restaura EXIT INT TERM

# ---------------------------------------------------------------- --niveis
cmd_niveis(){
  conecta
  say "lista de niveis validos que o firmware declara (gbll):"
  hid 'gbll' | sed 's/^/  /'
  printf '\n'
  say "brilho aplicado agora (gbri 0, PWM real):"
  printf '  %s\n' "$(le_bri)"
}

# ------------------------------------------------------------------ --piso
# Varre para baixo perguntando ao operador o que a TELA mostra. E o gate de
# docs/research/06:144. Cada degrau dura poucos segundos, entao a reversao do
# loop termico (2-3 unidades/2 s) e desprezivel dentro do degrau.
cmd_piso(){
  conecta
  RESTAURAR=1
  printf '\n'
  say "== mapeamento do PISO REAL do LED =="
  cat <<'TXT'
  Vou aplicar niveis de brilho decrescentes. Em CADA um, olhe a tela e responda.
  O que procurar, em ordem de gravidade:
    c = CINTILA / pisca / oscila   -> achou o piso, para aqui
    a = APAGOU / preto             -> achou o piso, para aqui
    s = so escureceu, imagem OK    -> segue para o proximo
  Nada disto grava no aparelho. Ctrl-C a qualquer momento restaura.
TXT
  printf '\n'
  local piso_ok="" primeiro_ruim=""
  for n in $DEGRAUS_PISO; do
    hid "sbri 0 $n" >/dev/null
    sleep 3
    local real; real=$(le_bri)
    printf "  nivel %-5s -> gbri devolveu %-6s  " "$n" "${real:-?}"
    # se o firmware clampou, o gbri volta bem diferente do pedido
    if [ -n "${real:-}" ] && [ "$real" -gt 0 ] 2>/dev/null; then
      local dif=$(( real > n ? real - n : n - real ))
      [ "$dif" -gt 60 ] && printf "${A}(clampou?)${Z} "
    fi
    local r=""
    while [ -z "$r" ]; do
      printf "[s/c/a] "
      read -r r </dev/tty || r=a
      case "$r" in s|S|c|C|a|A) ;; *) r="" ;; esac
    done
    case "$r" in
      s|S) piso_ok="$n" ;;
      *)   primeiro_ruim="$n"; break ;;
    esac
  done
  printf '\n'
  if [ -n "$primeiro_ruim" ]; then
    warn "primeiro nivel RUIM: $primeiro_ruim"
    ok   "menor nivel ACEITAVEL: ${piso_ok:-nenhum}"
    say  "=> o piso utilizavel e ${piso_ok:-indeterminado}. Nao escreva FW_LEVEL abaixo disso."
  else
    ok "todos os niveis ate $(echo "$DEGRAUS_PISO" | awk '{print $NF}') foram aceitos"
    say "=> o LED aceita a faixa inteira varrida. O limite não foi encontrado."
  fi
  printf '\n'
  say "ANOTE o resultado em docs/research/ - este e o gate do doc 06:144."
}

# ----------------------------------------------------------------- --curva
# Segura UM nivel por N minutos e mede a temperatura da optica em regime.
# Reaplica o nivel a cada REAPLICA_S para vencer o RunLineChange, e registra o
# gbri real em cada amostra: se a coluna bri_real subir, o loop venceu e o dado
# daquela linha NÃO vale.
cmd_curva(){
  local nivel="$1" amb="$2" minutos="$3"
  case "$nivel" in ''|*[!0-9]*) err "nivel inválido: '$nivel'"; exit 2 ;; esac
  [ "$nivel" -ge 100 ] && [ "$nivel" -le 1000 ] || { err "nivel fora de 100..1000"; exit 2; }
  case "$amb" in ''|*[!0-9.]*) err "--ambiente e OBRIGATORIO e numerico (ex.: 24.5)"; exit 2 ;; esac

  conecta
  RESTAURAR=1
  local dir="evidencias/$(date +%Y-%m-%d)"
  mkdir -p "$dir"
  local out="$dir/brilho-${nivel}-$(date +%H%M%S).tsv"
  # AMBIENTE e a coluna que faltou nas 4 medicoes historicas de exaustao e que as
  # tornou incomparaveis entre si (doc 39 seção 2.6). Sem ela não ha delta valido.
  printf 'ts\tuptime_s\tnivel_alvo\tbri_real\tambiente_C\toptica_C\tplaca_C\tdelta_sobre_amb\tregime\n' > "$out"

  say "== curva termica no nivel $nivel =="
  printf "  ambiente informado: %s C\n" "$amb"
  printf "  duracao: %s min   amostra: %ss   reaplica o nivel a cada %ss\n" "$minutos" "$INTERVALO_S" "$REAPLICA_S"
  printf "  saida: %s\n\n" "$out"
  warn "mantenha a MESMA cena na tela durante todo o teste (de preferencia branco 100%)"
  printf '\n'

  hid "sbri 0 $nivel" >/dev/null
  local fim=$(( $(date +%s) + minutos * 60 ))
  local prox_reaplica=$(( $(date +%s) + REAPLICA_S ))
  local hist="" n_reg=0 regime="NAO"
  while [ "$(date +%s)" -lt "$fim" ]; do
    if [ "$(date +%s)" -ge "$prox_reaplica" ]; then
      hid "sbri 0 $nivel" >/dev/null
      prox_reaplica=$(( $(date +%s) + REAPLICA_S ))
    fi
    local o p b up
    o=$(le_optica); p=$(le_placa); b=$(le_bri)
    up=$(sh_ 'cut -d" " -f1 /proc/uptime')
    if [ -z "$o" ]; then
      warn "props não responderam - reconectando"
      timeout 10 "$ADB" connect "$DEV" >/dev/null 2>&1; sleep 10; continue
    fi
    local d; d=$(awk -v a="$o" -v b="$amb" 'BEGIN{printf "%.1f", a-b}')

    # regime: REGIME_N amostras consecutivas dentro de REGIME_BANDA (um degrau do ADC)
    hist="$hist $o"; hist=$(echo "$hist" | awk -v k="$REGIME_N" '{n=NF; s=""; for(i=(n>k?n-k+1:1);i<=n;i++) s=s" "$i; print s}')
    n_reg=$(echo "$hist" | wc -w)
    if [ "$n_reg" -ge "$REGIME_N" ]; then
      regime=$(echo "$hist" | awk -v band="$REGIME_BANDA" '{mn=$1;mx=$1; for(i=1;i<=NF;i++){if($i<mn)mn=$i; if($i>mx)mx=$i} print (mx-mn<=band)?"SIM":"NÃO"}')
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date +%H:%M:%S)" "${up:-NA}" "$nivel" "${b:-NA}" "$amb" "$o" "${p:-NA}" "$d" "$regime" >> "$out"
    printf "  %s  optica %s C  (amb %s, delta %s)  bri_real %-5s regime=%s\n" \
      "$(date +%H:%M:%S)" "$o" "$amb" "$d" "${b:-?}" "$regime"

    # se o loop venceu a reaplicacao, avisa alto: as linhas seguintes não valem
    if [ -n "${b:-}" ] && [ "$b" -gt $(( nivel + 80 )) ] 2>/dev/null; then
      warn "o loop termico reassumiu o brilho (bri_real=$b > alvo=$nivel). Baixe REAPLICA_S."
    fi
    sleep "$INTERVALO_S"
  done

  printf '\n'
  say "== resumo =="
  awk -F'\t' 'NR>1 && $9=="SIM"{n++; s+=$6; if(min==""||$6<min)min=$6; if($6>max)max=$6}
    END{ if(n>0) printf "  em regime: n=%d  media=%.2f C  min=%.2f  max=%.2f  (amb informado na coluna 5)\n", n, s/n, min, max;
         else print "  NÃO atingiu regime na janela - rode por mais tempo" }' "$out"
  printf "\n  arquivo: %s\n" "$out"
  cat <<'TXT'

  COMO COMPARAR COM OUTRA CONDICAO:
    Rode de novo com o outro nivel (ou com o ventilador externo ligado), MESMO
    ambiente e MESMA cena. Compare as medias em regime.
    PISO DE SIGNIFICANCIA: o ADC tem degraus de ~2,3 C, entao diferenca menor que
    4,6 C (dois degraus) NAO e evidencia. Doc 39, secao 2.9.
TXT
}

# -------------------------------------------------------------------- main
AMB=""; MIN=25; NIVEL=""; MODO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --niveis)   MODO=niveis; shift ;;
    --piso)     MODO=piso; shift ;;
    --curva)    MODO=curva; NIVEL="${2:-}"; shift 2 || shift ;;
    --ambiente) AMB="${2:-}"; shift 2 || shift ;;
    --minutos)  MIN="${2:-25}"; shift 2 || shift ;;
    -h|--help)  MODO=ajuda; shift ;;
    *) err "argumento desconhecido: $1"; MODO=ajuda; break ;;
  esac
done

case "$MODO" in
  niveis) cmd_niveis ;;
  piso)   cmd_piso ;;
  curva)  cmd_curva "$NIVEL" "$AMB" "$MIN" ;;
  *)
    cat <<'TXT'
uso:
  PFL_IP=<ip> ./pfl7560-teste-brilho.sh --niveis
      lista os niveis validos (gbll) e o brilho atual. Nao muda nada.

  PFL_IP=<ip> ./pfl7560-teste-brilho.sh --piso
      GATE do doc 06:144. Varre 1000..400 perguntando o que a tela mostra em cada
      degrau, e diz qual e o menor nivel utilizavel. Dura ~1 min. Restaura na saida.

  PFL_IP=<ip> ./pfl7560-teste-brilho.sh --curva 750 --ambiente 24.5 [--minutos 25]
      Segura um nivel e mede a temperatura da optica ate o regime, gravando TSV em
      evidencias/. --ambiente e OBRIGATORIO. Reaplica o nivel para vencer o loop
      termico e registra o brilho real em cada amostra.

variaveis: REAPLICA_S (15) INTERVALO_S (30) REGIME_N (6) REGIME_BANDA (2.4)

seguranca: nao escreve em /vendor, nao usa `gtt`, e o trap devolve o brilho ao
controle da politica termica em qualquer saida, inclusive Ctrl-C.
TXT
    exit 1 ;;
esac
