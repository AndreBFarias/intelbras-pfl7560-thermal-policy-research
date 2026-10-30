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
#    ./install.sh --help
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
case "${1:-}" in
  -h|--help)
    sed -n '2,18p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  --check|-c) CHECK_ONLY=1 ;;
  --pendrive|-p)
    PENDRIVE_DIR="${2:-}"
    [ -n "$PENDRIVE_DIR" ] || { echo "uso: $0 --pendrive <pasta-raiz-do-pendrive>"; exit 1; }
    ;;
  "") ;;
  *) echo "uso: $0 [--check|--pendrive DIR|--help]"; exit 1 ;;
esac

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
# Copia o kit COMPLETO para a RAIZ do pendrive (newlink_update.sh, cor.sh, lvdsctl,
# nl_camcheck, nl_tela, ZYCustom.ini, LEIA-ME.txt, kit/*.png e fontes/*) e confere, depois da copia, o md5 de cada
# arquivo contra a lista embutida no proprio newlink_update.sh (a mesma que o
# aparelho confere antes de escrever). O newlink_update.sh nao esta na lista (nao
# pode conter o proprio md5) e o LEIA-ME.txt tambem nao: os dois sao comparados byte
# a byte com a origem. NAO grava nada no projetor.
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
  plugado. Ver INSTALL.md.

  NAO flashar nenhum .bin em firmware/ (quarentena).
------------------------------------------------------------
EOF
}

# --- main ---
if [ -n "$PENDRIVE_DIR" ]; then
  copiar_pendrive "$PENDRIVE_DIR"
  exit $?
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
