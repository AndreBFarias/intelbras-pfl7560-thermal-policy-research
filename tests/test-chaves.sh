#!/usr/bin/env bash
# Teste das chaves de ajuste do sistema (bloco 24): pendrive-autorun/suite-chaves.sh e os ganchos no
# suite-pedido.sh, suite-boot.sh, suite.sh (desinstalar) e newlink_update.sh (DESLIGAR-CHAVES.txt).
# Tudo em simulacao: um "aparelho" em pasta temporaria (PFL_ROOT) e comandos de mentira no PATH.
# Nenhum teste fala com o projetor.
# shellcheck disable=SC2016
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
FALHAS=0
TESTES=0
CASO=""
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }

IDS="deb_seg deb_ota deb_hisi deb_lnch deb_vlc log_vplug eth0 wifi_pwr web_cmd keystone"
GRUPOS_PKG="com.newlink.autotest com.newlink.factorymenu com.newlink.tvtestingtools com.hikeymasterprovision com.newlink.isuperred.ijkplayerdemo com.android.location.fused com.newlink.service com.newlink.service2 com.hisilicon.android.music com.hisilicon.android.videoplayer com.hisilicon.tvui com.hisilicon.tv.menu com.newlink.hisilauncher org.videolan.vlc com.mobisystems.editor.office_registered"
# pacotes que NENHUMA chave pode tocar, mesmo instalados
INTOCAVEIS="com.hisilicon.higallery com.hisilicon.tvsetting com.newlink.screensaver com.newlink.nlprovision com.newlink.hotkeysservices com.pfl7560.verificar com.pfl7560.home com.android.systemui com.google.android.gms com.zhiying.settings com.newlink.filemanager"

stub(){ printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
novo_cenario(){
  CASO="$1"
  T="$(mktemp -d)"
  R="$T/root"; S="$R/data/vendor/pfl7560-suite"; PEDH="$R/data/data/com.pfl7560.home"
  local b="$T/bin" p
  mkdir -p "$R/dev" "$R/data/vendor" "$R/data/data" "$b" "$R/sys/class/net/eth0" "$R/sys/class/net/wlan0" \
           "$R/sys/bus/usb/devices/1-3/power" "$R/sys/bus/usb/devices/1-3:1.0/power" "$R/sys/bus/usb/devices/1-1/power"
  mkdir -p "$S"; chmod 700 "$S"
  echo 0x1003 > "$R/sys/class/net/eth0/flags"
  echo a69c > "$R/sys/bus/usb/devices/1-3/idVendor"; echo 8d81 > "$R/sys/bus/usb/devices/1-3/idProduct"
  echo on > "$R/sys/bus/usb/devices/1-3/power/control"
  echo a69c > "$R/sys/bus/usb/devices/1-3:1.0/idVendor"; echo 8d81 > "$R/sys/bus/usb/devices/1-3:1.0/idProduct"
  echo on > "$R/sys/bus/usb/devices/1-3:1.0/power/control"
  echo 1d6b > "$R/sys/bus/usb/devices/1-1/idVendor"; echo 0002 > "$R/sys/bus/usb/devices/1-1/idProduct"
  echo on > "$R/sys/bus/usb/devices/1-1/power/control"
  : > "$T/calls.log"; : > "$T/pm-desligados"; : > "$T/pm-instalados"
  for p in $GRUPOS_PKG $INTOCAVEIS; do echo "$p" >> "$T/pm-instalados"; done
  printf '%s\n' ro.product.model=PFL7560 init.svc.boa=running init.svc.cmdsrv=running persist.hisi.keystone.enable=true \
    sys.boot.reason=shutdown,userrequested persist.sys.boot.reason=shutdown,userrequested ro.boot.bootreason=shutdown,userrequested > "$T/props"
  stub getprop 'awk -v k="$1" '"'"'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }'"'"' "$T/props"'
  stub setprop 'echo "setprop $1 ${2:-}" >> "$T/calls.log"
awk -v k="$1" '"'"'index($0, k "=") != 1'"'"' "$T/props" > "$T/props.novo"
printf "%s=%s\n" "$1" "${2:-}" >> "$T/props.novo"; mv "$T/props.novo" "$T/props"'
  stub pm 'echo "pm $*" >> "$T/calls.log"
[ -f "$T/pm-mudo" ] && exit 0
case "$1 $2" in
  "list packages")
    if [ "$3" = "-d" ]; then sed "s/^/package:/" "$T/pm-desligados"; exit 0; fi
    echo package:android; sed "s/^/package:/" "$T/pm-instalados"; exit 0 ;;
  "disable-user --user")
    [ -f "$T/pm-disable-falha" ] && exit 1
    grep -qx "$4" "$T/pm-desligados" || echo "$4" >> "$T/pm-desligados"; exit 0 ;;
  "enable --user") sed -i "/^$4\$/d" "$T/pm-desligados"; exit 0 ;;
esac
exit 0'
  stub ip 'echo "ip $*" >> "$T/calls.log"
[ -f "$T/ip-falha" ] && exit 1
if [ "$1 $2 $3 $4" = "link set eth0 down" ]; then echo 0x1002 > "$PFL_ROOT/sys/class/net/eth0/flags"; fi
if [ "$1 $2 $3 $4" = "link set eth0 up" ]; then echo 0x1003 > "$PFL_ROOT/sys/class/net/eth0/flags"; fi
exit 0'
  stub stop 'echo "stop $*" >> "$T/calls.log"; [ -f "$T/svc-falha" ] && exit 1
