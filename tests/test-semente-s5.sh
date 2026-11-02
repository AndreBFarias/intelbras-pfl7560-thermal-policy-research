#!/usr/bin/env bash
# test-semente-s5.sh - a suite nativa da build S5 (bloco 26, doc 47 s12).
#
# Monta um /vendor falso com o que o conteudo-s5.txt grava (ou, com PFL_S5_BIN=<.bin>, com o que
# o .bin de verdade traz no record 14), roda o comando do servico do pfl7560-suite.rc da S5 sob
# dash e confere a semente: 1o boot com o /data vazio, kit mais novo no /data, /vendor mais novo,
# copia interrompida, /vendor adulterado e pastas inseguras. O suite-boot.sh em si e testado pelo
# test-suite.sh; aqui o "sh" que a semente chama e um stub que registra QUAL suite-boot.sh rodou.
# shellcheck disable=SC2016
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/pendrive-autorun"
S5="$ROOT/artifacts/bin-build/s5"
MAN="$ROOT/artifacts/bin-build/conteudo-s5.txt"
MAN_S4B="$ROOT/artifacts/bin-build/conteudo.txt"

FALHAS=0
TESTES=0
CASO=""
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }
stub(){ printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }

LISTA="$(sed -n '/^SEMENTE_LISTA="/,/^"$/p' "$S5/suite-semente.sh" | sed 's/^SEMENTE_LISTA="//' | grep -E '^[0-9a-f]{32}  ')"
NOMES="$(printf '%s\n' "$LISTA" | sed 's/^[0-9a-f]*  //')"
EXEC="$(sed -n 's/^EXEC_LISTA="\(.*\)"$/\1/p' "$S5/suite-semente.sh")"
md5_lista(){ printf '%s\n' "$LISTA" | sed -n "s|^\\([0-9a-f]*\\)  $1\$|\\1|p"; }

# Vendor real do .bin (PFL_S5_BIN), extraido uma vez para build-s5/ (ignorado pelo git)
VENDOR_RAW=""
if [ -n "${PFL_S5_BIN:-}" ]; then
  VENDOR_RAW="$(mktemp -d)/vendor.raw"
  python3 -I - "$ROOT/artifacts/bin-build" "$PFL_S5_BIN" "$VENDOR_RAW" <<'PY' || { echo "nao consegui extrair o vendor de $PFL_S5_BIN"; exit 1; }
import struct, sys
sys.path.insert(0, sys.argv[1])
import sparse
b, raw = sys.argv[2], sys.argv[3]
with open(b, 'rb') as f:
    f.seek(0x40 + 32 * 14 + 0x14)
    tam, off = struct.unpack('>II', f.read(8))
    f.seek(off + 8)
    open(raw + '.sp', 'wb').write(f.read(tam))
sparse.expand(raw + '.sp', raw)
PY
  rm -f "$VENDOR_RAW.sp"
  echo "  (vendor do .bin real: $PFL_S5_BIN)"
fi

# poe no $R/vendor o que o manifesto grava sob /vendor/etc/pfl7560-suite e o .rc da S5
monta_vendor(){
  local o d m
  if [ -n "$VENDOR_RAW" ]; then
    mkdir -p "$R/vendor/etc/init"
    debugfs -R "rdump /etc/pfl7560-suite $R/vendor/etc" "$VENDOR_RAW" >/dev/null 2>&1
    debugfs -R "dump /etc/init/pfl7560-suite.rc $R/vendor/etc/init/pfl7560-suite.rc" "$VENDOR_RAW" >/dev/null 2>&1
    chmod -R u+w "$R/vendor"
    return
  fi
  while read -r o d m _; do
    case "$d" in /vendor/etc/pfl7560-suite*|/vendor/etc/init/pfl7560-suite.rc) ;; *) continue ;; esac
    if [ "$o" = "-" ]; then mkdir -p "$R$d"; chmod "$m" "$R$d"
    else mkdir -p "$(dirname "$R$d")"; cp "$ROOT/$o" "$R$d"; chmod "$m" "$R$d"; fi
  done < <(sed 's/#.*//' "$MAN" | grep -v '^prop ' | grep .)
}

