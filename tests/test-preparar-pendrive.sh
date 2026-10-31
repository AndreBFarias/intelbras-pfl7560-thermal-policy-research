#!/usr/bin/env bash
# tests/test-preparar-pendrive.sh - bloco 9C (C2): install.sh --pendrive ... --com-firmware e
# tests/preparar-pendrive.sh, SEM tocar em disco nenhum: lsblk, mkfs.vfat, mount, umount e df de
# mentira no PATH; .bin falsos pequenos, com o md5 esperado injetado pelas variaveis de teste
# (so valem com PFL_TESTE=1). O firmware de verdade (1,3 GB) nao e lido aqui.
#
#   bash tests/test-preparar-pendrive.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export LC_ALL=C
FALHAS=0; TESTES=0; CASO="-"
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
NOSSO_BIN="PFL7560-COMPLETO-NAO-GRADUADO.bin"

# ---- firmware falso ------------------------------------------------------------------
fw_falso(){ # $1 = pasta; cria o zip oficial falso e o nosso .bin falso; exporta os md5
  local d="$1"
  mkdir -p "$d/z/Software PFL7560"
  head -c 300000 /dev/urandom > "$d/z/Software PFL7560/PFL7560.bin"
  ( cd "$d/z" && zip -q -r "$d/Software PFL7560.zip" "Software PFL7560" )
  head -c 120000 /dev/urandom > "$d/$NOSSO_BIN"
  OFICIAL_MD5="$(md5 "$d/z/Software PFL7560/PFL7560.bin")"
  NOSSO_MD5="$(md5 "$d/$NOSSO_BIN")"
  rm -rf "$d/z"
}
arquivos(){ find "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }

# ===========================================================================================
echo "== install.sh --pendrive --com-firmware =="
FW="$TMP/fw"; mkdir -p "$FW"; fw_falso "$FW"
instala(){ # $1 = destino; resto = args extras; o ambiente de teste vem das variaveis do caso
  env PFL_TESTE=1 PFL_FIRMWARE_DIR="${FWDIR:-$FW}" PFL_FW_OFICIAL_MD5="${OFMD5:-$OFICIAL_MD5}" PFL_FW_NOSSO_MD5="${NSMD5:-$NOSSO_MD5}" \
      PATH="${PATH_EXTRA:+$PATH_EXTRA:}$PATH" bash "$ROOT/install.sh" --pendrive "$@" > "$TMP/saida.log" 2>&1
}

CASO="com firmware: tudo certo"
D="$TMP/d1"; mkdir -p "$D"
instala "$D" --com-firmware; RC=$?
afirma '[ "$RC" = 0 ]' "install.sh saiu $RC: $(tail -3 "$TMP/saida.log" | tr '\n' ' ')"
afirma '[ "$(md5 "$D/usb_update.bin")" = "$NOSSO_MD5" ]' "usb_update.bin na raiz nao e o nosso .bin"
afirma '[ "$(md5 "$D/resgate-oficial/PFL7560.bin")" = "$OFICIAL_MD5" ]' "resgate-oficial/PFL7560.bin nao e o .bin do zip oficial"
afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$D/resgate-oficial/LEIA-ME.txt")" ] && [ "$(grep -c $'"'"'\r'"'"' "$D/resgate-oficial/LEIA-ME.txt")" = 0 ]' "LEIA-ME do resgate falta, tem byte fora de ASCII ou CRLF"
afirma 'grep -q "28a2f280eee313a4b115567926b2ba4f" "$D/resgate-oficial/LEIA-ME.txt" && grep -q "usb_update.bin" "$D/resgate-oficial/LEIA-ME.txt" && grep -q "SEGURANDO O POWER" "$D/resgate-oficial/LEIA-ME.txt" && grep -q "Firmware PFL7560.zip" "$D/resgate-oficial/LEIA-ME.txt"' "LEIA-ME do resgate sem o md5, o nome usb_update.bin, o power-hold ou o aviso do modelo sem USB-C"
afirma '[ ! -e "$D/$NOSSO_BIN" ] && [ "$(find "$D" -name "usb_update.bin" | wc -l | tr -d " ")" = 1 ] && [ ! -e "$D/firmware-nosso-NAO-GRADUADO" ]' "o .bin com o nome original na raiz, mais de um usb_update.bin ou a pasta antiga"
afirma '[ -z "$(find "$D" -name "*.copiando")" ]' "sobrou arquivo temporario"
afirma 'cmp -s "$ROOT/pendrive-autorun/newlink_update.sh" "$D/newlink_update.sh" && cmp -s "$ROOT/pendrive-autorun/pfl7560.apk" "$D/pfl7560.apk"' "o kit nao foi copiado junto"
afirma 'grep -q "REFLASHA" "$TMP/saida.log"' "sem o aviso do risco de ligar segurando o power"

