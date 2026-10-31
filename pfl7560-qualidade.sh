#!/usr/bin/env bash
# pfl7560-qualidade.sh - os ajustes de imagem do PFL7560 contra o "maximo de qualidade" (bloco 11;
# docs/research/46-foco-e-qualidade.md s3 e s4). Le e mostra; so muda algo com --aplicar <ajuste>
# e a palavra MUDAR digitada, guardando o valor antigo para --voltar.
#
# O que le (adb por Wi-Fi, root; pelo hidebug, modulo "picture", os mesmos codigos do menu):
#   modo de imagem (gpicm), nitidez (gshr), reducao de ruido (gnr), MEMC (gmemc), contraste
#   dinamico DCI (gdci), overscan (govs) e a saida para o painel (getprop sys.nl.panel.resolution,
#   persist.display.720p e "wm size"; so leitura). Nunca gtt, nem nada do foco ou dos 4 pontos.
#
# Estes ajustes agem no caminho de VIDEO (HDMI, arquivos no player); a tela de calibracao da suite
# e plano grafico e nao passa por eles (doc 46 s3.4). O "maximo" e o da tabela do doc 46 s3.2,
# INFERIDO: confira pela camera (o mesmo video antes e depois) antes de deixar uma mudanca.
#
# Uso:
#   PFL_IP=<ip> ./pfl7560-qualidade.sh                     le e compara (so leitura)
#   PFL_IP=<ip> ./pfl7560-qualidade.sh --aplicar <ajuste>  poe UM ajuste no sugerido (pede MUDAR)
#   PFL_IP=<ip> ./pfl7560-qualidade.sh --voltar <ajuste>   devolve o valor guardado (pede MUDAR)
#   ./pfl7560-qualidade.sh --lista                         os ajustes e o sugerido (sem aparelho)
#   ./pfl7560-qualidade.sh --ajuda
# O valor antigo fica em backups-projetor/qualidade/<ajuste>.txt (ou PFL_BACKUPS). Um --aplicar com
# o antigo ja guardado NAO o sobrescreve: o guardado e o de antes da primeira mudanca.
# PROVISORIO: o formato da saida do hidebug no modulo picture nao foi visto no aparelho (doc 46 s9,
# item 4); o valor lido e o ultimo numero da resposta. Sem numero, nada e mudado.
set -uo pipefail
export LC_ALL=C

ADB="${ADB:-adb}"
PORTA=5555
IP="${PFL_IP:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BK="${PFL_BACKUPS:-$HERE/backups-projetor/qualidade}"
HIDEBUG=/vendor/bin/hidebug

AJUSTES='modo|gpicm|spicm|0 3|0|modo de imagem (0 padrao, 1 dinamico, 2 suave, 3 usuario, 4 vivido, 5 natural, 6 esporte)
nitidez|gshr|sshr|50|50|nitidez 0-100 (acima de 50 estreita a borda com halo, sem detalhe novo)
nr|gnr|snr|0|0|reducao de ruido (0 desligada ... 3 alta, 4 automatica)
memc|gmemc|smemc|0|0|MEMC, interpolacao de movimento (0 desligada)
dci|gdci|sdci|0|0|contraste dinamico DCI (0 desligado)
overscan|govs|sovs|0|0|overscan (0 = sem corte nem reescala)'

X='\033[1;31m'; V='\033[1;32m'; A='\033[1;33m'; C='\033[1;36m'; Z='\033[0m'
err(){ printf "${X}[ERRO]${Z}  %s\n" "$*" >&2; }
ok(){  printf "${V}[OK]${Z}    %s\n" "$*" >&2; }
warn(){ printf "${A}[AVISO]${Z} %s\n" "$*" >&2; }
say(){ printf "${C}>> %s${Z}\n" "$*" >&2; }
ajuda(){ sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; }

linha_de(){ printf '%s\n' "$AJUSTES" | awk -F'|' -v n="$1" '$1 == n'; }
campo_de(){ linha_de "$1" | cut -d'|' -f"$2"; }
nomes(){ printf '%s\n' "$AJUSTES" | cut -d'|' -f1 | tr '\n' ' '; }

