#!/vendor/bin/sh
# ---------------------------------------------------------------------------
#  CONVENCAO DE CHARSET (NAO MEXER): este arquivo e ASCII PURO de proposito.
#  Roda no shell do projetor (/vendor/bin/sh, mksh/toybox do Android 9, locale
#  incerto) e vive num pendrive FAT32; acento pt-BR pode virar mojibake ou
#  quebrar o parser do shell. NAO acentuar este arquivo. Convencao fixada na
#  sprint 25 (auditoria de acentuacao) - decisao registrada para o proximo
#  auditor.
# ---------------------------------------------------------------------------
# ============================================================================
#  PFL7560 - KIT UNIVERSAL de pendrive, v2 (termico + wi-fi + xiri + cor)
#
#  Como funciona: o proprio firmware roda /vendor/bin/nl_usb_update.sh a cada
#  boot (gatilho: sys.boot_completed=1). Esse script varre os pendrives e, se
#  achar um "newlink_update.sh" na raiz, EXECUTA ele como ROOT (via exec do
#  init). Por isso aqui roda so o que e CURTO: conferir o kit e a fase termica.
#  A fase de COR (pergunta a pessoa, ate ~90 s) e lancada DESTACADA, a partir de
#  uma copia em /data/vendor/pfl7560-kit (pasta so do root, 0700), pelo cor.sh.
#
#  Coloque na RAIZ do pendrive (FAT32) tudo o que esta na pasta pendrive-autorun:
#      newlink_update.sh  cor.sh  lvdsctl  nl_camcheck  ZYCustom.ini  LEIA-ME.txt  kit/*.png
#  Mesmo pendrive para qualquer PFL7560: sem serial, sem arquivo para editar.
#
#  IDEMPOTENTE:
#   - TERMICO: o estado-alvo e o md5 do ZYCustom.ini que o firmware le. Troca
#     (escrita atomica) so se o md5 atual for o de fabrica (dos DOIS modelos: com
#     USB-C V1.0.0.9 e sem USB-C V1.0.0.1) ou o da versao anterior nossa; md5
#     desconhecido = RECUSA. O .ini novo e montado a partir do .ini DO APARELHO,
#     trocando so as secoes termicas pelas do ZYCustom.ini do pendrive: o resto
#     (CONFIG_MODEL inclusive) fica byte a byte. 2a execucao: nada e escrito.
#   - COR: o cor.sh mede a escada de cinzas pela camera interna (nl_camcheck) e,
#     se ela estiver fora de ordem, troca o formato; sem camera ele pergunta olhando
#     a tela e so grava com DUAS teclas; sem tecla nada muda. 2a execucao: nada e
#     escrito e nada reinicia.
#   - Reinicia UMA vez, e so quando a fase termica mudou algo.
#
#  SEGURANCA: o md5 de CADA arquivo do kit e conferido contra a lista embutida
#  abaixo ANTES de qualquer escrita. Divergiu ou faltou = aborta. Este script
#  NUNCA chama hidebug nem gtt (doc 37). Limite honesto: um newlink_update.sh
#  adulterado roda como root e nao ha defesa contra ele.
#  E3b: o cor.sh, o lvdsctl e o nl_camcheck rodam como root, entao ficam so numa pasta do root
#  (nunca em /data/local/tmp, que o usuario shell grava), verificada a cada uso
#  (diretorio real, nao link, dono root); e o md5 do cor.sh e conferido
#  IMEDIATAMENTE antes de cada execucao (restaurar, tela e teste de cor).
# ============================================================================

# ---- ganchos de teste -------------------------------------------------------
# So valem com PFL_TESTE=1 (o harness em tests/ a define). Fora disso TODAS saem
# do ambiente, para que nenhuma seja porta de entrada em producao; R fica vazio.
if [ "${PFL_TESTE:-}" != "1" ]; then
  unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_RAPIDO PFL_DONO PFL_TESTE
