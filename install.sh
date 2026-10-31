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
#                                  # idem + o usb_update.bin OFICIAL (V1.0.0.9, do
#                                  # firmware/Software PFL7560.zip) na raiz e o nosso .bin
#                                  # em firmware-nosso-NAO-GRADUADO/ (ver INSTALL.md)
#    ./install.sh --conferir-firmware  # so confere as origens do firmware de resgate (md5),
#                                      # sem copiar nada (o tests/preparar-pendrive.sh usa)
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
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# \?//'
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
    *) echo "uso: $0 [--check|--pendrive DIR [--com-firmware]|--help]"; exit 1 ;;
  esac
  shift
done
if [ "$COM_FIRMWARE" = "1" ] && [ -z "$PENDRIVE_DIR" ]; then
  echo "uso: --com-firmware so vale junto com --pendrive <pasta-raiz-do-pendrive>"; exit 1
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

# Localiza adb (PATH ou SDK comum)
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
    err "Veja requirements e REQUIREMENTS.md"
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
  # .desktop: marcar executavel se existir
  [ -f "$HERE/PFL7560-Corrigir.desktop" ] && chmod +x "$HERE/PFL7560-Corrigir.desktop" || true
}

# ---- kit v2 no pendrive ------------------------------------------------------
# Copia o kit COMPLETO para a RAIZ do pendrive e confere, depois da copia, o md5 de cada
# arquivo contra a lista embutida no proprio newlink_update.sh (a mesma que o
# aparelho confere antes de escrever). O kit inteiro e o que a lista traz:
#   newlink_update.sh  cor.sh  lvdsctl  nl_camcheck  ZYCustom.ini  LEIA-ME.txt
#   suite.sh  suite-boot.sh  suite-pedido.sh  pfl7560-suite.rc   (suite de verificacao, bloco 9B)
#   nl_tela  fontes/*                                              (telas geradas, bloco 9A)
#   pfl7560.apk                                                    (app "PFL7560", bloco 9C)
#   kit/*.png
# O newlink_update.sh nao esta na lista (nao pode conter o proprio md5) e o LEIA-ME.txt
# tambem nao: os dois sao comparados byte a byte com a origem. NAO grava nada no projetor.
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
  have md5sum || have md5 || { err "sem md5sum/md5: nao consigo conferir a copia"; return 1; }
  lista="$(sed -n '/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p' "$src/newlink_update.sh" \
           | sed -n 's/^\(KIT_LISTA="\)\{0,1\}\([0-9a-f]\{32\}\)  \(.*\)$/\2  \3/p')"
  [ -n "$lista" ] || { err "nao achei a lista de md5 em pendrive-autorun/newlink_update.sh"; return 1; }
  say "copiando o kit v2 completo para a raiz de $dest"
  mkdir -p "$dest/kit" "$dest/fontes" || { err "nao consegui criar $dest/kit e $dest/fontes"; return 1; }
  cp "$src/newlink_update.sh" "$src/LEIA-ME.txt" "$dest/" || { err "falha ao copiar para $dest"; return 1; }
  while read -r h n; do
    [ -n "$n" ] || continue
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


# ---- firmware de resgate no pendrive (--com-firmware, bloco 9C) -------------------
# So o firmware OFICIAL do modelo COM USB-C (V1.0.0.9, Software PFL7560.zip) vai como
# usb_update.bin; NUNCA o "Firmware PFL7560.zip" (modelo sem USB-C, doc 42). O nosso .bin
# (escada, NAO graduado no hardware) vai so numa pasta, com um LEIA-ME, e nunca com o nome
# usb_update.bin (README do firmware). Tudo e conferido ANTES de copiar qualquer coisa
# (fw_conferir) e de novo depois (fw_copiar): faltou um arquivo ou o md5 nao e o esperado =
# erro claro e nada vai para o pendrive.
FW_DIR="${PFL_FIRMWARE_DIR:-$HERE/firmware}"
FW_OFICIAL_ZIP="Software PFL7560.zip"
FW_OFICIAL_MD5="28a2f280eee313a4b115567926b2ba4f"   # PFL7560.bin do V1.0.0.9 (firmware/README.md)
FW_NOSSO_BIN="PFL7560-FIX-escada-NAO-GRADUADO.bin"
FW_NOSSO_MD5="eae3a83db44f790b64b9a5838a27a977"
FW_NOSSO_LEIAME="LEIA-ME-nosso-NAO-GRADUADO.txt"
FW_NOSSO_PASTA="firmware-nosso-NAO-GRADUADO"
# gancho de teste: so com PFL_TESTE=1 o harness (tests/) troca os md5 esperados, para usar
# .bin falsos pequenos. Fora disso as variaveis saem do ambiente.
if [ "${PFL_TESTE:-}" = "1" ]; then
  FW_OFICIAL_MD5="${PFL_FW_OFICIAL_MD5:-$FW_OFICIAL_MD5}"
  FW_NOSSO_MD5="${PFL_FW_NOSSO_MD5:-$FW_NOSSO_MD5}"
else
  unset PFL_FW_OFICIAL_MD5 PFL_FW_NOSSO_MD5
fi
FW_MEMBRO=""

