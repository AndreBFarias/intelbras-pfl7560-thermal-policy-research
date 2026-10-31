#!/usr/bin/env bash
# tests/test-suite.sh - bloco 9B: harness da suite de verificacao.
#
# Roda os scripts REAIS do kit (suite.sh, suite-boot.sh, suite-pedido.sh, cor.sh,
# newlink_update.sh) contra uma arvore de mentira (PFL_ROOT) e stubs em um PATH
# temporario: getprop/setprop (com estado num arquivo), am, cmd, logcat, hidebug,
# nl_camcheck (faixas, niveis e geometria do contrato C-geo), nl_tela (contrato C-tela:
# guarda o campos.txt de cada tela), lvdsctl, getevent, input, dmesg, inotifyd, mount,
# chcon, chown, setsid, sleep, wm, reboot. NUNCA fala com o aparelho. Os cenarios rodam
# sob dash (POSIX estrito, como no test-kit-pendrive.sh).
#
#   bash tests/test-suite.sh
# as condicoes do afirma sao avaliadas depois (eval): aspas simples de proposito
# shellcheck disable=SC2016
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
OFF=$(( 168 + 69 * 768 + 92 ))
PNOME="RX058B_4300_5010E_1080P_M"
PROP_OV=vendor.zy.power.tm.temp
TODAS="$(mktemp)"     # todas as chamadas de todos os cenarios (verificacoes globais)
TODAS_CAMPOS="$(mktemp)"   # todos os campos.txt de todas as telas geradas
trap 'rm -f "$TODAS" "$TODAS_CAMPOS"' EXIT

FALHAS=0
TESTES=0
CASO=""
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }

# ---------------------------------------------------------------------------
# cenario
# ---------------------------------------------------------------------------
stub(){ printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
novo_cenario(){
  CASO="$1"
  MODO_AUTO_TESTE=0
  T="$(mktemp -d)"
  R="$T/root"; S="$R/data/vendor/pfl7560-suite"; W="$R/data/vendor/pfl7560-kit"; MP="$R/mnt/media_rw/USB1"
  PED="$R/data/data/com.pfl7560.verificar"
  PEDH="$R/data/data/com.pfl7560.home"
  local b="$T/bin"
  mkdir -p "$R/vendor/etc/init/hw" "$R/vendor/lib" "$R/vendor/bin" "$R/atv" "$R/proc/msp" "$R/dev/block/by-name" \
           "$R/data/local/tmp" "$R/data/vendor" "$R/data/media/0" "$R/sdcard" "$R/mnt/media_rw" \
           "$R/sys/class/net/wlan0" "$R/sys/class/rtc/rtc0" "$R/atv/bootvideo" "$b"
  echo "logo de fabrica" > "$R/atv/bootvideo/logo.jpg"; echo "animacao de fabrica" > "$R/atv/bootvideo/bootanimation.zip"
  : > "$R/vendor/lib/libhitvservice.so"
  : > "$R/dev/video0"
  echo up > "$R/sys/class/net/wlan0/operstate"
  echo 1793400000 > "$R/sys/class/rtc/rtc0/since_epoch"
  printf 'pm_state: normal\nwakeup: power\n' > "$R/proc/msp/pm"
  # aparelho com a correcao termica aplicada (o que o kit deixa)
  cp "$KIT/ZYCustom.ini" "$R/vendor/etc/ZYCustom.ini"
  cp "$ROOT/artifacts/build.prop.STOCK" "$R/vendor/build.prop"
  sed -i 's/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/' "$R/vendor/build.prop"
  cp "$ROOT/artifacts/init.bigfish.rc.STOCK" "$R/vendor/etc/init/hw/init.bigfish.rc"
  sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$R/vendor/etc/init/hw/init.bigfish.rc"
  # painel: perfil 69, VESA
  printf 'panel_name   | %s\ncut_idx      : 69\nlvds_fmt     | vesa\n' "$PNOME" > "$R/proc/msp/panel"
  head -c 8388608 /dev/zero | tr '\0' 'A' > "$R/dev/block/by-name/panelparam"
  printf '%s\0' "$PNOME" | dd of="$R/dev/block/by-name/panelparam" bs=1 seek=$(( 168 + 69 * 768 )) conv=notrunc 2>/dev/null
  printf '\000' | dd of="$R/dev/block/by-name/panelparam" bs=1 seek="$OFF" conv=notrunc 2>/dev/null
  cp "$R/dev/block/by-name/panelparam" "$T/pp-original.img"
  : > "$T/calls.log"; : > "$T/keys"
  # propriedades (getprop/setprop leem e gravam aqui); o sufixo do sensor e o do aparelho (U+2103)
  local c; c="$(printf '\342\204\203')"
  cat > "$T/props" <<FIM
ro.product.model=PFL7560
ro.serialno=SER123
ro.zhiying.version=V1.0.0.9
ro.boot.projectid=390
sys.boot.reason=shutdown,userrequested
persist.sys.boot.reason=shutdown,userrequested
ro.boot.bootreason=shutdown,userrequested
zysys.env_temp=54.7$c
zysys.light_temp=30.1$c
persist.display.720p=false
persist.sys.keystone.lt=0,1080
persist.sys.keystone.rt=1920,1080
persist.sys.keystone.lb=0,0
persist.sys.keystone.rb=1920,0
persist.sys.mountingmode=1
persist.sys.fac_flipmode=0
vendor.focus.camera.is_focused=true
sys.newlink.auto=0
FIM
  stub getprop 'awk -v k="$1" '"'"'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }'"'"' "$T/props"'
  stub setprop 'echo "setprop $1 ${2:-}" >> "$T/calls.log"
[ "$1" = vendor.zy.power.tm.temp ] && [ -z "${2:-}" ] && [ -f "$T/setprop-nao-limpa" ] && exit 0
awk -v k="$1" '"'"'index($0, k "=") != 1'"'"' "$T/props" > "$T/props.novo"
printf "%s=%s\n" "$1" "${2:-}" >> "$T/props.novo"; mv "$T/props.novo" "$T/props"'
  stub getevent 'echo "getevent $*" >> "$T/calls.log"
k=$(head -1 "$T/keys"); sed -i 1d "$T/keys"
[ "$k" = "key" ] && echo "/dev/input/event2: EV_KEY       KEY_OK                DOWN"
exit 0'
  stub am 'echo "am $*" >> "$T/calls.log"
[ "$1" = "start" ] || exit 0
f=$(echo "$*" | sed "s#.*-d file://\([^ ]*\).*#\1#")
[ -f "$PFL_ROOT$f" ] || echo "AM_ARQUIVO_AUSENTE $f" >> "$T/calls.log"
exit 0'
  # query-services: o descanso do app (bloco 16B), ausente com $T/sem-descanso
  # bloco 14: "cmd overlay list|enable|disable" sobre $T/overlay.db (linhas "[ ] pacote" / "[x] pacote");
  # overlay-demora = N consultas do list que ainda saem vazias (o PackageManager processando);
  # overlay-enable-falha = pacotes (um por linha) cujo enable falha
  stub cmd 'echo "cmd $*" >> "$T/calls.log"
case "$1 $2" in
  "overlay list") n=$(cat "$T/overlay-demora" 2>/dev/null || echo 0)
    if [ "$n" -gt 0 ]; then echo $((n-1)) > "$T/overlay-demora"; exit 0; fi
    cat "$T/overlay.db" 2>/dev/null; exit 0 ;;
  "overlay enable") grep -qx "$3" "$T/overlay-enable-falha" 2>/dev/null && exit 1
    sed -i "s/^\[ \] $3\$/[x] $3/" "$T/overlay.db"; exit 0 ;;
  "overlay disable") sed -i "s/^\[x\] $3\$/[ ] $3/" "$T/overlay.db"; exit 0 ;;
esac
case "$*" in *query-services*) [ -f "$T/sem-descanso" ] || echo "com.pfl7560.verificar/.Descanso"; exit 0 ;; esac
echo "priority=0 isDefault=false"; echo "com.hisilicon.higallery/.NetworkHiGallery"'
  stub logcat 'echo "logcat $*" >> "$T/calls.log"; [ -f "$T/logcat-saida" ] && cat "$T/logcat-saida"; exit 0'
  # hidebug: registra os argumentos e a entrada (o gtt chegaria por ela); saida de mentira.
  # Bloco 11: o motor de foco (gfd, gfdr, sfd <pos>). foco-pos = a posicao (sem ele, o gfd nao
  # responde num formato conhecido); foco-trava = o motor recusa andar ("Motor is too hot!");
  # foco-mudo-apos = N respostas do gfd e depois silencio.
  # Bloco 15: "sbl N" guarda N em $T/bl (salvo com $T/bl-trava, o fabricante que atrasa) e "gbl"
  # devolve "backlight:N" (100 sem nada guardado)
  stub hidebug 'in=$(cat 2>/dev/null | tr "\n" " ")
echo "HIDEBUG $* $in" >> "$T/calls.log"
case "$in" in *"sbl "*) n=${in##*sbl }; n=${n%% *}; [ -f "$T/bl-trava" ] || echo "$n" > "$T/bl" ;; esac
case "$in" in *gbl*) echo "backlight:$(cat "$T/bl" 2>/dev/null || echo 100)"; exit 0 ;; esac
case "$in" in *"custom gfd quit"*|*"custom gfdr quit"*|*"custom sfd "*)
  if [ ! -f "$T/foco-pos" ]; then echo "unknown command"; exit 0; fi
  case "$in" in
    *"sfd "*) n=${in##*sfd }; n=${n%% *}; [ -f "$T/foco-trava" ] || echo "$n" > "$T/foco-pos"; echo "Focus Distance Align to $n" ;;
    *gfdr*) echo "focus distance range : [0, 12000]" ;;
    *) c=$(cat "$T/n-gfd" 2>/dev/null || echo 0); c=$((c+1)); echo $c > "$T/n-gfd"
       [ -f "$T/foco-mudo-apos" ] && [ "$c" -gt "$(cat "$T/foco-mudo-apos")" ] && exit 0
       echo "focus distance : $(cat "$T/foco-pos")" ;;
  esac
  exit 0 ;;
esac
if [ -f "$T/hidebug-saida" ]; then cat "$T/hidebug-saida"; else printf "fan speed : 3000\nfan speed : 2950\nbacklight brightness : 1000\n"; fi'
  cp "$b/hidebug" "$R/vendor/bin/hidebug"
  # nl_camcheck: faixas acha 16; niveis olha o byte lvds_fmt (como no test-kit-pendrive);
  # geometria devolve $T/geo-<n> (n-esima chamada), $T/geo ou uma geometria boa; com foco-otimo, a
  # borda do centro sai da distancia entre foco-pos e foco-otimo (1,8 px no otimo, +1 px a cada 40) e
  # a da esquerda soma foco-lado (0,3 px sem ele). Bloco 11: nitidez devolve $T/nit ou um mapa bom.
  stub nl_camcheck 'echo "nl_camcheck $*" >> "$T/calls.log"
JEIDA="235 235 235 235 235 232 222 210 197 181 164 141 114 91 72 63"
VESA="235 235 235 231 192 148 105 86 220 212 156 90 185 116 195 128"
saida(){ for v in $1; do echo $v; done; echo "$2"; exit 0; }
case "$1" in
  faixas)
    [ -f "$T/cam-faixas-rc" ] && { echo "faixas achadas: 15 (esperadas 16)"; exit 3; }
    if [ -f "$T/cam-faixas-falhas" ]; then
      f=$(cat "$T/cam-faixas-falhas"); if [ "$f" -gt 0 ]; then echo $((f-1)) > "$T/cam-faixas-falhas"; echo "faixas achadas: 8 (esperadas 16)"; exit 3; fi
    fi
    i=0; : > "$4"; while [ $i -lt 16 ]; do echo "$((100+i*20)) $((114+i*20))" >> "$4"; i=$((i+1)); done
    echo "faixas achadas: 16 (esperadas 16)"; exit 0 ;;
  niveis)
    byte=$(dd if="$PFL_ROOT/dev/block/by-name/panelparam" bs=1 skip='"$OFF"' count=1 2>/dev/null | od -An -tu1 | tr -dc 0-9)
    if [ "$byte" != "$(cat "$T/cam-certo" 2>/dev/null)" ]; then saida "$VESA" "inv_cresc=9 inv_decresc=3"; fi
    saida "$JEIDA" "inv_cresc=10 inv_decresc=0" ;;
  geometria)
    n=$(cat "$T/n-geo" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n-geo"
    [ -f "$T/geo-rc" ] && { echo "faixas nao aparecem nas tres colunas"; exit "$(cat "$T/geo-rc")"; }
    if [ -f "$T/foco-otimo" ]; then
      awk -v p="$(cat "$T/foco-pos" 2>/dev/null || echo 0)" -v o="$(cat "$T/foco-otimo")" -v l="$(cat "$T/foco-lado" 2>/dev/null || echo 0.3)" \
        "BEGIN{d=p-o; if (d<0) d=-d; c=1.8+d/40; printf \"inclinacao_graus=0.40\\ntrapezio_pct=1.2\\nborda_centro_px=%.2f\\nborda_esq_px=%.2f\\nborda_dir_px=%.2f\\ncontraste_centro=0.93\\nquadro=1280x720\\n\", c, c+l, c+0.1}"
      exit 0
    fi
    if [ -f "$T/geo-$n" ]; then cat "$T/geo-$n"; elif [ -f "$T/geo" ]; then cat "$T/geo"; else
      printf "inclinacao_graus=0.40\ntrapezio_pct=1.2\nborda_centro_px=1.80\nborda_esq_px=2.10\nborda_dir_px=1.95\ncontraste_centro=0.93\nquadro=1280x720\n"; fi
    exit 0 ;;
  nitidez)
    [ -f "$T/nit-rc" ] && { echo "a imagem projetada nao aparece no quadro"; exit "$(cat "$T/nit-rc")"; }
    if [ -f "$T/nit" ]; then cat "$T/nit"; else
      printf "nitidez_r1c1=2.05\nnitidez_r1c2=1.85\nnitidez_r1c3=1.95\nnitidez_r2c1=1.95\nnitidez_r2c2=1.80\nnitidez_r2c3=1.90\nnitidez_r3c1=2.10\nnitidez_r3c2=1.85\nnitidez_r3c3=2.00\nquadro=1280x720\n"; fi
    exit 0 ;;
esac
exit 2'
  # nl_tela (C-tela): guarda o campos.txt de cada tela e escreve um PNG de mentira
  stub nl_tela 'n=$(cat "$T/n-tela" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n-tela"
nome=$(basename "$3" .png)
echo "nl_tela $1 $nome" >> "$T/calls.log"
cp "$2" "$T/campos-$n-$1-$nome.txt"
[ -f "$T/nltela-falha" ] && exit 1
printf "PNGDEMENTIRA" > "$3"; exit 0'
  stub lvdsctl 'echo "lvdsctl $*" >> "$T/calls.log"
pp="$PFL_ROOT/dev/block/by-name/panelparam"
if [ "$2" = "1" ]; then printf "\001"; else printf "\000"; fi | dd of="$pp" bs=1 seek='"$OFF"' conv=notrunc 2>/dev/null
exit 0'
  # sleep: registra; com $T/mata-no-sleep = N, o "sleep N" manda TERM para quem chamou
  stub sleep 'echo "sleep $*" >> "$T/calls.log"
if [ -f "$T/mata-no-sleep" ] && [ "$1" = "$(cat "$T/mata-no-sleep")" ]; then rm -f "$T/mata-no-sleep"; kill -TERM "$PPID"; fi
# sleep-cria: caminhos (um por linha) que o "sleep 30" do laco do vigia cria (um pedido que chega depois do boot)
if [ -f "$T/sleep-cria" ] && [ "$1" = 30 ]; then while IFS= read -r f; do : > "$f"; done < "$T/sleep-cria"; rm -f "$T/sleep-cria"; fi
# o PackageManager grava o package-restrictions.xml com atraso: restr-atraso = quantos sleeps ate gravar
if [ -f "$T/restr-pendente" ]; then
  n=$(cat "$T/restr-atraso" 2>/dev/null || echo 0)
  if [ "$n" -le 1 ]; then cat "$T/restr-pendente" >> "$PFL_ROOT/data/system/users/0/package-restrictions.xml"; rm -f "$T/restr-pendente"; else echo $((n-1)) > "$T/restr-atraso"; fi
fi
exit 0'
  stub input 'echo "input $*" >> "$T/calls.log"'
  # alerta de sistema do firmware: "$T/alerta" = quantas consultas ainda o mostram focado
  stub dumpsys 'case "$1" in package) [ -f "$T/dumpsys-descanso" ] && echo "  1a2b com.pfl7560.verificar/.Descanso filter 3c4d"; exit 0 ;; esac
n=$(cat "$T/alerta" 2>/dev/null || echo 0)
p=$(cat "$T/alerta-pacote" 2>/dev/null || echo com.newlink.nlprovision)
if [ "$n" -gt 0 ]; then echo $((n-1)) > "$T/alerta"; echo "  mCurrentFocus=Window{8a4910d u0 $p}"; else echo "  mCurrentFocus=Window{1 u0 com.hisilicon.higallery/x}"; fi'
  # bloco 14: pm sobre arquivos de estado. pm-instalados = pacotes (um por linha, alem do "android");
  # pm-desligados = os desligados; pm-fora = o pm ainda nao responde; pm-disable-falha; restr-nunca =
  # o xml nunca e gravado; restr-atraso = N (o stub sleep grava o xml depois de N sleeps)
  stub pm 'echo "pm $*" >> "$T/calls.log"
case "$1 $2" in
  "list packages")
    if [ "$3" = "-d" ]; then sed "s/^/package:/" "$T/pm-desligados" 2>/dev/null; exit 0; fi
    [ -f "$T/pm-fora" ] && exit 0
    echo package:android; sed "s/^/package:/" "$T/pm-instalados" 2>/dev/null; exit 0 ;;
  "disable-user --user")
    [ -f "$T/pm-disable-falha" ] && exit 1
    echo "$4" >> "$T/pm-desligados"
    mkdir -p "$PFL_ROOT/data/system/users/0"
    l="  <pkg name=\"$4\" enabled=\"3\" enabledCaller=\"shell:0\" />"
    if [ -f "$T/restr-nunca" ]; then :
    elif [ -f "$T/restr-atraso" ]; then echo "$l" >> "$T/restr-pendente"
    else echo "$l" >> "$PFL_ROOT/data/system/users/0/package-restrictions.xml"; fi
    exit 0 ;;
  "enable --user") sed -i "/^$4\$/d" "$T/pm-desligados"; exit 0 ;;
esac
exit 0'
  stub wm 'echo "Physical size: 1920x1080"'
  stub dmesg '[ -f "$T/dmesg" ] && cat "$T/dmesg"; exit 0'
  stub inotifyd 'echo "inotifyd $*" >> "$T/calls.log"; exit 0'
  # settings (bloco 16B): "$T/settings.db" guarda "ns chave=valor"; get de chave ausente = "null"
  # (como o do aparelho); put falha com $T/settings-falha
  cat > "$b/settings" <<'FIM'
#!/bin/sh
echo "settings $*" >> "$T/calls.log"
case "$1" in
  get)
    v=$(awk -v k="$2 $3" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' "$T/settings.db" 2>/dev/null)
    if [ -n "$v" ]; then echo "$v"; else echo null; fi ;;
  put)
    [ -f "$T/settings-falha" ] && exit 1
    awk -v k="$2 $3" 'index($0, k "=") != 1' "$T/settings.db" > "$T/settings.novo" 2>/dev/null
    echo "$2 $3=$4" >> "$T/settings.novo"; mv "$T/settings.novo" "$T/settings.db" ;;
