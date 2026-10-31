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
#  O app "Verificar projetor" grava /sdcard/pfl7560/pedir-verificacao (no disco:
#  /data/media/0/pfl7560). O vigia (inotifyd ou laco, ligado pelo suite-boot.sh)
#  chama este script como root. Aceita so o arquivo pedir-verificacao, apaga o
#  arquivo (o conteudo e ignorado), respeita a protecao de 10 min e a trava, e lanca
#  suite.sh pedido destacado com o md5 conferido NA HORA contra o embutido aqui.
# ============================================================================

if [ "${PFL_TESTE:-}" != "1" ]; then
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE
fi
R="${PFL_ROOT:-}"
SUITE="$R/data/vendor/pfl7560-suite"
FIM_ARQ="$SUITE/ultimo-fim"
LOCK="$R/dev/pfl7560-suite.lock"
PEDIDO_DIR="$R/data/media/0/pfl7560"
INTERVALO_MIN=600
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"

# md5 do suite.sh. Gerado por tests/atualizar-md5-kit.sh. NAO editar a mao.
# SUITE_MD5_INICIO
SUITE_MD5="ea698598b4b0d5a45e92f73f414179f9"
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
terminou_ha_pouco(){
  _fim=$(head -n 1 "$FIM_ARQ" 2>/dev/null | tr -cd '0-9' | cut -c1-20)
  _agora=$(date +%s 2>/dev/null | tr -cd '0-9')
  [ -n "$_fim" ] && [ -n "$_agora" ] || return 1
  [ "$_agora" -ge "$_fim" ] && [ $(( _agora - _fim )) -lt "$INTERVALO_MIN" ]
}

# so o arquivo do pedido, e so escrita fechada (w) ou movido para dentro (y)
[ "${3:-}" = "pedir-verificacao" ] || exit 0
case "${1:-}" in *w*|*y*) ;; *) exit 0 ;; esac
# apaga o pedido (um link e apagado, nunca seguido); o conteudo nao e lido
rm -f "$PEDIDO_DIR/pedir-verificacao"
if ! dir_seguro "$SUITE"; then
  echo "[PFL7560-suite-pedido] [ERRO] $SUITE nao e uma pasta so do root - pedido ignorado."
  exit 1
fi
exec >>"$SUITE/vigia.log" 2>&1 </dev/null
LOG "pedido de verificacao recebido ($(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null))"
# um pedido que nao se apaga (uma pasta com o nome, por exemplo) nao vira laco de suites
if [ -e "$PEDIDO_DIR/pedir-verificacao" ] || [ -L "$PEDIDO_DIR/pedir-verificacao" ]; then
  LOG "[AVISO] nao consegui apagar o pedido $PEDIDO_DIR/pedir-verificacao - pedido ignorado."
  exit 0
fi
if [ -d "$LOCK" ]; then LOG "a suite ja esta rodando (trava) - pedido ignorado."; exit 0; fi
if terminou_ha_pouco; then LOG "a suite terminou ha menos de 10 min - pedido ignorado."; exit 0; fi
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
