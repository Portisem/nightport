#!/bin/bash
# Importa D3DMetal (Apple Game Porting Toolkit) a un motor ya armado.
#
# D3DMetal es software propietario de Apple: Nightport NO lo incluye ni lo redistribuye.
# Cada usuario lo descarga de https://developer.apple.com/games/ (cuenta de Apple gratuita),
# acepta la licencia de Apple y lo importa en su propia Mac con este script.
#
# Imports Apple's D3DMetal (GPTK) into an engine. Nightport never ships it: each user downloads
# it from Apple, accepts Apple's license and imports it locally.
#
# Uso / usage: scripts/import-gptk.sh [carpeta-redist-lib] [carpeta-del-motor]
#   carpeta-redist-lib: la carpeta "redist/lib" del DMG de Apple, o una copia ya importada.
#   Por defecto busca el DMG montado y luego ~/Library/Application Support/GamingMac/Components/gptk-*/lib
set -euo pipefail

R="${GMAC_BUILD_ROOT:-$HOME/.gamingmac}"
SUPPORT="$HOME/Library/Application Support/GamingMac"

SRC="${1:-}"
if [ -z "$SRC" ]; then
    for c in /Volumes/Evaluation\ environment\ for\ Windows\ games*/redist/lib "$SUPPORT"/Components/gptk-*/lib; do
        [ -d "$c/wine" ] && SRC="$c" && break
    done
fi
PREFIX="${2:-$R/engines/cx26}"

[ -n "$SRC" ] && [ -d "$SRC/wine" ] && [ -d "$SRC/external" ] || {
    echo "No encuentro D3DMetal. Descarga el Game Porting Toolkit de Apple, monta el DMG y vuelve a correr:"
    echo "  scripts/import-gptk.sh \"/Volumes/Evaluation environment for Windows games 3.0/redist/lib\""
    exit 1
}
[ -x "$PREFIX/bin/wine" ] || { echo "No hay un motor en $PREFIX"; exit 1; }

echo "→ D3DMetal desde $SRC"
G="$PREFIX/lib64/apple_gptk"
rm -rf "$G"
mkdir -p "$G"
cp -a "$SRC/external" "$SRC/wine" "$G/"
# Read Me de Apple: MetalFX se activa renombrando nvngx-on-metalfx → nvngx
[ -e "$G/wine/x86_64-unix/nvngx-on-metalfx.so" ] && mv "$G/wine/x86_64-unix/nvngx-on-metalfx.so" "$G/wine/x86_64-unix/nvngx.so"
[ -e "$G/wine/x86_64-windows/nvngx-on-metalfx.dll" ] && mv "$G/wine/x86_64-windows/nvngx-on-metalfx.dll" "$G/wine/x86_64-windows/nvngx.dll"
# Los .so usan @rpath=@loader_path para libd3dshared.dylib
ln -sf ../../external/libd3dshared.dylib "$G/wine/x86_64-unix/libd3dshared.dylib"
# La licencia de Apple pide conservar sus avisos en cada copia
for f in License.rtf License.pdf Acknowledgements.rtf "Read Me.rtf"; do
    [ -e "$SRC/../$f" ] && cp "$SRC/../$f" "$G/" || true
done
echo "D3DMetal importado en $G"
