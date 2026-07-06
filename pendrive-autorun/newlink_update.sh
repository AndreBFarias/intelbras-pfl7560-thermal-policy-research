#!/vendor/bin/sh
# ============================================================================
#  PFL7560 - AUTOINSTALADOR via pendrive (termico + wi-fi + xiri)
#
#  Como funciona: o proprio firmware roda /vendor/bin/nl_usb_update.sh a cada
#  boot (gatilho: sys.boot_completed=1). Esse script varre os pendrives e, se
#  achar um "newlink_update.sh" na raiz, EXECUTA ele como ROOT. Ou seja: basta
#  este arquivo + o ZYCustom.ini estarem na raiz do pendrive, plugar e ligar.
#
#  IDEMPOTENTE: se a correcao ja estiver aplicada, sai sem fazer nada (nao
#  entra em loop de reboot). So reinicia UMA vez, quando de fato aplica.
#
#  Coloque na RAIZ do pendrive (FAT32):  newlink_update.sh  +  ZYCustom.ini
# ============================================================================
MP="/mnt/media_rw/$1"
LOG(){ echo "[PFL7560-fix] $*"; }
LOG "==== autorun iniciado (mountpoint=$1) ===="

# trava de seguranca: so age no PFL7560
MODEL=$(getprop ro.product.model 2>/dev/null)
if [ "$MODEL" != "PFL7560" ]; then
  LOG "modelo='$MODEL' nao e PFL7560 - abortado por seguranca."
  exit 0
fi

# idempotencia: 2o sensor ativo (HW_VIRTUAL_CHANNEL = 1) e a marca da nossa build
if grep -q "HW_VIRTUAL_CHANNEL = 1" /vendor/etc/ZYCustom.ini 2>/dev/null; then
  LOG "correcao JA aplicada neste projetor. Nada a fazer. (pode remover o pendrive)"
  exit 0
fi

LOG "correcao ausente -> aplicando no /vendor ..."
mount -o rw,remount /vendor
CHG=0

# ---- FIX 1: termico (copia a config agressiva) ----
if [ -f "$MP/ZYCustom.ini" ]; then
  if cp "$MP/ZYCustom.ini" /vendor/etc/ZYCustom.ini && chmod 644 /vendor/etc/ZYCustom.ini; then
    LOG "[OK] termico: ZYCustom.ini gravado (fans 100%, brilho 100%, 2o sensor, shutdown 75C)"
    CHG=1
  else
    LOG "[ERRO] falha ao gravar ZYCustom.ini"
  fi
else
  LOG "[ERRO] ZYCustom.ini NAO esta na raiz do pendrive - abortando."
  exit 1
fi

# ---- FIX 2: wi-fi reconecta sozinho apos boot ----
if grep -q "wifi_disconnect_on_boot=1" /vendor/build.prop 2>/dev/null; then
  if sed -i "s/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/" /vendor/build.prop; then
    LOG "[OK] wi-fi: wifi_disconnect_on_boot=0"
    CHG=1
  fi
else
  LOG "wi-fi ja estava ok (=0 ou linha ausente)"
fi

# ---- FIX 3: silencia o spam do xiriservice ----
RC=/vendor/etc/init/hw/init.bigfish.rc
if grep -A1 "service xiriservice" "$RC" 2>/dev/null | grep -q "disabled"; then
  LOG "xiri ja estava desabilitado"
else
  if sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$RC"; then
    LOG "[OK] xiri: xiriservice desabilitado (fim do spam de log)"
    CHG=1
  fi
fi

sync
if [ "$CHG" = "1" ]; then
  LOG "==== CORRECAO APLICADA COM SUCESSO! reiniciando em 8s para ativar ===="
  sleep 8
  reboot
else
  LOG "==== nada foi alterado (arquivos ausentes?) - verifique o pendrive ===="
fi
