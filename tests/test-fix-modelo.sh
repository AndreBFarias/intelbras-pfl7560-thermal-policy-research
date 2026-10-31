#!/usr/bin/env bash
# tests/test-fix-modelo.sh - bloco 6 (T6.3): o pfl7560-fix.sh apply/revert e POR MODELO.
#
# Roda o pfl7560-fix.sh REAL contra um aparelho de mentira: um adb de mentira no PATH que
# executa os comandos de `adb shell` numa arvore temporaria (o /vendor vira $FAKE/vendor),
# e push/pull que copiam para ela. NUNCA fala com o aparelho. O script e os artefatos sao
# copiados para uma pasta temporaria: o backups-projetor/ do teste nao toca o do repo.
#
#   bash tests/test-fix-modelo.sh
# shellcheck disable=SC2034
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FALHAS=0
TESTES=0
CASO=""
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }

A_INI=29d8ba36149413e899563029df078f6d     # fabrica V1.0.0.9
A_BP=fd8406c494c201e468a0401fa082027c
N_INI=ed3f314ca89698cb057a74ef64dca38e     # fabrica V1.0.0.1 (NOTYPEC)
N_BP=f5b24c1db546dcfb4340f485bf841c8e
A_FIX=252ab7a72a007a8b79b3fc86bd5c0d19     # corrigido V1.0.0.9
N_FIX=bdf5c4640596d1b2f2fb7f62fbadd6e3     # corrigido V1.0.0.1

# aparelho de fabrica de um modelo: $1 = antigo|novo
novo_cenario(){
  CASO="$2"
  T="$(mktemp -d)"; FAKE="$T/dev"
  mkdir -p "$FAKE/vendor/etc/init/hw" "$T/bin" "$T/repo/artifacts"
  cp "$ROOT/pfl7560-fix.sh" "$T/repo/"
  cp "$ROOT"/artifacts/ZYCustom.ini.ORIGINAL "$ROOT"/artifacts/ZYCustom.ini.NOTYPEC.STOCK \
     "$ROOT"/artifacts/build.prop.STOCK "$ROOT"/artifacts/build.prop.NOTYPEC.STOCK \
     "$ROOT"/artifacts/init.bigfish.rc.STOCK "$ROOT"/artifacts/ZYCustom_390.NOTYPEC.ini "$T/repo/artifacts/"
  cp "$ROOT/artifacts/init.bigfish.rc.STOCK" "$FAKE/vendor/etc/init/hw/init.bigfish.rc"
  if [ "$1" = novo ]; then
    cp "$ROOT/artifacts/ZYCustom.ini.NOTYPEC.STOCK" "$FAKE/vendor/etc/ZYCustom.ini"
    cp "$ROOT/artifacts/build.prop.NOTYPEC.STOCK" "$FAKE/vendor/build.prop"
    echo KJM_5H039_412_INTELBRAS_NOTYPEC_TP > "$T/projectname"
  else
    cp "$ROOT/artifacts/ZYCustom.ini.ORIGINAL" "$FAKE/vendor/etc/ZYCustom.ini"
    cp "$ROOT/artifacts/build.prop.STOCK" "$FAKE/vendor/build.prop"
    echo KJM_5H039_412_INTELBRAS_TP > "$T/projectname"
  fi
  cat > "$T/bin/adb" <<'FIM'
#!/bin/sh
[ "$1" = "-s" ] && shift 2
c="$1"; shift
echo "adb $c $*" >> "$T/adb.log"
sub(){ printf '%s' "$1" | sed "s#/vendor#$FAKE/vendor#g"; }
case "$c" in
  reboot) echo reboot >> "$T/reboot.log" ;;
  push) cp "$1" "$(sub "$2")" ;;
  pull) cp "$(sub "$1")" "$2" ;;
  shell) case "$*" in
           id) echo "uid=0(root) gid=0(root)" ;;
           "mount -o ro,remount /vendor") ;;
           *) sh -c "$(sub "$*")" ;;
         esac ;;
  *) ;;
