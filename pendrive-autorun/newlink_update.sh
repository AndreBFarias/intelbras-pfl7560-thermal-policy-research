#!/vendor/bin/sh
# ---------------------------------------------------------------------------
#  CONVENCAO DE CHARSET (NAO MEXER): este arquivo e ASCII PURO de proposito.
#  Roda no shell do projetor (/vendor/bin/sh, BusyBox/Android, locale incerto)
#  e vive num pendrive FAT32; acento pt-BR pode virar mojibake ou quebrar o
#  parser do shell. NAO acentuar este arquivo. Convencao fixada na sprint 25
#  (auditoria de acentuacao) - decisao registrada para o proximo auditor.
# ---------------------------------------------------------------------------
# ============================================================================
#  PFL7560 - AUTOINSTALADOR via pendrive (termico + wi-fi + xiri)
#
#  Como funciona: o proprio firmware roda /vendor/bin/nl_usb_update.sh a cada
#  boot (gatilho: sys.boot_completed=1). Esse script varre os pendrives e, se
#  achar um "newlink_update.sh" na raiz, EXECUTA ele como ROOT. Ou seja: basta
#  este arquivo + o ZYCustom.ini estarem na raiz do pendrive, plugar e ligar.
#
#  IDEMPOTENTE: checa os TRES estados-alvo (termico, wi-fi, xiri). Se os tres
#  ja estiverem aplicados, sai sem fazer nada (nao entra em loop de reboot).
#  Reaplica so o que faltar, e reinicia UMA vez, apenas quando algo mudou.
#
#  Coloque na RAIZ do pendrive (FAT32):  newlink_update.sh  +  ZYCustom.ini
# ============================================================================
MP="/mnt/media_rw/$1"
INI=/vendor/etc/ZYCustom.ini
BP=/vendor/build.prop
RC=/vendor/etc/init/hw/init.bigfish.rc
INI_MD5_OK="252ab7a72a007a8b79b3fc86bd5c0d19"   # md5 esperado do ZYCustom.ini corrigido

# ---------------------------------------------------------------------------
#  FIX 4 (OPCIONAL) - cor do painel trocado, VESA -> JEIDA.
#
#  DESLIGADO POR PADRAO, e com DUAS travas. So roda se existir na raiz do
#  pendrive um arquivo chamado EU-TROQUEI-O-PAINEL-PARA-0600.txt E se o SERIAL
#  deste aparelho (ro.serialno) estiver escrito dentro dele. Sem as duas coisas,
#  este bloco e ignorado e o autorun se comporta exatamente como antes.
#
#  POR QUE DUAS TRAVAS: forcar JEIDA num PFL7560 com o painel DE FABRICA
#  (RX058B-4300) QUEBRA a cor dos meios-tons dele. So o arquivo nao basta: este
#  pendrive e feito para ser emprestado e corrigir OUTROS PFL7560, e um arquivo
#  vazio sobrevive a emprestimo, copia de pasta e clonagem de midia. Amarrando
#  ao serial, a autorizacao vale para UM aparelho e nao viaja junto.
#  O software NAO consegue saber qual painel esta fisicamente no motor optico:
#  depois da troca, o driver continua reportando RX058B_4300. Quem afirma a
#  troca e o dono, escrevendo o serial no arquivo.
#
#  O QUE ELE FAZ: grava 1 byte (lvds_fmt) no perfil de painel ATIVO dentro da
#  particao panelparam. Isso persiste no boot nativamente, sem servico extra e
#  sem depender do nl_lvdsctl (que nao existe num aparelho recem-reflashado).
#  Layout: tabela comeca em 168; cada perfil tem 768 bytes; lvds_fmt fica em
#  0x5c (92) dentro do perfil. 0 = VESA, 1 = JEIDA.
# ---------------------------------------------------------------------------
SENTINELA="EU-TROQUEI-O-PAINEL-PARA-0600.txt"
PP=/dev/block/by-name/panelparam
PERFIL_TAM=768
TABELA_BASE=168
LVDS_FMT_OFF=92
PERFIL_MAX=82

LOG(){ echo "[PFL7560-fix] $*"; }
LOG "==== autorun iniciado (mountpoint=$1) ===="

# indice e nome do perfil ativo, lidos de /proc/msp/panel - a mesma fonte que o
# pfl7560-saude.sh ja usa, e a unica com captura versionada no repo
# (evidencias/diagnostico-2026-08-17/proc-panel.txt). O "+0" do awk evita a
# armadilha de o shell interpretar um valor com zero a esquerda como octal.
cor_idx(){ awk -F'[:|]' '/cut_idx/{v=$2; gsub(/[^0-9]/,"",v); if(v!=""){print v+0; exit}}' /proc/msp/panel 2>/dev/null; }
cor_pnome(){ awk -F'[:|]' '/panel_name/{v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); if(v!=""){print v; exit}}' /proc/msp/panel 2>/dev/null; }