awk -v k="init.svc.$1" '"'"'index($0, k "=") != 1'"'"' "$T/props" > "$T/props.novo"; echo "init.svc.$1=stopped" >> "$T/props.novo"; mv "$T/props.novo" "$T/props"'
  stub start 'echo "start $*" >> "$T/calls.log"
awk -v k="init.svc.$1" '"'"'index($0, k "=") != 1'"'"' "$T/props" > "$T/props.novo"; echo "init.svc.$1=running" >> "$T/props.novo"; mv "$T/props.novo" "$T/props"'
  stub sleep 'echo "sleep $*" >> "$T/calls.log"'
  stub gtt 'echo "GTT $*" >> "$T/calls.log"'
  stub logcat 'echo "logcat $*" >> "$T/calls.log"'
  stub reboot 'echo "reboot" >> "$T/calls.log"'
  ln -sf "$(command -v dash)" "$b/sh"
  export T
}
limpa(){ if [ -n "${DEBUG_KEEP:-}" ]; then echo "  (mantido: $T)"; else rm -rf "$T"; fi; }
amb(){
  env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_RAPIDO=1 PFL_ROOT="$R" PFL_PM_ESPERA=0 PFL_PM_TENTATIVAS=3 \
      PFL_APP_UID_MIN=0 PFL_VIGIA_VOLTAS=2 PATH="$T/bin:$PATH" "$@"
}
instala(){
  local f
  for f in suite-chaves.sh suite-pedido.sh suite-boot.sh suite-curvas.sh; do cp "$KIT/$f" "$S/$f"; chmod 755 "$S/$f"; done
  cp "$KIT/debloat-aprovados.txt" "$S/debloat-aprovados.txt"; chmod 600 "$S/debloat-aprovados.txt"
  mkdir -p "$PEDH"
}
ch(){ amb dash "$S/suite-chaves.sh" "$@" > "$T/ch.out" 2>&1; RC=$?; }
estado(){ amb dash "$S/suite-chaves.sh" estado 2>/dev/null | head -n 1; }
pos(){ local i=1 n; for n in $IDS; do [ "$n" = "$1" ] && { echo "$i"; return; }; i=$((i+1)); done; }
car(){ estado | cut -c"$(pos "$1")"; }
prop_(){ awk -v k="$1" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' "$T/props"; }
tem_chamada(){ grep -qF -- "$1" "$T/calls.log" 2>/dev/null; }
desligado(){ grep -qx "$1" "$T/pm-desligados"; }
escolha(){ sed -n "s/^$1=//p" "$S/chaves.escolhas" 2>/dev/null | tail -n 1; }
tudo_ligado(){ local i; for i in $IDS; do ch aplicar "$i" ligar; done; }

c_estaticos(){
  CASO="estaticos"
  local f="$KIT/suite-chaves.sh"
  afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$f")" ]' "suite-chaves.sh tem byte fora de ASCII"
  afirma '[ "$(grep -c $'"'"'\r'"'"' "$f")" = 0 ]' "suite-chaves.sh tem CRLF"
  afirma 'head -1 "$f" | grep -qx "#!/vendor/bin/sh"' "shebang"
  afirma 'dash -n "$f" && bash -n "$f" && busybox sh -n "$f"' "sintaxe sh"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qE "\[\[ |\$\{[A-Za-z_]+//|(^|[ ;])source |(^|[ ;])local |echo -n|<<<"' "bashismo"
  afirma 'grep -q "^  PATH=\"/system/bin:/system/xbin:/vendor/bin:/vendor/xbin\"; export PATH$" "$f"' "sem o PATH fixo"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qwE "gtt|stp|logcat|adb|hidebug"' "cita gtt/stp/logcat/adb/hidebug fora de comentario"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qE "pm (uninstall|clear|hide)|rm -rf /(data|system|vendor)[^$]"' "comando destrutivo"
  afirma 'git -C "$ROOT" check-attr byte-exact -- pendrive-autorun/suite-chaves.sh | grep -q "byte-exact: set"' "fora do .gitattributes byte-exact"
  if command -v shellcheck >/dev/null 2>&1; then
    afirma 'shellcheck -s sh "$f" "$KIT/suite-pedido.sh" "$KIT/suite-boot.sh" "$KIT/suite.sh" "$KIT/newlink_update.sh"' "shellcheck -s sh"
    afirma 'shellcheck "$ROOT/tests/test-chaves.sh"' "shellcheck do teste"
  else
    echo "  (shellcheck ausente: etapa pulada)"
  fi
  afirma 'bash "$ROOT/tests/atualizar-md5-kit.sh" --check >/dev/null' "listas md5 desatualizadas"
  afirma '[ "$(sed -n "s/^CHAVES_MD5=\"\(.*\)\"$/\1/p" "$KIT/suite-boot.sh")" = "$(md5 "$f")" ] && [ "$(sed -n "s/^CHAVES_MD5=\"\(.*\)\"$/\1/p" "$KIT/suite-pedido.sh")" = "$(md5 "$f")" ]' "CHAVES_MD5 embutido em boot/pedido difere do script"
  afirma 'sed -n "/^# SUITE_LISTA_INICIO/,/^# SUITE_LISTA_FIM/p" "$KIT/suite.sh" | grep -q "^$(md5 "$f")  suite-chaves.sh$"' "suite-chaves.sh fora da SUITE_LISTA do suite.sh"
  afirma 'sed -n "/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p" "$KIT/newlink_update.sh" | grep -q "^$(md5 "$f")  suite-chaves.sh$"' "suite-chaves.sh fora da KIT_LISTA"
  afirma 'grep -q "^KIT_EXEC=.* suite-chaves.sh" "$KIT/newlink_update.sh"' "suite-chaves.sh fora da KIT_EXEC"
  # o desinstalar chama o resgate antes de apagar a pasta
  afirma 'grep -q "sh \"\$SUITE/suite-chaves.sh\" resgate" "$KIT/suite.sh"' "desinstalar nao chama o resgate das chaves"
  afirma 'grep -q "com.pfl7560.home/chave\"" "$KIT/suite.sh"' "desinstalar nao apaga o pedido chave da home"
  # nenhuma lista de grupo traz um pacote intocavel
  local g p lista
  for p in $INTOCAVEIS; do
    afirma '! grep -E "^    deb_[a-z]+\) echo " "$f" | grep -qw "$p"' "grupo de debloat cita $p (intocavel)"
  done
  lista=$(grep -E '^    deb_[a-z]+\) echo ' "$f" | tr -d '"' | tr ' ' '\n' | grep -E '^(com|org)\.' | sort -u | tr '\n' ' ')
  for g in $GRUPOS_PKG; do afirma 'printf "%s\n" "$lista" | tr " " "\n" | grep -qx "$g"' "grupo da tabela sem $g"; done
  afirma '[ "$(printf "%s\n" "$lista" | wc -w)" = "$(printf "%s\n" "$GRUPOS_PKG" | wc -w)" ]' "grupos tem pacote a mais ou a menos que a tabela: $lista"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qE "com.newlink.screensaver" || grep -E "^    com.newlink.screensaver" "$f" | grep -q "return 1"' "screensaver fora da lista de negacao"
}

