#!/usr/bin/env bash
# tests/test-kit-pendrive.sh - bloco 5 (E3): harness do kit universal de pendrive.
#
# Roda o newlink_update.sh e o cor.sh REAIS (os que vao no pendrive) contra uma
# arvore de mentira (PFL_ROOT) e stubs de getprop/getevent/am/lvdsctl/reboot/
# sleep/mount/setsid em um PATH temporario. dd, cmp, md5sum, od, tr, sed, awk e
# timeout sao os do host. NUNCA fala com o aparelho. Os cenarios rodam sob dash
# (POSIX estrito; o mksh do Android 9 nao esta nesta maquina). O busybox ash so
# entra na checagem de sintaxe (sh -n): ele embute mount/sleep/reboot como
# applets, que passam por cima dos stubs do PATH, entao NAO serve para cenarios.
#
# Bloco 7: o modo automatico (camera) roda com um nl_camcheck de mentira que le o byte
# lvds_fmt da panelparam de mentira e devolve uma escada em ordem (ou embaralhada);
# o nl_camcheck de verdade e provado a parte (tests/test-camcheck.sh).
#
# Bloco 9B: o autorun lanca a SUITE (suite.sh pendrive), que roda o cor.sh no modo suite
# e depois as etapas dela. Aqui a suite roda sem nl_tela (telas estaticas do kit): a
# sequencia de telas fica "aguarde" (abertura da suite), as do cor.sh, "calibracao" (a
# geometria da suite; o nl_camcheck de mentira nao tem o modo geometria) e a final da
# suite ("pronto" ou "erro"). A suite em si e provada em tests/test-suite.sh.
#
# Precisa de: dash, busybox, shellcheck (opcional), pkill, python3 com PIL e numpy.
#
#   bash tests/test-kit-pendrive.sh
# shellcheck disable=SC2034,SC2115
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
# shellcheck disable=SC2034  # usada nas strings do afirma (eval) e nos stubs
APP_VC="$(sed -n 's/^APP_VERSION_CODE="\([0-9]*\)"$/\1/p' "$KIT/newlink_update.sh")"   # versionCode do app no kit
OFF=$(( 168 + 69 * 768 + 92 ))     # byte lvdsctl_fmt do perfil 69 (53252, 0-based; 53253 no cmp -l)
PNOME="RX058B_4300_5010E_1080P_M"
REAL_CMP="$(command -v cmp)"
REAL_MD5SUM="$(command -v md5sum)"

FALHAS=0
TESTES=0
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA [$SHELL_NOME] $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }

md5(){ md5sum "$1" | cut -d' ' -f1; }
W(){ echo "$T/root/data/vendor/pfl7560-kit"; }   # pasta de trabalho do cenario
# ambiente de teste: SO com PFL_TESTE=1 os ganchos PFL_* valem (E3b). O dono exigido
# nas pastas e o do usuario que roda o harness (no aparelho e o root, uid 0).
amb(){
  env PFL_TESTE=1 PFL_DONO="${DONO_TESTE:-$(id -u)}" PFL_RAPIDO=1 PFL_ROOT="$T/root" \
      PFL_LVDSCTL="$T/bin/lvdsctl" PFL_LVDSCTL_MD5="$(md5 "$T/bin/lvdsctl")" \
      PFL_NLCAMCHECK="$T/bin/nl_camcheck" PFL_NLCAMCHECK_MD5="$(md5 "$T/bin/nl_camcheck")" \
      PFL_MODO_AUTO="${MODO_AUTO_TESTE:-0}" PFL_ESPERA_OK_VOLTAS=2 PATH="$T/bin:$PATH" "$@"
}
pp_md5(){ md5 "$T/root/dev/block/by-name/panelparam"; }
pp_byte(){ dd if="$T/root/dev/block/by-name/panelparam" bs=1 skip="$OFF" count=1 2>/dev/null | od -An -tu1 | tr -dc '0-9'; }
chamadas(){ grep -c "^$1" "$T/calls.log" 2>/dev/null || true; }
tem_chamada(){ grep -q "$1" "$T/calls.log" 2>/dev/null; }
telas(){ grep '^am start' "$T/calls.log" 2>/dev/null | sed 's#.*/\([a-z0-9-]*\)\.png.*#\1#' | tr '\n' ' '; }

# ---------------------------------------------------------------------------
# cenario: arvore de mentira + stubs
# ---------------------------------------------------------------------------
novo_cenario(){ # $1 = nome do caso
  CASO="$1"
  MODO_AUTO_TESTE=0     # os casos do fluxo manual rodam com o modo automatico desligado
  T="$(mktemp -d)"
  local r="$T/root" b="$T/bin"
  mkdir -p "$r/vendor/etc/init/hw" "$r/vendor/lib" "$r/vendor/bin" "$r/atv" "$r/proc/msp" "$r/dev/block/by-name" \
           "$r/data/local/tmp" "$r/data/media/0" "$r/sdcard" "$r/mnt/media_rw/USB1" "$r/atv/bootvideo" "$b"
  # a marca de fabrica (bloco 14): o logo e a animacao de boot originais do aparelho
  echo "logo de fabrica" > "$r/atv/bootvideo/logo.jpg"; echo "animacao de fabrica" > "$r/atv/bootvideo/bootanimation.zip"
  : > "$r/vendor/lib/libhitvservice.so"
  : > "$r/dev/video0"
  # termico/wi-fi/xiri: aparelho de FABRICA
  cp "$ROOT/artifacts/ZYCustom.ini.ORIGINAL" "$r/vendor/etc/ZYCustom.ini"
  cp "$ROOT/artifacts/build.prop.STOCK" "$r/vendor/build.prop"
  cp "$ROOT/artifacts/init.bigfish.rc.STOCK" "$r/vendor/etc/init/hw/init.bigfish.rc"
  # painel: perfil 69, VESA
  printf 'panel_name   | %s\ncut_idx      : 69\nlvds_fmt     | vesa\n' "$PNOME" > "$r/proc/msp/panel"
  head -c 8388608 /dev/zero | tr '\0' 'A' > "$r/dev/block/by-name/panelparam"
  printf '%s\0' "$PNOME" | dd of="$r/dev/block/by-name/panelparam" bs=1 seek=$(( 168 + 69 * 768 )) conv=notrunc 2>/dev/null
  printf '\000' | dd of="$r/dev/block/by-name/panelparam" bs=1 seek="$OFF" conv=notrunc 2>/dev/null
  # pendrive = copia da pasta do kit
  cp -r "$KIT"/. "$r/mnt/media_rw/USB1/"
  : > "$T/calls.log"; : > "$T/keys"
  PP0="$(md5 "$r/dev/block/by-name/panelparam")"
  cp "$r/dev/block/by-name/panelparam" "$T/pp-original.img"

  stub getprop 'case "$1" in
  ro.product.model) cat "$T/model" 2>/dev/null || echo PFL7560 ;;
  ro.serialno) echo SER123 ;;
  vendor.focus.camera.is_focused) echo true ;;
esac'
  echo PFL7560 > "$T/model"
  stub getevent 'echo "getevent $*" >> "$T/calls.log"
# injecoes do harness: trocam o lvdsctl entre a copia e o uso (1a ou 2a espera de tecla)
n=$(cat "$T/n-getevent" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n-getevent"
[ -f "$T/adultera-lvdsctl-$n" ] && echo "# adulterado" >> "$T/bin/lvdsctl"
[ -f "$T/linka-lvdsctl-$n" ] && { cp "$T/bin/lvdsctl" "$T/lvdsctl.copia"; rm -f "$T/bin/lvdsctl"; ln -s "$T/lvdsctl.copia" "$T/bin/lvdsctl"; }
k=$(head -1 "$T/keys"); sed -i 1d "$T/keys"
[ "$k" = "key" ] && echo "/dev/input/event2: EV_KEY       KEY_OK                DOWN"
exit 0'
  stub am 'echo "am $*" >> "$T/calls.log"
[ "$1" = "force-stop" ] && exit 0
f=$(echo "$*" | sed "s#.*-d file://\([^ ]*\).*#\1#")
f="$PFL_ROOT$f"
[ -f "$f" ] || echo "AM_ARQUIVO_AUSENTE $f" >> "$T/calls.log"
exit 0'
  # resolvedor de VIEW de PNG (ultima linha = pacote/atividade); a 1a chamada de cada tela
  stub cmd 'echo "cmd $*" >> "$T/calls.log"
n=$(cat "$T/n-cmd" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n-cmd"
[ -f "$T/adultera-nlcam-$n" ] && echo "# adulterado" >> "$T/bin/nl_camcheck"
[ -f "$T/cmd-falha" ] && exit 1
echo "priority=0 isDefault=false"
if [ -f "$T/cmd-pkg" ]; then echo "$(cat "$T/cmd-pkg")/.Atividade"; else echo "com.hisilicon.higallery/.NetworkHiGallery"; fi'
  # nl_camcheck de mentira: faixas acha 16 (ou 15 com cam-faixas-rc); niveis olha o byte
  # lvds_fmt da panelparam de mentira: igual ao de cam-certo = escada em ordem
  stub nl_camcheck 'echo "nl_camcheck $*" >> "$T/calls.log"
JEIDA="235 235 235 235 235 232 222 210 197 181 164 141 114 91 72 63"
VESA="235 235 235 231 192 148 105 86 220 212 156 90 185 116 195 128"
saida(){ for v in $1; do echo $v; done; echo "$2"; exit 0; }
case "$1" in
  faixas)
    [ -f "$T/cam-faixas-rc" ] && { echo "faixas achadas: 15 (esperadas 16)"; exit 3; }
    i=0; : > "$4"; while [ $i -lt 16 ]; do echo "$((100+i*20)) $((114+i*20))" >> "$4"; i=$((i+1)); done
    echo "faixas achadas: 16 (esperadas 16)"; exit 0 ;;
  niveis)
    [ -f "$T/cam-falha-niveis" ] && { echo "open: Device or resource busy" >&2; exit 1; }
    byte=$(dd if="$PFL_ROOT/dev/block/by-name/panelparam" bs=1 skip='"$OFF"' count=1 2>/dev/null | od -An -tu1 | tr -dc 0-9)
    [ -f "$T/cam-escuro" ] && saida "20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20" "inv_cresc=0 inv_decresc=0"
    [ -f "$T/cam-indeciso" ] && saida "$JEIDA" "inv_cresc=1 inv_decresc=4"
    if [ -f "$T/cam-nao-resolve" ] || [ "$byte" != "$(cat "$T/cam-certo")" ]; then saida "$VESA" "inv_cresc=9 inv_decresc=3"; fi
    saida "$JEIDA" "inv_cresc=10 inv_decresc=0" ;;
  geometria)
    printf "inclinacao_graus=0.4\ntrapezio_pct=1.0\nborda_centro_px=1.80\nborda_esq_px=1.90\nborda_dir_px=1.90\ncontraste_centro=0.93\nquadro=1280x720\n"; exit 0 ;;
esac
exit 2'
  stub reboot 'echo "reboot" >> "$T/calls.log"'
  stub sleep 'echo "sleep $*" >> "$T/calls.log"'
  stub mount 'echo "mount $*" >> "$T/calls.log"; [ -f "$T/mount-falha" ] && exit 1; exit 0'
  # hidebug: registra os argumentos E o que entrou pela entrada (o gtt chegaria por ela)
  stub hidebug 'echo "HIDEBUG $* $(cat 2>/dev/null | tr "\n" " ")" >> "$T/calls.log"'
  cp "$b/hidebug" "$r/vendor/bin/hidebug"
  # bloco 9B: o que a suite usa e o host nao tem (ou nao pode, sem root)
  stub setprop 'echo "setprop $*" >> "$T/calls.log"'
  stub logcat 'exit 0'
  stub wm 'echo "Physical size: 1920x1080"'
  stub input 'echo "input $*" >> "$T/calls.log"'
  stub chown 'echo "chown $*" >> "$T/calls.log"'
  stub chcon 'echo "chcon $*" >> "$T/calls.log"'
  stub dmesg 'exit 0'
  stub gtt 'echo "GTT $*" >> "$T/calls.log"'
  # bloco 9C: pm e dumpsys do app. $T/app-versao = versionCode instalado (vazio = ausente);
  # pm-falha = o install falha; pm-sem-versioncode = o pm list nao mostra a versao (cai no dumpsys)
  stub pm 'echo "pm $*" >> "$T/calls.log"
case "$1" in
  list)
    v=$(cat "$T/app-versao" 2>/dev/null); [ -n "$v" ] || exit 0
    if [ -f "$T/pm-sem-versioncode" ]; then echo "package:com.pfl7560.verificar"; else echo "package:com.pfl7560.verificar versionCode:$v minSdk:28 targetSdk:28"; fi
    exit 0 ;;
  install)
    [ -f "$T/pm-falha" ] && { echo "Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE]"; exit 1; }
    md5sum "$3" | cut -d" " -f1 > "$T/apk-instalado-md5"   # o que o pm leu (a copia do root some no fim da suite)
    echo '"$APP_VC"' > "$T/app-versao"; echo Success; exit 0 ;;
esac
exit 1'
  stub dumpsys 'echo "dumpsys $*" >> "$T/calls.log"
v=$(cat "$T/app-versao" 2>/dev/null); [ -n "$v" ] && echo "    versionCode=$v minSdk=28 targetSdk=28"
exit 0'
  # md5sum que, uma vez, troca o cor.sh da pasta de trabalho quando le o ZYCustom.ini
  # do /vendor (isso acontece DEPOIS da copia conferida e ANTES de executar o cor.sh)
  stub md5sum 'if [ -f "$T/troca-cor" ]; then case "$*" in *vendor/etc/ZYCustom.ini)
  w="$PFL_ROOT/data/vendor/pfl7560-kit"; modo=$(cat "$T/troca-cor"); rm -f "$T/troca-cor"
  case "$modo" in
    conteudo) printf "touch \"$T/cor-adulterado-rodou\"\n" >> "$w/cor.sh" ;;
    link) cp "$w/cor.sh" "$T/cor.igual"; rm -f "$w/cor.sh"; ln -s "$T/cor.igual" "$w/cor.sh" ;;
  esac ;; esac; fi
# e outra que adultera um arquivo NO PENDRIVE logo depois da conferencia la (o md5
# do ultimo PNG da lista) e antes da copia para a pasta do root
if [ -f "$T/troca-pendrive" ]; then case "$*" in *media_rw/USB1/kit/reiniciando.png)
  a=$(cat "$T/troca-pendrive"); rm -f "$T/troca-pendrive"
  printf "\ntouch \"$T/pendrive-adulterado-rodou\"\n" >> "$PFL_ROOT/mnt/media_rw/USB1/$a" ;; esac; fi
exec '"$REAL_MD5SUM"' "$@"'
  # setsid de mentira: roda o comando e marca o fim (o script o lanca com &)
  stub setsid '"$@"; touch "$T/setsid.done"'
  # cmp que pode falhar so para o backup (caso de backup invalido)
  stub cmp 'if [ -f "$T/cmp-falha" ]; then for a in "$@"; do case "$a" in *panelparam-original.img) exit 1 ;; esac; done; fi
exec '"$REAL_CMP"' "$@"'
  # lvdsctl de mentira: persiste o byte como a SetLvdsFormat real (doc 40 s1)
  stub lvdsctl 'echo "lvdsctl $*" >> "$T/calls.log"
[ -f "$T/lvds-falha" ] && exit 0
pp="$PFL_ROOT/dev/block/by-name/panelparam"
if [ "$2" = "1" ]; then printf "\001"; else printf "\000"; fi | dd of="$pp" bs=1 seek='"$OFF"' conv=notrunc 2>/dev/null
[ -f "$T/lvds-corrompe" ] && rm -f "$T/lvds-corrompe" && printf "ZZ" | dd of="$pp" bs=1 seek='"$(( 168 + 69 * 768 + 200 ))"' conv=notrunc 2>/dev/null
# fora do perfil (cabecalho da particao), uma vez
[ -f "$T/lvds-corrompe-cab" ] && rm -f "$T/lvds-corrompe-cab" && printf "ZZ" | dd of="$pp" bs=1 seek=10 conv=notrunc 2>/dev/null
# so na chamada que devolve o formato original (fmt 0), uma vez
[ "$2" = "0" ] && [ -f "$T/lvds-corrompe-ao-reverter" ] && rm -f "$T/lvds-corrompe-ao-reverter" && printf "ZZ" | dd of="$pp" bs=1 seek='"$(( 168 + 69 * 768 + 200 ))"' conv=notrunc 2>/dev/null
exit 0'
  ln -sf "$(command -v "$SHELL_BIN")" "$b/sh"
  [ "$SHELL_BIN" = busybox ] && ln -sf "$(command -v busybox)" "$b/sh"
  export T
}

stub(){ printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }

# o servico de boot da suite (bloco 9B) ja instalado, como o kit deixa
rc_suite_ok(){
  cp "$KIT/pfl7560-suite.rc" "$T/root/vendor/etc/init/pfl7560-suite.rc"; chmod 644 "$T/root/vendor/etc/init/pfl7560-suite.rc"
  # o app ja no /vendor/app (bloco 9C): o aparelho "com tudo" nao abre o /vendor por ele
  mkdir -p "$T/root/vendor/app/PFL7560"; chmod 755 "$T/root/vendor/app/PFL7560"
  cp "$KIT/pfl7560.apk" "$T/root/vendor/app/PFL7560/PFL7560.apk"; chmod 644 "$T/root/vendor/app/PFL7560/PFL7560.apk"
  mkdir -p "$T/root/vendor/app/PFL7560Home"; chmod 755 "$T/root/vendor/app/PFL7560Home"
  cp "$KIT/pfl7560-home.apk" "$T/root/vendor/app/PFL7560Home/PFL7560Home.apk"; chmod 644 "$T/root/vendor/app/PFL7560Home/PFL7560Home.apk"
  grep -qx "vendor.newlink.launcher.package=com.pfl7560.home" "$T/root/vendor/build.prop" || echo "vendor.newlink.launcher.package=com.pfl7560.home" >> "$T/root/vendor/build.prop"
  fm_e_overlays_ok
}
# bloco 14: as sobreposicoes de tema ja em /vendor/overlay, a prop do gerenciador de arquivos e a marca
# ja gravada (o aparelho "com tudo" nao abre o /vendor nem escreve nada por eles)
OVL_KIT="$(sed -n '/^# KIT_OVERLAYS_INICIO/,/^# KIT_OVERLAYS_FIM/p' "$KIT/newlink_update.sh" | sed -n 's/^\(KIT_OVERLAYS="\)\{0,1\}\(overlay\/[A-Za-z0-9]*\.apk:[A-Za-z0-9]*\)$/\2/p')"
overlays_ok(){
  local e
  for e in $OVL_KIT; do
    mkdir -p "$T/root/vendor/overlay/${e#*:}"; chmod 755 "$T/root/vendor/overlay/${e#*:}"
    cp "$KIT/${e%%:*}" "$T/root/vendor/overlay/${e#*:}/${e#*:}.apk"; chmod 644 "$T/root/vendor/overlay/${e#*:}/${e#*:}.apk"
  done
}
fm_e_overlays_ok(){
  overlays_ok
  grep -qx "vendor.nl.filemanage_file=1" "$T/root/vendor/build.prop" || echo "vendor.nl.filemanage_file=1" >> "$T/root/vendor/build.prop"
  cp "$KIT/marca/logo.jpg" "$T/root/atv/bootvideo/logo.jpg"; cp "$KIT/marca/bootanimation.zip" "$T/root/atv/bootvideo/bootanimation.zip"
}
# aparelho com tudo aplicado (termico/wi-fi/xiri/servico da suite): so a cor fica em jogo
aparelho_ok(){
  local r="$T/root"
  rc_suite_ok
  cp "$KIT/ZYCustom.ini" "$r/vendor/etc/ZYCustom.ini"
  sed -i 's/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/' "$r/vendor/build.prop"
  sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$r/vendor/etc/init/hw/init.bigfish.rc"
}
estado_vendor(){ ( cd "$T/root/vendor" && find . -type f | sort | xargs md5sum | md5sum ); }

# modelo SEM USB-C (V1.0.0.1, NOTYPEC): o aparelho de fabrica dele (ini e build.prop do
# firmware de 2026-10-20, doc 42). Chamar logo depois de novo_cenario.
modelo_novo(){
  cp "$ROOT/artifacts/ZYCustom.ini.NOTYPEC.STOCK" "$T/root/vendor/etc/ZYCustom.ini"
  cp "$ROOT/artifacts/build.prop.NOTYPEC.STOCK" "$T/root/vendor/build.prop"
}
# ... e o dele ja com tudo aplicado (termico por secoes, wi-fi e xiri)
aparelho_ok_novo(){
  local r="$T/root"
  rc_suite_ok
  cp "$ROOT/artifacts/ZYCustom_390.NOTYPEC.ini" "$r/vendor/etc/ZYCustom.ini"
  cp "$ROOT/artifacts/build.prop.NOTYPEC.STOCK" "$r/vendor/build.prop"
  sed -i 's/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/' "$r/vendor/build.prop"
  echo "vendor.newlink.launcher.package=com.pfl7560.home" >> "$r/vendor/build.prop"
  echo "vendor.nl.filemanage_file=1" >> "$r/vendor/build.prop"
  sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$r/vendor/etc/init/hw/init.bigfish.rc"
}
# linhas do ini sem o CONFIG_MODEL (para comparar o resto byte a byte)
sem_modelo(){ grep -av '^CONFIG_MODEL' "$1"; }

# roda o autorun; $1.. = teclas (key|nokey) na ordem em que getevent for chamado
roda(){
  : > "$T/keys"; for k in "$@"; do echo "$k" >> "$T/keys"; done
  rm -f "$T/setsid.done"
  amb $SHELL_BIN_RUN "$T/root/mnt/media_rw/USB1/newlink_update.sh" USB1 > "$T/out.log" 2>&1
  RC=$?
  local i=0
  while [ -z "${SEM_ESPERA:-}" ] && grep -q "lancando a " "$T/out.log" && [ ! -f "$T/setsid.done" ] && [ "$i" -lt 100 ]; do
    sleep 0.1; i=$((i+1))
  done
  [ -f "$T/root/data/vendor/pfl7560-kit/cor.log" ] && cp "$T/root/data/vendor/pfl7560-kit/cor.log" "$T/cor.log.copia" 2>/dev/null
  return 0
}
limpa(){ if [ -n "${DEBUG_KEEP:-}" ]; then echo "  (mantido: $T)"; else chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"; fi; }
# log completo (autorun + fase de cor, que vai para o pendrive no fim)
log_tudo(){ cat "$T/out.log" "$T/root/mnt/media_rw/USB1/newlink_cor.log" "$T/root/mnt/media_rw/USB1/newlink_suite.log" 2>/dev/null; }

# ---------------------------------------------------------------------------
# casos
# ---------------------------------------------------------------------------
c_sem_tecla(){
  novo_cenario "sem tecla = nenhuma escrita"; aparelho_ok
  local v0; v0="$(estado_vendor)"
  roda nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam mudou sem tecla"
  afirma '[ "$(chamadas lvdsctl)" = 0 ]' "lvdsctl foi chamado sem tecla"
  afirma '[ ! -e "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" ]' "backup criado sem tecla"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal criado sem tecla"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "gancho criado sem tecla"
  afirma '[ "$(chamadas reboot)" = 0 ]' "reboot sem motivo"
  afirma '[ "$(estado_vendor)" = "$v0" ]' "/vendor mudou"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'log_tudo | grep -q "sem tecla em 30s: formato mantido"' "log sem a linha de 'sem tecla'"
  afirma '! grep -q AM_ARQUIVO_AUSENTE "$T/calls.log"' "tela apontou arquivo inexistente"
  limpa
}

c_tecla_timeout(){
  novo_cenario "tecla + timeout = reverte"; aparelho_ok
  roda key nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam diferente do original depois de reverter"
  afirma '[ "$(pp_byte)" = 0 ]' "byte nao voltou a 0"
  afirma 'tem_chamada "lvdsctl fmt 1" && tem_chamada "lvdsctl fmt 0"' "esperava fmt 1 (teste) e fmt 0 (reversao)"
  afirma '[ "$(chamadas getevent)" = 2 ]' "getevent deveria ser chamado 2 vezes"
  afirma 'cmp -s "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" "$T/pp-original.img"' "backup do pendrive nao confere com o original"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal sobrou"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "gancho sobrou"
  afirma '[ "$(telas)" = "aguarde escada-1 escada-1 escada-2 calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'log_tudo | grep -q "sem segunda tecla"' "log sem 'sem segunda tecla'"
  afirma 'log_tudo | grep -q "revertido: lvds_fmt=0"' "log sem confirmacao da reversao"
  limpa
}

c_tecla_tecla(){
  novo_cenario "tecla + tecla = grava e rele"; aparelho_ok
  roda key key
  afirma '[ "$(pp_byte)" = 1 ]' "byte nao ficou em 1"
  afirma '[ "$(cmp -l "$T/pp-original.img" "$T/root/dev/block/by-name/panelparam" | wc -l)" = 1 ]' "mais de um byte mudou"
  afirma 'cmp -l "$T/pp-original.img" "$T/root/dev/block/by-name/panelparam" | grep -q "^ *53253 "' "o byte alterado nao e o 0x5c do perfil 69"
  afirma '[ "$(chamadas lvdsctl)" = 1 ] && tem_chamada "lvdsctl fmt 1"' "so uma chamada fmt 1 era esperada"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal sobrou depois de confirmar"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "gancho sobrou depois de confirmar"
  afirma 'cmp -s "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" "$T/pp-original.img"' "backup nao guarda o original"
  afirma '[ "$(telas)" = "aguarde escada-1 escada-1 escada-2 calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'log_tudo | grep -q "segunda tecla: lvds_fmt=1 mantido, relido"' "log sem a confirmacao"
  # segunda execucao sobre o estado confirmado (JEIDA): sem tecla = nada muda
  local pp1; pp1="$(pp_md5)"; : > "$T/calls.log"
  roda nokey
  afirma '[ "$(pp_md5)" = "$pp1" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas reboot)" = 0 ]' "2a execucao mexeu em algo"
  limpa
}

c_idempotencia(){
  novo_cenario "2a execucao: nada a fazer"
  roda nokey            # 1a: aplica termico/wifi/xiri e pede reboot
  afirma '[ "$(chamadas reboot)" = 1 ]' "1a execucao deveria reiniciar uma vez"
  afirma '[ "$(md5 "$T/root/vendor/etc/ZYCustom.ini")" = "$(md5 "$KIT/ZYCustom.ini")" ]' "ini nao ficou igual ao corrigido"
  afirma '[ -f "$T/root/vendor/etc/ZYCustom.ini.STOCK" ] && [ "$(md5 "$T/root/vendor/etc/ZYCustom.ini.STOCK")" = 29d8ba36149413e899563029df078f6d ]' "STOCK nao guardado"
  afirma 'grep -q "wifi_disconnect_on_boot=0" "$T/root/vendor/build.prop"' "wi-fi nao aplicado"
  afirma '[ ! -e "$T/setsid.done" ]' "fase de cor nao deve rodar antes do reboot termico"
  afirma 'tem_chamada "reiniciando.png"' "tela 'reiniciando' nao apareceu"
  afirma 'tem_chamada "mount -o rw,remount /vendor" && tem_chamada "mount -o ro,remount /vendor"' "remount rw/ro ausente"
  local v1; v1="$(estado_vendor)"; : > "$T/calls.log"
  roda nokey            # 2a: tudo ok, so a pergunta de cor
  afirma '[ "$(chamadas reboot)" = 0 ]' "2a execucao reiniciou"
  afirma '[ "$(estado_vendor)" = "$v1" ]' "2a execucao escreveu em /vendor"
  afirma '[ "$(chamadas mount)" = 0 ]' "2a execucao remontou /vendor"
  afirma '[ "$(pp_md5)" = "$PP0" ]' "2a execucao mexeu na panelparam"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ]' "telas da 2a: '$(telas)'"
  limpa
}

c_ini_anterior(){
  # cada versao NOSSA que ja foi para aparelho: a do artifacts e as que o pendrive
  # levou antes da escada (git: d10f6da = 1ad641ed) e com espacos cortados (cd5a80f)
  local v f
  for v in artifacts:PREV-211927 d10f6da cd5a80f; do
    novo_cenario "ini da versao anterior ($v) e atualizado"
    f="$T/root/vendor/etc/ZYCustom.ini"
    case "$v" in
      artifacts:*) cp "$ROOT/artifacts/ZYCustom_390.PREV-211927.ini" "$f" ;;
      *) git -C "$ROOT" show "$v:pendrive-autorun/ZYCustom.ini" > "$f" 2>/dev/null \
           || { echo "  (sem historico git de $v: caso pulado)"; limpa; continue; } ;;
    esac
    roda nokey
    afirma '[ "$(md5 "$f")" = 252ab7a72a007a8b79b3fc86bd5c0d19 ]' "ini anterior nao foi atualizado"
    afirma '[ ! -e "$T/root/vendor/etc/ZYCustom.ini.STOCK" ]' "versao anterior foi guardada como STOCK"
    afirma '[ "$(chamadas reboot)" = 1 ]' "sem reboot"
    limpa
  done
}

c_ini_desconhecido(){
  novo_cenario "md5 de .ini desconhecido = recusa"
  head -c 3000 /dev/urandom | base64 > "$T/root/vendor/etc/ZYCustom.ini"
  local m0; m0="$(md5 "$T/root/vendor/etc/ZYCustom.ini")"
  roda nokey
  afirma '[ "$(md5 "$T/root/vendor/etc/ZYCustom.ini")" = "$m0" ]' "ini desconhecido foi sobrescrito"
  afirma 'grep -q "NAO vou sobrescrever" "$T/out.log"' "log sem a recusa"
  afirma '[ "$(chamadas reboot)" = 0 ]' "reiniciou apesar da recusa"
  afirma '[ ! -e "$T/root/vendor/etc/ZYCustom.ini.new" ]' ".new sobrou"
  afirma 'grep -q "wifi_disconnect_on_boot=0" "$T/root/vendor/build.prop"' "wi-fi e xiri sao independentes e deviam aplicar"
  afirma 'grep -q "PARCIAL" "$T/out.log"' "log sem PARCIAL"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao erro " ]' "tela final deveria ser erro: '$(telas)'"
  limpa
}

c_atv_override(){
  novo_cenario "/atv/ini com override = avisa"; aparelho_ok
  mkdir -p "$T/root/atv/ini"; echo x > "$T/root/atv/ini/ZYCustom_390.ini"
  roda nokey
  afirma 'grep -q "TEM PRECEDENCIA" "$T/out.log"' "sem aviso de precedencia"
  afirma '! grep -q "CORRECAO APLICADA COM SUCESSO" "$T/out.log"' "disse sucesso apesar do override"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao erro " ]' "tela final deveria ser erro: '$(telas)'"
  afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam mudou"
  limpa
}

c_adulterado(){
  local alvo
  for alvo in "kit/escada-1.png" "cor.sh" "lvdsctl" "nl_camcheck" "ZYCustom.ini" "kit/pronto.png"; do
    novo_cenario "arquivo do kit adulterado ($alvo) = aborta antes de escrever"
    local v0; v0="$(estado_vendor)"
    printf 'X' >> "$T/root/mnt/media_rw/USB1/$alvo"
    roda key key
    afirma '[ "$RC" = 1 ]' "deveria sair com 1 (saiu com $RC)"
    afirma '[ "$(estado_vendor)" = "$v0" ]' "/vendor mudou"
    afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam mudou"
    afirma '[ "$(chamadas reboot)" = 0 ] && [ "$(chamadas mount)" = 0 ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas getevent)" = 0 ]' "houve reboot/mount/lvdsctl/getevent"
    afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit" ]' "o kit foi copiado para /data antes de conferir"
    afirma 'grep -q "adulterado" "$T/out.log" && grep -q "$alvo" "$T/out.log"' "log nao aponta $alvo"
    limpa
  done
  novo_cenario "arquivo do kit ausente = aborta antes de escrever"
  local v0; v0="$(estado_vendor)"
  rm -f "$T/root/mnt/media_rw/USB1/kit/erro.png"
  roda key key
  afirma '[ "$RC" = 1 ] && [ "$(estado_vendor)" = "$v0" ] && [ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas reboot)" = 0 ]' "arquivo ausente nao abortou limpo"
  limpa
}

