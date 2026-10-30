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
# Precisa de: dash, busybox, shellcheck (opcional), pkill, python3 com PIL e numpy.
#
#   bash tests/test-kit-pendrive.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
OFF=$(( 168 + 69 * 768 + 92 ))     # byte lvdsctl_fmt do perfil 69 (53252, 0-based; 53253 no cmp -l)
PNOME="RX058B_4300_5010E_1080P_M"
REAL_CMP="$(command -v cmp)"

FALHAS=0
TESTES=0
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA [$SHELL_NOME] $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }

md5(){ md5sum "$1" | cut -d' ' -f1; }
pp_md5(){ md5 "$T/root/dev/block/by-name/panelparam"; }
pp_byte(){ dd if="$T/root/dev/block/by-name/panelparam" bs=1 skip="$OFF" count=1 2>/dev/null | od -An -tu1 | tr -dc '0-9'; }
chamadas(){ grep -c "^$1" "$T/calls.log" 2>/dev/null || true; }
tem_chamada(){ grep -q "$1" "$T/calls.log" 2>/dev/null; }
telas(){ grep '^am ' "$T/calls.log" 2>/dev/null | sed 's#.*/\([a-z0-9-]*\)\.png.*#\1#' | tr '\n' ' '; }

# ---------------------------------------------------------------------------
# cenario: arvore de mentira + stubs
# ---------------------------------------------------------------------------
novo_cenario(){ # $1 = nome do caso
  CASO="$1"
  T="$(mktemp -d)"
  local r="$T/root" b="$T/bin"
  mkdir -p "$r/vendor/etc/init/hw" "$r/vendor/lib" "$r/atv" "$r/proc/msp" "$r/dev/block/by-name" \
           "$r/data/local/tmp" "$r/sdcard" "$r/mnt/media_rw/USB1" "$b"
  : > "$r/vendor/lib/libhitvservice.so"
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
k=$(head -1 "$T/keys"); sed -i 1d "$T/keys"
[ "$k" = "key" ] && echo "/dev/input/event2: EV_KEY       KEY_OK                DOWN"
exit 0'
  stub am 'echo "am $*" >> "$T/calls.log"
f=$(echo "$*" | sed "s#.*-d file://\([^ ]*\).*#\1#")
f="$PFL_ROOT$f"
[ -f "$f" ] || echo "AM_ARQUIVO_AUSENTE $f" >> "$T/calls.log"
exit 0'
  stub reboot 'echo "reboot" >> "$T/calls.log"'
  stub sleep 'echo "sleep $*" >> "$T/calls.log"'
  stub mount 'echo "mount $*" >> "$T/calls.log"; exit 0'
  stub hidebug 'echo "HIDEBUG $*" >> "$T/calls.log"'
  stub gtt 'echo "GTT $*" >> "$T/calls.log"'
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

# aparelho com tudo aplicado (termico/wi-fi/xiri): so a cor fica em jogo
aparelho_ok(){
  local r="$T/root"
  cp "$KIT/ZYCustom.ini" "$r/vendor/etc/ZYCustom.ini"
  sed -i 's/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/' "$r/vendor/build.prop"
  sed -i "/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled" "$r/vendor/etc/init/hw/init.bigfish.rc"
}
estado_vendor(){ ( cd "$T/root/vendor" && find . -type f | sort | xargs md5sum | md5sum ); }

# roda o autorun; $1.. = teclas (key|nokey) na ordem em que getevent for chamado
roda(){
  : > "$T/keys"; for k in "$@"; do echo "$k" >> "$T/keys"; done
  rm -f "$T/setsid.done"
  PFL_RAPIDO=1 PFL_ROOT="$T/root" PFL_LVDSCTL="$T/bin/lvdsctl" PATH="$T/bin:$PATH" \
    $SHELL_BIN_RUN "$T/root/mnt/media_rw/USB1/newlink_update.sh" USB1 > "$T/out.log" 2>&1
  RC=$?
  local i=0
  while [ -z "${SEM_ESPERA:-}" ] && grep -q "lancando a fase de cor" "$T/out.log" && [ ! -f "$T/setsid.done" ] && [ "$i" -lt 100 ]; do
    sleep 0.1; i=$((i+1))
  done
  [ -f "$T/root/data/local/tmp/pfl7560-kit/cor.log" ] && cp "$T/root/data/local/tmp/pfl7560-kit/cor.log" "$T/cor.log.copia" 2>/dev/null
  return 0
}
limpa(){ if [ -n "${DEBUG_KEEP:-}" ]; then echo "  (mantido: $T)"; else rm -rf "$T"; fi; }
# log completo (autorun + fase de cor, que vai para o pendrive no fim)
log_tudo(){ cat "$T/out.log" "$T/root/mnt/media_rw/USB1/newlink_cor.log" 2>/dev/null; }

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
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal criado sem tecla"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "gancho criado sem tecla"
  afirma '[ "$(chamadas reboot)" = 0 ]' "reboot sem motivo"
  afirma '[ "$(estado_vendor)" = "$v0" ]' "/vendor mudou"
  afirma '[ "$(telas)" = "aguarde metades-1 pronto " ]' "telas: '$(telas)'"
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
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal sobrou"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "gancho sobrou"
  afirma '[ "$(telas)" = "aguarde metades-1 metades-1 metades-2 pronto " ]' "telas: '$(telas)'"
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
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal sobrou depois de confirmar"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "gancho sobrou depois de confirmar"
  afirma 'cmp -s "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" "$T/pp-original.img"' "backup nao guarda o original"
  afirma '[ "$(telas)" = "aguarde metades-1 metades-1 metades-2 pronto " ]' "telas: '$(telas)'"
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
  afirma '[ "$(telas)" = "aguarde metades-1 pronto " ]' "telas da 2a: '$(telas)'"
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
  afirma '[ "$(telas)" = "aguarde metades-1 erro " ]' "tela final deveria ser erro: '$(telas)'"
  limpa
}