c_ler(){
  novo_cenario "ler: estado inicial lido do aparelho"
  instala
  ch estado
  afirma '[ "$(estado)" = "0000000000" ]' "estado inicial: $(estado)"
  ch ler
  afirma '[ "$RC" = 0 ] && [ "$(prop_ vendor.pfl7560.chaves)" = "0000000000" ]' "prop chaves: '$(prop_ vendor.pfl7560.chaves)'"
  # parcial, ligada e ausente
  echo com.newlink.autotest >> "$T/pm-desligados"
  afirma '[ "$(car deb_seg)" = p ]' "um pacote desligado de seis = p: $(estado)"
  for p in com.newlink.service com.newlink.service2; do echo "$p" >> "$T/pm-desligados"; done
  afirma '[ "$(car deb_ota)" = 1 ]' "grupo todo desligado = 1: $(estado)"
  grep -v '^com.hisilicon' "$T/pm-instalados" > "$T/x"; mv "$T/x" "$T/pm-instalados"
  afirma '[ "$(car deb_hisi)" = - ]' "grupo sem nenhum pacote instalado = -: $(estado)"
  echo 0x1002 > "$R/sys/class/net/eth0/flags"
  afirma '[ "$(car eth0)" = 1 ]' "eth0 sem o bit UP = 1: $(estado)"
  echo auto > "$R/sys/bus/usb/devices/1-3/power/control"
  afirma '[ "$(car wifi_pwr)" = 1 ]' "power/control=auto = 1"
  rm -rf "$R/sys/bus/usb/devices/1-3"
  afirma '[ "$(car wifi_pwr)" = - ]' "sem o USB do AIC8800 = -"
  afirma '[ "$(car web_cmd)" = 0 ]' "servicos rodando = 0"
  echo "init.svc.boa=stopped" >> "$T/props"
  afirma '[ "$(car web_cmd)" = p ]' "so um servico parado = p: $(estado)"
  rm -rf "$R/sys/class/net/eth0"
  afirma '[ "$(car eth0)" = - ]' "sem eth0 = -"
  echo "log.tag.HI_VPLUGIN=S" >> "$T/props"
  afirma '[ "$(car log_vplug)" = 1 ]' "log.tag.HI_VPLUGIN=S = 1"
  echo "persist.hisi.keystone.enable=false" >> "$T/props"
  afirma '[ "$(car keystone)" = 1 ]' "keystone false = 1"
  : > "$T/pm-mudo"; sed -i '/^$/d' "$T/pm-instalados"
  # pm que nao responde ao 'list': estado ilegivel, nunca suposto
  stub pm 'exit 1'
  afirma '[ "$(car deb_seg)" = "?" ]' "pm mudo = ?: $(estado)"
  limpa
}

