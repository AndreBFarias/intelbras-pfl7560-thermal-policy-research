#!/usr/bin/env bash
# ============================================================================
#  install.sh — prepara o PC (Linux/macOS) para a correcao PFL7560 via adb
#
#  NAO grava nada no projetor. So instala/verifica ferramentas do host.
#
#  Uso:
#    ./install.sh              # instala deps se faltar + verifica
#    ./install.sh --check      # so verifica (sem instalar)
#    ./install.sh --pendrive DIR   # copia o kit v2 COMPLETO para a raiz do pendrive
#                                  # (DIR = ponto de montagem) e confere os md5
#    ./install.sh --pendrive DIR --com-firmware
#                                  # idem + o NOSSO .bin na raiz como usb_update.bin e o
#                                  # OFICIAL V1.0.0.9 (do firmware/Software PFL7560.zip)
#                                  # em resgate-oficial/ (ver INSTALL.md)
#    ./install.sh --conferir-firmware  # so confere as origens do firmware de resgate (md5),
#                                      # sem copiar nada (o tests/preparar-pendrive.sh usa)
#    ./install.sh --dev        # idem + o que o desenvolvimento usa (requirements.txt)
#    ./install.sh --check --dev    # so verifica, inclusive o de desenvolvimento
#    ./install.sh --diario     # so COPIA as unidades systemd --user do diario do projetor para
#                              # ~/.config/systemd/user/ e mostra os comandos para ligar. Nao liga nada.
#    ./install.sh --help
#  PFL_FIRMWARE_DIR=<pasta> aponta outra pasta de firmware (padrao: firmware/ deste repo).
#
#  Depois:
#    PFL_IP=<ip> ./pfl7560-fix.sh status|apply|revert
#  Ou sem PC: pendrive-autorun/ (veja INSTALL.md)
# ============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" || exit 1

CHECK_ONLY=0
PENDRIVE_DIR=""
COM_FIRMWARE=0
CONFERIR_FW=0
DIARIO=0
DEV=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      sed -n '2,26p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    --check|-c) CHECK_ONLY=1 ;;
    --pendrive|-p)
      PENDRIVE_DIR="${2:-}"
      case "$PENDRIVE_DIR" in
        ""|-*) echo "uso: $0 --pendrive <pasta-raiz-do-pendrive> [--com-firmware]"; exit 1 ;;
      esac
      shift
      ;;
    --com-firmware) COM_FIRMWARE=1 ;;
    --conferir-firmware) CONFERIR_FW=1 ;;
    --dev) DEV=1 ;;
    --diario) DIARIO=1 ;;
    *) echo "uso: $0 [--check] [--dev] | --pendrive DIR [--com-firmware] | --diario | --help"; exit 1 ;;
  esac
  shift
done
if [ "$DIARIO" = "1" ] && { [ -n "$PENDRIVE_DIR" ] || [ "$COM_FIRMWARE" = "1" ] || [ "$CONFERIR_FW" = "1" ] || [ "$CHECK_ONLY" = "1" ] || [ "$DEV" = "1" ]; }; then
  echo "uso: --diario vale sozinho (so copia as unidades do diario)"; exit 1
fi
if [ "$COM_FIRMWARE" = "1" ] && [ -z "$PENDRIVE_DIR" ]; then
  echo "uso: --com-firmware so vale junto com --pendrive <pasta-raiz-do-pendrive>"; exit 1
fi
if [ "$DEV" = "1" ] && { [ -n "$PENDRIVE_DIR" ] || [ "$CONFERIR_FW" = "1" ]; }; then
  echo "uso: --dev vale com ou sem --check, nao com --pendrive nem --conferir-firmware"; exit 1
fi
if [ "$CONFERIR_FW" = "1" ] && { [ -n "$PENDRIVE_DIR" ] || [ "$COM_FIRMWARE" = "1" ] || [ "$CHECK_ONLY" = "1" ]; }; then
  echo "uso: --conferir-firmware vale sozinho (so confere as origens; nao copia nada)"; exit 1
fi

say(){ printf '\033[1;36m>> %s\033[0m\n' "$*"; }
ok(){  printf '\033[1;32m[OK] %s\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
err(){ printf '\033[1;31m[ERRO] %s\033[0m\n' "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

detect_os(){
  case "$(uname -s)" in
    Linux*)  echo linux ;;
    Darwin*) echo macos ;;
    *)       echo other ;;
  esac
}

