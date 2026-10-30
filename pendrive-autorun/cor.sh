#!/vendor/bin/sh
# ---------------------------------------------------------------------------
#  CONVENCAO DE CHARSET (NAO MEXER): ASCII PURO de proposito, como o
#  newlink_update.sh. Roda no /vendor/bin/sh do projetor (mksh/toybox do
#  Android 9) e vive em pendrive FAT32. Sem bashismo.
# ---------------------------------------------------------------------------
# ============================================================================
#  PFL7560 - kit universal, FASE DE COR (bloco 5, doc 41)
#
#  Quem chama: o newlink_update.sh, DEPOIS de conferir o md5 de cada arquivo do
#  kit e de copia-los para /data/vendor/pfl7560-kit (pasta SO DO ROOT, 0700).
#  Este script roda DESTACADO do exec do init (a pergunta dura ate ~90 s) e
#  nunca e executado direto do pendrive.
#
#    cor.sh <mountpoint> <termica-falhou|""> <md5 de cor.sh>   teste de cor
#    cor.sh --restaurar                     devolve o formato original (journal)
#    cor.sh --tela <nome>                   mostra kit/<nome>.png e sai
#
#  SEGURANCA (E3b): tudo aqui roda como root. A pasta de trabalho e verificada a
#  cada uso (diretorio real, nao link, dono root, sem acesso de grupo/outros);
#  arquivo dela que seja link ou de outro dono e recusado; o lvdsctl so executa
#  com o md5 embutido conferido NA HORA; o backup so restaura com o md5 gravado
#  no journal.
#
#  O QUE FAZ (idempotente, sem serial, sem arquivo para editar):
#   1. Projeta as DUAS METADES de cinza (63|64 e 127|128). Formato certo = metades
#      iguais; formato errado = uma bem mais clara (rotacao de 2 bits, doc 41 s4).
#   2. Sem tecla em 30 s: NADA e escrito. Esta e a saida do aparelho de fabrica.
#   3. Com uma tecla: backup do panelparam (conferido com cmp), journal em /data,
#      troca o formato AO VIVO (lvdsctl fmt) e projeta de novo.
#   4. So MANTEM com uma SEGUNDA tecla, e so se a particao inteira diferir do
#      backup apenas no byte 0x5c. Sem ela, REVERTE e confere a particao inteira
#      contra o backup. Nao precisa de confirmacao.
#   5. Queda de energia no meio: o journal restaura no boot seguinte (pelo
#      newlink_update.sh com o pendrive, ou pelo gancho de boot de fabrica).
#
#  Toca SO no byte lvdsctl_fmt (0x5c) do perfil ativo da panelparam; nunca em
#  swap, bit ou map. NUNCA chama hidebug nem gtt (doc 37).
# ============================================================================

# ---- ganchos de teste -------------------------------------------------------
# So valem com PFL_TESTE=1 (o harness em tests/ a define). Fora disso TODAS saem
# do ambiente, para que nenhuma delas seja porta de entrada em producao. O gancho
# de boot gerado por este script apaga todas antes de qualquer coisa.
if [ "${PFL_TESTE:-}" != "1" ]; then
  unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_RAPIDO PFL_DONO PFL_TESTE
fi
R="${PFL_ROOT:-}"
PP="$R/dev/block/by-name/panelparam"
PROC_PANEL="$R/proc/msp/panel"
WORK="$R/data/vendor/pfl7560-kit"
NLSU="$R/data/local/nlsu"
HOOK="$NLSU/update_after_boot.sh"
LOCK="$R/dev/pfl7560-kit.lock"
LVDSCTL="${PFL_LVDSCTL:-$WORK/lvdsctl}"
# md5 do lvdsctl do kit (o mesmo da lista do newlink_update.sh); conferido na hora
# de cada execucao. DONO_UID: o dono exigido nas pastas e arquivos (root = 0).
LVDSCTL_MD5="178d812872cb9306c0ae6faeed07184a"
DONO_UID=0
if [ "${PFL_TESTE:-}" = "1" ]; then
  [ -n "${PFL_DONO:-}" ] && DONO_UID="$PFL_DONO"
  [ -n "${PFL_LVDSCTL_MD5:-}" ] && LVDSCTL_MD5="$PFL_LVDSCTL_MD5"
fi
LIBHITV="$R/vendor/lib/libhitvservice.so"
LIBS="/vendor/lib:/system/lib"
JOURNAL="$WORK/journal"
BKP="$WORK/panelparam-original.img"
LOGF="$WORK/cor.log"