c_aplicar(){
  local i
  novo_cenario "aplicar: cada chave liga, le o estado real e volta pela mesma chave"
  instala
  for i in $IDS; do
    ch aplicar "$i" ligar
    afirma '[ "$RC" = 0 ]' "aplicar $i ligar saiu com $RC: $(tr '\n' '|' < "$T/ch.out")"
    afirma '[ "$(car "$i")" = 1 ]' "$i nao ficou ligada: $(estado)"
    afirma '[ "$(escolha "$i")" = 1 ]' "escolha de $i nao guardada"
    afirma '[ "$(prop_ vendor.pfl7560.chaves_aviso | cut -d: -f1,2)" = "$i:ok" ]' "aviso de $i: $(prop_ vendor.pfl7560.chaves_aviso)"
    afirma '[ "$(prop_ vendor.pfl7560.chaves | cut -c"$(pos "$i")")" = 1 ]' "prop chaves nao mostra $i ligada: $(prop_ vendor.pfl7560.chaves)"
  done
  afirma '[ "$(estado)" = "1111111111" ]' "todas ligadas: $(estado)"
  for i in $IDS; do
    ch aplicar "$i" desligar
    afirma '[ "$(car "$i")" = 0 ]' "$i nao voltou: $(estado)"
    afirma '[ "$(escolha "$i")" = 0 ]' "escolha de $i nao virou 0"
  done
  afirma '[ "$(estado)" = "0000000000" ]' "tudo de volta: $(estado)"
  afirma '[ ! -s "$T/pm-desligados" ]' "sobrou pacote desligado: $(tr '\n' ' ' < "$T/pm-desligados")"
  afirma '[ "$(cat "$R/sys/bus/usb/devices/1-3/power/control")" = on ] && [ "$(cat "$R/sys/class/net/eth0/flags")" = 0x1003 ]' "porta/chip nao voltaram"
  afirma '[ "$(prop_ log.tag.HI_VPLUGIN)" = "" ] && [ "$(prop_ persist.hisi.keystone.enable)" = true ]' "props nao voltaram"
  afirma 'tem_chamada "setprop log.tag.HI_VPLUGIN S" && tem_chamada "ip link set eth0 down" && tem_chamada "stop boa" && tem_chamada "stop cmdsrv" && tem_chamada "setprop persist.hisi.keystone.enable false"' "comandos esperados nao rodaram"
  afirma '[ "$(cat "$R/sys/bus/usb/devices/1-3:1.0/power/control")" = on ] && [ "$(cat "$R/sys/bus/usb/devices/1-1/power/control")" = on ]' "tocou em interface ou em outro dispositivo USB"
  afirma '! grep -q "^GTT\|^logcat\|^reboot" "$T/calls.log"' "gtt/logcat/reboot chamado"
  afirma '[ ! -d "$R/dev/pfl7560-chaves.trava" ]' "a trava ficou"
  # chip Wi-Fi achado pelo id, nao pelo 1-3
  mv "$R/sys/bus/usb/devices/1-3" "$R/sys/bus/usb/devices/2-1"
  ch aplicar wifi_pwr ligar
  afirma '[ "$(cat "$R/sys/bus/usb/devices/2-1/power/control")" = auto ]' "nao achou o chip pelo id (2-1)"
  echo 8d80 > "$R/sys/bus/usb/devices/2-1/idProduct"
  afirma '[ "$(car wifi_pwr)" = 1 ]' "id a69c:8d80 tambem vale"
  echo 1234 > "$R/sys/bus/usb/devices/2-1/idProduct"
  ch aplicar wifi_pwr desligar
  afirma '[ "$RC" = 2 ] && [ "$(cat "$R/sys/bus/usb/devices/2-1/power/control")" = auto ]' "id errado: nao devia ter mexido (rc=$RC)"
  limpa

  novo_cenario "aplicar: recusas e falhas nao mentem"
  instala
  ch aplicar nao_existe ligar
  afirma '[ "$RC" = 1 ] && [ ! -e "$S/chaves.escolhas" ]' "id desconhecido aceito"
  ch aplicar eth0 talvez
  afirma '[ "$RC" = 1 ] && [ ! -e "$S/chaves.escolhas" ]' "acao invalida aceita"
  : > "$T/pm-disable-falha"; rm -f "$T/pm-disable-falha"
  touch "$T/pm-disable-falha"
  ch aplicar deb_seg ligar
  afirma '[ "$RC" = 1 ] && [ "$(prop_ vendor.pfl7560.chaves_aviso | cut -d: -f1,2)" != "deb_seg:ok" ]' "falha do pm virou ok: $(prop_ vendor.pfl7560.chaves_aviso)"
  rm -f "$T/pm-disable-falha"
  touch "$T/ip-falha"
  ch aplicar eth0 ligar
  afirma '[ "$RC" = 1 ] && [ "$(car eth0)" = 0 ]' "falha do ip: rc=$RC estado=$(estado)"
  rm -f "$T/ip-falha"
  rm -rf "$R/sys/class/net/eth0"
  ch aplicar eth0 ligar
  afirma '[ "$RC" = 2 ] && [ "$(prop_ vendor.pfl7560.chaves_aviso | cut -d: -f1,2)" = "eth0:ausente" ] && [ -z "$(escolha eth0)" ]' "eth0 ausente: rc=$RC aviso=$(prop_ vendor.pfl7560.chaves_aviso)"
  rm -rf "$R/sys/bus/usb/devices/1-3"
  ch aplicar wifi_pwr ligar
  afirma '[ "$RC" = 2 ] && [ -z "$(escolha wifi_pwr)" ]' "chip ausente: rc=$RC"
  # o lancador de fabrica so sai se a home nova estiver de pe
  grep -v '^com.pfl7560.home$' "$T/pm-instalados" > "$T/x"; mv "$T/x" "$T/pm-instalados"
  ch aplicar deb_lnch ligar
  afirma '[ "$RC" = 2 ] && [ "$(prop_ vendor.pfl7560.chaves_aviso | cut -d: -f1,2)" = "deb_lnch:sem-home" ] && ! desligado com.newlink.hisilauncher && [ -z "$(escolha deb_lnch)" ]' "launcher desligado sem home instalada: rc=$RC"
  echo com.pfl7560.home >> "$T/pm-instalados"; echo com.pfl7560.home >> "$T/pm-desligados"
  ch aplicar deb_lnch ligar
  afirma '[ "$RC" = 2 ] && ! desligado com.newlink.hisilauncher' "launcher desligado com a home desligada"
  sed -i '/^com.pfl7560.home$/d' "$T/pm-desligados"
  ch aplicar deb_lnch ligar
  afirma '[ "$RC" = 0 ] && desligado com.newlink.hisilauncher' "launcher nao desligou com a home de pe"
  limpa
}