CASO="sem --com-firmware: nem usb_update.bin nem resgate"
D="$TMP/d2"; mkdir -p "$D"
instala "$D"; RC=$?
afirma '[ "$RC" = 0 ] && [ ! -e "$D/usb_update.bin" ] && [ ! -e "$D/resgate-oficial" ]' "rc=$RC; firmware foi sem pedir"
afirma '[ -f "$D/newlink_update.sh" ]' "kit nao copiado"

CASO="pendrive do arranjo antigo (oficial na raiz, nosso na pasta) com --com-firmware: troca e tira a pasta antiga"
D="$TMP/d2b"; mkdir -p "$D/firmware-nosso-NAO-GRADUADO"; echo velho > "$D/usb_update.bin"; echo velho > "$D/firmware-nosso-NAO-GRADUADO/x.bin"
instala "$D" --com-firmware; RC=$?
afirma '[ "$RC" = 0 ] && [ "$(md5 "$D/usb_update.bin")" = "$NOSSO_MD5" ] && [ ! -e "$D/firmware-nosso-NAO-GRADUADO" ] && [ "$(md5 "$D/resgate-oficial/PFL7560.bin")" = "$OFICIAL_MD5" ]' "rc=$RC: $(find "$D" -name "*.bin" | tr '\n' ' ')"

sem_kit(){ # $1 = destino  $2 = trecho esperado na mensagem; o que ja estava no pendrive fica, o kit nao vai
  SK_D="$1"; SK_T="$2"
  afirma '[ "$RC" != 0 ]' "install.sh deveria recusar"
  afirma '[ ! -e "$SK_D/newlink_update.sh" ] && [ ! -e "$SK_D/kit" ]' "copiou o kit mesmo assim em $SK_D"
  afirma 'grep -qF -- "$SK_T" "$TMP/saida.log"' "mensagem sem '$SK_T': $(grep ERRO "$TMP/saida.log" | head -2 | tr '\n' ' ')"
}

CASO="pendrive com DESINSTALAR-SUITE.txt: recusa (plugado, ele desinstalaria a suite)"
D="$TMP/d2c"; mkdir -p "$D"; : > "$D/DESINSTALAR-SUITE.txt"
instala "$D"; RC=$?
sem_kit "$D" "DESINSTALAR-SUITE.txt"
afirma '[ -e "$D/DESINSTALAR-SUITE.txt" ]' "apagou o arquivo do dono"
D="$TMP/d2d"; mkdir -p "$D"; : > "$D/DESINSTALAR-SUITE.txt"
instala "$D" --com-firmware; RC=$?
sem_kit "$D" "DESINSTALAR-SUITE.txt"
afirma '[ ! -e "$D/usb_update.bin" ] && [ ! -e "$D/resgate-oficial" ]' "copiou o firmware num pendrive recusado"

CASO="pendrive com usb_update.bin, sem --com-firmware: recusa (power-hold regravaria com um .bin nao conferido)"
D="$TMP/d2e"; mkdir -p "$D"; echo qualquer > "$D/usb_update.bin"
instala "$D"; RC=$?
sem_kit "$D" "usb_update.bin"
afirma '[ "$(cat "$D/usb_update.bin")" = qualquer ]' "mexeu no usb_update.bin do dono"