novo_cenario(){
  CASO="$1"
  T="$(mktemp -d)"
  R="$T/root"; S="$R/data/vendor/pfl7560-suite"
  mkdir -p "$R/vendor/bin" "$R/data/vendor" "$T/bin"
  : > "$T/calls.log"
  monta_vendor
  stub setprop 'echo "setprop $*" >> "$T/calls.log"'
  stub sh 'echo "BOOT $1 $(md5sum "$1" | cut -d" " -f1)" >> "$T/calls.log"'
  export T
}
limpa(){ chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"; }

# o comando do servico do .rc, com /vendor no root falso, sob dash
roda(){
  local cmd
  cmd="$(sed -n 's/^service pfl7560_suite \/vendor\/bin\/sh \(\/vendor\/[^ ]*\)$/\1/p' "$R/vendor/etc/init/pfl7560-suite.rc")"
  env PFL_TESTE=1 PFL_DONO="$(id -u)" PFL_ROOT="$R" PATH="$T/bin:$PATH" dash "$R$cmd" > "$T/out.log" 2>&1
  RC=$?
}
estado(){ grep '^setprop vendor.pfl7560.semente ' "$T/calls.log" | tail -1 | cut -d' ' -f3; }
boot_md5(){ grep "^BOOT $S/suite-boot.sh " "$T/calls.log" | tail -1 | cut -d' ' -f3; }
suite_igual_lista(){
  local n
  for n in $NOMES; do
    [ -f "$S/$n" ] && [ ! -L "$S/$n" ] && [ "$(md5 "$S/$n")" = "$(md5_lista "$n")" ] || return 1
  done
}
modos_ok(){
  local n m
  for n in $NOMES; do
    m=0600; case " $EXEC " in *" $n "*) m=0755 ;; esac
    [ "$(stat -c %a "$S/$n")" = "${m#0}" ] || { echo "$n: $(stat -c %a "$S/$n") != $m"; return 1; }
  done
  for n in "$S" "$S/kit" "$S/fontes" "$S/marca"; do
    [ "$(stat -c %a "$n")" = 700 ] || { echo "$n: $(stat -c %a "$n")"; return 1; }
  done
}
estampa(){ ( cd "$S" && find . -type f ! -name semente.log -printf '%p %i %Y\n' | sort ); }
kit_no_data(){
  # o que o kit deixa no /data ao instalar ou atualizar a suite (sem semente.lista)
  local n
  mkdir -p "$S"; chmod 700 "$S"
  for n in $NOMES; do mkdir -p "$S/$(dirname "$n")"; chmod 700 "$S/$(dirname "$n")"; cp "$KIT/$n" "$S/$n"; done
  printf '\n# suite-boot.sh de um kit mais novo\n' >> "$S/suite-boot.sh"
}

echo "== estaticos =="
CASO="estaticos"
afirma 'LC_ALL=C grep -qvP "^[\x00-\x7f]*$" "$S5/suite-semente.sh" "$S5/pfl7560-suite.rc"; [ $? = 1 ]' "semente ou .rc da S5 fora do ASCII puro"
if command -v shellcheck >/dev/null; then
  afirma 'shellcheck -s sh "$S5/suite-semente.sh"' "shellcheck -s sh da semente nao esta limpo"
fi
afirma 'bash "$ROOT/tests/atualizar-md5-kit.sh" --check >/dev/null' "SEMENTE_LISTA ou RC_S5_MD5 desatualizados (rode tests/atualizar-md5-kit.sh)"
afirma '[ "$(sed -n "s/^RC_S5_MD5=\"\([0-9a-f]*\)\"$/\1/p" "$KIT/newlink_update.sh")" = "$(md5 "$S5/pfl7560-suite.rc")" ]' "RC_S5_MD5 do kit difere do .rc da S5"
afirma 'grep -qx "service pfl7560_suite /vendor/bin/sh /vendor/etc/pfl7560-suite/suite-semente.sh" "$S5/pfl7560-suite.rc"' ".rc da S5 nao roda a semente do /vendor"
afirma 'grep -qx "on property:sys.boot_completed=1" "$S5/pfl7560-suite.rc" && grep -qx "    seclabel u:r:vendor_shell:s0" "$S5/pfl7560-suite.rc" && grep -qx "    seclabel u:r:vendor_shell:s0" "$KIT/pfl7560-suite.rc"' "gatilho ou dominio do .rc da S5 difere do do kit"
# a lista da semente e a suite_nomes do kit (KIT_LISTA menos o que nao vai para o /data)
KIT_SUITE="$(sed -n '/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p' "$KIT/newlink_update.sh" | grep -oE '[0-9a-f]{32}  [^"]+$' \
  | grep -v -e '  ZYCustom.ini$' -e '  pfl7560-suite.rc$' -e '  pfl7560.apk$' -e '  pfl7560-home.apk$' -e '  overlay/' -e '  marca/bootanimation.zip$')"