c_intocaveis(){
  local i p
  novo_cenario "intocaveis: nenhuma chave, boot ou resgate mexe em pacote fora da lista"
  instala
  tudo_ligado
  ch boot
  ch resgate
  ch boot
  for p in $INTOCAVEIS; do
    afirma '! grep -qE "^pm (disable-user --user 0|enable --user 0|disable|enable|uninstall|clear) $p\$" "$T/calls.log"' "mexeu em $p"
    afirma '! desligado "$p"' "$p ficou desligado"
  done
  afirma '! grep -E "^pm (disable|enable)" "$T/calls.log" | grep -q "higallery"' "mexeu no higallery (visor das telas da suite)"
  afirma '[ "$(grep -c "^pm disable-user" "$T/calls.log")" -ge 15 ]' "poucos pm disable-user ($(grep -c '^pm disable-user' "$T/calls.log"))"
  limpa
  # mesmo com a lista contaminada, a negacao segura
  novo_cenario "intocaveis: a lista de negacao vale sozinha"
  instala
  sed -i 's/^\(    deb_lnch) echo "\)com.newlink.hisilauncher/\1com.newlink.hisilauncher com.hisilicon.higallery com.pfl7560.home com.android.systemui com.newlink.screensaver/' "$S/suite-chaves.sh"
  afirma 'grep -q "higallery" "$S/suite-chaves.sh"' "troca da lista nao aplicada"
  ch aplicar deb_lnch ligar
  afirma '! desligado com.hisilicon.higallery && ! desligado com.pfl7560.home && ! desligado com.android.systemui && ! desligado com.newlink.screensaver && desligado com.newlink.hisilauncher' "lista contaminada passou pela negacao: $(tr '\n' ' ' < "$T/pm-desligados")"
  limpa
}

c_pedido_cmd(){
  novo_cenario "pedido: so 'v1 ler' e 'v1 <id> ligar|desligar'"
  instala
  ch pedido "v1 eth0 ligar"
  afirma '[ "$(car eth0)" = 1 ]' "pedido valido nao aplicou: $(estado)"
  ch pedido "v1 eth0 desligar"
  afirma '[ "$(car eth0)" = 0 ]' "pedido de desligar nao aplicou"
  ch pedido "v1 ler"
  afirma '[ "$(prop_ vendor.pfl7560.chaves)" = "0000000000" ]' "v1 ler nao publicou: $(prop_ vendor.pfl7560.chaves)"
  : > "$T/calls.log"
  ch pedido "eth0 ligar"
  ch pedido "v2 eth0 ligar"
  ch pedido "v1 eth0"
  ch pedido "v1 eth0 ligar extra"
  ch pedido "v1 eth0 LIGAR"
  ch pedido "v1 ../x ligar"
  ch pedido "v1 eth0 ligar; reboot"
  ch pedido ""
  ch pedido "v1 ler ler"
  afirma '! tem_chamada "ip link" && [ "$(car eth0)" = 0 ]' "pedido invalido mexeu: $(tr '\n' '|' < "$T/calls.log")"
  afirma '[ -s "$S/chaves.log" ]' "chaves.log nao registrou as recusas"
  limpa
}