fi
R="${PFL_ROOT:-}"
MP="$R/mnt/media_rw/$1"
INI="$R/vendor/etc/ZYCustom.ini"
BP="$R/vendor/build.prop"
RC="$R/vendor/etc/init/hw/init.bigfish.rc"
ATV_INI_DIR="$R/atv/ini"
WORK="$R/data/vendor/pfl7560-kit"
JOURNAL="$WORK/journal"
ESPERA_REBOOT=8
# dono exigido na pasta de trabalho e nos arquivos dela (root = 0)
DONO_UID=0
[ "${PFL_TESTE:-}" = "1" ] && [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
# gancho de teste (so com PFL_TESTE=1): o harness (tests/) zera a espera
[ -n "${PFL_RAPIDO:-}" ] && ESPERA_REBOOT=0

# md5 do ZYCustom.ini. O kit serve a DOIS modelos, que so diferem no CONFIG_MODEL
# do [Global] (doc 42): o com USB-C (V1.0.0.9, KJM_5H039_412) e o sem USB-C
# (V1.0.0.1, KJM_5H039_412_INTELBRAS_NOTYPEC_TP). Para cada .ini conhecido o
# resultado esperado tambem e conhecido; qualquer outro md5 = desconhecido = o kit
# recusa em vez de sobrescrever um mapa que nao conhece.
#   *_OK            corrigido, modelo com USB-C (e o ZYCustom.ini do pendrive)
#   *_OK_NOTYPEC    corrigido, modelo sem USB-C (artifacts/ZYCustom_390.NOTYPEC.ini)
#   *_FABRICA       de fabrica V1.0.0.9 (com USB-C); *_FABRICA_NOTYPEC, o V1.0.0.1
# Versoes anteriores nossas que ja foram para aparelho (todas do modelo com USB-C):
#   bbf82dd1  artifacts/ZYCustom_390.PREV-211927.ini
#   1ad641ed  pendrive-autorun/ZYCustom.ini de 23169d6 a d10f6da (antes da
#             escada; a que o pendrive e o adb levaram, docs 26 e 34)
#   5868d67f  pendrive-autorun/ZYCustom.ini de cd5a80f (escada com os espacos
#             de fim de linha cortados)
INI_MD5_OK="252ab7a72a007a8b79b3fc86bd5c0d19"
INI_MD5_OK_NOTYPEC="bdf5c4640596d1b2f2fb7f62fbadd6e3"
INI_MD5_FABRICA="29d8ba36149413e899563029df078f6d"
INI_MD5_FABRICA_NOTYPEC="ed3f314ca89698cb057a74ef64dca38e"
INI_MD5_ANTERIORES="bbf82dd17d4523b7df8a86bec0e850ce 1ad641ed2dd99e61d8a987a675e9aced 5868d67fd8d47564842494aa8f14c37c"
# secoes que o kit troca no .ini do aparelho (as do ZYCustom.ini do pendrive); o
# resto do arquivo nao e tocado. [Thermal] leva os limites de 70/75 C.
TERM_SECOES="Thermal BacklightPolicy ThermalPolicy Thermistor_0 Thermistor_1 CoolingFan_0 CoolingFan_1"

# md5 de CADA arquivo do kit, relativo a raiz do pendrive. Gerado por
# tests/atualizar-md5-kit.sh (o harness confere que esta em dia). NAO editar a mao.
# KIT_LISTA_INICIO
KIT_LISTA="252ab7a72a007a8b79b3fc86bd5c0d19  ZYCustom.ini
51ed332580e2b19b287d0968083f56d1  cor.sh
178d812872cb9306c0ae6faeed07184a  lvdsctl
596ab23dff8b3ef0e779c99769b48e2c  nl_camcheck
b8791aa99caac36094977931c0bc210d  nl_tela
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
"
# KIT_LISTA_FIM

LOG(){ echo "[PFL7560-fix] $*"; }
LOG "==== autorun iniciado (mountpoint=$1) ===="

# trava de seguranca: so age no PFL7560
MODEL=$(getprop ro.product.model 2>/dev/null)
if [ "$MODEL" != "PFL7560" ]; then
  LOG "modelo='$MODEL' nao e PFL7560 - abortado por seguranca."
  exit 0
fi

# sem md5sum nao ha como conferir o kit: aborta antes de qualquer escrita
if ! command -v md5sum >/dev/null 2>&1; then
  LOG "[ERRO] md5sum ausente - nao consigo conferir o kit. Abortado (nada foi alterado)."
  exit 1
fi

if [ ! -d "$MP" ]; then
  LOG "[ERRO] mountpoint '$MP' nao existe - abortando (nada foi alterado)."
  exit 1
fi

# ---- conferencia do kit ------------------------------------------------------
kit_nomes(){ echo "$KIT_LISTA" | sed -n 's/^[0-9a-f][0-9a-f]*  //p'; }
kit_md5_esperado(){ echo "$KIT_LISTA" | sed -n "s|^\\([0-9a-f][0-9a-f]*\\)  $1\$|\\1|p" | head -1; }
# confere cada arquivo de $2... em $1; devolve !=0 se algum faltar ou divergir
kit_conferir(){
  _base="$1"; shift
  _rc=0
  for _n in "$@"; do
    _esp=$(kit_md5_esperado "$_n")
    _got=$(md5sum "$_base/$_n" 2>/dev/null | cut -d' ' -f1)
    if [ -z "$_esp" ] || [ "$_got" != "$_esp" ]; then
      LOG "[ERRO] kit: '$_n' ausente ou md5 diferente do esperado (achado '$_got', esperado '$_esp')."
      _rc=1
    fi
  done
  return "$_rc"
}

# ---- pasta de trabalho so do root (E3b) --------------------------------------
# O cor.sh e o lvdsctl rodam como root a partir de $WORK. Se alguem que nao e root
# pudesse escrever la (ou trocar a pasta por um link), executaria codigo como root.
#  - dir_seguro: diretorio real (nao link), dono root, sem acesso de grupo/outros
#    (o ls pode por '.' ou '+' no fim do modo, por SELinux/ACL);
#  - arq_seguro: arquivo regular (nao link) e de dono root.
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
trabalho_ok(){
  dir_seguro "$WORK" && return 0
  LOG "[ERRO] $WORK nao e uma pasta so do root (link, dono errado ou aberta a outros) - NAO vou usar nem escrever nela."
  return 1
}
# cria a pasta (0700, do root) se nao existir e confere; uma que ja exista e
# errada NUNCA e consertada nem apagada aqui: recusa.
preparar_trabalho(){
  if [ ! -e "$WORK" ] && [ ! -L "$WORK" ]; then
    mkdir -p "${WORK%/*}" 2>/dev/null
    ( umask 077; mkdir "$WORK" 2>/dev/null ) && chmod 700 "$WORK" 2>/dev/null
  fi
  trabalho_ok
}
# confere os arquivos do kit de $1 (a pasta de trabalho ou a de preparo dentro
# dela): regulares (nao link), do root e com o md5 da lista
conferir_em(){
  _cb="$1"; shift
  _trc=0   # nome proprio: o kit_conferir tambem usa _rc e _n
  for _tn in "$@"; do
    if ! arq_seguro "$_cb/$_tn"; then
      LOG "[ERRO] kit: '$_tn' em $_cb nao e arquivo regular do root (link ou outro dono)."
      _trc=1
    fi
  done
  kit_conferir "$_cb" "$@" || _trc=1
  return "$_trc"
}
trabalho_conferir(){ conferir_em "$WORK" "$@"; }
# IMEDIATAMENTE antes de cada execucao do cor.sh (restaurar, tela, teste): pasta
# so do root, cor.sh regular do root e md5 da lista embutida. O lvdsctl quem
# confere, na hora de executa-lo, e o proprio cor.sh.
cor_pronto(){
  trabalho_ok || return 1
  trabalho_conferir cor.sh
}

# ---- recuperacao: journal de um teste de cor interrompido --------------------
# Roda ANTES de qualquer outra coisa. Usa a copia do cor.sh que ficou em $WORK
# (a que o proprio journal usa), reconferida contra a lista embutida.
if [ -e "$WORK" ] || [ -L "$WORK" ]; then
  trabalho_ok || { LOG "[ERRO] pasta de trabalho recusada - ABORTADO. Nada foi alterado."; exit 1; }
fi
if [ -f "$JOURNAL" ]; then
  LOG "journal de cor pendente: um teste anterior foi interrompido; restaurando o formato original antes de tudo"
  if cor_pronto; then
    sh "$WORK/cor.sh" --restaurar
    if [ "$?" = "3" ]; then
      LOG "restauracao pediu reboot; encerrando por aqui."
      exit 0
    fi
  else
    LOG "[AVISO] cor.sh de recuperacao ausente, link ou com md5 diferente em $WORK; o gancho de boot ou o proximo teste tenta."
  fi
fi

# ---- md5 de cada arquivo do kit ANTES de qualquer escrita --------------------
# shellcheck disable=SC2046
if ! kit_conferir "$MP" $(kit_nomes); then
  LOG "[ERRO] kit incompleto ou adulterado - ABORTADO. Nada foi alterado. Copie de novo TODOS os arquivos da pasta do kit para a raiz do pendrive."
  # unica escrita permitida aqui: a tela de erro, e so se ela propria confere
  if kit_conferir "$MP" kit/erro.png >/dev/null 2>&1; then
    mkdir -p "$R/sdcard/pfl7560-kit" && cp "$MP/kit/erro.png" "$R/sdcard/pfl7560-kit/erro.png" \
      && am start -a android.intent.action.VIEW -d "file:///sdcard/pfl7560-kit/erro.png" -t image/png >/dev/null 2>&1
  fi
  exit 1
fi
LOG "kit conferido: $(kit_nomes | wc -l | tr -dc '0-9') arquivos com md5 certo"

# copia o kit para a pasta so do root (o cor.sh roda de la, destacado). Nao apaga
# o journal nem o backup: so kit/, fontes/ e os arquivos da lista sao trocados.
# A copia vai primeiro para uma pasta de PREPARO dentro de $WORK, e conferida LA
# e so entao cada arquivo vai para o lugar com mv (rename, atomico; um link no
# lugar dele e substituido, nunca seguido). Assim $WORK/cor.sh e $WORK/lvdsctl
# nunca tem, nem por um instante, um arquivo nao conferido: o pendrive pode ser
# alterado em uso (o usuario shell grava nele) e um cor.sh do gancho de boot pode
# estar rodando ao mesmo tempo; ele ve a versao velha ou a nova, as duas conferidas.
# So os arquivos da lista sao copiados.
if ! preparar_trabalho; then
  LOG "[ERRO] pasta de trabalho recusada - abortando (nada foi alterado)."
  exit 1
fi
KIT_COPIA=$(kit_nomes | grep -v '^ZYCustom.ini$')
PREP="$WORK/preparo.$$"
copiar_preparo(){
  rm -rf "$PREP"
  ( umask 077; mkdir "$PREP" && mkdir "$PREP/kit" && mkdir "$PREP/fontes" ) || return 1
  for _cn in $KIT_COPIA; do cp "$MP/$_cn" "$PREP/$_cn" || return 1; done
  chmod 755 "$PREP/cor.sh" "$PREP/lvdsctl" "$PREP/nl_camcheck" "$PREP/nl_tela"
}
por_no_lugar(){
  rm -rf "$WORK/kit" && mkdir "$WORK/kit" || return 1
  rm -rf "$WORK/fontes" && mkdir "$WORK/fontes" || return 1
  for _cn in $KIT_COPIA; do mv -f "$PREP/$_cn" "$WORK/$_cn" || return 1; done
}
if ! copiar_preparo; then
  rm -rf "$PREP"
  LOG "[ERRO] nao consegui copiar o kit para $WORK - abortando (nada de /vendor foi alterado)."
  exit 1
fi
# shellcheck disable=SC2086  # lista de nomes sem espaco, divisao de proposito
if ! conferir_em "$PREP" $KIT_COPIA || ! por_no_lugar; then
  rm -rf "$PREP"
  LOG "[ERRO] a copia do kit em $WORK nao confere - abortando (nada de /vendor foi alterado)."
  exit 1
fi
rm -rf "$PREP"
# shellcheck disable=SC2086
if ! trabalho_conferir $KIT_COPIA; then
  LOG "[ERRO] a copia do kit em $WORK nao confere - abortando (nada de /vendor foi alterado)."
  exit 1
fi
COR_MD5=$(kit_md5_esperado cor.sh)

# ---- estados-alvo (idempotencia) ---------------------------------------------
# termico: o ini em uso tem de ser IDENTICO ao corrigido (md5). Um .ini anterior
# a escada tem o mux mas nao a escada e antes passava como aplicado.
ini_md5(){ md5sum "$INI" 2>/dev/null | cut -d' ' -f1; }
term_ok(){ _m=$(ini_md5); [ -n "$_m" ] && { [ "$_m" = "$INI_MD5_OK" ] || [ "$_m" = "$INI_MD5_OK_NOTYPEC" ]; }; }
# md5 que o .ini corrigido TEM de ter, dado o md5 do .ini do aparelho; vazio =
# aparelho desconhecido (nao e aplicavel)
term_alvo_de(){
  [ -n "$1" ] || return 0
  [ "$1" = "$INI_MD5_FABRICA_NOTYPEC" ] && { echo "$INI_MD5_OK_NOTYPEC"; return 0; }
  [ "$1" = "$INI_MD5_FABRICA" ] && { echo "$INI_MD5_OK"; return 0; }
  for _a in $INI_MD5_ANTERIORES; do
    [ "$1" = "$_a" ] && { echo "$INI_MD5_OK"; return 0; }
  done
  return 0
}

# ---- .ini por secoes ---------------------------------------------------------
# Monta o .ini corrigido a partir do .ini DO APARELHO ($1) e do corrigido do
# pendrive ($2): as secoes de TERM_SECOES vem do $2, tudo o mais (o cabecalho antes
# da 1a secao, o CONFIG_MODEL, as demais secoes) fica byte a byte como no $1.
# So grep/sed/head/tail/tr (nada de awk) e cortes por numero de linha, que nao
# mexem nos bytes (o arquivo mistura ASCII, chines GBK e mojibake). O chamador
# confere o md5 do resultado contra o esperado: se o shell do aparelho se
# comportar diferente, o resultado nao confere e nada e gravado.
# "linha nome" de cada secao [nome] do arquivo $1
ini_secoes(){ grep -a -n '^\[' "$1" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\):\[\([^]]*\)\].*$/\1 \2/p'; }
# "ini fim" (linhas) da secao $2 do arquivo $1; !=0 se nao existe ou se repete
ini_faixa(){
  _ftot=$(grep -a -c '' "$1" 2>/dev/null)
  [ "$(ini_secoes "$1" | grep -c " $2\$")" = 1 ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- "$_ftot" "$2" $(ini_secoes "$1" | grep -A1 " $2\$" | tr '\n' ' ')
  [ "$4" = "$2" ] || return 1
  if [ -n "${5:-}" ]; then echo "$3 $(($5-1))"; else echo "$3 $1"; fi
}
# acrescenta a $INI_S a secao $1 (linhas $2 a $3 do $INI_A, ou a do $INI_B se termica)
ini_emite(){
  case " $TERM_SECOES " in
    *" $1 "*)
      # shellcheck disable=SC2046
      set -- $(ini_faixa "$INI_B" "$1")
      [ "$#" = 2 ] || return 1
      head -n "$2" "$INI_B" | tail -n "+$1" >> "$INI_S" ;;
    *) head -n "$3" "$INI_A" | tail -n "+$2" >> "$INI_S" ;;
  esac
}
ini_compor(){
  INI_A="$1"; INI_B="$2"; INI_S="$3"
  _ctot=$(grep -a -c '' "$INI_A" 2>/dev/null)
  ini_secoes "$INI_A" > "$INI_S.lista" || return 1
  _cprim=$(sed -n '1s/ .*//p' "$INI_S.lista")
  [ -n "$_cprim" ] && [ -n "$_ctot" ] || return 1
  : > "$INI_S" || return 1
  if [ "$_cprim" -gt 1 ]; then head -n "$((_cprim-1))" "$INI_A" >> "$INI_S" || return 1; fi
  _cini=""; _cnome=""
  while read -r _cl _cn; do
    if [ -n "$_cnome" ]; then ini_emite "$_cnome" "$_cini" "$((_cl-1))" || return 1; fi
    _cini="$_cl"; _cnome="$_cn"
  done < "$INI_S.lista"
  ini_emite "$_cnome" "$_cini" "$_ctot" || return 1
  rm -f "$INI_S.lista"
}
# monta em $WORK/ini.composto o .ini corrigido do aparelho e confere o md5 ($1 =
# esperado; $2 = md5 do .ini do aparelho). Sem o esperado igual, apaga e devolve !=0.
#  - de fabrica (qualquer dos dois modelos): so as secoes termicas, o resto do .ini do
#    aparelho fica como esta (o CONFIG_MODEL de cada modelo e preservado);
#  - versao anterior NOSSA: e um .ini do modelo com USB-C que ja foi corrigido uma vez
#    e que difere do atual ate fora das secoes termicas (espacos de fim de linha), entao
#    troca-se o arquivo inteiro, como sempre foi (o resultado e o mesmo md5 de antes).
term_compor(){
  rm -f "$WORK/ini.composto" "$WORK/ini.composto.lista"
  _anterior=0
  for _a in $INI_MD5_ANTERIORES; do [ "$2" = "$_a" ] && _anterior=1; done
  if [ "$_anterior" = 1 ]; then
    cp "$MP/ZYCustom.ini" "$WORK/ini.composto" 2>/dev/null || _anterior=erro
  else
    ini_compor "$INI" "$MP/ZYCustom.ini" "$WORK/ini.composto" || _anterior=erro
  fi
  if [ "$_anterior" != erro ] && [ "$(md5sum "$WORK/ini.composto" 2>/dev/null | cut -d' ' -f1)" = "$1" ]; then
    return 0
  fi
  rm -f "$WORK/ini.composto" "$WORK/ini.composto.lista"
  return 1
}
wifi_ok(){ [ -f "$BP" ] && grep -q "wifi_disconnect_on_boot=0" "$BP" 2>/dev/null; }
xiri_ok(){ grep -A1 "service xiriservice" "$RC" 2>/dev/null | grep -q "disabled"; }

