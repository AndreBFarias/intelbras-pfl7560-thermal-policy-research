#!/vendor/bin/sh
# ---------------------------------------------------------------------------
#  CONVENCAO DE CHARSET (NAO MEXER): ASCII PURO de proposito, como o
#  newlink_update.sh. Roda no /vendor/bin/sh do projetor (mksh/toybox do
#  Android 9) e vive em pendrive FAT32. Sem bashismo.
# ---------------------------------------------------------------------------
# ============================================================================
#  PFL7560 - SUITE DE VERIFICACAO, pedido do app (bloco 9B)
#
#    suite-pedido.sh <evento> <pasta> <arquivo>     (como o inotifyd chama)
#
#  O app "Verificar projetor" grava pedir-verificacao na pasta privada dele
#  (/data/data/com.pfl7560.verificar). O vigia (inotifyd ou laco, ligado pelo
#  suite-boot.sh) chama este script como root. Aceita so o arquivo pedir-verificacao
#  e so se o dono dele for o dono da pasta, um UID de app (>= 10000): so o proprio app
#  grava ali (em /sdcard qualquer app gravaria). Apaga o arquivo (o conteudo e
#  ignorado), respeita a protecao de 10 min e a trava, e lanca suite.sh pedido
#  destacado com o md5 conferido NA HORA contra o embutido aqui.
#
#  Bloco 15 (atalho Luz da home): o mesmo molde, com o arquivo "luz". O app grava
#  so digitos (10..100) na pasta dele; este script confere a origem como acima, le SO
#  digitos (ate 3), recusa o resto, guarda o nivel em $SUITE/luz (root, 0600), aplica
#  pelo hidebug ("picture", "sbl N"), confere com "gbl" e devolve o valor ao app pela
#  prop vendor.pfl7560.luz (o root nao escreve nada na pasta do app: revisao de
#  seguranca de 2026-10-31). O pedido e MOVIDO para a pasta so do root antes de ser lido. Nao usa a protecao de 10 min; com a trava
#  ocupada (rampa no meio) so guarda. suite-boot.sh chama "suite-pedido.sh aplicar-luz"
#  em todo boot para reaplicar o nivel guardado (a gravacao do sbl pelo fabricante e
#  atrasada e nao confiavel: um reboot logo depois perde o valor).
# ============================================================================

if [ "${PFL_TESTE:-}" != "1" ]; then
  # o init sobe o servico de boot com o PATH do /vendor: cmd, pm, am, settings, input,
  # dumpsys e logcat moram em /system/bin (visto no aparelho em 2026-10-31: "exec cmd: No
  # such file or directory" no boot). PATH fixo, com /system antes, em producao.
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_APP_UID_MIN
fi
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
FIM_ARQ="$SUITE/ultimo-fim"
LOCK="$R/dev/pfl7560-suite.lock"
# cada pedido so vale vindo da pasta privada do app dele: a verificacao do app Verificar,
# a luz da home (o atalho Luz mora na home; visto no aparelho em 2026-10-31: o vigia so
# olhava a pasta do Verificar e o pedido de luz da home nunca era lido)
VERIF_DIR="$R/data/data/com.pfl7560.verificar"
HOME_DIR="$R/data/data/com.pfl7560.home"
PEDIDO_DIR="$VERIF_DIR"
LUZ_ARQ="$SUITE/luz"
HIDEBUG="$R/vendor/bin/hidebug"
INTERVALO_MIN=600
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
APP_UID_MIN=10000
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_APP_UID_MIN:-}" ] && APP_UID_MIN="$PFL_APP_UID_MIN"

# md5 do suite.sh. Gerado por tests/atualizar-md5-kit.sh. NAO editar a mao.
# SUITE_MD5_INICIO
SUITE_MD5="478e0f4852d5d40f2ff2f6a4583beb25"
# SUITE_MD5_FIM

