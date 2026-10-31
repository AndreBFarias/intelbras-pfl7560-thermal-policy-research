#!/usr/bin/env bash
# tests/preparar-pendrive.sh - prepara um pendrive FAT32 do zero com o kit v2 e o firmware de
# resgate (bloco 9C). FORMATA o dispositivo informado: apaga tudo que esta nele.
#
#   sudo bash tests/preparar-pendrive.sh /dev/sdX      (o disco do pendrive, ou /dev/sdX1)
#
# Passos: (1) confere que o dispositivo e um pendrive: disco removivel (lsblk RM=1) por USB
# (TRAN=usb) e sem nada do sistema montado nele, informado como o disco inteiro ou uma particao
# dele (nada de dispositivo mapeado, crypt, lvm, loop); qualquer outro e RECUSADO, sem
# perguntar; (2) mostra modelo e tamanho e pede para DIGITAR o caminho do dispositivo; (3) formata
# FAT32 (mkfs.vfat -F 32 -n PFL7560); (4) monta, roda install.sh --pendrive <montagem>
# --com-firmware (copia o kit, o usb_update.bin oficial e o nosso .bin sem ativar, e confere o
# md5 de cada arquivo) e (5) desmonta. As origens do firmware (arquivos e md5) sao conferidas
# ANTES de formatar, pelo install.sh --conferir-firmware: faltou arquivo ou o md5 nao bate = nada
# e formatado. Para escolher outra pasta de firmware:
# PFL_FIRMWARE_DIR=<pasta>. Precisa de root (mkfs/mount): use sudo.
#
# Passe o disco inteiro (/dev/sdb: formata sem tabela de particoes) ou, melhor, a particao FAT32
# de um pendrive que ja tem tabela MBR (/dev/sdb1).
#
# Ganchos de teste (so valem com PFL_TESTE=1; o harness tests/test-preparar-pendrive.sh os usa
# com lsblk/mkfs.vfat/mount/umount de mentira no PATH): pula a exigencia de ser root e de ser
# dispositivo de bloco. Fora disso nada disso existe.
set -uo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="${1:-}"

err(){ printf '[ERRO] %s\n' "$*" >&2; }
say(){ printf '>> %s\n' "$*"; }
if [ -z "$DEV" ] || [ "$#" != 1 ]; then echo "uso: sudo bash $0 /dev/sdX   (formata o pendrive: apaga tudo)" >&2; exit 2; fi

if [ "${PFL_TESTE:-}" != "1" ]; then
  [ -b "$DEV" ] || { err "'$DEV' nao e um dispositivo de bloco"; exit 2; }
  [ "$(id -u)" = "0" ] || { err "precisa de root (mkfs e mount): rode com sudo"; exit 2; }
fi
for c in lsblk mkfs.vfat mount umount mktemp; do
  command -v "$c" >/dev/null 2>&1 || { err "falta o comando $c"; exit 2; }
done

# campo KEY="valor" de uma linha do lsblk -P
campo(){ printf '%s\n' "$1" | sed -n "s/.*\(^\| \)$2=\"\([^\"]*\)\".*/\2/p"; }
info(){ lsblk -dnP -o NAME,RM,TRAN,TYPE,MODEL,SIZE,PKNAME "$1" 2>/dev/null | head -1; }

L="$(info "$DEV")"
[ -n "$L" ] || { err "o lsblk nao conhece '$DEV'"; exit 2; }
PAI="$(campo "$L" PKNAME)"
if [ -n "$PAI" ]; then            # particao: RM e TRAN sao do disco que a contem
  LD="$(info "/dev/$PAI")"
  [ -n "$LD" ] || { err "o lsblk nao conhece o disco '/dev/$PAI' de '$DEV'"; exit 2; }
else
  LD="$L"