esac
exit 0
FIM
  chmod +x "$b/settings"
  stub mount 'echo "mount $*" >> "$T/calls.log"; exit 0'
  stub chcon 'echo "chcon $*" >> "$T/calls.log"; exit 0'
  stub chown 'echo "chown $*" >> "$T/calls.log"; exit 0'
  stub reboot 'echo "reboot" >> "$T/calls.log"'
  stub gtt 'echo "GTT $*" >> "$T/calls.log"'
  # setsid: registra; so executa com $T/setsid-roda (a suite em si e testada chamando direto)
  stub setsid 'echo "setsid $*" >> "$T/calls.log"; [ -f "$T/setsid-roda" ] && "$@"; exit 0'
  ln -sf "$(command -v dash)" "$b/sh"
  export T
}
limpa(){
  cat "$T/calls.log" >> "$TODAS" 2>/dev/null
  cat "$T"/campos-*.txt >> "$TODAS_CAMPOS" 2>/dev/null
  if [ -n "${DEBUG_KEEP:-}" ]; then echo "  (mantido: $T)"; else rm -rf "$T"; fi
}
amb(){
  env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_RAPIDO=1 PFL_ROOT="$R" \
      PFL_LVDSCTL="$T/bin/lvdsctl" PFL_LVDSCTL_MD5="$(md5 "$T/bin/lvdsctl")" \
      PFL_NLCAMCHECK="$T/bin/nl_camcheck" PFL_NLCAMCHECK_MD5="$(md5 "$T/bin/nl_camcheck")" \
      PFL_NLTELA="$T/bin/nl_tela" PFL_NLTELA_MD5="${NLTELA_MD5_TESTE:-$(md5 "$T/bin/nl_tela")}" \
      PFL_APP_UID_MIN="${APP_UID_MIN_TESTE:-0}" \
      PFL_MODO_AUTO="$MODO_AUTO_TESTE" PFL_VIGIA_VOLTAS=2 PFL_ESPERA_OK_VOLTAS=2 PATH="$T/bin:$PATH" "$@"
}
# a pasta da suite como o newlink_update.sh deixa (so do root, os arquivos do kit)
instala_suite(){
  ( umask 077; mkdir -p "$S/kit" "$S/fontes" )
  chmod 700 "$S" "$S/kit" "$S/fontes"
  local f
  for f in suite.sh suite-boot.sh suite-pedido.sh cor.sh lvdsctl nl_camcheck; do cp "$KIT/$f" "$S/$f"; chmod 755 "$S/$f"; done
  cp "$KIT"/kit/*.png "$S/kit/"
  cp "$KIT"/fontes/* "$S/fontes/"
  mkdir -p "$PED" "$PEDH"
}
roda_suite(){ amb dash "$S/suite.sh" "$@" > "$T/out.log" 2>&1; RC=$?; }
roda_boot(){ amb dash "$S/suite-boot.sh" > "$T/boot.out" 2>&1; RC=$?; }
roda_pedido(){ amb dash "$S/suite-pedido.sh" "$@" > "$T/pedido.out" 2>&1; RC=$?; }
roda_kit(){
  amb dash "$MP/newlink_update.sh" USB1 > "$T/kit.out" 2>&1; RC=$?
}
pendrive(){ mkdir -p "$MP"; cp -r "$KIT"/. "$MP/"; }
rc_suite_ok(){ cp "$KIT/pfl7560-suite.rc" "$R/vendor/etc/init/pfl7560-suite.rc"; chmod 644 "$R/vendor/etc/init/pfl7560-suite.rc"; }
res(){ sed -n "s/^$1=//p" "$S/resultados.txt" 2>/dev/null | head -1; }
ult_hist(){ tail -1 "$S/historico-boot.txt" 2>/dev/null; }
tem_chamada(){ grep -qF -- "$1" "$T/calls.log" 2>/dev/null; }
chamadas(){ grep -c "^$1" "$T/calls.log" 2>/dev/null || true; }
telas(){ grep '^am start' "$T/calls.log" 2>/dev/null | sed 's#.*/\([a-z0-9-]*\)\.png.*#\1#' | sed 's/-[0-9]\{6,\}$//' | tr '\n' ' '; }
campos(){ local f r=""; for f in "$T"/campos-*-"$1"-"$2".txt; do [ -e "$f" ] && r="$f"; done; echo "$r"; }   # $1 = aviso|resumo, $2 = nome
pp_md5(){ md5 "$R/dev/block/by-name/panelparam"; }
# corredor feliz da rampa: o firmware reage ao override
rampa_reage(){ printf '%s\n' "10-30 19:40:01.000 I/ZYThermalManager( 1): Overheat Warning" \
  "10-30 19:40:02.000 I/ZYThermalManager( 1): Level Change 1000 => 850!" \
  "10-30 19:40:30.000 I/ZYThermalManager( 1): Level Change 850 => 1000!" > "$T/logcat-saida"; }
# uma saida de geometria (C-geo); $1..$6 = inclinacao trapezio borda_c borda_e borda_d contraste
geo(){ printf 'inclinacao_graus=%s\ntrapezio_pct=%s\nborda_centro_px=%s\nborda_esq_px=%s\nborda_dir_px=%s\ncontraste_centro=%s\nquadro=1280x720\n' "$@"; }
# valores de item com mais de 18 caracteres (\uXXXX conta como um) em todas as telas
valores_longos(){ sed -n 's/^item=[^|]*|\([^|]*\)|.*/\1/p' "$TODAS_CAMPOS" | sed 's/\\u[0-9a-f]\{4\}/X/g' | awk 'length($0) > 18' | sort -u; }
item_de(){ grep -F "item=$1|" "$(campos resumo resumo)" 2>/dev/null | head -1 | sed 's/^item=//'; }

# ---------------------------------------------------------------------------
# B2 - gatilho (suite-boot.sh)
# ---------------------------------------------------------------------------
c_gatilho_matriz(){
  local caso ano br gat dec mot
  # ano do relogio no boot | sys.boot.reason | gatilho | decisao esperada | motivo esperado
  while IFS='|' read -r ano br gat dec mot; do
    [ -n "$ano" ] || continue
    novo_cenario "gatilho: ano=$ano motivo='$br' gatilho=$gat = $dec ($mot)"
    instala_suite
    echo "[    1.2] rtc-hisi rtc0: setting system clock to $ano-01-01 00:00:05 UTC (5)" > "$T/dmesg"
    awk '!/^sys.boot.reason=/' "$T/props" > "$T/p" && echo "sys.boot.reason=$br" >> "$T/p" && mv "$T/p" "$T/props"
    [ "$gat" = "-" ] || echo "$gat" > "$S/gatilho"
    roda_boot
    afirma '[ "$RC" = 0 ]' "suite-boot.sh saiu com $RC"
    afirma 'ult_hist | grep -q "decisao=$dec; motivo=$mot$"' "historico: '$(ult_hist)'"
    if [ "$dec" = sim ]; then
      afirma 'tem_chamada "setsid sh $S/suite.sh tomada $mot"' "a suite nao foi lancada: $(grep setsid "$T/calls.log" | tr '\n' '|')"
    else
      afirma '! grep -q "suite.sh tomada" "$T/calls.log"' "a suite foi lancada sem motivo"
    fi
    limpa
  done <<'MATRIZ'
1970|shutdown,userrequested|-|sim|relogio_zerado
2000|reboot,adb|-|sim|relogio_zerado
2026|shutdown,userrequested|-|nao|desligamento_limpo
2026|shutdown,shell|-|nao|desligamento_limpo
2026|reboot,adb|-|nao|desligamento_limpo
2026|kernel_panic|-|sim|desligamento_nao_limpo
2026||-|sim|desligamento_nao_limpo
2026|shutdown,userrequested|sempre|sim|gatilho_sempre
1970|kernel_panic|nunca|nao|gatilho_nunca
2026|shutdown,userrequested|qualquer-coisa|nao|desligamento_limpo
1970|shutdown,userrequested|auto|sim|relogio_zerado
MATRIZ

  # criterio (m): a marca gravada no boot anterior sobreviveu = a energia caiu ligado
  novo_cenario "gatilho: marca pfl7560,ligado no motivo = queda_de_energia, roda"
  instala_suite
  awk '!/^(sys|persist\.sys)\.boot\.reason=/' "$T/props" > "$T/p" && printf '%s\n' "sys.boot.reason=pfl7560,ligado" "persist.sys.boot.reason=pfl7560,ligado" >> "$T/p" && mv "$T/p" "$T/props"
  roda_boot
  afirma 'ult_hist | grep -q "persist_boot_reason=pfl7560,ligado; .*decisao=sim; motivo=queda_de_energia$"' "historico: '$(ult_hist)'"
  afirma 'tem_chamada "setsid sh $S/suite.sh tomada queda_de_energia"' "a suite nao foi lancada"
  afirma 'tem_chamada "setprop persist.sys.boot.reason pfl7560,ligado"' "a marca nao foi regravada"
  limpa

  novo_cenario "gatilho: marca so no persist (bootstat limpou o sys) = queda_de_energia"
  instala_suite
  awk '!/^(sys|persist\.sys)\.boot\.reason=/' "$T/props" > "$T/p" && printf '%s\n' "sys.boot.reason=reboot" "persist.sys.boot.reason=pfl7560,ligado" >> "$T/p" && mv "$T/p" "$T/props"
  roda_boot
  afirma 'ult_hist | grep -q "decisao=sim; motivo=queda_de_energia$"' "historico: '$(ult_hist)'"
  limpa

  novo_cenario "gatilho: desligamento limpo = nao roda, mas a marca e gravada para o proximo boot"
  instala_suite
  roda_boot
  afirma 'ult_hist | grep -q "decisao=nao; motivo=desligamento_limpo$"' "historico: '$(ult_hist)'"
  afirma 'tem_chamada "setprop persist.sys.boot.reason pfl7560,ligado"' "a marca nao foi gravada"
  limpa

  novo_cenario "gatilho: nunca = a marca nao e gravada"
  instala_suite; echo nunca > "$S/gatilho"
  roda_boot
  afirma '! grep -q "^setprop persist.sys.boot.reason" "$T/calls.log"' "gravou a marca com gatilho nunca"
  limpa

  novo_cenario "gatilho: sem a linha do relogio no dmesg vale so o motivo"
  instala_suite
  roda_boot
  afirma 'ult_hist | grep -q "ano_boot=; .*decisao=nao; motivo=desligamento_limpo$"' "historico: '$(ult_hist)'"
  limpa
}

c_gatilho_bloqueios(){
  novo_cenario "gatilho: a suite terminou ha 1 min = nao roda (protecao contra laco)"
  instala_suite; echo sempre > "$S/gatilho"
  echo $(( $(date +%s) - 60 )) > "$S/ultimo-fim"
  roda_boot
  afirma 'ult_hist | grep -q "decisao=nao; motivo=terminou_ha_menos_de_10min$"' "historico: '$(ult_hist)'"
  afirma '! grep -q "suite.sh tomada" "$T/calls.log"' "lancou dentro dos 10 min"
  limpa

  novo_cenario "gatilho: a suite terminou ha 12 min = roda"
  instala_suite; echo sempre > "$S/gatilho"
  echo $(( $(date +%s) - 720 )) > "$S/ultimo-fim"
  roda_boot
  afirma 'ult_hist | grep -q "decisao=sim; motivo=gatilho_sempre$"' "historico: '$(ult_hist)'"
  limpa

  novo_cenario "gatilho: relogio que voltou no tempo (fim no futuro) nao bloqueia"
  instala_suite; echo sempre > "$S/gatilho"
  echo $(( $(date +%s) + 100000 )) > "$S/ultimo-fim"
  roda_boot
  afirma 'ult_hist | grep -q "decisao=sim"' "historico: '$(ult_hist)'"
  limpa

  novo_cenario "gatilho: pendrive do kit montado no boot = o fluxo do pendrive cobre"
  instala_suite; echo sempre > "$S/gatilho"
  pendrive
  roda_boot
  afirma 'ult_hist | grep -q "decisao=nao; motivo=pendrive_do_kit_montado$"' "historico: '$(ult_hist)'"
  afirma '! grep -q "suite.sh tomada" "$T/calls.log"' "lancou com o pendrive montado"
  limpa

  novo_cenario "gatilho: trava ocupada = nao roda"
  instala_suite; echo sempre > "$S/gatilho"
  mkdir "$R/dev/pfl7560-suite.lock"
  roda_boot
  afirma 'ult_hist | grep -q "decisao=nao; motivo=trava_ocupada$"' "historico: '$(ult_hist)'"
  limpa

  novo_cenario "gatilho: historico guarda no maximo 30 boots, com todos os sinais"
  instala_suite
  echo "[    1.2] rtc-hisi rtc0: setting system clock to 2026-10-30 22:00:05 UTC (1793411205)" > "$T/dmesg"
  local i=0
  # entre um boot e outro, um desligamento limpo (o sistema sobrescreve a marca)
  while [ "$i" -lt 35 ]; do
    awk '!/^persist\.sys\.boot\.reason=/' "$T/props" > "$T/p" && echo "persist.sys.boot.reason=shutdown,userrequested" >> "$T/p" && mv "$T/p" "$T/props"
    roda_boot; i=$((i+1))
  done
  afirma '[ "$(grep -c "" "$S/historico-boot.txt")" = 30 ]' "historico com $(grep -c "" "$S/historico-boot.txt") linhas"
  afirma 'ult_hist | grep -q "boot_reason=shutdown,userrequested; persist_boot_reason=shutdown,userrequested; ro_bootreason=shutdown,userrequested; relogio_boot=2026-10-30 22:00:05 UTC (1793411205); ano_boot=2026; rtc_epoch=1793400000; pm=pm_state: normal wakeup: power"' "sinais faltando: '$(ult_hist)'"
  afirma '[ -z "$(LC_ALL=C grep -nP "[^\x20-\x7E]" "$S/historico-boot.txt")" ]' "historico com byte fora de ASCII imprimivel"
  limpa
}

c_gatilho_seguranca(){
  novo_cenario "boot: suite.sh adulterado = decide mas NAO executa"
  instala_suite; echo sempre > "$S/gatilho"
  printf 'touch "%s"\n' "$T/adulterado-rodou" >> "$S/suite.sh"
  roda_boot
  afirma '! grep -q "suite.sh tomada" "$T/calls.log"' "lancou o suite.sh adulterado"
  afirma 'grep -q "md5 diferente do embutido - NAO executado" "$S/boot.log"' "log sem a recusa"
  limpa

  novo_cenario "boot: suite.sh trocado por LINK de mesmo conteudo = NAO executa"
  instala_suite; echo sempre > "$S/gatilho"
  cp "$S/suite.sh" "$T/suite.igual"; rm -f "$S/suite.sh"; ln -s "$T/suite.igual" "$S/suite.sh"
  roda_boot
  afirma '! grep -q "suite.sh tomada" "$T/calls.log"' "lancou um suite.sh que e link"
  limpa

  novo_cenario "boot: pasta da suite aberta a outros = nada feito"
  instala_suite; chmod 755 "$S"
  roda_boot
  afirma '[ "$RC" = 1 ] && [ ! -e "$S/historico-boot.txt" ] && [ ! -e "$S/boot.log" ]' "agiu numa pasta aberta (rc=$RC)"
  afirma '[ "$(chamadas setsid)" = 0 ] && [ "$(chamadas inotifyd)" = 0 ]' "lancou algo"
  limpa

  novo_cenario "boot: pasta da suite e LINK (para uma pasta com os scripts) = nada feito"
  instala_suite; echo sempre > "$S/gatilho"; mv "$S" "$T/alvo"; ln -s "$T/alvo" "$S"
  roda_boot
  afirma '[ "$RC" = 1 ] && [ ! -e "$T/alvo/historico-boot.txt" ] && [ ! -e "$T/alvo/boot.log" ]' "escreveu no alvo do link (rc=$RC)"
  afirma '[ "$(chamadas setsid)" = 0 ] && [ "$(chamadas inotifyd)" = 0 ]' "lancou algo"
  limpa
}

c_vigia(){
  novo_cenario "vigia: inotifyd na pasta do pedido, mascara wwy (o toybox ignora a 1a letra)"
  instala_suite
  roda_boot
  afirma 'tem_chamada "inotifyd $S/suite-pedido.sh $PED:wwy $PEDH:wwy"' "inotifyd nao foi ligado: $(grep inotifyd "$T/calls.log")"
  afirma 'grep -q "vigia do pedido ligado: inotifyd" "$S/boot.log"' "log sem o tipo do vigia"
  afirma '[ -s "$R/dev/pfl7560-suite.vigia" ]' "sem o pid do vigia"
  limpa

  novo_cenario "vigia: pedido pendente de antes do vigia = tratado uma vez ao ligar"
  instala_suite; : > "$PED/pedir-verificacao"
  roda_boot
  afirma 'grep -q "pedido pendente de antes do vigia" "$S/boot.log" && tem_chamada "setsid sh $S/suite.sh pedido" && [ ! -e "$PED/pedir-verificacao" ]' "o pendente nao foi tratado: $(tail -3 "$S/boot.log" | tr '\n' '|')"
  limpa

  novo_cenario "vigia: um so por boot (o vivo nao e duplicado)"
  instala_suite
  sh -c 'sleep 30; :' pfl7560-vigia-teste & local vp=$!
  echo "$vp" > "$R/dev/pfl7560-suite.vigia"
  roda_boot
  afirma '[ "$(chamadas inotifyd)" = 0 ]' "ligou um 2o vigia"
  afirma 'grep -q "vigia do pedido ja ligado" "$S/boot.log"' "log sem o aviso"
  kill "$vp" 2>/dev/null; wait "$vp" 2>/dev/null
  limpa

  novo_cenario "vigia: suite-pedido.sh adulterado = vigia NAO ligado"
  instala_suite
  echo "# x" >> "$S/suite-pedido.sh"
  roda_boot
  afirma '[ "$(chamadas inotifyd)" = 0 ]' "ligou o vigia com o suite-pedido.sh adulterado"
  limpa

  novo_cenario "vigia: pasta do Verificar e LINK = so a da home e vigiada"
  instala_suite; rmdir "$PED"; mkdir -p "$T/alvo"; ln -s "$T/alvo" "$PED"
  roda_boot
  afirma 'tem_chamada "inotifyd $S/suite-pedido.sh $PEDH:wwy" && ! grep -q "inotifyd.*$PED:" "$T/calls.log"' "vigiou o link ou largou a home: $(grep inotifyd "$T/calls.log")"
  limpa

  novo_cenario "vigia: as duas pastas em LINK = vigia NAO ligado"
  instala_suite; rmdir "$PED" "$PEDH"; mkdir -p "$T/alvo"; ln -s "$T/alvo" "$PED"; ln -s "$T/alvo" "$PEDH"
  roda_boot
  afirma '[ "$(chamadas inotifyd)" = 0 ] && grep -q "nenhuma pasta de app para vigiar" "$S/boot.log"' "vigiou um link"
  limpa

  novo_cenario "pedido: luz pela pasta do Verificar e verificacao pela pasta da home = ignorados"
  instala_suite; echo 60 > "$PED/luz"; : > "$PEDH/pedir-verificacao"
  roda_pedido w "$PED" luz; roda_pedido w "$PEDH" pedir-verificacao
  afirma '[ "$(grep -c "^HIDEBUG" "$T/calls.log")" = 0 ] && [ "$(chamadas setsid)" = 0 ] && [ -e "$PED/luz" ] && [ -e "$PEDH/pedir-verificacao" ]' "aceitou pedido da pasta errada"
  limpa

  if ! command -v inotifyd >/dev/null 2>&1; then
    novo_cenario "vigia: sem inotifyd = laco; um pedido no laco lanca a suite"
    instala_suite
    rm -f "$T/bin/inotifyd"
    : > "$PED/pedir-verificacao"
    roda_boot
    afirma 'grep -q "vigia do pedido ligado: laco de 30s" "$S/boot.log"' "log sem o laco: $(cat "$S/boot.log")"
    afirma 'tem_chamada "setsid sh $S/suite.sh pedido"' "o pedido no laco nao lancou a suite"
    afirma '[ ! -e "$PED/pedir-verificacao" ]' "o pedido nao foi apagado"
    limpa

    novo_cenario "vigia: sem inotifyd = laco; o descanso de tela (inicio e fim) tambem chega ao suite-pedido"
    instala_suite; echo 60 > "$S/luz"; chmod 600 "$S/luz"
    rm -f "$T/bin/inotifyd"
    printf '%s\n' "$PED/descanso-inicio" "$PED/descanso-fim" > "$T/sleep-cria"
    roda_boot
    afirma 'tem_chamada "HIDEBUG  picture sbl 10 quit " && grep -q "luz de volta a 60%" "$S/vigia.log"' "o laco ignorou o descanso: $(grep HIDEBUG "$T/calls.log" | tr '\n' '|')"
    afirma '[ ! -e "$PED/descanso-inicio" ] && [ ! -e "$PED/descanso-fim" ]' "o sinal do descanso nao foi apagado"
    limpa
  else
    echo "  (o host tem inotifyd: caso do laco pulado)"
  fi
}

# descanso de tela MeowCast (bloco 16B): o suite-boot.sh aponta o sistema para o .Descanso
sdb(){ awk -v k="secure $1" 'index($0, k "=") == 1 { print substr($0, length(k) + 2) }' "$T/settings.db" 2>/dev/null; }
c_descanso(){
  local D="com.pfl7560.verificar/.Descanso" FAB="com.newlink.screensaver/com.newlink.screensaver.ScreenService"
  novo_cenario "descanso: do fabricante = o boot aponta as duas chaves para o MeowCast"
  instala_suite
  printf 'secure screensaver_components=%s\nsecure screensaver_default_component=%s\n' "$FAB" "$FAB" > "$T/settings.db"
  roda_boot
  afirma '[ "$(sdb screensaver_components)" = "$D" ] && [ "$(sdb screensaver_default_component)" = "$D" ]' "chaves: $(tr '\n' '|' < "$T/settings.db")"
  afirma 'grep -q "descanso: screensaver_components era" "$S/boot.log"' "log sem a troca"
  limpa

  novo_cenario "descanso: chaves vazias (null) tambem sao apontadas; segundo boot nao regrava"
  instala_suite
  roda_boot
  afirma '[ "$(sdb screensaver_components)" = "$D" ] && [ "$(sdb screensaver_default_component)" = "$D" ]' "chaves: $(tr '\n' '|' < "$T/settings.db")"
  : > "$T/calls.log"
  roda_boot
  afirma '! grep -q "^settings put" "$T/calls.log" && grep -q "screensaver_components ja e" "$S/boot.log"' "regravou o que ja estava certo: $(grep '^settings' "$T/calls.log" | tr '\n' '|')"
  limpa

  novo_cenario "descanso: so uma chave errada = so ela e regravada"
  instala_suite
  printf 'secure screensaver_components=%s\nsecure screensaver_default_component=%s\n' "$D" "$FAB" > "$T/settings.db"
  roda_boot
  afirma '[ "$(chamadas "settings put")" = 1 ] && [ "$(sdb screensaver_default_component)" = "$D" ]' "puts: $(grep '^settings put' "$T/calls.log" | tr '\n' '|')"
  limpa

  novo_cenario "descanso: servico ausente (cmd e dumpsys nao o veem) = nao mexe em nada"
  instala_suite; : > "$T/sem-descanso"
  printf 'secure screensaver_components=%s\n' "$FAB" > "$T/settings.db"
  roda_boot
  afirma '[ "$(chamadas "settings put")" = 0 ] && [ "$(sdb screensaver_components)" = "$FAB" ]' "mexeu sem o servico: $(cat "$T/settings.db")"
  afirma 'grep -q "descanso: o servico $D nao apareceu em 6 consultas" "$S/boot.log"' "log sem o aviso"
  limpa

  novo_cenario "descanso: o cmd nao responde mas o dumpsys package ve o servico = aponta"
  instala_suite; : > "$T/sem-descanso"; : > "$T/dumpsys-descanso"
  roda_boot
  afirma '[ "$(sdb screensaver_components)" = "$D" ]' "reserva do dumpsys nao funcionou: $(cat "$T/settings.db" 2>/dev/null)"
  limpa

  novo_cenario "descanso: com qualquer gatilho (nunca) o boot tambem aponta; falha do put so avisa"
  instala_suite; echo nunca > "$S/gatilho"
  roda_boot
  afirma '[ "$(sdb screensaver_components)" = "$D" ] && [ "$RC" = 0 ]' "gatilho nunca nao ligou o descanso (rc=$RC)"
  limpa
  novo_cenario "descanso: put que falha = aviso no log, o boot segue (vigia ligado)"
  instala_suite; : > "$T/settings-falha"
  roda_boot
  afirma '[ "$RC" = 0 ] && grep -q "AVISO.*nao consegui gravar screensaver_components" "$S/boot.log" && tem_chamada "inotifyd $S/suite-pedido.sh $PED:wwy"' "o boot parou no put (rc=$RC): $(tail -4 "$S/boot.log" | tr '\n' '|')"
  limpa
}

# bloco 14: o suite-boot.sh liga as sobreposicoes de tema (a do android por ultimo) e desliga os apps do fabricante
OVL_PKGS="zysetting nlprovision tvsettings android"
overlays_cenario(){ # pastas em /vendor/overlay e o estado do sistema (todas desligadas)
  local x
  mkdir -p "$R/vendor/overlay"
  : > "$T/overlay.db"
  echo "com.zhiying.settings" >> "$T/overlay.db"
  for x in $OVL_PKGS; do
    mkdir -p "$R/vendor/overlay/PFL7560Tema$x"
    echo "[ ] com.pfl7560.tema.$x" >> "$T/overlay.db"
  done
}
ovdb(){ sed -n "s/^\\(\\[.\\]\\) com\\.pfl7560\\.tema\\.$1\$/\\1/p" "$T/overlay.db"; }
enables(){ grep '^cmd overlay enable' "$T/calls.log" | sed 's/.*tema\.//' | tr '\n' ' '; }
c_overlays_boot(){
  novo_cenario "overlay: desligadas = o boot liga todas, a do android por ultimo; 2o boot nao liga nada"
  instala_suite; overlays_cenario
  roda_boot
  afirma '[ "$RC" = 0 ] && [ "$(ovdb zysetting)" = "[x]" ] && [ "$(ovdb nlprovision)" = "[x]" ] && [ "$(ovdb tvsettings)" = "[x]" ] && [ "$(ovdb android)" = "[x]" ]' "estado: $(tr '\n' '|' < "$T/overlay.db")"
  afirma '[ "$(enables | awk "{print \$NF}")" = android ] && [ "$(enables | wc -w | tr -d " ")" = 4 ]' "ordem das ligacoes: $(enables)"
  afirma 'grep -q "overlay: 4 ligada(s) neste boot" "$S/boot.log"' "log sem o resumo: $(grep overlay "$S/boot.log" | tr '\n' '|')"
  : > "$T/calls.log"
  roda_boot
  afirma '[ -z "$(enables)" ] && grep -q "overlay: 0 ligada(s) neste boot" "$S/boot.log"' "2o boot ligou de novo: $(enables)"
  limpa

  novo_cenario "overlay: a que ja esta ligada ([x]) nao e tocada, so as desligadas"
  instala_suite; overlays_cenario
  sed -i 's/^\[ \] com.pfl7560.tema.zysetting$/[x] com.pfl7560.tema.zysetting/' "$T/overlay.db"
  roda_boot
  afirma '[ "$(enables | tr " " "\n" | grep -c zysetting)" = 0 ] && [ "$(enables | wc -w | tr -d " ")" = 3 ] && [ "$(ovdb zysetting)" = "[x]" ]' "ligacoes: $(enables)"
  limpa

  novo_cenario "overlay: o PackageManager ainda processando (lista vazia nas 3 primeiras consultas) = espera e liga"
  instala_suite; overlays_cenario; echo 3 > "$T/overlay-demora"
  roda_boot
  afirma '[ "$(ovdb android)" = "[x]" ] && [ "$(enables | wc -w | tr -d " ")" = 4 ] && [ "$(chamadas "sleep 0")" -ge 3 ]' "nao esperou: $(enables); sleeps=$(chamadas "sleep 0")"
  limpa

  novo_cenario "overlay: o sistema nunca as lista = 6 consultas, aviso e nada ligado; o boot segue (vigia ligado)"
  instala_suite; overlays_cenario; echo 99 > "$T/overlay-demora"
  roda_boot
  afirma '[ "$RC" = 0 ] && [ -z "$(enables)" ] && grep -q "overlay: o sistema lista 0 de 4 sobreposicoes depois de 6 consultas" "$S/boot.log" && tem_chamada "inotifyd $S/suite-pedido.sh $PED:wwy"' "rc=$RC; $(grep overlay "$S/boot.log" | tr '\n' '|')"
  limpa

  novo_cenario "overlay: o enable de uma falha = aviso e as outras (inclusive a do android) seguem"
  instala_suite; overlays_cenario; echo com.pfl7560.tema.nlprovision > "$T/overlay-enable-falha"
  roda_boot
  afirma '[ "$(ovdb nlprovision)" = "[ ]" ] && [ "$(ovdb zysetting)" = "[x]" ] && [ "$(ovdb android)" = "[x]" ] && grep -q "AVISO.*overlay: nao consegui ligar com.pfl7560.tema.nlprovision" "$S/boot.log" && [ "$RC" = 0 ]' "estado: $(tr '\n' '|' < "$T/overlay.db"); rc=$RC"
  limpa

  novo_cenario "overlay: sem pasta nossa em /vendor/overlay = nada a ligar, nem pergunta ao sistema"
  instala_suite; : > "$T/overlay.db"
  roda_boot
  afirma '[ "$(chamadas "cmd overlay")" = 0 ] && grep -q "overlay: nenhuma sobreposicao nossa em /vendor/overlay" "$S/boot.log"' "consultou o sistema sem ter o que ligar: $(grep '^cmd overlay' "$T/calls.log" | head -2)"
  limpa

  novo_cenario "overlay: com o gatilho nunca o boot tambem liga"
  instala_suite; overlays_cenario; echo nunca > "$S/gatilho"
  roda_boot
  afirma '[ "$(ovdb android)" = "[x]" ] && [ "$RC" = 0 ]' "gatilho nunca nao ligou: $(tr '\n' '|' < "$T/overlay.db")"
  limpa
}

APPS14="com.mobisystems.editor.office_registered com.newlink.cast com.hisilicon.miracast"
apps_cenario(){ local a; : > "$T/pm-instalados"; : > "$T/pm-desligados"; for a in $APPS14 org.videolan.vlc; do echo "$a" >> "$T/pm-instalados"; done; }
restr_tem(){ grep -a "name=\"$1\"" "$R/data/system/users/0/package-restrictions.xml" 2>/dev/null | grep -aq 'enabled="3"'; }
c_apps_boot(){
  local a
  novo_cenario "apps: ligados = o boot desliga so os tres e confere o enabled=3; 2o boot nao mexe"
  instala_suite; apps_cenario
  roda_boot
  afirma '[ "$RC" = 0 ] && [ "$(sort "$T/pm-desligados" | tr "\n" " ")" = "$(echo $APPS14 | tr " " "\n" | sort | tr "\n" " ")" ]' "desligados: $(tr '\n' ' ' < "$T/pm-desligados")"
  for a in $APPS14; do afirma 'restr_tem "$a"' "$a sem enabled=3 no package-restrictions.xml"; done
  afirma 'grep -q "apps: estado gravado no package-restrictions.xml (enabled=3)" "$S/boot.log" && ! tem_chamada "pm disable-user --user 0 org.videolan.vlc"' "log ou desligou o que nao devia: $(grep apps "$S/boot.log" | tr '\n' '|')"
  : > "$T/calls.log"
  roda_boot
  afirma '[ "$(chamadas "pm disable-user")" = 0 ] && [ "$(grep -c "apps: .* ja estava desligado" "$S/boot.log")" = 3 ]' "2o boot desligou de novo: $(grep '^pm disable' "$T/calls.log")"
  limpa

  novo_cenario "apps: um nao instalado = pulado, os outros desligados"
  instala_suite; apps_cenario; sed -i '/com.newlink.cast/d' "$T/pm-instalados"
  roda_boot
  afirma 'grep -q "apps: com.newlink.cast nao esta instalado" "$S/boot.log" && [ "$(wc -l < "$T/pm-desligados" | tr -d " ")" = 2 ]' "desligados: $(tr '\n' ' ' < "$T/pm-desligados"); $(grep apps "$S/boot.log" | tr '\n' '|')"
  limpa

  novo_cenario "apps: o xml so e gravado depois de 2 esperas = o boot espera e confirma"
  instala_suite; apps_cenario; echo 2 > "$T/restr-atraso"
  roda_boot
  afirma 'restr_tem com.newlink.cast && grep -q "apps: estado gravado no package-restrictions.xml" "$S/boot.log"' "nao esperou o xml: $(grep apps "$S/boot.log" | tr '\n' '|')"
  limpa

  novo_cenario "apps: o xml nunca grava = aviso de que ainda nao mostra enabled=3 (nao reiniciar ja)"
  instala_suite; apps_cenario; : > "$T/restr-nunca"
  roda_boot
  afirma '[ "$RC" = 0 ] && grep -q "AVISO.*apps: o package-restrictions.xml ainda nao mostra enabled=3 para:" "$S/boot.log"' "rc=$RC; $(grep apps "$S/boot.log" | tr '\n' '|')"
  limpa

  novo_cenario "apps: o pm disable-user falha = aviso por app, o boot segue"
  instala_suite; apps_cenario; : > "$T/pm-disable-falha"
  roda_boot
  afirma '[ "$RC" = 0 ] && [ "$(grep -c "AVISO.*apps: nao consegui desligar" "$S/boot.log")" = 3 ] && [ -z "$(cat "$T/pm-desligados")" ]' "rc=$RC; $(grep apps "$S/boot.log" | tr '\n' '|')"
  limpa

  novo_cenario "apps: o pm nao responde = 6 consultas, aviso, nada desligado"
  instala_suite; apps_cenario; : > "$T/pm-fora"
  roda_boot
  afirma '[ "$RC" = 0 ] && grep -q "AVISO.*apps: o pm nao respondeu em 6 consultas" "$S/boot.log" && [ "$(chamadas "pm disable-user")" = 0 ]' "rc=$RC; $(grep apps "$S/boot.log" | tr '\n' '|')"
  limpa

  novo_cenario "apps: com o gatilho nunca o boot tambem desliga"
  instala_suite; apps_cenario; echo nunca > "$S/gatilho"
  roda_boot
  afirma '[ "$(wc -l < "$T/pm-desligados" | tr -d " ")" = 3 ] && [ "$RC" = 0 ]' "gatilho nunca nao desligou: $(tr '\n' ' ' < "$T/pm-desligados")"
  limpa
}

c_pedido(){
  novo_cenario "pedido: arquivo do pedido = apaga e lanca suite.sh pedido"
  instala_suite; echo "qualquer conteudo" > "$PED/pedir-verificacao"
  roda_pedido w "$PED" pedir-verificacao
  afirma '[ ! -e "$PED/pedir-verificacao" ]' "o pedido nao foi apagado"
  afirma 'tem_chamada "setsid sh $S/suite.sh pedido"' "nao lancou a suite"
  limpa

  novo_cenario "pedido: evento n (criado, ainda sem o conteudo) = ignorado; o w vem depois"
  instala_suite; : > "$PED/pedir-verificacao"
  roda_pedido n "$PED" pedir-verificacao
  afirma '[ "$(chamadas setsid)" = 0 ] && [ -e "$PED/pedir-verificacao" ]' "tratou o evento de criacao"
  limpa

  local ev
  for ev in "w outro-arquivo" "d pedir-verificacao" "w ../pedir-verificacao"; do
    novo_cenario "pedido: evento '$ev' = ignorado"
    instala_suite; : > "$PED/pedir-verificacao"
    # shellcheck disable=SC2086
    set -- $ev
    roda_pedido "$1" "$PED" "$2"
    afirma '[ "$(chamadas setsid)" = 0 ]' "lancou com o evento '$ev'"
    limpa
  done

  novo_cenario "pedido: pasta que nao e de app (UID abaixo do minimo) = apaga e ignora"
  instala_suite; : > "$PED/pedir-verificacao"
  APP_UID_MIN_TESTE=99999999 roda_pedido w "$PED" pedir-verificacao
  afirma '[ "$(chamadas setsid)" = 0 ] && grep -q "nao veio do app" "$S/vigia.log"' "lancou um pedido que nao veio do app"
  afirma '[ ! -e "$PED/pedir-verificacao" ]' "o pedido recusado nao foi apagado"
  limpa

  novo_cenario "pedido: o pedido e um LINK = apaga o link e ignora"
  instala_suite; : > "$T/alvo-pedido"; ln -s "$T/alvo-pedido" "$PED/pedir-verificacao"
  roda_pedido w "$PED" pedir-verificacao
  afirma '[ "$(chamadas setsid)" = 0 ] && [ -f "$T/alvo-pedido" ] && [ ! -L "$PED/pedir-verificacao" ]' "seguiu ou lancou por um link"
  limpa

  novo_cenario "pedido: a suite terminou ha 2 min = roda assim mesmo (o pedido e do dono)"
  instala_suite; echo $(( $(date +%s) - 120 )) > "$S/ultimo-fim"; : > "$PED/pedir-verificacao"
  roda_pedido w "$PED" pedir-verificacao
  afirma 'tem_chamada "setsid sh $S/suite.sh pedido" && grep -q "o pedido e do dono: roda" "$S/vigia.log"' "nao lancou o pedido do dono dentro dos 10 min"
  limpa

  novo_cenario "pedido: trava ocupada = ignorado"
  instala_suite; mkdir "$R/dev/pfl7560-suite.lock"; : > "$PED/pedir-verificacao"
  roda_pedido w "$PED" pedir-verificacao
  afirma '[ "$(chamadas setsid)" = 0 ] && grep -q "trava" "$S/vigia.log"' "lancou com a trava ocupada"
  limpa

  novo_cenario "pedido: suite.sh adulterado = NAO executa"
  instala_suite; echo "# x" >> "$S/suite.sh"; : > "$PED/pedir-verificacao"
  roda_pedido y "$PED" pedir-verificacao
  afirma '[ "$(chamadas setsid)" = 0 ] && grep -q "NAO executado" "$S/vigia.log"' "lancou o suite.sh adulterado"
  limpa
}

# bloco 15: o atalho Luz da home. $PED/luz e o pedido do app; a resposta do root e a prop
# vendor.pfl7560.luz (o root nao escreve na pasta do app)
luz_prop(){ awk -F= '$1=="vendor.pfl7560.luz"{v=$2} END{print v}' "$T/props"; }
hb(){ grep -c "^HIDEBUG" "$T/calls.log" 2>/dev/null || true; }
modo(){ stat -c %a "$1" 2>/dev/null; }
c_luz(){
  local v
  novo_cenario "luz: pedido valido (60) = guarda, aplica pelo hidebug, confere e devolve ao app"
  instala_suite; printf '60' > "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma 'tem_chamada "HIDEBUG  picture sbl 60 quit "' "sem o sbl 60: $(grep HIDEBUG "$T/calls.log")"
  afirma 'tem_chamada "HIDEBUG  picture gbl quit "' "sem a leitura gbl"
  afirma '[ "$(cat "$S/luz")" = 60 ] && [ "$(modo "$S/luz")" = 600 ]' "luz guardada errada: '$(cat "$S/luz" 2>/dev/null)' modo $(modo "$S/luz")"
  afirma '[ "$(luz_prop)" = 60 ] && tem_chamada "setprop vendor.pfl7560.luz 60"' "prop da luz errada: '$(luz_prop)'"
  afirma '[ -z "$(ls -A "$PEDH")" ] && [ ! -e "$S/luz.pedido" ]' "sobrou algo na pasta do app ou na da suite: $(ls -A "$PEDH") $(ls -d "$S"/*pedido* 2>/dev/null)"
  afirma '! grep -q "chown" "$T/calls.log"' "o root mexeu em dono de arquivo: $(grep chown "$T/calls.log")"
  afirma '[ "$(chamadas setsid)" = 0 ] && ! grep -q "^GTT" "$T/calls.log" && ! grep -q "^HIDEBUG.*gtt" "$T/calls.log"' "lancou a suite ou chamou gtt"
  afirma 'grep -q "luz 60% aplicada" "$S/vigia.log"' "log sem a confirmacao: $(tail -3 "$S/vigia.log")"
  limpa

  # a luz nao tem a protecao de 10 min
  novo_cenario "luz: a suite terminou ha 1 min = aplica mesmo assim (sem a protecao de 10 min)"
  instala_suite; echo $(( $(date +%s) - 60 )) > "$S/ultimo-fim"; printf '80\n' > "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma '[ "$(luz_prop)" = 80 ] && tem_chamada "sbl 80"' "nao aplicou dentro dos 10 min"
  limpa

  novo_cenario "luz: zeros a esquerda e fim de linha (060) = 60"
  instala_suite; printf '060\r\n' > "$PEDH/luz"
  roda_pedido y "$PEDH" luz
  afirma '[ "$(luz_prop)" = 60 ] && tem_chamada "sbl 60 quit"' "060 nao virou 60"
  limpa

  for v in abc 5 9 200 101 "" 1000 -60 "6a0" "60 70" "0" "000" "6.0"; do
    novo_cenario "luz: pedido invalido '$v' = recusado, nada aplicado"
    instala_suite; printf '%s' "$v" > "$PEDH/luz"
    roda_pedido w "$PEDH" luz
    afirma '[ "$(hb)" = 0 ] && [ ! -e "$S/luz" ] && [ -z "$(luz_prop)" ]' "aplicou/guardou o invalido '$v': $(grep HIDEBUG "$T/calls.log")"
    afirma '[ ! -e "$PEDH/luz" ] && grep -q "recusado" "$S/vigia.log"' "o invalido '$v' nao foi apagado/registrado"
    limpa
  done

  novo_cenario "luz: o pedido e um LINK = apaga o link, nao le o alvo, nada aplicado"
  instala_suite; echo 60 > "$T/alvo-luz"; ln -s "$T/alvo-luz" "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma '[ "$(hb)" = 0 ] && [ ! -e "$S/luz" ] && [ "$(cat "$T/alvo-luz")" = 60 ] && [ ! -L "$PEDH/luz" ]' "seguiu o link"
  limpa

  novo_cenario "luz: pasta que nao e de app (UID abaixo do minimo) = apaga e ignora"
  instala_suite; echo 60 > "$PEDH/luz"
  APP_UID_MIN_TESTE=99999999 roda_pedido w "$PEDH" luz
  afirma '[ "$(hb)" = 0 ] && [ ! -e "$S/luz" ] && grep -q "nao veio do app" "$S/vigia.log" && [ ! -e "$PEDH/luz" ]' "aceitou luz de quem nao e app"
  limpa

  novo_cenario "luz: eventos que nao sao w/y e nomes parecidos = ignorados"
  instala_suite; echo 60 > "$PEDH/luz"
  roda_pedido n "$PEDH" luz; roda_pedido d "$PEDH" luz; roda_pedido w "$PEDH" luzes; roda_pedido w "$PEDH" luz-atual; roda_pedido w "$PEDH" ../luz
  afirma '[ "$(hb)" = 0 ] && [ -e "$PEDH/luz" ]' "tratou um evento que nao devia"
  limpa

  novo_cenario "luz: trava ocupada (rampa no meio) = guarda, nao aplica"
  instala_suite; mkdir "$R/dev/pfl7560-suite.lock"; echo 40 > "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma '[ "$(hb)" = 0 ] && [ "$(cat "$S/luz")" = 40 ] && grep -q "trava" "$S/vigia.log" && [ -z "$(luz_prop)" ]' "aplicou com a trava ou nao guardou"
  limpa

  novo_cenario "luz: o gbl nao confirma (gravacao atrasada do fabricante) = avisa, 3 leituras, devolve o que o aparelho disse"
  instala_suite; echo 100 > "$T/bl"; : > "$T/bl-trava"; echo 60 > "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma '[ "$(grep -c "HIDEBUG  picture gbl" "$T/calls.log")" = 3 ] && [ "$(chamadas "sleep 1")" = 2 ]' "nao tentou 3 vezes: $(grep -c gbl "$T/calls.log") leituras"
  afirma 'grep -q "gbl leu .100." "$S/vigia.log" && [ "$(luz_prop)" = 100 ] && [ "$(cat "$S/luz")" = 60 ]' "aviso/luz-atual/guardada erradas: $(tail -2 "$S/vigia.log")"
  limpa

  novo_cenario "luz: links plantados no app = o root nao toca neles"
  instala_suite; echo X > "$T/alvo-x"; ln -s "$T/alvo-x" "$PEDH/luz-atual"; ln -s "$T/alvo-x" "$PEDH/luz-atual.novo"; echo 60 > "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma '[ "$(cat "$T/alvo-x")" = X ] && [ -L "$PEDH/luz-atual" ] && [ -L "$PEDH/luz-atual.novo" ] && [ "$(luz_prop)" = 60 ]' "o root mexeu nos links do app"
  limpa

  novo_cenario "luz: FIFO no lugar do pedido = recusado sem travar o vigia"
  instala_suite; mkfifo "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma '[ "$(hb)" = 0 ] && [ ! -e "$S/luz" ] && [ ! -e "$S/luz.pedido" ] && [ ! -e "$PEDH/luz" ]' "o FIFO foi lido, aplicado ou sobrou"
  limpa

  novo_cenario "luz: sem o hidebug = guarda, avisa, nao publica a prop"
  instala_suite; rm -f "$R/vendor/bin/hidebug"; echo 60 > "$PEDH/luz"
  roda_pedido w "$PEDH" luz
  afirma '[ "$(cat "$S/luz")" = 60 ] && grep -q "hidebug ausente" "$S/vigia.log" && [ -z "$(luz_prop)" ]' "reagiu mal ao hidebug ausente"
  limpa

  novo_cenario "luz: a verificacao continua funcionando (luz e depois pedir-verificacao)"
  instala_suite; echo 60 > "$PEDH/luz"; : > "$PED/pedir-verificacao"
  roda_pedido w "$PEDH" luz; roda_pedido w "$PED" pedir-verificacao
  afirma 'tem_chamada "setsid sh $S/suite.sh pedido" && [ ! -e "$PED/pedir-verificacao" ] && [ "$(luz_prop)" = 60 ]' "a verificacao ou a luz quebrou"
  limpa

  # ---- descanso de tela: luz a 10% e volta ----
  novo_cenario "descanso: inicio = luz a 10% sem mexer no nivel guardado; fim = volta ao guardado"
  instala_suite; echo 60 > "$S/luz"; chmod 600 "$S/luz"; echo 60 > "$T/bl"; : > "$PED/descanso-inicio"
  roda_pedido w "$PED" descanso-inicio
  afirma 'tem_chamada "HIDEBUG  picture sbl 10 quit " && [ "$(cat "$S/luz")" = 60 ] && [ ! -e "$PED/descanso-inicio" ]' "inicio: $(grep HIDEBUG "$T/calls.log")"
  : > "$PED/descanso-fim"
  roda_pedido w "$PED" descanso-fim
  afirma 'tem_chamada "HIDEBUG  picture sbl 60 quit " && grep -q "luz de volta a 60%" "$S/vigia.log"' "fim nao voltou a 60"
  limpa

  novo_cenario "descanso: sem nivel guardado = o fim volta ao nivel de antes do descanso (gbl), nao a 100%"
  instala_suite; echo 70 > "$T/bl"; : > "$PED/descanso-inicio"
  roda_pedido w "$PED" descanso-inicio
  afirma '[ "$(cat "$S/luz-antes-descanso" 2>/dev/null)" = 70 ] && [ "$(stat -c %a "$S/luz-antes-descanso" 2>/dev/null)" = 600 ]' "inicio nao guardou o nivel de antes (0600): '$(cat "$S/luz-antes-descanso" 2>/dev/null)'"
  : > "$PED/descanso-fim"
  roda_pedido w "$PED" descanso-fim
  afirma 'tem_chamada "HIDEBUG  picture sbl 70 quit " && ! tem_chamada "sbl 100 quit" && grep -q "luz de volta a 70%" "$S/vigia.log"' "fim nao voltou a 70: $(grep HIDEBUG "$T/calls.log" | tr '\n' '|')"
  afirma '[ ! -e "$S/luz-antes-descanso" ]' "o nivel de antes do descanso sobrou depois do fim"
  limpa

  novo_cenario "descanso: dois inicio seguidos e depois fim = volta ao primeiro nivel (nao a 10%)"
  instala_suite; echo 70 > "$T/bl"; : > "$PED/descanso-inicio"
  roda_pedido w "$PED" descanso-inicio
  : > "$PED/descanso-inicio"
  roda_pedido w "$PED" descanso-inicio
  : > "$PED/descanso-fim"
  roda_pedido w "$PED" descanso-fim
  afirma '[ "$(grep "sbl" "$T/calls.log" | tail -1)" = "HIDEBUG  picture sbl 70 quit " ]' "o segundo inicio guardou 10: $(grep sbl "$T/calls.log" | tr '\n' '|')"
  limpa

  novo_cenario "descanso: fim sem inicio = volta ao nivel guardado"
  instala_suite; echo 40 > "$S/luz"; chmod 600 "$S/luz"; : > "$PED/descanso-fim"
  roda_pedido w "$PED" descanso-fim
  afirma 'tem_chamada "HIDEBUG  picture sbl 40 quit "' "nao voltou ao guardado: $(grep sbl "$T/calls.log" | tr '\n' '|')"
  limpa

  novo_cenario "descanso: fim sem inicio e sem nada guardado = 100%"
  instala_suite; : > "$PED/descanso-fim"
  roda_pedido w "$PED" descanso-fim
  afirma 'tem_chamada "HIDEBUG  picture sbl 100 quit "' "sem nada guardado nao voltou a 100"
  limpa

  novo_cenario "descanso: nivel de antes plantado como link = ignorado, volta ao guardado"
  instala_suite; echo 40 > "$S/luz"; chmod 600 "$S/luz"; echo 90 > "$T/alvo-l"; ln -s "$T/alvo-l" "$S/luz-antes-descanso"; : > "$PED/descanso-fim"
  roda_pedido w "$PED" descanso-fim
  afirma 'tem_chamada "HIDEBUG  picture sbl 40 quit " && ! tem_chamada "sbl 90 quit"' "seguiu o link: $(grep sbl "$T/calls.log" | tr '\n' '|')"
  limpa

  novo_cenario "descanso: com a suite rodando (trava) = nao mexe na luz"
  instala_suite; mkdir "$R/dev/pfl7560-suite.lock"; : > "$PED/descanso-inicio"
  roda_pedido w "$PED" descanso-inicio
  afirma '[ "$(grep -c "^HIDEBUG" "$T/calls.log")" = 0 ] && grep -q "descanso inicio sem efeito" "$S/vigia.log"' "mexeu na luz com a trava"
  limpa

  novo_cenario "descanso: pela pasta da home ou que nao veio do app = ignorado"
  instala_suite; : > "$PEDH/descanso-inicio"
  roda_pedido w "$PEDH" descanso-inicio
  : > "$PED/descanso-inicio"
  APP_UID_MIN_TESTE=99999999 roda_pedido w "$PED" descanso-inicio
  afirma '[ "$(grep -c "^HIDEBUG" "$T/calls.log")" = 0 ]' "aceitou descanso de origem errada"
  limpa

  novo_cenario "descanso: sinais velhos no boot sao apagados (o boot reaplica o nivel)"
  instala_suite; : > "$PED/descanso-inicio"; : > "$PED/descanso-fim"; echo 70 > "$S/luz-antes-descanso"
  roda_boot
  afirma '[ ! -e "$PED/descanso-inicio" ] && [ ! -e "$PED/descanso-fim" ] && ! grep -q "sbl 10" "$T/calls.log"' "sinal velho do descanso sobrou ou foi aplicado"
  afirma '[ ! -e "$S/luz-antes-descanso" ]' "o nivel de antes de um descanso velho sobrou no boot"
  limpa

  # ---- boot ----
  novo_cenario "luz: boot reaplica o nivel guardado e atualiza a prop da luz"
  instala_suite; echo 40 > "$S/luz"; chmod 600 "$S/luz"
  roda_boot
  afirma 'tem_chamada "HIDEBUG  picture sbl 40 quit " && [ "$(luz_prop)" = 40 ]' "nao reaplicou: $(grep HIDEBUG "$T/calls.log")"
  afirma 'grep -q "reaplicando a luz guardada: 40%" "$S/boot.log" && grep -q "vigia do pedido ligado" "$S/boot.log"' "log do boot: $(cat "$S/boot.log")"
  afirma 'awk "/sbl 40/ { a = NR } /^inotifyd/ { b = NR } END { exit !(a > 0 && b > a) }" "$T/calls.log"' "a luz nao foi aplicada antes do vigia"
  limpa

  novo_cenario "luz: boot com gatilho nunca reaplica do mesmo jeito (escolha do dono)"
  instala_suite; echo nunca > "$S/gatilho"; echo 25 > "$S/luz"; chmod 600 "$S/luz"
  roda_boot
  afirma 'tem_chamada "sbl 25 quit" && [ "$(luz_prop)" = 25 ] && [ "$(chamadas setsid)" = 0 ]' "gatilho nunca barrou a luz ou lancou a suite"
  limpa

  novo_cenario "luz: boot sem o arquivo luz nao mexe no hidebug"
  instala_suite
  roda_boot
  afirma '[ "$(hb)" = 0 ] && [ -z "$(luz_prop)" ]' "mexeu na luz sem escolha do dono"
  limpa

  for v in abc 5 200; do
    novo_cenario "luz: boot com o arquivo guardado invalido '$v' = nao aplica"
    instala_suite; printf '%s' "$v" > "$S/luz"; chmod 600 "$S/luz"
    roda_boot
    afirma '[ "$(hb)" = 0 ] && grep -q "invalida" "$S/boot.log"' "reaplicou o invalido '$v'"
    limpa
  done

  novo_cenario "luz: boot com o arquivo luz LINK = ignorado"
  instala_suite; echo 40 > "$T/alvo-luz"; ln -s "$T/alvo-luz" "$S/luz"
  roda_boot
  afirma '[ "$(hb)" = 0 ] && grep -q "link ou de outro dono" "$S/boot.log"' "seguiu o link"
  limpa

  novo_cenario "luz: boot com o suite-pedido.sh adulterado = luz NAO reaplicada"
  instala_suite; echo 40 > "$S/luz"; echo "# x" >> "$S/suite-pedido.sh"
  roda_boot
  afirma '[ "$(hb)" = 0 ] && grep -q "luz NAO reaplicada" "$S/boot.log"' "reaplicou com o script adulterado"
  limpa

  novo_cenario "luz: pedido de luz pendente de antes do vigia = tratado uma vez ao ligar"
  instala_suite; echo 70 > "$PEDH/luz"
  roda_boot
  afirma 'grep -q "pedido de luz pendente" "$S/boot.log" && [ "$(cat "$S/luz")" = 70 ] && [ "$(luz_prop)" = 70 ] && [ ! -e "$PEDH/luz" ]' "o pendente de luz nao foi tratado: $(tail -4 "$S/boot.log" | tr '\n' '|')"
  limpa
}

# ---------------------------------------------------------------------------
# B1 - instalacao pelo newlink_update.sh
# ---------------------------------------------------------------------------
c_instalacao(){
  local rc="$R/vendor/etc/init/pfl7560-suite.rc"
  novo_cenario "instalacao: arquivos, servico de boot e a suite lancada (a pasta do app nao e do kit)"
  pendrive; rc="$R/vendor/etc/init/pfl7560-suite.rc"
  roda_kit
  afirma '[ "$RC" = 0 ]' "newlink_update.sh saiu com $RC: $(tail -3 "$T/kit.out")"
  afirma 'ls -ld "$S" | grep -q "^drwx------"' "pasta da suite nao e 0700: $(ls -ld "$S")"
  local f
  for f in suite.sh suite-boot.sh suite-pedido.sh cor.sh lvdsctl nl_camcheck kit/aguarde.png kit/calibracao.png kit/pronto.png kit/erro.png; do
    afirma 'cmp -s "$KIT/$f" "$S/$f"' "$f nao foi para a pasta da suite"
  done
  afirma '[ -x "$S/suite.sh" ] && [ -x "$S/suite-boot.sh" ] && [ -x "$S/suite-pedido.sh" ]' "scripts da suite sem +x"
  afirma '[ ! -e "$S/pfl7560-suite.rc" ] && [ ! -e "$S/ZYCustom.ini" ]' "copiou .rc ou .ini para a pasta da suite"
  afirma '[ -z "$(ls -d "$S"/preparo.* 2>/dev/null)" ]' "sobrou pasta de preparo"
  afirma 'cmp -s "$KIT/pfl7560-suite.rc" "$rc"' "o .rc instalado nao e o do kit"
  afirma 'ls -l "$rc" | grep -q "^-rw-r--r--"' ".rc sem modo 0644: $(ls -l "$rc")"
  afirma 'tem_chamada "chown root:root $R/vendor/etc/pfl7560-suite.rc.new"' "sem chown root:root no .rc"
  afirma 'tem_chamada "chcon u:object_r:vendor_configs_file:s0 $R/vendor/etc/pfl7560-suite.rc.new"' "sem chcon no .rc: $(grep chcon "$T/calls.log")"
  afirma '[ ! -e "$R/vendor/etc/pfl7560-suite.rc.new" ] && [ ! -e "$R/vendor/etc/init/pfl7560-suite.rc.new" ]' ".new sobrou"
  afirma 'tem_chamada "mount -o rw,remount /vendor" && tem_chamada "mount -o ro,remount /vendor"' "o .rc foi gravado sem o remount rw/ro"
  afirma 'grep -q "servico de boot instalado em .*rotulo" "$T/kit.out"' "log sem o rotulo final"
  afirma '[ ! -e "$PED" ] && ! tem_chamada "chown media_rw" && [ ! -e "$R/data/media/0/pfl7560" ]' "o kit mexeu na pasta do app ou criou pasta de pedido compartilhada"
  afirma 'tem_chamada "setsid sh $S/suite.sh pendrive $MP"' "o autorun nao lancou a suite: $(grep setsid "$T/calls.log")"
  afirma '! grep -q "setsid sh .*cor.sh" "$T/calls.log"' "o autorun lancou o cor.sh direto"
  # o .rc tem exatamente o servico do spec
  afirma 'grep -qx "service pfl7560_suite /vendor/bin/sh /data/vendor/pfl7560-suite/suite-boot.sh" "$rc" && grep -qx "    seclabel u:r:vendor_shell:s0" "$rc" && grep -qx "on property:sys.boot_completed=1" "$rc" && grep -qx "    start pfl7560_suite" "$rc" && grep -qx "    oneshot" "$rc" && grep -qx "    disabled" "$rc" && grep -qx "    user root" "$rc" && grep -qx "    group root" "$rc"' "o .rc nao tem o servico do spec"

  # 2a execucao: nada regravado, nada remontado
  local m1 v1
  m1="$(stat -c %Y.%i "$rc")"
  v1="$(cd "$S" && find . -type f -name '*.sh' -exec stat -c '%n %Y %i' {} + | sort)"
  : "$m1" "$v1"   # usadas dentro das condicoes do afirma (eval)
  : > "$T/calls.log"
  sleep 1.1
  roda_kit
  afirma '[ "$(chamadas mount)" = 0 ] && [ "$(chamadas chcon)" = 0 ]' "2a execucao remontou /vendor ou refez o chcon"
  afirma '[ "$(stat -c %Y.%i "$rc")" = "$m1" ]' "2a execucao regravou o .rc"
  afirma '[ "$(cd "$S" && find . -type f -name "*.sh" -exec stat -c "%n %Y %i" {} + | sort)" = "$v1" ]' "2a execucao regravou scripts da suite"
  afirma 'grep -q "suite: arquivos ja estavam em dia" "$T/kit.out" && grep -q "servico de boot ja estava instalado" "$T/kit.out"' "log da 2a sem 'em dia'"

  # arquivo adulterado na pasta da suite: o kit refaz so ele
  echo "# x" >> "$S/nl_camcheck"; : > "$T/calls.log"
  roda_kit
  afirma 'cmp -s "$KIT/nl_camcheck" "$S/nl_camcheck"' "o nl_camcheck adulterado ficou"
  afirma 'grep -q "arquivos atualizados em .*: nl_camcheck$" "$T/kit.out"' "log: $(grep suite "$T/kit.out" | head -3)"
  limpa

  novo_cenario "instalacao: .rc que e LINK no lugar = substituido, alvo intacto"
  pendrive; rc="$R/vendor/etc/init/pfl7560-suite.rc"
  echo "alvo" > "$T/alvo.rc"; ln -s "$T/alvo.rc" "$rc"
  roda_kit
  afirma '[ ! -L "$rc" ] && cmp -s "$KIT/pfl7560-suite.rc" "$rc"' "o link ficou"
  afirma '[ "$(cat "$T/alvo.rc")" = alvo ]' "escreveu no alvo do link"
  limpa

  novo_cenario "instalacao: pasta da suite e LINK = recusa, nada no alvo, cor.sh sozinho"
  pendrive; mkdir -p "$T/alvo"; chmod 700 "$T/alvo"; ln -s "$T/alvo" "$S"
  roda_kit
  afirma '[ -z "$(ls -A "$T/alvo")" ]' "escreveu no alvo do link"
  afirma 'grep -q "suite NAO instalada" "$T/kit.out"' "log sem a recusa"
  afirma '[ ! -e "$R/vendor/etc/init/pfl7560-suite.rc" ]' "instalou o .rc sem a suite"
  afirma 'tem_chamada "setsid sh $W/cor.sh $MP"' "sem a suite, o cor.sh deveria rodar como antes: $(grep setsid "$T/calls.log")"
  limpa

  novo_cenario "instalacao: subpasta kit/ da suite e LINK = recusa, nada no alvo"
  pendrive; roda_kit
  mkdir -p "$T/alvo"; chmod 700 "$T/alvo"; rm -rf "$S/kit"; ln -s "$T/alvo" "$S/kit"; : > "$T/calls.log"
  roda_kit
  afirma '[ -z "$(ls -A "$T/alvo")" ] && grep -q "kit nao e uma pasta so do root" "$T/kit.out"' "usou a subpasta que e link"
  afirma 'tem_chamada "setsid sh $W/cor.sh $MP" && ! tem_chamada "suite.sh pendrive"' "deveria cair no cor.sh sozinho: $(grep setsid "$T/calls.log")"
  limpa

  novo_cenario "instalacao: pasta da suite de outro dono ou aberta = recusa e nao conserta"
  pendrive; mkdir -p "$S"; chmod 755 "$S"
  roda_kit
  afirma '[ -z "$(ls -A "$S")" ] && ls -ld "$S" | grep -q "^drwxr-xr-x"' "mexeu na pasta recusada"
  afirma 'tem_chamada "setsid sh $W/cor.sh $MP"' "sem a suite, o cor.sh deveria rodar"
  limpa

  novo_cenario "instalacao: arquivo da suite adulterado NO PENDRIVE = aborta antes de escrever"
  pendrive; echo "# x" >> "$MP/suite.sh"
  roda_kit
  afirma '[ "$RC" = 1 ] && [ ! -e "$S" ] && [ "$(chamadas setsid)" = 0 ] && [ "$(chamadas mount)" = 0 ]' "nao abortou limpo (rc=$RC)"
  afirma 'grep -q "suite.sh" "$T/kit.out" && grep -q "adulterado" "$T/kit.out"' "log nao aponta o suite.sh"
  limpa

  novo_cenario "instalacao: pasta do app e LINK = o kit nao toca nela, suite segue"
  pendrive; mkdir -p "$R/data/data" "$T/alvo"; ln -s "$T/alvo" "$PED"
  roda_kit
  afirma '[ -L "$PED" ] && [ -z "$(ls -A "$T/alvo")" ] && ! tem_chamada "chown media_rw"' "mexeu no link da pasta do app"
  afirma 'tem_chamada "setsid sh $S/suite.sh pendrive"' "a suite deveria seguir"
  limpa
}

c_desinstalar(){
  novo_cenario "desinstalar: DESINSTALAR-SUITE.txt remove servico, pasta, pedido e vigia; cor.sh roda sozinho"
  pendrive
  roda_kit
  afirma '[ -d "$S" ] && [ -f "$R/vendor/etc/init/pfl7560-suite.rc" ]' "preparo: a suite nao foi instalada"
  sh -c 'sleep 30; :' pfl7560-vigia-teste & local vp=$!
  echo "$vp" > "$R/dev/pfl7560-suite.vigia"
  mkdir -p "$R/sdcard/pfl7560-suite" "$PED"; : > "$PED/pedir-verificacao"; : > "$PED/do-app"
  printf '%s\n' "persist.sys.boot.reason=pfl7560,ligado" >> "$T/props"
  printf 'secure screensaver_components=com.pfl7560.verificar/.Descanso\nsecure screensaver_default_component=com.pfl7560.verificar/.Descanso\n' > "$T/settings.db"
  : > "$MP/DESINSTALAR-SUITE.txt"; : > "$T/calls.log"
  roda_kit
  wait "$vp" 2>/dev/null; local vrc=$?
  afirma '[ "$(grep "^secure screensaver_components=" "$T/settings.db" | cut -d= -f2)" = "com.newlink.screensaver/com.newlink.screensaver.ScreenService" ] && [ "$(grep "^secure screensaver_default_component=" "$T/settings.db" | cut -d= -f2)" = "com.newlink.screensaver/com.newlink.screensaver.ScreenService" ]' "o desinstalar nao devolveu o descanso do fabricante: $(tr '\n' '|' < "$T/settings.db")"
  afirma 'tem_chamada "setprop persist.sys.boot.reason "' "desinstalar deixou a marca pfl7560,ligado"
  afirma '[ ! -e "$R/vendor/etc/init/pfl7560-suite.rc" ]' "o .rc ficou"
  afirma '[ ! -e "$S" ] && [ ! -e "$PED/pedir-verificacao" ] && [ ! -e "$R/sdcard/pfl7560-suite" ]' "pasta da suite, o pedido ou a pasta das telas ficou"
  afirma '[ -f "$PED/do-app" ]' "desinstalar apagou arquivo do app (a pasta e dele)"
  afirma '[ "$vrc" = 143 ]' "o vigia nao foi encerrado com TERM (wait=$vrc)"
  afirma '[ ! -e "$R/dev/pfl7560-suite.vigia" ]' "pid do vigia ficou"
  afirma 'tem_chamada "setprop ctl.stop pfl7560_suite"' "nao parou o servico"
  afirma 'tem_chamada "mount -o rw,remount /vendor" && tem_chamada "mount -o ro,remount /vendor"' "removeu o .rc sem remount"
  afirma 'tem_chamada "setsid sh $W/cor.sh $MP" && ! tem_chamada "suite.sh pendrive"' "deveria rodar so o cor.sh: $(grep setsid "$T/calls.log")"
  afirma 'grep -q "suite removida" "$T/kit.out"' "log sem a remocao"
  # desinstalar de novo: nada a remover, nao falha
  : > "$T/calls.log"
  roda_kit
  afirma '[ "$RC" = 0 ] && [ "$(chamadas mount)" = 0 ]' "2o desinstalar remontou ou falhou (rc=$RC)"
  limpa
}

# desinstalar leva o bloco 14 de volta: desliga as sobreposicoes (a do android primeiro) e apaga as pastas,
# tira a prop do gerenciador, religa os apps e restaura a marca
c_desinstalar14(){
  local d
  novo_cenario "desinstalar: sobreposicoes desligadas (android primeiro) e removidas, prop do gerenciador tirada, apps religados, marca restaurada"
  pendrive; apps_cenario
  roda_kit
  afirma 'grep -qx "vendor.nl.filemanage_file=1" "$R/vendor/build.prop" && cmp -s "$KIT/marca/logo.jpg" "$R/atv/bootvideo/logo.jpg"' "preparo: o kit nao pos a prop ou a marca"
  afirma '[ -n "$(ls -d "$R"/vendor/overlay/PFL7560Tema* 2>/dev/null)" ]' "preparo: o kit nao instalou sobreposicoes"
  : > "$T/overlay.db"
  for d in "$R"/vendor/overlay/PFL7560Tema*; do echo "[x] com.pfl7560.tema.$(basename "$d" | sed 's/^PFL7560Tema//' | tr '[:upper:]' '[:lower:]')" >> "$T/overlay.db"; done
  echo "$APPS14" | tr ' ' '\n' > "$T/pm-desligados"
  : > "$MP/DESINSTALAR-SUITE.txt"; : > "$T/calls.log"
  roda_kit
  afirma '! grep -q "\[x\]" "$T/overlay.db" && [ "$(grep "^cmd overlay disable" "$T/calls.log" | head -1)" = "cmd overlay disable com.pfl7560.tema.android" ]' "disable: $(grep '^cmd overlay' "$T/calls.log" | sed 's/.*tema\.//' | tr '\n' ' ')"
  afirma '[ -z "$(ls -d "$R"/vendor/overlay/PFL7560Tema* 2>/dev/null)" ] && grep -q "sobreposicoes de tema removidas" "$T/kit.out"' "sobrou pasta de sobreposicao: $(find "$R/vendor/overlay" -maxdepth 1 | tr '\n' ' ')"
  afirma '! grep -q "^vendor.nl.filemanage_file=" "$R/vendor/build.prop" && grep -q "wifi_disconnect_on_boot=0" "$R/vendor/build.prop"' "a prop do gerenciador ficou ou o fix do wi-fi saiu"
  afirma '[ ! -s "$T/pm-desligados" ] && [ "$(grep -c "^pm enable --user 0 " "$T/calls.log")" = 3 ]' "apps nao religados: $(tr '\n' ' ' < "$T/pm-desligados")"
  afirma '[ "$(cat "$R/atv/bootvideo/logo.jpg")" = "logo de fabrica" ] && [ "$(cat "$R/atv/bootvideo/bootanimation.zip")" = "animacao de fabrica" ] && [ ! -e "$S" ]' "marca nao restaurada ou pasta da suite ficou"
  afirma 'grep -q "marca: logo.jpg de fabrica restaurado" "$T/kit.out"' "log sem a restauracao da marca"
  # desinstalar de novo: nada a remover, nao remonta, nao religa
  : > "$T/calls.log"
  roda_kit
  afirma '[ "$RC" = 0 ] && [ "$(chamadas mount)" = 0 ] && [ "$(chamadas "pm enable")" = 0 ]' "2o desinstalar mexeu de novo (rc=$RC)"
  limpa
}

# ---------------------------------------------------------------------------
# B3 - etapas (suite.sh chamado direto, pasta da suite pronta)
# ---------------------------------------------------------------------------
# cenario de etapas: tudo bem (cor certa pela camera, geometria boa, rampa reage)
etapa_feliz(){ instala_suite; MODO_AUTO_TESTE=1; echo 0 > "$T/cam-certo"; rampa_reage; }

c_etapas_cor(){
  local caso
  for caso in ordem corrigido manual_mantido manual_trocado erro; do
    novo_cenario "cor: resultado $caso"
    etapa_feliz
    case "$caso" in
      ordem) ;;
      corrigido) echo 1 > "$T/cam-certo"; echo nokey > "$T/keys" ;;
      manual_mantido) MODO_AUTO_TESTE=0; echo nokey > "$T/keys" ;;
      manual_trocado) MODO_AUTO_TESTE=0; printf 'key\nkey\n' > "$T/keys" ;;
      erro) sed -i "s/$PNOME/OUTRO_PAINEL/" "$R/proc/msp/panel" ;;
    esac
    roda_suite tomada relogio_zerado
    afirma '[ "$RC" = 0 ]' "suite saiu com $RC"
    afirma '[ "$(res cor_resultado)" = "$caso" ]' "cor_resultado='$(res cor_resultado)'"
    case "$caso" in
      ordem)
        afirma '[ "$(item_de "Formato do painel")" = "Formato do painel|VESA|ok" ]' "item: $(item_de "Formato do painel")"
        afirma '[ "$(pp_md5)" = "$(md5 "$T/pp-original.img")" ]' "mexeu na panelparam"
        afirma 'grep -qx "titulo=Tudo certo." "$(campos resumo resumo)" && ! grep -q "^destaque=" "$(campos resumo resumo)"' "titulo/destaque do tudo certo" ;;
      corrigido|manual_trocado)
        afirma '[ "$(item_de "Formato do painel")" = "Formato do painel|VESA \u2192 JEIDA|corrigido" ]' "item: $(item_de "Formato do painel")"
        afirma 'grep -qx "titulo=Tudo certo." "$(campos resumo resumo)" && grep -qxF "destaque=1 corre\u00e7\u00e3o feita." "$(campos resumo resumo)" && grep -qx "destaque_estado=corrigido" "$(campos resumo resumo)"' "titulo/destaque da correcao: $(grep -E '^(titulo|destaque)' "$(campos resumo resumo)" | tr '\n' '|')"
        # sem pendrive, a copia do backup fica na pasta da suite (persistente, so do root)
        afirma 'cmp -s "$S/panelparam-backup-SER123.img" "$T/pp-original.img"' "backup sem pendrive nao ficou na pasta da suite"
        afirma '[ ! -e "$W/journal" ] && [ ! -e "$R/data/local/nlsu/update_after_boot.sh" ]' "journal ou gancho sobraram" ;;
      manual_mantido)
        afirma '[ "$(item_de "Formato do painel")" = "Formato do painel|VESA|info" ]' "item: $(item_de "Formato do painel")"
        afirma '[ "$(pp_md5)" = "$(md5 "$T/pp-original.img")" ]' "mexeu na panelparam" ;;
      erro)
        afirma '[ "$(item_de "Formato do painel")" = "Formato do painel|erro|atencao" ]' "item: $(item_de "Formato do painel")"
        afirma 'grep -q "^titulo=Aten" "$(campos resumo resumo)" && grep -qx "destaque_estado=atencao" "$(campos resumo resumo)"' "titulo de atencao"
        afirma '[ "$(pp_md5)" = "$(md5 "$T/pp-original.img")" ]' "mexeu na panelparam" ;;
    esac
    # no modo suite o cor.sh nao mostra "aguarde" nem a tela final dele
    afirma '! grep -q "pfl7560-kit/aguarde.png\|pfl7560-kit/pronto.png\|pfl7560-kit/erro.png" "$T/calls.log"' "o cor.sh mostrou a tela dele no modo suite"
    afirma '[ "$caso" = erro ] || [ "$(res cor_formato_antes)" = VESA ]' "cor_formato_antes='$(res cor_formato_antes)'"
    limpa
  done

  novo_cenario "cor: cor.sh ADULTERADO na pasta da suite = nao executa"
  etapa_feliz
  printf 'touch "%s"\n' "$T/adulterado-rodou" >> "$S/cor.sh"
  roda_suite tomada
  afirma '[ ! -e "$T/adulterado-rodou" ]' "o cor.sh adulterado rodou"
  afirma '[ "$(res cor_resultado)" = erro ] && [ "$(chamadas lvdsctl)" = 0 ]' "seguiu com o cor.sh adulterado"
  afirma 'grep -q "cor.sh da pasta da suite nao confere" "$S/ultimo.log"' "log sem a recusa"
  afirma '[ "$(res itens)" = 19 ]' "a suite deveria seguir com as outras etapas"
  limpa

  novo_cenario "cor: pasta de trabalho do cor.sh e LINK = nao usa"
  etapa_feliz
  mkdir -p "$T/alvo"; chmod 700 "$T/alvo"; ln -s "$T/alvo" "$W"
  roda_suite tomada
  afirma '[ -z "$(ls -A "$T/alvo")" ] && [ "$(res cor_resultado)" = erro ]' "usou a pasta de trabalho que e link"
  limpa
}