CHG=0
FAIL=0
AVISO=0   # 1 = a fase termica nao ficou efetiva; a tela final sera ERRO

# /atv/ini/ZYCustom*.ini tem precedencia sobre o /vendor (doc 06): se existir,
# o ini do /vendor nao vale e o kit avisa em vez de dizer que deu certo.
for _f in "$ATV_INI_DIR"/ZYCustom*.ini; do
  if [ -f "$_f" ]; then
    LOG "[AVISO] termico: existe $_f e ele TEM PRECEDENCIA sobre $INI - a correcao termica do /vendor NAO esta valendo. Remova esse arquivo (ver docs/research/06)."
    AVISO=1
  fi
done

TERM_ACAO=0
if term_ok; then
  LOG "termico ja estava ok (md5 do ZYCustom.ini = corrigido)"
else
  TERM_MD5_ATUAL=$(ini_md5)
  TERM_ALVO=$(term_alvo_de "$TERM_MD5_ATUAL")
  if [ -z "$TERM_ALVO" ]; then
    LOG "[ERRO] termico: md5 do ZYCustom.ini em uso ('$(ini_md5)') nao e o de fabrica (V1.0.0.9 $INI_MD5_FABRICA; V1.0.0.1 $INI_MD5_FABRICA_NOTYPEC) nem o de uma versao anterior nossa - NAO vou sobrescrever (firmware diferente?)."
    FAIL=$((FAIL+1))
    AVISO=1
  elif ! term_compor "$TERM_ALVO" "$TERM_MD5_ATUAL"; then
    LOG "[ERRO] termico: nao consegui montar o ZYCustom.ini corrigido a partir do do aparelho (o resultado nao tem o md5 esperado $TERM_ALVO) - NAO vou gravar."
    FAIL=$((FAIL+1))
    AVISO=1
  else
    TERM_ACAO=1
  fi