MODO=ler
ALVO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --aplicar|--voltar) MODO="${1#--}"; ALVO="${2:-}"; [ -n "$ALVO" ] || { err "$1 pede o nome do ajuste: $(nomes)"; exit 2; }; shift 2 ;;
    --lista) MODO=lista; shift ;;
    --ajuda|-h|--help) ajuda; exit 0 ;;
    *) err "argumento desconhecido: $1 (veja --ajuda)"; exit 2 ;;
  esac
done
if [ -n "$ALVO" ] && [ -z "$(linha_de "$ALVO")" ]; then
  err "ajuste desconhecido: $ALVO (os ajustes: $(nomes))"; exit 2
fi

lista(){
  printf '%-9s %-6s %-9s %s\n' "AJUSTE" "LE" "MAXIMO" "O QUE E"
  printf '%s\n' "$AJUSTES" | awk -F'|' '{ m = $4; gsub(/ /, " ou ", m); printf "%-9s %-6s %-9s %s\n", $1, $2, m, $6 }'
  printf '%-9s %-6s %-9s %s\n' "saida" "props" "1080P" "saida para o painel: 1920x1080 nativa, sem a UI de 720p (so leitura)"
}

D=""
sh_dev(){ "$ADB" -s "$D" shell "$1" </dev/null 2>/dev/null | tr -d '\r'; }
conecta(){
  [ -n "$IP" ] || { err "defina PFL_IP=<ip do projetor> (o adb deste aparelho e so por Wi-Fi, TCP 5555)"; exit 2; }
  case "$IP" in *:*) D="$IP" ;; *) D="$IP:$PORTA" ;; esac
  timeout 15 "$ADB" connect "$D" >/dev/null 2>&1
  local u m
  u="$(sh_dev id | grep -oE 'uid=[0-9]+' | head -1)"
  if [ "$u" != "uid=0" ]; then
    timeout 15 "$ADB" -s "$D" root >/dev/null 2>&1; sleep 2
    timeout 15 "$ADB" connect "$D" >/dev/null 2>&1
  fi
  m="$(sh_dev "getprop ro.product.model" | tr -d '\n ')"
  [ "$m" = "PFL7560" ] || { err "o dispositivo em $D NAO e um PFL7560 (modelo '${m:-vazio}') - nada foi feito"; exit 2; }
  u="$(sh_dev id | grep -oE 'uid=[0-9]+' | head -1)"
  [ "$u" = "uid=0" ] || { err "sem root em $D (id devolveu '${u:-vazio}'): o hidebug nao responde - nada foi feito"; exit 2; }
  ok "conectado ao PFL7560 em $D (root)"
}