# nome do perfil gravado NA PARTICAO, no indice dado.
# O campo tem tamanho fixo e o nome termina em NUL; o resto do struct sao bytes
# binarios. Trocar NUL por quebra de linha e pegar a 1a linha corta exatamente
# no fim do nome - com 'tr -d' os bytes seguintes vinham colados (visto na
# bancada com imagem sintetica).
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

# A sentinela so vale para o aparelho cujo SERIAL esta escrito dentro dela.
# Sem isso, o pendrive emprestado, copiado ou clonado quebraria a cor de um
# PFL7560 com painel de fabrica (invariante 10) - e o proprio LEIA-ME preve
# emprestar o pendrive para corrigir OUTROS aparelhos. Serial ilegivel =
# correcao de cor desligada (falha fechada).
cor_serial(){ getprop ro.serialno 2>/dev/null | tr -dc 'A-Za-z0-9'; }
cor_habilitada(){
  _s=$(cor_serial); [ -n "$_s" ] || return 1
  [ -f "$MP/$SENTINELA" ] || return 1
  grep -q "$_s" "$MP/$SENTINELA" 2>/dev/null
}

# ATENCAO: o nome do perfil NAO distingue painel -4300 de -0600. Depois da troca
# fisica o driver continua reportando RX058B_4300_... Este gate prova que o
# OFFSET esta certo (o nome lido na particao bate com o que o driver reporta),
# nunca QUE PAINEL esta no motor optico. A unica trava contra estragar a cor de
# um aparelho de fabrica e a sentinela amarrada ao serial.
cor_pendente(){
  cor_habilitada || return 1
  _i=$(cor_idx); [ -n "$_i" ] || return 1
  case "$_i" in ''|*[!0-9]*) return 1 ;; esac
  [ "$_i" -le "$PERFIL_MAX" ] || return 1
  _p=$(cor_pnome); [ -n "$_p" ] || return 1
  case "$(cor_nome "$_i")" in "$_p"*) ;; *) return 1 ;; esac
  _v=$(cor_valor "$_i"); [ -n "$_v" ] || return 1
  [ "$_v" != "1" ]
}

# trava de seguranca: so age no PFL7560
MODEL=$(getprop ro.product.model 2>/dev/null)
if [ "$MODEL" != "PFL7560" ]; then
  LOG "modelo='$MODEL' nao e PFL7560 - abortado por seguranca."
  exit 0
fi

# estados-alvo (idempotencia): considera aplicado so quando os TRES estao ok
term_ok(){ grep -q "HW_VIRTUAL_CHANNEL = 1" "$INI" 2>/dev/null; }
wifi_ok(){ [ -f "$BP" ] && grep -q "wifi_disconnect_on_boot=0" "$BP" 2>/dev/null; }
xiri_ok(){ grep -A1 "service xiriservice" "$RC" 2>/dev/null | grep -q "disabled"; }

# A cor entra na conta do early-exit, senao o caso "termico ok, so a cor errada"
# sairia aqui sem fazer nada. Sem a sentinela, cor_pendente e sempre falso e o
# comportamento fica identico ao de antes.
if term_ok && wifi_ok && xiri_ok && ! cor_pendente; then
  LOG "correcao JA aplicada (termico + wi-fi + xiri). Nada a fazer. (pode remover o pendrive)"
  exit 0
fi

# validacoes ANTES de remontar /vendor rw (nao deixar a particao gravavel ao abortar)
if [ ! -d "$MP" ]; then
  LOG "[ERRO] mountpoint '$MP' nao existe - abortando (nada foi alterado)."
  exit 1
fi

# O /vendor so e aberto rw se algum dos 3 fixes DE /vendor estiver pendente.
# O FIX 4 (cor) escreve na particao panelparam, fora de qualquer superbloco
# montado: nao precisa de /vendor gravavel e nao deve morrer junto com ele.
# Sem isso, um aparelho recem-reflashado onde o remount falha ficaria com a cor
# inalcancavel, e uma cor cronicamente pendente remontaria /vendor rw em todo
# boot, para sempre.
VENDOR_RW=0
if ! term_ok || ! wifi_ok || ! xiri_ok; then
  if [ ! -f "$MP/ZYCustom.ini" ]; then
    LOG "[ERRO] ZYCustom.ini NAO esta na raiz do pendrive - abortando (nada foi alterado)."
    exit 1
  fi
  LOG "correcao ausente/incompleta -> aplicando o que faltar no /vendor ..."
  if ! mount -o rw,remount /vendor; then
    LOG "[ERRO] nao consegui remontar /vendor rw (dm-verity/particao ocupada?) - retentar no proximo boot."
    exit 1
  fi
  VENDOR_RW=1