# layout da panelparam (o mesmo do bloco 1 e do wizard do PC)
PERFIL_TAM=768
TABELA_BASE=168
LVDS_FMT_OFF=92
PERFIL_MAX=82
PP_TAM=8388608

# tempos (s)
TEMPO_TECLA=30        # sem tecla neste prazo = nao mexe / reverte
TEMPO_ASSENTAR=2      # tela nova + folga para a 1a tecla nao valer de 2a
AUTOFOCO_MAX=60
AUTOFOCO_FOLGA=30
ESPERA_REBOOT=5
# gancho de teste (so com PFL_TESTE=1): o harness (tests/) zera as esperas
[ -n "${PFL_RAPIDO:-}" ] && { TEMPO_ASSENTAR=0; AUTOFOCO_MAX=0; AUTOFOCO_FOLGA=0; ESPERA_REBOOT=0; }

# ---- MODO AUTOMATICO (E5, camera) -- DESLIGADO ---------------------------------
# Ponto de chamada reservado: com MODO_AUTO=1, em vez de esperar a tecla da
# pessoa, o kit chamaria um binario de camera (nl_camcheck, ainda inexistente)
# que mede a luma das duas metades e devolve 0 = formato certo, 1 = errado,
# 2 = sem margem (a pessoa decide). So liga depois do portao da etapa E5
# (docs/sprints/2026-10-29-bloco-5-kit-universal.md). Hoje a funcao abaixo nunca
# e chamada e devolve "sem decisao".
MODO_AUTO=0
decidir_por_camera(){ return 2; }

LOG(){ echo "[PFL7560-cor] $*"; }

