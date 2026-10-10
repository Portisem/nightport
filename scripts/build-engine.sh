#!/bin/bash
# Compila Wine (fuentes FOSS de CrossOver 26.3) para macOS x86_64 (Rosetta) con WoW64 i386.
# Toolchain sin Homebrew: conda-forge osx-64 (micromamba) + llvm-mingw. Ver docs/MOTOR.md.
#
# Uso: scripts/build-engine.sh [configure|build|install|all]
set -euo pipefail

R="${GMAC_BUILD_ROOT:-$HOME/.gamingmac}"
SRC="$R/build/src/sources/wine"
B="$R/build/wine"
PREFIX="$R/engines/cx26"
TC="$R/toolchain/x86"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

# llvm-mingw va al final: trae su propio "clang" que no conoce el SDK de macOS
export PATH="$TC/bin:/usr/bin:/bin:/usr/sbin:/sbin:$R/toolchain/llvm-mingw/bin"
export MACOSX_DEPLOYMENT_TARGET=13.0
export CC="/usr/bin/clang -arch x86_64"
export CXX="/usr/bin/clang++ -arch x86_64"
export OBJC="/usr/bin/clang -arch x86_64"
export CFLAGS="-O2 -Wno-implicit-function-declaration -Wno-deprecated-declarations -Wno-format -Wno-incompatible-pointer-types -Wno-int-conversion"
export CROSSCFLAGS="-O2"
export CPPFLAGS="-I$TC/include"
# rpath: herramientas de build (sfnt2fon) enlazan freetype con @rpath
export LDFLAGS="-L$TC/lib -Wl,-rpath,$TC/lib -Wl,-headerpad_max_install_names"
export PKG_CONFIG_PATH="$TC/lib/pkgconfig:$TC/share/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"

apply_patches() {
    for p in "$REPO"/patches/wine/*.patch; do
        if patch -d "$SRC" -p1 -R --dry-run -s -f < "$p" >/dev/null 2>&1; then
            echo "parche ya aplicado: $(basename "$p")"
        else
            patch -d "$SRC" -p1 -s < "$p" && echo "parche aplicado: $(basename "$p")"
        fi
    done
}

do_configure() {
    apply_patches
    mkdir -p "$B"
    cd "$B"
    arch -x86_64 "$SRC/configure" \
        --prefix="$PREFIX" \
        --enable-archs=i386,x86_64 \
        --disable-tests \
        --without-alsa --without-capi --without-dbus --without-oss --without-pulse \
        --without-udev --without-v4l2 --without-x --without-wayland \
        --without-sane --without-gphoto --without-pcap \
        --with-freetype --with-gnutls --with-sdl --with-vulkan --with-gstreamer \
        --with-coreaudio --with-opencl --with-krb5
}

do_build() {
    cd "$B"
    arch -x86_64 make -j"$(sysctl -n hw.ncpu)"
}

do_install() {
    cd "$B"
    arch -x86_64 make install
}

case "${1:-all}" in
    configure) do_configure ;;
    build) do_build ;;
    install) do_install ;;
    all) do_configure && do_build && do_install ;;
esac