c_etapas_geometria(){
  novo_cenario "geometria boa: tudo ok, sem autofoco"
  etapa_feliz
  roda_suite tomada
  afirma '[ "$(item_de "\u00c2ngulo")" = "\u00c2ngulo|0,4\u00b0|ok" ]' "angulo: $(item_de "\u00c2ngulo")"
  afirma '[ "$(item_de Foco)" = "Foco|bom|ok" ] && [ "$(item_de Nitidez)" = "Nitidez|1,8 \u00b7 canto 2,1 px|ok" ]' "foco/nitidez: $(item_de Foco) $(item_de Nitidez)"
  afirma '[ "$(res nitidez_r2c2)" = 1.80 ] && [ "$(res nitidez_pior_canto_px)" = 2.10 ] && [ "$(res nitidez_causa)" = nenhuma ]' "nitidez: $(res nitidez_r2c2) $(res nitidez_pior_canto_px) $(res nitidez_causa)"
  afirma '[ "$(chamadas "nl_camcheck nitidez")" -ge 1 ] && [ "$(res foco_varredura)" = nao_precisou ]' "mapa/varredura: $(chamadas "nl_camcheck nitidez") $(res foco_varredura)"
  afirma '! grep -q "^HIDEBUG.* \(gfd\|gfdr\|sfd\) " "$T/calls.log"' "mexeu no motor de foco com o foco bom"
  afirma '[ "$(item_de "4 pontos")" = "4 pontos|zerada|ok" ]' "4 pontos: $(item_de "4 pontos")"
  afirma '[ "$(item_de "C\u00e2mera")" = "C\u00e2mera|funcionando|ok" ]' "camera: $(item_de "C\u00e2mera")"
  afirma '[ "$(item_de Painel)" = "Painel|RX058B_4300|info" ] && [ "$(res cor_painel)" = "$PNOME" ]' "painel: $(item_de Painel) / $(res cor_painel)"
  afirma '! tem_chamada "am startservice"' "disparou autofoco sem precisar"
  afirma '[ "$(res geo_limiar_borda_px)" = 3.50 ] && [ "$(res foco_tentativas)" = 0 ]' "limiar/tentativas: $(res geo_limiar_borda_px) $(res foco_tentativas)"
  limpa

  novo_cenario "geometria: inclinada com 4 pontos zerados = dica de nivelar"
  etapa_feliz; geo -2.50 1.0 1.80 2.0 1.9 0.93 > "$T/geo"
  roda_suite tomada
  afirma '[ "$(item_de "\u00c2ngulo")" = "\u00c2ngulo|2,5\u00b0|atencao" ]' "angulo: $(item_de "\u00c2ngulo")"
  afirma 'grep -qxF "dica=Imagem inclinada 2,5\u00b0: abaixe o lado esquerdo do projetor." "$(campos resumo resumo)"' "dica: $(grep ^dica "$(campos resumo resumo)")"
  limpa

  novo_cenario "geometria: inclinada para o outro lado = o outro pe"
  etapa_feliz; geo 2.10 1.0 1.80 2.0 1.9 0.93 > "$T/geo"
  roda_suite tomada
  afirma 'grep -qF "abaixe o lado direito" "$(campos resumo resumo)"' "dica: $(grep ^dica "$(campos resumo resumo)")"
  limpa

  novo_cenario "geometria: 4 pontos ligados + trapezio = conselho de zerar (e nao de nivelar)"
  etapa_feliz; geo 2.82 12.5 1.77 2.24 1.95 0.93 > "$T/geo"
  sed -i 's/^persist.sys.keystone.lt=.*/persist.sys.keystone.lt=85,895/' "$T/props"
  roda_suite tomada
  afirma '[ "$(res quatro_pontos)" = ligada ] && [ "$(item_de "4 pontos")" = "4 pontos|ligada|atencao" ]' "4 pontos: $(res quatro_pontos) $(item_de "4 pontos")"
  afirma 'grep -qF "zere os 4 pontos" "$(campos resumo resumo)"' "sem o conselho dos 4 pontos"
  afirma '! grep -qF "abaixe o lado" "$(campos resumo resumo)"' "deu dica de nivelar com os 4 pontos ligados"
  afirma '! grep -q "^setprop persist.sys.keystone" "$T/calls.log"' "escreveu nas props dos 4 pontos"
  limpa

  novo_cenario "geometria: foco ruim que melhora no 2o autofoco"
  etapa_feliz
  geo 0.4 1.0 1.80 4.20 1.9 0.93 > "$T/geo-1"; geo 0.4 1.0 1.80 3.90 1.9 0.93 > "$T/geo-2"
  roda_suite tomada
  afirma '[ "$(grep -c "^am startservice -n com.zhiying.autofocus/.AutoFocusService -a com.zhiying.AUTO_FOCUS_SERVICE --ei auto_focus_keystone 0$" "$T/calls.log")" = 2 ]' "esperava 2 autofocos (so foco): $(grep startservice "$T/calls.log" | tr '\n' '|')"
  afirma '[ "$(res foco_tentativas)" = 2 ] && [ "$(item_de Foco)" = "Foco|refeito (2x)|corrigido" ]' "foco: $(res foco_tentativas) $(item_de Foco)"
  afirma '[ "$(grep -c "^nl_camcheck geometria" "$T/calls.log")" = 3 ]' "esperava 3 medicoes"
  # 1 da leitura antes do cor.sh + 3 medicoes da geometria
  afirma '[ "$(grep -c "^am start.*pfl7560-suite/calibracao.png" "$T/calls.log")" = 4 ]' "a calibracao deveria voltar a cada medicao"
  limpa

  novo_cenario "geometria: foco ruim que nao melhora = 2 autofocos e atencao"
  etapa_feliz; geo 0.4 1.0 1.80 4.20 1.9 0.93 > "$T/geo"
  roda_suite tomada
  afirma '[ "$(chamadas "am startservice")" = 2 ] && [ "$(item_de Foco)" = "Foco|irregular|atencao" ]' "foco: $(item_de Foco)"
  limpa

  novo_cenario "geometria: autofoco ja em curso = nao dispara outro, so espera"
  etapa_feliz; geo 0.4 1.0 1.80 4.20 1.9 0.93 > "$T/geo-1"
  sed -i 's/^sys.newlink.auto=.*/sys.newlink.auto=1/' "$T/props"
  roda_suite tomada
  afirma '! tem_chamada "am startservice"' "disparou com o autofoco em curso"
  afirma 'grep -q "autofoco ja em curso" "$S/ultimo.log"' "log sem o aviso"
  limpa

  local rc
  for rc in 1 3; do
    novo_cenario "geometria: camera falhou (rc=$rc) = itens pendentes e a suite segue"
    etapa_feliz; echo "$rc" > "$T/geo-rc"
    roda_suite tomada
    afirma '[ "$(item_de "\u00c2ngulo")" = "\u00c2ngulo|[sem leitura]|pendente" ] && [ "$(item_de Foco)" = "Foco|[sem leitura]|pendente" ] && [ "$(item_de Nitidez)" = "Nitidez|[sem leitura]|pendente" ]' "itens: $(item_de Foco)"
    afirma '[ "$(res camera)" = falhou ] && [ "$(res rampa)" = reagiu ] && [ "$(res itens)" = 19 ]' "a suite nao seguiu: camera=$(res camera) rampa=$(res rampa)"
    limpa
  done

  novo_cenario "camera: alerta do sistema na tela = fechado com ENTER antes de mostrar"
  etapa_feliz; echo 1 > "$T/alerta"
  roda_suite tomada
  afirma 'tem_chamada "input keyevent KEYCODE_DPAD_CENTER" && grep -q "alerta do sistema (com.newlink.nlprovision)" "$S/ultimo.log"' "o alerta nao foi fechado com o OK do controle"
  afirma '[ "$(res camera)" = ok ]' "camera: $(res camera)"
  limpa

  novo_cenario "camera: outro alerta do sistema (HDMI) = cancelado com BACK, nunca ENTER"
  etapa_feliz; echo 1 > "$T/alerta"; echo "com.zhiying.settings" > "$T/alerta-pacote"
  roda_suite tomada
  afirma 'tem_chamada "input keyevent KEYCODE_BACK" && ! tem_chamada "input keyevent KEYCODE_ENTER" && ! tem_chamada "input keyevent KEYCODE_DPAD_CENTER"' "teclas: $(grep "^input" "$T/calls.log" | tr '\n' '|')"
  limpa

  novo_cenario "camera: falha 2x e le na 3a = sem chamar a pessoa, autofoco entre as tentativas"
  etapa_feliz; echo 2 > "$T/cam-faixas-falhas"
  roda_suite tomada
  afirma '! grep -q "camera sem leitura" "$S/ultimo.log" && grep -q "tentativa 3" "$S/ultimo.log"' "log: $(grep -a camera "$S/ultimo.log" | tr '\n' '|')"
  afirma '[ "$(grep -c "disparando o autofoco" "$S/ultimo.log")" -ge 2 ]' "o autofoco nao foi refeito entre as tentativas"
  afirma '[ "$(res cor_resultado)" = ordem ]' "cor: $(res cor_resultado)"
  limpa

  novo_cenario "camera: falha 3x antes do cor.sh = tela da camera e espera de tecla SEM prazo; depois o cor.sh"
  etapa_feliz; echo 3 > "$T/cam-faixas-falhas"
  roda_suite tomada
  afirma 'grep -q "camera sem leitura: esperando uma tecla do controle, sem prazo" "$S/ultimo.log"' "nao chamou a pessoa"
  afirma '[ -n "$(campos aviso camera)" ] && grep -q "^tom=alerta" "$(campos aviso camera)" && ! grep -qi pendrive "$(campos aviso camera)"' "tela da camera: $(tr '\n' '|' < "$(campos aviso camera)" 2>/dev/null)"
  afirma '! grep -q "^campo rodape\|^rodape=" "$(campos aviso camera)"' "tela da camera com rodape"
  afirma 'grep -q "^tela: camera" "$S/ultimo.log" || grep -q "tela: camera-" "$S/ultimo.log"' "a tela da camera nao foi mostrada"
  afirma 'grep -q "cor: rodando cor.sh no modo suite" "$S/ultimo.log"' "a cor nao seguiu depois da tecla"
  limpa

  novo_cenario "geometria: sem /dev/video0 = camera ausente, sem nl_camcheck"
  etapa_feliz; MODO_AUTO_TESTE=0; echo nokey > "$T/keys"; rm -f "$R/dev/video0"
  roda_suite tomada
  afirma '[ "$(chamadas nl_camcheck)" = 0 ] && [ "$(item_de "C\u00e2mera")" = "C\u00e2mera|ausente|pendente" ]' "camera: $(item_de "C\u00e2mera")"
  limpa

  novo_cenario "geometria: nl_camcheck adulterado = nao executa"
  etapa_feliz; MODO_AUTO_TESTE=0; echo nokey > "$T/keys"
  # o md5 que a suite espera e o do binario original; o do PATH muda depois
  cp "$T/bin/nl_camcheck" "$T/nlcam.orig"; echo "# x" >> "$T/bin/nl_camcheck"
  env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_RAPIDO=1 PFL_ROOT="$R" PFL_LVDSCTL="$T/bin/lvdsctl" PFL_LVDSCTL_MD5="$(md5 "$T/bin/lvdsctl")" \
      PFL_NLCAMCHECK="$T/bin/nl_camcheck" PFL_NLCAMCHECK_MD5="$(md5 "$T/nlcam.orig")" PFL_NLTELA="$T/bin/nl_tela" PFL_NLTELA_MD5="$(md5 "$T/bin/nl_tela")" \
      PFL_MODO_AUTO=0 PATH="$T/bin:$PATH" dash "$S/suite.sh" tomada > "$T/out.log" 2>&1
  afirma '[ "$(chamadas nl_camcheck)" = 0 ] && [ "$(res camera)" = falhou ]' "executou o nl_camcheck adulterado"
  limpa

  novo_cenario "geometria: modo de projecao e resolucao"
  etapa_feliz
  sed -i 's/^persist.sys.mountingmode=.*/persist.sys.mountingmode=3/' "$T/props"
  roda_suite tomada
  afirma '[ "$(item_de "Modo de proje\u00e7\u00e3o")" = "Modo de proje\u00e7\u00e3o|girada 180\u00b0 (3)|info" ]' "modo: $(item_de "Modo de proje\u00e7\u00e3o")"
  afirma '[ "$(item_de "Resolu\u00e7\u00e3o")" = "Resolu\u00e7\u00e3o|1920x1080|info" ]' "resolucao: $(item_de "Resolu\u00e7\u00e3o")"
  afirma '! grep -q "^setprop persist.sys.mountingmode\|ProjectionService" "$T/calls.log"' "mexeu no modo de projecao"
  limpa
}