c_boot(){
  local i
  novo_cenario "boot: padroes de instalacao (debloat e log ligados; o resto desligado)"
  instala
  ch boot
  afirma '[ "$RC" = 0 ]' "boot saiu com $RC"
  afirma '[ "$(estado)" = "1111110000" ]' "padroes: $(estado) (esperado 1111110000)"
  afirma '! tem_chamada "ip link" && ! tem_chamada "stop " && ! tem_chamada "persist.hisi.keystone" && [ "$(cat "$R/sys/bus/usb/devices/1-3/power/control")" = on ]' "o boot mexeu no que o dono nao ligou"
  limpa

  novo_cenario "boot: escolha do dono vence o padrao e e reaplicada"
  instala
  ch aplicar eth0 ligar
  ch aplicar wifi_pwr ligar
  ch aplicar web_cmd ligar
  ch aplicar keystone ligar
  ch aplicar log_vplug desligar
  ch aplicar deb_hisi desligar
  # reboot de mentira: o aparelho volta ao que o boot da
  echo 0x1003 > "$R/sys/class/net/eth0/flags"; echo on > "$R/sys/bus/usb/devices/1-3/power/control"
  awk '!/^init.svc/' "$T/props" > "$T/p"; printf '%s\n' init.svc.boa=running init.svc.cmdsrv=running >> "$T/p"; mv "$T/p" "$T/props"
  : > "$T/pm-desligados"; : > "$T/calls.log"
  ch boot
  afirma '[ "$(estado)" = "1101101111" ]' "reaplicacao: $(estado) (esperado 1101101111)"
  afirma '! tem_chamada "pm disable-user --user 0 com.hisilicon.tvui"' "grupo desligado pelo dono foi desligado de novo no boot"
  afirma '! tem_chamada "setprop log.tag.HI_VPLUGIN S"' "log do vplugin voltou sozinho"
  limpa

  novo_cenario "boot: escolha 0 explicita desfaz o que outro desligou"
  instala
  ch aplicar deb_vlc desligar
  echo org.videolan.vlc >> "$T/pm-desligados"
  ch boot
  afirma '! desligado org.videolan.vlc && [ "$(car deb_vlc)" = 0 ]' "VLC ficou desligado apesar da escolha 0"
  limpa

  novo_cenario "boot: marca debloat-revertido segura so o grupo VLC/Office do padrao"
  instala
  : > "$S/debloat-revertido"
  ch boot
  afirma '[ "$(estado)" = "1111010000" ]' "com a marca: $(estado) (esperado 1111010000)"
  ch aplicar deb_vlc ligar
  afirma '[ "$(car deb_vlc)" = 1 ]' "o dono liga o grupo VLC mesmo com a marca"
  limpa

  novo_cenario "boot: pm que nao sobe nao trava nem finge"
  instala
  stub pm 'echo "pm $*" >> "$T/calls.log"; exit 1'
  ch boot
  afirma '[ "$RC" = 0 ]' "boot saiu com $RC"
  afirma '! tem_chamada "pm disable-user" && [ "$(car log_vplug)" = 1 ]' "sem pm: nao desliga, mas o resto segue"
  afirma '[ "$(grep -c "^sleep" "$T/calls.log")" -ge 2 ]' "nao esperou o pm"
  limpa

  novo_cenario "boot: a espera do pm nao segura a trava (o resgate passa)"
  instala
  touch "$T/pm-mudo"
  stub pm 'echo "pm $*" >> "$T/calls.log"
if [ -f "$T/pm-mudo" ]; then [ -d "$PFL_ROOT/dev/pfl7560-chaves.trava" ] && echo TRAVADA-NA-ESPERA >> "$T/calls.log"; exit 0; fi
case "$1 $2" in
  "list packages")
    if [ "$3" = "-d" ]; then sed "s/^/package:/" "$T/pm-desligados"; exit 0; fi
    echo package:android; sed "s/^/package:/" "$T/pm-instalados"; exit 0 ;;
  "disable-user --user") grep -qx "$4" "$T/pm-desligados" || echo "$4" >> "$T/pm-desligados"; exit 0 ;;
esac
exit 0'
  stub sleep 'echo "sleep $*" >> "$T/calls.log"; rm -f "$T/pm-mudo"'
  ch boot
  afirma '! tem_chamada TRAVADA-NA-ESPERA' "o boot segurou a trava enquanto esperava o pm"
  afirma '[ "$(estado)" = "1111110000" ]' "depois da espera: $(estado)"
  limpa

  novo_cenario "boot: trava velha (processo morto) nao prende"
  instala
  mkdir -p "$R/dev/pfl7560-chaves.trava"; echo 999999 > "$R/dev/pfl7560-chaves.trava/pid"
  ch boot
  afirma '[ "$(car log_vplug)" = 1 ]' "a trava velha prendeu o boot"
  limpa
}

