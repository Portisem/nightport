# The engine

[Español](../MOTOR.md)

## Decision: build Wine from CodeWeavers' CrossOver 26.3 free sources

| Option | Pros | Cons |
|---|---|---|
| **A. CrossOver 26.3 FOSS sources** ✅ | Same Wine CrossOver ships (Wine 11 + CX patches: D3DMetal support, `CX_GRAPHICS_BACKEND`, msync). Fair comparison with CrossOver. Base for our own patches. Legal and redistributable (LGPL) | Must be compiled (30–60 min the first time) with an x86_64 toolchain |
| B. WineHQ Wine (Gcenx builds, 11.x) | Direct download, very current | No CX patches: **D3DMetal doesn't work** (rules out DX12 games like Wukong) |
| C. The Wine inside an installed CrossOver | Zero work | Proprietary binaries: not redistributable and can't be patched. Only useful as a baseline |

`gmac` supports both engine flavors (`flavor: crossover | upstream`), so B remains a fallback for
DX9–DX11 games.

## Toolchain without Homebrew

Homebrew no longer installs in x86_64 mode on Apple Silicon (Intel moved to Tier 3 in 2026). We use
**micromamba + conda-forge (`osx-64`)**: prebuilt x86_64 packages in an isolated folder, no `sudo`,
easy to delete.

| Piece | Source |
|---|---|
| micromamba (arm64) | GitHub mamba-org/micromamba-releases |
| freetype, gnutls, SDL2, GStreamer, MoltenVK, bison, flex, pkg-config, libpng, krb5 (x86_64) | conda-forge `osx-64` |
| llvm-mingw (PE DLL compiler) | GitHub mstorsjo/llvm-mingw |
| Wine CX 26.3 | media.codeweavers.com (`crossover-sources-26.3.0.tar.gz`) |
| DXMT 0.80 (builtin) | GitHub 3Shain/dxmt |
| D3DMetal | Apple's Game Porting Toolkit, downloaded by each user → `scripts/import-gptk.sh` (never redistributed) |

## Steps

1. Toolchain and sources: `scripts/fetch-deps.sh`.
2. Build Wine CX 26.3 (64-bit + WoW64): `scripts/build-engine.sh all` → `engines/cx26/` with a
   CrossOver-like layout.
3. `scripts/assemble-engine.sh`: `lib/dxmt` ← DXMT 0.80, x86_64 libraries, Wine Mono/Gecko;
   `lib64/apple_gptk` ← D3DMetal only if the user imported it.
   To publish: `scripts/package-engine.sh` (excludes D3DMetal, writes a SHA-256).
4. `gmac bottle create Steam`, install Steam, launch games.

## Notes from Apple's GPTK Read Me

- `D3DM_ENABLE_METALFX=1` turns on DLSS→MetalFX (off by default). It needs `nvngx.dll` (renamed from
  `nvngx-on-metalfx.dll`) and `nvapi64.dll` in the prefix's `system32`: `gmac` does it.
- `D3DM_SUPPORT_DXR` (DX12 ray tracing), on by default on M3 or later.
- Shader cache: `$(getconf DARWIN_USER_CACHE_DIR)/d3dm/<game>/shaders.cache`.
- Logs prefixed `D3DM` in Console.app (category "D3DMetal").

## Sharing an existing CrossOver library without duplicating it

Optional, for people moving from CrossOver: instead of downloading games again, the new bottle
points to the existing folders (`gmac steam link`):

- `steamapps/common/<game>` → symlink to the CrossOver bottle's folder.
- `steamapps/appmanifest_<id>.acf` → copied (Steam sees the game as installed and only verifies it).

Saves live in each bottle (`AppData`) and can be copied or linked later.

## Status

✅ `cx26` engine built and installed. ✅ Steam installed and updated in a bottle.
✅ Translators validated with `gmtest` (our own test program, `tools/gmtest`):

| Test | Translator | Adapter the game sees | Result |
|---|---|---|---|
| DX11 | DXMT 0.80 | Apple M-series GPU (FL 11_0) | ✅ 120 FPS (ProMotion cap) |
| DX11 | D3DMetal 3.0 | AMD Compatibility Mode | ✅ 120 FPS |
| DX11 | wined3d (OpenGL) | NVIDIA GeForce 8800 GTX (fake) | ✅ no vsync |
| DX12 | D3DMetal 3.0 | AMD Compatibility Mode, DXR tier 1.1 | ✅ 120 FPS |

## Findings

1. **CrossOver's translator selector is proprietary** (`cxcompatdb.so` calls `prepend_dll_path`).
   We replaced it with `WINEDLLPATH_PRIORITY` (`patches/wine/0001`).
2. **Clang ABI bug on macOS (`patches/wine/0002`)**: Apple clang assumes `BOOLEAN` parameters arrive
   extended to 32 bits; Windows programs only write the low byte. Steam passed `restart=FALSE` to
   `NtQueryDirectoryObject` with garbage in the upper bytes → Wine read `TRUE` → infinite loop
   (6 M calls in 25 s, wineserver at 60 % CPU). CrossOver has the same code; whether it is hit
   depends on what garbage is on the stack. Fixed in 36 syscalls with `gm_bool()`.
3. **winemetal (DXMT)** must live next to Wine (`lib/wine/*`) and be copied to the bottle's
   `system32`/`syswow64`; `d3d11/dxgi/d3d10core` go in `lib/dxmt` so they can be chosen per game.
4. **Wine Mono/Gecko** must ship with the engine; otherwise `wineboot` opens a dialog and waits.
5. **wineserver must start with the same `WINEMSYNC`** as the game; otherwise the game can't connect.
6. **With no active display (Mac locked or asleep) Steam freezes**, with CrossOver too.
   `gmac doctor` and `gmac run` warn about it.
7. **Black Steam UI**: `steamwebhelper` (Chromium/CEF) needs, as in CrossOver,
   `--disable-gpu --in-process-gpu --no-sandbox`. Steam doesn't expose `--in-process-gpu`, so we
   added `GMAC_APPEND_ARGS` (`patches/wine/0003`) to inject arguments per executable. With DXMT it
   fails (cross-process swapchain) and with wined3d/D3DMetal the GPU process crashes.