# bloco 11: mapa de nitidez 3x3 e varredura fina de foco pelo hidebug
nit(){ printf 'nitidez_r1c1=%s\nnitidez_r1c2=%s\nnitidez_r1c3=%s\nnitidez_r2c1=%s\nnitidez_r2c2=%s\nnitidez_r2c3=%s\nnitidez_r3c1=%s\nnitidez_r3c2=%s\nnitidez_r3c3=%s\nquadro=1280x720\n' "$@"; }
sfds(){ grep "^HIDEBUG  custom sfd " "$T/calls.log" | sed 's/^HIDEBUG  custom sfd \([0-9]*\) quit $/\1/' | tr '\n' ' '; }
dicas_de(){ grep "^dica=" "$(campos resumo resumo)" 2>/dev/null; }
c_etapas_foco(){
  novo_cenario "nitidez: cantos da esquerda com 4 pontos ligados = zere e alinhe (uma dica so)"
  etapa_feliz; geo 2.82 12.5 1.90 2.24 1.95 0.93 > "$T/geo"
  sed -i 's/^persist.sys.keystone.lt=.*/persist.sys.keystone.lt=95,915/' "$T/props"
  nit 3.10 1.95 2.00 2.30 1.90 1.95 2.95 1.90 2.05 > "$T/nit"
  roda_suite tomada
  afirma '[ "$(item_de Nitidez)" = "Nitidez|1,9 \u00b7 canto 3,1 px|atencao" ]' "nitidez: $(item_de Nitidez)"
  afirma '[ "$(res nitidez_causa)" = lado_esquerdo ] && [ "$(res nitidez_r1c1)" = 3.10 ] && [ "$(res nitidez_r3c3)" = 2.05 ]' "res: $(res nitidez_causa) $(res nitidez_r1c1) $(res nitidez_r3c3)"
  afirma 'dicas_de | grep -qxF "dica=Cantos do lado esquerdo borrados (3,1 px; centro 1,9 px): zere os 4 pontos e alinhe o projetor de frente."' "dica: $(dicas_de)"
  afirma '[ "$(dicas_de | grep -c "zere os 4 pontos")" = 1 ]' "dica dos 4 pontos repetida: $(dicas_de)"
  afirma '[ "$(item_de "4 pontos")" = "4 pontos|ligada|atencao" ] && ! grep -q "^setprop persist.sys.keystone" "$T/calls.log"' "4 pontos: $(item_de "4 pontos")"
  limpa

  novo_cenario "nitidez: cantos da direita com 4 pontos zerados = alinhar de frente"
  etapa_feliz; nit 1.95 1.85 3.40 1.95 1.80 2.60 2.00 1.85 3.20 > "$T/nit"
  roda_suite tomada
  afirma '[ "$(res nitidez_causa)" = lado_direito ] && [ "$(item_de Nitidez)" = "Nitidez|1,8 \u00b7 canto 3,4 px|atencao" ]' "nitidez: $(res nitidez_causa) $(item_de Nitidez)"
  afirma 'dicas_de | grep -qxF "dica=Cantos do lado direito borrados (3,4 px; centro 1,8 px): alinhe o projetor de frente para a parede."' "dica: $(dicas_de)"
  afirma '! dicas_de | grep -q "4 pontos"' "falou dos 4 pontos com eles zerados"
  limpa

  novo_cenario "nitidez: cantos dos dois lados um pouco piores = sem dica, ok abaixo do limiar"
  etapa_feliz; nit 3.00 1.85 3.10 2.10 1.80 2.10 3.05 1.85 3.00 > "$T/nit"
  roda_suite tomada
  afirma '[ "$(res nitidez_causa)" = cantos ] && [ "$(item_de Nitidez)" = "Nitidez|1,8 \u00b7 canto 3,1 px|ok" ] && [ -z "$(dicas_de)" ]' "nitidez: $(res nitidez_causa) $(item_de Nitidez) $(dicas_de)"
  limpa

  novo_cenario "nitidez: borda de 2 digitos = valor sem px (cabe na coluna)"
  etapa_feliz; nit 12.34 1.85 1.95 1.95 1.80 1.90 2.10 1.85 2.00 > "$T/nit"
  roda_suite tomada
  afirma '[ "$(item_de Nitidez)" = "Nitidez|1,8 \u00b7 canto 12,3|atencao" ]' "nitidez: $(item_de Nitidez)"
  limpa

  local rc
  for rc in 1 3; do
    novo_cenario "nitidez: nl_camcheck nitidez falhou (rc=$rc) = item pela geometria, suite segue"
    etapa_feliz; echo "$rc" > "$T/nit-rc"
    roda_suite tomada
    afirma '[ "$(item_de Nitidez)" = "Nitidez|boa (1,8 px)|ok" ] && [ "$(res camera)" = ok ] && [ -z "$(res nitidez_causa)" ]' "nitidez: $(item_de Nitidez) camera=$(res camera)"
    limpa
  done

  novo_cenario "foco: centro borrado sem motor no hidebug = 2 autofocos, nada mexido, dica de foco refeito"
  etapa_feliz; geo 0.4 1.0 3.90 4.10 4.00 0.93 > "$T/geo"
  nit 4.10 3.95 4.00 4.00 3.90 4.05 4.20 3.95 4.10 > "$T/nit"
  roda_suite tomada
  afirma '[ "$(chamadas "am startservice")" = 2 ] && [ "$(res foco_varredura)" = sem_hidebug ] && [ -z "$(sfds)" ]' "varredura: $(res foco_varredura) sfd=$(sfds)"
  afirma '[ "$(grep -c "^HIDEBUG  custom gfd quit $" "$T/calls.log")" -ge 1 ]' "nem perguntou a posicao do foco"
  afirma '[ "$(res nitidez_causa)" = centro ] && dicas_de | grep -qxF "dica=Centro borrado (3,9 px): foco refeito. Se continuar, limpe a lente e confira a dist\u00e2ncia at\u00e9 a parede."' "dica: $(dicas_de)"
  afirma '! dicas_de | grep -q "Foco irregular"' "dica generica junto com a da causa: $(dicas_de)"
  afirma '[ "$(item_de Foco)" = "Foco|irregular|atencao" ]' "foco: $(item_de Foco)"
  limpa

  novo_cenario "nitidez: centro borrado so no mapa (geometria boa) = refaca o foco pela tecla"
  etapa_feliz; nit 4.10 3.95 4.00 4.00 3.90 4.05 4.20 3.95 4.10 > "$T/nit"
  roda_suite tomada
  afirma 'dicas_de | grep -qxF "dica=Centro borrado (3,9 px): refa\u00e7a o foco pela tecla do controle."' "dica: $(dicas_de)"
  limpa

  novo_cenario "foco: varredura acha a posicao melhor = fica nela, ajuste fino"
  etapa_feliz; echo 1000 > "$T/foco-pos"; echo 1080 > "$T/foco-otimo"
  roda_suite tomada
  afirma '[ "$(sfds)" = "880 920 960 1000 1040 1080 1120 1040 1080 " ]' "posicoes: $(sfds)"
  afirma '[ "$(cat "$T/foco-pos")" = 1080 ] && [ "$(res foco_varredura)" = melhorou ] && [ "$(res foco_pos_inicial)" = 1000 ] && [ "$(res foco_pos_final)" = 1080 ]' "fim: pos=$(cat "$T/foco-pos") $(res foco_varredura) $(res foco_pos_inicial) $(res foco_pos_final)"
  afirma '[ "$(res foco_borda_antes)" = 3.80 ] && [ "$(res foco_borda_depois)" = 1.80 ] && [ "$(res geo_borda_centro_px)" = 1.80 ]' "bordas: $(res foco_borda_antes) $(res foco_borda_depois) $(res geo_borda_centro_px)"
  afirma '[ "$(item_de Foco)" = "Foco|ajuste fino|corrigido" ]' "foco: $(item_de Foco)"
  afirma '[ "$(chamadas "am startservice")" = 2 ]' "a varredura deveria vir depois dos 2 autofocos"
  # cada movimento espera VARRE_PAUSA antes de ler o gfd: sfd, sleep 2, gfd
  afirma '[ -z "$(awk "/^HIDEBUG  custom sfd /{s=1; next} s==1 && /^HIDEBUG/{print; s=0; next} s==1 && /^sleep 2\$/{s=0}" "$T/calls.log")" ]' "leu o gfd sem a pausa depois do sfd"
  afirma '[ -z "$(grep "^HIDEBUG" "$T/calls.log" | grep -vE "^HIDEBUG  custom (gfs 0 gfs 1 gbri 0|gfd|gfdr|sfd [0-9]+) quit $")" ]' "outro comando no hidebug: $(grep "^HIDEBUG" "$T/calls.log" | grep -vE "custom (gfs 0 gfs 1 gbri 0|gfd|gfdr|sfd [0-9]+) quit" | head -2)"
  limpa

  novo_cenario "foco: varredura sem ganho (o borrao e do lado) = volta a posicao inicial por baixo"
  etapa_feliz; echo 1000 > "$T/foco-pos"; echo 1000 > "$T/foco-otimo"; echo 2.0 > "$T/foco-lado"
  roda_suite tomada
  afirma '[ "$(sfds)" = "880 920 960 1000 1040 1080 1120 960 1000 " ]' "posicoes: $(sfds)"
  afirma '[ "$(cat "$T/foco-pos")" = 1000 ] && [ "$(res foco_varredura)" = sem_ganho ] && [ "$(res foco_pos_final)" = 1000 ]' "fim: pos=$(cat "$T/foco-pos") $(res foco_varredura) $(res foco_pos_final)"
  afirma '[ "$(item_de Foco)" = "Foco|irregular|atencao" ] && grep -q "nada melhorou (sem_ganho): o foco voltou a 1000" "$S/ultimo.log"' "foco: $(item_de Foco)"
  limpa

  novo_cenario "foco: motor recusa andar (Motor is too hot) = para no 1o passo e devolve"
  etapa_feliz; echo 1000 > "$T/foco-pos"; echo 1080 > "$T/foco-otimo"; : > "$T/foco-trava"
  roda_suite tomada
  afirma '[ "$(sfds)" = "880 960 1000 " ] && [ "$(res foco_varredura)" = falhou ] && [ "$(res foco_pos_final)" = 1000 ]' "posicoes: $(sfds) $(res foco_varredura) $(res foco_pos_final)"
  afirma '[ "$(chamadas "nl_camcheck geometria")" = 3 ]' "mediu com o motor parado: $(chamadas "nl_camcheck geometria") geometrias"
  limpa

  novo_cenario "foco: hidebug para de responder no meio = manda voltar a posicao inicial e avisa"
  etapa_feliz; echo 1000 > "$T/foco-pos"; echo 1080 > "$T/foco-otimo"; echo 4 > "$T/foco-mudo-apos"
  roda_suite tomada
  afirma '[ "$(sfds | awk "{print \$NF}")" = 1000 ] && [ "$(cat "$T/foco-pos")" = 1000 ]' "nao mandou voltar: $(sfds) pos=$(cat "$T/foco-pos")"
  afirma '[ "$(res foco_varredura)" = nao_voltou ] && grep -q "NAO confirmei a volta do foco a 1000" "$S/ultimo.log"' "varredura: $(res foco_varredura)"
  limpa

  novo_cenario "foco: autofoco ainda em curso = a varredura nao mexe no motor"
  etapa_feliz; echo 1000 > "$T/foco-pos"; echo 1080 > "$T/foco-otimo"
  sed -i 's/^sys.newlink.auto=.*/sys.newlink.auto=1/' "$T/props"
  roda_suite tomada
  afirma '[ -z "$(sfds)" ] && [ "$(res foco_varredura)" = pulada ]' "mexeu: $(sfds) $(res foco_varredura)"
  limpa

  novo_cenario "foco: suite morta no meio da varredura = o trap devolve o motor"
  etapa_feliz; echo 1000 > "$T/foco-pos"; echo 1080 > "$T/foco-otimo"; echo 2 > "$T/mata-no-sleep"
  roda_suite tomada
  afirma '[ "$(cat "$T/foco-pos")" = 1000 ] && [ "$(res foco_varredura)" = interrompida ] && grep -q "saindo no meio da varredura de foco: devolvendo o motor a 1000" "$S/ultimo.log"' "pos=$(cat "$T/foco-pos") $(res foco_varredura) sfd=$(sfds)"
  limpa
}