c_atv_override(){
  novo_cenario "/atv/ini com override = avisa"; aparelho_ok
  mkdir -p "$T/root/atv/ini"; echo x > "$T/root/atv/ini/ZYCustom_390.ini"
  roda nokey
  afirma 'grep -q "TEM PRECEDENCIA" "$T/out.log"' "sem aviso de precedencia"
  afirma '! grep -q "CORRECAO APLICADA COM SUCESSO" "$T/out.log"' "disse sucesso apesar do override"
  afirma '[ "$(telas)" = "aguarde metades-1 erro " ]' "tela final deveria ser erro: '$(telas)'"
  afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam mudou"
  limpa
}

c_adulterado(){
  local alvo
  for alvo in "kit/metades-1.png" "cor.sh" "lvdsctl" "ZYCustom.ini" "kit/pronto.png"; do
    novo_cenario "arquivo do kit adulterado ($alvo) = aborta antes de escrever"
    local v0; v0="$(estado_vendor)"
    printf 'X' >> "$T/root/mnt/media_rw/USB1/$alvo"
    roda key key
    afirma '[ "$RC" = 1 ]' "deveria sair com 1 (saiu com $RC)"
    afirma '[ "$(estado_vendor)" = "$v0" ]' "/vendor mudou"
    afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam mudou"
    afirma '[ "$(chamadas reboot)" = 0 ] && [ "$(chamadas mount)" = 0 ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas getevent)" = 0 ]' "houve reboot/mount/lvdsctl/getevent"
    afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit" ]' "o kit foi copiado para /data antes de conferir"
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
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal sobrou"
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
  PFL_RAPIDO=1 PFL_ROOT="$T/root" PFL_LVDSCTL="$T/bin/lvdsctl" PATH="$T/bin:$PATH" $SHELL_BIN_RUN "$T/root/data/local/nlsu/update_after_boot.sh" > "$T/hook.log" 2>&1
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o gancho nao restaurou a panelparam"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ]' "o gancho nao se apagou"
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit" ]' "diretorio de trabalho sobrou"
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
  chmod 555 "$T/root/data/local/tmp/pfl7560-kit"
  if [ "$(id -u)" != 0 ]; then
    roda nokey
    afirma '[ "$(pp_md5)" = "$PP0" ]' "a particao nao foi restaurada"
    afirma '[ "$(chamadas reboot)" = 0 ]' "reiniciou com o journal de pe (laco de reboot)"
    afirma '[ -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "o journal deveria ter ficado"
  else
    echo "  (rodando como root: caso do journal que nao se apaga pulado)"
  fi
  chmod 755 "$T/root/data/local/tmp/pfl7560-kit"
  limpa

  novo_cenario "journal incoerente = nao escreve"; aparelho_ok
  simula_teste_interrompido
  sed -i 's/^J_OFF=.*/J_OFF=100/' "$T/root/data/local/tmp/pfl7560-kit/journal"
  roda nokey
  afirma '[ "$(pp_byte)" = 1 ]' "restaurou com journal incoerente"
  afirma '[ -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal incoerente foi apagado (deveria ficar para inspecao)"
  limpa
}

