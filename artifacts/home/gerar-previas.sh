#!/usr/bin/env bash
# artifacts/home/gerar-previas.sh - previas 1920x1080 da home, renderizadas no PC.
#
#   bash artifacts/home/gerar-previas.sh
#
# Compila o codigo de desenho do app (os arquivos Java puros de src/: Pintor, Tema, Item, Icones,
# Acoes, Modelo, Desenho) junto com o pintor Java2D de previa-src/ e grava os PNG em
# artifacts/home/previa/. Usa as fontes do kit (pendrive-autorun/fontes). Tambem confere a
# navegacao do D-pad. Precisa so de java/javac (17); roda sem tela (java.awt.headless).
set -euo pipefail
export LC_ALL=C TZ=UTC

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
SRC="$AQUI/src/com/pfl7560/home"
B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT

javac --release 8 -Xlint:-options -encoding UTF-8 -d "$B" \
  "$SRC/Pintor.java" "$SRC/Tema.java" "$SRC/Item.java" "$SRC/Icones.java" "$SRC/Acoes.java" \
  "$SRC/Modelo.java" "$SRC/Desenho.java" \
  "$AQUI"/previa-src/com/pfl7560/home/previa/*.java
java -Djava.awt.headless=true -cp "$B" com.pfl7560.home.previa.Previa \
  "$RAIZ/pendrive-autorun/fontes" "$AQUI/previa"