esac
exit 0
FIM
  cat > "$T/bin/getprop" <<'FIM'
#!/bin/sh
case "$1" in
  ro.product.model) echo PFL7560 ;;
  ro.newlink.projectname) cat "$T/projectname" 2>/dev/null ;;
esac
FIM
  chmod +x "$T/bin/adb" "$T/bin/getprop"
  : > "$T/adb.log"; : > "$T/reboot.log"
  export T FAKE
}
fix(){ ( cd "$T/repo" && env PFL_IP=1.2.3.4 PATH="$T/bin:$PATH" bash ./pfl7560-fix.sh "$@" ) > "$T/out.log" 2>&1; RC=$?; }
BKD(){ echo "$T/repo/backups-projetor"; }
reboots(){ wc -l < "$T/reboot.log"; }
estado(){ ( cd "$FAKE/vendor" && find . -type f | sort | xargs md5sum | md5sum ); }
limpa(){ if [ -n "${DEBUG_KEEP:-}" ]; then echo "  (mantido: $T)"; else rm -rf "$T"; fi; }

c_antigo_apply_revert(){
  novo_cenario antigo "modelo com USB-C: apply e revert (como sempre)"
  fix apply
  afirma '[ "$RC" = 0 ] && [ "$(reboots)" = 1 ]' "apply falhou ou nao reiniciou (rc=$RC): $(tail -2 "$T/out.log" | tr '\n' ' ')"
  afirma '[ "$(md5 "$FAKE/vendor/etc/ZYCustom.ini")" = $A_FIX ]' "ini aplicado nao e o corrigido do modelo antigo"
  afirma '[ "$(md5 "$(BKD)/ZYCustom.ini.STOCK")" = $A_INI ] && [ "$(md5 "$(BKD)/build.prop.STOCK")" = $A_BP ]' "backup do modelo antigo errado"
  afirma '[ ! -e "$(BKD)/notypec" ]' "criou pasta de backup do outro modelo"
  afirma 'grep -q "modelo do aparelho: antigo" "$T/out.log"' "log sem o modelo"
  fix revert
  afirma '[ "$RC" = 0 ] && [ "$(reboots)" = 2 ]' "revert falhou (rc=$RC): $(tail -2 "$T/out.log" | tr '\n' ' ')"
  afirma '[ "$(md5 "$FAKE/vendor/etc/ZYCustom.ini")" = $A_INI ] && [ "$(md5 "$FAKE/vendor/build.prop")" = $A_BP ]' "revert nao devolveu o stock do modelo antigo"
  limpa
}

c_novo_apply_revert(){
  novo_cenario novo "modelo sem USB-C: apply preserva o CONFIG_MODEL e o revert devolve o build.prop DELE"
  fix apply
  afirma '[ "$RC" = 0 ] && [ "$(reboots)" = 1 ]' "apply falhou ou nao reiniciou (rc=$RC): $(tail -2 "$T/out.log" | tr '\n' ' ')"
  afirma '[ "$(md5 "$FAKE/vendor/etc/ZYCustom.ini")" = $N_FIX ]' "ini aplicado nao e o corrigido do modelo novo"
  afirma 'grep -aq "^CONFIG_MODEL = KJM_5H039_412_INTELBRAS_NOTYPEC_TP;" "$FAKE/vendor/etc/ZYCustom.ini"' "CONFIG_MODEL do modelo novo foi rebaixado"
  afirma 'grep -aq "HW_VIRTUAL_CHANNEL = 1" "$FAKE/vendor/etc/ZYCustom.ini"' "mux nao corrigido"
  afirma 'grep -q "wifi_disconnect_on_boot=0" "$FAKE/vendor/build.prop"' "wi-fi nao aplicado"
  afirma '[ "$(md5 "$(BKD)/notypec/ZYCustom.ini.STOCK")" = $N_INI ] && [ "$(md5 "$(BKD)/notypec/build.prop.STOCK")" = $N_BP ]' "backup do modelo novo errado"
  afirma '[ ! -e "$(BKD)/ZYCustom.ini.STOCK" ] && [ ! -e "$(BKD)/build.prop.STOCK" ]' "o backup do modelo novo foi parar na pasta do antigo"
  fix revert
  afirma '[ "$RC" = 0 ] && [ "$(reboots)" = 2 ]' "revert falhou (rc=$RC): $(tail -2 "$T/out.log" | tr '\n' ' ')"
  afirma '[ "$(md5 "$FAKE/vendor/etc/ZYCustom.ini")" = $N_INI ]' "revert nao devolveu o ini de fabrica do modelo novo"
  afirma '[ "$(md5 "$FAKE/vendor/build.prop")" = $N_BP ]' "revert nao devolveu o build.prop do modelo novo"
  afirma '! grep -q "zysys.typec" "$FAKE/vendor/build.prop"' "o revert deu ao modelo novo as linhas zysys.typec (USB-C fantasma)"
  afirma 'grep -q "NOTYPEC_TP_updateVer.xml" "$FAKE/vendor/build.prop"' "o revert trocou o canal de OTA do modelo novo"
  limpa
}