c_journal_no_boot(){
  novo_cenario "journal no boot = restaura (pelo autorun)"; aparelho_ok
  simula_teste_interrompido
  [ "$(pp_byte)" = 1 ] && ok || falha "preparo: o byte deveria estar em 1"
  roda nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam nao foi restaurada ao original"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal sobrou"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "gancho sobrou"
  afirma 'tem_chamada "lvdsctl fmt 0"' "formato original nao foi aplicado ao vivo"
  afirma '[ "$(chamadas reboot)" = 0 ]' "reiniciou sem precisar"
  afirma 'grep -q "restaurando o formato original antes de tudo" "$T/out.log"' "log sem a restauracao"
  limpa

  novo_cenario "journal + perfil corrompido = restaura os 768 bytes do perfil"; aparelho_ok
  simula_teste_interrompido
  printf 'ZZ' | dd of="$T/root/dev/block/by-name/panelparam" bs=1 seek=$(( 168 + 69 * 768 + 300 )) conv=notrunc 2>/dev/null
  roda nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "perfil corrompido nao foi restaurado do backup"
  afirma 'grep -q "restaurando os 768 bytes do perfil" "$T/out.log"' "log sem a restauracao do perfil"
  limpa

  novo_cenario "journal no boot SEM pendrive = o gancho restaura"; aparelho_ok
  simula_teste_interrompido
  amb $SHELL_BIN_RUN "$T/root/data/local/nlsu/update_after_boot.sh" > "$T/hook.log" 2>&1
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o gancho nao restaurou a panelparam"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "o gancho nao se apagou"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit" ]' "diretorio de trabalho sobrou"
  limpa

  novo_cenario "journal + lvdsctl ausente = restaura por dd e reinicia (plano B)"; aparelho_ok
  simula_teste_interrompido
  rm -f "$T/root/vendor/lib/libhitvservice.so"
  roda nokey
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas reboot)" = 1 ] && [ "$(chamadas lvdsctl)" = 0 ]' "plano B por dd/reboot falhou"
  afirma '[ "$(telas)" = "" ]' "nao devia mostrar tela antes do reboot: '$(telas)'"
  limpa

  novo_cenario "journal que nao se apaga + sem lvdsctl = restaura e NAO reinicia (sem laco)"; aparelho_ok
  simula_teste_interrompido
  rm -f "$T/root/vendor/lib/libhitvservice.so"
  chmod 500 "$T/root/data/vendor/pfl7560-kit"
  if [ "$(id -u)" != 0 ]; then
    roda nokey
    afirma '[ "$(pp_md5)" = "$PP0" ]' "a particao nao foi restaurada"
    afirma '[ "$(chamadas reboot)" = 0 ]' "reiniciou com o journal de pe (laco de reboot)"
    afirma '[ -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "o journal deveria ter ficado"
  else
    echo "  (rodando como root: caso do journal que nao se apaga pulado)"
  fi
  chmod 700 "$T/root/data/vendor/pfl7560-kit"
  limpa

  novo_cenario "journal incoerente = nao escreve"; aparelho_ok
  simula_teste_interrompido
  sed -i 's/^J_OFF=.*/J_OFF=100/' "$T/root/data/vendor/pfl7560-kit/journal"
  roda nokey
  afirma '[ "$(pp_byte)" = 1 ]' "restaurou com journal incoerente"
  afirma '[ -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal incoerente foi apagado (deveria ficar para inspecao)"
  limpa
}

# estado de uma queda de energia no meio do teste: panelparam em JEIDA (1), journal,
# backup do original, copia do cor.sh em /data e gancho instalado
simula_teste_interrompido(){
  local r="$T/root" w="$T/root/data/vendor/pfl7560-kit"
  mkdir -p "$r/data/vendor" "$r/data/local/nlsu"
  ( umask 077; mkdir "$w" )
  cp "$r/dev/block/by-name/panelparam" "$w/panelparam-original.img"
  cp "$KIT/cor.sh" "$KIT/lvdsctl" "$w/"
  printf 'J_IDX=69\nJ_OFF=%s\nJ_FMT=0\nJ_MD5=%s\n' "$OFF" "$(md5 "$w/panelparam-original.img")" > "$w/journal"
  printf '\001' | dd of="$r/dev/block/by-name/panelparam" bs=1 seek="$OFF" conv=notrunc 2>/dev/null
  cat > "$r/data/local/nlsu/update_after_boot.sh" <<FIM
#!/vendor/bin/sh
# pfl7560-kit-gancho: criado pelo kit de pendrive.
if [ -f "$w/journal" ] && [ -f "$w/cor.sh" ]; then
  sh "$w/cor.sh" --restaurar
fi
[ -f "$w/journal" ] || rm -f "\$0"
FIM
}

# executa o kit ate a 2a pergunta e "cai a energia": a 2a espera de tecla mata o
# processo. Sobra o byte em JEIDA, o journal, o backup e o gancho GERADO pelo cor.sh.
# A "queda" mata SO o cor.sh DESTE cenario (o caminho dele passa por $T): um pkill pelo
# nome so ("pfl7560-kit/cor.sh") matava tambem o cor.sh de outra rodada do harness na
# mesma maquina (outra arvore, outro make check-kit), que falhava sem motivo (bloco 19C).
# shellcheck disable=SC2016  # o $T expande dentro do stub, na hora da queda
mata_cor(){ echo 'pkill -9 -f "$T/root/data/vendor/pfl7560-kit/cor.sh"; sleep 1'; }
gera_gancho_interrompido(){
  stub getevent 'echo "getevent $*" >> "$T/calls.log"
n=$(cat "$T/n" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n"
[ "$n" = 1 ] && echo "/dev/input/event2: EV_KEY       KEY_OK                DOWN"
if [ "$n" = 2 ]; then '"$(mata_cor)"'; fi
exit 0'
  roda
  rmdir "$T/root/dev/pfl7560-kit.lock" 2>/dev/null   # /dev e tmpfs: o lock some com a queda de energia
}

c_gancho_gerado(){
  # o gancho que o PROPRIO cor.sh escreve tem de ser o que restaura (nao um de teste)
  novo_cenario "gancho gerado pelo cor.sh restaura o formato"; aparelho_ok
  gera_gancho_interrompido
  afirma '[ "$(pp_byte)" = 1 ]' "o teste interrompido deveria ter deixado o byte em 1"
  afirma '[ -f "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal deveria existir"
  afirma 'grep -q "pfl7560-kit-gancho" "$T/root/data/local/nlsu/update_after_boot.sh"' "gancho nao foi gerado"
  amb $SHELL_BIN_RUN "$T/root/data/local/nlsu/update_after_boot.sh" > "$T/hook.log" 2>&1
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o gancho gerado nao restaurou"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ] && [ ! -e "$T/root/data/local/nlsu" ]' "o gancho nao se apagou"
  limpa
}

# ---------------------------------------------------------------------------
# E3b: seguranca da pasta de trabalho, do md5 na hora do uso, do backup e do gancho
# ---------------------------------------------------------------------------
# nada foi escrito na panelparam nem executado: o estado de $1 (md5 da particao)
# segue igual e nem lvdsctl nem getevent foram chamados
nada_escrito(){ # $1 = md5 esperado da panelparam; $2 = chamadas de lvdsctl ja feitas antes (padrao 0)
  afirma "[ \"\$(pp_md5)\" = \"$1\" ]" "panelparam mudou"
  afirma "[ \"\$(chamadas lvdsctl)\" = \"${2:-0}\" ]" "lvdsctl foi executado"
}

c_trabalho_inseguro(){
  local r pp0

  novo_cenario "pasta de trabalho e um LINK = recusa (nada escrito nem no alvo do link)"; aparelho_ok
  r="$T/root"; mkdir -p "$r/data/vendor" "$T/atacante"; ln -s "$T/atacante" "$r/data/vendor/pfl7560-kit"
  roda key key
  afirma '[ "$RC" = 1 ]' "deveria sair com 1 (saiu com $RC)"
  nada_escrito "$PP0"
  afirma '[ -z "$(ls -A "$T/atacante")" ]' "escreveu no alvo do link"
  afirma '[ "$(chamadas getevent)" = 0 ] && [ ! -e "$T/setsid.done" ]' "fase de cor rodou"
  afirma 'grep -q "so do root" "$T/out.log"' "log sem a recusa"
  limpa

  novo_cenario "pasta de trabalho aberta a outros (0755) = recusa e nao conserta"; aparelho_ok
  r="$T/root"; mkdir -p "$r/data/vendor/pfl7560-kit"; chmod 755 "$r/data/vendor/pfl7560-kit"
  roda key key
  afirma '[ "$RC" = 1 ]' "deveria sair com 1 (saiu com $RC)"
  nada_escrito "$PP0"
  afirma '[ -z "$(ls -A "$r/data/vendor/pfl7560-kit")" ]' "escreveu numa pasta aberta a outros"
  afirma 'ls -ld "$r/data/vendor/pfl7560-kit" | grep -q "^drwxr-xr-x"' "a pasta recusada foi alterada"
  limpa

  novo_cenario "pasta de trabalho de outro dono = recusa"; aparelho_ok
  r="$T/root"; mkdir -p "$r/data/vendor"; ( umask 077; mkdir "$r/data/vendor/pfl7560-kit" )
  DONO_TESTE=$(( $(id -u) + 1 )) roda key key
  afirma '[ "$RC" = 1 ]' "deveria sair com 1 (saiu com $RC)"
  nada_escrito "$PP0"
  afirma '[ -z "$(ls -A "$r/data/vendor/pfl7560-kit")" ]' "escreveu numa pasta de outro dono"
  limpa

  novo_cenario "cor.sh chamado direto com a pasta como link = recusa (--restaurar, --tela e teste)"; aparelho_ok
  r="$T/root"; mkdir -p "$r/data/vendor" "$T/atacante"; ln -s "$T/atacante" "$r/data/vendor/pfl7560-kit"
  : > "$T/keys"; echo key >> "$T/keys"; echo key >> "$T/keys"
  amb dash "$KIT/cor.sh" --restaurar > "$T/d1.log" 2>&1; local rc1=$?
  amb dash "$KIT/cor.sh" --tela pronto > "$T/d2.log" 2>&1; local rc2=$?
  amb dash "$KIT/cor.sh" "$r/mnt/media_rw/USB1" "" "$(md5 "$KIT/cor.sh")" > "$T/d3.log" 2>&1; local rc3=$?
  afirma '[ "$rc1" = 1 ] && [ "$rc2" = 1 ] && [ "$rc3" = 1 ]' "codigos de saida $rc1 $rc2 $rc3 (esperado 1 1 1)"
  nada_escrito "$PP0"
  afirma '[ -z "$(ls -A "$T/atacante")" ] && [ "$(chamadas getevent)" = 0 ] && [ "$(chamadas am)" = 0 ]' "agiu apesar do link"
  limpa

  novo_cenario "journal da pasta de trabalho e um LINK = nao restaura"; aparelho_ok
  simula_teste_interrompido
  cp "$(W)/journal" "$T/journal.copia"; rm -f "$(W)/journal"; ln -s "$T/journal.copia" "$(W)/journal"
  pp0="$(pp_md5)"
  roda nokey
  nada_escrito "$pp0"
  afirma 'grep -q "NAO vou escrever" "$T/out.log" || grep -q "NAO vou escrever" "$T/root/mnt/media_rw/USB1/newlink_cor.log"' "log sem a recusa"
  limpa

  novo_cenario "journal sem o md5 do backup (formato antigo) = nao restaura"; aparelho_ok
  simula_teste_interrompido
  sed -i '/^J_MD5=/d' "$(W)/journal"
  pp0="$(pp_md5)"
  roda nokey
  nada_escrito "$pp0"
  limpa
}

c_troca_apos_copia(){
  local modo
  for modo in conteudo link; do
    novo_cenario "cor.sh trocado ($modo) DEPOIS da copia e antes de executar = nao executa"; aparelho_ok
    echo "$modo" > "$T/troca-cor"
    roda key key
    afirma '[ ! -e "$T/troca-cor" ]' "a injecao do harness nao disparou"
    afirma '[ "$RC" = 1 ]' "deveria sair com 1 (saiu com $RC)"
    afirma '[ ! -e "$T/cor-adulterado-rodou" ] && [ ! -e "$T/setsid.done" ]' "o cor.sh trocado foi executado"
    nada_escrito "$PP0"
    afirma '[ "$(chamadas getevent)" = 0 ] && [ "$(chamadas am)" = 0 ]' "a fase de cor andou"
    afirma 'grep -q "cor.sh" "$T/out.log" && grep -q "NAO foi lancada" "$T/out.log"' "log sem a recusa"
    limpa
  done

  novo_cenario "cor.sh trocado depois da copia, no caminho da tela de reinicio = nao executa e o reboot segue"
  echo conteudo > "$T/troca-cor"
  roda nokey
  afirma '[ ! -e "$T/troca-cor" ]' "a injecao do harness nao disparou"
  afirma '[ ! -e "$T/cor-adulterado-rodou" ] && [ "$(chamadas am)" = 0 ]' "o cor.sh trocado foi executado (tela)"
  afirma '[ "$(chamadas reboot)" = 1 ]' "a correcao termica ja aplicada precisa do reboot"
  afirma '[ "$(md5 "$T/root/vendor/etc/ZYCustom.ini")" = "$(md5 "$KIT/ZYCustom.ini")" ]' "o termico nao ficou aplicado"
  nada_escrito "$PP0"
  limpa

  novo_cenario "cor.sh trocado na pasta com journal pendente = o autorun nao o executa para restaurar"; aparelho_ok
  simula_teste_interrompido
  printf 'touch "%s"\n' "$T/cor-adulterado-rodou" >> "$(W)/cor.sh"
  roda nokey
  afirma '[ ! -e "$T/cor-adulterado-rodou" ]' "o cor.sh adulterado foi executado"
  afirma 'grep -q "recuperacao ausente, link ou com md5 diferente" "$T/out.log"' "log sem o aviso"
  limpa
}

c_troca_no_pendrive(){
  local a
  for a in cor.sh lvdsctl nl_camcheck; do
    novo_cenario "$a adulterado NO PENDRIVE entre a conferencia e a copia = nunca chega ao caminho executavel"; aparelho_ok
    echo "$a" > "$T/troca-pendrive"
    roda key key
    afirma '[ ! -e "$T/troca-pendrive" ]' "a injecao do harness nao disparou"
    afirma '[ "$RC" = 1 ]' "deveria sair com 1 (saiu com $RC)"
    nada_escrito "$PP0"
    afirma '[ ! -e "$T/pendrive-adulterado-rodou" ] && [ ! -e "$T/setsid.done" ] && [ "$(chamadas getevent)" = 0 ]' "a fase de cor andou com o kit adulterado"
    # o invariante: em $WORK/<arquivo> so existe (se existir) a versao conferida
    afirma '[ ! -e "$(W)/$a" ] || [ "$(md5 "$(W)/$a")" = "$(md5 "$KIT/$a")" ]' "arquivo nao conferido ficou em $(W)/$a"
    afirma '[ -z "$(ls -d "$(W)"/preparo.* 2>/dev/null)" ]' "sobrou pasta de preparo"
    afirma 'grep -q "nao confere - abortando" "$T/out.log"' "log sem a recusa"
    limpa
  done
}

c_lvdsctl_na_hora(){
  novo_cenario "lvdsctl adulterado ANTES do uso = nao executa e nao escreve nada"; aparelho_ok
  : > "$T/adultera-lvdsctl-1"
  roda key key
  nada_escrito "$PP0"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ] && [ ! -e "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" ] && [ ! -e "$T/root/data/local/nlsu" ]' "preparou backup/journal/gancho com lvdsctl invalido"
  afirma 'log_tudo | grep -q "lvdsctl.*md5 diferente"' "log sem a recusa do lvdsctl"
  afirma '[ "$(telas)" = "aguarde escada-1 escada-1 calibracao erro " ]' "telas: '$(telas)'"
  limpa

  novo_cenario "lvdsctl trocado por LINK antes do uso = nao executa"; aparelho_ok
  : > "$T/linka-lvdsctl-1"
  roda key key
  nada_escrito "$PP0"
  afirma 'log_tudo | grep -q "lvdsctl.*link"' "log sem a recusa do link"
  limpa

  novo_cenario "lvdsctl adulterado entre o teste e a reversao = a reversao nao o executa e a particao volta por dd"; aparelho_ok
  : > "$T/adultera-lvdsctl-2"
  roda key nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "a panelparam nao voltou ao original"
  afirma '[ "$(chamadas lvdsctl)" = 1 ] && tem_chamada "lvdsctl fmt 1" && ! tem_chamada "lvdsctl fmt 0"' "o lvdsctl adulterado foi executado: $(grep '^lvdsctl' "$T/calls.log" | tr '\n' ' ')"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal sobrou"
  limpa
}

c_backup_adulterado(){
  local pp0

  novo_cenario "backup adulterado antes de restaurar = nao restaura (autorun)"; aparelho_ok
  simula_teste_interrompido
  printf 'X' | dd of="$(W)/panelparam-original.img" bs=1 seek=100 conv=notrunc 2>/dev/null
  pp0="$(pp_md5)"
  roda nokey
  nada_escrito "$pp0"
  afirma '[ -f "$(W)/journal" ]' "o journal deveria ficar para inspecao"
  afirma 'grep -q "backup adulterado" "$T/out.log" || grep -q "backup adulterado" "$T/root/mnt/media_rw/USB1/newlink_cor.log"' "log sem a recusa"
  limpa

  novo_cenario "backup adulterado antes de restaurar = nao restaura (gancho)"; aparelho_ok
  simula_teste_interrompido
  printf 'X' | dd of="$(W)/panelparam-original.img" bs=1 seek=100 conv=notrunc 2>/dev/null
  pp0="$(pp_md5)"
  amb dash "$T/root/data/local/nlsu/update_after_boot.sh" > "$T/hook.log" 2>&1
  nada_escrito "$pp0"
  afirma 'grep -q "backup adulterado" "$T/hook.log"' "log sem a recusa"
  limpa

  novo_cenario "backup trocado por LINK (mesmo conteudo) = nao restaura"; aparelho_ok
  simula_teste_interrompido
  cp "$(W)/panelparam-original.img" "$T/bkp.igual"; rm -f "$(W)/panelparam-original.img"
  ln -s "$T/bkp.igual" "$(W)/panelparam-original.img"
  pp0="$(pp_md5)"
  roda nokey
  nada_escrito "$pp0"
  afirma 'log_tudo | grep -q "link ou de outro dono"' "log sem a recusa do link"
  limpa

  novo_cenario "backup com o tamanho certo e md5 de outro = o journal manda"; aparelho_ok
  simula_teste_interrompido
  sed -i 's/^J_MD5=.*/J_MD5=00000000000000000000000000000000/' "$(W)/journal"
  pp0="$(pp_md5)"
  roda nokey
  nada_escrito "$pp0"
  limpa
}

