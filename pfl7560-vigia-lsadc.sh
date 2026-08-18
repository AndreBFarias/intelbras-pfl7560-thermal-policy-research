#!/usr/bin/env bash
# pfl7560-vigia-lsadc.sh - mede a TAXA de episodios de LSADC Error por hora de
# uso real, sem sondar o aparelho.
#
# A PERGUNTA QUE ESTE INSTRUMENTO RESPONDE:
#   "quantas vezes o LSADC Error aparece por hora de uso real, sem ninguem
#    sondando" -- e o numero que decide entre "foi o observador" e "e um terceiro
#    defeito de fabrica".
#
# POR QUE ELE NÃO PODE USAR hidebug: os comandos gtt forcam comutacao do mux dos
# termistores e sao SUSPEITOS de serem o próprio gatilho do erro (doc 35,
# LSADC-S2). Um instrumento que usa hidebug mede o observador, não o fenomeno.
# Aqui so ha logcat (leitura passiva de buffer) e /proc/uptime.
#
# O BURACO DE COBERTURA E O INIMIGO: se o vigia ficar fora do ar durante um
# episodio, a taxa sai viesada PARA BAIXO -- e um falso "esta tudo bem". Por isso
# ele registra a cobertura explicitamente e o resumo desconta o que não foi
# observado. Toda reconexao faz um backfill do buffer do logcat, que guarda
# histórico, para recuperar o que passou enquanto estava fora.
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh            # vigia (roda ate Ctrl-C)
#   PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh --resumo   # calcula a taxa e sai
set -u

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="${VIGIA_DIR:-$HERE/evidencias/lsadc}"
EV="$DIR/eventos.tsv"
COB="$DIR/cobertura.tsv"
# duas ocorrencias separadas por menos que isso pertencem ao MESMO episodio
GAP_EPISODIO="${GAP_EPISODIO:-60}"
mkdir -p "$DIR"

[ -s "$EV" ]  || printf 'ts_host\tboot_id\tevento\tlinha\n' > "$EV"
[ -s "$COB" ] || printf 'evento\tts_host\tboot_id\tuptime_s\n' > "$COB"

V='\033[1;32m'; X='\033[1;31m'; A='\033[1;33m'; C='\033[1;36m'; Z='\033[0m'
agora(){ date '+%Y-%m-%d %H:%M:%S'; }

# Identidade do boot = instante em que o aparelho ligou (epoch do host menos o
# uptime). Muda quando ha reboot, entao serve para separar sessões e para
# detectar que o aparelho reiniciou entre duas janelas de cobertura.
#
# Seta BID e UPTIME como globais em vez de imprimir: chamada em $(...) rodaria
# num subshell e o UPTIME não voltaria para o chamador.
BID=""; UPTIME=""
le_boot(){
  local up bruto; up=$(timeout 10 "$ADB" -s "$DEV" shell 'cut -d" " -f1 /proc/uptime' </dev/null 2>/dev/null | tr -d '\r')
  [ -n "$up" ] || return 1
  UPTIME="${up%%.*}"
  bruto=$(( $(date +%s) - UPTIME ))
  # O calculo flutua +-1 s entre leituras (latencia do adb + truncamento do
  # uptime), o que criaria um "boot novo" a cada janela e inflaria a contagem de
  # sessões. Um reboot de verdade move isso em minutos, entao qualquer variacao
  # menor que 60 s e a mesma sessão: mantem o primeiro valor como canônico.
  if [ -n "$BID" ] && [ $(( bruto > BID ? bruto - BID : BID - bruto )) -lt 60 ]; then
    return 0
  fi
  BID="$bruto"
}

