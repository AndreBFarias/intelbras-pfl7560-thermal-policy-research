#!/vendor/bin/sh
# suite-semente.sh - a suite nativa da build S5 (bloco 26, doc 47 s12).
#
# O firmware S5 grava a suite em /vendor/etc/pfl7560-suite (so leitura) e o servico de boot
# (o pfl7560-suite.rc da S5) roda este script depois do sys.boot_completed=1. Ele:
#   1. copia a suite do /vendor para /data/vendor/pfl7560-suite quando o /data nao tem uma
#      (1o boot depois da gravacao, que formata o /data): por uma pasta de preparo, com o md5
#      de cada arquivo conferido antes do mv, pastas so do root e o suite-boot.sh por ultimo
#      (sem ele o proximo boot copia tudo de novo);
#   2. regra de versao com o kit do pendrive: o /data so e trocado se a suite dele veio inteira
#      desta semente (semente.lista confere arquivo por arquivo) e o /vendor traz outra lista.
#      Se o kit instalou ou atualizou a suite, o /data vence e nada e copiado;
#   3. passa a vez ao suite-boot.sh do /data (o do kit, se o kit o atualizou), como o .rc do
#      kit faz.
# Registro em $SUITE/semente.log e na prop vendor.pfl7560.semente.

if [ "${PFL_TESTE:-}" != "1" ]; then
  PATH="/system/bin:/system/xbin:/vendor/bin:/vendor/xbin"; export PATH
  unset PFL_ROOT PFL_RAPIDO PFL_DONO PFL_TESTE PFL_VIGIA_VOLTAS