LOG(){ echo "[PFL7560-suite-pedido] $*"; }
dir_seguro(){
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ldn "$1" 2>/dev/null)
  case "$1" in
    d???------|d???------[.+]) [ "$3" = "$DONO_UID" ] ;;
    *) return 1 ;;
  esac
}
arq_seguro(){
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ln "$1" 2>/dev/null)
  [ "$3" = "$DONO_UID" ]
}
md5_de(){ md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
# a pasta do app: diretorio real (nao link) cujo dono e um UID de app. Deixa o dono em
# _du e o grupo em _dg.
pasta_do_app(){
  [ -d "$PEDIDO_DIR" ] && [ ! -L "$PEDIDO_DIR" ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ldn "$PEDIDO_DIR" 2>/dev/null); _du="${3:-}"; _dg="${4:-}"
  case "$_du" in ''|*[!0-9]*) return 1 ;; esac
  case "$_dg" in ''|*[!0-9]*) return 1 ;; esac
  [ "$_du" -ge "$APP_UID_MIN" ]
}
# o pedido $1 veio do app: arquivo regular cujo dono e o dono da pasta, e esse dono e um
# UID de app. Nenhum link e seguido.
pedido_do_app(){
  pasta_do_app || return 1
  [ -f "$PEDIDO_DIR/$1" ] && [ ! -L "$PEDIDO_DIR/$1" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ln "$PEDIDO_DIR/$1" 2>/dev/null); _fu="${3:-}"
  [ "$_fu" = "$_du" ]
}
terminou_ha_pouco(){
  _fim=$(head -n 1 "$FIM_ARQ" 2>/dev/null | tr -cd '0-9' | cut -c1-20)
  _agora=$(date +%s 2>/dev/null | tr -cd '0-9')
  [ -n "$_fim" ] && [ -n "$_agora" ] || return 1
  [ "$_agora" -ge "$_fim" ] && [ $(( _agora - _fim )) -lt "$INTERVALO_MIN" ]
}

# ---- luz (bloco 15) ----------------------------------------------------------
# So digitos, ate 3, de 10 a 100 (zeros a esquerda saem: "060" = 60). Devolve o numero em
# stdout; qualquer outra coisa (letras, sinal, vazio, 5, 200) e recusada.
luz_valida(){
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#1}" -le 3 ] || return 1
  _n=$(printf '%s' "$1" | sed 's/^0*//')
  [ -n "$_n" ] && [ "$_n" -ge 10 ] && [ "$_n" -le 100 ] || return 1
  printf '%s' "$_n"
}
# uma linha ASCII imprimivel e curta, so para o log
limpo(){ printf '%s' "$1" | tr -cd ' -~' | cut -c1-20; }
# devolve o valor ao app pela prop vendor.pfl7560.luz (o app le com getprop). Escrever
# como root numa pasta que o app controla abria corrida de link (revisao de seguranca).
escrever_luz_atual(){
  setprop vendor.pfl7560.luz "$1"
}
# le o pedido de luz sem nunca abrir um caminho que o app controla: MOVE (rename, que nao
# segue link) para a pasta so do root, confere la que e arquivo regular do UID do app e le
# com prazo (um FIFO nao trava o vigia). Deixa o conteudo em LUZ_BRUTO; !=0 = recusado.
ler_pedido_luz(){
  LUZ_BRUTO=""
  _lp="$SUITE/luz.pedido"
  rm -f "$_lp"
  dir_seguro "$SUITE" || return 1
  mv -f "$PEDIDO_DIR/luz" "$_lp" 2>/dev/null || return 1
  if [ ! -f "$_lp" ] || [ -L "$_lp" ]; then rm -f "$_lp"; return 1; fi
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ln "$_lp" 2>/dev/null)
  if [ "${3:-}" != "$_du" ]; then rm -f "$_lp"; return 1; fi
  LUZ_BRUTO=$(timeout 2 head -c 16 "$_lp" 2>/dev/null | tr -d '\r\n')
  rm -f "$_lp"
  return 0
}
ler_gbl(){ printf 'picture\ngbl\nquit\n' | timeout 15 "$HIDEBUG" 2>/dev/null | sed -n 's/^.*backlight:\([0-9]*\).*$/\1/p' | head -n 1; }
# aplica $1 (10..100) pelo hidebug, confere lendo gbl (ate 3 leituras, 1 s entre elas) e
# devolve ao app o que o aparelho disse
aplicar_luz(){
  if [ ! -x "$HIDEBUG" ]; then LOG "[AVISO] hidebug ausente - luz $1 nao aplicada."; return 1; fi
  printf 'picture\nsbl %s\nquit\n' "$1" | timeout 15 "$HIDEBUG" >/dev/null 2>&1
  _k=0
  while :; do
    _lido=$(ler_gbl)
    [ "$_lido" = "$1" ] && break
    _k=$(( _k + 1 ))
    [ "$_k" -ge 3 ] && break
    sleep 1
  done
  if [ "$_lido" = "$1" ]; then
    LOG "luz $1% aplicada (o gbl confere)"
  else
    LOG "[AVISO] luz $1% pedida, mas o gbl leu '$(limpo "$_lido")'"
  fi
  case "$_lido" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#_lido}" -le 3 ] || return 1
  escrever_luz_atual "$_lido"
}
# pedido de luz ja lido ($1 = o conteudo bruto): valida, guarda e aplica
tratar_luz(){
  if ! _v=$(luz_valida "$1"); then
    LOG "[AVISO] pedido de luz recusado (conteudo '$(limpo "$1")': so 10 a 100, so digitos)."
    return 0
  fi
  ( umask 077; printf '%s\n' "$_v" > "$LUZ_ARQ.novo" ) && mv -f "$LUZ_ARQ.novo" "$LUZ_ARQ"
  if [ -d "$LOCK" ]; then LOG "a suite esta rodando (trava): luz $_v% guardada, aplica no proximo boot."; return 0; fi
  aplicar_luz "$_v"
}

