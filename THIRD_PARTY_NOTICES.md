# Third-party notices / Avisos de terceros

Nightport's own source code is licensed under the **GNU GPL v3.0 or later** (see `LICENSE`).
Game profiles in `profiles/` are licensed under **CC BY-SA 4.0** (see `profiles/LICENSE`).
The Nightport name, logo and icon are **not** covered by those licenses (see `TRADEMARKS.md`).

The repository does not contain third-party binaries. The scripts in `scripts/` download and
build the components below; the resulting *engine* package bundles them under their own licenses.

El código propio de Nightport es GPL-3.0-or-later. Los perfiles son CC BY-SA 4.0. El nombre, logo e
ícono no están cubiertos por esas licencias. El repositorio no contiene binarios de terceros: los
scripts descargan y compilan los componentes de abajo, cada uno con su propia licencia.

## Engine components / Componentes del motor

| Component | License | Source |
|---|---|---|
| Wine (from CodeWeavers' CrossOver 26.3 FOSS sources) + Nightport patches in `patches/wine/` | LGPL-2.1-or-later | https://media.codeweavers.com/pub/crossover/source/ |
| DXMT | LGPL-2.1-or-later | https://github.com/3Shain/dxmt |
| DXVK (supported by the launcher; not bundled in the `cx26` engine yet) | Zlib | https://github.com/doitsujin/dxvk |
| MoltenVK | Apache-2.0 | https://github.com/KhronosGroup/MoltenVK |
| Wine Mono | Various free licenses (MIT, LGPL and others, see its COPYING) | https://github.com/madewokherd/wine-mono |
| Wine Gecko | MPL-2.0 | https://gitlab.winehq.org/wine/wine-gecko |
| llvm-mingw (build tool) | Apache-2.0 WITH LLVM-exception; mingw-w64 runtime: ZPL/public domain | https://github.com/mstorsjo/llvm-mingw |

### Libraries from conda-forge (osx-64) / Bibliotecas de conda-forge

| Library | License |
|---|---|
| FreeType | FTL or GPL-2.0-only |
| GnuTLS, libtasn1, glib, libintl | LGPL-2.1-or-later |
| nettle, gmp | LGPL-3.0-or-later or GPL-2.0-or-later |
| libunistring | LGPL-3.0-only or GPL-3.0-only |
| GStreamer, gst-plugins-base, gst-plugins-good | LGPL-2.0-or-later |
| libiconv, mpg123 | LGPL-2.1-only |
| lame, libidn2 | LGPL-2.0-only |
| SDL2, zlib | Zlib |
| libpng | libpng/zlib |
| libjpeg-turbo | IJG, BSD-3-Clause, Zlib |
| libogg, libvorbis, libopus, libvpx, pcre2, zstd | BSD-3-Clause |
| krb5, libffi, libexpat, libxml2, p11-kit | MIT |
| OpenSSL | Apache-2.0 |
| libc++ | Apache-2.0 WITH LLVM-exception |
| bzip2 | bzip2-1.0.6 |

**LGPL compliance:** every engine release is published together with the corresponding Wine
source code with `patches/wine/*.patch` applied, and the build scripts in `scripts/`.

**Cumplimiento LGPL:** cada motor publicado va acompañado del código fuente de Wine con los parches
de `patches/wine/` aplicados y de los scripts de compilación.

## Fonts / Fuentes

Unbounded, Manrope and JetBrains Mono, under the SIL Open Font License 1.1
(`brand/fonts/OFL-*.txt`).

## Not included / No incluido

- **Apple D3DMetal (Game Porting Toolkit)** is proprietary Apple software. Nightport does **not**
  include or redistribute it. Each user downloads it from Apple, accepts Apple's license and
  imports it locally (`scripts/import-gptk.sh`). D3DMetal es software de Apple: Nightport no lo
  incluye; cada usuario lo descarga de Apple y lo importa en su Mac.
- **CrossOver** binaries, UI, scripts and compatibility database (CodeWeavers, proprietary).
  Nightport only uses the free sources that CodeWeavers publishes.
- **Steam** (Valve). The app downloads the official installer from Valve when the user asks for it.
- Games. Users run their own legally obtained copies.

Nightport is not affiliated with Apple, Microsoft, Valve or CodeWeavers. All trademarks belong to
their respective owners. / Nightport no está afiliado a Apple, Microsoft, Valve ni CodeWeavers.
