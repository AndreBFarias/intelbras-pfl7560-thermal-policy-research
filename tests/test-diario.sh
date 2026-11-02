#!/usr/bin/env bash
# Teste do diario do projetor (bloco 24), lado do aparelho: pendrive-autorun/suite-diario.sh e os ganchos no
# suite-pedido.sh, suite-boot.sh e suite.sh (desinstalar). O lado do PC e o tests/test-pc-diario.sh.
# Tudo em simulacao: um "aparelho" em pasta temporaria (PFL_ROOT) e comandos de mentira no PATH.
# Nenhum teste fala com o projetor.
# shellcheck disable=SC2016,SC2034,SC2012
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

stub(){ printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
novo_cenario(){
  CASO="$1"
  T="$(mktemp -d)"
  R="$T/root"; S="$R/data/vendor/pfl7560-suite"; D="$S/diario"; PEDH="$R/data/data/com.pfl7560.home"
  local b="$T/bin"
  mkdir -p "$R/dev" "$R/data/vendor" "$b" "$R/proc/sys/kernel/random" "$R/sys/class/net/wlan0" "$R/sys/class/net/eth0" "$PEDH"
  mkdir -p "$S"; chmod 700 "$S"
  echo "812.34 3000.11" > "$R/proc/uptime"
  echo "0.52 0.40 0.30 1/200 999" > "$R/proc/loadavg"
  printf 'MemTotal:        2000000 kB\nMemFree:          100000 kB\nMemAvailable:     312000 kB\n' > "$R/proc/meminfo"
  echo "a1b2c3d4-e5f6-4711-8899-aabbccddeeff" > "$R/proc/sys/kernel/random/boot_id"
  echo up > "$R/sys/class/net/wlan0/operstate"; echo down > "$R/sys/class/net/eth0/operstate"
  printf '%s\n' zysys.env_temp=45 zysys.light_temp=41 vendor.pfl7560.luz=80 vendor.pfl7560.vent=agressivo:ok \
    vendor.pfl7560.led=padrao vendor.pfl7560.chaves=1101101111 > "$T/props"
  : > "$T/calls.log"
  stub getprop 'awk -v k="$1" '"'"'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }'"'"' "$T/props"'
  stub setprop 'echo "setprop $1 ${2:-}" >> "$T/calls.log"
awk -v k="$1" '"'"'index($0, k "=") != 1'"'"' "$T/props" > "$T/props.novo"
printf "%s=%s\n" "$1" "${2:-}" >> "$T/props.novo"; mv "$T/props.novo" "$T/props"'
  stub gtt 'echo "GTT $*" >> "$T/calls.log"'
  stub logcat 'echo "logcat $*" >> "$T/calls.log"'
  stub hidebug 'echo "hidebug $*" >> "$T/calls.log"'
  ln -sf "$(command -v dash)" "$b/sh"
  export T
}
limpa(){
  # so os lacos lancados por ESTE cenario (o caminho com a pasta temporaria e unico)
  for _p in $(pgrep -f "$S/suite-diario.sh laco" 2>/dev/null); do kill "$_p" 2>/dev/null; done
  if [ -n "${DEBUG_KEEP:-}" ]; then echo "  (mantido: $T)"; else rm -rf "$T"; fi
}
instala(){
  local f
  for f in suite-diario.sh suite-pedido.sh suite-boot.sh suite-chaves.sh suite-curvas.sh; do cp "$KIT/$f" "$S/$f"; chmod 755 "$S/$f"; done
  cp "$KIT/debloat-aprovados.txt" "$S/debloat-aprovados.txt"; chmod 600 "$S/debloat-aprovados.txt"
}
amb(){
  env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_RAPIDO=1 PFL_ROOT="$R" PFL_APP_UID_MIN=0 PFL_VIGIA_VOLTAS=2 PFL_PM_ESPERA=0 PFL_PM_TENTATIVAS=3 \
      PFL_DIARIO_INTERVALO="${INTERVALO_T:-30}" PFL_DIARIO_VOLTAS="${VOLTAS_T:-0}" PFL_DIARIO_MAX="${MAX_T:-262144}" \
      PATH="$T/bin:$PATH" "$@"
}
di(){ amb dash "$S/suite-diario.sh" "$@" > "$T/di.out" 2>&1; RC=$?; }
prop_(){ awk -v k="$1" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' "$T/props"; }
tem_chamada(){ grep -qF -- "$1" "$T/calls.log" 2>/dev/null; }
linhas(){ cat "$D"/diario-0.txt "$D"/diario-1.txt 2>/dev/null | grep -c .; }
ultima(){ cat "$D"/diario-0.txt "$D"/diario-1.txt 2>/dev/null | tail -n 1; }
tudo(){ cat "$D"/diario-0.txt "$D"/diario-1.txt 2>/dev/null; }
campo_da(){ printf '%s\n' "$2" | tr ' ' '\n' | sed -n "s/^$1=//p"; }
espera(){ local i=0; while ! eval "$1"; do i=$((i+1)); [ "$i" -ge 40 ] && return 1; sleep 0.1; done; return 0; }
FORMATO='^up=[0-9-]+ dt=[0-9-]+ boot=[0-9a-f-]+ env=[0-9.-]+ placa=[0-9.-]+ luz=[0-9-]+ load=[0-9.-]+ vent=[a-z0-9:_-]+ led=[a-z0-9:_-]+ wifi=[a-z-]+ eth=[a-z-]+ mem=[0-9-]+ ch=[01p?-]+ ev=[A-Za-z0-9:,+_-]+$'

c_estaticos(){
  CASO="estaticos"
  local f="$KIT/suite-diario.sh"
  afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$f")" ]' "suite-diario.sh tem byte fora de ASCII"
  afirma '[ "$(grep -c $'"'"'\r'"'"' "$f")" = 0 ]' "suite-diario.sh tem CRLF"
  afirma 'head -1 "$f" | grep -qx "#!/vendor/bin/sh"' "shebang"
  afirma 'dash -n "$f" && bash -n "$f" && busybox sh -n "$f"' "sintaxe sh"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qE "\[\[ |\$\{[A-Za-z_]+//|(^|[ ;])source |(^|[ ;])local |echo -n|<<<"' "bashismo"
  afirma 'grep -q "^  PATH=\"/system/bin:/system/xbin:/vendor/bin:/vendor/xbin\"; export PATH$" "$f"' "sem o PATH fixo"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qwE "gtt|stp|logcat|adb|hidebug|dmesg|top"' "cita gtt/stp/logcat/adb/hidebug fora de comentario"
  afirma '! grep -vE "^[[:space:]]*#" "$f" | grep -qE "rm -rf /(data|system|vendor)[^$]"' "comando destrutivo"
  afirma 'git -C "$ROOT" check-attr byte-exact -- pendrive-autorun/suite-diario.sh | grep -q "byte-exact: set"' "fora do .gitattributes byte-exact"
  if command -v shellcheck >/dev/null 2>&1; then
    afirma 'shellcheck -s sh "$f" "$KIT/suite-pedido.sh" "$KIT/suite-boot.sh" "$KIT/suite.sh" "$KIT/newlink_update.sh"' "shellcheck -s sh"
    afirma 'shellcheck "$ROOT/tests/test-diario.sh"' "shellcheck do teste"
  else
    echo "  (shellcheck ausente: etapa pulada)"
  fi
  afirma 'bash "$ROOT/tests/atualizar-md5-kit.sh" --check >/dev/null' "listas md5 desatualizadas"
  afirma '[ "$(sed -n "s/^DIARIO_MD5=\"\(.*\)\"$/\1/p" "$KIT/suite-boot.sh")" = "$(md5 "$f")" ] && [ "$(sed -n "s/^DIARIO_MD5=\"\(.*\)\"$/\1/p" "$KIT/suite-pedido.sh")" = "$(md5 "$f")" ]' "DIARIO_MD5 embutido em boot/pedido difere do script"
  afirma 'sed -n "/^# SUITE_LISTA_INICIO/,/^# SUITE_LISTA_FIM/p" "$KIT/suite.sh" | grep -q "^$(md5 "$f")  suite-diario.sh$"' "suite-diario.sh fora da SUITE_LISTA do suite.sh"
  afirma 'sed -n "/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p" "$KIT/newlink_update.sh" | grep -q "^$(md5 "$f")  suite-diario.sh$"' "suite-diario.sh fora da KIT_LISTA"
  afirma 'grep -q "^KIT_EXEC=.* suite-diario.sh" "$KIT/newlink_update.sh"' "suite-diario.sh fora da KIT_EXEC"
  afirma 'grep -q "sh \"\$SUITE/suite-diario.sh\" parar" "$KIT/suite.sh"' "desinstalar nao para o laco do diario"
  afirma 'grep -q "com.pfl7560.home/diario\"" "$KIT/suite.sh"' "desinstalar nao apaga o pedido diario da home (sobraria para a proxima instalacao)"
  afirma 'grep -q "^  luz|curva-vent|curva-led|chave|diario) PEDIDO_DIR=\"\$HOME_DIR\" ;;" "$KIT/suite-pedido.sh"' "suite-pedido nao aceita o pedido diario da pasta da home"
  afirma '[ "$(grep -c "chave diario" "$KIT/suite-boot.sh")" = 2 ]' "o vigia nao olha o pedido diario nos dois lugares"
  afirma 'grep -q "MAX_ARQ=262144" "$f"' "o tamanho de cada arquivo nao e 256 KB"
}

c_linha(){
  novo_cenario "linha: o formato, os valores e a prop"
  instala
  di uma-linha
  afirma '[ "$RC" = 0 ] && [ "$(linhas)" = 1 ]' "uma-linha nao gravou uma linha ($RC): $(cat "$T/di.out")"
  local l; l=$(ultima)
  afirma 'printf "%s\n" "$l" | grep -qE "$FORMATO"' "formato fora do contrato: $l"
  afirma '[ "$(campo_da up "$l")" = 812 ] && [ "$(campo_da boot "$l")" = a1b2c3d4 ] && [ "$(campo_da env "$l")" = 45 ] && [ "$(campo_da placa "$l")" = 41 ]' "up/boot/env/placa: $l"
  afirma '[ "$(campo_da luz "$l")" = 80 ] && [ "$(campo_da load "$l")" = 0.52 ] && [ "$(campo_da vent "$l")" = agressivo:ok ] && [ "$(campo_da led "$l")" = padrao ]' "luz/load/vent/led: $l"
  afirma '[ "$(campo_da wifi "$l")" = up ] && [ "$(campo_da eth "$l")" = down ] && [ "$(campo_da mem "$l")" = 312000 ] && [ "$(campo_da ch "$l")" = 1101101111 ] && [ "$(campo_da ev "$l")" = - ]' "wifi/eth/mem/ch/ev: $l"
  afirma '[ "$(campo_da dt "$l")" -gt 1700000000 ]' "dt nao e a hora do aparelho: $l"
  afirma '[ -z "$(printf "%s" "$l" | LC_ALL=C grep -P "[^ -~]")" ]' "linha com byte fora de ASCII imprimivel"
  afirma '[ "$(prop_ vendor.pfl7560.diario | cut -d: -f1)" = 1 ] && [ "$(prop_ vendor.pfl7560.diario | cut -d: -f3)" = 0 ]' "prop diario: $(prop_ vendor.pfl7560.diario)"
  afirma '[ "$(prop_ vendor.pfl7560.diario | cut -d: -f2)" = "$(cat "$D"/diario-0.txt | wc -c)" ]' "tamanho da prop difere do arquivo"
  afirma '[ "$(stat -c %a "$D")" = 700 ] && [ "$(stat -c %a "$D/diario-0.txt")" = 600 ]' "modos da pasta e do arquivo: $(stat -c %a "$D") $(stat -c %a "$D/diario-0.txt")"
  afirma '! tem_chamada GTT && ! tem_chamada logcat && ! tem_chamada hidebug' "o diario chamou gtt, logcat ou hidebug"
  # nada para ler: tudo vira "-" e a linha segue valida
  : > "$T/props"; rm -f "$R/proc/loadavg" "$R/proc/meminfo" "$R/sys/class/net/eth0/operstate" "$R/proc/sys/kernel/random/boot_id"
  di uma-linha
  l=$(ultima)
  afirma 'printf "%s\n" "$l" | grep -qE "$FORMATO" && [ "$(campo_da env "$l")" = - ] && [ "$(campo_da load "$l")" = - ] && [ "$(campo_da boot "$l")" = - ]' "sem fontes a linha quebrou: $l"
  limpa

  novo_cenario "linha: valor com lixo, espaco ou ponto e virgula nao entra na linha"
  instala
  printf '%s\n' 'zysys.env_temp=4 5;rm' 'vendor.pfl7560.vent=Agressivo $(id)' 'vendor.pfl7560.chaves=1101101111EXTRAEXTRAEXTRA' > "$T/props"
  di uma-linha
  local l; l=$(ultima)
  afirma 'printf "%s\n" "$l" | grep -qE "$FORMATO" && [ "$(printf "%s" "$l" | tr -cd " " | wc -c)" = 13 ]' "lixo furou o formato: $l"
  afirma '! printf "%s" "$l" | grep -qE "[;$()]"' "caractere de shell na linha: $l"
  limpa
}

c_revezamento(){
  novo_cenario "revezamento: dois arquivos, o atual enche, o outro e zerado"
  instala
  MAX_T=700
  local i m0 m1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do echo "$((i * 10)).00 1.0" > "$R/proc/uptime"; di uma-linha; done
  m0=$(wc -c < "$D/diario-0.txt"); m1=$(wc -c < "$D/diario-1.txt")
  afirma '[ "$m0" -le 700 ] && [ "$m1" -le 700 ] && [ "$m0" -gt 0 ] && [ "$m1" -gt 0 ]' "tamanhos $m0 e $m1 fora de 1..700"
  afirma '[ "$(ls "$D" | wc -l)" = 2 ]' "mais de dois arquivos: $(ls "$D" | tr '\n' ' ')"
  afirma 'tudo | grep -q "^up=200 "' "a linha mais nova se perdeu"
  afirma '! tudo | grep -q "^up=10 "' "a linha mais velha deveria ter sido reciclada"
  afirma '[ "$(linhas)" -ge 6 ] && [ "$(linhas)" -le 20 ]' "total de linhas $(linhas)"
  afirma '[ -z "$(tudo | grep -vE "$FORMATO")" ]' "linha partida entre os arquivos"
  afirma '[ "$(cat "$S/diario.atual")" = 0 ] || [ "$(cat "$S/diario.atual")" = 1 ]' "ponteiro invalido"
  afirma '[ "$(prop_ vendor.pfl7560.diario | cut -d: -f2)" = "$((m0 + m1))" ]' "a prop nao soma os dois arquivos"
  # o ponteiro estragado cai em 0 e nao quebra
  echo "lixo" > "$S/diario.atual"; di uma-linha
  afirma '[ "$RC" = 0 ] && [ -z "$(tudo | grep -vE "$FORMATO")" ]' "ponteiro estragado quebrou o diario"
  MAX_T=""
  limpa

  novo_cenario "revezamento: tamanho de verdade (256 KB) nao passa de 262144 por arquivo"
  instala
  mkdir -p "$D"; chmod 700 "$D"
  head -c 262100 /dev/zero | tr '\0' 'a' > "$D/diario-0.txt"; chmod 600 "$D/diario-0.txt"
  di uma-linha
  afirma '[ "$(wc -c < "$D/diario-0.txt")" = 262100 ] && [ "$(wc -c < "$D/diario-1.txt")" -gt 0 ] && [ "$(cat "$S/diario.atual")" = 1 ]' "nao virou o arquivo ao passar de 256 KB"
  limpa
}

c_eventos(){
  novo_cenario "eventos: as mudancas de chave da fila entram uma vez"
  instala
  printf '%s\n' '700 eth0 ligar ok' '705 deb_vlc desligar ok' > "$S/diario.fila"
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = "eth0:ligar:ok,deb_vlc:desligar:ok" ]' "ev da primeira linha: $(ultima)"
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = - ]' "o mesmo evento saiu duas vezes: $(ultima)"
  echo '810 keystone ligar falhou' >> "$S/diario.fila"
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = "keystone:ligar:falhou" ]' "so o evento novo devia sair: $(ultima)"
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = - ]' "evento repetido: $(ultima)"
  # a fila foi aparada e a linha vista sumiu: sai o que tem, sem quebrar
  printf '%s\n' '900 wifi_pwr ligar ok' > "$S/diario.fila"
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = "wifi_pwr:ligar:ok" ]' "fila aparada: $(ultima)"
  limpa

  novo_cenario "eventos: mais de 5 viram +N, lixo e linha torta ficam de fora"
  instala
  {
    echo '1 eth0 ligar ok'; echo '2 eth0 desligar ok'; echo '3 deb_seg ligar ok'; echo '4 deb_ota ligar ok'
    echo '5 deb_hisi ligar ok'; echo '6 keystone ligar ok'; echo '7 web_cmd ligar ok'
    echo 'torta so tres'; echo '8 a b c d'; echo '9 x;rm ligar ok'
  } > "$S/diario.fila"
  di uma-linha
  local ev; ev=$(campo_da ev "$(ultima)")
  afirma '[ "$ev" = "eth0:ligar:ok,eth0:desligar:ok,deb_seg:ligar:ok,deb_ota:ligar:ok,deb_hisi:ligar:ok,+3" ]' "ev: $ev"
  afirma '! printf "%s" "$ev" | grep -qE "[;$ ]"' "lixo no ev: $ev"
  limpa

  novo_cenario "eventos: ligar o diario depois de um tempo desligado nao despeja o passado"
  instala
  printf '%s\n' '10 eth0 ligar ok' '20 eth0 desligar ok' > "$S/diario.fila"
  di desligar
  echo '30 keystone ligar ok' >> "$S/diario.fila"
  di ligar
  di parar
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = - ]' "o passado entrou no diario ao ligar: $(ultima)"
  echo '40 web_cmd desligar ok' >> "$S/diario.fila"
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = "web_cmd:desligar:ok" ]' "evento depois de ligar: $(ultima)"
  limpa

  novo_cenario "eventos: a fila como link nao e lida"
  instala
  echo '1 eth0 ligar ok' > "$T/alvo"; ln -s "$T/alvo" "$S/diario.fila"
  di uma-linha
  afirma '[ "$(campo_da ev "$(ultima)")" = - ]' "seguiu o link da fila: $(ultima)"
  limpa
}