conecta(){
  timeout 15 "$ADB" connect "$DEV" >/dev/null 2>&1
  local m; m=$(timeout 10 "$ADB" -s "$DEV" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r')
  [ "$m" = "PFL7560" ]
}

# So as linhas que interessam. O erro repete a cada ~2 s durante um episodio;
# guardamos todas e o agrupamento em episodios acontece no resumo.
FILTRO='LSADC Error|Achieve Balance|Upset Balance|Overheat|Level Change|PWM Duty Change|bAbnormal'

registra(){  # registra <BID> <origem>
  local bid="$1" origem="$2" linha ev
  while IFS= read -r linha; do
    # tira as cores ANSI que o firmware injeta no log
    linha=$(printf '%s' "$linha" | sed 's/\x1b\[[0-9;]*m//g')
    case "$linha" in
      *"LSADC Error"*)     ev=LSADC_ERROR ;;
      *"Upset Balance"*)   ev=UPSET ;;
      *"Achieve Balance"*) ev=BALANCE ;;
      *Overheat*)          ev=OVERHEAT ;;
      *"Level Change"*)    ev=LEVEL ;;
      *"PWM Duty Change"*) ev=FAN ;;
      *bAbnormal=1*)       ev=FAN_ANORMAL ;;
      *) continue ;;
    esac

    # ESCADA DE BRILHO ATUANDO. O firmware loga "Level Change X => Y" a cada
    # tick, quase sempre com X == Y (nada mudou). O que interessa e a transicao
    # de verdade: X != Y significa que a politica de backlight reagiu a
    # temperatura -- descer e a escada protegendo a optica, subir e ela
    # devolvendo brilho na queda. Essas nunca sao amostradas.
    if [ "$ev" = LEVEL ]; then
      local de para
      de=$(printf '%s' "$linha" | sed -n 's/.*Level Change \([0-9]\{1,\}\) => \([0-9]\{1,\}\).*/\1/p')
      para=$(printf '%s' "$linha" | sed -n 's/.*Level Change \([0-9]\{1,\}\) => \([0-9]\{1,\}\).*/\2/p')
      if [ -n "$de" ] && [ -n "$para" ] && [ "$de" != "$para" ]; then
        ev=ESCADA
        if [ "$para" -lt "$de" ]; then
          printf "${A}[%s] ESCADA ATUOU: brilho %s -> %s (protegendo a optica)${Z}\n" "$(agora)" "$de" "$para"
        else
          printf "${V}[%s] ESCADA DEVOLVEU brilho: %s -> %s (temperatura caiu)${Z}\n" "$(agora)" "$de" "$para"
        fi
      fi
    fi

    # fan saindo do maximo tambem e evento raro que não pode ser amostrado
    if [ "$ev" = FAN ]; then
      case "$linha" in *"=> 1000!"*) ;; *) ev=FAN_ABAIXO_DO_MAXIMO
        printf "${X}[%s] FAN SAIU DO MAXIMO: %s${Z}\n" "$(agora)" "$linha" ;; esac
    fi

    # PRECURSOR: "Upset Balance" por si so e evento NORMAL -- e o loop dizendo
    # que a temperatura saiu do equilibrio, e o valor vem em mC plausivel
    # (ex.: 31360 = 31,4 C). O que interessa e o valor INVÁLIDO entrando no loop.
    #
    # Dois casos ja observados neste aparelho, com ordens de grandeza opostas:
    #   -1296474592  (2026-07-05, heat.logcat linha 167) -- lixo, precedeu o erro
    #             2  (2026-08-17, sessao-diagnostico-231714.tsv 23:20:44) -- 2 mC
    #                no meio de uma serie estavel em 63421, sete minutos antes do
    #                episodio travado. ATENCAO: essa veio de uma SONDAGEM externa
    #                via hidebug, não do loop do firmware. Aqui, ao contrario, o
    #                valor sai do log do próprio firmware -- por isso este vigia
    #                mede o fenomeno, e aquele capturador media o observador.
    #
    # FAIXA: os sensores deste aparelho leem 28-32 C (placa) e 55-70 C (optica).
    # Qualquer coisa abaixo de 5 C ou acima de 120 C e leitura inválida, não
    # temperatura. A faixa anterior (-1000 a 150000) deixava o "2 mC" passar --
    # justamente o caso mais interessante.
    if [ "$ev" = UPSET ] || [ "$ev" = BALANCE ]; then
      local val; val=$(printf '%s' "$linha" | sed -n 's/.*Temperature:\(-\{0,1\}[0-9]\{1,\}\).*/\1/p')
      if [ -n "$val" ] && { [ "$val" -lt 5000 ] || [ "$val" -gt 120000 ]; } 2>/dev/null; then
        ev="${ev}_ANOMALO"
        printf "${X}[%s] leitura INVÁLIDA do LSADC: %s mC (precursor de LSADC Error)${Z}\n" "$(agora)" "$val"
      fi
    fi

    # os normais sao muito frequentes e so servem de contraprova de que o loop
    # esta vivo; um a cada 20 basta e evita arquivo gigante. Os anomalos e os
    # erros nunca sao amostrados: entram todos.
    case "$ev" in
      BALANCE|LEVEL|UPSET|FAN) N=$((${N:-0}+1)); [ $((N % 20)) -eq 0 ] || continue ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$(agora)" "$bid" "$ev" "$linha" >> "$EV"
    [ "$ev" = "LSADC_ERROR" ] && printf "${X}[%s] LSADC Error detectado (origem: %s)${Z}\n" "$(agora)" "$origem"
  done
}