nada_copiado(){ # $1 = destino  $2 = trecho esperado na mensagem (globais: o afirma usa eval)
  NC_D="$1"; NC_T="$2"
  afirma '[ "$RC" != 0 ]' "install.sh deveria falhar"
  afirma '[ "$(arquivos "$NC_D")" = 0 ] && [ -z "$(ls -A "$NC_D")" ]' "copiou pela metade: $(ls -A "$NC_D" | tr '\n' ' ')"
  afirma 'grep -qF -- "$NC_T" "$TMP/saida.log"' "mensagem sem '$NC_T': $(grep ERRO "$TMP/saida.log" | head -2 | tr '\n' ' ')"
}

CASO="zip oficial ausente"
D="$TMP/d3"; mkdir -p "$D"; F="$TMP/fw3"; mkdir -p "$F"
cp "$FW/$NOSSO_BIN" "$F/"
FWDIR="$F" instala "$D" --com-firmware; RC=$?
nada_copiado "$D" "Software PFL7560.zip"

CASO="so o zip do modelo sem USB-C (Firmware PFL7560.zip) nao serve"
D="$TMP/d4"; mkdir -p "$D"; F4="$TMP/fw4"; mkdir -p "$F4"
cp "$FW/$NOSSO_BIN" "$F4/"; cp "$FW/Software PFL7560.zip" "$F4/Firmware PFL7560.zip"
FWDIR="$F4" instala "$D" --com-firmware; RC=$?
nada_copiado "$D" "NAO use o 'Firmware PFL7560.zip'"

CASO="md5 do .bin oficial diferente do esperado"
D="$TMP/d5"; mkdir -p "$D"
OFMD5="00000000000000000000000000000000" instala "$D" --com-firmware; RC=$?
nada_copiado "$D" "esperado e 00000000000000000000000000000000"

CASO="nosso .bin ausente"
D="$TMP/d6"; mkdir -p "$D"; F="$TMP/fw6"; mkdir -p "$F"
cp "$FW/Software PFL7560.zip" "$F/"
FWDIR="$F" instala "$D" --com-firmware; RC=$?
nada_copiado "$D" "falta '$F/$NOSSO_BIN'"

CASO="nosso .bin com md5 diferente"
D="$TMP/d7"; mkdir -p "$D"
NSMD5="11111111111111111111111111111111" instala "$D" --com-firmware; RC=$?
nada_copiado "$D" "esperado e 11111111111111111111111111111111"

CASO="zip com dois PFL7560.bin"
D="$TMP/d9"; mkdir -p "$D"; F="$TMP/fw9"; mkdir -p "$F" "$TMP/z9/a" "$TMP/z9/b"
cp "$FW/$NOSSO_BIN" "$F/"
head -c 1000 /dev/urandom > "$TMP/z9/a/PFL7560.bin"; head -c 1000 /dev/urandom > "$TMP/z9/b/PFL7560.bin"
( cd "$TMP/z9" && zip -q -r "$F/Software PFL7560.zip" a b )
FWDIR="$F" instala "$D" --com-firmware; RC=$?
nada_copiado "$D" "exatamente um PFL7560.bin"

CASO="md5 de teste ignorado fora do PFL_TESTE"
D="$TMP/d10"; mkdir -p "$D"
env PFL_FIRMWARE_DIR="$FW" PFL_FW_OFICIAL_MD5="$OFICIAL_MD5" PFL_FW_NOSSO_MD5="$NOSSO_MD5" bash "$ROOT/install.sh" --pendrive "$D" --com-firmware > "$TMP/saida.log" 2>&1; RC=$?
nada_copiado "$D" "esperado e 28a2f280eee313a4b115567926b2ba4f"

CASO="pouco espaco no pendrive"
D="$TMP/d11"; mkdir -p "$D"; mkdir -p "$TMP/bin-df"
printf '#!/bin/sh\necho "Filesystem 1024-blocks Used Available Capacity Mounted"\necho "/dev/x 1000 900 100 90%% /mnt"\n' > "$TMP/bin-df/df"; chmod +x "$TMP/bin-df/df"
PATH_EXTRA="$TMP/bin-df" instala "$D" --com-firmware; RC=$?
nada_copiado "$D" "pouco espaco"

CASO="pasta de firmware padrao do repo (sem PFL_FIRMWARE_DIR): sem o nosso .bin, falha antes de copiar"
D="$TMP/d12"; mkdir -p "$D"
if [ -e "$ROOT/firmware/$NOSSO_BIN" ]; then
  echo "  (o nosso .bin existe em firmware/: caso pulado para nao copiar 1,4 GB)"