fi

# O /vendor so e aberto rw se algum dos 3 fixes DE /vendor estiver pendente.
VENDOR_RW=0
if [ "$TERM_ACAO" = "1" ] || ! wifi_ok || ! xiri_ok; then
  LOG "correcao ausente/incompleta -> aplicando o que faltar no /vendor ..."
  if ! mount -o rw,remount /vendor; then
    LOG "[ERRO] nao consegui remontar /vendor rw (dm-verity/particao ocupada?) - retentar no proximo boot."
    exit 1
  fi
  VENDOR_RW=1
fi

# ---- FIX 1: termico (secoes termicas sobre o .ini do aparelho) ----
if [ "$TERM_ACAO" = "1" ]; then
  # salva o stock UMA vez, antes de sobrescrever, e so se o atual for o de fabrica
  # (de qualquer um dos dois modelos)
  if [ ! -f "$INI.STOCK" ] && { [ "$(ini_md5)" = "$INI_MD5_FABRICA" ] || [ "$(ini_md5)" = "$INI_MD5_FABRICA_NOTYPEC" ]; }; then
    cp "$INI" "$INI.STOCK" || LOG "[AVISO] nao consegui salvar $INI.STOCK"
  fi
  # escrita atomica: .new + validacao por md5 + mv + releitura por md5
  if cp "$WORK/ini.composto" "$INI.new" && chmod 644 "$INI.new" \
     && [ "$(md5sum "$INI.new" 2>/dev/null | cut -d' ' -f1)" = "$TERM_ALVO" ]; then
    if mv "$INI.new" "$INI" && term_ok; then
      LOG "[OK] termico: ZYCustom.ini gravado e conferido por md5 (fans 100% sempre, 2o sensor, escada de brilho 1000->850 entre 66C e 70C, shutdown 75C)"
      CHG=1
    else
      LOG "[ERRO] termico: falha no mv final ou a releitura nao confere."
      rm -f "$INI.new"
      FAIL=$((FAIL+1))
      AVISO=1
    fi
  else
    LOG "[ERRO] termico: o .new copiado nao tem o md5 esperado - NAO vou reiniciar."
    rm -f "$INI.new"
    FAIL=$((FAIL+1))
    AVISO=1
  fi
  rm -f "$WORK/ini.composto"