c_gancho_adulterado(){
  local pp0 g n0

  novo_cenario "gancho gerado: ambiente de teste apagado e md5 do cor.sh embutido"; aparelho_ok
  gera_gancho_interrompido
  g="$T/root/data/local/nlsu/update_after_boot.sh"
  afirma 'grep -q "^unset PFL_ROOT PFL_LVDSCTL PFL_LVDSCTL_MD5 PFL_NLCAMCHECK PFL_NLCAMCHECK_MD5 PFL_MODO_AUTO PFL_RAPIDO PFL_DONO PFL_TESTE$" "$g"' "gancho sem o unset dos ganchos de teste"
  afirma '[ "$(grep -n "PFL_" "$g" | head -1 | cut -d: -f1)" = "$(grep -n "^unset PFL_" "$g" | cut -d: -f1)" ]' "alguma referencia PFL_ vem antes do unset"
  afirma '! grep -vE "^(unset PFL_|PFL_TESTE=1;|export PFL_)" "$g" | grep -q "PFL_"' "gancho cita PFL_* fora do unset e do bloco do harness"
  afirma 'grep -q "^COR_MD5=\"$(md5 "$KIT/cor.sh")\"$" "$g"' "gancho sem o md5 do cor.sh"
  afirma 'grep -q "^W=\"$(W)\"$" "$g"' "gancho aponta para outra pasta"
  limpa

  novo_cenario "gancho com cor.sh ADULTERADO = nao executa"; aparelho_ok
  gera_gancho_interrompido
  g="$T/root/data/local/nlsu/update_after_boot.sh"
  printf 'touch "%s"\n' "$T/cor-adulterado-rodou" >> "$(W)/cor.sh"
  pp0="$(pp_md5)"; n0="$(chamadas lvdsctl)"
  amb dash "$g" > "$T/hook.log" 2>&1
  afirma '[ ! -e "$T/cor-adulterado-rodou" ]' "o cor.sh adulterado foi executado pelo gancho"
  nada_escrito "$pp0" "$n0"
  afirma '[ "$(pp_byte)" = 1 ] && [ -f "$(W)/journal" ] && [ -f "$g" ]' "o gancho nao deveria ter mexido em nada"
  afirma 'grep -q "NAO vou executar" "$T/hook.log"' "gancho sem o aviso"
  limpa

  novo_cenario "gancho com cor.sh trocado por LINK de mesmo conteudo = nao executa"; aparelho_ok
  gera_gancho_interrompido
  g="$T/root/data/local/nlsu/update_after_boot.sh"
  cp "$(W)/cor.sh" "$T/cor.igual"; rm -f "$(W)/cor.sh"; ln -s "$T/cor.igual" "$(W)/cor.sh"
  pp0="$(pp_md5)"; n0="$(chamadas lvdsctl)"
  amb dash "$g" > "$T/hook.log" 2>&1
  nada_escrito "$pp0" "$n0"
  afirma 'grep -q "NAO vou executar" "$T/hook.log"' "gancho sem o aviso"
  limpa

  novo_cenario "gancho com a pasta de trabalho aberta a outros = nao executa"; aparelho_ok
  gera_gancho_interrompido
  g="$T/root/data/local/nlsu/update_after_boot.sh"
  chmod 777 "$(W)"
  pp0="$(pp_md5)"; n0="$(chamadas lvdsctl)"
  amb dash "$g" > "$T/hook.log" 2>&1
  nada_escrito "$pp0" "$n0"
  afirma 'grep -q "NAO vou executar" "$T/hook.log"' "gancho sem o aviso"
  chmod 700 "$(W)"
  limpa

  novo_cenario "gancho NOSSO de outra versao (sem md5, de antes do E3b) = reescrito com o md5 do cor.sh"; aparelho_ok
  g="$T/root/data/local/nlsu/update_after_boot.sh"
  mkdir -p "$T/root/data/local/nlsu"; chmod 755 "$T/root/data/local/nlsu"
  printf '#!/vendor/bin/sh\n# pfl7560-kit-gancho: versao velha\nsh /data/local/tmp/pfl7560-kit/cor.sh --restaurar\n' > "$g"
  gera_gancho_interrompido
  afirma 'grep -q "^COR_MD5=\"$(md5 "$KIT/cor.sh")\"$" "$g"' "o gancho velho ficou (sem o md5 do cor.sh)"
  afirma '! grep -q "local/tmp" "$g"' "o gancho ainda aponta para /data/local/tmp"
  amb dash "$g" > "$T/hook.log" 2>&1
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o gancho reescrito nao restaurou"
  limpa

  novo_cenario "pasta do gancho aberta a outros ou de outro dono = o gancho nao e instalado"; aparelho_ok
  mkdir -p "$T/root/data/local/nlsu"; chmod 777 "$T/root/data/local/nlsu"
  roda key nokey
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "instalou o gancho numa pasta que outros gravam"
  afirma 'log_tudo | grep -q "nao consegui instalar o gancho de recuperacao"' "log sem o aviso"
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o teste de cor deveria terminar revertido"
  limpa
}

c_ambiente_sem_teste(){
  novo_cenario "ganchos PFL_* sem PFL_TESTE=1 sao ignorados (cor.sh e autorun)"; aparelho_ok
  simula_teste_interrompido
  local pp0 v0; pp0="$(pp_md5)"; v0="$(estado_vendor)"
  if [ "$(id -u)" != 0 ]; then
    env PFL_ROOT="$T/root" PFL_LVDSCTL="$T/bin/lvdsctl" PFL_LVDSCTL_MD5="$(md5 "$T/bin/lvdsctl")" PFL_RAPIDO=1 \
        PFL_DONO="$(id -u)" PATH="$T/bin:$PATH" dash "$KIT/cor.sh" --restaurar > "$T/sem-teste1.log" 2>&1
    env PFL_ROOT="$T/root" PFL_RAPIDO=1 PFL_DONO="$(id -u)" PATH="$T/bin:$PATH" \
        dash "$T/root/mnt/media_rw/USB1/newlink_update.sh" USB1 > "$T/sem-teste2.log" 2>&1
    afirma '[ "$(pp_md5)" = "$pp0" ] && [ "$(chamadas lvdsctl)" = 0 ]' "usou a arvore de mentira sem PFL_TESTE"
    afirma '[ "$(estado_vendor)" = "$v0" ]' "mexeu na arvore de mentira sem PFL_TESTE"
    afirma '! grep -q "$T" "$T/sem-teste1.log" "$T/sem-teste2.log"' "os logs citam a arvore de mentira"
  else
    echo "  (rodando como root: caso do ambiente sem PFL_TESTE pulado)"
  fi
  # estatico: nenhum override do ambiente aparece fora do bloco que o protege
  afirma 'grep -q "^if \[ \"\${PFL_TESTE:-}\" != \"1\" \]; then$" "$KIT/cor.sh" && grep -q "^if \[ \"\${PFL_TESTE:-}\" != \"1\" \]; then$" "$KIT/newlink_update.sh"' "falta o bloco que apaga os PFL_* sem PFL_TESTE"
  limpa
}

# ---------------------------------------------------------------------------
# bloco 7: modo automatico pela camera (nl_camcheck de mentira, ver novo_cenario)
# ---------------------------------------------------------------------------
auto_on(){ MODO_AUTO_TESTE=1; echo "$1" > "$T/cam-certo"; }   # $1 = byte lvds_fmt que da a escada em ordem
# 0 se TODO 'am start' vem logo depois de 'am force-stop <pacote>' ($1; padrao: a galeria)
force_stop_antes(){
  grep '^am ' "$T/calls.log" | awk -v pkg="${1:-com.hisilicon.higallery}" \
    '/^am start/ { n++; if (prev != "am force-stop " pkg) bad=1 } { prev=$0 } END { exit (bad || !n) }'
}
nl_chamadas(){ grep -c "^nl_camcheck $1" "$T/calls.log" 2>/dev/null || true; }

c_auto_certo(){
  novo_cenario "auto: escada em ordem (formato certo) = nada escrito"; aparelho_ok
  auto_on 0
  local v0; v0="$(estado_vendor)"
  roda
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ]' "mexeu na panelparam com a escada em ordem"
  afirma '[ ! -e "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" ] && [ ! -e "$(W)/journal" ] && [ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "backup, journal ou gancho criados"
  afirma '[ "$(chamadas getevent)" = 0 ] && [ "$(chamadas reboot)" = 0 ]' "pediu tecla ou reiniciou"
  afirma '[ "$(nl_chamadas faixas)" = 3 ] && [ "$(nl_chamadas niveis)" = 1 ]' "esperava 3 faixas (leitura da suite antes do cor, cor e geometria) e 1 niveis: $(grep '^nl_camcheck' "$T/calls.log" | tr '\n' '|')"
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'log_tudo | grep -q "escada em ordem com lvds_fmt=0: formato certo, nada foi escrito"' "log sem a decisao"
  afirma 'log_tudo | grep -q "niveis= 235 235 235 235 235 232 222 210 197 181 164 141 114 91 72 63 inv_cresc=10 inv_decresc=0 amplitude=172"' "log sem os 16 valores e as inversoes"
  afirma 'force_stop_antes' "am force-stop nao veio antes de cada am start: $(grep '^am ' "$T/calls.log" | tr '\n' '|')"
  afirma '[ "$(estado_vendor)" = "$v0" ]' "/vendor mudou"
  # 2a execucao no mesmo estado: igual
  : > "$T/calls.log"; roda
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(nl_chamadas niveis)" = 1 ]' "2a execucao mexeu em algo"
  limpa

  novo_cenario "auto: ja em JEIDA e em ordem = nada escrito (idempotente)"; aparelho_ok
  printf '\001' | dd of="$T/root/dev/block/by-name/panelparam" bs=1 seek="$OFF" conv=notrunc 2>/dev/null
  PP0="$(pp_md5)"
  auto_on 1
  roda
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas getevent)" = 0 ]' "mexeu em JEIDA ja em ordem"
  afirma 'log_tudo | grep -q "formato certo, nada foi escrito"' "log sem a decisao"
  limpa
}

c_auto_errado(){
  novo_cenario "auto: fora de ordem, a troca resolve, sem tecla = mantem"; aparelho_ok
  auto_on 1
  roda nokey
  afirma '[ "$(pp_byte)" = 1 ]' "o byte nao ficou em 1"
  afirma '[ "$(cmp -l "$T/pp-original.img" "$T/root/dev/block/by-name/panelparam" | wc -l)" = 1 ] && cmp -l "$T/pp-original.img" "$T/root/dev/block/by-name/panelparam" | grep -q "^ *53253 "' "mais de um byte mudou, ou nao foi o 0x5c do perfil 69"
  afirma '[ "$(chamadas lvdsctl)" = 1 ] && tem_chamada "lvdsctl fmt 1"' "so uma chamada fmt 1 era esperada"
  afirma 'cmp -s "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" "$T/pp-original.img"' "backup nao guarda o original"
  afirma '[ ! -e "$(W)/journal" ] && [ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "journal ou gancho sobraram"
  afirma '[ "$(chamadas getevent)" = 1 ] && [ "$(nl_chamadas niveis)" = 2 ]' "esperava 1 espera de tecla e 2 medicoes"
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 escada-1 corrigida calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'log_tudo | grep -q "escada FORA de ordem (3 inversoes)"' "log sem a medicao antes"
  afirma 'log_tudo | grep -q "lvds_fmt=1 mantido, relido e a particao confere"' "log sem a confirmacao"
  afirma 'force_stop_antes' "am force-stop nao veio antes de cada am start: $(grep '^am ' "$T/calls.log" | tr '\n' '|')"
  afirma '[ "$(chamadas gtt)" = 0 ] && ! grep -q "^HIDEBUG.*gtt" "$T/calls.log"' "chamou gtt (direto ou pelo hidebug)"
  # 2a execucao: agora em ordem, nada muda
  local pp1; pp1="$(pp_md5)"; : > "$T/calls.log"
  roda
  afirma '[ "$(pp_md5)" = "$pp1" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas reboot)" = 0 ]' "2a execucao mexeu em algo"
  limpa

  novo_cenario "auto: fora de ordem, a troca resolve, tecla = desfaz"; aparelho_ok
  auto_on 1
  roda key
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(pp_byte)" = 0 ]' "a particao nao voltou ao original"
  afirma 'tem_chamada "lvdsctl fmt 1" && tem_chamada "lvdsctl fmt 0"' "esperava fmt 1 (troca) e fmt 0 (desfazer)"
  afirma '[ ! -e "$(W)/journal" ] && [ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "journal ou gancho sobraram"
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 escada-1 corrigida calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'log_tudo | grep -q "quer desfazer a correcao automatica"' "log sem o desfazer"
  limpa

  novo_cenario "auto: a troca nao resolve = reverte e cai no manual (sem tecla: nada escrito)"; aparelho_ok
  auto_on 1; : > "$T/cam-nao-resolve"
  roda nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "a particao nao voltou ao original"
  afirma 'tem_chamada "lvdsctl fmt 1" && tem_chamada "lvdsctl fmt 0"' "esperava fmt 1 e a reversao fmt 0"
  afirma '[ ! -e "$(W)/journal" ] && [ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "journal ou gancho sobraram"
  afirma '[ "$(chamadas getevent)" = 1 ]' "o fluxo manual deveria pedir a 1a tecla"
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 escada-1 escada-1 calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'log_tudo | grep -q "a troca nao deixou a escada em ordem" && log_tudo | grep -q "fluxo manual"' "log sem a queda para o manual"
  limpa

  novo_cenario "auto: a troca nao resolve + o manual ainda segue (tecla, tecla = grava)"; aparelho_ok
  auto_on 1; : > "$T/cam-nao-resolve"
  roda key key
  afirma '[ "$(pp_byte)" = 1 ] && [ "$(chamadas getevent)" = 2 ]' "o fluxo manual nao gravou com as duas teclas"
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 escada-1 escada-1 escada-1 escada-2 calibracao pronto " ]' "telas: '$(telas)'"
  afirma 'force_stop_antes' "am force-stop nao veio antes de cada am start"
  limpa

  # queda de energia na tela "corrigida": a troca automatica ja tinha backup, journal e
  # gancho; o gancho de boot que o proprio cor.sh gerou devolve o original
  novo_cenario "auto: queda de energia depois da troca = journal e gancho restauram"; aparelho_ok
  auto_on 1
  stub getevent 'echo "getevent $*" >> "$T/calls.log"; '"$(mata_cor)"'; exit 0'
  roda
  rmdir "$T/root/dev/pfl7560-kit.lock" 2>/dev/null
  afirma '[ "$(pp_byte)" = 1 ] && tem_chamada "lvdsctl fmt 1"' "a troca automatica deveria ter deixado o byte em 1"
  afirma '[ -f "$(W)/journal" ] && grep -q "^J_FMT=0$" "$(W)/journal"' "a troca automatica nao deixou journal com o formato original"
  afirma 'cmp -s "$(W)/panelparam-original.img" "$T/pp-original.img"' "backup da troca automatica nao guarda o original"
  afirma 'grep -q "pfl7560-kit-gancho" "$T/root/data/local/nlsu/update_after_boot.sh"' "a troca automatica nao instalou o gancho"
  amb $SHELL_BIN_RUN "$T/root/data/local/nlsu/update_after_boot.sh" > "$T/hook.log" 2>&1
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o gancho nao restaurou o formato depois da troca automatica"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "o gancho nao se apagou"
  limpa

  novo_cenario "auto: lvdsctl nao muda o byte = reverte, erro, sem journal"; aparelho_ok
  auto_on 1; : > "$T/lvds-falha"
  roda
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ ! -e "$(W)/journal" ]' "panelparam mudou ou journal sobrou"
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 calibracao erro " ]' "telas: '$(telas)'"
  limpa
}