c_etapas_temperatura(){
  novo_cenario "temperatura normal: leitura sem gtt"
  etapa_feliz
  roda_suite tomada
  afirma '[ "$(item_de LED)" = "LED|54,7 \u00b0C|ok" ] && [ "$(item_de Placa)" = "Placa|30,1 \u00b0C|ok" ]' "temperaturas: $(item_de LED) $(item_de Placa)"
  afirma '[ "$(item_de Ventoinha)" = "Ventoinha|3000 / 2950|ok" ] && [ "$(item_de Brilho)" = "Brilho|1000|info" ]' "ventoinha/brilho: $(item_de Ventoinha) $(item_de Brilho)"
  afirma '[ "$(item_de "Corre\u00e7\u00e3o t\u00e9rmica")" = "Corre\u00e7\u00e3o t\u00e9rmica|ativa|ok" ]' "termica: $(item_de "Corre\u00e7\u00e3o t\u00e9rmica")"
  afirma 'grep -q "^HIDEBUG  custom gfs 0 gfs 1 gbri 0 quit $" "$T/calls.log"' "o hidebug nao recebeu exatamente gfs/gbri: $(grep HIDEBUG "$T/calls.log")"
  afirma '[ "$(res escada)" = presente ] && [ "$(res ini_md5)" = 252ab7a72a007a8b79b3fc86bd5c0d19 ]' "escada/md5: $(res escada) $(res ini_md5)"
  afirma '[ -n "$(campos aviso etapa3)" ] && grep -qF "etapa=Etapa 3 de 4 \u00b7 temperatura" "$(campos aviso etapa3)"' "tela da etapa 3"
  limpa

  novo_cenario "temperatura: LED quente = atencao, dica de ventilacao, rampa nao injeta"
  etapa_feliz
  sed -i "s/^zysys.env_temp=.*/zysys.env_temp=68.2/" "$T/props"
  roda_suite tomada
  afirma '[ "$(item_de LED)" = "LED|68,2 \u00b0C|atencao" ]' "LED: $(item_de LED)"
  afirma 'grep -qF "dica=LED quente (68,2 \u00b0C)" "$(campos resumo resumo)"' "sem a dica de ventilacao"
  afirma '[ "$(res rampa)" = pulada ] && ! tem_chamada "setprop $PROP_OV 71000"' "injetou com o LED quente"
  limpa

  novo_cenario "temperatura: ventoinha parada = atencao"
  etapa_feliz; printf 'fan speed : 0\nfan speed : 2950\nbacklight brightness : 850\n' > "$T/hidebug-saida"
  roda_suite tomada
  afirma '[ "$(item_de Ventoinha)" = "Ventoinha|0 / 2950 parada|atencao" ]' "ventoinha: $(item_de Ventoinha)"
  limpa

  novo_cenario "temperatura: ZYCustom em /atv/ini anula a correcao = atencao, rampa nao injeta"
  etapa_feliz; mkdir -p "$R/atv/ini"; cp "$ROOT/artifacts/ZYCustom.ini.ORIGINAL" "$R/atv/ini/ZYCustom.ini"
  roda_suite tomada
  afirma '[ "$(item_de "Corre\u00e7\u00e3o t\u00e9rmica")" = "Corre\u00e7\u00e3o t\u00e9rmica|anulada em /atv|atencao" ]' "termica: $(item_de "Corre\u00e7\u00e3o t\u00e9rmica")"
  afirma '[ "$(res rampa)" = pulada ] && ! tem_chamada "setprop $PROP_OV 71000"' "injetou com o .ini de fabrica efetivo (EMERGENCY=$(res rampa_emergency))"
  limpa

  novo_cenario "temperatura: props ilegiveis = pendentes, rampa nao injeta"
  etapa_feliz; sed -i '/^zysys/d' "$T/props"; : > "$T/hidebug-saida"
  roda_suite tomada
  afirma '[ "$(item_de LED)" = "LED|[a ler]|pendente" ] && [ "$(item_de Ventoinha)" = "Ventoinha|[a ler]|pendente" ]' "itens: $(item_de LED) $(item_de Ventoinha)"
  afirma '[ "$(res rampa)" = pulada ]' "rampa=$(res rampa)"
  limpa
}

