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
#  kit e de copia-los para /data/local/tmp/pfl7560-kit. Este script roda
#  DESTACADO do exec do init (a pergunta dura ate ~90 s) e nunca e executado
#  direto do pendrive.
#
#    cor.sh <mountpoint> [termica-falhou]   teste de cor (pergunta a pessoa)
#    cor.sh --restaurar                     devolve o formato original (journal)
#    cor.sh --tela <nome>                   mostra kit/<nome>.png e sai
#
#  O QUE FAZ (idempotente, sem serial, sem arquivo para editar):
#   1. Projeta as DUAS METADES de cinza (63|64 e 127|128). Formato certo = metades
#      iguais; formato errado = uma bem mais clara (rotacao de 2 bits, doc 41 s4).
#   2. Sem tecla em 30 s: NADA e escrito. Esta e a saida do aparelho de fabrica.
#   3. Com uma tecla: backup do panelparam (conferido com cmp), journal em /data,
#      troca o formato AO VIVO (lvdsctl fmt) e projeta de novo.
#   4. So MANTEM com uma SEGUNDA tecla. Sem ela, REVERTE e confere relendo o byte
#      0x5c e o perfil inteiro contra o backup. Nao precisa de confirmacao.
#   5. Queda de energia no meio: o journal restaura no boot seguinte (pelo
#      newlink_update.sh com o pendrive, ou pelo gancho de boot de fabrica).
#
#  Toca SO no byte lvdsctl_fmt (0x5c) do perfil ativo da panelparam; nunca em
#  swap, bit ou map. NUNCA chama hidebug nem gtt (doc 37).
# ============================================================================

# ---- ganchos de teste -------------------------------------------------------
# Em producao NENHUMA destas variaveis existe. O harness (tests/) as define para
# apontar este script para uma arvore de mentira e para um lvdsctl de mentira.
R="${PFL_ROOT:-}"
PP="$R/dev/block/by-name/panelparam"
PROC_PANEL="$R/proc/msp/panel"
WORK="$R/data/local/tmp/pfl7560-kit"
NLSU="$R/data/local/nlsu"
HOOK="$NLSU/update_after_boot.sh"
LOCK="$R/dev/pfl7560-kit.lock"
LVDSCTL="${PFL_LVDSCTL:-$WORK/lvdsctl}"
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
# gancho de teste: o harness (tests/) zera as esperas; em producao nao existe
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
esperar_tecla(){
  timeout "$TEMPO_TECLA" getevent -ql 2>/dev/null | grep -q 'EV_KEY.*DOWN'
}

# ---- lvdsctl (troca AO VIVO) -------------------------------------------------
vivo_disponivel(){ [ -x "$LVDSCTL" ] && [ -f "$LIBHITV" ]; }
# O codigo de saida do lvdsctl nao e confiavel; quem confirma e a releitura do
# byte (SetLvdsFormat persiste na hora, doc 40 s1).
aplicar_vivo(){
  LOG "lvdsctl fmt $1"
  LD_LIBRARY_PATH="$LIBS" timeout 30 "$LVDSCTL" fmt "$1" >/dev/null 2>&1
}

# ---- journal -----------------------------------------------------------------
jornal_gravar(){ # idx off fmt_original
  {
    echo "J_IDX=$1"
    echo "J_OFF=$2"
    echo "J_FMT=$3"
  } > "$JOURNAL.new" && sync && mv "$JOURNAL.new" "$JOURNAL" && sync
}
jornal_campo(){ sed -n "s/^$1=\\([0-9]*\\)\$/\\1/p" "$JOURNAL" 2>/dev/null | head -1; }
# carrega e valida o journal em J_IDX/J_OFF/J_FMT; falha fechada
jornal_ler(){
  J_IDX=$(jornal_campo J_IDX); J_OFF=$(jornal_campo J_OFF); J_FMT=$(jornal_campo J_FMT)
  case "$J_IDX$J_OFF$J_FMT" in ''|*[!0-9]*) return 1 ;; esac
  [ -n "$J_IDX" ] && [ -n "$J_OFF" ] && [ -n "$J_FMT" ] || return 1
  [ "$J_IDX" -le "$PERFIL_MAX" ] || return 1
  [ "$J_FMT" = "0" ] || [ "$J_FMT" = "1" ] || return 1
  [ "$J_OFF" = "$(( TABELA_BASE + J_IDX * PERFIL_TAM + LVDS_FMT_OFF ))" ]
}

