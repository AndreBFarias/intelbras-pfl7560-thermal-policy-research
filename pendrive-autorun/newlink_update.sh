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
LOG(){ echo "[PFL7560-fix] $*"; }
LOG "==== autorun iniciado (mountpoint=$1) ===="

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

if term_ok && wifi_ok && xiri_ok; then
  LOG "correcao JA aplicada (termico + wi-fi + xiri). Nada a fazer. (pode remover o pendrive)"
  exit 0
fi

# validacoes ANTES de remontar /vendor rw (nao deixar a particao gravavel ao abortar)
if [ ! -d "$MP" ]; then
  LOG "[ERRO] mountpoint '$MP' nao existe - abortando (nada foi alterado)."
  exit 1
fi
if [ ! -f "$MP/ZYCustom.ini" ]; then
  LOG "[ERRO] ZYCustom.ini NAO esta na raiz do pendrive - abortando (nada foi alterado)."
  exit 1
fi

LOG "correcao ausente/incompleta -> aplicando o que faltar no /vendor ..."
if ! mount -o rw,remount /vendor; then
  LOG "[ERRO] nao consegui remontar /vendor rw (dm-verity/particao ocupada?) - retentar no proximo boot."
  exit 1
fi
CHG=0
FAIL=0

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

sync
if [ "$CHG" = "1" ] && [ "$FAIL" = "0" ]; then
  LOG "==== CORRECAO APLICADA COM SUCESSO! reiniciando em 8s para ativar ===="
  sleep 8
  reboot
elif [ "$FAIL" != "0" ]; then
  LOG "==== [PARCIAL] $FAIL fix(es) falharam - reexecute o pendrive (reinicie o projetor). ===="
  mount -o ro,remount /vendor 2>/dev/null
else
  LOG "==== nada foi alterado (os fixes pendentes ja estavam ok). ===="
  mount -o ro,remount /vendor 2>/dev/null
fi