c_etapas_rampa(){
  novo_cenario "rampa: o firmware reage = ok, override limpo e conferido"
  etapa_feliz
  roda_suite tomada
  afirma '[ "$(res rampa)" = reagiu ] && [ "$(item_de "Rampa t\u00e9rmica")" = "Rampa t\u00e9rmica|reagiu e voltou|ok" ]' "rampa: $(res rampa) $(item_de "Rampa t\u00e9rmica")"
  afirma 'grep -n "^setprop $PROP_OV" "$T/calls.log" | tr "\n" "|" | grep -q "^[0-9]*:setprop $PROP_OV 71000|[0-9]*:setprop $PROP_OV |$"' "setprop: $(grep "^setprop $PROP_OV" "$T/calls.log" | tr '\n' '|')"
  afirma '[ -z "$(awk -F= -v k="$PROP_OV" "\$1==k{print \$2}" "$T/props")" ]' "override ficou"
  afirma 'tem_chamada "logcat -v time -T 1 -s ZYThermalManager"' "logcat sem o filtro"
  afirma '[ -n "$(campos aviso etapa4)" ] && grep -qx "tom=alerta" "$(campos aviso etapa4)" && grep -qF "escurecer" "$(campos aviso etapa4)"' "tela da etapa 4"
  afirma 'tem_chamada "sleep 40"' "o override nao ficou os 40 s"
  limpa

  novo_cenario "rampa: o firmware nao reage (so os X => X do regime) = atencao"
  etapa_feliz
  printf '%s\n' "I/ZYThermalManager: Level Change 1000 => 1000!" "I/ZYThermalManager: Level Change 850 => 850!" > "$T/logcat-saida"
  roda_suite tomada
  afirma '[ "$(res rampa)" = nao_reagiu ] && [ "$(item_de "Rampa t\u00e9rmica")" = "Rampa t\u00e9rmica|n\u00e3o reagiu|atencao" ]' "rampa: $(res rampa)"
  afirma 'grep -qF "dica=A prote\u00e7\u00e3o t\u00e9rmica n\u00e3o reagiu" "$(campos resumo resumo)"' "sem a dica"
  afirma '[ -z "$(awk -F= -v k="$PROP_OV" "\$1==k{print \$2}" "$T/props")" ]' "override ficou"
  limpa

  novo_cenario "rampa: morte no meio (TERM durante a injecao) = o trap limpa o override"
  etapa_feliz; echo 40 > "$T/mata-no-sleep"
  roda_suite tomada
  afirma '[ "$RC" = 130 ]' "deveria sair com 130 (saiu com $RC)"
  afirma 'tem_chamada "setprop $PROP_OV 71000" && [ "$(grep -n "^setprop $PROP_OV" "$T/calls.log" | tail -1 | cut -d" " -f3-)" = "" ]' "a ultima escrita do override nao foi a limpeza: $(grep "^setprop $PROP_OV" "$T/calls.log" | tr '\n' '|')"
  afirma '[ -z "$(awk -F= -v k="$PROP_OV" "\$1==k{print \$2}" "$T/props")" ]' "override ficou depois da morte"
  afirma '[ "$(res rampa_limpeza_saida)" = ok ] && [ -n "$(res fim)" ]' "resultados sem a limpeza na saida"
  afirma '[ ! -d "$R/dev/pfl7560-suite.lock" ] && [ -s "$S/ultimo-fim" ]' "trava ficou ou sem ultimo-fim"
  limpa

  local sinal
  for sinal in INT HUP; do
    novo_cenario "rampa: sinal $sinal durante a injecao = o trap limpa"
    etapa_feliz
    stub sleep 'echo "sleep $*" >> "$T/calls.log"; [ "$1" = 40 ] && kill -'"$sinal"' "$PPID"; exit 0'
    roda_suite tomada
    afirma '[ -z "$(awk -F= -v k="$PROP_OV" "\$1==k{print \$2}" "$T/props")" ] && tem_chamada "setprop $PROP_OV 71000"' "override ficou ($sinal)"
    limpa
  done

  novo_cenario "rampa: a limpeza nao confirma = 3 tentativas, atencao e dica de reiniciar"
  etapa_feliz; : > "$T/setprop-nao-limpa"
  roda_suite tomada
  afirma '[ "$(res rampa)" = limpeza_falhou ] && [ "$(res rampa_limpeza)" = falhou ]' "rampa: $(res rampa)"
  afirma '[ "$(grep -c "^setprop $PROP_OV $" "$T/calls.log")" -ge 3 ]' "menos de 3 tentativas de limpeza"
  afirma 'grep -qF "dica=Reinicie o projetor agora" "$(campos resumo resumo)"' "sem a dica de reiniciar"
  limpa

  novo_cenario "rampa: .ini corrigido mas WARNING/EMERGENCY ilegiveis = nao injeta"
  etapa_feliz
  # um .ini sem as linhas de limiar, com o md5 de um corrigido? impossivel; a trava do
  # md5 vem antes. Aqui o EMERGENCY some do .ini efetivo em /atv/ini (md5 diferente)
  mkdir -p "$R/atv/ini"; grep -av EMERGENCY_VALUE "$KIT/ZYCustom.ini" > "$R/atv/ini/ZYCustom_390.ini"
  roda_suite tomada
  afirma '[ "$(res rampa)" = pulada ] && ! tem_chamada "setprop $PROP_OV 71000"' "injetou sem EMERGENCY"
  afirma '[ "$(res ini_efetivo)" = /atv/ini/ZYCustom_390.ini ]' "ini efetivo errado: $(res ini_efetivo)"
  limpa
}