# $1 = destino (ponto de montagem); vazio = so as origens, sem a pasta nem o espaco (--conferir-firmware)
fw_conferir(){
  local dest="$1" zip="$FW_DIR/$FW_OFICIAL_ZIP" nosso="$FW_DIR/$FW_NOSSO_BIN" m n tam livre
  if [ -n "$dest" ] && [ ! -d "$dest" ]; then
    err "'$dest' nao e uma pasta (informe o ponto de montagem do pendrive FAT32)"; return 1
  fi
  have unzip || { err "sem o comando unzip: preciso dele para tirar o .bin oficial do zip"; return 1; }
  have md5sum || have md5 || { err "sem md5sum/md5: nao consigo conferir o firmware"; return 1; }
  say "firmware de resgate: conferindo as origens em $FW_DIR"
  if [ ! -f "$zip" ]; then
    err "falta '$zip' (o firmware OFICIAL V1.0.0.9 do aparelho com USB-C). NAO use o 'Firmware PFL7560.zip': e do modelo sem USB-C."
    return 1
  fi
  if [ ! -f "$nosso" ]; then
    err "falta '$nosso' (o nosso .bin; e 'local only', nao vem no git: copie-o para $FW_DIR). Nada foi copiado."
    return 1
  fi
  if [ ! -f "$FW_DIR/$FW_NOSSO_LEIAME" ]; then
    err "falta '$FW_DIR/$FW_NOSSO_LEIAME' (o texto que acompanha o nosso .bin no pendrive). Nada foi copiado."
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
  ok "firmware oficial V1.0.0.9 (md5 $FW_OFICIAL_MD5) e nosso .bin (md5 $FW_NOSSO_MD5) conferidos"
}

fw_limpar(){ rm -rf "${1:?}/usb_update.bin" "${1:?}/usb_update.bin.copiando" "${1:?}/$FW_NOSSO_PASTA"; }

fw_copiar(){
  local dest zip="$FW_DIR/$FW_OFICIAL_ZIP" p
  dest="$(cd "$1" && pwd)"; p="$dest/$FW_NOSSO_PASTA"
  say "copiando o firmware de resgate (o oficial e grande: leva alguns minutos)"
  if ! { unzip -p "$zip" "$FW_MEMBRO" > "$dest/usb_update.bin.copiando" \
         && mv -f "$dest/usb_update.bin.copiando" "$dest/usb_update.bin" \
         && mkdir -p "$p" \
         && cp "$FW_DIR/$FW_NOSSO_BIN" "$p/$FW_NOSSO_BIN" \
         && cp "$FW_DIR/$FW_NOSSO_LEIAME" "$p/LEIA-ME.txt"; }; then
    fw_limpar "$dest"; err "falha ao copiar o firmware (pendrive cheio, protegido ou removido?). O firmware foi removido do pendrive; NAO use este pendrive."
    return 1
  fi
  sync
  say "conferindo o firmware depois da copia"
  if [ "$(md5_de "$dest/usb_update.bin")" != "$FW_OFICIAL_MD5" ]; then
    fw_limpar "$dest"; err "usb_update.bin NAO confere com o md5 oficial $FW_OFICIAL_MD5. O firmware foi removido do pendrive; copie de novo."
    return 1
  fi
  ok "usb_update.bin (oficial V1.0.0.9, md5 $FW_OFICIAL_MD5)"
  if [ "$(md5_de "$p/$FW_NOSSO_BIN")" != "$FW_NOSSO_MD5" ] || ! cmp -s "$FW_DIR/$FW_NOSSO_LEIAME" "$p/LEIA-ME.txt"; then
    fw_limpar "$dest"; err "$FW_NOSSO_PASTA/ NAO confere com a origem. O firmware foi removido do pendrive; copie de novo."
    return 1
  fi
  ok "$FW_NOSSO_PASTA/ ($FW_NOSSO_BIN md5 $FW_NOSSO_MD5 e LEIA-ME.txt; NAO esta ativo)"
  warn "pendrive com firmware de resgate: ligar o projetor SEGURANDO O POWER com ele plugado REFLASHA o aparelho e apaga o /data. Deixe-o desconectado no uso normal (LEIA-ME.txt do kit)."
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
  plugado. Com --com-firmware leva tambem o usb_update.bin oficial (resgate).
  Ver INSTALL.md.

  NAO flashar nenhum .bin em firmware/ (quarentena).
------------------------------------------------------------
EOF
}

# --- main ---
if [ "$CONFERIR_FW" = "1" ]; then
  fw_conferir ""
  exit $?
fi
if [ -n "$PENDRIVE_DIR" ]; then
  # com firmware, as origens sao conferidas ANTES de copiar o kit: nada vai pela metade
  if [ "$COM_FIRMWARE" = "1" ]; then fw_conferir "$PENDRIVE_DIR" || exit 1; fi
  copiar_pendrive "$PENDRIVE_DIR" || exit 1
  if [ "$COM_FIRMWARE" = "1" ]; then fw_copiar "$PENDRIVE_DIR" || exit 1; fi
  exit 0
fi
OS="$(detect_os)"
say "PFL7560 — setup do PC ($OS)"
chmod_scripts

if [ "$CHECK_ONLY" = "1" ]; then
  verify
  exit $?
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
  # ainda tenta nmap se faltar e houver gerenciador (nao fatal)
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
if verify; then
  ok "setup do PC concluido"
  print_next
  exit 0
else
  err "setup incompleto — veja requirements e REQUIREMENTS.md"
  print_next
  exit 1
fi