# ---- seguranca da pasta de trabalho e dos arquivos dela (E3b) -----------------
# Este script roda como root a partir de $WORK. Se alguem que nao e root pudesse
# escrever la (ou trocar a pasta por um link), executaria codigo como root. Entao:
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
# md5 de um arquivo (so o hash)
md5_de(){ md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
trabalho_ok(){
  dir_seguro "$WORK" && return 0
  LOG "[ERRO] $WORK nao e uma pasta so do root (link, dono errado ou aberta a outros) - NAO vou usar nem escrever."
  return 1
}

# ---- travas ------------------------------------------------------------------
# lock em /dev (tmpfs): some no reboot, entao nunca fica preso. Impede que o
# newlink_update.sh e o gancho de boot restaurem ao mesmo tempo.
pegar_lock(){ mkdir "$LOCK" 2>/dev/null; }
# shellcheck disable=SC2317  # chamada por trap EXIT
soltar_lock(){ rmdir "$LOCK" 2>/dev/null; }

# ---- leitura do perfil de painel ---------------------------------------------
cor_idx(){ awk -F'[:|]' '/cut_idx/{v=$2; gsub(/[^0-9]/,"",v); if(v!=""){print v+0; exit}}' "$PROC_PANEL" 2>/dev/null; }
cor_pnome(){ awk -F'[:|]' '/panel_name/{v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); if(v!=""){print v; exit}}' "$PROC_PANEL" 2>/dev/null; }
cor_nome(){
  _i="$1"; [ -n "$_i" ] || return 1
  dd if="$PP" bs=1 skip=$(( TABELA_BASE + _i * PERFIL_TAM )) count=32 2>/dev/null \
    | tr '\000' '\n' | head -1
}
# valor atual do byte lvds_fmt (0=VESA, 1=JEIDA); vazio se nao conseguir ler
cor_valor(){
  _i="$1"; [ -n "$_i" ] || return 1
  dd if="$PP" bs=1 skip=$(( TABELA_BASE + _i * PERFIL_TAM + LVDS_FMT_OFF )) count=1 2>/dev/null \
    | od -An -tu1 | tr -dc '0-9'
}
cor_serial(){ getprop ro.serialno 2>/dev/null | tr -dc 'A-Za-z0-9'; }

# grava 1 byte (0 ou 1) no offset dado. So existem estes dois valores.
gravar_fmt(){
  _off="$1"
  if [ "$2" = "1" ]; then
    printf '\001' | dd of="$PP" bs=1 seek="$_off" count=1 conv=notrunc 2>/dev/null
  else
    printf '\000' | dd of="$PP" bs=1 seek="$_off" count=1 conv=notrunc 2>/dev/null
  fi
}

# ---- tela --------------------------------------------------------------------
# PREMISSA NAO CONFIRMADA NO APARELHO (E1-e): a galeria abre PNG fora de /sdcard.
# Opcao segura: usar /sdcard/pfl7560-kit, caminho que o doc 28 s4 provou; se nao
# der para gravar la, cai em $WORK/tela (o caminho candidato da E1-e).
preparar_tela(){
  TELA_DIR="$R/sdcard/pfl7560-kit"
  # so copia PNG que seja arquivo regular do root (nada de link dentro de $WORK/kit)
  for _p in "$WORK"/kit/*.png; do
    arq_seguro "$_p" || { LOG "[AVISO] $_p e link ou de outro dono - telas NAO preparadas."; TELA_DIR=""; return 1; }
  done
  rm -rf "$TELA_DIR" 2>/dev/null
  if ! mkdir -p "$TELA_DIR" 2>/dev/null || ! cp "$WORK"/kit/*.png "$TELA_DIR"/ 2>/dev/null; then
    TELA_DIR="$WORK/tela"
    mkdir -p "$TELA_DIR" && cp "$WORK"/kit/*.png "$TELA_DIR"/ 2>/dev/null
  fi
  chmod 755 "$TELA_DIR" 2>/dev/null
  chmod 644 "$TELA_DIR"/*.png 2>/dev/null
}
mostrar(){
  _f="$TELA_DIR/$1.png"
  [ -f "$_f" ] || { LOG "[AVISO] tela $1 ausente em $TELA_DIR"; return 1; }
  LOG "tela: $1"
  am start -a android.intent.action.VIEW -d "file://${_f#"$R"}" -t image/png >/dev/null 2>&1
}

# PREMISSA NAO CONFIRMADA (doc 41, modos de falha): o autofoco/keystone pode
# cobrir a tela do kit logo apos o boot e o AutoFocusService some uns 25 s depois
# de subir. Espera ate AUTOFOCO_MAX a prop dizer que focou e mais AUTOFOCO_FOLGA.
# Se a prop nao existir, o laco acaba no teto e segue (nunca trava).
aguardar_autofoco(){
  _t=0
  while [ "$_t" -lt "$AUTOFOCO_MAX" ]; do
    [ "$(getprop vendor.focus.camera.is_focused 2>/dev/null)" = "true" ] && break
    sleep 2
    _t=$(( _t + 2 ))
  done
  sleep "$AUTOFOCO_FOLGA"
}

# PREMISSA NAO CONFIRMADA (E1-d): getevent existe e, com -ql, imprime linhas
# "EV_KEY ... DOWN" ao vivo quando se aperta uma tecla do controle. Aceita QUALQUER
# tecla (o codigo e desconhecido). Se a saida for bufferizada ou o formato
# diferir, nada casa e o resultado e "sem tecla", que e sempre o lado seguro:
# nada e gravado na primeira pergunta e tudo e revertido na segunda.
# Na E1-d, confira ESTE comando com pipe (getevent -ql | grep), nao o getevent
# sozinho num terminal: no terminal a saida sai por linha e esconderia uma
# bufferizacao por bloco quando a saida e um pipe.
esperar_tecla(){
  timeout "$TEMPO_TECLA" getevent -ql 2>/dev/null | grep -q 'EV_KEY.*DOWN'
}

# ---- lvdsctl (troca AO VIVO) -------------------------------------------------
# O lvdsctl roda como root: so executa se for arquivo regular do root (nao link) e
# com o md5 embutido, conferido AGORA (a cada execucao), nunca "de antes".
lvdsctl_confere(){
  if arq_seguro "$LVDSCTL" && [ "$(md5_de "$LVDSCTL")" = "$LVDSCTL_MD5" ]; then return 0; fi
  LOG "[ERRO] lvdsctl ($LVDSCTL) ausente, link, de outro dono ou com md5 diferente do esperado - NAO vou executar."
  return 1
}
vivo_disponivel(){ [ -x "$LVDSCTL" ] && [ -f "$LIBHITV" ] && lvdsctl_confere; }
# O codigo de saida do lvdsctl nao e confiavel; quem confirma e a releitura do
# byte (SetLvdsFormat persiste na hora, doc 40 s1).
aplicar_vivo(){
  lvdsctl_confere || return 1
  LOG "lvdsctl fmt $1"
  LD_LIBRARY_PATH="$LIBS" timeout 30 "$LVDSCTL" fmt "$1" >/dev/null 2>&1
}

# ---- journal -----------------------------------------------------------------
jornal_gravar(){ # idx off fmt_original md5_do_backup
  {
    echo "J_IDX=$1"
    echo "J_OFF=$2"
    echo "J_FMT=$3"
    echo "J_MD5=$4"
  } > "$JOURNAL.new" && sync && mv "$JOURNAL.new" "$JOURNAL" && sync
}
jornal_campo(){ sed -n "s/^$1=\\([0-9]*\\)\$/\\1/p" "$JOURNAL" 2>/dev/null | head -1; }
# md5 do backup guardado no journal (32 hex minusculos, ou vazio)
jornal_md5(){ sed -n 's/^J_MD5=\([0-9a-f]*\)$/\1/p' "$JOURNAL" 2>/dev/null | head -1; }
# carrega e valida o journal em J_IDX/J_OFF/J_FMT/J_MD5; falha fechada
jornal_ler(){
  arq_seguro "$JOURNAL" || return 1
  J_IDX=$(jornal_campo J_IDX); J_OFF=$(jornal_campo J_OFF); J_FMT=$(jornal_campo J_FMT)
  J_MD5=$(jornal_md5)
  [ "${#J_MD5}" = "32" ] || return 1
  case "$J_IDX$J_OFF$J_FMT" in ''|*[!0-9]*) return 1 ;; esac
  [ -n "$J_IDX" ] && [ -n "$J_OFF" ] && [ -n "$J_FMT" ] || return 1
  [ "$J_IDX" -le "$PERFIL_MAX" ] || return 1
  [ "$J_FMT" = "0" ] || [ "$J_FMT" = "1" ] || return 1
  [ "$J_OFF" = "$(( TABELA_BASE + J_IDX * PERFIL_TAM + LVDS_FMT_OFF ))" ]
}

# ---- comparacao da particao com o backup -------------------------------------
# Compara a PARTICAO INTEIRA, nao so o perfil: uma escrita do lvdsctl fora do
# perfil (cabecalho, outro perfil, checksum) tambem tem de aparecer. Sem arquivo
# temporario: cmp direto entre o dispositivo e o backup.
particao_igual_backup(){ cmp -s "$PP" "$BKP"; }
# 0 se a particao difere do backup (no maximo) no byte lvds_fmt do journal ($1)
particao_so_difere_no_fmt(){
  _n=$(cmp -l "$PP" "$BKP" 2>/dev/null | head -2 | wc -l | tr -dc '0-9')
  [ -n "$_n" ] && [ "$_n" -le 1 ] || return 1
  [ "$_n" = "0" ] && return 0
  # shellcheck disable=SC2046
  set -- "$1" $(cmp -l "$PP" "$BKP" 2>/dev/null | head -1)
  [ "$2" = "$(( $1 + 1 ))" ]
}
# copia do backup para a particao um trecho [inicio, inicio+tamanho)
restaurar_trecho(){
  dd if="$BKP" of="$PP" bs=1 skip="$1" seek="$1" count="$2" conv=notrunc 2>/dev/null && sync
}

# ---- restauracao -------------------------------------------------------------
# Devolve o byte original a partir do journal e CONFERE a particao inteira contra
# o backup. Se houver qualquer outra diferenca, restaura os 768 bytes do perfil
# e, se ainda sobrar diferenca fora dele, a particao inteira; confere de novo.
# journal legivel e backup do tamanho da particao: sem isso nada se escreve
# O backup so vale se for arquivo regular do root (nao link), do tamanho da
# particao e com o md5 que o journal gravou quando ele foi feito (E3b): um backup
# trocado ou adulterado nunca e usado para restaurar.
jornal_e_backup_ok(){
  trabalho_ok || return 1
  jornal_ler || { LOG "[ERRO] journal ilegivel, incoerente, link ou de outro dono - NAO vou escrever."; return 1; }
  arq_seguro "$BKP" || { LOG "[ERRO] backup $BKP ausente, link ou de outro dono - NAO vou escrever."; return 1; }
  _tam=$(wc -c < "$BKP" | tr -dc '0-9')
  [ "$_tam" = "$PP_TAM" ] || { LOG "[ERRO] backup com $_tam bytes (esperado $PP_TAM) - NAO vou escrever."; return 1; }
  [ "$(md5_de "$BKP")" = "$J_MD5" ] || { LOG "[ERRO] md5 do backup diferente do gravado no journal (backup adulterado) - NAO vou escrever."; return 1; }
}
restaurar_formato(){
  jornal_e_backup_ok || return 1
  LOG "restaurando lvds_fmt=$J_FMT no perfil $J_IDX (offset $J_OFF)"
  gravar_fmt "$J_OFF" "$J_FMT" || { LOG "[ERRO] dd de restauracao falhou."; return 1; }
  sync
  if particao_igual_backup; then
    LOG "[OK] formato restaurado: a particao inteira confere com o backup"
    return 0
  fi
  LOG "[AVISO] a particao difere do backup alem do byte - restaurando os $PERFIL_TAM bytes do perfil"
  restaurar_trecho $(( TABELA_BASE + J_IDX * PERFIL_TAM )) "$PERFIL_TAM" \
    || { LOG "[ERRO] restauracao do perfil falhou."; return 1; }
  if particao_igual_backup; then
    LOG "[OK] perfil restaurado do backup e a particao inteira confere"
    return 0
  fi
  LOG "[AVISO] ainda ha diferenca fora do perfil - restaurando a particao inteira do backup"
  if ! { dd if="$BKP" of="$PP" bs=4096 conv=notrunc 2>/dev/null && sync; }; then
    LOG "[ERRO] restauracao da particao falhou."; return 1
  fi
  if particao_igual_backup; then
    LOG "[OK] particao restaurada do backup e conferida"
    return 0
  fi
  LOG "[ERRO] depois de restaurar, a releitura NAO confere. Restaure o backup com ./pfl7560-lcd-color.sh restore."
  return 1
}

# Desfaz um teste de cor a partir do journal, NESTA ordem: (1) aplica o formato
# original AO VIVO com o journal ainda valendo (o lvdsctl tambem grava na
# particao); (2) grava o byte e CONFERE a particao inteira contra o backup;
# (3) so entao apaga o journal e o gancho. Nenhuma escrita na particao fica
# depois da conferencia. VIVO_OK=1 se o lvdsctl devolveu 0 (o formato ao vivo
# provavelmente voltou). Devolve !=0 se nao conferiu ou se o journal nao pode ser
# apagado: o journal fica e a proxima tentativa refaz tudo (e idempotente).
reverter(){
  VIVO_OK=0
  jornal_e_backup_ok || return 1
  if vivo_disponivel && aplicar_vivo "$J_FMT"; then VIVO_OK=1; fi
  restaurar_formato || return 1
  rm -f "$JOURNAL"
  if [ -f "$JOURNAL" ]; then
    LOG "[ERRO] formato restaurado e conferido, mas nao consegui apagar $JOURNAL."
    return 1
  fi
  remover_gancho
  return 0
}

# ---- gancho de recuperacao ---------------------------------------------------
# PREMISSA NAO CONFIRMADA (E1-c): /data/local/nlsu nao existe neste aparelho. O
# init de fabrica executa /data/local/nlsu/update_after_boot.sh como root no
# sys.boot_completed (init.bigfish.rc:371-373). So criamos o gancho se NAO existir
# um; se existir um que nao e nosso, nao tocamos e avisamos. O gancho se apaga
# quando o journal some.
#
# O gancho roda como root e vive numa pasta que o usuario shell pode ter criado
# antes de nos (/data/local e do shell), entao: so instalamos se $NLSU nao existir
# ou for diretorio real do root sem escrita de grupo/outros. O gancho gerado:
#  1. apaga do ambiente TODOS os ganchos de teste (PFL_*); em producao ele nao leva
#     nenhuma atribuicao deles (so o harness, com PFL_TESTE=1, as embute);
#  2. so executa o cor.sh se a pasta de trabalho for so do root, o cor.sh for
#     arquivo regular do root (nao link) e o md5 for o EMBUTIDO neste gancho (o do
#     cor.sh que o gerou), conferido na hora da execucao.
nlsu_ok(){
  [ -d "$NLSU" ] && [ ! -L "$NLSU" ] || return 1
  # shellcheck disable=SC2046  # divisao em campos de proposito
  set -- $(ls -ldn "$NLSU" 2>/dev/null)
  case "$1" in
    d????-??-*) [ "$3" = "$DONO_UID" ] ;;
    *) return 1 ;;
  esac
}
gerar_gancho(){
  echo '#!/vendor/bin/sh'
  echo '# pfl7560-kit-gancho: criado pelo kit de pendrive. Restaura o formato LVDS se um'
  echo '# teste de cor foi interrompido e se apaga quando o journal some.'
  echo 'unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_RAPIDO PFL_DONO PFL_TESTE'
  if [ "${PFL_TESTE:-}" = "1" ]; then
    echo "PFL_TESTE=1; PFL_ROOT='$R'; PFL_RAPIDO='${PFL_RAPIDO:-}'; PFL_DONO='$DONO_UID'; PFL_LVDSCTL='${PFL_LVDSCTL:-}'; PFL_LVDSCTL_MD5='$LVDSCTL_MD5'"
    echo 'export PFL_TESTE PFL_ROOT PFL_RAPIDO PFL_DONO PFL_LVDSCTL PFL_LVDSCTL_MD5'
  fi
  echo "W=\"$WORK\""
  echo "JOURNAL=\"$JOURNAL\""
  echo "DONO=\"$DONO_UID\""
  echo "COR_MD5=\"$COR_MD5\""
  cat <<'FIM'
seguro_dir(){
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  set -- $(ls -ldn "$1" 2>/dev/null)
  case "$1" in
    d???------|d???------[.+]) [ "$3" = "$DONO" ] ;;
    *) return 1 ;;
  esac
}
seguro_arq(){
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  set -- $(ls -ln "$1" 2>/dev/null)
  [ "$3" = "$DONO" ]
}
if [ -f "$JOURNAL" ]; then
  if seguro_dir "$W" && seguro_arq "$W/cor.sh" \
     && [ "$(md5sum "$W/cor.sh" 2>/dev/null | cut -d' ' -f1)" = "$COR_MD5" ]; then
    sh "$W/cor.sh" --restaurar
  else
    echo "[PFL7560-gancho] cor.sh ou a pasta de trabalho nao conferem - NAO vou executar."
  fi
fi
[ -f "$JOURNAL" ] || rm -f "$0"
FIM
}
instalar_gancho(){
  if [ -e "$HOOK" ] || [ -L "$HOOK" ]; then
    nlsu_ok && grep -q "pfl7560-kit-gancho" "$HOOK" 2>/dev/null && [ ! -L "$HOOK" ] && return 0
    LOG "[AVISO] ja existe $HOOK e nao e nosso (ou a pasta nao e so do root): gancho de recuperacao NAO instalado (a restauracao depende do pendrive no proximo boot)."
    return 0
  fi
  # mkdir (sem -p) falha se alguem criou a pasta no meio tempo; nlsu_ok decide
  if [ ! -e "$NLSU" ] && [ ! -L "$NLSU" ]; then
    mkdir -p "${NLSU%/*}" 2>/dev/null
    ( umask 022; mkdir "$NLSU" 2>/dev/null ) && chmod 755 "$NLSU" 2>/dev/null
  fi
  if nlsu_ok && gerar_gancho > "$HOOK.new"; then
    chmod 755 "$HOOK.new" && mv "$HOOK.new" "$HOOK" && sync && LOG "gancho de recuperacao instalado em $HOOK" && return 0
  fi
  rm -f "$HOOK.new" 2>/dev/null
  LOG "[AVISO] nao consegui instalar o gancho de recuperacao em $HOOK (se a pasta existe, ela nao e so do root)."
  return 0
}
remover_gancho(){
  if grep -q "pfl7560-kit-gancho" "$HOOK" 2>/dev/null; then
    rm -f "$HOOK"
    rmdir "$NLSU" 2>/dev/null
  fi
}

# ---- backup ------------------------------------------------------------------
# dd + cmp: o cmp valida tamanho E conteudo de uma vez; um backup byte-identico
# a ESTA particao e, por definicao, um backup valido dela. A copia principal fica
# em /data (o journal depende dela); a copia do pendrive e best effort.
preparar_backup(){
  rm -f "$BKP" "$BKP.md5"
  if ! { dd if="$PP" of="$BKP" bs=4096 2>/dev/null && sync && arq_seguro "$BKP" && cmp -s "$BKP" "$PP"; }; then
    LOG "[ERRO] backup do panelparam invalido ou impossivel - NAO vou escrever."
    rm -f "$BKP"
    return 1
  fi
  _tam=$(wc -c < "$BKP" | tr -dc '0-9')
  if [ "$_tam" != "$PP_TAM" ]; then
    LOG "[ERRO] backup com $_tam bytes (esperado $PP_TAM) - NAO vou escrever."
    rm -f "$BKP"
    return 1
  fi
  BKP_MD5=$(md5_de "$BKP")
  if [ "${#BKP_MD5}" != "32" ]; then
    LOG "[ERRO] nao consegui o md5 do backup - NAO vou escrever."
    rm -f "$BKP"
    return 1
  fi
  echo "$BKP_MD5  panelparam-original.img" > "$BKP.md5"
  LOG "[OK] backup do panelparam salvo e conferido com cmp em $BKP"
  _s=$(cor_serial); [ -n "$_s" ] || _s="sem-serial"
  _b="$MP/panelparam-backup-$_s.img"
  if [ -d "$MP" ] && cp "$BKP" "$_b" 2>/dev/null && sync && cmp -s "$_b" "$PP"; then
    md5sum "$_b" > "$_b.md5" 2>/dev/null
    LOG "[OK] copia do backup no pendrive conferida: $_b"
  else
    rm -f "$_b" "$_b.md5" 2>/dev/null
    LOG "[AVISO] nao consegui copiar o backup para o pendrive (o de $WORK vale)."
  fi
  return 0
}

# ---- fim ----------------------------------------------------------------------
limpar_trabalho(){
  # com journal pendente o diretorio de trabalho e o que o gancho usa: fica.
  [ -f "$JOURNAL" ] && return 0
  rm -rf "$WORK"
}
finalizar(){ # tela
  _t="$1"
  if [ "$_t" = "pronto" ] && [ -n "$AVISO" ]; then
    LOG "[AVISO] a fase termica nao ficou efetiva (ver o log): mostrando ERRO em vez de PRONTO."
    _t="erro"
  fi
  mostrar "$_t"
  if [ -n "$MP" ] && [ -d "$MP" ]; then cp "$LOGF" "$MP/newlink_cor.log" 2>/dev/null; fi
  limpar_trabalho
  exit 0
}

# ============================================================================
#  modos
# ============================================================================
modo_restaurar(){
  pegar_lock || { LOG "outra instancia em andamento - nada a fazer aqui."; exit 0; }
  trap soltar_lock EXIT
  if [ ! -e "$WORK" ] && [ ! -L "$WORK" ]; then LOG "sem journal - nada a restaurar."; exit 0; fi
  trabalho_ok || exit 1
  [ -f "$JOURNAL" ] || { LOG "sem journal - nada a restaurar."; exit 0; }
  LOG "journal pendente: um teste de cor foi interrompido; devolvendo o formato original"
  if ! reverter; then
    # sem reboot aqui: com o journal de pe, reiniciar poderia virar laco
    LOG "[ERRO] nao consegui restaurar; o journal fica para a proxima tentativa."
    exit 1
  fi
  rm -rf "$WORK"
  if [ "$VIVO_OK" = "1" ]; then
    LOG "formato original aplicado ao vivo e a particao confere com o backup"
    exit 0
  fi
  # sem lvdsctl, o byte certo so vale no proximo boot: reinicia (plano B por dd).
  # O journal ja foi apagado e conferido, entao o boot seguinte nao reinicia de novo.
  LOG "[AVISO] sem lvdsctl utilizavel: reiniciando para o byte restaurado valer"
  sleep "$ESPERA_REBOOT"
  reboot
  exit 3   # avisa o newlink_update.sh de que um reboot foi pedido
}

modo_teste(){
  MP="$1"
  AVISO="$2"
  COR_MD5="$3"
  # o md5 de si mesmo vem de quem conferiu o kit (newlink_update.sh) e e o que o
  # gancho de boot vai embutir; sem ele ou se nao bater, nada acontece.
  if [ "${#COR_MD5}" != "32" ] || [ "$(md5_de "$0")" != "$COR_MD5" ]; then
    LOG "[ERRO] md5 de cor.sh ausente ou diferente do conferido pelo newlink_update.sh - NAO vou escrever."
    exit 1
  fi
  pegar_lock || { LOG "outra instancia em andamento - saindo."; exit 0; }
  trap soltar_lock EXIT
  trabalho_ok || exit 1
  LOG "==== fase de cor iniciada (mountpoint=$MP) ===="

  if [ -f "$JOURNAL" ]; then
    LOG "journal pendente de uma execucao anterior: restaurando antes de qualquer coisa"
    reverter || { LOG "[ERRO] restauracao falhou - NAO vou iniciar outro teste."; finalizar erro; }
    if [ "$VIVO_OK" != "1" ]; then
      LOG "[AVISO] formato original restaurado na particao, mas sem lvdsctl ao vivo: vale no proximo boot. NAO vou iniciar outro teste."
      finalizar erro
    fi
  fi

  preparar_tela
  mostrar aguarde
  aguardar_autofoco

  # perfil ativo: indice e nome vem do driver, e o nome gravado na particao tem de
  # bater (prova de OFFSET, nao de qual painel esta no motor optico).
  CIDX=$(cor_idx); PNOME=$(cor_pnome)
  case "$CIDX" in ''|*[!0-9]*) CIDX="" ;; *) [ "$CIDX" -le "$PERFIL_MAX" ] || CIDX="" ;; esac
  if [ -z "$CIDX" ] || [ -z "$PNOME" ]; then
    LOG "[ERRO] nao consegui ler o perfil de painel (idx='$CIDX' nome_driver='$PNOME') - NAO vou escrever."
    finalizar erro
  fi
  CNOME=$(cor_nome "$CIDX")
  case "$CNOME" in
    "$PNOME"*) ;;
    *) LOG "[ERRO] offset $(( TABELA_BASE + CIDX * PERFIL_TAM )) devolveu '$CNOME' mas o driver diz '$PNOME' - offset errado, NAO vou escrever."
       finalizar erro ;;
  esac
  CVAL=$(cor_valor "$CIDX")
  case "$CVAL" in 0|1) ;; *) LOG "[ERRO] lvds_fmt='$CVAL' (esperado 0 ou 1) - NAO vou escrever."; finalizar erro ;; esac
  OFF=$(( TABELA_BASE + CIDX * PERFIL_TAM + LVDS_FMT_OFF ))
  NOVO=$(( 1 - CVAL ))
  LOG "perfil $CIDX '$PNOME': lvds_fmt=$CVAL (0=VESA, 1=JEIDA)"

  if [ "$MODO_AUTO" = "1" ]; then
    decidir_por_camera
    LOG "modo automatico sem decisao (E5 nao implementada): a pessoa decide"
  fi

  # ---- pergunta 1: as metades estao iguais? ----
  mostrar metades-1
  if ! esperar_tecla; then
    LOG "sem tecla em ${TEMPO_TECLA}s: formato mantido ($CVAL), nada foi escrito"
    finalizar pronto
  fi
  LOG "tecla recebida: a pessoa viu as metades DIFERENTES"
  mostrar metades-1   # reabre: a galeria pode ter trocado de imagem ou aberto um menu

  vivo_disponivel || {
    LOG "[ERRO] lvdsctl ou libhitvservice ausente: nao da para testar ao vivo. Nada foi escrito. Use o wizard do PC (pfl7560-lcd-color.sh wizard)."
    finalizar erro
  }
  preparar_backup || finalizar erro
  jornal_gravar "$CIDX" "$OFF" "$CVAL" "$BKP_MD5" || { LOG "[ERRO] nao consegui gravar o journal - NAO vou escrever."; finalizar erro; }
  instalar_gancho

  LOG "trocando lvds_fmt $CVAL -> $NOVO ao vivo (journal guarda o original)"
  aplicar_vivo "$NOVO"
  if [ "$(cor_valor "$CIDX")" != "$NOVO" ]; then
    LOG "[ERRO] depois do lvdsctl o byte lido e '$(cor_valor "$CIDX")', nao $NOVO - revertendo."
    reverter || LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
    finalizar erro
  fi

  # ---- pergunta 2: agora estao iguais? so mantem com a SEGUNDA tecla ----
  sleep "$TEMPO_ASSENTAR"
  mostrar metades-2
  sleep "$TEMPO_ASSENTAR"
  if esperar_tecla; then
    if [ "$(cor_valor "$CIDX")" = "$NOVO" ] && particao_so_difere_no_fmt "$OFF"; then
      LOG "[OK] segunda tecla: lvds_fmt=$NOVO mantido, relido e a particao confere (so o byte 0x5c mudou)"
      rm -f "$JOURNAL"
      remover_gancho
      finalizar pronto
    fi
    LOG "[ERRO] a releitura nao confirmou (byte ou perfil diferente do esperado) - revertendo."
  else
    LOG "sem segunda tecla em ${TEMPO_TECLA}s: revertendo para lvds_fmt=$CVAL"
  fi
  if reverter; then
    LOG "[OK] revertido: lvds_fmt=$CVAL"
    [ "$VIVO_OK" = "1" ] || LOG "[AVISO] o lvdsctl nao confirmou a volta ao vivo: o formato original vale a partir do proximo boot."
    finalizar pronto
  fi
  LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
  finalizar erro
}

case "$1" in
  --restaurar) modo_restaurar ;;
  --tela) trabalho_ok || exit 1; preparar_tela; mostrar "$2"; exit 0 ;;
  *) modo_teste "$1" "$2" "$3" ;;
esac
