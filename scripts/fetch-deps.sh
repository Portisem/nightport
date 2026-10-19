#!/bin/bash
# Descarga todo lo necesario para compilar el motor (sin Homebrew, sin sudo).
#   micromamba + conda-forge osx-64 (dependencias x86_64), llvm-mingw, fuentes FOSS de CrossOver,
#   DXMT (builtin) y Wine Mono/Gecko. Todo queda en $GMAC_BUILD_ROOT (por defecto ~/.gamingmac).
# Nada de esto es de Apple: D3DMetal (GPTK) se importa aparte con scripts/import-gptk.sh.
#
# Downloads everything needed to build the engine. Apple's D3DMetal is NOT fetched here.
set -euo pipefail

R="${GMAC_BUILD_ROOT:-$HOME/.gamingmac}"
CX_VERSION="26.3.0"
DXMT_VERSION="v0.80"
LLVM_MINGW="20261006"
MONO="10.4.1"
GECKO="2.47.4"

mkdir -p "$R"/dl/{micromamba,llvm-mingw,crossover,dxmt,addons} "$R"/toolchain "$R"/build/src

get() { [ -f "$2" ] || curl -fL --retry 3 -o "$2" "$1"; }

echo "→ micromamba"
get https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-osx-arm64 "$R/dl/micromamba/micromamba"
chmod +x "$R/dl/micromamba/micromamba"

echo "→ llvm-mingw $LLVM_MINGW"
LM="llvm-mingw-$LLVM_MINGW-ucrt-macos-universal"
get "https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW/$LM.tar.xz" "$R/dl/llvm-mingw/$LM.tar.xz"
if [ ! -d "$R/toolchain/llvm-mingw" ]; then
    tar -xJf "$R/dl/llvm-mingw/$LM.tar.xz" -C "$R/toolchain"
    mv "$R/toolchain/$LM" "$R/toolchain/llvm-mingw"
fi

echo "→ fuentes FOSS de CrossOver $CX_VERSION (Wine LGPL)"
get "https://media.codeweavers.com/pub/crossover/source/crossover-sources-$CX_VERSION.tar.gz" "$R/dl/crossover/crossover-sources-$CX_VERSION.tar.gz"
[ -d "$R/build/src/sources/wine" ] || tar -xzf "$R/dl/crossover/crossover-sources-$CX_VERSION.tar.gz" -C "$R/build/src"

echo "→ DXMT $DXMT_VERSION"
get "https://github.com/3Shain/dxmt/releases/download/$DXMT_VERSION/dxmt-$DXMT_VERSION-builtin.tar.gz" "$R/dl/dxmt/dxmt-$DXMT_VERSION-builtin.tar.gz"
mkdir -p "$R/dl/dxmt/x"
[ -d "$R/dl/dxmt/x/$DXMT_VERSION" ] || tar -xzf "$R/dl/dxmt/dxmt-$DXMT_VERSION-builtin.tar.gz" -C "$R/dl/dxmt/x"

echo "→ Wine Mono $MONO / Gecko $GECKO"
get "https://dl.winehq.org/wine/wine-mono/$MONO/wine-mono-$MONO-x86.tar.xz" "$R/dl/addons/wine-mono-$MONO-x86.tar.xz"
for a in x86 x86_64; do
    get "https://dl.winehq.org/wine/wine-gecko/$GECKO/wine-gecko-$GECKO-$a.tar.xz" "$R/dl/addons/wine-gecko-$GECKO-$a.tar.xz"
done

echo "→ dependencias x86_64 (conda-forge osx-64)"
export MAMBA_ROOT_PREFIX="$R/toolchain/mamba"
[ -d "$R/toolchain/x86" ] || "$R/dl/micromamba/micromamba" create -y -p "$R/toolchain/x86" --platform osx-64 -c conda-forge \
    freetype gnutls sdl2 gstreamer gst-plugins-base gst-plugins-good moltenvk libpng krb5 \
    bison flex pkg-config make autoconf automake libtool gettext

echo "Listo. Siguiente: scripts/build-engine.sh all && scripts/assemble-engine.sh"