c_ligar_desligar(){
  novo_cenario "ligar e desligar: a marca, a prop e o que a linha faz"
  instala
  di desligar
  afirma '[ -e "$S/diario.desligado" ] && [ "$(prop_ vendor.pfl7560.diario | cut -d: -f1)" = 0 ]' "desligar nao marcou: $(prop_ vendor.pfl7560.diario)"
  di uma-linha
  afirma '[ "$(linhas)" = 0 ]' "gravou linha com o diario desligado"
  di iniciar
  afirma '[ ! -e "$R/dev/pfl7560-diario.pid" ] && grep -q "desligado pelo dono" "$T/di.out"' "iniciar lancou o laco com o diario desligado"
  di ligar
  afirma '[ ! -e "$S/diario.desligado" ] && [ "$(prop_ vendor.pfl7560.diario | cut -d: -f1)" = 1 ]' "ligar nao tirou a marca: $(prop_ vendor.pfl7560.diario)"
  di parar
  limpa
}

c_laco(){
  novo_cenario "laco: grava uma linha por volta e para sozinho na marca"
  instala
  VOLTAS_T=3; INTERVALO_T=0
  di laco
  afirma '[ "$(linhas)" = 3 ] && [ ! -e "$R/dev/pfl7560-diario.pid" ]' "o laco de 3 voltas gravou $(linhas) linhas"
  VOLTAS_T=""; INTERVALO_T=""
  touch "$S/diario.desligado"
  di laco
  afirma '[ "$(linhas)" = 3 ]' "o laco rodou com a marca de desligado"
  limpa

  novo_cenario "laco: iniciar lanca um so, desligar mata, ligar volta"
  instala
  di iniciar
  afirma 'espera "[ \$(linhas) -ge 1 ]"' "o laco lancado nao gravou a primeira linha: $(cat "$T/di.out")"
  local pid; pid=$(head -n 1 "$R/dev/pfl7560-diario.pid" | tr -cd '0-9')
  afirma '[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && grep -aq suite-diario "/proc/$pid/cmdline"' "pid do laco nao esta vivo: '$pid'"
  di iniciar
  afirma 'grep -q "ja vivo" "$T/di.out" && [ "$(head -n 1 "$R/dev/pfl7560-diario.pid" | tr -cd "0-9")" = "$pid" ]' "um segundo iniciar mudou o pid: $(cat "$T/di.out")"
  di desligar
  afirma 'espera "! kill -0 $pid 2>/dev/null"' "desligar nao matou o laco $pid"
  afirma '[ ! -e "$R/dev/pfl7560-diario.pid" ] && [ -e "$S/diario.desligado" ]' "pid ou marca depois do desligar"
  local antes; antes=$(linhas); sleep 0.5
  afirma '[ "$(linhas)" = "$antes" ]' "o diario seguiu gravando depois de desligado"
  di ligar
  afirma 'espera "[ \$(linhas) -gt $antes ]"' "ligar nao religou o laco"
  di desligar
  limpa

  novo_cenario "laco: pid de outro processo no arquivo nao e morto"
  instala
  sleep 30 &
  local outro=$!
  echo "$outro" > "$R/dev/pfl7560-diario.pid"
  di desligar
  afirma 'kill -0 "$outro" 2>/dev/null' "o parar matou um processo que nao e o laco do diario"
  kill "$outro" 2>/dev/null
  limpa
}