c_novo_revert_com_backup_do_antigo(){
  # armadilha: backup do V1.0.0.9 na pasta de sempre, aparelho do modelo novo
  novo_cenario novo "revert no modelo novo com SO o backup do V1.0.0.9 = recusa"
  mkdir -p "$(BKD)"
  cp "$ROOT/artifacts/ZYCustom.ini.ORIGINAL" "$(BKD)/ZYCustom.ini.STOCK"
  cp "$ROOT/artifacts/build.prop.STOCK" "$(BKD)/build.prop.STOCK"
  cp "$ROOT/artifacts/init.bigfish.rc.STOCK" "$(BKD)/init.bigfish.rc.STOCK"
  local e0; e0="$(estado)"
  fix revert
  afirma '[ "$RC" != 0 ]' "revert nao recusou"
  afirma '[ "$(estado)" = "$e0" ] && [ "$(reboots)" = 0 ]' "mexeu no aparelho ou reiniciou apesar da recusa"
  afirma 'grep -q "backup ausente ou vazio" "$T/out.log" && grep -q "MODELO novo" "$T/out.log"' "mensagem nao explica: $(tail -2 "$T/out.log" | tr '\n' ' ')"
  limpa
}

c_revert_backup_de_outro_modelo(){
  # backup do outro modelo colocado na pasta certa: o md5 nao confere = recusa
  novo_cenario novo "revert com build.prop.STOCK de outro modelo na pasta do aparelho = recusa"
  mkdir -p "$(BKD)/notypec"
  cp "$ROOT/artifacts/ZYCustom.ini.NOTYPEC.STOCK" "$(BKD)/notypec/ZYCustom.ini.STOCK"
  cp "$ROOT/artifacts/build.prop.STOCK" "$(BKD)/notypec/build.prop.STOCK"
  cp "$ROOT/artifacts/init.bigfish.rc.STOCK" "$(BKD)/notypec/init.bigfish.rc.STOCK"
  local e0; e0="$(estado)"
  fix revert
  afirma '[ "$RC" != 0 ] && [ "$(estado)" = "$e0" ] && [ "$(reboots)" = 0 ]' "nao recusou ou mexeu no aparelho"
  afirma 'grep -q "nao e o build.prop de fabrica do modelo novo" "$T/out.log"' "mensagem: $(tail -2 "$T/out.log" | tr '\n' ' ')"
  limpa
  novo_cenario antigo "revert no modelo antigo com build.prop.STOCK do modelo novo = recusa"
  mkdir -p "$(BKD)"
  cp "$ROOT/artifacts/ZYCustom.ini.ORIGINAL" "$(BKD)/ZYCustom.ini.STOCK"
  cp "$ROOT/artifacts/build.prop.NOTYPEC.STOCK" "$(BKD)/build.prop.STOCK"
  cp "$ROOT/artifacts/init.bigfish.rc.STOCK" "$(BKD)/init.bigfish.rc.STOCK"
  e0="$(estado)"
  fix revert
  afirma '[ "$RC" != 0 ] && [ "$(estado)" = "$e0" ] && [ "$(reboots)" = 0 ]' "nao recusou ou mexeu no aparelho"
  limpa
}

