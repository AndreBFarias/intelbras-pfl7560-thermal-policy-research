#!/usr/bin/env bash
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

campo(){ printf '%s\n' "$1" | sed -n "s/.*\(^\| \)$2=\"\([^\"]*\)\".*/\2/p"; }
info(){ lsblk -dnP -o NAME,RM,TRAN,TYPE,MODEL,SIZE,PKNAME "$1" 2>/dev/null | head -1; }

L="$(info "$DEV")"
[ -n "$L" ] || { err "o lsblk nao conhece '$DEV'"; exit 2; }
PAI="$(campo "$L" PKNAME)"
if [ -n "$PAI" ]; then
  LD="$(info "/dev/$PAI")"
  [ -n "$LD" ] || { err "o lsblk nao conhece o disco '/dev/$PAI' de '$DEV'"; exit 2; }
else
  LD="$L"
fi
RM="$(campo "$LD" RM)"; TRAN="$(campo "$LD" TRAN)"; TIPO="$(campo "$LD" TYPE)"
MODELO="$(campo "$LD" MODEL)"; TAM="$(campo "$L" SIZE)"
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

if ! bash "$ROOT/install.sh" --conferir-firmware; then
  err "o firmware em ${PFL_FIRMWARE_DIR:-$ROOT/firmware} nao confere (ver acima). Nada foi formatado."
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
# shellcheck disable=SC2317
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