find_adb(){
  if have adb; then command -v adb; return 0; fi
  local c
  for c in \
    "$HOME/Android/Sdk/platform-tools/adb" \
    "$HOME/Android/sdk/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb" \
    "/usr/lib/android-sdk/platform-tools/adb"
  do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

install_linux(){
  if have apt-get; then
    say "Debian/Ubuntu/Pop — instalando android-tools-adb e nmap"
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y android-tools-adb nmap
  elif have dnf; then
    say "Fedora — instalando android-tools e nmap"
    sudo dnf install -y android-tools nmap
  elif have pacman; then
    say "Arch — instalando android-tools e nmap"
    sudo pacman -Sy --noconfirm android-tools nmap
  elif have zypper; then
    say "openSUSE — instalando android-tools e nmap"
    sudo zypper --non-interactive install android-tools nmap
  else
    err "nao reconheci o gerenciador de pacotes."
    err "Instale manualmente: adb (android-tools / platform-tools) e, opcional, nmap."
    err "Veja o INSTALL.md, secao 0"
    return 1
  fi
}

install_macos(){
  if ! have brew; then
    err "Homebrew nao encontrado. Instale: https://brew.sh"
    err "Depois: brew install android-platform-tools nmap"
    return 1
  fi
  say "macOS — instalando android-platform-tools e nmap via Homebrew"
  brew install android-platform-tools nmap
}

chmod_scripts(){
  chmod +x \
    "$HERE/pfl7560-fix.sh" \
    "$HERE/pfl7560-menu.sh" \
    "$HERE/install.sh" \
    "$HERE/pendrive-autorun/newlink_update.sh" \
    2>/dev/null || true
  [ -f "$HERE/PFL7560-Corrigir.desktop" ] && chmod +x "$HERE/PFL7560-Corrigir.desktop" || true
}

md5_de(){
  if have md5sum; then md5sum "$1" | cut -d' ' -f1
  elif have md5; then md5 -q "$1"
  else return 1
  fi
}
copiar_pendrive(){
  local dest="$1" src="$HERE/pendrive-autorun" lista h n f falhas=0 total=0
  [ -d "$dest" ] || { err "'$dest' nao e uma pasta (informe o ponto de montagem do pendrive FAT32)"; return 1; }
  dest="$(cd "$dest" && pwd)"
  [ "$dest" != "$src" ] || { err "o destino e a propria pasta do kit"; return 1; }
  if [ -e "$dest/DESINSTALAR-SUITE.txt" ]; then
    err "o pendrive tem DESINSTALAR-SUITE.txt: plugado, ele DESINSTALA a suite em vez de instalar. Apague o arquivo e rode de novo. Nada foi copiado."
    return 1
  fi
  if [ "$COM_FIRMWARE" != "1" ] && { [ -e "$dest/usb_update.bin" ] || [ -L "$dest/usb_update.bin" ]; }; then
    err "o pendrive tem um usb_update.bin que nao foi conferido: ligar o projetor SEGURANDO O POWER com ele plugado REGRAVA o aparelho com esse arquivo. Apague-o, ou rode com --com-firmware (troca e confere). Nada foi copiado."
    return 1
  fi
  have md5sum || have md5 || { err "sem md5sum/md5: nao consigo conferir a copia"; return 1; }
  lista="$(sed -n '/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p' "$src/newlink_update.sh" \
           | sed -n 's/^\(KIT_LISTA="\)\{0,1\}\([0-9a-f]\{32\}\)  \(.*\)$/\2  \3/p')"
  [ -n "$lista" ] || { err "nao achei a lista de md5 em pendrive-autorun/newlink_update.sh"; return 1; }
  say "copiando o kit v2 completo para a raiz de $dest"
  mkdir -p "$dest/kit" "$dest/fontes" || { err "nao consegui criar $dest/kit e $dest/fontes"; return 1; }
  cp "$src/newlink_update.sh" "$src/LEIA-ME.txt" "$dest/" || { err "falha ao copiar para $dest"; return 1; }
  while read -r h n; do
    [ -n "$n" ] || continue
    case "$n" in */*) mkdir -p "$dest/${n%/*}" || { err "nao consegui criar $dest/${n%/*}"; falhas=$((falhas+1)); } ;; esac
    cp "$src/$n" "$dest/$n" || { err "falha ao copiar $n"; falhas=$((falhas+1)); }
  done <<LISTA
$lista
LISTA
  sync
  say "conferindo a copia contra a lista embutida no newlink_update.sh"
  while read -r h n; do
    [ -n "$n" ] || continue
    total=$((total+1))
    if [ "$(md5_de "$dest/$n" 2>/dev/null)" = "$h" ]; then ok "$n"
    else err "$n: md5 diferente do esperado ($h) ou ausente"; falhas=$((falhas+1)); fi
  done <<LISTA
$lista
LISTA
  for f in newlink_update.sh LEIA-ME.txt; do
    total=$((total+1))
    if cmp -s "$src/$f" "$dest/$f"; then ok "$f"
    else err "$f: copia diferente da origem"; falhas=$((falhas+1)); fi
  done
  if [ "$falhas" = "0" ]; then
    ok "kit v2 completo no pendrive: $total arquivos conferidos. Desligue o projetor, plugue o pendrive e ligue."
    return 0
  fi
  err "$falhas arquivo(s) NAO conferem - nao use este pendrive. Copie de novo."
  return 1
}

FW_DIR="${PFL_FIRMWARE_DIR:-$HERE/firmware}"
FW_OFICIAL_ZIP="Software PFL7560.zip"
FW_OFICIAL_MD5="28a2f280eee313a4b115567926b2ba4f"
FW_NOSSO_BIN="PFL7560-S6-COMPLETO-NAO-GRADUADO.bin"
# o md5 aprovado vem do .md5 versionado (o mesmo arquivo e o mesmo formato que o firmware/preflight-flash.sh le):
# remontar a S6 so muda o .md5, e o pendrive sai com o usb_update.bin que o pre-voo aceita
FW_NOSSO_MD5_ARQ="$HERE/firmware/$FW_NOSSO_BIN.md5"
FW_RESGATE_PASTA="resgate-oficial"
FW_LEGADO_PASTA="firmware-nosso-NAO-GRADUADO"
if [ "${PFL_TESTE:-}" = "1" ]; then
  FW_OFICIAL_MD5="${PFL_FW_OFICIAL_MD5:-$FW_OFICIAL_MD5}"
  FW_NOSSO_MD5_ARQ="${PFL_FW_NOSSO_MD5_ARQ:-$FW_NOSSO_MD5_ARQ}"
else
  unset PFL_FW_OFICIAL_MD5 PFL_FW_NOSSO_MD5 PFL_FW_NOSSO_MD5_ARQ
fi
FW_NOSSO_MD5="$(sed -n 's/^\([0-9a-f]\{32\}\)  PFL7560-S6-COMPLETO-NAO-GRADUADO\.bin$/\1/p' "$FW_NOSSO_MD5_ARQ" 2>/dev/null | head -n 1)"
if [ "${PFL_TESTE:-}" = "1" ]; then FW_NOSSO_MD5="${PFL_FW_NOSSO_MD5:-$FW_NOSSO_MD5}"; fi
FW_MEMBRO=""

fw_conferir(){
  local dest="$1" zip="$FW_DIR/$FW_OFICIAL_ZIP" nosso="$FW_DIR/$FW_NOSSO_BIN" m n tam livre
  if [ -n "$dest" ] && [ ! -d "$dest" ]; then
    err "'$dest' nao e uma pasta (informe o ponto de montagem do pendrive FAT32)"; return 1
  fi
  have unzip || { err "sem o comando unzip: preciso dele para tirar o .bin oficial do zip"; return 1; }
  have md5sum || have md5 || { err "sem md5sum/md5: nao consigo conferir o firmware"; return 1; }
  say "firmware: conferindo as origens em $FW_DIR"
  if [ ! -f "$zip" ]; then
    err "falta '$zip' (o firmware OFICIAL V1.0.0.9 do aparelho com USB-C). NAO use o 'Firmware PFL7560.zip': e do modelo sem USB-C."
    return 1
  fi
  if [ ! -f "$nosso" ]; then
    err "falta '$nosso' (o nosso .bin; e 'local only', nao vem no git: copie-o para $FW_DIR). Nada foi copiado."
    return 1
  fi
  if [ -z "$FW_NOSSO_MD5" ]; then
    err "sem o md5 aprovado de $FW_NOSSO_BIN em '$FW_NOSSO_MD5_ARQ' (linha '<md5>  $FW_NOSSO_BIN'). Nada foi copiado."
    return 1
  fi
  n="$(unzip -Z1 "$zip" 2>/dev/null | grep -E '(^|/)PFL7560\.bin$')"
  if [ -z "$n" ] || [ "$(printf '%s\n' "$n" | wc -l)" != "1" ]; then
    err "'$FW_OFICIAL_ZIP' deveria ter exatamente um PFL7560.bin e tem: '${n:-nenhum}'. Nada foi copiado."
    return 1
  fi
  FW_MEMBRO="$n"
  m="$(unzip -p "$zip" "$FW_MEMBRO" | { md5sum 2>/dev/null || md5 -q; } | cut -d' ' -f1)"
  if [ "$m" != "$FW_OFICIAL_MD5" ]; then
    err "o .bin dentro de '$FW_OFICIAL_ZIP' tem md5 $m, o esperado e $FW_OFICIAL_MD5 (V1.0.0.9 oficial). Nada foi copiado."
    return 1
  fi
  m="$(md5_de "$nosso")"
  if [ "$m" != "$FW_NOSSO_MD5" ]; then
    err "'$FW_NOSSO_BIN' tem md5 $m, o esperado e $FW_NOSSO_MD5. Nada foi copiado."
    return 1
  fi
  if [ -n "$dest" ]; then
    tam=$(( $(unzip -l "$zip" "$FW_MEMBRO" | awk 'END{print $1}') + $(wc -c < "$nosso") + 10485760 ))
    livre=$(( $(df -Pk "$dest" | awk 'NR==2{print $4}') * 1024 ))
    if [ "$livre" -lt "$tam" ]; then
      err "pouco espaco em $dest: preciso de $((tam / 1048576)) MB e ha $((livre / 1048576)) MB livres. Nada foi copiado."
      return 1
    fi
  fi
  ok "nosso .bin $FW_NOSSO_BIN (md5 $FW_NOSSO_MD5) e firmware oficial V1.0.0.9 (md5 $FW_OFICIAL_MD5) conferidos"
}

fw_leiame(){
  cat <<'LEIAME'
FIRMWARE OFICIAL DE FABRICA (V1.0.0.9) - RESGATE
================================================

O PFL7560.bin desta pasta e o firmware OFICIAL de fabrica da Intelbras,
V1.0.0.9, do aparelho COM entrada USB-C. Ele NAO esta ativo: o projetor so
olha o usb_update.bin da RAIZ do pendrive, e esse e o NOSSO firmware S6
(escada de brilho, wi-fi, xiri, a suite, a home e o app ja na imagem). A S5,
a anterior, foi gravada e funcionou; a S6 ainda nao foi provada no aparelho.

QUANDO USAR
  So se o nosso firmware deixar o projetor sem ligar ou sem funcionar direito.

COMO USAR
  1. Num PC, apague o usb_update.bin da raiz do pendrive.
  2. Copie este PFL7560.bin para a RAIZ do pendrive com o nome usb_update.bin.
  3. Com o projetor desligado e o pendrive plugado, ligue SEGURANDO O POWER.
     Isso regrava o aparelho e APAGA o /data (Wi-Fi, contas e apps).
  4. Depois, rode o kit do pendrive de novo (sem segurar o power).
  NAO use o firmware do modelo sem USB-C ("Firmware PFL7560.zip").

CONFERENCIA
  md5 deste PFL7560.bin: 28a2f280eee313a4b115567926b2ba4f
  (no Linux: md5sum PFL7560.bin)
LEIAME
}

fw_limpar(){ rm -rf "${1:?}/usb_update.bin" "${1:?}/usb_update.bin.copiando" "${1:?}/$FW_RESGATE_PASTA" "${1:?}/$FW_LEGADO_PASTA"; }

fw_copiar(){
  local dest zip="$FW_DIR/$FW_OFICIAL_ZIP" r
  dest="$(cd "$1" && pwd)"; r="$dest/$FW_RESGATE_PASTA"
  fw_limpar "$dest"
  say "copiando o firmware: o nosso .bin como usb_update.bin e o oficial em $FW_RESGATE_PASTA/ (sao grandes: leva alguns minutos)"
  if ! { mkdir -p "$r" \
         && unzip -p "$zip" "$FW_MEMBRO" > "$r/PFL7560.bin.copiando" \
         && mv -f "$r/PFL7560.bin.copiando" "$r/PFL7560.bin" \
         && fw_leiame > "$r/LEIA-ME.txt" \
         && cp "$FW_DIR/$FW_NOSSO_BIN" "$dest/usb_update.bin.copiando" \
         && mv -f "$dest/usb_update.bin.copiando" "$dest/usb_update.bin"; }; then
    fw_limpar "$dest"; err "falha ao copiar o firmware (pendrive cheio, protegido ou removido?). O firmware foi removido do pendrive; NAO use este pendrive."
    return 1
  fi
  sync
  say "conferindo o firmware depois da copia"
  if [ "$(md5_de "$r/PFL7560.bin")" != "$FW_OFICIAL_MD5" ] || ! fw_leiame | cmp -s - "$r/LEIA-ME.txt"; then
    fw_limpar "$dest"; err "$FW_RESGATE_PASTA/ NAO confere (md5 oficial $FW_OFICIAL_MD5 ou o LEIA-ME). O firmware foi removido do pendrive; copie de novo."
    return 1
  fi
  ok "$FW_RESGATE_PASTA/PFL7560.bin (oficial V1.0.0.9, md5 $FW_OFICIAL_MD5) e LEIA-ME.txt; NAO esta ativo"
  if [ "$(md5_de "$dest/usb_update.bin")" != "$FW_NOSSO_MD5" ]; then
    fw_limpar "$dest"; err "usb_update.bin NAO confere com o md5 do nosso .bin $FW_NOSSO_MD5. O firmware foi removido do pendrive; copie de novo."
    return 1
  fi
  ok "usb_update.bin (o nosso $FW_NOSSO_BIN, md5 $FW_NOSSO_MD5)"
  warn "pendrive com firmware: ligar o projetor SEGURANDO O POWER com ele plugado REFLASHA o aparelho com o NOSSO .bin (nao provado no hardware) e apaga o /data. O resgate e o oficial em $FW_RESGATE_PASTA/ (LEIA-ME.txt dela). Deixe-o desconectado no uso normal."
}

verify(){
  local rc=0 adb_path
  say "verificando ferramentas do PC..."

  if adb_path="$(find_adb)"; then
    ok "adb: $adb_path"
    "$adb_path" version 2>/dev/null | head -1 || true
  else
    err "adb NAO encontrado"
    rc=1
  fi

  if have nmap; then
    ok "nmap: $(command -v nmap) (opcional — so para PFL_MAC)"
  else
    warn "nmap ausente (ok se voce usar PFL_IP=<ip>)"
  fi

  if [ -x "$HERE/pfl7560-fix.sh" ]; then
    ok "pfl7560-fix.sh presente e executavel"
  else
    err "pfl7560-fix.sh ausente ou sem +x"
    rc=1
  fi

  if [ -f "$HERE/pendrive-autorun/ZYCustom.ini" ] && [ -f "$HERE/pendrive-autorun/newlink_update.sh" ] \
     && [ -f "$HERE/pendrive-autorun/cor.sh" ] && [ -f "$HERE/pendrive-autorun/lvdsctl" ] \
     && [ -f "$HERE/pendrive-autorun/nl_camcheck" ] \
     && [ -d "$HERE/pendrive-autorun/kit" ]; then
    ok "pendrive-autorun/ completo (metodo sem PC)"
  else
    warn "pendrive-autorun/ incompleto"
  fi

  if [ -x "$HERE/tests/check-stock-md5.sh" ] || [ -f "$HERE/tests/check-stock-md5.sh" ]; then
    if bash "$HERE/tests/check-stock-md5.sh" >/dev/null 2>&1; then
      ok "integridade dos artefatos (make check) OK"
    else
      warn "make check falhou — rode: make check"
    fi
  fi

  return "$rc"
}

SDK_DIR="${ANDROID_SDK:-$HOME/Android/sdk}"
NDK_DIR="${ANDROID_NDK:-$HOME/Android/android-ndk-r27c}"
CLT_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
NDK_URL="https://dl.google.com/android/repository/android-ndk-r27c-linux.zip"
DEV_APT="android-tools-adb nmap shellcheck zip unzip curl git git-lfs make bc dosfstools libarchive-zip-perl default-jdk-headless python3 python3-pil python3-numpy vlc"
DEV_CMDS="adb nmap shellcheck zip unzip curl git git-lfs make bc mkfs.vfat crc32 javac java keytool python3 vlc"

dev_baixar(){
  local url="$1" dest="$2" tmp
  # baixa ao lado do destino: o /tmp costuma ser tmpfs pequeno e o NDK aberto passa de 2 GB
  mkdir -p "$(dirname "$dest")" && tmp="$(mktemp -d "$(dirname "$dest")/.baixando.XXXXXX")" || return 1
  curl -fL --retry 3 -o "$tmp/pacote.zip" "$url" && unzip -q "$tmp/pacote.zip" -d "$tmp/x" || { rm -rf "$tmp"; return 1; }
  mv "$tmp/x/$(ls "$tmp/x" | head -1)" "$dest"
  local r=$?; rm -rf "$tmp"; return "$r"
}

install_dev(){
  if [ "$(detect_os)" != "linux" ] || ! have apt-get; then
    warn "--dev instala sozinho so em Debian/Ubuntu/Pop. Instale a mao: $DEV_APT; o Android SDK (build-tools 35.0.0, android-34) em $SDK_DIR e o NDK r27c em $NDK_DIR"
    return 1
  fi
  say "pacotes de desenvolvimento (pode pedir sudo)"
  sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $DEV_APT || return 1
  if [ ! -x "$SDK_DIR/build-tools/35.0.0/d8" ] || [ ! -f "$SDK_DIR/platforms/android-34/android.jar" ]; then
    if [ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
      say "Android SDK command-line tools em $SDK_DIR"
      dev_baixar "$CLT_URL" "$SDK_DIR/cmdline-tools/latest" || { err "falhou o download das command-line tools"; return 1; }
    fi
    say "build-tools 35.0.0 e android-34 (aceitando as licencas do SDK)"
    yes | "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_DIR" --licenses >/dev/null 2>&1
    "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_DIR" "build-tools;35.0.0" "platforms;android-34" >/dev/null || { err "sdkmanager falhou"; return 1; }
  fi
  if [ ! -d "$NDK_DIR/toolchains" ]; then
    say "Android NDK r27c em $NDK_DIR (~650 MB)"
    dev_baixar "$NDK_URL" "$NDK_DIR" || { err "falhou o download do NDK"; return 1; }
  fi
}

verify_dev(){
  local rc=0 c
  say "verificando o que o desenvolvimento usa..."
  for c in $DEV_CMDS; do
    if have "$c"; then ok "$c"; else err "$c ausente"; rc=1; fi
  done
  if python3 -I -c 'import PIL, numpy' 2>/dev/null; then
    ok "python3: Pillow e numpy (visiveis com python3 -I, como os testes rodam)"
  else
    err "python3 -I nao enxerga Pillow/numpy: instale python3-pil e python3-numpy pelo apt (pip --user nao serve, os testes rodam isolados)"
    rc=1
  fi
  if [ -x "$SDK_DIR/build-tools/35.0.0/d8" ] && [ -f "$SDK_DIR/platforms/android-34/android.jar" ]; then
    ok "Android SDK: $SDK_DIR (build-tools 35.0.0, android-34)"
  else
    err "Android SDK incompleto em $SDK_DIR (precisa de build-tools 35.0.0 e android-34)"; rc=1
  fi
  if [ -x "$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang" ]; then
    ok "Android NDK: $NDK_DIR"
  else
    err "Android NDK r27c ausente em $NDK_DIR"; rc=1
  fi
  return "$rc"
}

print_next(){
  cat <<'EOF'

------------------------------------------------------------
  PC pronto? Proximos passos:

  1) Projetor LIGADO, mesmo Wi-Fi do PC.
  2) Anote o IP: Configuracoes -> Wi-Fi -> (rede conectada).
  3) Comandos:

       PFL_IP=192.168.0.50 ./pfl7560-fix.sh status
       PFL_IP=192.168.0.50 ./pfl7560-fix.sh apply
       PFL_IP=192.168.0.50 ./pfl7560-fix.sh revert

     (troque o IP pelo do seu projetor)

  Sem PC: ./install.sh --pendrive /caminho/do/pendrive (FAT32) copia o kit
  v2 completo para a raiz e confere os md5; ligue o projetor com o pendrive
  plugado. Com --com-firmware leva tambem o nosso .bin (usb_update.bin) e o oficial (resgate-oficial/).
  Ver INSTALL.md.

  NAO flashar nenhum .bin em firmware/ (quarentena).
------------------------------------------------------------
EOF
}

# Unidades do diario (bloco 24): so COPIA os dois arquivos para o systemd --user do dono, trocando o
# @AQUI@ pela pasta deste repositorio. Nao roda systemctl, nao liga timer, nao grava no projetor.
# HOME e XDG_CONFIG_HOME podem apontar para uma pasta de teste.
instalar_diario(){
  local origem="$HERE/systemd" dest="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" u
  case "$HERE" in
    *[[:space:]%\\]*) err "o caminho '$HERE' tem espaco, % ou barra invertida: o systemd nao le assim. Mova o repositorio."; return 1 ;;
  esac
  for u in pfl7560-diario.service pfl7560-diario.timer; do
    [ -f "$origem/$u" ] || { err "falta $origem/$u"; return 1; }
  done
  [ -x "$HERE/pfl7560-diario.sh" ] || chmod +x "$HERE/pfl7560-diario.sh" 2>/dev/null
  mkdir -p "$dest" || { err "nao consegui criar $dest"; return 1; }
  for u in pfl7560-diario.service pfl7560-diario.timer; do
    sed "s|@AQUI@|$HERE|g" "$origem/$u" > "$dest/$u.novo" && mv -f "$dest/$u.novo" "$dest/$u" \
      || { err "nao consegui gravar $dest/$u"; return 1; }
    chmod 644 "$dest/$u"
    ok "unidade copiada: $dest/$u"
  done
  cat <<DIARIOFIM

Nada foi ligado. Para ligar (uma vez, na sua conta):
  1. mkdir -p ~/.config/pfl7560 && echo 'PFL_IP=<ip do projetor>' > ~/.config/pfl7560/diario.env
  2. systemctl --user daemon-reload
  3. systemctl --user enable --now pfl7560-diario.timer
Para desligar:  systemctl --user disable --now pfl7560-diario.timer
Os arquivos ficam em $HERE/logs-projetor/ (um por mes).
DIARIOFIM
}
if [ "$DIARIO" = "1" ]; then
  instalar_diario
  exit $?
fi
if [ "$CONFERIR_FW" = "1" ]; then
  fw_conferir ""
  exit $?
fi
if [ -n "$PENDRIVE_DIR" ]; then
  if [ "$COM_FIRMWARE" = "1" ]; then fw_conferir "$PENDRIVE_DIR" || exit 1; fi
  copiar_pendrive "$PENDRIVE_DIR" || exit 1
  if [ "$COM_FIRMWARE" = "1" ]; then fw_copiar "$PENDRIVE_DIR" || exit 1; fi
  exit 0
fi
OS="$(detect_os)"
say "PFL7560 — setup do PC ($OS)"
chmod_scripts

if [ "$CHECK_ONLY" = "1" ]; then
  verify; rc=$?
  if [ "$DEV" = "1" ]; then verify_dev || rc=1; fi
  exit "$rc"
fi
if [ "$DEV" = "1" ]; then
  install_dev || warn "a instalacao de desenvolvimento nao terminou (ver acima)"
fi

ADB_NOW="$(find_adb || true)"
if [ -z "$ADB_NOW" ]; then
  case "$OS" in
    linux) install_linux || exit 1 ;;
    macos) install_macos || exit 1 ;;
    *)
      err "SO nao suportado por este instalador automatico: $(uname -s)"
      err "Instale o adb manualmente (platform-tools) e rode: $0 --check"
      exit 1
      ;;
  esac
else
  ok "adb ja disponivel — pulando instalacao de pacotes"
  if ! have nmap && [ "$OS" = "linux" ] && [ "${PFL_INSTALL_NMAP:-1}" = "1" ]; then
    say "nmap opcional ausente — tentando instalar (pode pedir sudo)..."
    if have apt-get; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nmap 2>/dev/null || warn "nmap nao instalado (ignore se usar PFL_IP)"
    elif have dnf; then
      sudo dnf install -y nmap 2>/dev/null || warn "nmap nao instalado"
    elif have pacman; then
      sudo pacman -Sy --noconfirm nmap 2>/dev/null || warn "nmap nao instalado"
    fi
  fi
fi

chmod_scripts
DEV_OK=1
if [ "$DEV" = "1" ]; then verify_dev || DEV_OK=0; fi
if verify && [ "$DEV_OK" = "1" ]; then
  ok "setup do PC concluido"
  print_next
  exit 0
else
  err "setup incompleto — veja o INSTALL.md, secao 0"
  print_next
  exit 1
fi