# modo do boot: reaplica o nivel guardado em $SUITE/luz (suite-boot.sh, antes do vigia)
if [ "${1:-}" = "aplicar-luz" ]; then
  dir_seguro "$SUITE" || { LOG "[ERRO] $SUITE nao e uma pasta so do root - luz nao reaplicada."; exit 1; }
  [ -e "$LUZ_ARQ" ] || exit 0
  arq_seguro "$LUZ_ARQ" || { LOG "[AVISO] $LUZ_ARQ e link ou de outro dono - ignorado."; exit 0; }
  _b=$(head -c 16 "$LUZ_ARQ" 2>/dev/null | tr -d '\r\n')
  if ! _v=$(luz_valida "$_b"); then LOG "[AVISO] luz guardada invalida ('$(limpo "$_b")') - nao reaplicada."; exit 0; fi
  LOG "reaplicando a luz guardada: $_v%"
  aplicar_luz "$_v"
  exit 0
fi

# ---- descanso de tela (pedido do dono, 2026-10-31): luz a 10% enquanto ele estiver na tela
DESCANSO_LUZ=10
ANTES_ARQ="$SUITE/luz-antes-descanso"
# o nivel que o dono escolheu (10..100), ou 100 sem escolha
luz_guardada(){
  _b=""
  arq_seguro "$LUZ_ARQ" && _b=$(head -c 16 "$LUZ_ARQ" 2>/dev/null | tr -d '\r\n')
  luz_valida "$_b" || printf '100'
}
# $1 = inicio|fim. Nao mexe no nivel guardado nem na prop da home; com a suite rodando
# (trava, rampa no meio) nao age. O boot reaplica o nivel guardado de qualquer jeito.
tratar_descanso(){
  if [ -d "$LOCK" ]; then LOG "a suite esta rodando (trava): descanso $1 sem efeito na luz."; return 0; fi
  if [ ! -x "$HIDEBUG" ]; then LOG "[AVISO] hidebug ausente - descanso $1 sem efeito na luz."; return 0; fi
  if [ "$1" = "inicio" ]; then
    if [ ! -e "$ANTES_ARQ" ] && [ ! -L "$ANTES_ARQ" ] && _a=$(luz_valida "$(ler_gbl)"); then
      ( umask 077; printf '%s\n' "$_a" > "$ANTES_ARQ.novo" ) && mv -f "$ANTES_ARQ.novo" "$ANTES_ARQ"
    fi
    _dv="$DESCANSO_LUZ"
  else
    _dv=""
    arq_seguro "$ANTES_ARQ" && _dv=$(luz_valida "$(head -c 16 "$ANTES_ARQ" 2>/dev/null | tr -d '\r\n')")
    rm -f "$ANTES_ARQ"
    [ -n "$_dv" ] || _dv=$(luz_guardada)
  fi
  printf 'picture\nsbl %s\nquit\n' "$_dv" | timeout 15 "$HIDEBUG" >/dev/null 2>&1
  if [ "$1" = "inicio" ]; then LOG "descanso na tela: luz a $_dv% (o nivel do dono continua guardado)"
  else LOG "descanso terminou: luz de volta a $_dv%"; fi
}