afirma '[ "$LISTA" = "$KIT_SUITE" ]' "SEMENTE_LISTA difere da suite que o kit instala"
# os executaveis: a semente da 0755 so ao que esta no EXEC_LISTA; um executavel novo no KIT_EXEC sem par aqui
# sairia 0600 no /data e a suite nao o rodaria
afirma '[ -n "$EXEC" ] && [ "$EXEC" = "$(sed -n "s/^KIT_EXEC=\"\(.*\)\"$/\1/p" "$KIT/newlink_update.sh")" ]' "EXEC_LISTA da semente difere do KIT_EXEC do kit"
for n in $NOMES; do
  afirma '[ "$(md5 "$KIT/$n")" = "$(md5_lista "$n")" ]' "$n: md5 do kit difere da SEMENTE_LISTA"
done
# o manifesto da S5: o da S4b (menos o .rc) + a suite + as 2 props
ENT_S5="$(sed 's/#.*//' "$MAN" | grep . | tr -s ' ' | sed 's/ $//')"
ENT_S4B="$(sed 's/#.*//' "$MAN_S4B" | grep . | tr -s ' ' | sed 's/ $//')"
afirma '[ -z "$(comm -23 <(printf "%s\n" "$ENT_S4B" | grep -v pfl7560-suite.rc | sort) <(printf "%s\n" "$ENT_S5" | sort))" ]' "conteudo-s5.txt perdeu linhas do conteudo.txt: $(comm -23 <(printf "%s\n" "$ENT_S4B" | grep -v pfl7560-suite.rc | sort) <(printf "%s\n" "$ENT_S5" | sort) | head -2)"
afirma 'printf "%s\n" "$ENT_S5" | grep -qx "artifacts/bin-build/s5/pfl7560-suite.rc /vendor/etc/init/pfl7560-suite.rc 0644 0 0 u:object_r:vendor_configs_file:s0"' "o .rc do manifesto da S5 nao e o da S5 com os metadados do stock"
SUITE_MAN="$(printf '%s\n' "$ENT_S5" | sed -n 's|^pendrive-autorun/\([^ ]*\) /vendor/etc/pfl7560-suite/\([^ ]*\) 0644 0 0 u:object_r:vendor_configs_file:s0$|\1 \2|p')"
afirma '[ "$(printf "%s\n" "$SUITE_MAN" | cut -d" " -f1)" = "$NOMES" ] && [ "$(printf "%s\n" "$SUITE_MAN" | cut -d" " -f2)" = "$NOMES" ]' "a suite do manifesto nao e a SEMENTE_LISTA (mesma ordem, 0644 root:root vendor_configs_file)"
afirma '[ "$(printf "%s\n" "$ENT_S5" | grep -c "/vendor/etc/pfl7560-suite")" = "$(( $(printf "%s\n" "$NOMES" | wc -l) + 1 + 4 ))" ]' "manifesto com entradas a mais ou a menos em /vendor/etc/pfl7560-suite"
afirma 'printf "%s\n" "$ENT_S5" | grep -qx "artifacts/bin-build/s5/suite-semente.sh /vendor/etc/pfl7560-suite/suite-semente.sh 0644 0 0 u:object_r:vendor_configs_file:s0"' "a semente fora do manifesto"
for d in "" /fontes /kit /marca; do
  afirma 'printf "%s\n" "$ENT_S5" | grep -qx -- "- /vendor/etc/pfl7560-suite$d 0755 0 2000 u:object_r:vendor_configs_file:s0"' "pasta /vendor/etc/pfl7560-suite$d sem os metadados de /vendor/etc do stock"