fi
CHG=0
FAIL=0
FAIL_COR=0

# ---- FIX 1: termico (copia a config agressiva) ----
if term_ok; then
  LOG "termico ja estava ok (HW_VIRTUAL_CHANNEL = 1)"
else
  # valida o md5 do ini do pendrive ANTES de copiar (se md5sum existir).
  # Se md5sum faltar no PATH do boot, SRC_MD5 fica vazio e caimos no guard real: o grep pos-copia abaixo.
  SRC_MD5="$(md5sum "$MP/ZYCustom.ini" 2>/dev/null | awk '{print $1}')"
  if [ -n "$SRC_MD5" ] && [ "$SRC_MD5" != "$INI_MD5_OK" ]; then
    LOG "[ERRO] termico: md5 do ZYCustom.ini do pendrive ('$SRC_MD5') != esperado ($INI_MD5_OK) - NAO copiado."
    FAIL=$((FAIL+1))
  else
    # salva o stock UMA vez, antes de sobrescrever
    if [ ! -f "$INI.STOCK" ]; then
      cp "$INI" "$INI.STOCK" || LOG "[AVISO] nao consegui salvar $INI.STOCK"
    fi
    # escrita atomica: .new + validacao + mv
    if cp "$MP/ZYCustom.ini" "$INI.new" && chmod 644 "$INI.new" && grep -q "HW_VIRTUAL_CHANNEL = 1" "$INI.new" && grep -q "= 66000, 67500, 69000, 70000, 71500, 73000" "$INI.new"; then
      if mv "$INI.new" "$INI"; then
        LOG "[OK] termico: ZYCustom.ini gravado (fans 100% sempre, 2o sensor, escada de brilho 1000->850 entre 66C e 70C, shutdown 75C)"
        CHG=1
      else
        LOG "[ERRO] termico: falha no mv final - original intacto."
        rm -f "$INI.new"
        FAIL=$((FAIL+1))
      fi
    else
      LOG "[ERRO] termico: destino .new nao contem 'HW_VIRTUAL_CHANNEL = 1' - NAO vou reiniciar."
      rm -f "$INI.new"
      FAIL=$((FAIL+1))
    fi
  fi
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

# ---- FIX 4 (OPCIONAL, so com a sentinela do PROPRIO aparelho): cor do painel ----
# Falhas daqui vao para FAIL_COR, NUNCA para FAIL: uma correcao opcional e
# cosmetica nao pode vetar a ativacao da politica termica, que e o fix de
# seguranca. A unica excecao e o caso ambiguo (gravei e a releitura nao
# confirmou), que precisa da atencao do dono antes de reiniciar.
if ! cor_habilitada; then
  if [ -f "$MP/$SENTINELA" ]; then
    _s=$(cor_serial)
    if [ -z "$_s" ]; then
      LOG "cor: nao consegui ler ro.serialno - correcao de cor desligada por seguranca."
    else
      LOG "cor: o arquivo de autorizacao nao cobre ESTE aparelho (serial $_s)."
      LOG "cor: se o painel DESTE aparelho foi trocado pelo -0600, escreva '$_s' dentro dele. Se nao foi, NAO faca isso: quebraria a cor deste aparelho."
    fi
  else
    LOG "cor: correcao opcional de painel nao habilitada neste aparelho (ver LEIA-ME)."
  fi