c_envio(){
  novo_cenario "envio: enviar so marca, enviado limpa e guarda a data do PC"
  instala
  di enviar
  afirma '[ -f "$S/diario.envio" ] && [ "$(prop_ vendor.pfl7560.diario | cut -d: -f3)" = 1 ]' "enviar nao marcou o pedido: $(prop_ vendor.pfl7560.diario)"
  afirma '[ "$(linhas)" = 0 ] && ! tem_chamada adb' "enviar fez mais que marcar"
  di enviado 2026-11-01T14:32:05
  afirma '[ ! -e "$S/diario.envio" ] && [ "$(prop_ vendor.pfl7560.diario | cut -d: -f3)" = 0 ] && [ "$(prop_ vendor.pfl7560.diario_envio)" = 2026-11-01T14:32:05 ]' "enviado nao limpou: $(prop_ vendor.pfl7560.diario) / $(prop_ vendor.pfl7560.diario_envio)"
  afirma '[ "$(cat "$S/diario.ultimo-envio")" = 2026-11-01T14:32:05 ]' "ultimo-envio nao foi guardado"
  local ruim
  for ruim in '' 2026-11-01 '2026-11-01T14:32:05;rm' '2026-11-01 14:32:05' 'abcd-ef-ghTij:kl:mn' '2026-11-01T14:32:05X' '$(id)xxxxxxxxxxxxxxxxx' '2026-11-01T14:32:0'; do
    di enviado "$ruim"
    afirma '[ "$RC" != 0 ] && [ "$(cat "$S/diario.ultimo-envio")" = 2026-11-01T14:32:05 ]' "data ruim aceita: '$ruim'"
  done
  limpa
}