c_modelo_desconhecido(){
  novo_cenario antigo "modelo desconhecido ou contraditorio = apply e revert recusam"
  local e0 cmd
  # CONFIG_MODEL de outro modelo
  sed -i 's/^CONFIG_MODEL = .*/CONFIG_MODEL = OUTRO_MODELO;/' "$FAKE/vendor/etc/ZYCustom.ini"
  echo OUTRO_MODELO_TP > "$T/projectname"
  e0="$(estado)"
  for cmd in apply revert; do
    fix "$cmd"
    afirma '[ "$RC" != 0 ] && [ "$(estado)" = "$e0" ] && [ "$(reboots)" = 0 ] && [ ! -d "$(BKD)" ]' "$cmd num modelo desconhecido nao recusou limpo"
    afirma 'grep -q "modelo nao reconhecido" "$T/out.log"' "$cmd: mensagem"
  done
  # um sinal conhecido e o outro presente mas DESCONHECIDO: nao basta o conhecido, recusa
  # (senao o apply gravaria o ini do V1.0.0.9 por cima do CONFIG_MODEL de outro modelo)
  echo KJM_5H039_412_INTELBRAS_TP > "$T/projectname"
  e0="$(estado)"
  for cmd in apply revert; do
    fix "$cmd"
    afirma '[ "$RC" != 0 ] && [ "$(estado)" = "$e0" ] && [ "$(reboots)" = 0 ] && [ ! -d "$(BKD)" ]' "$cmd com CONFIG_MODEL desconhecido e projectname conhecido nao recusou limpo"
    afirma 'grep -q "modelo nao reconhecido" "$T/out.log"' "$cmd (CONFIG_MODEL desconhecido): mensagem"
  done
  cp "$ROOT/artifacts/ZYCustom.ini.ORIGINAL" "$FAKE/vendor/etc/ZYCustom.ini"
  echo OUTRO_MODELO_TP > "$T/projectname"
  e0="$(estado)"
  for cmd in apply revert; do
    fix "$cmd"
    afirma '[ "$RC" != 0 ] && [ "$(estado)" = "$e0" ] && [ "$(reboots)" = 0 ] && [ ! -d "$(BKD)" ]' "$cmd com projectname desconhecido e CONFIG_MODEL conhecido nao recusou limpo"
    afirma 'grep -q "modelo nao reconhecido" "$T/out.log"' "$cmd (projectname desconhecido): mensagem"
  done
  # ini diz antigo, propriedade diz sem USB-C
  cp "$ROOT/artifacts/ZYCustom.ini.ORIGINAL" "$FAKE/vendor/etc/ZYCustom.ini"
  echo KJM_5H039_412_INTELBRAS_NOTYPEC_TP > "$T/projectname"
  e0="$(estado)"
  for cmd in apply revert; do
    fix "$cmd"
    afirma '[ "$RC" != 0 ] && [ "$(estado)" = "$e0" ] && [ "$(reboots)" = 0 ] && [ ! -d "$(BKD)" ]' "$cmd com sinais contraditorios nao recusou limpo"
    afirma 'grep -q "sinais contraditorios" "$T/out.log"' "$cmd: mensagem"
  done
  limpa
}

c_novo_apply_idempotente(){
  novo_cenario novo "modelo sem USB-C: apply 2x deixa o mesmo estado"
  fix apply
  local e1; e1="$(estado)"
  fix apply
  afirma '[ "$RC" = 0 ] && [ "$(estado)" = "$e1" ]' "segundo apply mudou o aparelho (rc=$RC)"
  afirma '[ "$(md5 "$(BKD)/notypec/ZYCustom.ini.STOCK")" = $N_INI ]' "o backup foi sobrescrito pelo estado corrigido"
  limpa
}