else
  CIDX=$(cor_idx)
  PNOME=$(cor_pnome)
  CNOME=$(cor_nome "$CIDX")
  CVAL=$(cor_valor "$CIDX")
  OKIDX=0
  case "$CIDX" in ''|*[!0-9]*) ;; *) [ "$CIDX" -le "$PERFIL_MAX" ] && OKIDX=1 ;; esac
  if [ "$OKIDX" != "1" ] || [ -z "$PNOME" ] || [ -z "$CVAL" ]; then
    LOG "[ERRO] cor: nao consegui ler o perfil de painel (idx='$CIDX' nome_driver='$PNOME' val='$CVAL') - NAO vou escrever."
    FAIL_COR=$((FAIL_COR+1)); CIDX=""
  else
    # prova de offset: o nome gravado em TABELA_BASE+idx*768 tem de bater com o
    # nome que o driver reporta agora. Fonte independente; substitui o antigo
    # gate *RX058B*, que casava em cinco perfis diferentes (doc 28).
    case "$CNOME" in
      "$PNOME"*) ;;
      *) LOG "[ERRO] cor: offset $(( TABELA_BASE + CIDX * PERFIL_TAM )) devolveu '$CNOME' mas o driver diz '$PNOME' - offset errado, NAO vou escrever."
         FAIL_COR=$((FAIL_COR+1)); CIDX="" ;;
    esac
  fi
  if [ -n "$CIDX" ]; then
    if [ "$CVAL" = "1" ]; then
      LOG "cor ja estava ok (perfil $CIDX '$PNOME', lvds_fmt=1 JEIDA)"
    else
      OFF=$(( TABELA_BASE + CIDX * PERFIL_TAM + LVDS_FMT_OFF ))
      LOG "cor: perfil $CIDX '$PNOME' esta com lvds_fmt=$CVAL (VESA); corrigindo para 1 (JEIDA) no offset $OFF"
      # invariante 5: backup 8 MiB + md5 ANTES de gravar. O cmp -s valida tamanho
      # E conteudo de uma vez; um backup byte-identico a ESTA particao e, por
      # definicao, um backup valido dela - cobre backup truncado por queda de
      # energia e backup de outro aparelho. Extensao .img porque o arranjo (A)
      # do LEIA-ME promete pendrive de autorun sem nenhum .bin junto.
      BKP="$MP/panelparam-backup-$(cor_serial).img"
      BKPOK=0
      if [ -f "$BKP" ] && cmp -s "$BKP" "$PP"; then
        LOG "cor: backup $BKP confere byte a byte com a particao - reaproveitado"
        BKPOK=1
      elif dd if="$PP" of="$BKP" bs=4096 2>/dev/null && sync && cmp -s "$BKP" "$PP"; then
        md5sum "$BKP" > "$BKP.md5" 2>/dev/null
        LOG "[OK] cor: backup do panelparam salvo e conferido em $BKP"
        BKPOK=1
      else
        LOG "[ERRO] cor: backup do panelparam invalido ou impossivel - NAO vou escrever."
        rm -f "$BKP" "$BKP.md5"
        FAIL_COR=$((FAIL_COR+1))
      fi
      if [ "$BKPOK" = "1" ]; then
        if printf '\1' | dd of="$PP" bs=1 seek="$OFF" count=1 conv=notrunc 2>/dev/null; then
          sync
          # le de volta: so conta como aplicado se o byte realmente virou 1
          CVAL2=$(cor_valor "$CIDX")
          if [ "$CVAL2" = "1" ]; then
            LOG "[OK] cor: lvds_fmt=1 (JEIDA) gravado e conferido - vale no proximo boot"
            CHG=1
          elif [ "$CVAL2" = "$CVAL" ]; then
            LOG "[ERRO] cor: o dd retornou ok mas o byte continua $CVAL - NADA foi gravado, nao ha o que restaurar."
            FAIL_COR=$((FAIL_COR+1))
          else
            LOG "[ERRO] cor: gravei e a releitura devolveu '$CVAL2' - estado AMBIGUO. Restaure $BKP com ./pfl7560-lcd-color.sh restore antes de reiniciar."
            FAIL=$((FAIL+1))
          fi
        else
          LOG "[ERRO] cor: dd de escrita falhou - particao intacta (nada foi gravado)."
          FAIL_COR=$((FAIL_COR+1))
        fi
      fi
    fi
  fi
fi

sync
# fecha o /vendor em TODOS os ramos, inclusive no de reboot - antes ele ficava
# gravavel durante os 8 s de sleep.
if [ "$VENDOR_RW" = "1" ]; then
  mount -o ro,remount /vendor 2>/dev/null
fi
if [ "$FAIL_COR" != "0" ]; then
  LOG "[AVISO] cor: $FAIL_COR falha(s) na correcao OPCIONAL de cor - nada foi gravado no panelparam. Nao bloqueia os fixes termicos."
fi
if [ "$CHG" = "1" ] && [ "$FAIL" = "0" ]; then
  LOG "==== CORRECAO APLICADA COM SUCESSO! reiniciando em 8s para ativar ===="
  sleep 8
  reboot
elif [ "$FAIL" != "0" ]; then
  LOG "==== [PARCIAL] $FAIL fix(es) falharam - reexecute o pendrive (reinicie o projetor). ===="
else
  LOG "==== nada foi alterado (os fixes pendentes ja estavam ok). ===="
fi