fi

# ---- FIX 2: wi-fi reconecta sozinho apos boot ----
if wifi_ok; then
  LOG "wi-fi ja estava ok (wifi_disconnect_on_boot=0 presente)"
else
  if [ ! -f "$BP.STOCK" ]; then
    cp "$BP" "$BP.STOCK" || LOG "[AVISO] nao consegui salvar $BP.STOCK"
  fi
  if cp "$BP" "$BP.new" && sed -i "s/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/" "$BP.new" \
     && grep -q "wifi_disconnect_on_boot=0" "$BP.new" && mv "$BP.new" "$BP"; then
    LOG "[OK] wi-fi: wifi_disconnect_on_boot=0"
    CHG=1
  else
    LOG "[ERRO] wi-fi: falha ao editar wifi_disconnect_on_boot em $BP"
    rm -f "$BP.new"
    FAIL=$((FAIL+1))
  fi
fi

# ---- FIX 3: silencia o spam do xiriservice ----
if xiri_ok; then
  LOG "xiri ja estava desabilitado"
else
  # BOOT-CRITICO: nunca sed -i no arquivo vivo; edita .new e so entao mv
  if [ ! -f "$RC.STOCK" ]; then
    cp "$RC" "$RC.STOCK" || LOG "[AVISO] nao consegui salvar $RC.STOCK"
  fi
  if cp "$RC" "$RC.new" \
     && sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$RC.new" \
     && grep -A1 "service xiriservice" "$RC.new" | grep -q "disabled" \
     && mv "$RC.new" "$RC"; then
    LOG "[OK] xiri: xiriservice desabilitado (fim do spam de log)"
    CHG=1
  else
    LOG "[ERRO] xiri: falha ao desabilitar xiriservice em $RC"
    rm -f "$RC.new"
    FAIL=$((FAIL+1))
  fi