# ---------------------------------------------------------------------------
# telas, resumo e modos
# ---------------------------------------------------------------------------
c_telas(){
  local modo
  for modo in tomada pedido; do
    novo_cenario "telas do modo $modo: nenhuma cita pendrive; resumo com os 19 itens"
    etapa_feliz
    if [ "$modo" = tomada ]; then roda_suite tomada relogio_zerado; else roda_suite pedido; fi
    afirma '[ "$RC" = 0 ]' "suite saiu com $RC: $(tail -3 "$S/ultimo.log")"
    afirma '[ -z "$(cat "$T"/campos-*.txt | grep -i pendrive)" ]' "tela do modo $modo cita pendrive: $(cat "$T"/campos-*.txt | grep -i pendrive | head -2)"
    afirma '[ "$(grep -c "^item=" "$(campos resumo resumo)")" = 19 ] && [ "$(grep -c "^grupo=" "$(campos resumo resumo)")" = 4 ]' "resumo sem 19 itens em 4 grupos"
    afirma '[ "$(grep -E "^(grupo|item)=" "$(campos resumo resumo)" | sed "s/|.*//" | tr "\n" ";")" = "grupo=COR;item=Formato do painel;item=C\u00e2mera;item=Painel;grupo=IMAGEM;item=Resolu\u00e7\u00e3o;item=\u00c2ngulo;item=Foco;item=Nitidez;item=4 pontos;item=Modo de proje\u00e7\u00e3o;grupo=TEMPERATURA;item=LED;item=Placa;item=Brilho;item=Ventoinha;item=Rampa t\u00e9rmica;grupo=SISTEMA;item=Firmware;item=Corre\u00e7\u00e3o t\u00e9rmica;item=Wi-Fi;item=Motivo do boot;item=Data e hora;" ]' "ordem dos itens: $(grep -E "^(grupo|item)=" "$(campos resumo resumo)" | sed "s/|.*//" | tr "\n" ";")"
    afirma '! grep -q "^item=.*|.*|.*|" "$(campos resumo resumo)" && ! grep -qv "^item=.*|\(ok\|corrigido\|atencao\|info\|pendente\)$" <(grep "^item=" "$(campos resumo resumo)")' "item com estado fora do contrato"
    afirma '[ -z "$(LC_ALL=C grep -nP "[^\x20-\x7E]" "$T"/campos-*.txt)" ]' "campos.txt com byte fora de ASCII imprimivel"
    afirma '[ "$(telas)" = "abertura calibracao calibracao escada-1 calibracao etapa3 etapa4 resumo " ]' "telas: '$(telas)'"
    afirma '[ "$(chamadas getevent)" = 1 ] && tem_chamada "input keyevent KEYCODE_HOME"' "resumo sem a espera de tecla ou sem voltar ao inicio"
    afirma '[ "$(tail -2 "$T/calls.log" | head -1)" = "am force-stop com.hisilicon.higallery" ]' "a galeria nao foi fechada antes do HOME"
    afirma '[ -z "$(grep "^am start" "$T/calls.log" | grep -v "file:///sdcard/pfl7560-")" ] && ! grep -q AM_ARQUIVO_AUSENTE "$T/calls.log"' "tela fora de /sdcard ou ausente"
    afirma 'grep -qF "rodape=$( [ "$modo" = tomada ] && echo "queda de energia" || echo "verifica\u00e7\u00e3o pedida") \u00b7 " "$(campos resumo resumo)"' "rodape do resumo"
    if [ "$modo" = tomada ]; then
      afirma 'grep -qxF "titulo=Voltou a energia.\nConferindo o projetor." "$(campos aviso abertura)"' "titulo da abertura da tomada"
    else
      afirma 'grep -qxF "titulo=Verifica\u00e7\u00e3o pedida.\nConferindo o projetor." "$(campos aviso abertura)"' "titulo da abertura do pedido"
    fi
    afirma '[ "$(grep -c "^passo=" "$(campos aviso abertura)")" = 4 ] && [ "$(grep -c "^passo=.*|fila$" "$(campos aviso abertura)")" = 4 ]' "abertura sem os 4 passos em fila"
    # C-res: resultados.txt e ultimo.log
    afirma '[ "$(res modo)" = "$modo" ] && [ "$(res itens)" = 19 ] && [ -n "$(res fim)" ] && [ -z "$(LC_ALL=C grep -nP "[^\x20-\x7E]" "$S/resultados.txt")" ]' "resultados.txt"
    afirma 'grep -q "suite terminada" "$S/ultimo.log" && [ ! -e "$S/resultados.txt.new" ] && [ ! -d "$R/dev/pfl7560-suite.lock" ]' "fim sujo"
    limpa
  done

  novo_cenario "modo pendrive: a ultima tela pede para tirar o pendrive; log no pendrive"
  etapa_feliz; pendrive
  roda_suite pendrive "$MP"
  afirma '[ "$(telas)" = "abertura calibracao calibracao escada-1 calibracao etapa3 etapa4 resumo final " ]' "telas: '$(telas)'"
  afirma 'grep -qx "titulo=Pode tirar o pendrive." "$(campos aviso final)"' "tela final"
  afirma 'grep -qxF "titulo=Pendrive do kit encontrado.\nConferindo o projetor." "$(campos aviso abertura)"' "abertura do pendrive"
  afirma '[ -s "$MP/newlink_suite.log" ] && [ -s "$MP/newlink_cor.log" ]' "logs nao foram para o pendrive"
  afirma '[ "$(grep -c "^sleep 2$" "$T/calls.log")" -eq 0 ]' "ESPERA_TIRAR=0 no harness: nao devia esperar"
  limpa

  novo_cenario "modo pendrive com termica-falhou e sem nl_tela = final estatica de erro"
  etapa_feliz; pendrive; : > "$T/nltela-falha"
  roda_suite pendrive "$MP" termica-falhou
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 calibracao erro " ]' "telas: '$(telas)'"
  limpa

  novo_cenario "sem nl_tela (md5 errado) no modo tomada: telas estaticas so sem pendrive"
  etapa_feliz; NLTELA_MD5_TESTE=00000000000000000000000000000000
  roda_suite tomada
  unset NLTELA_MD5_TESTE
  afirma '[ "$(chamadas nl_tela)" = 0 ]' "executou o nl_tela com md5 errado"
  afirma '[ "$(telas)" = "aguarde calibracao calibracao escada-1 calibracao " ] && tem_chamada "input keyevent KEYCODE_HOME"' "telas: '$(telas)'"
  afirma '[ "$(res itens)" = 19 ]' "resultados sem os 19 itens"
  limpa

  novo_cenario "resumo: tecla fecha antes"
  etapa_feliz; echo key > "$T/keys"
  roda_suite tomada
  afirma 'grep -q "resumo fechado por tecla" "$S/ultimo.log"' "log sem o fechamento por tecla"
  afirma 'tem_chamada "getevent -ql"' "sem getevent"
  limpa

  novo_cenario "pendrive: outra suite rodando = o modo pendrive espera (aqui 0 s) e sai sem mexer"
  etapa_feliz; pendrive; mkdir "$R/dev/pfl7560-suite.lock"
  roda_suite pendrive "$MP"
  afirma '[ "$RC" = 0 ] && [ "$(chamadas am)" = 0 ] && [ -d "$R/dev/pfl7560-suite.lock" ]' "andou com a trava de outra suite"
  limpa

  novo_cenario "tomada: outra suite rodando = sai"
  etapa_feliz; mkdir "$R/dev/pfl7560-suite.lock"
  roda_suite tomada
  afirma '[ "$RC" = 0 ] && [ "$(chamadas am)" = 0 ]' "andou com a trava"
  limpa

  novo_cenario "suite: pasta da suite aberta = nao roda"
  etapa_feliz; chmod 755 "$S"
  roda_suite tomada
  afirma '[ "$RC" = 1 ] && [ "$(chamadas am)" = 0 ] && [ ! -e "$S/ultimo.log" ]' "rodou numa pasta aberta"
  limpa

  novo_cenario "suite: subpasta kit/ da suite e LINK (mesmos PNG) = nao roda"
  etapa_feliz; cp -r "$S/kit" "$T/kit.igual"; rm -rf "$S/kit"; ln -s "$T/kit.igual" "$S/kit"
  roda_suite tomada
  afirma '[ "$RC" = 1 ] && [ "$(chamadas am)" = 0 ]' "rodou com a subpasta link (rc=$RC)"
  limpa

  novo_cenario "suite: PNG do kit adulterado na pasta da suite = nao mostra"
  etapa_feliz; NLTELA_MD5_TESTE=0; printf 'X' >> "$S/kit/calibracao.png"
  roda_suite tomada
  unset NLTELA_MD5_TESTE
  afirma '! grep -q "calibracao.png" "$T/calls.log"' "mostrou a calibracao adulterada"
  limpa
}

c_ambiente(){
  novo_cenario "ganchos PFL_* sem PFL_TESTE=1 sao ignorados (suite, boot, pedido)"
  etapa_feliz
  local f
  if [ "$(id -u)" != 0 ] && [ ! -e /data/vendor/pfl7560-suite ]; then
    for f in suite.sh suite-boot.sh suite-pedido.sh; do
      env PFL_ROOT="$R" PFL_RAPIDO=1 PFL_DONO="$(id -u)" PATH="$T/bin:$PATH" dash "$S/$f" tomada > "$T/sem-teste.log" 2>&1
      afirma '[ "$(chamadas setsid)" = 0 ] && [ "$(chamadas am)" = 0 ] && [ ! -e "$S/ultimo.log" ] && [ ! -e "$S/boot.log" ]' "$f usou a arvore de mentira sem PFL_TESTE"
    done
    env PFL_ROOT="$R" PATH="$T/bin:$PATH" dash "$S/suite-pedido.sh" w /x pedir-verificacao > "$T/sem-teste.log" 2>&1
    afirma '[ "$(chamadas setsid)" = 0 ]' "suite-pedido.sh usou a arvore de mentira sem PFL_TESTE"
  else
    echo "  (root ou /data/vendor/pfl7560-suite existe no host: caso pulado)"
  fi
  for f in suite.sh suite-boot.sh suite-pedido.sh; do
    afirma 'grep -q "^if \[ \"\${PFL_TESTE:-}\" != \"1\" \]; then$" "$KIT/$f"' "$f sem o bloco que apaga os PFL_*"
  done
  limpa
}

