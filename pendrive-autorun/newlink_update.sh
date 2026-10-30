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
#  uma copia em /data/local/tmp, pelo cor.sh.
#
#  Coloque na RAIZ do pendrive (FAT32) tudo o que esta na pasta pendrive-autorun:
#      newlink_update.sh  cor.sh  lvdsctl  ZYCustom.ini  kit/*.png
#  Mesmo pendrive para qualquer PFL7560: sem serial, sem arquivo para editar.
#
#  IDEMPOTENTE:
#   - TERMICO: o estado-alvo e o md5 do ZYCustom.ini que o firmware le. Troca
#     (escrita atomica) so se o md5 atual for o de fabrica ou o da versao
#     anterior nossa; md5 desconhecido = RECUSA. 2a execucao: nada e escrito.
#   - COR: o cor.sh pergunta olhando a tela e so grava com DUAS teclas; sem
#     tecla nada muda. 2a execucao: nada e escrito e nada reinicia.
#   - Reinicia UMA vez, e so quando a fase termica mudou algo.
#
#  SEGURANCA: o md5 de CADA arquivo do kit e conferido contra a lista embutida
#  abaixo ANTES de qualquer escrita. Divergiu ou faltou = aborta. Este script
#  NUNCA chama hidebug nem gtt (doc 37). Limite honesto: um newlink_update.sh
#  adulterado roda como root e nao ha defesa contra ele.
# ============================================================================

# ---- ganchos de teste -------------------------------------------------------
# Em producao PFL_ROOT nao existe e R fica vazio. O harness (tests/) o define
# para apontar o script para uma arvore de mentira.
R="${PFL_ROOT:-}"
MP="$R/mnt/media_rw/$1"
INI="$R/vendor/etc/ZYCustom.ini"
BP="$R/vendor/build.prop"
RC="$R/vendor/etc/init/hw/init.bigfish.rc"
ATV_INI_DIR="$R/atv/ini"
WORK="$R/data/local/tmp/pfl7560-kit"
JOURNAL="$WORK/journal"
ESPERA_REBOOT=8
# gancho de teste: o harness (tests/) zera a espera; em producao nao existe
[ -n "${PFL_RAPIDO:-}" ] && ESPERA_REBOOT=0

# md5 do ZYCustom.ini: o corrigido (alvo), o de fabrica V1.0.0.9 e o da versao
# anterior nossa (artifacts/ZYCustom_390.PREV-211927.ini). Qualquer outro =
# desconhecido = o kit recusa em vez de sobrescrever um mapa que nao conhece.
INI_MD5_OK="252ab7a72a007a8b79b3fc86bd5c0d19"
INI_MD5_FABRICA="29d8ba36149413e899563029df078f6d"
INI_MD5_ANTERIOR="bbf82dd17d4523b7df8a86bec0e850ce"

# md5 de CADA arquivo do kit, relativo a raiz do pendrive. Gerado por
# tests/atualizar-md5-kit.sh (o harness confere que esta em dia). NAO editar a mao.
# KIT_LISTA_INICIO
KIT_LISTA="252ab7a72a007a8b79b3fc86bd5c0d19  ZYCustom.ini
a9387fbd01b496522b7223f67cc16a92  cor.sh
178d812872cb9306c0ae6faeed07184a  lvdsctl
acaaefb249632298e6af03c73dbc1c8d  kit/aguarde.png
1afd05f32600385e0587acf062262988  kit/erro.png
a21d35e144a6f18c2af7f69c6a52bdef  kit/metades-1.png
d631a0d5929746c4cfe2e797cb1eaa3f  kit/metades-2.png
7cd6dca3430ab476de9bb4c30b3dd4b5  kit/pronto.png
ab1ca6ffb16e52c7fed90f6db418965b  kit/reiniciando.png
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