fi

sync
# fecha o /vendor em TODOS os ramos, inclusive no de reboot - antes ele ficava
# gravavel durante os 8 s de sleep.
if [ "$VENDOR_RW" = "1" ]; then
  mount -o ro,remount /vendor 2>/dev/null
fi

if [ "$CHG" = "1" ] && [ "$FAIL" = "0" ]; then
  LOG "==== CORRECAO APLICADA COM SUCESSO! reiniciando em 8s para ativar ===="
  # a fase de cor roda no boot seguinte, com o pendrive ainda plugado. A tela e so
  # cosmetica: se o cor.sh nao conferir na hora, nao executa e o reboot segue.
  if cor_pronto; then
    sh "$WORK/cor.sh" --tela reiniciando
  else
    LOG "[ERRO] cor.sh nao conferiu na hora de executar - tela de reinicio dispensada (a correcao ja foi aplicada)."
  fi
  sleep "$ESPERA_REBOOT"
  reboot
  exit 0
fi
if [ "$FAIL" != "0" ]; then
  LOG "==== [PARCIAL] $FAIL fix(es) falharam - reexecute o pendrive (reinicie o projetor). ===="
  AVISO=1
else
  LOG "==== fixes de /vendor ja estavam ok; nada a reiniciar. ===="
fi