c_resgate(){
  novo_cenario "resgate: desliga todas, grava 0 em todas e o boot nao reaplica nada"
  instala
  tudo_ligado
  afirma '[ "$(estado)" = "1111111111" ]' "preparo: $(estado)"
  ch resgate
  afirma '[ "$RC" = 0 ]' "resgate saiu com $RC"
  afirma '[ "$(estado)" = "0000000000" ]' "depois do resgate: $(estado)"
  for i in $IDS; do afirma '[ "$(escolha "$i")" = 0 ]' "escolha de $i nao ficou 0"; done
  afirma '[ ! -s "$T/pm-desligados" ] && [ "$(cat "$R/sys/class/net/eth0/flags")" = 0x1003 ] && [ "$(cat "$R/sys/bus/usb/devices/1-3/power/control")" = on ]' "algo ficou desligado"
  : > "$T/calls.log"
  ch boot
  afirma '[ "$(estado)" = "0000000000" ]' "o boot reaplicou depois do resgate: $(estado)"
  afirma '! tem_chamada "pm disable-user" && ! tem_chamada "setprop log.tag.HI_VPLUGIN S"' "o boot ligou algo depois do resgate"
  afirma '[ "$(ls -A "$S" | grep -c "revertido\|resgate")" = 0 ]' "o resgate deixou marca"
  limpa

  novo_cenario "resgate: trava presa por outra rodada viva ainda grava 0 em todas"
  instala
  tudo_ligado
  mkdir -p "$R/dev/pfl7560-chaves.trava"; echo "$$" > "$R/dev/pfl7560-chaves.trava/pid"
  : > "$T/calls.log"
  ch resgate
  afirma '[ "$RC" != 0 ] && grep -q "escolhas gravadas em 0" "$T/ch.out"' "resgate sem trava nao avisou: $(tail -1 "$T/ch.out")"
  for i in $IDS; do afirma '[ "$(escolha "$i")" = 0 ]' "sem a trava, a escolha de $i nao ficou 0"; done
  afirma '[ "$(grep -c "^sleep" "$T/calls.log")" -ge 179 ]' "o resgate desistiu da trava cedo demais"
  rm -rf "$R/dev/pfl7560-chaves.trava"
  ch boot
  afirma '[ "$(estado)" = "0000000000" ]' "o boot seguinte nao desligou o que ficou: $(estado)"
  limpa

  novo_cenario "resgate: chave que nao confere ainda fica com escolha 0"
  instala
  tudo_ligado
  touch "$T/ip-falha"
  ch resgate
  afirma '[ "$(escolha eth0)" = 0 ]' "eth0 nao confirmou e a escolha ficou '$(escolha eth0)' (o boot religaria)"
  limpa

  novo_cenario "wifi: o chip que some ao dormir nao fica escolhido (o boot nao repete)"
  instala
  ch aplicar wifi_pwr ligar
  afirma '[ "$(escolha wifi_pwr)" = 1 ]' "preparo: escolha '$(escolha wifi_pwr)'"
  ch aplicar wifi_pwr desligar
  # o power/control aponta para o idVendor: gravar "auto" faz o chip sumir da lista do USB
  rm -f "$R/sys/bus/usb/devices/1-3/power/control"; ln -s ../idVendor "$R/sys/bus/usb/devices/1-3/power/control"
  ch aplicar wifi_pwr ligar
  afirma '[ "$RC" != 0 ] && [ "$(escolha wifi_pwr)" = 0 ]' "o chip sumiu e a escolha ficou '$(escolha wifi_pwr)' (rc=$RC)"
  afirma '[ "$(prop_ vendor.pfl7560.chaves_aviso | cut -d: -f1-2)" = "wifi_pwr:sumiu" ]' "aviso: '$(prop_ vendor.pfl7560.chaves_aviso)'"
  afirma 'grep -q " wifi_pwr ligar sumiu$" "$S/diario.fila"' "a fila do diario nao registrou o sumico"
  limpa

  novo_cenario "resgate: aparelho sem eth0 e sem chip nao quebra"
  instala
  rm -rf "$R/sys/class/net/eth0" "$R/sys/bus/usb/devices/1-3"
  ch resgate
  afirma '[ "$RC" = 0 ]' "resgate saiu com $RC"
  limpa
}

c_pacotes_fora(){
  novo_cenario "pacotes-fora: so os grupos que o dono desligou"
  instala
  ch pacotes-fora
  afirma '[ ! -s "$T/ch.out" ]' "padrao nao tem grupo fora: $(cat "$T/ch.out")"
  ch aplicar deb_vlc desligar
  ch pacotes-fora
  afirma 'grep -qx org.videolan.vlc "$T/ch.out" && grep -qx com.mobisystems.editor.office_registered "$T/ch.out" && [ "$(wc -l < "$T/ch.out")" = 2 ]' "pacotes-fora: $(tr '\n' ' ' < "$T/ch.out")"
  limpa
}

c_integracao_pedido(){
  novo_cenario "pedido: a home escreve 'chave', o suite-pedido valida e o suite-chaves aplica"
  instala
  # md5 embutido do suite-chaves conferido na hora
  printf 'v1 eth0 ligar\n' > "$PEDH/chave"
  amb dash "$S/suite-pedido.sh" w "$PEDH" chave > "$T/pedido.out" 2>&1
  afirma '[ "$(car eth0)" = 1 ] && [ ! -e "$PEDH/chave" ]' "pedido da home nao aplicou: $(tail -3 "$T/pedido.out")"
  # pedido de quem nao e o app (uid abaixo do minimo)
  printf 'v1 eth0 desligar\n' > "$PEDH/chave"
  env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_RAPIDO=1 PFL_ROOT="$R" PFL_APP_UID_MIN=99999 PATH="$T/bin:$PATH" dash "$S/suite-pedido.sh" w "$PEDH" chave > "$T/pedido.out" 2>&1
  afirma '[ "$(car eth0)" = 1 ] && [ ! -e "$PEDH/chave" ]' "pedido de quem nao e o app foi aplicado"
  # conteudo grande demais e cortado, nao estoura
  head -c 5000 /dev/zero | tr '\0' 'a' > "$PEDH/chave"
  amb dash "$S/suite-pedido.sh" w "$PEDH" chave > "$T/pedido.out" 2>&1
  afirma '[ "$(car eth0)" = 1 ] && [ ! -e "$PEDH/chave" ] && [ "$(prop_ vendor.pfl7560.chaves | wc -c)" -le 12 ]' "pedido enorme mexeu em algo"
  # link no lugar do pedido nao e seguido
  echo "v1 eth0 desligar" > "$T/alvo"; ln -s "$T/alvo" "$PEDH/chave"
  amb dash "$S/suite-pedido.sh" w "$PEDH" chave > "$T/pedido.out" 2>&1
  afirma '[ "$(car eth0)" = 1 ]' "o link do pedido foi seguido"
  rm -f "$PEDH/chave"
  # script de chaves adulterado: nao roda
  printf 'v1 eth0 desligar\n' > "$PEDH/chave"
  echo "# adulterado" >> "$S/suite-chaves.sh"
  amb dash "$S/suite-pedido.sh" w "$PEDH" chave > "$T/pedido.out" 2>&1
  afirma '[ "$(cat "$R/sys/class/net/eth0/flags")" = 0x1002 ] && grep -q "md5 diferente" "$S/vigia.log"' "rodou um suite-chaves.sh com md5 diferente"
  limpa
}