# ---- recuperacao: journal de um teste de cor interrompido --------------------
# Roda ANTES de qualquer outra coisa. Usa a copia do cor.sh que ficou em /data
# (a que o proprio journal usa), reconferida contra a lista embutida.
if [ -f "$JOURNAL" ]; then
  LOG "journal de cor pendente: um teste anterior foi interrompido; restaurando o formato original antes de tudo"
  if [ -f "$WORK/cor.sh" ] && [ "$(md5sum "$WORK/cor.sh" 2>/dev/null | cut -d' ' -f1)" = "$(kit_md5_esperado cor.sh)" ]; then
    sh "$WORK/cor.sh" --restaurar
    if [ "$?" = "3" ]; then
      LOG "restauracao pediu reboot; encerrando por aqui."
      exit 0
    fi
  else
    LOG "[AVISO] cor.sh de recuperacao ausente ou com md5 diferente em $WORK; o gancho de boot ou o proximo teste tenta."
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

# copia o kit para /data/local/tmp (o cor.sh roda de la, destacado) e reconfere
# a copia. Nao apaga o journal: so o diretorio kit/ e recriado.
rm -rf "$WORK/kit"
if ! { mkdir -p "$WORK/kit" && cp "$MP/cor.sh" "$MP/lvdsctl" "$WORK/" && cp "$MP"/kit/*.png "$WORK/kit/" \
       && chmod 755 "$WORK/cor.sh" "$WORK/lvdsctl"; }; then
  LOG "[ERRO] nao consegui copiar o kit para $WORK - abortando (nada de /vendor foi alterado)."
  exit 1
fi
# shellcheck disable=SC2046
if ! kit_conferir "$WORK" $(kit_nomes | grep -v '^ZYCustom.ini$'); then
  LOG "[ERRO] a copia do kit em $WORK nao confere - abortando (nada de /vendor foi alterado)."
  exit 1
fi

# ---- estados-alvo (idempotencia) ---------------------------------------------
# termico: o ini em uso tem de ser IDENTICO ao corrigido (md5). Um .ini anterior
# a escada tem o mux mas nao a escada e antes passava como aplicado.
ini_md5(){ md5sum "$INI" 2>/dev/null | cut -d' ' -f1; }
term_ok(){ [ "$(ini_md5)" = "$INI_MD5_OK" ]; }
term_aplicavel(){
  _m=$(ini_md5)
  [ "$_m" = "$INI_MD5_FABRICA" ] || [ "$_m" = "$INI_MD5_ANTERIOR" ]
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
elif term_aplicavel; then
  TERM_ACAO=1
else
  LOG "[ERRO] termico: md5 do ZYCustom.ini em uso ('$(ini_md5)') nao e o de fabrica ($INI_MD5_FABRICA) nem o de versao anterior nossa - NAO vou sobrescrever (firmware diferente de V1.0.0.9?)."
  FAIL=$((FAIL+1))
  AVISO=1
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

# ---- FIX 1: termico (copia a config agressiva) ----
if [ "$TERM_ACAO" = "1" ]; then
  # salva o stock UMA vez, antes de sobrescrever, e so se o atual for o de fabrica
  if [ ! -f "$INI.STOCK" ] && [ "$(ini_md5)" = "$INI_MD5_FABRICA" ]; then
    cp "$INI" "$INI.STOCK" || LOG "[AVISO] nao consegui salvar $INI.STOCK"
  fi
  # escrita atomica: .new + validacao por md5 + mv + releitura por md5
  if cp "$MP/ZYCustom.ini" "$INI.new" && chmod 644 "$INI.new" \
     && [ "$(md5sum "$INI.new" 2>/dev/null | cut -d' ' -f1)" = "$INI_MD5_OK" ]; then
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
  # a fase de cor roda no boot seguinte, com o pendrive ainda plugado
  sh "$WORK/cor.sh" --tela reiniciando
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
if [ "$AVISO" = "1" ]; then AVISO_ARG="termica-falhou"; else AVISO_ARG=""; fi
LOG "lancando a fase de cor (cor.sh) destacada; log em $WORK/cor.log e, no fim, newlink_cor.log no pendrive"
if command -v setsid >/dev/null 2>&1; then
  setsid sh "$WORK/cor.sh" "$MP" "$AVISO_ARG" >>"$WORK/cor.log" 2>&1 </dev/null &
else
  nohup sh "$WORK/cor.sh" "$MP" "$AVISO_ARG" >>"$WORK/cor.log" 2>&1 </dev/null &
fi
exit 0