c_auto_duvida(){
  local caso arq
  for caso in "faixas 15" "indeciso" "escuro" "falha-niveis" "sem-camera"; do
    novo_cenario "auto: $caso = cai no manual sem escrever"; aparelho_ok
    auto_on 1
    case "$caso" in
      "faixas 15") : > "$T/cam-faixas-rc" ;;
      indeciso) : > "$T/cam-indeciso" ;;
      escuro) : > "$T/cam-escuro" ;;
      falha-niveis) : > "$T/cam-falha-niveis" ;;
      sem-camera) rm -f "$T/root/dev/video0" ;;
    esac
    roda nokey
    afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ]' "escreveu na panelparam"
    afirma '[ ! -e "$(W)/journal" ] && [ ! -e "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" ] && [ ! -e "$T/root/data/local/nlsu" ]' "backup/journal/gancho"
    if [ "$caso" = "faixas 15" ]; then
      # a camera nao le: a suite chama a pessoa (2 voltas de espera no harness) antes do cor.sh
      # e de novo na geometria; o manual pede a 1a tecla
      afirma '[ "$(chamadas getevent)" = 5 ] && [ "$(grep -c "camera sem leitura" "$T/root/data/vendor/pfl7560-suite/ultimo.log")" = 2 ]' "esperas: getevent=$(chamadas getevent)"
    else
      afirma '[ "$(chamadas getevent)" = 1 ]' "o fluxo manual deveria pedir a 1a tecla"
    fi
    afirma 'log_tudo | grep -q "fluxo manual"' "log sem a queda para o manual"
    case "$caso" in
      "faixas 15") arq='[ "$(nl_chamadas niveis)" = 0 ] && [ "$(nl_chamadas faixas)" = 7 ] && telas | grep -q "^aguarde calibracao .*escada-1 .*pronto $"' ;;
      sem-camera) arq='[ "$(chamadas nl_camcheck)" = 0 ] && [ "$(telas)" = "aguarde escada-1 pronto " ]' ;;
      *) arq='[ "$(telas)" = "aguarde calibracao calibracao escada-1 escada-1 calibracao pronto " ]' ;;
    esac
    afirma "$arq" "telas/chamadas ($caso): '$(telas)'"
    limpa
  done
}

c_auto_nlcam_adulterado(){
  local n
  for n in 1 3; do
    novo_cenario "auto: nl_camcheck adulterado antes do uso #$n = nao executa e nao escreve"; aparelho_ok
    auto_on 1; : > "$T/adultera-nlcam-$n"
    roda nokey
    nada_escrito "$PP0"
    afirma '[ "$n" != 1 ] || [ "$(chamadas nl_camcheck)" = 0 ]' "o nl_camcheck adulterado foi executado"
    afirma '[ "$n" != 3 ] || { [ "$(nl_chamadas faixas)" = 1 ] && [ "$(nl_chamadas niveis)" = 0 ]; }' "medicao feita com o binario adulterado"
    afirma 'log_tudo | grep -q "nl_camcheck.*md5 diferente"' "log sem a recusa do nl_camcheck"
    afirma '[ "$(chamadas getevent)" = 1 ]' "deveria cair no manual"
    limpa
  done
  novo_cenario "auto: nl_camcheck trocado por LINK = nao executa"; aparelho_ok
  auto_on 1; : > "$T/linka-nlcam"
  cp "$T/bin/nl_camcheck" "$T/nlcam.copia"; rm -f "$T/bin/nl_camcheck"; ln -s "$T/nlcam.copia" "$T/bin/nl_camcheck"
  roda nokey
  nada_escrito "$PP0"
  afirma '[ "$(chamadas nl_camcheck)" = 0 ] && log_tudo | grep -q "nl_camcheck.*link"' "executou o nl_camcheck que e link"
  limpa
}

c_troca_de_tela(){
  local pk
  for pk in "com.outra.galeria" "android" "FALHA"; do
    novo_cenario "tela: pacote do resolvedor '$pk'"; aparelho_ok
    case "$pk" in FALHA) : > "$T/cmd-falha" ;; *) echo "$pk" > "$T/cmd-pkg" ;; esac
    roda nokey
    if [ "$pk" = "com.outra.galeria" ]; then
      afirma 'force_stop_antes com.outra.galeria' "force-stop nao usou o pacote do resolvedor: $(grep '^am ' "$T/calls.log" | tr '\n' '|')"
    else
      afirma 'force_stop_antes com.hisilicon.higallery' "sem resolver (ou 'android'), deveria cair em com.hisilicon.higallery: $(grep '^am ' "$T/calls.log" | tr '\n' '|')"
    fi
    afirma '[ "$(chamadas cmd)" -ge 3 ] && grep -q "^cmd package resolve-activity --brief -a android.intent.action.VIEW" "$T/calls.log"' "o resolvedor nao foi consultado a cada tela"
    afirma '! grep -q "^am force-stop android$" "$T/calls.log"' "force-stop do pacote android"
    limpa
  done
}

c_modo_auto_ambiente(){
  novo_cenario "PFL_MODO_AUTO=0 sem PFL_TESTE=1 e ignorado; com PFL_TESTE=1 vale"
  # cor.sh sem o despacho final: so imprime o MODO_AUTO que ele calculou
  sed '/^case "\$1" in$/,$d' "$KIT/cor.sh" > "$T/cor-sem-despacho.sh"
  echo 'echo "MODO_AUTO=$MODO_AUTO"' >> "$T/cor-sem-despacho.sh"
  afirma '[ "$(env PFL_MODO_AUTO=0 dash "$T/cor-sem-despacho.sh")" = "MODO_AUTO=1" ]' "PFL_MODO_AUTO=0 sem PFL_TESTE desligou o modo automatico"
  afirma '[ "$(env PFL_TESTE=1 PFL_MODO_AUTO=0 dash "$T/cor-sem-despacho.sh")" = "MODO_AUTO=0" ]' "PFL_MODO_AUTO=0 com PFL_TESTE nao desligou"
  afirma '[ "$(env dash "$T/cor-sem-despacho.sh")" = "MODO_AUTO=1" ]' "o padrao nao e MODO_AUTO=1"
  afirma '[ "$(env PFL_NLCAMCHECK=/tmp/x PFL_NLCAMCHECK_MD5=0 dash -c ". \"$T/cor-sem-despacho.sh\" >/dev/null; echo \$NLCAM \$NLCAM_MD5")" = "/data/vendor/pfl7560-kit/nl_camcheck $(sed -n "s/^NLCAM_MD5=\"\([0-9a-f]*\)\"$/\1/p" "$KIT/cor.sh")" ]' "PFL_NLCAMCHECK* valeram sem PFL_TESTE"
  limpa
}

c_falhas_seguras(){
  novo_cenario "lvdsctl nao muda o byte = reverte e nao deixa journal"; aparelho_ok
  : > "$T/lvds-falha"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam mudou"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal sobrou"
  afirma '[ "$(telas)" = "aguarde escada-1 escada-1 calibracao erro " ]' "telas: '$(telas)'"
  afirma '[ "$(chamadas getevent)" = 1 ]' "nao devia pedir a 2a tecla se o formato nao trocou"
  limpa

  novo_cenario "lvdsctl corrompe outro byte do perfil + 2a tecla = nao mantem"; aparelho_ok
  : > "$T/lvds-corrompe"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o perfil nao voltou ao original"
  afirma 'log_tudo | grep -q "a releitura nao confirmou"' "log sem a recusa"
  limpa

  novo_cenario "lvdsctl corrompe o cabecalho (fora do perfil) + 2a tecla = nao mantem"; aparelho_ok
  : > "$T/lvds-corrompe-cab"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ]' "a particao nao voltou ao original (diferenca fora do perfil)"
  afirma 'log_tudo | grep -q "a releitura nao confirmou"' "manteve com o cabecalho alterado"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal sobrou"
  limpa

  novo_cenario "lvdsctl corrompe ao devolver o formato = o journal ainda vale e a reversao confere"; aparelho_ok
  : > "$T/lvds-corrompe-ao-reverter"
  roda key nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "a escrita do lvdsctl na reversao ficou sem conferencia"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal sobrou"
  limpa

  novo_cenario "journal + lvdsctl corrompe ao restaurar no boot = confere depois"; aparelho_ok
  simula_teste_interrompido
  : > "$T/lvds-corrompe-ao-reverter"
  roda nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "a escrita do lvdsctl na restauracao do boot ficou sem conferencia"
  limpa

  novo_cenario "backup invalido (cmp falha) = nao escreve"; aparelho_ok
  : > "$T/cmp-falha"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ]' "escreveu sem backup valido"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "journal criado sem backup"
  afirma '[ ! -e "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" ]' "backup invalido ficou no pendrive"
  afirma '[ "$(telas)" = "aguarde escada-1 escada-1 calibracao erro " ]' "telas: '$(telas)'"
  limpa

  novo_cenario "nome do perfil na particao nao bate com o driver = nao escreve"; aparelho_ok
  sed -i 's/RX058B_4300_5010E_1080P_M/OUTRO_PAINEL/' "$T/root/proc/msp/panel"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas getevent)" = 0 ]' "escreveu com offset nao provado"
  afirma '[ "$(telas)" = "aguarde calibracao erro " ]' "telas: '$(telas)'"
  limpa

  novo_cenario "lvds_fmt com valor estranho = nao escreve"; aparelho_ok
  printf '\002' | dd of="$T/root/dev/block/by-name/panelparam" bs=1 seek="$OFF" conv=notrunc 2>/dev/null
  local m; m="$(pp_md5)"
  roda key key
  afirma '[ "$(pp_md5)" = "$m" ] && [ "$(chamadas lvdsctl)" = 0 ]' "mexeu com valor desconhecido"
  limpa

  novo_cenario "lvdsctl indisponivel = nao testa e nao escreve"; aparelho_ok
  rm -f "$T/root/vendor/lib/libhitvservice.so"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ ! -e "$T/root/data/vendor/pfl7560-kit/journal" ]' "escreveu sem lvdsctl"
  limpa

  novo_cenario "modelo diferente = aborta"; aparelho_ok
  echo OUTRO > "$T/model"
  local v0; v0="$(estado_vendor)"
  roda key key
  afirma '[ "$(estado_vendor)" = "$v0" ] && [ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ ! -e "$T/setsid.done" ]' "agiu em modelo errado"
  limpa

  novo_cenario "outra instancia (lock) = nao faz nada"; aparelho_ok
  mkdir "$T/root/dev/pfl7560-kit.lock"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas getevent)" = 0 ]' "ignorou o lock"
  limpa
}

# ---------------------------------------------------------------------------
# bloco 6 (T6.1): termico por secoes, preservando o CONFIG_MODEL, nos DOIS modelos
# ---------------------------------------------------------------------------
c_modelo_antigo_secoes(){
  novo_cenario "modelo com USB-C (V1.0.0.9): por secoes sai o md5 de sempre"
  roda nokey
  afirma '[ "$(md5 "$T/root/vendor/etc/ZYCustom.ini")" = 252ab7a72a007a8b79b3fc86bd5c0d19 ]' "o ini do modelo antigo nao tem o md5 252ab7a7"
  afirma 'grep -aq "^CONFIG_MODEL = KJM_5H039_412;" "$T/root/vendor/etc/ZYCustom.ini"' "CONFIG_MODEL do modelo antigo mudou"
  afirma '[ "$(chamadas reboot)" = 1 ]' "sem reboot"
  afirma '[ ! -e "$(W)/ini.composto" ]' "arquivo de trabalho do ini sobrou"
  afirma '[ ! -e "$T/root/vendor/etc/ZYCustom.ini.new" ]' ".new sobrou"
  limpa
}

c_modelo_novo_secoes(){
  novo_cenario "modelo sem USB-C (NOTYPEC, V1.0.0.1): troca so as secoes termicas"; modelo_novo
  local f="$T/root/vendor/etc/ZYCustom.ini" st="$ROOT/artifacts/ZYCustom.ini.NOTYPEC.STOCK"
  afirma '[ "$(md5 "$f")" = ed3f314ca89698cb057a74ef64dca38e ]' "preparo: o ini de fabrica novo nao tem o md5 esperado"
  roda nokey
  afirma '[ "$(md5 "$f")" = bdf5c4640596d1b2f2fb7f62fbadd6e3 ]' "o ini do modelo novo nao ficou com o md5 esperado"
  afirma '[ "$(md5 "$f")" = "$(md5 "$ROOT/artifacts/ZYCustom_390.NOTYPEC.ini")" ]' "difere do artefato ZYCustom_390.NOTYPEC.ini"
  # o CONFIG_MODEL do modelo sem USB-C foi preservado (nao virou o do modelo antigo)
  afirma 'grep -aq "^CONFIG_MODEL = KJM_5H039_412_INTELBRAS_NOTYPEC_TP;" "$f"' "CONFIG_MODEL do modelo novo nao foi preservado"
  afirma '! grep -aq "^CONFIG_MODEL = KJM_5H039_412;" "$f"' "CONFIG_MODEL rebaixado para o do modelo antigo"
  # difere do corrigido do modelo antigo SO no CONFIG_MODEL (uma linha)
  afirma '[ "$(diff -a "$f" "$KIT/ZYCustom.ini" | grep -c "^[<>]")" = 2 ] && diff -a "$f" "$KIT/ZYCustom.ini" | grep -aq "CONFIG_MODEL"' "difere do corrigido antigo em mais que o CONFIG_MODEL"
  afirma 'cmp -s <(sem_modelo "$f") <(sem_modelo "$KIT/ZYCustom.ini")' "fora o CONFIG_MODEL, nao e o ini corrigido"
  # as secoes termicas de fato mudaram e o mux esta corrigido
  afirma 'grep -aq "HW_VIRTUAL_CHANNEL = 1" "$f" && grep -aq "= 66000, 67500, 69000, 70000, 71500, 73000" "$f"' "secoes termicas nao foram trocadas"
  # o que NAO e termico ficou byte a byte como no stock: so as linhas termicas diferem
  afirma '[ "$(diff -a "$st" "$f" | grep -a "^[<>]" | grep -avE "WARNING_VALUE|EMERGENCY_VALUE|POLICY_[01]_(THRESHOLD|BRIGHTNESS|SPEED)|HW_VIRTUAL_CHANNEL|DEFAULT_PWM_DUTY|FW_SPEED_CURVE" | wc -l)" = 0 ]' "linhas fora das secoes termicas mudaram em relacao ao stock novo"
  afirma '[ -f "$f.STOCK" ] && [ "$(md5 "$f.STOCK")" = ed3f314ca89698cb057a74ef64dca38e ]' "o stock novo nao foi guardado como .STOCK"
  afirma 'grep -q "wifi_disconnect_on_boot=0" "$T/root/vendor/build.prop"' "wi-fi nao aplicado no modelo novo"
  afirma '[ "$(chamadas reboot)" = 1 ]' "o modelo novo deveria reiniciar uma vez"
  afirma '! grep -q "NAO vou sobrescrever" "$T/out.log"' "recusou um ini de fabrica conhecido"
  # 2a execucao: idempotente, nada e escrito
  local v1; v1="$(estado_vendor)"; : > "$T/calls.log"
  roda nokey
  afirma '[ "$(chamadas reboot)" = 0 ] && [ "$(chamadas mount)" = 0 ]' "2a execucao reiniciou ou remontou /vendor"
  afirma '[ "$(estado_vendor)" = "$v1" ]' "2a execucao escreveu em /vendor"
  afirma '[ "$(md5 "$f")" = bdf5c4640596d1b2f2fb7f62fbadd6e3 ]' "2a execucao mexeu no ini"
  afirma 'grep -q "termico ja estava ok" "$T/out.log"' "log sem 'termico ja estava ok' na 2a execucao"
  limpa

  novo_cenario "modelo sem USB-C ja corrigido: nada a fazer"; aparelho_ok_novo
  local v0; v0="$(estado_vendor)"
  roda nokey
  afirma '[ "$(estado_vendor)" = "$v0" ] && [ "$(chamadas reboot)" = 0 ] && [ "$(chamadas mount)" = 0 ]' "mexeu em aparelho novo ja corrigido"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ]' "telas: '$(telas)'"
  limpa
}

c_modelo_novo_desconhecido(){
  novo_cenario "modelo novo com ini alterado (md5 desconhecido) = recusa"; modelo_novo
  local f="$T/root/vendor/etc/ZYCustom.ini" m0
  printf 'x' >> "$f"; m0="$(md5 "$f")"
  roda nokey
  afirma '[ "$(md5 "$f")" = "$m0" ]' "ini novo alterado foi sobrescrito"
  afirma 'grep -q "NAO vou sobrescrever" "$T/out.log"' "log sem a recusa"
  afirma 'grep -q "ed3f314ca89698cb057a74ef64dca38e" "$T/out.log" && grep -q "29d8ba36149413e899563029df078f6d" "$T/out.log"' "a recusa nao cita os dois md5 de fabrica"
  afirma '[ "$(chamadas reboot)" = 0 ] && [ ! -e "$f.new" ] && [ ! -e "$f.STOCK" ]' "reiniciou, deixou .new ou guardou STOCK apesar da recusa"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao erro " ]' "tela final deveria ser erro: '$(telas)'"
  limpa
}