# so os arquivos dos pedidos, e so escrita fechada (w) ou movido para dentro (y)
NOME="${3:-}"
case "$NOME" in
  pedir-verificacao|descanso-inicio|descanso-fim) PEDIDO_DIR="$VERIF_DIR" ;;
  luz) PEDIDO_DIR="$HOME_DIR" ;;
  *) exit 0 ;;
esac
# a pasta do evento tem de ser a do app daquele pedido (nada de luz pela pasta do Verificar)
[ "${2%/}" = "$PEDIDO_DIR" ] || exit 0
case "${1:-}" in *w*|*y*) ;; *) exit 0 ;; esac
# a origem e conferida ANTES de apagar; depois apaga (um link e apagado, nunca
# seguido). O pedido de verificacao nao tem o conteudo lido; o de luz tem, so se veio do app
DO_APP=0
pedido_do_app "$NOME" && DO_APP=1
LUZ_BRUTO=""
if [ "$NOME" = "luz" ] && [ "$DO_APP" = "1" ]; then
  ler_pedido_luz || DO_APP=0
fi
rm -f "$PEDIDO_DIR/$NOME"
if ! dir_seguro "$SUITE"; then
  echo "[PFL7560-suite-pedido] [ERRO] $SUITE nao e uma pasta so do root - pedido ignorado."
  exit 1
fi
exec >>"$SUITE/vigia.log" 2>&1 </dev/null
LOG "pedido de $NOME recebido ($(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null))"
# um pedido que nao se apaga (uma pasta com o nome, por exemplo) nao vira laco de suites
if [ -e "$PEDIDO_DIR/$NOME" ] || [ -L "$PEDIDO_DIR/$NOME" ]; then
  LOG "[AVISO] nao consegui apagar o pedido $PEDIDO_DIR/$NOME - pedido ignorado."
  exit 0
fi
if [ "$DO_APP" != "1" ]; then LOG "[AVISO] o pedido nao veio do app (dono do arquivo nao e o da pasta do app) - ignorado."; exit 0; fi
if [ "$NOME" = "luz" ]; then tratar_luz "$LUZ_BRUTO"; exit 0; fi
case "$NOME" in descanso-*) tratar_descanso "${NOME#descanso-}"; exit 0 ;; esac
if [ -d "$LOCK" ]; then LOG "a suite ja esta rodando (trava) - pedido ignorado."; exit 0; fi
# o pedido e do dono (tocou no icone): roda mesmo se a suite acabou de rodar. A protecao
# de 10 min e contra laco no boot (suite-boot.sh), nao contra quem pede (2026-10-31).
if terminou_ha_pouco; then LOG "a suite terminou ha menos de 10 min, mas o pedido e do dono: roda."; fi
# ULTIMA conferencia antes de executar
if ! { arq_seguro "$SUITE/suite.sh" && [ "$(md5_de "$SUITE/suite.sh")" = "$SUITE_MD5" ]; }; then
  LOG "[ERRO] suite.sh ausente, link, de outro dono ou com md5 diferente do embutido - NAO executado."
  exit 1
fi
LOG "lancando a suite (suite.sh pedido) destacada"
if command -v setsid >/dev/null 2>&1; then
  setsid sh "$SUITE/suite.sh" pedido >>"$SUITE/lancador.log" 2>&1 </dev/null &
else
  nohup sh "$SUITE/suite.sh" pedido >>"$SUITE/lancador.log" 2>&1 </dev/null &
fi
exit 0