# ---------------------------------------------------------------------------
# achados do conferente (bloco 9B)
# ---------------------------------------------------------------------------
c_conferente(){
  local rc

  novo_cenario "conferente: so o .rc pendente e o remount falha = o kit segue (suite lancada), sem .rc"
  pendrive; rc="$R/vendor/etc/init/pfl7560-suite.rc"
  stub mount 'echo "mount $*" >> "$T/calls.log"; case "$*" in *rw,remount*) exit 1 ;; esac; exit 0'
  roda_kit
  afirma '[ "$RC" = 0 ]' "o kit abortou por causa do .rc (rc=$RC): $(tail -3 "$T/kit.out")"
  afirma '[ ! -e "$rc" ] && [ ! -e "$R/vendor/etc/pfl7560-suite.rc.new" ]' "gravou o .rc sem o /vendor rw"
  afirma 'grep -q "servico de boot e app da suite NAO instalados" "$T/kit.out"' "log sem o aviso do .rc"
  afirma 'tem_chamada "setsid sh $S/suite.sh pendrive $MP"' "a suite nao foi lancada: $(grep setsid "$T/calls.log")"
  limpa

  novo_cenario "conferente: fix do /vendor pendente e o remount falha = aborta como antes"
  pendrive; cp "$ROOT/artifacts/build.prop.STOCK" "$R/vendor/build.prop"
  stub mount 'echo "mount $*" >> "$T/calls.log"; case "$*" in *rw,remount*) exit 1 ;; esac; exit 0'
  roda_kit
  afirma '[ "$RC" = 1 ] && [ "$(chamadas setsid)" = 0 ]' "deveria abortar como antes (rc=$RC)"
  limpa

  novo_cenario "conferente: rotulo do .rc preparado fora do padrao = nao entra em /vendor/etc/init"
  pendrive; rc="$R/vendor/etc/init/pfl7560-suite.rc"
  # ls -Z de mentira: o init.bigfish.rc tem o rotulo de fabrica; o resto, um rotulo errado
  # (o chcon nao pegou)
  stub ls 'if [ "$1" = "-Z" ]; then case "$2" in *init.bigfish.rc) echo "u:object_r:vendor_configs_file:s0 $2" ;; *) echo "u:object_r:vendor_file:s0 $2" ;; esac; exit 0; fi
exec '"$(command -v ls)"' "$@"'
  roda_kit
  afirma '[ "$RC" = 0 ] && [ ! -e "$rc" ] && [ ! -e "$R/vendor/etc/pfl7560-suite.rc.new" ]' "o .rc fora do padrao entrou ou sobrou (rc=$RC)"
  afirma 'grep -q "rc preparado ficou fora do padrao" "$T/kit.out"' "log sem a recusa do rotulo"
  afirma 'tem_chamada "mount -o ro,remount /vendor"' "o /vendor ficou rw"
  afirma 'tem_chamada "setsid sh $S/suite.sh pendrive $MP"' "a suite deveria seguir"
  limpa

  novo_cenario "conferente: 2 suites interrompidas seguidas = o boot nao roda mais sozinho"
  instala_suite; echo sempre > "$S/gatilho"; echo 2 > "$S/incompletas"
  roda_boot
  afirma 'ult_hist | grep -q "incompletas=2; gatilho=sempre; decisao=nao; motivo=interrompida_2x_seguidas$"' "historico: '$(ult_hist)'"
  afirma '! grep -q "suite.sh tomada" "$T/calls.log"' "lancou depois de 2 interrupcoes"
  limpa

  novo_cenario "conferente: 1 suite interrompida = ainda roda"
  instala_suite; echo sempre > "$S/gatilho"; echo 1 > "$S/incompletas"
  roda_boot
  afirma 'ult_hist | grep -q "incompletas=1; gatilho=sempre; decisao=sim; motivo=gatilho_sempre$"' "historico: '$(ult_hist)'"
  limpa

  novo_cenario "conferente: a suite conta o inicio e zera no fim"
  etapa_feliz; echo 1 > "$S/incompletas"
  stub wm 'cat "$PFL_ROOT/data/vendor/pfl7560-suite/incompletas" > "$T/inc-durante" 2>/dev/null; echo "Physical size: 1920x1080"'
  roda_suite tomada
  afirma '[ "$(cat "$T/inc-durante" 2>/dev/null)" = 2 ]' "durante a suite o contador devia ser 2: '$(cat "$T/inc-durante" 2>/dev/null)'"
  afirma '[ ! -e "$S/incompletas" ]' "o contador nao foi zerado no fim"
  limpa

  novo_cenario "conferente: a suite morta por TERM tambem zera (o trap chega ao fim)"
  etapa_feliz; echo 40 > "$T/mata-no-sleep"
  roda_suite tomada
  afirma '[ "$RC" = 130 ] && [ ! -e "$S/incompletas" ]' "rc=$RC ou contador ficou"
  limpa

  novo_cenario "conferente: timeout que nao repassa o TERM (toybox) = o logcat da rampa nao fica orfao"
  etapa_feliz
  local real_sleep; real_sleep="$(command -v sleep)"
  stub logcat 'echo "logcat $*" >> "$T/calls.log"; cat "$T/logcat-saida"; echo $$ > "$T/logcat.pid"; exec '"$real_sleep"' 30'
  stub timeout 'shift; case "$1" in logcat) "$@" & wait $! ;; *) exec "$@" ;; esac'
  roda_suite tomada
  afirma '[ -s "$T/logcat.pid" ] && ! kill -0 "$(cat "$T/logcat.pid")" 2>/dev/null' "o logcat ficou rodando depois da suite"
  afirma '[ "$(res rampa)" = reagiu ]' "rampa: $(res rampa)"
  [ -s "$T/logcat.pid" ] && kill "$(cat "$T/logcat.pid")" 2>/dev/null
  limpa

  novo_cenario "conferente: desinstalar leva a copia do backup do panelparam para o pendrive"
  pendrive
  roda_kit
  cp "$T/pp-original.img" "$S/panelparam-backup-SER123.img"
  : > "$MP/DESINSTALAR-SUITE.txt"; : > "$T/calls.log"
  roda_kit
  afirma '[ ! -e "$S" ] && cmp -s "$MP/suite-panelparam-backup-SER123.img" "$T/pp-original.img"' "a copia do backup se perdeu"
  afirma '( cd "$MP" && md5sum -c --quiet suite-panelparam-backup-SER123.img.md5 )' "md5 da copia no pendrive"
  afirma 'grep -q "copia do backup do panelparam levada para o pendrive" "$T/kit.out"' "log sem a copia"
  limpa

  novo_cenario "conferente: desinstalar com o override ativo (suite morta no meio da rampa) = limpa"
  pendrive
  roda_kit
  awk -v k="$PROP_OV" 'index($0, k "=") != 1' "$T/props" > "$T/p" && echo "$PROP_OV=71000" >> "$T/p" && mv "$T/p" "$T/props"
  : > "$MP/DESINSTALAR-SUITE.txt"; : > "$T/calls.log"
  roda_kit
  afirma '[ -z "$(awk -F= -v k="$PROP_OV" "\$1==k{print \$2}" "$T/props")" ] && tem_chamada "setprop $PROP_OV "' "o override ficou depois de desinstalar"
  afirma 'grep -q "override de temperatura limpo e conferido" "$T/kit.out"' "log sem a limpeza"
  limpa

  novo_cenario "conferente: pedido que nao se apaga (pasta) = ignorado, sem lancar"
  instala_suite; mkdir -p "$PED/pedir-verificacao/x"
  roda_pedido w "$PED" pedir-verificacao
  afirma '[ "$(chamadas setsid)" = 0 ]' "lancou um pedido que nao foi apagado"
  afirma 'grep -q "nao consegui apagar o pedido" "$S/vigia.log"' "log sem o aviso"
  limpa

  if ! command -v inotifyd >/dev/null 2>&1; then
    novo_cenario "conferente: laco do vigia ignora uma pasta com o nome do pedido"
    instala_suite; rm -f "$T/bin/inotifyd"; mkdir -p "$PED/pedir-verificacao/x"
    roda_boot
    afirma '[ "$(chamadas setsid)" = 0 ] && ! grep -q "pedido de verificacao recebido" "$S/vigia.log" 2>/dev/null' "o laco tratou a pasta como pedido"
    limpa
  fi

  novo_cenario "conferente: historico guarda a barra invertida do motivo (printf, nao echo)"
  instala_suite
  awk '!/^sys.boot.reason=/' "$T/props" > "$T/p" && printf '%s\n' 'sys.boot.reason=a\cb' >> "$T/p" && mv "$T/p" "$T/props"
  roda_boot
  afirma 'ult_hist | grep -qF "boot_reason=a\cb; "' "historico: '$(ult_hist)'"
  afirma 'ult_hist | grep -q "motivo=desligamento_nao_limpo$"' "a linha foi cortada: '$(ult_hist)'"
  limpa

  novo_cenario "conferente: modo pendrive com termica-falhou = tela final em alerta citando o log"
  etapa_feliz; pendrive
  roda_suite pendrive "$MP" termica-falhou
  afirma 'grep -qx "tom=alerta" "$(campos aviso final)" && grep -q "newlink_update.log" "$(campos aviso final)" && grep -qx "titulo=Pode tirar o pendrive." "$(campos aviso final)"' "tela final: $(tr '\n' '|' < "$(campos aviso final)")"
  limpa

  novo_cenario "conferente: modo pendrive sem falha = tela final normal"
  etapa_feliz; pendrive
  roda_suite pendrive "$MP"
  afirma 'grep -qx "tom=normal" "$(campos aviso final)" && ! grep -q "newlink_update.log" "$(campos aviso final)"' "tela final: $(tr '\n' '|' < "$(campos aviso final)")"
  limpa
}

# ---------------------------------------------------------------------------
# estaticos
# ---------------------------------------------------------------------------
c_estaticos(){
  CASO="estaticos"
  local f
  for f in suite.sh suite-boot.sh suite-pedido.sh pfl7560-suite.rc newlink_update.sh cor.sh LEIA-ME.txt; do
    afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$KIT/$f")" ]' "$f tem byte fora de ASCII"
    afirma '[ "$(grep -c $'"'"'\r'"'"' "$KIT/$f")" = 0 ]' "$f tem CRLF"
  done
  for f in suite.sh suite-boot.sh suite-pedido.sh; do
    afirma 'head -1 "$KIT/$f" | grep -qx "#!/vendor/bin/sh"' "shebang de $f"
    afirma 'dash -n "$KIT/$f"' "dash -n $f"
    afirma 'busybox sh -n "$KIT/$f"' "busybox sh -n $f"
    afirma 'bash -n "$KIT/$f"' "bash -n $f"
    afirma '! grep -vE "^[[:space:]]*#" "$KIT/$f" | grep -qE "\[\[ |\$\{[A-Za-z_]+//|(^|[ ;])source |(^|[ ;])local |echo -n|<<<"' "bashismo em $f"
    afirma '! grep -vE "^[[:space:]]*#" "$KIT/$f" | grep -qw adb' "$f cita adb"
    afirma 'git -C "$ROOT" check-attr byte-exact -- "pendrive-autorun/$f" | grep -q "byte-exact: set"' "$f nao esta como byte-exact no .gitattributes"
  done
  afirma 'git -C "$ROOT" check-attr byte-exact -- pendrive-autorun/pfl7560-suite.rc | grep -q "byte-exact: set"' ".rc nao esta como byte-exact"
  if command -v shellcheck >/dev/null 2>&1; then
    afirma 'shellcheck -s sh "$KIT/suite.sh" "$KIT/suite-boot.sh" "$KIT/suite-pedido.sh" "$KIT/cor.sh" "$KIT/newlink_update.sh"' "shellcheck -s sh"
    afirma 'shellcheck "$ROOT/tests/test-suite.sh" "$ROOT/tests/atualizar-md5-kit.sh"' "shellcheck dos testes"
  else
    echo "  (shellcheck ausente: etapa pulada)"
  fi
  afirma 'bash "$ROOT/tests/atualizar-md5-kit.sh" --check >/dev/null' "listas md5 desatualizadas"
  # cada md5 da SUITE_LISTA e o do arquivo do kit
  afirma '( cd "$KIT" && sed -n "/^# SUITE_LISTA_INICIO/,/^# SUITE_LISTA_FIM/p" suite.sh | sed -n "s/^\(SUITE_LISTA=\"\)\{0,1\}\([0-9a-f]\{32\}  .*\)\$/\2/p" | md5sum -c --quiet - )' "SUITE_LISTA nao confere com os arquivos"
  afirma '[ "$(sed -n "s/^SUITE_MD5=\"\(.*\)\"$/\1/p" "$KIT/suite-boot.sh")" = "$(md5 "$KIT/suite.sh")" ] && [ "$(sed -n "s/^SUITE_MD5=\"\(.*\)\"$/\1/p" "$KIT/suite-pedido.sh")" = "$(md5 "$KIT/suite.sh")" ] && [ "$(sed -n "s/^PEDIDO_MD5=\"\(.*\)\"$/\1/p" "$KIT/suite-boot.sh")" = "$(md5 "$KIT/suite-pedido.sh")" ]' "md5 do suite.sh/suite-pedido.sh embutidos errados"
  for f in INI_MD5_OK INI_MD5_OK_NOTYPEC; do
    afirma '[ "$(grep "^$f=" "$KIT/suite.sh" | cut -d\" -f2)" = "$(grep "^$f=" "$KIT/newlink_update.sh" | cut -d\" -f2)" ]' "$f da suite difere do newlink_update.sh"
  done
  # o override: so 71000, literal, nunca configuravel; 75000 nunca (fora de comentario)
  afirma '[ "$(grep -c "^INJETADO=71000$" "$KIT/suite.sh")" = 1 ] && ! grep -q "INJETADO=.*\\\$" "$KIT/suite.sh"' "INJETADO nao e o 71000 literal"
  afirma '! grep -vE "^[[:space:]]*#" "$KIT/suite.sh" | grep -q 75000' "suite.sh cita 75000 fora de comentario"
  afirma '[ "$(grep -c "setprop \"\$PROP_OVERRIDE\"" "$KIT/suite.sh")" = 2 ] && grep -q "setprop \"\$PROP_OVERRIDE\" \"\$INJETADO\"$" "$KIT/suite.sh" && grep -q "setprop \"\$PROP_OVERRIDE\" '"''"'" "$KIT/suite.sh"' "setprop do override fora do padrao (so 71000 e vazio)"
  # o hidebug: a unica entrada e gfs/gbri; gtt nunca. Bloco 11: o foco so por hb_foco, que so
  # deixa passar gfd, gfdr e sfd <numero> (nada de sfd2/sfd3/saps nem GPIO)
  afirma '[ "$(grep -c "| timeout 15 \"\$HIDEBUG\"" "$KIT/suite.sh")" = 2 ] && grep -q "^    gfd|gfdr) ;;$" "$KIT/suite.sh" && ! grep -vE "^[[:space:]]*#" "$KIT/suite.sh" | grep -qE "sfd2|sfd3|saps|/proc/msp/gpio"' "o hidebug recebe algo fora de gfs/gbri e gfd/gfdr/sfd"
  afirma '[ "$(grep -c "HIDEBUG" "$KIT/suite.sh")" -ge 1 ] && ! grep -vE "^[[:space:]]*#" "$KIT/suite.sh" | grep -qiE "gtt"' "suite.sh cita gtt fora de comentario"
  # (bloco 15: o suite-pedido.sh passa a falar com o hidebug so para a luz, "sbl" e "gbl"; gtt nunca)
  afirma '! grep -vE "^[[:space:]]*#" "$KIT/suite-boot.sh" "$KIT/suite-pedido.sh" | grep -qiE "gtt"' "boot/pedido citam gtt"
  afirma '! grep -vE "^[[:space:]]*#" "$KIT/suite-boot.sh" | grep -qi "hidebug"' "o boot fala com o hidebug direto (deve chamar o suite-pedido.sh)"
  afirma '[ -z "$(grep -vE "^[[:space:]]*#" "$KIT/suite-pedido.sh" | grep "| timeout 15 " | grep -vE "sbl %s|gbl")" ]' "o suite-pedido.sh manda ao hidebug algo alem de sbl/gbl: $(grep -vE "^[[:space:]]*#" "$KIT/suite-pedido.sh" | grep "| timeout 15 " | grep -vE "sbl %s|gbl")"
  # os 4 pontos e o modo de projecao: so leitura
  # o servico de boot sobe com o PATH do /vendor: os scripts fixam o PATH com /system/bin
  for f in suite-boot.sh suite.sh suite-pedido.sh cor.sh; do
    afirma 'grep -q "^  PATH=\"/system/bin:/system/xbin:/vendor/bin:/vendor/xbin\"; export PATH$" "$KIT/$f"' "$f sem o PATH fixo com /system/bin"
  done
  # o awk do Android 9 recusa "exit !(...)" (visto no aparelho): nenhum script do kit usa
  afirma '! grep -n "exit !" "$KIT"/*.sh' "script do kit com exit !(...) no awk: $(grep -n "exit !" "$KIT"/*.sh | head -3)"
  # (a unica prop persist que a suite toca e a marca do gatilho, so no desinstalar)
  afirma '! grep -vE "^[[:space:]]*#" "$KIT/suite.sh" | grep -v "setprop persist.sys.boot.reason \"\"" | grep -qE "setprop (persist|\"?persist)|ProjectionService|nlhotkey|FourPointActivity"' "a suite escreve 4 pontos/modo ou abre telas do sistema"
  # o .rc: 0644 no git tambem nao importa (o kit faz chmod); conteudo do servico
  afirma 'grep -qx "service pfl7560_suite /vendor/bin/sh /data/vendor/pfl7560-suite/suite-boot.sh" "$KIT/pfl7560-suite.rc"' ".rc sem o servico"
}

# ---------------------------------------------------------------------------
echo "== estaticos =="
c_estaticos
echo "== cenarios sob dash =="
for c in ${CASOS:-c_gatilho_matriz c_gatilho_bloqueios c_gatilho_seguranca c_vigia c_descanso c_pedido c_luz c_instalacao c_desinstalar c_desinstalar14 c_overlays_boot c_apps_boot \
         c_etapas_cor c_etapas_geometria c_etapas_foco c_etapas_temperatura c_etapas_rampa c_telas c_ambiente c_conferente}; do
  echo "  $c"
  "$c"
done

# globais: em TODOS os cenarios
CASO="global"
# o valor de cada item cabe na coluna do resumo (medido no nl_tela do 9A: 18 caracteres
# de Mono 34 px; \uXXXX conta como um)
afirma '[ -z "$(valores_longos)" ]' "valor de item longo demais: $(valores_longos | tr '\n' '|')"
afirma '[ "$(grep -c "^item=" "$TODAS_CAMPOS")" -ge 300 ]' "poucos resumos gerados nos cenarios ($(grep -c "^item=" "$TODAS_CAMPOS"))"
afirma '! grep -q "^GTT" "$TODAS" && ! grep -q "^HIDEBUG.*gtt" "$TODAS"' "gtt chamado em algum cenario"
afirma '[ -z "$(grep "^HIDEBUG.* \(gfd\|gfdr\|sfd\)" "$TODAS" | grep -vE "^HIDEBUG  custom (gfd|gfdr|sfd [0-9]+) quit $")" ]' "o motor de foco recebeu outro comando: $(grep "^HIDEBUG.* \(gfd\|gfdr\|sfd\)" "$TODAS" | grep -vE "custom (gfd|gfdr|sfd [0-9]+) quit" | head -2)"
afirma '[ "$(grep -c "^HIDEBUG  custom sfd " "$TODAS")" -ge 10 ]' "a varredura quase nao rodou nos cenarios"
afirma '[ -z "$(grep "^setprop $PROP_OV" "$TODAS" | grep -v "^setprop $PROP_OV 71000$" | grep -v "^setprop $PROP_OV $")" ]' "o override recebeu outro valor: $(grep "^setprop $PROP_OV" "$TODAS" | sort -u | tr '\n' '|')"
afirma '! grep -q 75000 "$TODAS"' "75000 apareceu em alguma chamada"
afirma '[ "$(grep -c "^setprop $PROP_OV 71000$" "$TODAS")" -ge 5 ]' "a rampa quase nao rodou nos cenarios ($(grep -c "^setprop $PROP_OV 71000$" "$TODAS"))"

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