done
afirma '[ "$(printf "%s\n" "$ENT_S5" | grep "^prop ")" = "$(printf "prop %s\nprop %s" "$(sed -n "s/^HOME_LINHA=\"\(.*\)\"$/\1/p" "$KIT/newlink_update.sh")" "$(sed -n "s/^FM_LINHA=\"\(.*\)\"$/\1/p" "$KIT/newlink_update.sh")")" ]' "as props do manifesto nao sao as HOME_LINHA e FM_LINHA do kit"
afirma 'git -C "$ROOT" check-attr byte-exact -- artifacts/bin-build/s5/suite-semente.sh artifacts/bin-build/s5/pfl7560-suite.rc | grep -c "byte-exact: set" | grep -qx 2' "s5/ fora do byte-exact no .gitattributes"

echo "== cenarios (dash) =="
novo_cenario "1o boot: /data vazio = suite copiada e conferida, pastas so do root, passa a vez"
rmdir "$R/data/vendor"
roda
afirma '[ "$RC" = 0 ] && [ "$(estado)" = copiada ]' "rc=$RC estado=$(estado): $(tail -3 "$S/semente.log" 2>/dev/null | tr '\n' '|')"
afirma 'suite_igual_lista' "a suite no /data nao confere com a SEMENTE_LISTA"
afirma 'modos_ok >/dev/null' "modos: $(modos_ok)"
afirma '[ "$(boot_md5)" = "$(md5_lista suite-boot.sh)" ]' "nao passou a vez ao suite-boot.sh copiado: $(grep ^BOOT "$T/calls.log")"
afirma '[ "$(cat "$S/semente.lista")" = "$LISTA" ] && [ ! -e "$S/semente.preparo" ]' "semente.lista errada ou sobrou o preparo"
afirma 'grep -q "acao=copiar motivo=data_sem_suite" "$S/semente.log" && grep -q "\[OK\] suite copiada do /vendor e conferida: 28 arquivos" "$S/semente.log"' "log: $(tr '\n' '|' < "$S/semente.log")"
E1="$(estampa)"
: > "$T/calls.log"; roda
afirma '[ "$RC" = 0 ] && [ "$(estado)" = em_dia ] && [ "$(estampa)" = "$E1" ] && [ "$(boot_md5)" = "$(md5_lista suite-boot.sh)" ]' "2o boot regravou ou nao passou a vez (estado=$(estado))"
limpa

novo_cenario "kit mais novo no /data (sem semente.lista) = o /data vence, nada copiado"
kit_no_data
K="$(md5 "$S/suite-boot.sh")"; E1="$(estampa)"
roda
afirma '[ "$RC" = 0 ] && [ "$(estado)" = data_vence ] && [ "$(estampa)" = "$E1" ]' "estado=$(estado); a semente mexeu no /data do kit"
afirma '[ "$(boot_md5)" = "$K" ] && [ ! -e "$S/semente.lista" ]' "nao rodou o suite-boot.sh do kit: $(grep ^BOOT "$T/calls.log")"
limpa

novo_cenario "kit atualizou a suite depois da semente (semente.lista nao confere) = o /data vence"
roda
printf '\n# suite.sh de um kit mais novo\n' >> "$S/suite.sh"
E1="$(estampa)"; : > "$T/calls.log"; roda
afirma '[ "$(estado)" = data_vence ] && [ "$(estampa)" = "$E1" ] && [ "$(boot_md5)" = "$(md5_lista suite-boot.sh)" ]' "estado=$(estado); a semente desfez o kit"
limpa