c_integracao_boot(){
  novo_cenario "boot: suite-boot.sh reaplica as chaves e a lista antiga respeita o grupo desligado"
  instala
  stub dmesg 'exit 0'; stub inotifyd 'echo "inotifyd $*" >> "$T/calls.log"; exit 0'
  mkdir -p "$R/data/system/users/0"; : > "$R/data/system/users/0/package-restrictions.xml"
  ch aplicar deb_vlc desligar
  : > "$T/calls.log"
  amb dash "$S/suite-boot.sh" > "$T/boot.out" 2>&1
  afirma '[ "$(estado | cut -c1-6)" = "111101" ]' "depois do boot: $(estado)"
  afirma '! tem_chamada "pm disable-user --user 0 org.videolan.vlc" && ! tem_chamada "pm disable-user --user 0 com.mobisystems"' "o debloat do boot desligou o VLC/Office que o dono pos fora"
  afirma 'grep -q "nas chaves - nada a desligar" "$S/boot.log"' "o boot nao registrou o grupo fora: $(grep -c . "$S/boot.log")"
  limpa

  novo_cenario "boot: sem a escolha o debloat de sempre segue (VLC desligado pela lista)"
  instala
  stub dmesg 'exit 0'; stub inotifyd 'exit 0'
  mkdir -p "$R/data/system/users/0"; : > "$R/data/system/users/0/package-restrictions.xml"
  echo org.videolan.vlc >> "$T/pm-instalados"
  amb dash "$S/suite-boot.sh" > "$T/boot.out" 2>&1
  afirma 'desligado org.videolan.vlc && [ "$(car deb_vlc)" = 1 ]' "o padrao nao desligou o VLC"
  limpa

  novo_cenario "boot: suite-chaves.sh adulterado nao roda no boot"
  instala
  stub dmesg 'exit 0'; stub inotifyd 'exit 0'
  mkdir -p "$R/data/system/users/0"; : > "$R/data/system/users/0/package-restrictions.xml"
  echo "# adulterado" >> "$S/suite-chaves.sh"
  amb dash "$S/suite-boot.sh" > "$T/boot.out" 2>&1
  afirma 'grep -q "suite-chaves.sh ausente, link, de outro dono ou com md5 diferente" "$S/boot.log" && ! tem_chamada "setprop log.tag.HI_VPLUGIN S"' "rodou o script adulterado"
  limpa
}

c_pendrive(){
  novo_cenario "pendrive: DESLIGAR-CHAVES.txt chama o resgate (so com o script conferido)"
  instala
  tudo_ligado
  local fn="$T/fn.sh" MP="$T/usb"
  mkdir -p "$MP" "$T/work"
  touch "$MP/DESLIGAR-CHAVES.txt"
  {
    echo 'LOG(){ echo "LOG $*"; }'
    echo "SUITE='$S'; MP='$MP'; WORK='$T/work'"
    echo 'dir_seguro(){ [ -d "$1" ]; }'
    echo 'trabalho_ok(){ [ -d "$WORK" ]; }'
    echo 'trabalho_conferir(){ [ "$(md5sum "$WORK/$1" | cut -d" " -f1)" = "$(md5sum "'"$KIT"'/$1" | cut -d" " -f1)" ]; }'
    sed -n '/^chaves_pendrive()/,/^}/p' "$KIT/newlink_update.sh"
    echo 'chaves_pendrive'
  } > "$fn"
  cp "$KIT/suite-chaves.sh" "$T/work/suite-chaves.sh"
  amb dash "$fn" > "$T/pend.out" 2>&1
  afirma '[ "$(estado)" = "0000000000" ] && grep -q "DESLIGAR-CHAVES.txt" "$T/pend.out"' "o resgate do pendrive nao desligou: $(estado) / $(tail -2 "$T/pend.out")"
  tudo_ligado
  echo "# adulterado" >> "$T/work/suite-chaves.sh"
  amb dash "$fn" > "$T/pend.out" 2>&1
  afirma '[ "$(estado)" = "1111111111" ] && grep -q "ERRO" "$T/pend.out"' "rodou o script nao conferido"
  rm -f "$MP/DESLIGAR-CHAVES.txt"; cp "$KIT/suite-chaves.sh" "$T/work/suite-chaves.sh"
  amb dash "$fn" > "$T/pend.out" 2>&1
  afirma '[ "$(estado)" = "1111111111" ]' "sem o arquivo no pendrive nao devia desligar"
  limpa
}

echo "== estaticos =="
c_estaticos
echo "== cenarios sob dash =="
for c in c_ler c_aplicar c_intocaveis c_pedido_cmd c_boot c_resgate c_pacotes_fora c_integracao_pedido c_integracao_boot c_pendrive; do
  echo "  $c"
  "$c"
done
echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
