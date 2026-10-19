# Game profiles / Perfiles de juegos

[English](#english) · [Español](#español)

## English

A profile is a JSON file in `profiles/` named after its `id`. Any field you leave out is inherited
from `profiles/_defaults.json`. Profiles are licensed under CC BY-SA 4.0.

```json
{
  "id": "halo-mcc",
  "name": "Halo: The Master Chief Collection",
  "steamAppId": 976730,
  "status": "probando",
  "api": "DX11 (64-bit)",
  "launch": { "mode": "exe", "exe": "Halo The Master Chief Collection\\MCC\\Binaries\\Win64\\MCC-Win64-Shipping.exe" },
  "graphics": { "backend": "dxmt", "candidates": ["dxmt", "d3dmetal"] },
  "notes": ["Launching the exe directly runs without anti-cheat: campaign and custom games work, matchmaking doesn't."]
}
```

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Unique id, same as the file name (`kebab-case`) |
| `name` | string | Display name |
| `steamAppId` | number | Steam App ID (links the profile to the installed game) |
| `status` | string | `verificado`/`funciona`/`excelente` (works great), `jugable` (playable), `probando` (testing), `pendiente` (untested), `bloqueado`/`anti-cheat` (blocked) |
| `api` | string | Graphics API and bitness, for humans |
| `launch.mode` | `steam` \| `exe` | `steam`: Steam launches it like its Play button. `exe`: run the executable directly |
| `launch.exe` | string | Windows path, or relative to `steamapps/common` |
| `launch.args` | [string] | Extra arguments |
| `graphics.backend` | `d3dmetal` \| `dxmt` \| `dxvk` \| `wined3d` | Translator to use |
| `graphics.candidates` | [string] | Other translators worth benchmarking |
| `sync` | `msync` \| `esync` \| `none` | Wine synchronization mode |
| `rosettaAVX` | bool | Expose AVX through Rosetta |
| `retina` | bool | Wine's Retina mode |
| `metalHUD` | bool | Show Apple's Metal performance HUD |
| `metalFX` | bool | D3DMetal: translate DLSS to MetalFX |
| `dxr` | bool | D3DMetal: expose DirectX Raytracing |
| `windowsVersion` | string | e.g. `win10` |
| `wineDebug` | string | `WINEDEBUG` channels |
| `env` | object | Extra environment variables |
| `dllOverrides` | object | Wine DLL overrides |
| `notes` | [string] | What you found, how you measured, known issues |

**Measuring before submitting:** use a fixed scene (a save, 60–120 s), run it with each candidate
translator (`gmac run <id> --backend <b> --hud`) and note the FPS average and 1% low. Mention your
Mac and macOS version in the PR.

## Español

Un perfil es un archivo JSON en `profiles/` con el nombre de su `id`. Lo que no pongas se hereda de
`profiles/_defaults.json`. Los perfiles están bajo CC BY-SA 4.0.

Los campos son los de la tabla de arriba. En resumen:

- `status`: `verificado`/`funciona`/`excelente`, `jugable`, `probando`, `pendiente`,
  `bloqueado`/`anti-cheat`.
- `launch.mode`: `steam` (lo lanza Steam como su botón Jugar) o `exe` (el ejecutable directo).
- `graphics.backend`: `d3dmetal`, `dxmt`, `dxvk` o `wined3d`; `graphics.candidates`: otros que vale
  la pena comparar.
- `metalFX` y `dxr` solo aplican con D3DMetal.
- `notes`: qué encontraste, cómo lo mediste y problemas conocidos.

**Mide antes de mandarlo:** escena fija (un save, 60–120 s), córrela con cada traductor candidato
(`gmac run <id> --backend <b> --hud`) y anota FPS promedio y 1 % low. Indica tu Mac y versión de
macOS en el PR.