# estado de uma queda de energia no meio do teste: panelparam em JEIDA (1), journal,
# backup do original, copia do cor.sh em /data e gancho instalado
simula_teste_interrompido(){
  local r="$T/root" w="$T/root/data/local/tmp/pfl7560-kit"
  mkdir -p "$w" "$r/data/local/nlsu"
  cp "$r/dev/block/by-name/panelparam" "$w/panelparam-original.img"
  cp "$KIT/cor.sh" "$w/cor.sh"
  printf 'J_IDX=69\nJ_OFF=%s\nJ_FMT=0\n' "$OFF" > "$w/journal"
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

c_gancho_gerado(){
  # o gancho que o PROPRIO cor.sh escreve tem de ser o que restaura (nao um de teste)
  novo_cenario "gancho gerado pelo cor.sh restaura o formato"; aparelho_ok
  # executa so ate a 2a pergunta e "cai a energia": 2a espera de tecla mata o processo
  stub getevent 'echo "getevent $*" >> "$T/calls.log"
n=$(cat "$T/n" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$T/n"
[ "$n" = 1 ] && echo "/dev/input/event2: EV_KEY       KEY_OK                DOWN"
if [ "$n" = 2 ]; then pkill -9 -f "pfl7560-kit/cor.sh"; sleep 1; fi
exit 0'
  roda
  afirma '[ "$(pp_byte)" = 1 ]' "o teste interrompido deveria ter deixado o byte em 1"
  afirma '[ -f "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal deveria existir"
  afirma 'grep -q "pfl7560-kit-gancho" "$T/root/data/local/nlsu/update_after_boot.sh"' "gancho nao foi gerado"
  rmdir "$T/root/dev/pfl7560-kit.lock" 2>/dev/null   # /dev e tmpfs: o lock some com a queda de energia
  PFL_RAPIDO=1 PFL_ROOT="$T/root" PFL_LVDSCTL="$T/bin/lvdsctl" PATH="$T/bin:$PATH" $SHELL_BIN_RUN "$T/root/data/local/nlsu/update_after_boot.sh" > "$T/hook.log" 2>&1
  afirma '[ "$(pp_md5)" = "$PP0" ]' "o gancho gerado nao restaurou"
  afirma '[ ! -e "$T/root/data/local/nlsu/update_after_boot.sh" ] && [ ! -e "$T/root/data/local/nlsu" ]' "o gancho nao se apagou"
  limpa
}

c_falhas_seguras(){
  novo_cenario "lvdsctl nao muda o byte = reverte e nao deixa journal"; aparelho_ok
  : > "$T/lvds-falha"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ]' "panelparam mudou"
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal sobrou"
  afirma '[ "$(telas)" = "aguarde metades-1 metades-1 erro " ]' "telas: '$(telas)'"
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
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal sobrou"
  limpa

  novo_cenario "lvdsctl corrompe ao devolver o formato = o journal ainda vale e a reversao confere"; aparelho_ok
  : > "$T/lvds-corrompe-ao-reverter"
  roda key nokey
  afirma '[ "$(pp_md5)" = "$PP0" ]' "a escrita do lvdsctl na reversao ficou sem conferencia"
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal sobrou"
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
  afirma '[ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "journal criado sem backup"
  afirma '[ ! -e "$T/root/mnt/media_rw/USB1/panelparam-backup-SER123.img" ]' "backup invalido ficou no pendrive"
  afirma '[ "$(telas)" = "aguarde metades-1 metades-1 erro " ]' "telas: '$(telas)'"
  limpa

  novo_cenario "nome do perfil na particao nao bate com o driver = nao escreve"; aparelho_ok
  sed -i 's/RX058B_4300_5010E_1080P_M/OUTRO_PAINEL/' "$T/root/proc/msp/panel"
  roda key key
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ "$(chamadas getevent)" = 0 ]' "escreveu com offset nao provado"
  afirma '[ "$(telas)" = "aguarde erro " ]' "telas: '$(telas)'"
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
  afirma '[ "$(pp_md5)" = "$PP0" ] && [ "$(chamadas lvdsctl)" = 0 ] && [ ! -e "$T/root/data/local/tmp/pfl7560-kit/journal" ]' "escreveu sem lvdsctl"
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

c_sem_hidebug(){
  novo_cenario "nunca chama hidebug/gtt"
  roda nokey
  afirma '! grep -qE "^(HIDEBUG|GTT)" "$T/calls.log"' "hidebug/gtt chamado na 1a execucao"
  roda key key
  afirma '! grep -qE "^(HIDEBUG|GTT)" "$T/calls.log"' "hidebug/gtt chamado na fase de cor"
  # estatico: nenhuma linha executavel (fora de comentario) cita hidebug ou gtt
  afirma '! grep -vE "^[[:space:]]*#" "$KIT/newlink_update.sh" "$KIT/cor.sh" | grep -qiE "hidebug|[[:space:]]gtt[[:space:]]"' "script executavel cita hidebug/gtt"
  limpa
}

# ---------------------------------------------------------------------------
# estaticos
# ---------------------------------------------------------------------------
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
  afirma '[ "$(md5 "$KIT/lvdsctl")" = 178d812872cb9306c0ae6faeed07184a ]' "lvdsctl do kit com md5 errado"
  afirma 'git -C "$ROOT" diff --quiet HEAD -- artifacts/lcd-color-fix/lvdsctl artifacts/lcd-color-fix/lvdsctl.c' "lvdsctl/lvdsctl.c de artifacts foram alterados"
  for f in cor.sh newlink_update.sh LEIA-ME.txt lvdsctl kit/metades-1.png; do
    afirma 'git -C "$ROOT" check-attr byte-exact -- "pendrive-autorun/$f" | grep -q "byte-exact: set"' "$f nao esta como byte-exact no .gitattributes"
  done
  afirma 'python3 -I "$ROOT/tests/simula-padroes-kit.py" >/dev/null' "simulacao dos padroes falhou"
  # LEIA-ME: fluxo de leigo com ate 5 passos numerados e todos os arquivos do kit citados
  afirma '[ "$(sed -n "/^COMO USAR/,/^  Resultado da parte termica/p" "$KIT/LEIA-ME.txt" | grep -cE "^  [0-9]\. ")" = 5 ]' "o fluxo do LEIA-ME nao tem exatamente 5 passos"
  for f in newlink_update.sh cor.sh lvdsctl ZYCustom.ini kit; do
    afirma 'grep -q "$f" "$KIT/LEIA-ME.txt"' "LEIA-ME nao cita $f"
  done
}

# ---------------------------------------------------------------------------
echo "== estaticos =="
c_estaticos

for SHELL_NOME in ${SHELLS:-dash}; do
  case "$SHELL_NOME" in
    dash) SHELL_BIN=dash; SHELL_BIN_RUN="dash" ;;
    busybox) SHELL_BIN=busybox; SHELL_BIN_RUN="busybox sh" ;;
  esac
  command -v "$SHELL_BIN" >/dev/null 2>&1 || { echo "(sem $SHELL_BIN: pulado)"; continue; }
  echo "== cenarios sob $SHELL_NOME =="
  for c in ${CASOS:-c_sem_tecla c_tecla_timeout c_tecla_tecla c_idempotencia c_ini_anterior c_ini_desconhecido \
           c_atv_override c_adulterado c_journal_no_boot c_gancho_gerado c_falhas_seguras c_sem_hidebug}; do
    echo "  $c"
    "$c"
  done
done

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