LEITURA=""
ler_tudo(){
  local cmds c
  cmds=$(printf '%s\n' "$AJUSTES" | cut -d'|' -f2 | tr '\n' ' ')
  c="for c in $cmds; do echo \"@@ \$c\"; printf 'picture\\n%s\\nquit\\n' \"\$c\" | $HIDEBUG 2>&1; done;"
  c="$c echo '@@ saida'; getprop sys.nl.panel.resolution; getprop persist.display.720p; wm size"
  LEITURA="$(sh_dev "$c")"
  [ -n "$LEITURA" ] || { err "o aparelho nao respondeu a leitura"; exit 1; }
  case "$LEITURA" in *"errno = 13"*) err "o hidebug negou acesso (errno = 13): sem root"; exit 1 ;; esac
}
secao(){ printf '%s\n' "$LEITURA" | awk -v s="@@ $1" '$0 == s { d = 1; next } /^@@ / { d = 0 } d'; }
valor(){ secao "$1" | grep -aoE '[0-9]+' | tail -1; }
dentro(){ case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

mostrar(){
  local n g aceitos desc v est fora=0 res p720 wm
  echo "PFL7560 - ajustes de imagem contra o maximo de qualidade (doc 46 s3.2)"
  echo
  printf '  %-9s %-6s %-9s %-8s %s\n' "AJUSTE" "ATUAL" "MAXIMO" "ESTADO" "O QUE E"
  while IFS='|' read -r n g _ aceitos _ desc; do
    v="$(valor "$g")"
    if [ -z "$v" ]; then est="sem leitura"; v="?"
    elif dentro "$v" "$aceitos"; then est="ok"
    else est="fora"; fora=$((fora + 1)); fi
    printf '  %-9s %-6s %-9s %-8s %s\n' "$n" "$v" "${aceitos// / ou }" "$est" "$desc"
  done <<< "$AJUSTES"
  res="$(secao saida | sed -n 1p)"; p720="$(secao saida | sed -n 2p)"
  wm="$(secao saida | sed -n 's/^Physical size: \([0-9]*x[0-9]*\).*/\1/p' | head -1)"
  if [ "$res" = "1080P" ] && [ "$p720" = "false" ] && [ "$wm" = "1920x1080" ]; then est="ok"; else est="fora"; fora=$((fora + 1)); fi
  printf '  %-9s %-6s %-9s %-8s %s\n' "saida" "${res:-?}" "1080P" "$est" "painel ${wm:-?}, persist.display.720p=${p720:-?} (so leitura; doc 46 s4)"
  echo
  if [ "$fora" -gt 0 ]; then
    echo "  $fora ajuste(s) fora do maximo. Para mudar UM: --aplicar <ajuste> (pede MUDAR; o antigo fica"
    echo "  guardado para --voltar). Mude um por vez e compare o mesmo video antes e depois."
  else
    echo "  Tudo no maximo."
  fi
  echo "  Estes ajustes agem no video (HDMI, arquivos); a tela de calibracao da suite nao passa por eles."
}

confirma(){
  printf '%s\n' "$1" >&2
  local r=""
  read -r -p "Digite MUDAR para continuar: " r || true
  [ "$r" = "MUDAR" ] || { err "cancelado, nada foi mudado"; exit 2; }
}
mudar(){
  local g s v
  g="$(campo_de "$1" 2)"; s="$(campo_de "$1" 3)"
  sh_dev "printf 'picture\\n$s $2\\nquit\\n' | $HIDEBUG" >/dev/null
  ler_tudo
  v="$(valor "$g")"
  [ "$v" = "$2" ] || { err "$1: pedi $2 e o aparelho releu '${v:-nada}'"; return 1; }
  ok "$1 = $2 (relido)"
}

aplicar(){
  local g sug v arq
  g="$(campo_de "$ALVO" 2)"; sug="$(campo_de "$ALVO" 5)"
  ler_tudo
  v="$(valor "$g")"
  [ -n "$v" ] || { err "nao li o valor atual de $ALVO (resposta: $(secao "$g" | tr '\n' ' ' | cut -c1-120)) - nada foi mudado"; exit 1; }
  if [ "$v" = "$sug" ]; then ok "$ALVO ja esta em $sug: nada a mudar"; return 0; fi
  arq="$BK/$ALVO.txt"
  if [ -s "$arq" ]; then
    warn "o valor antigo de $ALVO ja esta guardado ($(head -1 "$arq")): fica o de antes da primeira mudanca"
  fi
  confirma "Vou mudar $ALVO de $v para $sug no $D (o ajuste fica gravado no aparelho; --voltar $ALVO desfaz)."
  if [ ! -s "$arq" ]; then
    mkdir -p "$BK" || { err "nao criei $BK - nada foi mudado"; exit 1; }
    printf '%s\n# %s, %s, antes do --aplicar\n' "$v" "$ALVO" "$(date '+%Y-%m-%d %H:%M:%S')" > "$arq" || { err "nao gravei $arq - nada foi mudado"; exit 1; }
    ok "valor antigo guardado em $arq: $v"
  fi
  mudar "$ALVO" "$sug" || exit 1
}

voltar(){
  local arq v
  arq="$BK/$ALVO.txt"
  [ -s "$arq" ] || { err "nao ha valor guardado para $ALVO em $arq - nada foi mudado"; exit 1; }
  v="$(head -1 "$arq")"
  case "$v" in ''|*[!0-9]*) err "$arq nao tem um numero na 1a linha ('$v') - nada foi mudado"; exit 1 ;; esac
  confirma "Vou devolver $ALVO ao valor guardado ($v) no $D."
  mudar "$ALVO" "$v" || exit 1
  rm -f "$arq"
  ok "$ALVO voltou a $v; $arq apagado"
}

case "$MODO" in
  lista) lista; exit 0 ;;
esac
conecta
case "$MODO" in
  ler) ler_tudo; mostrar ;;
  aplicar) aplicar ;;
  voltar) voltar ;;
esac