fi
R="${PFL_ROOT:-}"
ORIGEM="$R/vendor/etc/pfl7560-suite"
SUITE="$R/data/vendor/pfl7560-suite"
LISTA_DATA="$SUITE/semente.lista"
LOG_ARQ="$SUITE/semente.log"
PREP="$SUITE/semente.preparo"
SH_BOOT="/vendor/bin/sh"
DONO_UID=0
if [ "${PFL_TESTE:-}" = "1" ]; then
  SH_BOOT="sh"
  [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
fi
LOG_MAX=100
EXEC_LISTA="cor.sh lvdsctl nl_camcheck nl_tela nl_logo suite.sh suite-boot.sh suite-pedido.sh suite-curvas.sh suite-chaves.sh suite-diario.sh suite-logo.sh"

# SEMENTE_LISTA_INICIO
SEMENTE_LISTA="0dbcf2861f96e24e728342732ce54340  cor.sh
178d812872cb9306c0ae6faeed07184a  lvdsctl
02bedd31ae0e82afd10c41daabf2bd56  nl_camcheck
662acb7ac307699a389e892047f0d883  nl_tela
e8f7948153b78854673c5536ab20ba30  suite.sh
368b9057a2d4666760f0c2ac9fef8b73  suite-boot.sh
794858512c34b592e496293ac1ef535d  suite-pedido.sh
7dd0b18e1dfb44edd998ee99a7faad24  suite-curvas.sh
ed4179886e1c028c3f8a8f423036e5e9  suite-chaves.sh
90caa1f05da00c43a29dd364ed3afb69  suite-diario.sh
2760b4c77e6639632f63a156859520bc  nl_logo
d1b0b118aa713b541c0514687eab1609  suite-logo.sh
127353d6189874843b431b88baf1b290  debloat-aprovados.txt
acaaefb249632298e6af03c73dbc1c8d  kit/aguarde.png
cedac2a713b8b29dd1b64d77a587b49f  kit/calibracao.png
b9b36dfd2df8eb824ee2d480d70c45a9  kit/corrigida.png
1afd05f32600385e0587acf062262988  kit/erro.png
0afaa2345ab1082d73171003922f5277  kit/escada-1.png
85fc83ce25d4d44a1bb7b7baafc3c090  kit/escada-2.png
7cd6dca3430ab476de9bb4c30b3dd4b5  kit/pronto.png
ab1ca6ffb16e52c7fed90f6db418965b  kit/reiniciando.png
6b63b3f38003b887aa8433d74a873844  fontes/IBMPlexMono-Regular.ttf
be3d5e5c761ef60563c87b9475f5a99d  fontes/IBMPlexMono-SemiBold.ttf
f7c622dca16e1da365a328894f74cbac  fontes/IBMPlexSansCondensed-Bold.ttf
c90afb82696a6873464b6cc8f315f0eb  fontes/IBMPlexSansCondensed-Regular.ttf
9f4dbd7c74436d0d895ccc3689c42490  fontes/IBMPlexSansCondensed-SemiBold.ttf
160cec49299e5d622c5150977bfe188c  fontes/OFL.txt
78b23ececb6a42622424e11d4098fdbe  marca/logo.jpg
"
# SEMENTE_LISTA_FIM

LOG(){ echo "[PFL7560-semente] $*"; }
estado(){ setprop vendor.pfl7560.semente "$1" 2>/dev/null; }

dir_seguro(){
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ldn "$1" 2>/dev/null)
  case "$1" in
    d???------|d???------[.+]) [ "$3" = "$DONO_UID" ] ;;
    *) return 1 ;;
  esac
}
arq_seguro(){
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  # shellcheck disable=SC2046
  set -- $(ls -ln "$1" 2>/dev/null)
  [ "$3" = "$DONO_UID" ]
}
md5_de(){ md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
lista_limpa(){ printf '%s\n' "$1" | grep -x '[0-9a-f]\{32\}  [A-Za-z0-9._-][A-Za-z0-9._/-]*'; }
nomes(){ lista_limpa "$1" | sed 's/^[0-9a-f]*  //'; }
subpastas(){ nomes "$1" | sed -n 's|/.*||p' | sort -u; }
# confere(<lista> <pasta>): cada arquivo da lista e regular, do root e tem o md5 da lista
confere(){
  _cl=$(lista_limpa "$1")
  [ -n "$_cl" ] || return 1
  _crc=0
  for _cn in $(nomes "$_cl"); do
    _ce=$(printf '%s\n' "$_cl" | sed -n "s|^\\([0-9a-f]*\\)  $_cn\$|\\1|p" | head -n 1)
    if ! arq_seguro "$2/$_cn" || [ "$(md5_de "$2/$_cn")" != "$_ce" ]; then
      LOG "  $2/$_cn ausente, link, de outro dono ou com md5 diferente (esperado $_ce)"
      _crc=1
    fi
  done
  return "$_crc"
}
pura(){
  arq_seguro "$LISTA_DATA" || return 1
  _pl=$(cat "$LISTA_DATA" 2>/dev/null)
  [ -n "$(lista_limpa "$_pl")" ] || return 1
  confere "$_pl" "$SUITE" >/dev/null
}
mesma_lista(){ [ "$(lista_limpa "$(cat "$LISTA_DATA" 2>/dev/null)")" = "$(lista_limpa "$SEMENTE_LISTA")" ]; }

copiar(){
  if [ ! -d "$ORIGEM" ] || [ -L "$ORIGEM" ] || ! confere "$SEMENTE_LISTA" "$ORIGEM"; then
    LOG "[ERRO] a suite do /vendor ($ORIGEM) nao confere com a lista da semente - nada copiado."
    return 1
  fi
  rm -rf "$PREP"
  ( umask 077; mkdir "$PREP" ) || return 1
  for _sd in $(subpastas "$SEMENTE_LISTA"); do ( umask 077; mkdir "$PREP/$_sd" ) || return 1; done
  for _sn in $(nomes "$SEMENTE_LISTA"); do
    ( umask 077; cp "$ORIGEM/$_sn" "$PREP/$_sn" ) || { LOG "[ERRO] nao consegui copiar $_sn para o preparo."; return 1; }
  done
  for _sn in $EXEC_LISTA; do [ -f "$PREP/$_sn" ] && chmod 755 "$PREP/$_sn"; done
  if ! confere "$SEMENTE_LISTA" "$PREP"; then
    LOG "[ERRO] a copia no preparo nao confere - nada posto no lugar."
    return 1
  fi
  rm -f "$SUITE/suite-boot.sh" || return 1
  for _sd in $(subpastas "$SEMENTE_LISTA"); do
    if [ ! -e "$SUITE/$_sd" ] && [ ! -L "$SUITE/$_sd" ]; then
      ( umask 077; mkdir "$SUITE/$_sd" ) && chmod 700 "$SUITE/$_sd"
    fi
    dir_seguro "$SUITE/$_sd" || { LOG "[ERRO] $SUITE/$_sd nao e uma pasta so do root (link?) - nada posto no lugar."; return 1; }
  done
  ( umask 077; lista_limpa "$SEMENTE_LISTA" > "$LISTA_DATA.novo" ) && mv -f "$LISTA_DATA.novo" "$LISTA_DATA" || return 1
  for _sn in $(nomes "$SEMENTE_LISTA"); do
    [ "$_sn" = "suite-boot.sh" ] && continue
    mv -f "$PREP/$_sn" "$SUITE/$_sn" || { LOG "[ERRO] mv de $_sn falhou."; return 1; }
  done
  mv -f "$PREP/suite-boot.sh" "$SUITE/suite-boot.sh" || { LOG "[ERRO] mv do suite-boot.sh falhou."; return 1; }
  rm -rf "$PREP"
  if ! confere "$SEMENTE_LISTA" "$SUITE"; then
    LOG "[ERRO] a suite no /data nao conferiu depois da copia."
    return 1
  fi
  return 0
}

if [ ! -e "$SUITE" ] && [ ! -L "$SUITE" ]; then
  mkdir -p "${SUITE%/*}" 2>/dev/null
  ( umask 077; mkdir "$SUITE" 2>/dev/null ) && chmod 700 "$SUITE" 2>/dev/null
fi
if ! dir_seguro "$SUITE"; then
  LOG "[ERRO] $SUITE nao e uma pasta so do root (link, dono errado ou aberta) - nada feito."
  estado erro_pasta
  exit 1
fi
if [ -f "$LOG_ARQ" ]; then tail -n "$LOG_MAX" "$LOG_ARQ" > "$LOG_ARQ.novo" 2>/dev/null && mv -f "$LOG_ARQ.novo" "$LOG_ARQ"; fi
[ -L "$LOG_ARQ" ] && rm -f "$LOG_ARQ"
exec >>"$LOG_ARQ" 2>&1 </dev/null
LOG "==== boot $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) ===="

ACAO=nada
if ! arq_seguro "$SUITE/suite-boot.sh"; then
  ACAO=copiar; MOTIVO=data_sem_suite
elif pura; then
  if mesma_lista; then MOTIVO=em_dia; else ACAO=copiar; MOTIVO=vendor_mais_novo; fi
else
  MOTIVO=data_vence
fi
LOG "acao=$ACAO motivo=$MOTIVO"
if [ "$ACAO" = "copiar" ]; then
  if copiar; then
    LOG "[OK] suite copiada do /vendor e conferida: $(nomes "$SEMENTE_LISTA" | wc -l | tr -dc '0-9') arquivos ($MOTIVO)"
    estado copiada
  else
    rm -rf "$PREP"
    estado erro_copia
  fi
elif [ "$MOTIVO" = "em_dia" ]; then
  LOG "suite do /data igual a do /vendor - nada copiado"
  estado em_dia
else
  LOG "suite do /data instalada ou atualizada pelo kit - o /data vence, nada copiado"
  estado data_vence
fi

if arq_seguro "$SUITE/suite-boot.sh"; then
  LOG "passando a vez ao $SUITE/suite-boot.sh"
  exec "$SH_BOOT" "$SUITE/suite-boot.sh"
fi
LOG "[ERRO] sem suite-boot.sh no /data - a suite nao roda neste boot."
exit 1