c_install_bat_recusa_outro_modelo(){
  # install.bat (so texto: nao ha Windows aqui) grava o ini/build.prop do V1.0.0.9; no apply e no
  # revert so segue com o CONFIG_MODEL do V1.0.0.9, conferido depois do connect e ANTES de qualquer
  # escrita (backup/remount)
  CASO="install.bat recusa o modelo sem USB-C"
  local b="$ROOT/install.bat"
  afirma '[ "$(grep -c "CONFIG_MODEL \*= \*KJM_5H039_412;" "$b")" = 2 ]' "esperava a conferencia do CONFIG_MODEL no apply e no revert"
  # o CONFIG_MODEL sozinho nao basta: um aparelho sem USB-C que ja levou o ini do V1.0.0.9 (pelo
  # install.bat/fix.sh de antes do bloco 6) tem o CONFIG_MODEL rebaixado, e o revert lhe daria o
  # build.prop do V1.0.0.9. A mesma linha tem de conferir tambem o ro.newlink.projectname.
  afirma '[ "$(grep "CONFIG_MODEL \*= \*KJM_5H039_412;" "$b" | grep -c "getprop ro.newlink.projectname | grep -qx KJM_5H039_412_INTELBRAS_TP")" = 2 ]' "a conferencia do install.bat nao exige tambem o ro.newlink.projectname do V1.0.0.9"
  afirma 'awk '"'"'/^:do_apply/{a=1} /^:do_revert/{a=0} a&&/call :connect/{c=NR} a&&/CONFIG_MODEL \*=/{m=NR} a&&/call :backup_stock/{k=NR} END{exit !(c&&m&&k&&c<m&&m<k)}'"'"' "$b"' "apply: a conferencia do modelo nao esta entre o connect e o backup"
  afirma 'awk '"'"'/^:do_revert/{a=1} /^:no_bk/{a=0} a&&/call :connect/{c=NR} a&&/CONFIG_MODEL \*=/{m=NR} a&&/remount/{k=NR} END{exit !(c&&m&&k&&c<m&&m<k)}'"'"' "$b"' "revert: a conferencia do modelo nao esta entre o connect e o remount"
  afirma '[ "$(grep -c $'"'"'\r'"'"' "$b")" = 0 ]' "install.bat ganhou CRLF"
}

c_busca_por_mac(){
  novo_cenario antigo "PFL_MAC: o nmap acha o IP sem arquivo temporario de nome fixo"
  printf '#!/bin/sh\nexec "$@"\n' > "$T/bin/sudo"
  printf '#!/bin/sh\necho "Nmap scan report for 192.168.7.42"\necho "Host is up (0.0040s latency)."\necho "MAC Address: AA:BB:CC:DD:EE:FF (Newlink)"\n' > "$T/bin/nmap"
  chmod +x "$T/bin/sudo" "$T/bin/nmap"
  ( cd "$T/repo" && env -u PFL_IP PFL_MAC=aa:bb:cc:dd:ee:ff PFL_SUBNET=192.168.7.0/24 PATH="$T/bin:$PATH" bash ./pfl7560-fix.sh status ) > "$T/out.log" 2>&1
  afirma 'grep -q "adb connect 192.168.7.42:5555" "$T/adb.log"' "nao conectou no IP do nmap: $(head -3 "$T/adb.log" | tr '\n' '|')"
  afirma '! grep -q "/tmp/pfl\." "$ROOT/pfl7560-fix.sh"' "o pfl7560-fix.sh ainda grava a saida do nmap em /tmp/pfl.<pid>"
  limpa
}

echo "== pfl7560-fix.sh por modelo (adb de mentira) =="
for c in c_antigo_apply_revert c_novo_apply_revert c_novo_revert_com_backup_do_antigo \
         c_revert_backup_de_outro_modelo c_modelo_desconhecido c_novo_apply_idempotente c_install_bat_recusa_outro_modelo c_busca_por_mac; do
  echo "  $c"
  "$c"
done
echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