# se o grep/sed/head/tail do aparelho se comportarem diferente e o ini montado nao tiver
# o md5 esperado, nada e gravado (o harness estraga o tail do PATH)
c_secoes_resultado_errado(){
  local m
  for m in antigo novo; do
    novo_cenario "montagem por secoes com resultado errado ($m) = nao grava"
    [ "$m" = novo ] && modelo_novo
    stub tail 'echo LIXO'
    local f="$T/root/vendor/etc/ZYCustom.ini" m0; m0="$(md5 "$f")"
    roda nokey
    afirma '[ "$(md5 "$f")" = "$m0" ]' "gravou um ini montado errado ($m)"
    afirma 'grep -q "nao consegui montar o ZYCustom.ini corrigido" "$T/out.log"' "log sem o erro de montagem ($m)"
    afirma '[ "$(chamadas reboot)" = 0 ] && [ ! -e "$f.new" ] && [ ! -e "$(W)/ini.composto" ]' "reiniciou, .new ou arquivo de trabalho sobrou ($m)"
    afirma '[ "$(telas)" = "aguarde escada-1 calibracao erro " ]' "tela final deveria ser erro: '$(telas)'"
    limpa
  done
}

c_sem_hidebug(){
  # bloco 9B: a suite le ventoinha e brilho pelo hidebug (gfs, gbri); o gtt, nunca
  novo_cenario "nunca chama gtt (nem pelo hidebug); autorun e cor.sh nem chamam hidebug"
  roda nokey
  afirma '! grep -q "^GTT" "$T/calls.log" && ! grep -q "^HIDEBUG.*gtt" "$T/calls.log"' "gtt chamado na 1a execucao"
  roda key key
  afirma '! grep -q "^GTT" "$T/calls.log" && ! grep -q "^HIDEBUG.*gtt" "$T/calls.log"' "gtt chamado na fase de cor ou na suite"
  afirma 'grep -q "^HIDEBUG.*gfs 0" "$T/calls.log"' "a suite nao leu a ventoinha pelo hidebug"
  # estatico: nenhuma linha executavel (fora de comentario) cita hidebug ou gtt
  afirma '! grep -vE "^[[:space:]]*#" "$KIT/newlink_update.sh" "$KIT/cor.sh" | grep -qiE "hidebug|[[:space:]]gtt[[:space:]]"' "script executavel cita hidebug/gtt"
  limpa
}

# ---------------------------------------------------------------------------
# E3c: instaladores copiam o kit v2 COMPLETO para a raiz do pendrive e conferem
# ---------------------------------------------------------------------------
c_instalador(){
  CASO="install.sh --pendrive"; SHELL_NOME="-"
  local d x f n
  d="$(mktemp -d)"
  afirma 'bash "$ROOT/install.sh" --pendrive "$d" >"$d.log" 2>&1' "install.sh --pendrive falhou: $(tail -3 "$d.log" 2>/dev/null | tr '\n' ' ')"
  for f in newlink_update.sh cor.sh lvdsctl nl_camcheck nl_tela ZYCustom.ini LEIA-ME.txt suite.sh suite-boot.sh suite-pedido.sh pfl7560-suite.rc pfl7560.apk pfl7560-home.apk kit/aguarde.png kit/calibracao.png kit/corrigida.png kit/erro.png kit/escada-1.png kit/escada-2.png kit/pronto.png kit/reiniciando.png fontes/IBMPlexMono-Regular.ttf fontes/IBMPlexMono-SemiBold.ttf fontes/IBMPlexSansCondensed-Bold.ttf fontes/IBMPlexSansCondensed-Regular.ttf fontes/IBMPlexSansCondensed-SemiBold.ttf fontes/OFL.txt; do
    afirma 'cmp -s "$KIT/$f" "$d/$f"' "pendrive sem $f ou com copia diferente"
  done
  n="$(cd "$d" && find . -type f | wc -l)"
  local nl; nl="$(sed -n '/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p' "$KIT/newlink_update.sh" | grep -cE '^(KIT_LISTA=")?[0-9a-f]{32}  ')"
  afirma '[ "$n" = "$((nl + 2))" ]' "esperava $((nl + 2)) arquivos no pendrive (lista + newlink_update.sh + LEIA-ME.txt), achei $n"
  # o pendrive copiado confere, arquivo a arquivo, com a lista que o aparelho usa
  afirma '( cd "$d" && sed -n "/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p" "$KIT/newlink_update.sh" \
            | sed -n "s/^\(KIT_LISTA=\"\)\{0,1\}\([0-9a-f]\{32\}  .*\)\$/\2/p" | md5sum -c --quiet - )' "o pendrive nao confere com a lista embutida"
  # destino inexistente e destino = pasta do kit: recusa
  afirma '! bash "$ROOT/install.sh" --pendrive "$d/nao-existe" >/dev/null 2>&1' "aceitou destino inexistente"
  afirma '! bash "$ROOT/install.sh" --pendrive "$KIT" >/dev/null 2>&1' "aceitou a propria pasta do kit como destino"
  afirma '! bash "$ROOT/install.sh" --pendrive >/dev/null 2>&1' "aceitou --pendrive sem destino"

  # origem com arquivo adulterado (uma copia da arvore): a conferencia depois da copia reprova
  x="$(mktemp -d)"
  mkdir -p "$x/pendrive-autorun" && cp -r "$KIT"/. "$x/pendrive-autorun/" && cp "$ROOT/install.sh" "$x/"
  printf 'X' >> "$x/pendrive-autorun/kit/pronto.png"
  mkdir -p "$d.2"
  afirma '! bash "$x/install.sh" --pendrive "$d.2" >"$d.2.log" 2>&1' "install.sh aceitou um kit com PNG adulterado"
  afirma 'grep -q "kit/pronto.png" "$d.2.log"' "a recusa nao aponta o arquivo"
  rm -rf "$d" "$d.log" "$d.2" "$d.2.log" "$x"

  # install.bat: texto estatico (nao ha Windows aqui; a prova de execucao e a mao)
  CASO="install.bat"
  local b="$ROOT/install.bat"
  afirma '[ "$(grep -c $'"'"'\r'"'"' "$b")" = 0 ]' "install.bat ganhou CRLF (tinha so LF)"
  for f in newlink_update.sh cor.sh lvdsctl nl_camcheck nl_tela ZYCustom.ini LEIA-ME.txt suite.sh suite-boot.sh suite-pedido.sh pfl7560-suite.rc pfl7560.apk pfl7560-home.apk 'kit\*.png' 'fontes\*' 'overlay\*' 'marca\*'; do
    afirma 'sed -n "/^:do_pendrive/,/^goto :menu/p" "$b" | grep -qF "$f"' "install.bat nao copia/lista $f"
  done
  afirma 'sed -n "/^:do_pendrive/,/^goto :menu/p" "$b" | grep -q "Get-FileHash -Algorithm MD5"' "install.bat nao confere o md5 depois da copia"
  afirma 'sed -n "/^:do_pendrive/,/^goto :menu/p" "$b" | grep -q "newlink_update.sh.*\\x22"' "install.bat nao le a lista embutida no newlink_update.sh"
  # o regex da lista do install.bat acha as mesmas entradas da lista embutida
  afirma '[ "$(python3 -I -c "
import re,sys
t=open(sys.argv[1]).read()
print(len(re.findall(r\"(?m)^(?:KIT_LISTA=\\x22)?([0-9a-f]{32})  (\\S+)\\s*\$\", t)))" "$KIT/newlink_update.sh")" = "$nl" ]' "regex da lista do install.bat nao acha as $nl entradas"
  for f in newlink_update.sh cor.sh lvdsctl nl_camcheck ZYCustom.ini LEIA-ME.txt; do
    afirma 'grep -q "$f" "$ROOT/INSTALL.md"' "INSTALL.md nao lista $f"
  done
  afirma 'grep -q "kit/\*.png" "$ROOT/INSTALL.md"' "INSTALL.md nao lista kit/*.png"
  afirma 'grep -q "pendrive-autorun/overlay/" "$ROOT/INSTALL.md" && grep -q "pendrive-autorun/marca/" "$ROOT/INSTALL.md"' "INSTALL.md nao lista overlay/ e marca/"
}

# ---------------------------------------------------------------------------
# estaticos
# ---------------------------------------------------------------------------
# conferente do 9B: o caminho de antes (cor.sh lancado direto pelo autorun, com as telas
# dele) continua valendo quando a suite nao roda; aqui com DESINSTALAR-SUITE.txt
c_sem_suite_legado(){
  local u
  novo_cenario "sem a suite (DESINSTALAR): cor.sh direto, sem tecla = telas de antes"; aparelho_ok
  u="$T/root/mnt/media_rw/USB1"; : > "$u/DESINSTALAR-SUITE.txt"
  roda nokey
  afirma 'grep -q "lancando a fase de cor (cor.sh) destacada" "$T/out.log" && ! grep -q "suite.sh pendrive" "$T/out.log"' "nao lancou o cor.sh direto"
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ]' "mexeu na panelparam sem tecla"
  afirma '[ "$(telas)" = "aguarde escada-1 pronto " ]' "telas: '$(telas)'"
  afirma '[ ! -e "$T/root/data/vendor/pfl7560-suite" ] && [ ! -e "$T/root/vendor/etc/init/pfl7560-suite.rc" ]' "a suite ficou instalada"
  afirma '[ -s "$u/newlink_cor.log" ] && [ ! -e "$u/newlink_suite.log" ]' "log do pendrive"
  limpa

  novo_cenario "sem a suite (DESINSTALAR): tecla + tecla = grava, backup no pendrive"; aparelho_ok
  u="$T/root/mnt/media_rw/USB1"; : > "$u/DESINSTALAR-SUITE.txt"
  roda key key
  afirma '[ "$(pp_byte)" = 1 ] && [ ! -e "$(W)/journal" ]' "nao gravou ou journal sobrou"
  afirma 'cmp -s "$u/panelparam-backup-SER123.img" "$T/pp-original.img"' "backup do pendrive"
  afirma '[ "$(telas)" = "aguarde escada-1 escada-1 escada-2 pronto " ]' "telas: '$(telas)'"
  limpa

  novo_cenario "sem a suite (DESINSTALAR): .ini desconhecido = tela final erro do cor.sh"
  head -c 3000 /dev/urandom | base64 > "$T/root/vendor/etc/ZYCustom.ini"
  u="$T/root/mnt/media_rw/USB1"; : > "$u/DESINSTALAR-SUITE.txt"
  roda nokey
  afirma '[ "$(telas)" = "aguarde escada-1 erro " ]' "telas: '$(telas)'"
  limpa

  novo_cenario "sem a suite (DESINSTALAR): auto em ordem = telas de antes"; aparelho_ok
  u="$T/root/mnt/media_rw/USB1"; : > "$u/DESINSTALAR-SUITE.txt"
  auto_on 0
  roda
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(nl_chamadas faixas)" = 1 ] && [ "$(nl_chamadas niveis)" = 1 ]' "chamadas da camera: $(grep '^nl_camcheck' "$T/calls.log" | tr '\n' '|')"
  afirma '[ "$(telas)" = "aguarde calibracao escada-1 pronto " ]' "telas: '$(telas)'"
  afirma '! grep -q "^HIDEBUG" "$T/calls.log"' "sem a suite ninguem chama o hidebug"
  limpa
}

# bloco 9C: o kit poe o app em /vendor/app/PFL7560 (app do sistema; o pm install do firmware
# recusa apps de fora) na janela rw do /vendor; falha nao para o kit
APPV(){ echo "$T/root/vendor/app/PFL7560"; }
c_app(){
  novo_cenario "app: ausente = vai para /vendor/app como app do sistema, antes da suite; 2a vez nao regrava"; aparelho_ok
  rm -rf "$(APPV)"
  roda nokey
  afirma 'cmp -s "$KIT/pfl7560.apk" "$(APPV)/PFL7560.apk" && ls -l "$(APPV)/PFL7560.apk" | grep -q "^-rw-r--r--"' "apk ausente, diferente ou fora de 0644 em vendor/app: $(ls -l "$(APPV)" 2>&1 | tr '\n' '|')"
  afirma 'ls -ld "$(APPV)" | grep -q "^drwxr-xr-x"' "pasta do app sem 0755"
  afirma 'tem_chamada "^chcon u:object_r:vendor_app_file:s0 .*vendor/app/.PFL7560.apk.new\$" && tem_chamada "^chcon u:object_r:vendor_app_file:s0 $(APPV)\$"' "sem chcon vendor_app_file: $(grep '^chcon' "$T/calls.log" | tr '\n' '|')"
  afirma '[ "$(chamadas "pm ")" = 0 ]' "usou o pm (recusado pelo firmware)"
  afirma '[ ! -e "$T/root/vendor/app/.PFL7560.apk.new" ] && [ ! -e "$T/root/data/vendor/pfl7560-suite/pfl7560.apk" ]' "sobrou .new ou o apk foi para a pasta da suite"
  afirma 'tem_chamada "^mount -o rw,remount /vendor" && tem_chamada "^mount -o ro,remount /vendor"' "gravou no /vendor sem o remount rw/ro"
  afirma '[ "$(grep -n "vendor_app_file" "$T/calls.log" | head -1 | cut -d: -f1)" -lt "$(grep -n "^am start" "$T/calls.log" | head -1 | cut -d: -f1)" ]' "o app nao entrou antes da primeira tela da suite"
  afirma 'log_tudo | grep -q "\[OK\] app: pfl7560.apk instalado como app do sistema" && log_tudo | grep -q "PROXIMO boot"' "log sem a instalacao ou sem o aviso do proximo boot"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ] && [ "$(pp_md5)" = "$PP0" ]' "o app mudou o fluxo do kit: telas '$(telas)'"
  : > "$T/calls.log"
  roda nokey
  afirma '! tem_chamada "^mount -o rw,remount /vendor" && log_tudo | grep -q "app: pfl7560.apk ja estava em /vendor/app/PFL7560"' "2a execucao abriu o /vendor ou regravou"
  limpa

  novo_cenario "app: home ausente = vai para /vendor/app/PFL7560Home; o outro app fica"; aparelho_ok
  rm -rf "$T/root/vendor/app/PFL7560Home"
  roda nokey
  afirma 'cmp -s "$KIT/pfl7560-home.apk" "$T/root/vendor/app/PFL7560Home/PFL7560Home.apk" && log_tudo | grep -q "\[OK\] app: pfl7560-home.apk instalado" && log_tudo | grep -q "app: pfl7560.apk ja estava"' "home: $(log_tudo | grep "app:" | tr '\n' '|')"
  limpa

  novo_cenario "home: prop da home no build.prop so com a home instalada; desinstalar tira"; aparelho_ok
  sed -i '/^vendor.newlink.launcher.package=/d' "$T/root/vendor/build.prop"; rm -rf "$T/root/vendor/app/PFL7560Home"
  roda nokey
  afirma '[ "$(grep -cx "vendor.newlink.launcher.package=com.pfl7560.home" "$T/root/vendor/build.prop")" = 1 ] && log_tudo | grep -q "\[OK\] home:"' "prop: $(grep launcher "$T/root/vendor/build.prop")"
  afirma '[ "$(grep -c "wifi_disconnect_on_boot=0" "$T/root/vendor/build.prop")" = 1 ]' "o build.prop perdeu o fix do wi-fi"
  : > "$T/root/mnt/media_rw/USB1/DESINSTALAR-SUITE.txt"
  roda nokey
  afirma '! grep -q "vendor.newlink.launcher.package" "$T/root/vendor/build.prop" && log_tudo | grep -q "home nova desligada"' "o desinstalar nao tirou a home: $(grep launcher "$T/root/vendor/build.prop")"
  limpa

  novo_cenario "home: o apk da home nao grava (cp falha) = a prop NAO e gravada"; aparelho_ok
  sed -i '/^vendor.newlink.launcher.package=/d' "$T/root/vendor/build.prop"; rm -rf "$T/root/vendor/app/PFL7560Home"
  # um diretorio no lugar do .new faz o cp do apk falhar
  mkdir -p "$T/root/vendor/app/.PFL7560Home.apk.new/x"
  roda nokey
  afirma '! grep -q "vendor.newlink.launcher.package" "$T/root/vendor/build.prop" && log_tudo | grep -q "a tela inicial continua a de fabrica"' "gravou a prop sem a home instalada: $(log_tudo | grep -i home | tr '\n' '|')"
  limpa
  afirma '[ ! -e "$T" ]' "a pasta do teste sobrou no /tmp: $T"

  novo_cenario "app: apk antigo em /vendor/app = atualiza"; aparelho_ok
  mkdir -p "$(APPV)"; echo velho > "$(APPV)/PFL7560.apk"
  roda nokey
  afirma 'cmp -s "$KIT/pfl7560.apk" "$(APPV)/PFL7560.apk" && log_tudo | grep -q "\[OK\] app:"' "nao atualizou"
  limpa

  novo_cenario "app: pasta do app e LINK = o link sai, o alvo fica intacto"; aparelho_ok
  rm -rf "$(APPV)"; mkdir -p "$T/alvo-app"; ln -s "$T/alvo-app" "$(APPV)"
  roda nokey
  afirma '[ -z "$(ls -A "$T/alvo-app")" ] && [ -d "$(APPV)" ] && [ ! -L "$(APPV)" ] && cmp -s "$KIT/pfl7560.apk" "$(APPV)/PFL7560.apk"' "seguiu o link ou nao instalou"
  limpa

  novo_cenario "app: remount do /vendor falha = o kit segue (cor, suite e telas como sempre)"; aparelho_ok
  rm -rf "$(APPV)"; : > "$T/mount-falha"
  roda nokey
  afirma '[ "$RC" = 0 ] && [ ! -e "$(APPV)/PFL7560.apk" ] && log_tudo | grep -q "servico de boot e app da suite NAO instalados"' "rc=$RC; sem o aviso"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ] && [ "$(pp_md5)" = "$PP0" ]' "a falha mudou o fluxo: telas '$(telas)'"
  limpa

  novo_cenario "app: DESINSTALAR-SUITE = nao mexe no app"; aparelho_ok
  rm -rf "$(APPV)"; : > "$T/root/mnt/media_rw/USB1/DESINSTALAR-SUITE.txt"
  roda nokey
  afirma '[ ! -e "$(APPV)" ] && ! grep -q "vendor_app_file" "$T/calls.log"' "mexeu no app ao desinstalar a suite"
  limpa

  novo_cenario "app: apk adulterado no pendrive = o kit aborta antes de instalar"; aparelho_ok
  rm -rf "$(APPV)"; printf 'X' >> "$T/root/mnt/media_rw/USB1/pfl7560.apk"
  roda nokey
  afirma '[ "$RC" != 0 ] && [ ! -e "$(APPV)" ] && log_tudo | grep -q "pfl7560.apk.*md5 diferente"' "rc=$RC; instalou apk adulterado"
  limpa
}

