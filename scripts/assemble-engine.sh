#!/bin/bash
# Arma el motor instalado (make install) con sus dependencias y traductores gráficos.
#   lib64/                 dylibs x86_64 (freetype, gnutls, SDL2, MoltenVK, GStreamer…)
#   lib/dxmt/              DXMT (builtin): x86_64-windows, i386-windows, x86_64-unix
#   lib64/apple_gptk/      D3DMetal (GPTK 3.0): external/ + wine/{x86_64-windows,x86_64-unix}
#   engine.json            manifiesto para gmac
set -euo pipefail

R="${GMAC_BUILD_ROOT:-$HOME/.gamingmac}"
PREFIX="$R/engines/cx26"
TC="$R/toolchain/x86"
DXMT="$R/dl/dxmt/x/v0.80"
GPTK="$HOME/Library/Application Support/GamingMac/Components/gptk-3.0/lib"
LINK="$HOME/Library/Application Support/GamingMac/Engines/cx26"

[ -x "$PREFIX/bin/wine" ] || { echo "Falta make install en $PREFIX"; exit 1; }

echo "→ dependencias x86_64"
mkdir -p "$PREFIX/lib64"
cp -a "$TC"/lib/*.dylib "$PREFIX/lib64/"
rm -rf "$PREFIX/lib64/gstreamer-1.0"
cp -a "$TC/lib/gstreamer-1.0" "$PREFIX/lib64/gstreamer-1.0"
# Wine abre libvulkan.1.dylib: MoltenVK exporta la API de Vulkan directamente
[ -e "$PREFIX/lib64/libvulkan.1.dylib" ] || ln -sf libMoltenVK.dylib "$PREFIX/lib64/libvulkan.1.dylib"

echo "→ DXMT $(basename "$DXMT")"
rm -rf "$PREFIX/lib/dxmt"
mkdir -p "$PREFIX/lib/dxmt"
cp -a "$DXMT"/x86_64-windows "$DXMT"/i386-windows "$PREFIX/lib/dxmt/"
# winemetal enlaza @rpath/ntdll.so y winemac.so (@loader_path): debe vivir junto a Wine, como en CrossOver.
# En lib/dxmt quedan solo d3d11/dxgi/d3d10core/nvngx/nvapi64, que se eligen con WINEDLLPATH_PRIORITY.
cp "$DXMT/x86_64-unix/winemetal.so" "$PREFIX/lib/wine/x86_64-unix/"
cp "$DXMT/x86_64-windows/winemetal.dll" "$PREFIX/lib/wine/x86_64-windows/"
cp "$DXMT/i386-windows/winemetal.dll" "$PREFIX/lib/wine/i386-windows/"
rm -f "$PREFIX"/lib/dxmt/*/winemetal.dll

echo "→ D3DMetal (GPTK 3.0)"
G="$PREFIX/lib64/apple_gptk"
rm -rf "$G"
mkdir -p "$G"
cp -a "$GPTK/external" "$GPTK/wine" "$G/"
# Read Me de Apple: activar MetalFX renombrando nvngx-on-metalfx → nvngx
mv "$G/wine/x86_64-unix/nvngx-on-metalfx.so" "$G/wine/x86_64-unix/nvngx.so"
mv "$G/wine/x86_64-windows/nvngx-on-metalfx.dll" "$G/wine/x86_64-windows/nvngx.dll"
# Los .so usan @rpath=@loader_path para libd3dshared.dylib
ln -sf ../../external/libd3dshared.dylib "$G/wine/x86_64-unix/libd3dshared.dylib"

echo "→ Wine Mono / Gecko (evita el diálogo de instalación al crear bottles)"
ADD="$R/dl/addons"
mkdir -p "$PREFIX/share/wine/mono" "$PREFIX/share/wine/gecko"
[ -d "$PREFIX/share/wine/mono/wine-mono-10.4.1" ] || tar -xJf "$ADD/wine-mono-10.4.1-x86.tar.xz" -C "$PREFIX/share/wine/mono"
[ -d "$PREFIX/share/wine/gecko/wine-gecko-2.47.4-x86" ] || tar -xJf "$ADD/wine-gecko-2.47.4-x86.tar.xz" -C "$PREFIX/share/wine/gecko"
[ -d "$PREFIX/share/wine/gecko/wine-gecko-2.47.4-x86_64" ] || tar -xJf "$ADD/wine-gecko-2.47.4-x86_64.tar.xz" -C "$PREFIX/share/wine/gecko"

cat > "$PREFIX/engine.json" <<EOF
{
  "name": "cx26",
  "flavor": "crossover",
  "wineVersion": "11.0 (CrossOver 26.3 FOSS + parches GamingMac)",
  "notes": "DXMT $(basename "$DXMT"), D3DMetal 3.0"
}
EOF

mkdir -p "$(dirname "$LINK")"
ln -sfn "$PREFIX" "$LINK"
echo "Motor listo: $LINK → $PREFIX"
du -sh "$PREFIX"