c_pedido(){
  novo_cenario "pedido: so v1 + as quatro palavras"
  instala
  di pedido "v1 desligar"
  afirma '[ -e "$S/diario.desligado" ]' "v1 desligar nao desligou"
  di pedido "v1 ligar"
  afirma '[ ! -e "$S/diario.desligado" ]' "v1 ligar nao ligou"
  di pedido "v1 enviar"
  afirma '[ -f "$S/diario.envio" ]' "v1 enviar nao marcou"
  rm -f "$S/diario.envio"
  di pedido "v1 ler"
  afirma '[ "$(prop_ vendor.pfl7560.diario | cut -d: -f1)" = 1 ]' "v1 ler nao publicou"
  local ruim
  for ruim in "v2 desligar" "v1 apagar" "v1" "desligar" "v1 desligar ; rm -rf /" "v1 desligar enviar" "" "v1 DESLIGAR" "v1 ../ligar"; do
    rm -f "$S/diario.desligado" "$S/diario.envio"
    di pedido "$ruim"
    afirma '[ ! -e "$S/diario.desligado" ] && [ ! -e "$S/diario.envio" ]' "pedido ruim agiu: '$ruim'"
  done
  limpa
}

c_seguranca(){
  novo_cenario "seguranca: pasta do root aberta ou diario em link nao gravam fora"
  instala
  chmod 755 "$S"
  di uma-linha
  afirma '[ ! -e "$D" ] && grep -q "nao e uma pasta so do root" "$T/di.out"' "gravou numa pasta aberta"
  di desligar
  afirma '[ ! -e "$S/diario.desligado" ]' "mexeu numa pasta aberta"
  chmod 700 "$S"
  limpa

  novo_cenario "seguranca: a pasta diario e os arquivos como link nao sao seguidos"
  instala
  mkdir -p "$T/fora"; echo "intacto" > "$T/fora/x"
  ln -s "$T/fora" "$D"
  di uma-linha
  afirma '[ -d "$D" ] && [ ! -L "$D" ] && [ "$(cat "$T/fora/x")" = intacto ] && [ "$(ls "$T/fora" | wc -l)" = 1 ]' "seguiu o link da pasta diario"
  rm -f "$D/diario-0.txt"
  echo "alvo-intacto" > "$T/alvo"; ln -s "$T/alvo" "$D/diario-0.txt"
  di uma-linha
  afirma '[ "$(cat "$T/alvo")" = alvo-intacto ] && [ ! -L "$D/diario-0.txt" ] && [ "$(linhas)" -ge 1 ]' "escreveu atraves do link do arquivo"
  limpa
}