fi
RM="$(campo "$LD" RM)"; TRAN="$(campo "$LD" TRAN)"; TIPO="$(campo "$LD" TYPE)"
MODELO="$(campo "$LD" MODEL)"; TAM="$(campo "$L" SIZE)"
# o proprio dispositivo: o disco inteiro (sem pai) ou uma particao dele; um mapeado (crypt, lvm),
# loop ou raid tambem tem pai, mas nao e o pendrive que o mkfs.vfat deve apagar
TIPO_DEV="$(campo "$L" TYPE)"
if [ -n "$PAI" ]; then TIPO_ESPERADO=part; else TIPO_ESPERADO=disk; fi
if [ "$RM" != "1" ] || [ "$TRAN" != "usb" ] || [ "$TIPO" != "disk" ] || [ "$TIPO_DEV" != "$TIPO_ESPERADO" ]; then
  err "RECUSADO: '$DEV' nao e um pendrive (removivel=${RM:-?}, ligacao=${TRAN:-?}, tipo=${TIPO_DEV:-?}; exijo removivel=1 por usb, o disco inteiro ou uma particao dele). Nada foi feito."
  exit 3
fi
for mp in $(lsblk -nr -o MOUNTPOINT "$DEV" 2>/dev/null); do
  case "$mp" in
    /|/boot|/boot/*|/home|/home/*|/usr|/usr/*|/var|/var/*|/etc|/etc/*|/efi|/efi/*)
      err "RECUSADO: '$DEV' tem $mp montado (e do sistema). Nada foi feito."; exit 3 ;;
  esac
done

# as origens do firmware (arquivos e md5) sao conferidas ANTES de formatar; o install.sh refaz
# isto na copia. Sem isto um md5 errado so apareceria com o pendrive ja apagado.
if ! bash "$ROOT/install.sh" --conferir-firmware; then
  err "o firmware de resgate em ${PFL_FIRMWARE_DIR:-$ROOT/firmware} nao confere (ver acima). Nada foi formatado."
  exit 4
fi

echo
echo "  Dispositivo : $DEV"
echo "  Modelo      : ${MODELO:-?}"
echo "  Tamanho     : ${TAM:-?}"
echo "  TUDO que esta nele sera APAGADO e o pendrive ficara FAT32 com o nome PFL7560."
printf '  Para continuar, digite o caminho do dispositivo (%s): ' "$DEV"
read -r RESP
if [ "$RESP" != "$DEV" ]; then
  err "confirmacao diferente de '$DEV'. Nada foi feito."
  exit 5
fi

MP="$(mktemp -d)"
MONTADO=""
# shellcheck disable=SC2317  # chamada pelo trap
sai(){
  if [ -n "$MONTADO" ]; then umount "$MP" 2>/dev/null; fi
  rmdir "$MP" 2>/dev/null
}
trap sai EXIT

say "desmontando o que estiver montado em $DEV"
for mp in $(lsblk -nr -o MOUNTPOINT "$DEV" 2>/dev/null); do umount "$mp" || { err "nao consegui desmontar $mp"; exit 6; }; done
say "formatando $DEV em FAT32"
mkfs.vfat -F 32 -n PFL7560 "$DEV" || { err "o mkfs.vfat falhou"; exit 6; }
sync
say "montando em $MP"
mount "$DEV" "$MP" || { err "nao consegui montar $DEV (o desktop pode te-lo montado sozinho). Monte e rode: bash install.sh --pendrive <pasta> --com-firmware"; exit 6; }
MONTADO=1
bash "$ROOT/install.sh" --pendrive "$MP" --com-firmware
RC=$?
sync
umount "$MP" || { err "nao consegui desmontar $MP"; RC=6; }
MONTADO=""
if [ "$RC" = "0" ]; then
  say "pronto: pendrive preparado e conferido. Pode retirar. Plugue so quando for usar (LEIA-ME.txt do kit)."
else
  err "a copia nao terminou bem (codigo $RC): NAO use este pendrive."
fi
exit "$RC"
