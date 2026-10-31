#!/usr/bin/env bash
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