else
  env bash "$ROOT/install.sh" --pendrive "$D" --com-firmware > "$TMP/saida.log" 2>&1; RC=$?
  nada_copiado "$D" "$ROOT/firmware/$NOSSO_BIN"
fi

CASO="--conferir-firmware: so confere as origens (o preparar-pendrive.sh usa antes de formatar)"
D="$TMP/d13"; mkdir -p "$D"
env PFL_TESTE=1 PFL_FIRMWARE_DIR="$FW" PFL_FW_OFICIAL_MD5="$OFICIAL_MD5" PFL_FW_NOSSO_MD5="$NOSSO_MD5" bash "$ROOT/install.sh" --conferir-firmware > "$TMP/saida.log" 2>&1; RC=$?
afirma '[ "$RC" = 0 ] && grep -q "conferidos" "$TMP/saida.log"' "rc=$RC: $(tail -3 "$TMP/saida.log" | tr '\n' ' ')"
env PFL_TESTE=1 PFL_FIRMWARE_DIR="$FW" PFL_FW_OFICIAL_MD5="00000000000000000000000000000000" PFL_FW_NOSSO_MD5="$NOSSO_MD5" bash "$ROOT/install.sh" --conferir-firmware > "$TMP/saida.log" 2>&1; RC=$?
afirma '[ "$RC" != 0 ] && grep -q "esperado e 00000000000000000000000000000000" "$TMP/saida.log"' "md5 oficial errado passou: rc=$RC"
env PFL_TESTE=1 PFL_FIRMWARE_DIR="$FW" PFL_FW_OFICIAL_MD5="$OFICIAL_MD5" PFL_FW_NOSSO_MD5="11111111111111111111111111111111" bash "$ROOT/install.sh" --conferir-firmware > "$TMP/saida.log" 2>&1; RC=$?
afirma '[ "$RC" != 0 ] && grep -q "esperado e 11111111111111111111111111111111" "$TMP/saida.log"' "md5 do nosso errado passou: rc=$RC"
afirma '! bash "$ROOT/install.sh" --conferir-firmware --pendrive "$D" >/dev/null 2>&1 && [ -z "$(ls -A "$D")" ]' "aceitou --conferir-firmware junto com --pendrive"

CASO="argumentos"
afirma '! bash "$ROOT/install.sh" --com-firmware >/dev/null 2>&1' "aceitou --com-firmware sem --pendrive"
afirma '! bash "$ROOT/install.sh" --pendrive --com-firmware >/dev/null 2>&1' "aceitou --com-firmware como destino"
afirma '! bash "$ROOT/install.sh" --pendrive "$TMP/nao-existe" --com-firmware >/dev/null 2>&1' "aceitou destino inexistente"

# ===========================================================================================
echo "== tests/preparar-pendrive.sh =="
BIN="$TMP/bin"; mkdir -p "$BIN"
cat > "$BIN/lsblk" <<'EOF'
#!/bin/sh
echo "lsblk $*" >> "$T/calls.log"
for a; do last="$a"; done
case "$*" in
  *"-dnP"*) f="$T/lsblk-$(basename "$last").txt"; [ -f "$f" ] && cat "$f"; exit 0 ;;
  *"MOUNTPOINT"*) cat "$T/lsblk-mont.txt" 2>/dev/null; exit 0 ;;