# bloco 14: sobreposicoes de tema (/vendor/overlay), prop do gerenciador de arquivos e marca MeowCast
OVLV(){ echo "$T/root/vendor/overlay"; }
S14(){ echo "$T/root/data/vendor/pfl7560-suite"; }
N_OVL="$(echo "$OVL_KIT" | wc -w | tr -d ' ')"
c_bloco14(){
  local e n
  novo_cenario "overlay: ausentes = todas vao para /vendor/overlay/<Nome>, a do android por ultimo, sem enable (e do boot); 2a vez nao regrava"; aparelho_ok
  rm -rf "$(OVLV)"
  roda nokey
  afirma '[ "$RC" = 0 ] && [ "$N_OVL" -ge 1 ]' "rc=$RC, lista de sobreposicoes vazia ($N_OVL)"
  for e in $OVL_KIT; do
    n="${e#*:}"
    afirma 'cmp -s "$KIT/${e%%:*}" "$(OVLV)/$n/$n.apk" && ls -l "$(OVLV)/$n/$n.apk" | grep -q "^-rw-r--r--" && ls -ld "$(OVLV)/$n" | grep -q "^drwxr-xr-x"' "$n ausente, diferente ou com modo errado: $(ls -lR "$(OVLV)/$n" 2>&1 | tr '\n' '|')"
    afirma 'tem_chamada "^chcon u:object_r:vendor_overlay_file:s0 $(OVLV)/$n\$" && tem_chamada "^chcon u:object_r:vendor_overlay_file:s0 .*vendor/overlay/.$n.apk.new\$"' "$n sem chcon vendor_overlay_file"
  done
  afirma '[ "$(log_tudo | grep -c "\[OK\] overlay: ")" = "$N_OVL" ]' "esperava $N_OVL instalacoes no log, achei $(log_tudo | grep -c "\[OK\] overlay: ")"
  afirma 'log_tudo | grep "\[OK\] overlay: " | tail -1 | grep -q "PFL7560TemaAndroid.apk"' "a do android nao foi a ultima: $(log_tudo | grep "\[OK\] overlay: " | tail -1 | cut -c1-80)"
  afirma 'log_tudo | grep "\[OK\] overlay: " | head -1 | grep -q "instalado como sobreposicao do sistema" && log_tudo | grep -q "PROXIMO boot"' "log sem a sobreposicao ou sem o aviso do proximo boot"
  afirma '! tem_chamada "^cmd overlay" && ! tem_chamada "^pm "' "o kit ligou a sobreposicao (isso e do suite-boot.sh, depois do boot) ou usou o pm"
  afirma 'tem_chamada "^mount -o rw,remount /vendor" && tem_chamada "^mount -o ro,remount /vendor"' "gravou sem o remount rw/ro"
  afirma '[ -z "$(find "$T/root/vendor" -name ".*.new")" ] && [ -z "$(find "$(S14)" -name "*.apk")" ]' "sobrou .new ou o apk foi para a pasta da suite"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ] && [ "$(pp_md5)" = "$PP0" ]' "as sobreposicoes mudaram o fluxo do kit: telas '$(telas)'"
  : > "$T/calls.log"
  roda nokey
  afirma '! tem_chamada "^mount -o rw,remount /vendor" && [ "$(log_tudo | grep -c "overlay: .* ja estava em /vendor/overlay/")" = "$N_OVL" ]' "2a execucao abriu o /vendor ou regravou"
  limpa

  novo_cenario "overlay: APK de versao antiga = atualiza so ele"; aparelho_ok
  e="$(echo "$OVL_KIT" | tr ' ' '\n' | head -1)"; n="${e#*:}"
  echo velho > "$(OVLV)/$n/$n.apk"
  roda nokey
  afirma 'cmp -s "$KIT/${e%%:*}" "$(OVLV)/$n/$n.apk" && [ "$(log_tudo | grep -c "\[OK\] overlay: ")" = 1 ]' "nao atualizou so o $n: $(log_tudo | grep "overlay:" | cut -c1-90 | tr '\n' '|')"
  limpa

  novo_cenario "overlay: um APK nao grava = os outros entram e o kit segue (cor, suite e telas como sempre)"; aparelho_ok
  e="$(echo "$OVL_KIT" | tr ' ' '\n' | head -1)"; n="${e#*:}"
  rm -rf "$(OVLV)/$n"; mkdir -p "$(OVLV)/.$n.apk.new/x"
  roda nokey
  afirma '[ "$RC" = 0 ] && [ ! -e "$(OVLV)/$n/$n.apk" ] && log_tudo | grep -q "AVISO.*overlay: nao consegui gravar o apk" && [ "$(log_tudo | grep -c "\[OK\] overlay: ")" = 0 ]' "rc=$RC; $(log_tudo | grep "overlay:" | cut -c1-90 | tr '\n' '|')"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ] && [ "$(pp_md5)" = "$PP0" ]' "a falha mudou o fluxo: telas '$(telas)'"
  chmod -R u+rwx "$(OVLV)" 2>/dev/null
  limpa

  novo_cenario "overlay: so uma pasta falha, as outras (e a do android) entram"; aparelho_ok
  e="$(echo "$OVL_KIT" | tr ' ' '\n' | head -1)"; n="${e#*:}"
  for x in $OVL_KIT; do [ "$x" != "$e" ] && rm -rf "$(OVLV)/${x#*:}"; done
  rm -rf "$(OVLV)/$n"
  # o primeiro nao grava (a pasta do .new e um diretorio); os demais, ausentes, entram
  mkdir -p "$(OVLV)/.$n.apk.new/x"
  roda nokey
  afirma '[ ! -e "$(OVLV)/$n/$n.apk" ] && [ "$(log_tudo | grep -c "\[OK\] overlay: ")" = "$((N_OVL - 1))" ]' "esperava $((N_OVL - 1)) instaladas: $(log_tudo | grep "overlay:" | cut -c1-90 | tr '\n' '|')"
  chmod -R u+rwx "$(OVLV)" 2>/dev/null
  limpa

  novo_cenario "overlay: pasta e LINK = o link sai, o alvo fica intacto"; aparelho_ok
  e="$(echo "$OVL_KIT" | tr ' ' '\n' | head -1)"; n="${e#*:}"
  rm -rf "$(OVLV)/$n"; mkdir -p "$T/alvo-ovl"; ln -s "$T/alvo-ovl" "$(OVLV)/$n"
  roda nokey
  afirma '[ -z "$(ls -A "$T/alvo-ovl")" ] && [ -d "$(OVLV)/$n" ] && [ ! -L "$(OVLV)/$n" ] && cmp -s "$KIT/${e%%:*}" "$(OVLV)/$n/$n.apk"' "seguiu o link ou nao instalou"
  limpa

  novo_cenario "overlay: remount do /vendor falha = nada do /vendor, mas a marca (que nao e do /vendor) entra e o kit segue"; aparelho_ok
  rm -rf "$(OVLV)"; echo orig > "$T/root/atv/bootvideo/logo.jpg"; : > "$T/mount-falha"
  roda nokey
  afirma '[ "$RC" = 0 ] && [ ! -e "$(OVLV)" ] && log_tudo | grep -q "NAO instalados"' "rc=$RC; sem o aviso"
  afirma 'cmp -s "$KIT/marca/logo.jpg" "$T/root/atv/bootvideo/logo.jpg"' "a marca nao entrou sem o /vendor"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ] && [ "$(pp_md5)" = "$PP0" ]' "a falha mudou o fluxo: telas '$(telas)'"
  limpa

  novo_cenario "overlay: APK adulterado NO PENDRIVE = o kit aborta antes de instalar"; aparelho_ok
  e="$(echo "$OVL_KIT" | tr ' ' '\n' | head -1)"; n="${e#*:}"
  rm -rf "$(OVLV)"; printf 'X' >> "$T/root/mnt/media_rw/USB1/${e%%:*}"
  roda nokey
  afirma '[ "$RC" != 0 ] && [ ! -e "$(OVLV)" ] && log_tudo | grep -q "${e%%:*}.*md5 diferente"' "rc=$RC; instalou apk adulterado"
  limpa

  novo_cenario "overlay: DESINSTALAR-SUITE = nao instala sobreposicao, prop nem marca"; aparelho_ok
  rm -rf "$(OVLV)"; sed -i '/^vendor.nl.filemanage_file=/d' "$T/root/vendor/build.prop"
  echo orig > "$T/root/atv/bootvideo/logo.jpg"
  : > "$T/root/mnt/media_rw/USB1/DESINSTALAR-SUITE.txt"
  roda nokey
  afirma '[ ! -e "$(OVLV)" ] && ! grep -q "vendor.nl.filemanage_file" "$T/root/vendor/build.prop" && [ "$(cat "$T/root/atv/bootvideo/logo.jpg")" = orig ]' "gravou algo do bloco 14 com a suite desinstalada"
  limpa

  # ---- prop do gerenciador de arquivos -----------------------------------------------------
  novo_cenario "gerenciador: prop ausente = gravada uma vez, o resto do build.prop fica; 2a vez nao regrava"; aparelho_ok
  sed -i '/^vendor.nl.filemanage_file=/d' "$T/root/vendor/build.prop"
  cp "$T/root/vendor/build.prop" "$T/bp-antes"
  roda nokey
  afirma '[ "$(grep -cx "vendor.nl.filemanage_file=1" "$T/root/vendor/build.prop")" = 1 ] && log_tudo | grep -q "\[OK\] gerenciador:"' "prop: $(grep filemanage "$T/root/vendor/build.prop")"
  afirma 'diff <(grep -v "^vendor.nl.filemanage_file=" "$T/root/vendor/build.prop") "$T/bp-antes" >/dev/null' "o build.prop perdeu ou ganhou outra linha"
  : > "$T/calls.log"
  roda nokey
  afirma '! tem_chamada "^mount -o rw,remount /vendor" && log_tudo | grep -q "gerenciador: a prop do gerenciador ja estava"' "2a execucao abriu o /vendor ou regravou"
  limpa

  novo_cenario "gerenciador: prop com outro valor (=0) = trocada, sem duplicar"; aparelho_ok
  sed -i 's/^vendor.nl.filemanage_file=1$/vendor.nl.filemanage_file=0/' "$T/root/vendor/build.prop"
  roda nokey
  afirma '[ "$(grep -c "^vendor.nl.filemanage_file=" "$T/root/vendor/build.prop")" = 1 ] && grep -qx "vendor.nl.filemanage_file=1" "$T/root/vendor/build.prop"' "prop: $(grep filemanage "$T/root/vendor/build.prop" | tr '\n' '|')"
  limpa

  novo_cenario "gerenciador: o build.prop nao grava = aviso, build.prop intacto, o kit segue"; aparelho_ok
  sed -i '/^vendor.nl.filemanage_file=/d' "$T/root/vendor/build.prop"
  cp "$T/root/vendor/build.prop" "$T/bp-antes"; mkdir -p "$T/root/vendor/build.prop.new/x"
  roda nokey
  afirma '[ "$RC" = 0 ] && cmp -s "$T/bp-antes" "$T/root/vendor/build.prop" && log_tudo | grep -q "AVISO.*gerenciador: nao consegui gravar" ' "rc=$RC; $(log_tudo | grep gerenciador | cut -c1-100)"
  afirma '[ "$(telas)" = "aguarde escada-1 calibracao pronto " ]' "a falha mudou o fluxo: telas '$(telas)'"
  chmod -R u+rwx "$T/root/vendor/build.prop.new" 2>/dev/null
  limpa

  # ---- marca MeowCast -------------------------------------------------------------------
  novo_cenario "marca: os de fabrica sao guardados UMA vez e os do kit gravados com cat (dono e rotulo ficam); 2a vez nada; firmware que os troca nao muda o backup"; aparelho_ok
  echo "logo de fabrica" > "$T/root/atv/bootvideo/logo.jpg"; echo "animacao de fabrica" > "$T/root/atv/bootvideo/bootanimation.zip"
  roda nokey
  afirma 'cmp -s "$KIT/marca/logo.jpg" "$T/root/atv/bootvideo/logo.jpg" && cmp -s "$KIT/marca/bootanimation.zip" "$T/root/atv/bootvideo/bootanimation.zip"' "a marca do kit nao foi gravada"
  afirma '[ "$(cat "$(S14)/marca-original/logo.jpg")" = "logo de fabrica" ] && [ "$(cat "$(S14)/marca-original/bootanimation.zip")" = "animacao de fabrica" ]' "backup dos originais errado: $(ls -l "$(S14)/marca-original" 2>&1 | tr '\n' '|')"
  afirma 'ls -ld "$(S14)/marca-original" | grep -q "^drwx------" && [ -z "$(find "$(S14)/marca-original" -name "*.new")" ]' "pasta do backup sem 0700 ou com .new"
  afirma 'log_tudo | grep -q "\[OK\] marca: logo.jpg gravado" && log_tudo | grep -q "\[OK\] marca: bootanimation.zip gravado"' "log sem a marca: $(log_tudo | grep marca | cut -c1-90 | tr '\n' '|')"
  afirma '! tem_chamada "^mount -o rw,remount /vendor"' "a marca abriu o /vendor sem precisar (o aparelho ja estava com tudo no /vendor)"
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(telas)" = "aguarde escada-1 calibracao pronto " ]' "a marca mudou o fluxo do kit: telas '$(telas)'"
  m1="$(stat -c %Y.%i "$(S14)/marca-original/logo.jpg")"
  : > "$T/calls.log"; roda nokey
  afirma 'log_tudo | grep -q "marca: logo.jpg ja estava igual ao do kit" && [ "$(stat -c %Y.%i "$(S14)/marca-original/logo.jpg")" = "$m1" ]' "2a execucao regravou: $(log_tudo | grep marca | cut -c1-90 | tr '\n' '|')"
  # o firmware (ou o dono) poe outro logo; o kit grava o dele de novo e o backup continua sendo o de fabrica
  echo "outro logo" > "$T/root/atv/bootvideo/logo.jpg"
  roda nokey
  afirma 'cmp -s "$KIT/marca/logo.jpg" "$T/root/atv/bootvideo/logo.jpg" && [ "$(cat "$(S14)/marca-original/logo.jpg")" = "logo de fabrica" ]' "o backup foi sobrescrito ou o logo nao voltou"
  limpa

  novo_cenario "marca: desinstalar restaura os de fabrica e a pasta da suite sai"; aparelho_ok
  echo "logo de fabrica" > "$T/root/atv/bootvideo/logo.jpg"; echo "animacao de fabrica" > "$T/root/atv/bootvideo/bootanimation.zip"
  roda nokey
  : > "$T/root/mnt/media_rw/USB1/DESINSTALAR-SUITE.txt"
  roda nokey
  afirma '[ "$(cat "$T/root/atv/bootvideo/logo.jpg")" = "logo de fabrica" ] && [ "$(cat "$T/root/atv/bootvideo/bootanimation.zip")" = "animacao de fabrica" ]' "nao restaurou: $(cat "$T/root/atv/bootvideo/logo.jpg" | head -c 30)"
  afirma 'log_tudo | grep -q "\[OK\] marca: logo.jpg de fabrica restaurado" && [ ! -e "$(S14)" ]' "log ou pasta da suite: $(log_tudo | grep marca | cut -c1-90 | tr '\n' '|')"
  limpa

  novo_cenario "marca: arquivo de fabrica ausente ou LINK = aviso, nada criado nem escrito no alvo do link"; aparelho_ok
  rm -f "$T/root/atv/bootvideo/bootanimation.zip" "$T/root/atv/bootvideo/logo.jpg"
  echo alvo > "$T/alvo-marca"; ln -s "$T/alvo-marca" "$T/root/atv/bootvideo/logo.jpg"
  roda nokey
  afirma '[ ! -e "$T/root/atv/bootvideo/bootanimation.zip" ] && [ "$(cat "$T/alvo-marca")" = alvo ] && [ -L "$T/root/atv/bootvideo/logo.jpg" ] && [ "$(log_tudo | grep -c "AVISO.*marca: ")" = 2 ]' "criou ou escreveu no link: $(log_tudo | grep marca | cut -c1-90 | tr '\n' '|')"
  afirma '[ "$RC" = 0 ] && [ "$(telas)" = "aguarde escada-1 calibracao pronto " ]' "o aviso parou o kit (rc=$RC)"
  limpa

  if [ "$(id -u)" != 0 ]; then
    novo_cenario "marca: o cat nao grava (arquivo somente leitura) = original mantido, aviso, o kit segue; desinstalar que nao restaura deixa o backup"; aparelho_ok
    echo "logo de fabrica" > "$T/root/atv/bootvideo/logo.jpg"; chmod 444 "$T/root/atv/bootvideo/logo.jpg"
    roda nokey
    afirma '[ "$(cat "$T/root/atv/bootvideo/logo.jpg")" = "logo de fabrica" ] && log_tudo | grep -q "AVISO.*marca: logo.jpg nao conferiu depois de gravar - voltei o original" && [ "$RC" = 0 ]' "rc=$RC; $(log_tudo | grep marca | cut -c1-110 | tr '\n' '|')"
    afirma 'cmp -s "$KIT/marca/bootanimation.zip" "$T/root/atv/bootvideo/bootanimation.zip"' "a falha de um impediu o outro"
    # liberado, o logo do kit entra; so leitura de novo, o desinstalar nao consegue devolver o de fabrica
    chmod 644 "$T/root/atv/bootvideo/logo.jpg"
    roda nokey
    chmod 444 "$T/root/atv/bootvideo/logo.jpg"
    : > "$T/root/mnt/media_rw/USB1/DESINSTALAR-SUITE.txt"
    roda nokey
    afirma 'log_tudo | grep -q "ERRO.*marca: nao consegui restaurar logo.jpg" && log_tudo | grep -q "a pasta da suite FICA" && [ "$(cat "$(S14)/marca-original/logo.jpg")" = "logo de fabrica" ]' "o backup sumiu com o restaura falho: $(log_tudo | grep marca | cut -c1-110 | tr '\n' '|')"
    chmod 644 "$T/root/atv/bootvideo/logo.jpg"
    limpa
  fi

  novo_cenario "marca: arquivo da marca adulterado NO PENDRIVE = o kit aborta antes de gravar"; aparelho_ok
  echo "logo de fabrica" > "$T/root/atv/bootvideo/logo.jpg"; printf 'X' >> "$T/root/mnt/media_rw/USB1/marca/logo.jpg"
  roda nokey
  afirma '[ "$RC" != 0 ] && [ "$(cat "$T/root/atv/bootvideo/logo.jpg")" = "logo de fabrica" ] && log_tudo | grep -q "marca/logo.jpg.*md5 diferente"' "rc=$RC; gravou marca adulterada"
  limpa

  # ---- desinstalar leva o bloco 14 de volta -------------------------------------------------------
  novo_cenario "desinstalar: sobreposicoes, prop do gerenciador e marca voltam ao de fabrica; o resto do /vendor fica"; aparelho_ok
  echo "logo de fabrica" > "$T/root/atv/bootvideo/logo.jpg"; echo "animacao de fabrica" > "$T/root/atv/bootvideo/bootanimation.zip"
  roda nokey
  afirma 'log_tudo | grep -q "marca: logo.jpg gravado"' "preparo: a marca nao foi gravada"
  : > "$T/root/mnt/media_rw/USB1/DESINSTALAR-SUITE.txt"
  roda nokey
  afirma '[ -z "$(ls -d "$(OVLV)"/PFL7560Tema* 2>/dev/null)" ] && log_tudo | grep -q "\[OK\] sobreposicoes de tema removidas"' "sobrou sobreposicao: $(ls "$(OVLV)" 2>&1 | tr '\n' ' ')"
  afirma '! grep -q "vendor.nl.filemanage_file" "$T/root/vendor/build.prop" && log_tudo | grep -q "\[OK\] gerenciador de arquivos: prop tirada"' "a prop do gerenciador ficou"
  afirma 'grep -q "wifi_disconnect_on_boot=0" "$T/root/vendor/build.prop"' "o desinstalar levou o fix do wi-fi junto"
  afirma 'tem_chamada "^mount -o rw,remount /vendor" && tem_chamada "^mount -o ro,remount /vendor"' "tirou sem o remount rw/ro"
  limpa
}

