# Contributing / Contribuir

[English](#english) · [Español](#español)

## English

Thanks for helping! Nightport is a personal project maintained in spare time, so small, focused
contributions are easiest to review.

**Most useful contributions**

1. **Compatibility reports**: use the *Compatibility report* issue form. Include your Mac (chip,
   memory), macOS version, the translator you used and what happened.
2. **Game profiles**: a pull request adding `profiles/<game-id>.json` (see
   [docs/PROFILES.md](docs/PROFILES.md)). Say how you measured it (scene, FPS average, 1% low).
3. **Bug fixes** in the app, the CLI or the scripts.
4. **Wine patches**: keep them minimal, one topic per patch, with a comment explaining why.

**Rules**

- No piracy: issues or PRs about cracks, keygens or bypassing DRM or anti-cheat are closed.
- Never commit proprietary files: CrossOver binaries or databases, Apple's GPTK/D3DMetal, Steam,
  game files or executables.
- Before attaching logs, remove personal information (your macOS username appears in paths).
- Run `swift build` before sending a PR.

**Sign-off (DCO)**: by contributing you certify you have the right to submit your work under the
project's licenses ([Developer Certificate of Origin](https://developercertificate.org/)). Add a
`Signed-off-by` line to your commits with `git commit -s`.

Licenses: code under GPL-3.0-or-later, profiles under CC BY-SA 4.0.

## Español

¡Gracias por ayudar! Nightport es un proyecto personal que se mantiene en tiempo libre, así que las
contribuciones pequeñas y enfocadas son las más fáciles de revisar.

**Lo que más ayuda**

1. **Reportes de compatibilidad**: usa el formulario *Reporte de compatibilidad*. Incluye tu Mac
   (chip, memoria), versión de macOS, el traductor que usaste y qué pasó.
2. **Perfiles de juegos**: un pull request que agregue `profiles/<id-del-juego>.json` (ver
   [docs/PROFILES.md](docs/PROFILES.md)). Indica cómo lo mediste (escena, FPS promedio, 1 % low).
3. **Correcciones** en la app, la CLI o los scripts.
4. **Parches de Wine**: mínimos, un tema por parche, con un comentario que explique por qué.

**Reglas**

- Nada de piratería: se cierran issues o PRs sobre cracks, keygens o evadir DRM o anti-cheat.
- Nunca subas archivos propietarios: binarios o bases de datos de CrossOver, GPTK/D3DMetal de Apple,
  Steam, archivos o ejecutables de juegos.
- Antes de adjuntar logs, quita tu información personal (tu usuario de macOS aparece en las rutas).
- Corre `swift build` antes de mandar un PR.

**Firma (DCO)**: al contribuir certificas que tienes derecho a aportar tu trabajo bajo las licencias
del proyecto ([Developer Certificate of Origin](https://developercertificate.org/)). Agrega la línea
`Signed-off-by` a tus commits con `git commit -s`.

Licencias: código GPL-3.0-or-later, perfiles CC BY-SA 4.0.