c_integracao(){
  novo_cenario "integracao: a home escreve 'diario', o suite-pedido valida e o suite-diario age"
  instala
  printf 'v1 desligar\n' > "$PEDH/diario"
  amb dash "$S/suite-pedido.sh" w "$PEDH" diario > "$T/pedido.out" 2>&1
  afirma '[ -e "$S/diario.desligado" ] && [ ! -e "$PEDH/diario" ]' "pedido da home nao desligou: $(tail -3 "$T/pedido.out")"
  printf 'v1 ligar\n' > "$PEDH/diario"
  amb dash "$S/suite-pedido.sh" w "$PEDH" diario > "$T/pedido.out" 2>&1
  afirma '[ ! -e "$S/diario.desligado" ] && [ ! -e "$PEDH/diario" ]' "pedido da home nao ligou: $(tail -3 "$T/pedido.out")"
  printf 'v1 enviar\n' > "$PEDH/diario"
  amb dash "$S/suite-pedido.sh" w "$PEDH" diario > "$T/pedido.out" 2>&1
  afirma '[ -f "$S/diario.envio" ] && [ ! -e "$PEDH/diario" ]' "pedido de envio nao marcou"
  # quem nao e o app
  rm -f "$S/diario.envio"; printf 'v1 enviar\n' > "$PEDH/diario"
  env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_RAPIDO=1 PFL_ROOT="$R" PFL_APP_UID_MIN=99999 PATH="$T/bin:$PATH" dash "$S/suite-pedido.sh" w "$PEDH" diario > "$T/pedido.out" 2>&1
  afirma '[ ! -f "$S/diario.envio" ] && [ ! -e "$PEDH/diario" ]' "pedido de quem nao e o app foi aceito"
  # enorme e cortado
  head -c 5000 /dev/zero | tr '\0' 'a' > "$PEDH/diario"
  amb dash "$S/suite-pedido.sh" w "$PEDH" diario > "$T/pedido.out" 2>&1
  afirma '[ ! -f "$S/diario.envio" ] && [ ! -e "$S/diario.desligado" ] && [ ! -e "$PEDH/diario" ]' "pedido enorme agiu"
  # link no lugar do pedido
  echo "v1 desligar" > "$T/alvo"; ln -s "$T/alvo" "$PEDH/diario"
  amb dash "$S/suite-pedido.sh" w "$PEDH" diario > "$T/pedido.out" 2>&1
  afirma '[ ! -e "$S/diario.desligado" ]' "o link do pedido foi seguido"
  rm -f "$PEDH/diario"
  # script adulterado nao roda
  printf 'v1 desligar\n' > "$PEDH/diario"
  echo "# adulterado" >> "$S/suite-diario.sh"
  amb dash "$S/suite-pedido.sh" w "$PEDH" diario > "$T/pedido.out" 2>&1
  afirma '[ ! -e "$S/diario.desligado" ] && grep -q "suite-diario.sh ausente, link, de outro dono ou com md5 diferente" "$S/vigia.log"' "rodou um suite-diario.sh com md5 diferente"
  limpa

  novo_cenario "integracao: o boot liga o diario, ou nao liga se o dono desligou"
  instala
  stub dmesg 'exit 0'; stub inotifyd 'exit 0'
  mkdir -p "$R/data/system/users/0"; : > "$R/data/system/users/0/package-restrictions.xml"
  VOLTAS_T=2; INTERVALO_T=0
  amb dash "$S/suite-boot.sh" > "$T/boot.out" 2>&1
  afirma 'espera "[ \$(linhas) -ge 2 ]"' "o boot nao ligou o diario: $(tail -3 "$S/boot.log" 2>/dev/null) $(cat "$S/diario.log" 2>/dev/null)"
  afirma 'grep -q "laco do diario lancado" "$S/boot.log"' "boot.log sem o registro do laco"
  rm -rf "$D"; touch "$S/diario.desligado"
  amb dash "$S/suite-boot.sh" > "$T/boot.out" 2>&1
  sleep 0.3
  afirma '[ ! -e "$D" ] && grep -q "desligado pelo dono" "$S/boot.log"' "o boot ligou o diario que o dono desligou"
  VOLTAS_T=""; INTERVALO_T=""
  limpa

  novo_cenario "integracao: suite-diario.sh adulterado nao roda no boot"
  instala
  stub dmesg 'exit 0'; stub inotifyd 'exit 0'
  mkdir -p "$R/data/system/users/0"; : > "$R/data/system/users/0/package-restrictions.xml"
  echo "# adulterado" >> "$S/suite-diario.sh"
  amb dash "$S/suite-boot.sh" > "$T/boot.out" 2>&1
  afirma '[ ! -e "$D" ] && grep -q "suite-diario.sh ausente, link, de outro dono ou com md5 diferente" "$S/boot.log"' "rodou o script adulterado no boot"
  limpa

  novo_cenario "integracao: o desinstalar para o laco do diario"
  instala
  afirma 'sed -n "/suite-diario.sh\" suite-diario.sh/,/^  fi/p" "$KIT/suite.sh" | grep -q "parar"' "o desinstalar nao chama parar sob a conferencia"
  limpa
}

echo "== estaticos =="
c_estaticos
echo "== cenarios sob dash =="
for c in ${CASOS:-c_linha c_revezamento c_eventos c_ligar_desligar c_laco c_envio c_pedido c_seguranca c_integracao}; do
  echo "  $c"
  "$c"
done
echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