novo_cenario "semente pura de um /vendor antigo (firmware novo gravado por cima do /data) = copia de novo"
roda
printf '\n# versao antiga\n' >> "$S/suite.sh"
sed -i "s|^[0-9a-f]*  suite.sh\$|$(md5 "$S/suite.sh")  suite.sh|" "$S/semente.lista"
: > "$T/calls.log"; roda
afirma '[ "$RC" = 0 ] && [ "$(estado)" = copiada ] && suite_igual_lista && [ "$(cat "$S/semente.lista")" = "$LISTA" ]' "estado=$(estado); nao trocou a semente antiga"
afirma 'grep -q "motivo=vendor_mais_novo" "$S/semente.log"' "log sem o motivo"
limpa

novo_cenario "copia interrompida (sem suite-boot.sh, arquivo pela metade, preparo sobrando) = copia inteira"
roda
rm -f "$S/suite-boot.sh"; head -c 100 "$R/vendor/etc/pfl7560-suite/fontes/OFL.txt" > "$S/fontes/OFL.txt"
mkdir -p "$S/semente.preparo/lixo"
: > "$T/calls.log"; roda
afirma '[ "$RC" = 0 ] && [ "$(estado)" = copiada ] && suite_igual_lista && [ ! -e "$S/semente.preparo" ]' "estado=$(estado); a copia interrompida nao foi refeita"
limpa

novo_cenario "/vendor adulterado = nada copiado, nada roda"
rmdir "$R/data/vendor"
chmod u+w "$R/vendor/etc/pfl7560-suite/suite.sh"; echo "# adulterado" >> "$R/vendor/etc/pfl7560-suite/suite.sh"
roda
afirma '[ "$RC" != 0 ] && [ "$(estado)" = erro_copia ] && [ ! -e "$S/suite-boot.sh" ] && [ ! -e "$S/suite.sh" ] && [ ! -e "$S/semente.preparo" ]' "rc=$RC estado=$(estado); copiou do /vendor adulterado: $(ls "$S" | tr '\n' ' ')"
afirma '! grep -q "^BOOT" "$T/calls.log" && grep -q "nao confere com a lista da semente" "$S/semente.log"' "rodou algo ou sem o log do erro"
limpa

novo_cenario "/data/vendor/pfl7560-suite e link = nada feito"
mkdir "$T/alvo"; chmod 700 "$T/alvo"; ln -s "$T/alvo" "$S"
roda
afirma '[ "$RC" != 0 ] && [ "$(estado)" = erro_pasta ] && [ -z "$(ls -A "$T/alvo")" ] && ! grep -q "^BOOT" "$T/calls.log"' "rc=$RC estado=$(estado); escreveu pelo link: $(ls -A "$T/alvo" | tr '\n' ' ')"
limpa

novo_cenario "/data/vendor/pfl7560-suite aberta a outros (0755) = nada feito"
mkdir -p "$S"; chmod 755 "$S"
roda
afirma '[ "$RC" != 0 ] && [ "$(estado)" = erro_pasta ] && [ -z "$(ls -A "$S")" ]' "rc=$RC estado=$(estado)"
limpa

novo_cenario "subpasta kit/ e link = nada posto no lugar, nada escrito pelo link"
mkdir -p "$S" "$T/alvo"; chmod 700 "$S" "$T/alvo"; ln -s "$T/alvo" "$S/kit"
roda
afirma '[ "$RC" != 0 ] && [ "$(estado)" = erro_copia ] && [ -z "$(ls -A "$T/alvo")" ] && [ ! -e "$S/suite-boot.sh" ]' "rc=$RC estado=$(estado); $(ls -A "$T/alvo" | tr '\n' ' ')"
limpa

novo_cenario "suite-boot.sh do /data e link = tratado como ausente, copia por cima"
mkdir -p "$S"; chmod 700 "$S"; echo 'touch "$T/link-rodou"' > "$T/falso.sh"; ln -s "$T/falso.sh" "$S/suite-boot.sh"
roda
afirma '[ "$(estado)" = copiada ] && [ ! -L "$S/suite-boot.sh" ] && [ "$(boot_md5)" = "$(md5_lista suite-boot.sh)" ] && [ "$(cat "$T/falso.sh")" = "touch \"\$T/link-rodou\"" ]' "estado=$(estado); seguiu o link"
limpa

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ -n "$VENDOR_RAW" ] && rm -rf "$(dirname "$VENDOR_RAW")"
[ "$FALHAS" = 0 ]