c_estaticos(){
  CASO="estaticos"; SHELL_NOME="-"
  local f
  for f in "$KIT/newlink_update.sh" "$KIT/cor.sh" "$KIT/LEIA-ME.txt"; do
    afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$f")" ]' "$(basename "$f") tem caractere fora de ASCII"
    afirma '[ "$(grep -c $'"'"'\r'"'"' "$f")" = 0 ]' "$(basename "$f") tem CRLF"
  done
  afirma 'head -1 "$KIT/newlink_update.sh" | grep -q "^#!/vendor/bin/sh$" && head -1 "$KIT/cor.sh" | grep -q "^#!/vendor/bin/sh$"' "shebang"
  for f in "$KIT/newlink_update.sh" "$KIT/cor.sh"; do
    afirma 'dash -n "$f"' "dash -n $(basename "$f")"
    afirma 'busybox sh -n "$f"' "busybox sh -n $(basename "$f")"
    afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qE "\[\[ |\$\{[A-Za-z_]+//|(^|[ ;])source |(^|[ ;])local |echo -n|<<<"' "bashismo em $(basename "$f")"
  done
  if command -v shellcheck >/dev/null 2>&1; then
    afirma 'shellcheck -s sh "$KIT/newlink_update.sh" "$KIT/cor.sh"' "shellcheck -s sh"
  else
    echo "  (shellcheck ausente: etapa pulada)"
  fi
  afirma 'bash "$ROOT/tests/atualizar-md5-kit.sh" --check >/dev/null' "lista md5 embutida desatualizada"
  local lista_ini; lista_ini="$(sed -n 's/^KIT_LISTA="\([0-9a-f]*\)  ZYCustom.ini$/\1/p' "$KIT/newlink_update.sh")"
  afirma '[ "$lista_ini" = "$(grep ^INI_MD5_OK= "$KIT/newlink_update.sh" | cut -d\" -f2)" ]' "INI_MD5_OK difere do md5 da lista"
  afirma '[ "$(md5 "$KIT/ZYCustom.ini")" = 252ab7a72a007a8b79b3fc86bd5c0d19 ]' "ZYCustom.ini do pendrive mudou"
  # bloco 6: os md5 do modelo sem USB-C embutidos batem com os artefatos versionados
  afirma '[ "$(grep ^INI_MD5_OK_NOTYPEC= "$KIT/newlink_update.sh" | cut -d\" -f2)" = "$(md5 "$ROOT/artifacts/ZYCustom_390.NOTYPEC.ini")" ]' "INI_MD5_OK_NOTYPEC difere do artefato corrigido"
  afirma '[ "$(grep ^INI_MD5_FABRICA_NOTYPEC= "$KIT/newlink_update.sh" | cut -d\" -f2)" = "$(md5 "$ROOT/artifacts/ZYCustom.ini.NOTYPEC.STOCK")" ]' "INI_MD5_FABRICA_NOTYPEC difere do ini de fabrica novo versionado"
  afirma '[ "$(grep ^INI_MD5_FABRICA= "$KIT/newlink_update.sh" | cut -d\" -f2)" = "$(md5 "$ROOT/artifacts/ZYCustom.ini.ORIGINAL")" ]' "INI_MD5_FABRICA difere do ini de fabrica antigo versionado"
  afirma '! grep -vE "^[[:space:]]*#" "$KIT/newlink_update.sh" | grep -qw awk' "o newlink_update.sh usa awk (o shell do aparelho so garante sed/grep/head/tail)"
  afirma '[ "$(md5 "$KIT/lvdsctl")" = 178d812872cb9306c0ae6faeed07184a ]' "lvdsctl do kit com md5 errado"
  # bloco 9C: o apk do kit e o de artifacts/app; o versionCode do kit e o do build.sh (e o do apk, se ha aapt2)
  afirma 'cmp -s "$KIT/pfl7560.apk" "$ROOT/artifacts/app/pfl7560.apk"' "pfl7560.apk do kit difere do de artifacts/app"
  afirma '[ -n "$APP_VC" ] && [ "$APP_VC" = "$(sed -n "s/^VERSAO_CODIGO=\([0-9]*\) .*/\1/p" "$ROOT/artifacts/app/build.sh")" ]' "APP_VERSION_CODE do newlink_update.sh difere do VERSAO_CODIGO do build.sh"
  local aapt2
  # shellcheck disable=SC2012  # nomes sem espaco; o ls so acha o aapt2 do SDK local
  aapt2="$(command -v aapt2 || ls "${ANDROID_SDK:-$HOME/Android/sdk}"/build-tools/*/aapt2 2>/dev/null | tail -1)"
  if [ -n "$aapt2" ]; then
    afirma '"$aapt2" dump badging "$KIT/pfl7560.apk" | grep -q "^package: name='"'"'com.pfl7560.verificar'"'"' versionCode='"'"'$APP_VC'"'"'"' "versionCode do apk difere do APP_VERSION_CODE"
    afirma '[ "$("$aapt2" dump badging "$KIT/pfl7560.apk" | grep -c "^launchable-activity")" = 2 ] && [ "$("$aapt2" dump badging "$KIT/pfl7560.apk" | grep -c "^leanback-launchable-activity")" = 2 ]' "o apk nao tem as duas atividades com LAUNCHER e LEANBACK_LAUNCHER"
    afirma '[ -z "$("$aapt2" dump permissions "$KIT/pfl7560.apk" | grep "^uses-permission")" ] && "$aapt2" dump badging "$KIT/pfl7560.apk" | grep -q "^targetSdkVersion:.28."' "o apk pede permissao ou nao tem targetSdk 28"
  else
    echo "  (aapt2 ausente: conferencia do versionCode do apk pulada)"
  fi
  afirma '[ "$(sed -n "s/^LVDSCTL_MD5=\"\([0-9a-f]*\)\"$/\1/p" "$KIT/cor.sh")" = "$(md5 "$KIT/lvdsctl")" ]' "LVDSCTL_MD5 do cor.sh difere do md5 do lvdsctl"
  afirma '[ "$(sed -n "s/^NLCAM_MD5=\"\([0-9a-f]*\)\"$/\1/p" "$KIT/cor.sh")" = "$(md5 "$KIT/nl_camcheck")" ]' "NLCAM_MD5 do cor.sh difere do md5 do nl_camcheck do kit"
  afirma 'cmp -s "$KIT/nl_camcheck" "$ROOT/artifacts/camcheck/nl_camcheck"' "nl_camcheck do kit difere do versionado em artifacts/camcheck"
  afirma '[ ! -e "$KIT/kit/metades-1.png" ] && [ ! -e "$KIT/kit/metades-2.png" ]' "metades-*.png ainda no kit"
  afirma '! grep -q "data/local/tmp/pfl7560-kit" "$KIT/cor.sh" "$KIT/newlink_update.sh"' "script ainda usa a pasta gravavel pelo shell"
  afirma 'git -C "$ROOT" diff --quiet HEAD -- artifacts/lcd-color-fix/lvdsctl artifacts/lcd-color-fix/lvdsctl.c' "lvdsctl/lvdsctl.c de artifacts foram alterados"
  for f in cor.sh newlink_update.sh LEIA-ME.txt lvdsctl nl_camcheck pfl7560.apk kit/escada-1.png kit/calibracao.png kit/corrigida.png; do
    afirma 'git -C "$ROOT" check-attr byte-exact -- "pendrive-autorun/$f" | grep -q "byte-exact: set"' "$f nao esta como byte-exact no .gitattributes"
  done
  afirma 'python3 -I "$ROOT/tests/simula-padroes-kit.py" >/dev/null' "simulacao dos padroes falhou"
  # bloco 14: o kit leva TODOS os APKs de artifacts/overlay/apk (nenhum a mais, nenhum a menos), com a
  # do android por ultimo, e a marca; tudo na KIT_LISTA e byte-exact
  afirma '[ "$(echo "$OVL_KIT" | wc -w | tr -d " ")" = "$(ls "$ROOT"/artifacts/overlay/apk/*.apk | wc -l | tr -d " ")" ]' "KIT_OVERLAYS nao tem um item por APK de artifacts/overlay/apk"
  afirma '[ "$(echo "$OVL_KIT" | tr " " "\n" | tail -1)" = "overlay/PFL7560TemaAndroid.apk:PFL7560TemaAndroid" ]' "a sobreposicao do android nao e a ultima de KIT_OVERLAYS"
  for f in $OVL_KIT; do
    afirma 'cmp -s "$ROOT/artifacts/overlay/apk/${f#*:}.apk" "$KIT/${f%%:*}"' "${f%%:*} do kit difere do de artifacts/overlay/apk"
    afirma 'grep -q "  ${f%%:*}\$" <(sed -n "/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p" "$KIT/newlink_update.sh")' "${f%%:*} fora da KIT_LISTA"
  done
  for f in marca/logo.jpg marca/bootanimation.zip; do
    afirma 'cmp -s "$KIT/$f" "$ROOT/artifacts/tema/$f" && grep -q "  $f\$" <(sed -n "/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p" "$KIT/newlink_update.sh")' "$f difere de artifacts/tema/marca ou esta fora da KIT_LISTA"
  done
  afirma 'git -C "$ROOT" check-attr byte-exact -- pendrive-autorun/overlay/PFL7560TemaAndroid.apk pendrive-autorun/marca/logo.jpg | grep -c "byte-exact: set" | grep -qx 2' "overlay/ e marca/ nao estao como byte-exact no .gitattributes"
  afirma '! git -C "$ROOT" check-ignore -q pendrive-autorun/marca/bootanimation.zip' "o .gitignore (*.zip) esconde marca/bootanimation.zip"
  # LEIA-ME: fluxo de leigo com ate 5 passos numerados e todos os arquivos do kit citados
  afirma '[ "$(sed -n "/^COMO USAR/,/^  Resultado da parte termica/p" "$KIT/LEIA-ME.txt" | grep -cE "^  [0-9]\. ")" = 5 ]' "o fluxo do LEIA-ME nao tem exatamente 5 passos"
  for f in newlink_update.sh cor.sh lvdsctl nl_camcheck nl_tela pfl7560.apk fontes ZYCustom.ini kit DESINSTALAR-SUITE.txt incompletas suite-panelparam-backup; do
    afirma 'grep -q "$f" "$KIT/LEIA-ME.txt"' "LEIA-ME nao cita $f"
  done
}

# ---------------------------------------------------------------------------
echo "== estaticos =="
c_estaticos
echo "== instaladores (E3c) =="
c_instalador

for SHELL_NOME in ${SHELLS:-dash}; do
  case "$SHELL_NOME" in
    dash) SHELL_BIN=dash; SHELL_BIN_RUN="dash" ;;
    busybox) SHELL_BIN=busybox; SHELL_BIN_RUN="busybox sh" ;;
  esac
  command -v "$SHELL_BIN" >/dev/null 2>&1 || { echo "(sem $SHELL_BIN: pulado)"; continue; }
  echo "== cenarios sob $SHELL_NOME =="
  for c in ${CASOS:-c_sem_tecla c_tecla_timeout c_tecla_tecla c_idempotencia c_ini_anterior c_ini_desconhecido \
           c_atv_override c_adulterado c_journal_no_boot c_gancho_gerado c_trabalho_inseguro c_troca_apos_copia c_troca_no_pendrive c_lvdsctl_na_hora c_backup_adulterado c_gancho_adulterado c_ambiente_sem_teste c_falhas_seguras c_sem_hidebug \
           c_modelo_antigo_secoes c_modelo_novo_secoes c_modelo_novo_desconhecido c_secoes_resultado_errado \
           c_auto_certo c_auto_errado c_auto_duvida c_auto_nlcam_adulterado c_troca_de_tela c_modo_auto_ambiente c_sem_suite_legado c_app c_bloco14}; do
    echo "  $c"
    "$c"
  done
done

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
