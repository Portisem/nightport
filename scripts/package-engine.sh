#!/bin/bash
# Empaqueta el motor para publicarlo (GitHub Releases) SIN componentes de Apple ni de CrossOver.
# Genera dist/<motor>.tar.xz + .sha256 y se niega a continuar si encuentra D3DMetal.
#
# Packages the engine for distribution WITHOUT Apple (D3DMetal) or proprietary CrossOver files.
#
# Uso / usage: scripts/package-engine.sh [carpeta-del-motor] [nombre]
set -euo pipefail

R="${GMAC_BUILD_ROOT:-$HOME/.gamingmac}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${1:-$R/engines/cx26}"
NAME="${2:-$(basename "$PREFIX")}"
OUT="$REPO/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[ -x "$PREFIX/bin/wine" ] || { echo "No hay un motor en $PREFIX"; exit 1; }

echo "→ copiando $PREFIX (sin lib64/apple_gptk)"
rsync -a --exclude 'lib64/apple_gptk' "$PREFIX/" "$STAGE/$NAME/"

# Ningún binario de Apple o de CrossOver propietario puede salir en el paquete.
BAD=$(find "$STAGE/$NAME" \( -iname '*d3dmetal*' -o -iname 'libd3dshared*' -o -iname 'cxcompatdb*' -o -iname '*.tie' \) -print)
if [ -n "$BAD" ]; then
    echo "ERROR: el paquete contiene archivos que no se pueden redistribuir:"; echo "$BAD"; exit 1
fi

cp "$REPO/LICENSE" "$REPO/THIRD_PARTY_NOTICES.md" "$STAGE/$NAME/" 2>/dev/null || true

mkdir -p "$OUT"
echo "→ comprimiendo"
tar -C "$STAGE" -cJf "$OUT/$NAME.tar.xz" "$NAME"
(cd "$OUT" && shasum -a 256 "$NAME.tar.xz" > "$NAME.tar.xz.sha256")
ls -lh "$OUT/$NAME.tar.xz"
cat "$OUT/$NAME.tar.xz.sha256"
echo
echo "Recuerda (LGPL): publica junto al motor el código fuente de Wine con patches/wine/ aplicados."