esac
exit 1
EOF
cat > "$BIN/mkfs.vfat" <<'EOF'
#!/bin/sh
echo "mkfs.vfat $*" >> "$T/calls.log"
EOF
cat > "$BIN/mount" <<'EOF'
#!/bin/sh
echo "mount $*" >> "$T/calls.log"
EOF
cat > "$BIN/umount" <<'EOF'
#!/bin/sh
echo "umount $*" >> "$T/calls.log"
# guarda uma copia do que estava no "pendrive" (a pasta de montagem) para o teste olhar
[ -d "$1" ] && [ "$1" != "${1#/tmp}" ] && [ ! -d "$T/snapshot" ] && cp -r "$1" "$T/snapshot" 2>/dev/null
exit 0
EOF
chmod +x "$BIN"/*

prepara(){ # $1.. = argumentos do preparar-pendrive.sh; confirmacao vem de $CONFIRMA; usa $TMP/p como T
  rm -rf "$TMP/p"; mkdir -p "$TMP/p"; : > "$TMP/p/calls.log"
  [ -n "${LINHA_DEV:-}" ] && printf '%s\n' "$LINHA_DEV" > "$TMP/p/lsblk-$(basename "${1:-x}").txt"
  [ -n "${LINHA_PAI:-}" ] && printf '%s\n' "$LINHA_PAI" > "$TMP/p/lsblk-${PAI_NOME:-sdb}.txt"
  printf '%s' "${MONTAGENS:-}" > "$TMP/p/lsblk-mont.txt"
  printf '%s\n' "${CONFIRMA:-}" | env T="$TMP/p" PFL_TESTE="${TESTE_ON:-1}" PFL_FIRMWARE_DIR="${FWDIR:-$FW}" PFL_FW_OFICIAL_MD5="${OFMD5:-$OFICIAL_MD5}" PFL_FW_NOSSO_MD5="${NSMD5:-$NOSSO_MD5}" \
      PATH="$BIN:$PATH" bash "$ROOT/tests/preparar-pendrive.sh" "$@" > "$TMP/p/saida.log" 2>&1
  RC=$?
}
mkfs_chamadas(){ grep -c '^mkfs.vfat' "$TMP/p/calls.log" 2>/dev/null || true; }
L_USB='NAME="sdb" RM="1" TRAN="usb" TYPE="disk" MODEL="Cruzer Blade" SIZE="14,5G" PKNAME=""'

CASO="recusa: disco fixo (RM=0, sata)"
LINHA_DEV='NAME="sda" RM="0" TRAN="sata" TYPE="disk" MODEL="Samsung SSD 860" SIZE="465,8G" PKNAME=""' CONFIRMA=/dev/sda prepara /dev/sda
afirma '[ "$RC" = 3 ] && [ "$(mkfs_chamadas)" = 0 ] && grep -q "RECUSADO" "$TMP/p/saida.log"' "rc=$RC mkfs=$(mkfs_chamadas): $(tail -2 "$TMP/p/saida.log" | tr '\n' ' ')"
afirma '! grep -q "^mount\|^umount" "$TMP/p/calls.log"' "montou ou desmontou um disco recusado"

CASO="recusa: removivel mas nao USB"
LINHA_DEV='NAME="mmcblk0" RM="1" TRAN="" TYPE="disk" MODEL="" SIZE="29,7G" PKNAME=""' CONFIRMA=/dev/mmcblk0 prepara /dev/mmcblk0
afirma '[ "$RC" = 3 ] && [ "$(mkfs_chamadas)" = 0 ]' "rc=$RC mkfs=$(mkfs_chamadas)"

CASO="recusa: USB mas nao removivel (HD externo)"
LINHA_DEV='NAME="sdc" RM="0" TRAN="usb" TYPE="disk" MODEL="Elements" SIZE="931,5G" PKNAME=""' CONFIRMA=/dev/sdc prepara /dev/sdc
afirma '[ "$RC" = 3 ] && [ "$(mkfs_chamadas)" = 0 ]' "rc=$RC mkfs=$(mkfs_chamadas)"

CASO="recusa: pendrive com o / do sistema montado"
LINHA_DEV="$L_USB" MONTAGENS=$'/\n' CONFIRMA=/dev/sdb prepara /dev/sdb
afirma '[ "$RC" = 3 ] && [ "$(mkfs_chamadas)" = 0 ] && grep -q "do sistema" "$TMP/p/saida.log"' "rc=$RC mkfs=$(mkfs_chamadas)"

CASO="recusa: particao de um disco fixo"
LINHA_DEV='NAME="sda1" RM="0" TRAN="" TYPE="part" MODEL="" SIZE="465G" PKNAME="sda"' PAI_NOME=sda LINHA_PAI='NAME="sda" RM="0" TRAN="sata" TYPE="disk" MODEL="Samsung SSD 860" SIZE="465,8G" PKNAME=""' CONFIRMA=/dev/sda1 prepara /dev/sda1
afirma '[ "$RC" = 3 ] && [ "$(mkfs_chamadas)" = 0 ]' "rc=$RC mkfs=$(mkfs_chamadas)"

CASO="recusa: dispositivo desconhecido do lsblk"
CONFIRMA=/dev/zzz prepara /dev/zzz
afirma '[ "$RC" = 2 ] && [ "$(mkfs_chamadas)" = 0 ]' "rc=$RC"

CASO="uso: sem argumento e com dois"
afirma 'bash "$ROOT/tests/preparar-pendrive.sh" >/dev/null 2>&1; [ $? = 2 ]' "sem argumento nao saiu 2"
afirma 'bash "$ROOT/tests/preparar-pendrive.sh" /dev/a /dev/b >/dev/null 2>&1; [ $? = 2 ]' "com dois argumentos nao saiu 2"

CASO="fora do PFL_TESTE o dispositivo tem de ser de bloco (os ganchos nao existem em producao)"
LINHA_DEV="$L_USB" CONFIRMA=/dev/sdb TESTE_ON=0 prepara /dev/sdb
afirma '[ "$RC" = 2 ] && [ "$(mkfs_chamadas)" = 0 ] && grep -q "dispositivo de bloco" "$TMP/p/saida.log"' "rc=$RC mkfs=$(mkfs_chamadas)"

CASO="confirmacao errada: nada e formatado"
LINHA_DEV="$L_USB" CONFIRMA=sim prepara /dev/sdb
afirma '[ "$RC" = 5 ] && [ "$(mkfs_chamadas)" = 0 ] && ! grep -q "^mount" "$TMP/p/calls.log"' "rc=$RC mkfs=$(mkfs_chamadas)"
afirma 'grep -q "Cruzer Blade" "$TMP/p/saida.log" && grep -q "14,5G" "$TMP/p/saida.log"' "nao mostrou modelo e tamanho antes de pedir a confirmacao"
LINHA_DEV="$L_USB" CONFIRMA="" prepara /dev/sdb
afirma '[ "$RC" = 5 ] && [ "$(mkfs_chamadas)" = 0 ]' "confirmacao vazia formatou (rc=$RC)"

CASO="firmware faltando: nada e formatado"
F="$TMP/fwp"; mkdir -p "$F"; cp "$FW/Software PFL7560.zip" "$F/"
LINHA_DEV="$L_USB" CONFIRMA=/dev/sdb FWDIR="$F" prepara /dev/sdb
afirma '[ "$RC" = 4 ] && [ "$(mkfs_chamadas)" = 0 ]' "rc=$RC mkfs=$(mkfs_chamadas)"

CASO="md5 do firmware errado: nada e formatado (conferido ANTES do mkfs, nao so na copia)"
LINHA_DEV="$L_USB" CONFIRMA=/dev/sdb OFMD5="00000000000000000000000000000000" prepara /dev/sdb
afirma '[ "$RC" = 4 ] && [ "$(mkfs_chamadas)" = 0 ] && ! grep -q "^mount\|^umount" "$TMP/p/calls.log"' "oficial com md5 errado: rc=$RC mkfs=$(mkfs_chamadas)"
LINHA_DEV="$L_USB" CONFIRMA=/dev/sdb NSMD5="11111111111111111111111111111111" prepara /dev/sdb
afirma '[ "$RC" = 4 ] && [ "$(mkfs_chamadas)" = 0 ]' "nosso .bin com md5 errado: rc=$RC mkfs=$(mkfs_chamadas)"

CASO="recusa: dispositivo mapeado (crypt/dm) sobre o pendrive: so disco inteiro ou particao"
LINHA_DEV='NAME="dm-0" RM="0" TRAN="" TYPE="crypt" MODEL="" SIZE="14,5G" PKNAME="sdb"' LINHA_PAI="$L_USB" CONFIRMA=/dev/dm-0 prepara /dev/dm-0
afirma '[ "$RC" = 3 ] && [ "$(mkfs_chamadas)" = 0 ] && grep -q "RECUSADO" "$TMP/p/saida.log"' "rc=$RC mkfs=$(mkfs_chamadas)"

CASO="pendrive de verdade (RM=1, usb): formata FAT32, copia o kit e o firmware, desmonta"
LINHA_DEV="$L_USB" CONFIRMA=/dev/sdb prepara /dev/sdb
afirma '[ "$RC" = 0 ]' "rc=$RC: $(tail -4 "$TMP/p/saida.log" | tr '\n' ' ')"
afirma '[ "$(mkfs_chamadas)" = 1 ] && grep -qx "mkfs.vfat -F 32 -n PFL7560 /dev/sdb" "$TMP/p/calls.log"' "mkfs: $(grep '^mkfs' "$TMP/p/calls.log" | tr '\n' '|')"
afirma '[ "$(grep -n "^mkfs" "$TMP/p/calls.log" | cut -d: -f1)" -lt "$(grep -n "^mount" "$TMP/p/calls.log" | head -1 | cut -d: -f1)" ] && [ "$(grep -n "^mount" "$TMP/p/calls.log" | head -1 | cut -d: -f1)" -lt "$(grep -n "^umount" "$TMP/p/calls.log" | tail -1 | cut -d: -f1)" ]' "ordem mkfs, mount, umount quebrada: $(cut -d' ' -f1 "$TMP/p/calls.log" | tr '\n' ' ')"
afirma '[ -d "$TMP/p/snapshot" ] && [ "$(md5 "$TMP/p/snapshot/usb_update.bin")" = "$NOSSO_MD5" ] && [ "$(md5 "$TMP/p/snapshot/resgate-oficial/PFL7560.bin")" = "$OFICIAL_MD5" ] && [ -f "$TMP/p/snapshot/resgate-oficial/LEIA-ME.txt" ] && cmp -s "$ROOT/pendrive-autorun/pfl7560.apk" "$TMP/p/snapshot/pfl7560.apk"' "o pendrive nao ficou com o kit, o apk e o firmware"
afirma 'grep -q "pronto: pendrive preparado" "$TMP/p/saida.log"' "sem a mensagem final"

CASO="particao de pendrive removivel (PKNAME=sdb): aceita"
LINHA_DEV='NAME="sdb1" RM="1" TRAN="" TYPE="part" MODEL="" SIZE="14,5G" PKNAME="sdb"' LINHA_PAI="$L_USB" CONFIRMA=/dev/sdb1 prepara /dev/sdb1
afirma '[ "$RC" = 0 ] && grep -qx "mkfs.vfat -F 32 -n PFL7560 /dev/sdb1" "$TMP/p/calls.log"' "rc=$RC"

CASO="pendrive montado pelo desktop: desmonta antes de formatar"
LINHA_DEV="$L_USB" MONTAGENS=$'/media/usuario/PENDRIVE\n' CONFIRMA=/dev/sdb prepara /dev/sdb
afirma '[ "$RC" = 0 ] && grep -qx "umount /media/usuario/PENDRIVE" "$TMP/p/calls.log" && [ "$(grep -n "^umount /media" "$TMP/p/calls.log" | cut -d: -f1)" -lt "$(grep -n "^mkfs" "$TMP/p/calls.log" | cut -d: -f1)" ]' "rc=$RC: $(cut -d' ' -f1-2 "$TMP/p/calls.log" | tr '\n' '|')"

CASO="install.bat e install-firmware-pendrive.ps1 (texto: nao ha Windows aqui)"
# shellcheck disable=SC2034  # usadas nas strings do afirma (eval)
BAT="$ROOT/install.bat"; PS1="$ROOT/install-firmware-pendrive.ps1"
afirma '[ -f "$PS1" ] && [ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$PS1")" ] && [ "$(grep -c $'"'"'\r'"'"' "$PS1")" = 0 ]' "o .ps1 falta, tem byte fora de ASCII ou CRLF"
afirma 'sed -n "/^:do_pendrive/,/^goto :menu/p" "$BAT" | grep -q "install-firmware-pendrive.ps1.*-Modo conferir" && sed -n "/^:do_pendrive/,/^goto :menu/p" "$BAT" | grep -q "install-firmware-pendrive.ps1.*-Modo copiar"' "install.bat nao chama o .ps1 nos dois modos"
afirma '[ "$(grep -n "Modo conferir" "$BAT" | head -1 | cut -d: -f1)" -lt "$(grep -n "copy /y \"%SRC%\\\\kit" "$BAT" | head -1 | cut -d: -f1)" ]' "o firmware nao e conferido ANTES de copiar o kit no install.bat"
afirma '[ "$(grep -n "Modo copiar" "$BAT" | head -1 | cut -d: -f1)" -gt "$(grep -n "NAO confere com a lista" "$BAT" | head -1 | cut -d: -f1)" ]' "o firmware e copiado antes da conferencia do kit no install.bat"
afirma '[ "$(sed -n "s/^\$OficialMd5 = .\([0-9a-f]*\).$/\1/p" "$PS1")" = "$(sed -n "s/^FW_OFICIAL_MD5=\"\([0-9a-f]*\)\".*/\1/p" "$ROOT/install.sh")" ]' "md5 do oficial difere entre o .ps1 e o install.sh"
afirma '[ "$(sed -n "s/^\$NossoMd5 = .\([0-9a-f]*\).$/\1/p" "$PS1")" = "$(sed -n "s/^FW_NOSSO_MD5=\"\([0-9a-f]*\)\".*/\1/p" "$ROOT/install.sh")" ]' "md5 do nosso difere entre o .ps1 e o install.sh"
afirma '[ "$(cut -d" " -f1 "$ROOT/firmware/$NOSSO_BIN.md5")" = "$(sed -n "s/^FW_NOSSO_MD5=\"\([0-9a-f]*\)\".*/\1/p" "$ROOT/install.sh")" ]' "md5 do nosso no install.sh difere do firmware/$NOSSO_BIN.md5"
afirma 'grep -q "^FW_NOSSO_BIN=\"$NOSSO_BIN\"$" "$ROOT/install.sh" && grep -q "^\$NossoBin = .$NOSSO_BIN.$" "$PS1"' "o install.sh ou o .ps1 nao levam o $NOSSO_BIN"
afirma 'diff <(sed -n "/^fw_leiame(){/,/^LEIAME\$/p" "$ROOT/install.sh" | sed "1,2d;\$d") <(sed -n "/^\$LeiameResgate = @.\$/,/^.@\$/p" "$PS1" | sed "1d;\$d") >/dev/null' "o LEIA-ME do resgate difere entre o install.sh e o .ps1"
afirma '[ "$(sed -n "/^fw_leiame(){/,/^LEIAME\$/p" "$ROOT/install.sh" | grep -c .)" -gt 5 ]' "o install.sh sem o texto do LEIA-ME do resgate"
afirma 'grep -q "28a2f280eee313a4b115567926b2ba4f" "$ROOT/pendrive-autorun/LEIA-ME.txt" && grep -q "^FW_OFICIAL_MD5=\"28a2f280eee313a4b115567926b2ba4f\"" "$ROOT/install.sh"' "md5 oficial do install.sh difere do citado no LEIA-ME do kit"
afirma 'grep -q "SO para o aparelho COM entrada USB-C (V1.0.0.9)" "$ROOT/pendrive-autorun/LEIA-ME.txt" && grep -q "Só serve para o aparelho \*\*com USB-C\*\*" "$ROOT/INSTALL.md"' "o LEIA-ME do kit ou o INSTALL.md nao dizem que o resgate e so do modelo com USB-C"
afirma 'grep -q "^FW_OFICIAL_ZIP=\"Software PFL7560.zip\"" "$ROOT/install.sh" && grep -q "^\$ZipNome = .Software PFL7560.zip.$" "$PS1"' "o zip de origem do resgate nao e o Software PFL7560.zip (o Firmware PFL7560.zip e do modelo sem USB-C)"

CASO="estaticos"
afirma 'bash -n "$ROOT/tests/preparar-pendrive.sh" && bash -n "$ROOT/install.sh"' "bash -n"
if command -v shellcheck >/dev/null 2>&1; then
  afirma 'shellcheck "$ROOT/tests/preparar-pendrive.sh"' "shellcheck do preparar-pendrive.sh"
else
  echo "  (shellcheck ausente: etapa pulada)"
fi

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
