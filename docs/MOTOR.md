# El motor (Fase 1)

## Decisión: compilar Wine desde las fuentes FOSS de CrossOver 26.3

| Opción | Pros | Contras |
|---|---|---|
| **A. Fuentes FOSS de CrossOver 26.3** ✅ | Mismo Wine que usas hoy (Wine 11 + parches CX: soporte D3DMetal, `CX_GRAPHICS_BACKEND`, msync). Comparación justa con CrossOver. Base para nuestros parches. Legal y redistribuible. | Hay que compilar (≈30–60 min la primera vez) y preparar toolchain x86_64. |
| B. Wine de WineHQ (builds de Gcenx, 11.x) | Descarga directa, muy actual. | Sin parches CX: **D3DMetal no funciona** (Wukong queda fuera). |
| C. Usar el Wine de tu CrossOver instalado | Cero trabajo. | Binarios propietarios: no redistribuible y no podemos parchearlo. Solo sirve como línea base. |

`gmac` ya soporta ambos tipos de motor (`flavor: crossover | upstream`), así que B queda como
plan alterno para juegos DX9–DX11 si la compilación se complica.

## Toolchain sin Homebrew

Homebrew ya no permite instalarse en modo x86_64 en Apple Silicon (Intel bajó a Tier 3 en 2026).
Usamos **micromamba + conda-forge (`osx-64`)**: paquetes x86_64 ya compilados, instalados en
una carpeta aislada (`Application Support/GamingMac/toolchain`), sin sudo y fáciles de borrar.

| Pieza | Fuente |
|---|---|
| micromamba (arm64) | GitHub mamba-org/micromamba-releases |
| freetype, gnutls, SDL2, GStreamer, MoltenVK, bison, flex, pkg-config, libpng, krb5 (x86_64) | conda-forge `osx-64` |
| llvm-mingw (compilador de DLLs PE) | GitHub mstorsjo/llvm-mingw |
| Wine CX 26.3 | media.codeweavers.com (crossover-sources-26.3.0.tar.gz) |
| DXMT 0.80 (builtin) | GitHub 3Shain/dxmt |
| D3DMetal 3.0 | GPTK 3.0 del usuario → `Components/gptk-3.0` ✅ importado |

## Pasos

1. Toolchain (micromamba + conda-forge + llvm-mingw).
2. Compilar Wine CX 26.3 (64-bit + WoW64) → `Engines/cx26/` con layout de CrossOver.
3. `lib/dxmt` ← DXMT 0.80, `lib64/apple_gptk` ← GPTK 3.0.
4. `gmac bottle create Steam`, instalar Steam, enlazar juegos existentes.

## Notas del GPTK 3.0 (Read Me de Apple)

- `D3DM_ENABLE_METALFX=1` activa DLSS→MetalFX (apagado por defecto). Requiere `nvngx.dll`
  (renombrado de `nvngx-on-metalfx.dll`) y `nvapi64.dll` en `system32` del prefix: `gmac` lo hace.
- `D3DM_SUPPORT_DXR` (raytracing DX12), por defecto encendido en M3 o posterior.
- Caché de shaders: `$(getconf DARWIN_USER_CACHE_DIR)/d3dm/<juego>/shaders.cache`.
- Logs con prefijo `D3DM` en Console.app (categoría "D3DMetal").

## Compartir juegos con CrossOver sin duplicar 186 GB

En lugar de volver a descargar, el bottle nuevo apunta a las carpetas existentes:

- `steamapps/common/<juego>` → symlink a la carpeta del bottle de CrossOver.
- `steamapps/appmanifest_<id>.acf` → copia (Steam lo reconoce como instalado y solo verifica).

Las partidas guardadas viven en cada bottle (`AppData`); se pueden copiar o enlazar después.
Cuando dejes CrossOver, movemos los juegos a una biblioteca neutral (`~/Games/SteamLibrary`).

## Estado (2026-10-10)

✅ Motor `cx26` compilado e instalado (`scripts/build-engine.sh all && scripts/assemble-engine.sh`).
✅ Bottle `Steam` creado, Steam instalado y actualizado, juegos de CrossOver enlazados.
✅ Traductores validados con `gmtest` (prueba propia, `tools/gmtest`):

| Prueba | Traductor | Adaptador que ve el juego | Resultado |
|---|---|---|---|
| DX11 | DXMT 0.80 | Apple M5 Pro (FL 11_0) | ✅ 120 FPS (tope ProMotion) |
| DX11 | D3DMetal 3.0 | AMD Compatibility Mode | ✅ 120 FPS |
| DX11 | wined3d (OpenGL) | NVIDIA GeForce 8800 GTX (falso) | ✅ sin vsync |
| DX12 | D3DMetal 3.0 | AMD Compatibility Mode, DXR tier 1.1 | ✅ 120 FPS |

⏳ Iniciar sesión en Steam y probar juegos: requiere la sesión de macOS **desbloqueada**.

## Hallazgos

1. **El selector de traductor de CrossOver es propietario** (`cxcompatdb.so` llama a `prepend_dll_path`).
   Lo reemplazamos con `WINEDLLPATH_PRIORITY` (patches/wine/0001).
2. **Bug de ABI de clang en macOS (patches/wine/0002)**: Apple clang asume que los parámetros
   `BOOLEAN` llegan extendidos a 32 bits; los programas de Windows solo escriben el byte bajo.
   Steam pasaba `restart=FALSE` a `NtQueryDirectoryObject` con basura arriba → Wine lo leía como
   `TRUE` → ciclo infinito (6 M llamadas en 25 s, wineserver al 60 % CPU). CrossOver tiene el mismo
   código; le afecta solo según qué basura quede en la pila. Corregido en 36 syscalls con `gm_bool()`.
3. **winemetal (DXMT)** debe vivir junto a Wine (`lib/wine/*`) y copiarse a `system32`/`syswow64`
   del bottle; `d3d11/dxgi/d3d10core` van en `lib/dxmt` para elegirlos por juego.
4. **Wine Mono/Gecko** deben venir en el motor; si no, `wineboot` abre un diálogo y se queda esperando.
5. **El wineserver debe arrancar con el mismo `WINEMSYNC`** que el juego; si no, el juego no conecta.
6. **Sin pantalla activa (Mac bloqueada/dormida) Steam se congela**, también con CrossOver.
   `gmac doctor` y `gmac run` ahora lo advierten.