# ---- comparacao do perfil com o backup ---------------------------------------
perfil_para(){ # arquivo idx destino
  dd if="$1" bs=1 skip=$(( TABELA_BASE + $2 * PERFIL_TAM )) count="$PERFIL_TAM" of="$3" 2>/dev/null
}
perfil_comparar(){ # idx -> deixa perfil-agora e perfil-bkp em $WORK
  perfil_para "$PP" "$1" "$WORK/perfil-agora" && perfil_para "$BKP" "$1" "$WORK/perfil-bkp"
}
perfil_igual_backup(){ perfil_comparar "$1" && cmp -s "$WORK/perfil-agora" "$WORK/perfil-bkp"; }
# 0 se o perfil atual so difere do backup (no maximo) no byte lvds_fmt
perfil_so_difere_no_fmt(){
  perfil_comparar "$1" || return 1
  _n=$(cmp -l "$WORK/perfil-agora" "$WORK/perfil-bkp" 2>/dev/null | wc -l | tr -dc '0-9')
  [ -n "$_n" ] && [ "$_n" -le 1 ] || return 1
  [ "$_n" = "0" ] && return 0
  # shellcheck disable=SC2046
  set -- $(cmp -l "$WORK/perfil-agora" "$WORK/perfil-bkp" 2>/dev/null | head -1)
  [ "$1" = "$(( LVDS_FMT_OFF + 1 ))" ]
}

# ---- restauracao -------------------------------------------------------------
# Devolve o byte original a partir do journal e CONFERE: o byte relido e o perfil
# inteiro contra o backup. Se houver qualquer outra diferenca (setor corrompido),
# restaura os 768 bytes do perfil a partir do backup e confere de novo.
restaurar_formato(){
  jornal_ler || { LOG "[ERRO] journal ilegivel ou incoerente - NAO vou escrever."; return 1; }
  [ -f "$BKP" ] || { LOG "[ERRO] backup $BKP ausente - NAO vou escrever."; return 1; }
  _tam=$(wc -c < "$BKP" | tr -dc '0-9')
  [ "$_tam" = "$PP_TAM" ] || { LOG "[ERRO] backup com $_tam bytes (esperado $PP_TAM) - NAO vou escrever."; return 1; }
  LOG "restaurando lvds_fmt=$J_FMT no perfil $J_IDX (offset $J_OFF)"
  gravar_fmt "$J_OFF" "$J_FMT" || { LOG "[ERRO] dd de restauracao falhou."; return 1; }
  sync
  if [ "$(cor_valor "$J_IDX")" = "$J_FMT" ] && perfil_igual_backup "$J_IDX"; then
    LOG "[OK] formato restaurado: byte e perfil conferem com o backup"
    return 0
  fi
  LOG "[AVISO] o perfil difere do backup alem do byte - restaurando os $PERFIL_TAM bytes do perfil"
  _a=$(( TABELA_BASE + J_IDX * PERFIL_TAM ))
  dd if="$BKP" of="$PP" bs=1 skip="$_a" seek="$_a" count="$PERFIL_TAM" conv=notrunc 2>/dev/null \
    || { LOG "[ERRO] restauracao do perfil falhou."; return 1; }
  sync
  if [ "$(cor_valor "$J_IDX")" = "$J_FMT" ] && perfil_igual_backup "$J_IDX"; then
    LOG "[OK] perfil restaurado do backup e conferido"
    return 0
  fi
  LOG "[ERRO] depois de restaurar o perfil, a releitura NAO confere. Restaure o backup com ./pfl7560-lcd-color.sh restore."
  return 1
}