# ---- FASE DE COR (destacada do exec do init) ---------------------------------
# PREMISSA NAO CONFIRMADA (doc 41): o init processa o 'exec' de forma bloqueante
# (inferido do AOSP), entao a pergunta de ate ~90 s nao pode rodar aqui dentro;
# lancamos o cor.sh destacado (setsid, ou nohup se nao houver) com log proprio,
# que ele copia para o pendrive no fim. E o unico ponto que depende disso.
# Segunda premissa, do mesmo ponto: ao fim do exec o init NAO mata o grupo de
# processos do servico temporario (oneshot) e o cor.sh destacado sobrevive. Se
# matar, a fase de cor morre no inicio: sem journal ainda, nada foi escrito.
if [ "$AVISO" = "1" ]; then AVISO_ARG="termica-falhou"; else AVISO_ARG=""; fi
# O cor.sh recebe o md5 que a lista embutida manda (COR_MD5): e o que o gancho de
# boot dele vai embutir. A conferencia abaixo e a ULTIMA antes de executar.
if ! cor_pronto; then
  LOG "[ERRO] cor.sh nao conferiu na hora de executar - a fase de cor NAO foi lancada (nada foi escrito na panelparam)."
  exit 1
fi
LOG "lancando a fase de cor (cor.sh) destacada; log em $WORK/cor.log e, no fim, newlink_cor.log no pendrive"
if command -v setsid >/dev/null 2>&1; then
  setsid sh "$WORK/cor.sh" "$MP" "$AVISO_ARG" "$COR_MD5" >>"$WORK/cor.log" 2>&1 </dev/null &
else
  nohup sh "$WORK/cor.sh" "$MP" "$AVISO_ARG" "$COR_MD5" >>"$WORK/cor.log" 2>&1 </dev/null &
fi
exit 0