vigia(){
  [ -n "$IP" ] || { echo "defina PFL_IP=<ip do projetor>"; exit 2; }
  # TRAVA CONTRA DUPLICACAO: duas instancias gravam janelas de cobertura
  # sobrepostas no mesmo arquivo e a medicao passa a contar o mesmo tempo duas
  # vezes (visto em 2026-08-18: 6,76 h somadas para 2,36 h reais). Como o
  # numero de horas observadas e o criterio de decisao do estudo, isso não pode
  # acontecer em silencio.
  LOCK="$DIR/vigia.pid"
  if [ -f "$LOCK" ]; then
    _p=$(cat "$LOCK" 2>/dev/null)
    if [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null; then
      echo "ja existe um vigia rodando (PID $_p). Encerre-o antes, ou apague $LOCK se for orfao."
      exit 2
    fi
  fi
  echo $$ > "$LOCK"
  trap 'rm -f "$LOCK"' EXIT INT TERM
  DEV="$IP:$PORTA"
  printf "${C}vigia LSADC iniciado${Z}  destino: %s\n" "$DIR"
  printf "passivo: so logcat e /proc/uptime. Nenhum acesso ao hidebug.\n\n"
  local ANT_BID=""
  while :; do
    if ! conecta || ! le_boot; then
      sleep 30; continue
    fi
    if [ "$BID" != "$ANT_BID" ]; then
      [ -n "$ANT_BID" ] && printf "${A}[%s] o aparelho REINICIOU${Z}\n" "$(agora)"
      printf "${V}[%s] sessão ativa (boot_id=%s, ligado ha %ss)${Z}\n" "$(agora)" "$BID" "$UPTIME"
      ANT_BID="$BID"
    fi
    printf 'COBERTURA_INICIO\t%s\t%s\t%s\n' "$(agora)" "$BID" "$UPTIME" >> "$COB"

    # backfill: o buffer do logcat guarda o histórico do boot, entao uma leitura
    # unica recupera o que aconteceu enquanto o vigia estava fora do ar
    timeout 60 "$ADB" -s "$DEV" shell 'logcat -d -v time -s ZYThermalManager' </dev/null 2>/dev/null \
      | grep -aE "$FILTRO" | registra "$BID" backfill

    # streaming: enquanto a conexao viver, cada linha chega na hora
    timeout 21600 "$ADB" -s "$DEV" shell 'logcat -v time -s ZYThermalManager' </dev/null 2>/dev/null \
      | grep -aE --line-buffered "$FILTRO" | registra "$BID" stream

    local up_fim; up_fim=$(timeout 10 "$ADB" -s "$DEV" shell 'cut -d" " -f1 /proc/uptime' </dev/null 2>/dev/null | tr -d '\r')
    printf 'COBERTURA_FIM\t%s\t%s\t%s\n' "$(agora)" "$BID" "${up_fim%%.*}" >> "$COB"
    printf "${A}[%s] cobertura interrompida (aparelho desligou ou a rede caiu)${Z}\n" "$(agora)"
    sleep 20
  done
}

resumo(){
  [ -s "$COB" ] || { echo "sem dados ainda em $COB"; exit 1; }
  printf "${C}== cobertura observada ==${Z}\n"
  # soma as janelas fechadas; uma janela aberta (sem FIM) conta ate agora
  # UNIAO das janelas, não soma: janelas sobrepostas (duas instancias, ou
  # reconexao rapida) contariam o mesmo tempo real duas vezes e inflariam as
  # horas observadas, que sao o criterio de decisao do estudo.
  awk -F'\t' -v agora="$(date +%s)" '
    function seg(s){ gsub(/-/," ",s); gsub(/:/," ",s); return mktime(s) }
    NR>1 && $1=="COBERTURA_INICIO" { ini[++n]=seg($2); fim[n]=0 }
    NR>1 && $1=="COBERTURA_FIM" { for(i=n;i>=1;i--) if(fim[i]==0){ fim[i]=seg($2); break } }
    END{
      if(n==0){ print "  nenhuma janela registrada"; exit }
      ab=0
      for(i=1;i<=n;i++) if(fim[i]==0){ fim[i]=agora; ab=1 }
      for(i=1;i<=n;i++) for(j=i+1;j<=n;j++) if(ini[j]<ini[i]){
        t=ini[i];ini[i]=ini[j];ini[j]=t; t=fim[i];fim[i]=fim[j];fim[j]=t }
      soma=0; for(i=1;i<=n;i++) soma+=fim[i]-ini[i]
      uni=0; ci=ini[1]; cf=fim[1]
      for(i=2;i<=n;i++){ if(ini[i]<=cf){ if(fim[i]>cf) cf=fim[i] } else { uni+=cf-ci; ci=ini[i]; cf=fim[i] } }
      uni+=cf-ci
      if(ab) printf "  (uma janela ainda aberta)\n"
      printf "  janelas de observacao : %d\n", n
      printf "  tempo observado       : %.2f h (%.0f min)\n", uni/3600, uni/60
      if(soma-uni > 60) printf "  (havia %.2f h de sobreposicao, descontada)\n", (soma-uni)/3600
    }' "$COB"

  local boots; boots=$(awk -F'\t' 'NR>1{print $3}' "$COB" | sort -u | wc -l)
  printf "  boots distintos       : %s\n" "$boots"

  printf "\n${C}== episodios de LSADC Error ==${Z}\n"
  printf "  (ocorrencias separadas por >= %ss contam como episodios diferentes)\n" "$GAP_EPISODIO"
  awk -F'\t' -v gap="$GAP_EPISODIO" '
    function seg(s){ gsub(/-/," ",s); gsub(/:/," ",s); return mktime(s) }
    NR>1 && $3=="LSADC_ERROR" {
      t=seg($1)
      if(ant==0 || t-ant>=gap){ ep++; ini[ep]=$1; bid[ep]=$2 }
      fim[ep]=$1; linhas[ep]++; ant=t
    }
    END{
      if(ep==0){ print "  NENHUM episodio observado."; exit }
      printf "  %-4s %-21s %-21s %-8s %s\n", "ep", "inicio", "fim", "linhas", "boot_id"
      for(i=1;i<=ep;i++) printf "  %-4d %-21s %-21s %-8d %s\n", i, ini[i], fim[i], linhas[i], bid[i]
      printf "  TOTAL: %d episodio(s)\n", ep
    }' "$EV"

  printf "\n${C}== escada de brilho e ventiladores ==${Z}\n"
  awk -F'\t' '
    NR>1 && $3=="ESCADA" { n++; print "  ESCADA  " $1 "  " $4 }
    NR>1 && $3=="FAN_ABAIXO_DO_MAXIMO" { f++; print "  FAN     " $1 "  " $4 }
    NR>1 && $3=="FAN_ANORMAL" { a++; print "  ANORMAL " $1 "  " $4 }
    NR>1 && $3=="FAN" { ok++ }
    END{
      if(n==0) print "  escada: nenhuma atuacao observada (so conta se a optica passar de 66 C)"
      else printf "  escada: %d transicao(oes) de brilho observada(s)\n", n
      if(f+a>0) printf "  fans:   %d saida(s) do maximo, %d anomalia(s) -- INVESTIGAR\n", f+0, a+0
      else if(ok>0) printf "  fans:   sempre no maximo (%d confirmacoes de duty 1000)\n", ok
      else print "  fans:   sem confirmacao ainda (amostradas 1 a cada 20; aguarde alguns minutos)"
    }' "$EV"

  printf "\n${C}== precursores (valor de temperatura fora de faixa) ==${Z}\n"
  awk -F'\t' '
    NR>1 && $3 ~ /_ANOMALO$/ { n++; print "  " $1 "  " $4 }
    END{ if(n==0) print "  nenhum valor fora de faixa observado."
         else printf "  TOTAL: %d leitura(s) inválida(s) que NÃO viraram LSADC Error ainda\n", n }' "$EV"

  printf "\n${C}== veredito ==${Z}\n"
  local h ep
  h=$(awk -F'\t' -v agora="$(date +%s)" '
    function seg(s){ gsub(/-/," ",s); gsub(/:/," ",s); return mktime(s) }
    NR>1 && $1=="COBERTURA_INICIO"{ ini[++n]=seg($2); fim[n]=0 }
    NR>1 && $1=="COBERTURA_FIM"{ for(i=n;i>=1;i--) if(fim[i]==0){ fim[i]=seg($2); break } }
    END{
      if(n==0){ printf "0.0000"; exit }
      for(i=1;i<=n;i++) if(fim[i]==0) fim[i]=agora
      for(i=1;i<=n;i++) for(j=i+1;j<=n;j++) if(ini[j]<ini[i]){
        t=ini[i];ini[i]=ini[j];ini[j]=t; t=fim[i];fim[i]=fim[j];fim[j]=t }
      uni=0; ci=ini[1]; cf=fim[1]
      for(i=2;i<=n;i++){ if(ini[i]<=cf){ if(fim[i]>cf) cf=fim[i] } else { uni+=cf-ci; ci=ini[i]; cf=fim[i] } }
      uni+=cf-ci; printf "%.4f", uni/3600 }' "$COB")
  ep=$(awk -F'\t' -v gap="$GAP_EPISODIO" '
    function seg(s){ gsub(/-/," ",s); gsub(/:/," ",s); return mktime(s) }
    NR>1 && $3=="LSADC_ERROR"{ t=seg($1); if(ant==0||t-ant>=gap) ep++; ant=t }
    END{ print ep+0 }' "$EV")

  if [ "$ep" -gt 0 ]; then
    awk -v e="$ep" -v h="$h" 'BEGIN{ printf "  taxa observada: %.3f episodios por hora (%d em %.2f h)\n", e/h, e, h }'
    printf "  ${X}CONCLUSAO: o erro ocorre no uso real. Nao e artefato do observador.${Z}\n"
    printf "  Consequencia: verificar de vez em quando NÃO basta -- e preciso vigiar e reiniciar.\n"
  else
    # Regra dos tres: com zero eventos em h horas, o limite superior de 95%% para
    # a taxa e 3/h. E o maximo que se pode afirmar a partir de "não vi nenhum".
    awk -v h="$h" 'BEGIN{
      if(h<=0){ print "  sem tempo observado ainda."; exit }
      printf "  zero episodios em %.2f h de observacao.\n", h
      printf "  limite superior (regra dos tres, 95%%): taxa < %.3f por hora\n", 3/h
      printf "  ou seja: se houvesse 1 episodio a cada %.1f h, provavelmente ja teria aparecido.\n", h/3
      if(h < 10) printf "  AINDA INSUFICIENTE. Para descartar 1 episodio a cada 10 h, observe ~30 h.\n"
      else if(h < 30) printf "  Ja descarta taxas altas. Para descartar 1 a cada 10 h, chegue a ~30 h.\n"
      else printf "  Observacao suficiente para descartar taxa >= 1 episodio a cada 10 h.\n"
    }'
  fi
  printf "\n  dados brutos: %s\n                %s\n" "$EV" "$COB"
}

case "${1:-}" in
  --resumo) resumo ;;
  "")       vigia ;;
  *) echo "uso: PFL_IP=<ip> $0 [--resumo]"; exit 2 ;;
esac