# ---- gancho de recuperacao ---------------------------------------------------
# PREMISSA NAO CONFIRMADA (E1-c): /data/local/nlsu nao existe neste aparelho. O
# init de fabrica executa /data/local/nlsu/update_after_boot.sh como root no
# sys.boot_completed (init.bigfish.rc:371-373). So criamos o gancho se NAO existir
# um; se existir um que nao e nosso, nao tocamos e avisamos. O gancho se apaga
# quando o journal some.
instalar_gancho(){
  if [ -e "$HOOK" ]; then
    grep -q "pfl7560-kit-gancho" "$HOOK" 2>/dev/null && return 0
    LOG "[AVISO] ja existe $HOOK e nao e nosso: gancho de recuperacao NAO instalado (a restauracao depende do pendrive no proximo boot)."
    return 0
  fi
  if mkdir -p "$NLSU" 2>/dev/null && cat > "$HOOK.new" <<FIM
#!/vendor/bin/sh
# pfl7560-kit-gancho: criado pelo kit de pendrive. Restaura o formato LVDS se um
# teste de cor foi interrompido e se apaga quando o journal some.
if [ -f "$JOURNAL" ] && [ -f "$WORK/cor.sh" ]; then
  sh "$WORK/cor.sh" --restaurar
fi
[ -f "$JOURNAL" ] || rm -f "\$0"
FIM
  then
    chmod 755 "$HOOK.new" && mv "$HOOK.new" "$HOOK" && sync && LOG "gancho de recuperacao instalado em $HOOK" && return 0
  fi
  rm -f "$HOOK.new" 2>/dev/null
  LOG "[AVISO] nao consegui instalar o gancho de recuperacao em $HOOK."
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
  if ! { dd if="$PP" of="$BKP" bs=4096 2>/dev/null && sync && cmp -s "$BKP" "$PP"; }; then
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
  md5sum "$BKP" > "$BKP.md5" 2>/dev/null
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
  [ -f "$JOURNAL" ] || { LOG "sem journal - nada a restaurar."; exit 0; }
  LOG "journal pendente: um teste de cor foi interrompido; devolvendo o formato original"
  if ! restaurar_formato; then
    LOG "[ERRO] nao consegui restaurar; o journal fica para a proxima tentativa."
    exit 1
  fi
  _fmt="$J_FMT"
  rm -f "$JOURNAL"
  remover_gancho
  if vivo_disponivel && aplicar_vivo "$_fmt"; then
    LOG "formato original aplicado ao vivo"
    rm -rf "$WORK"
  else
    # sem lvdsctl, o byte certo so vale no proximo boot: reinicia (plano B por dd)
    LOG "[AVISO] sem lvdsctl utilizavel: reiniciando para o byte restaurado valer"
    rm -rf "$WORK"
    sleep "$ESPERA_REBOOT"
    reboot
    exit 3   # avisa o newlink_update.sh de que um reboot foi pedido
  fi
  exit 0
}

modo_teste(){
  MP="$1"
  AVISO="$2"
  pegar_lock || { LOG "outra instancia em andamento - saindo."; exit 0; }
  trap soltar_lock EXIT
  LOG "==== fase de cor iniciada (mountpoint=$MP) ===="

  if [ -f "$JOURNAL" ]; then
    LOG "journal pendente de uma execucao anterior: restaurando antes de qualquer coisa"
    restaurar_formato || { LOG "[ERRO] restauracao falhou - NAO vou iniciar outro teste."; finalizar erro; }
    rm -f "$JOURNAL"
    remover_gancho
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
  jornal_gravar "$CIDX" "$OFF" "$CVAL" || { LOG "[ERRO] nao consegui gravar o journal - NAO vou escrever."; finalizar erro; }
  instalar_gancho

  LOG "trocando lvds_fmt $CVAL -> $NOVO ao vivo (journal guarda o original)"
  aplicar_vivo "$NOVO"
  if [ "$(cor_valor "$CIDX")" != "$NOVO" ]; then
    LOG "[ERRO] depois do lvdsctl o byte lido e '$(cor_valor "$CIDX")', nao $NOVO - revertendo."
    if restaurar_formato; then
      rm -f "$JOURNAL"; remover_gancho; aplicar_vivo "$CVAL"
    fi
    finalizar erro
  fi

  # ---- pergunta 2: agora estao iguais? so mantem com a SEGUNDA tecla ----
  sleep "$TEMPO_ASSENTAR"
  mostrar metades-2
  sleep "$TEMPO_ASSENTAR"
  if esperar_tecla; then
    if [ "$(cor_valor "$CIDX")" = "$NOVO" ] && perfil_so_difere_no_fmt "$CIDX"; then
      LOG "[OK] segunda tecla: lvds_fmt=$NOVO mantido, relido e perfil confere (so o byte 0x5c mudou)"
      rm -f "$JOURNAL"
      remover_gancho
      finalizar pronto
    fi
    LOG "[ERRO] a releitura nao confirmou (byte ou perfil diferente do esperado) - revertendo."
  else
    LOG "sem segunda tecla em ${TEMPO_TECLA}s: revertendo para lvds_fmt=$CVAL"
  fi
  if restaurar_formato; then
    rm -f "$JOURNAL"
    remover_gancho
    aplicar_vivo "$CVAL"
    LOG "[OK] revertido: lvds_fmt=$CVAL"
    finalizar pronto
  fi
  LOG "[ERRO] a reversao nao conferiu; journal mantido: o proximo boot tenta de novo."
  finalizar erro
}

case "$1" in
  --restaurar) modo_restaurar ;;
  --tela) preparar_tela; mostrar "$2"; exit 0 ;;
  *) modo_teste "$1" "$2" ;;
esac
