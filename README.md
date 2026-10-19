# Nightport

> Tus juegos de Windows, en casa en tu Mac. (Código interno: GamingMac)

Lanzador personal de juegos de Windows para macOS (Apple Silicon), construido sobre piezas
abiertas: Wine (fuentes FOSS de CrossOver), DXMT, DXVK y MoltenVK, más D3DMetal de Apple
(GPTK, lo provee el usuario). Cada juego tiene un **perfil curado** con el traductor gráfico y
los ajustes que mejor le funcionan, medidos con benchmarks.

## App

```bash
scripts/build-app.sh   # instala ~/Applications/Nightport.app
```

Mientras la app está abierta, cada partida de la biblioteca (lanzada desde Nightport o desde
Steam) se graba en `~/Library/Application Support/GamingMac/Sessions/` y se resume en
**Actividad** con sugerencias. Los FPS se miden con wined3d (traza `fps` de Wine); con
D3DMetal/DXMT por ahora solo CPU, GPU, memoria y temperatura. Nada sale de la Mac.

Marca, tokens y mockups en `brand/`.

## CLI

```bash
swift build
.build/debug/gmac doctor                 # estado del sistema
.build/debug/gmac profiles               # juegos con perfil
.build/debug/gmac run halo-mcc --dry-run # muestra exactamente cómo se lanzaría
.build/debug/gmac run halo-mcc --backend d3dmetal --hud
.build/debug/gmac check left-4-dead-2     # ¿qué tan bien correría en esta Mac?
.build/debug/gmac steam games Steam      # juegos instalados en el Steam del bottle
.build/debug/gmac monitor left-4-dead-2   # graba la sesión de un juego abierto (FPS, CPU, GPU, memoria)
.build/debug/gmac sessions               # sesiones grabadas y sugerencias
```

## Documentación

- [docs/FASE0.md](docs/FASE0.md): estrategia, orden de juegos y cómo superar a CrossOver
- [docs/JUEGOS.md](docs/JUEGOS.md): matriz de compatibilidad de la biblioteca
- [docs/MOTOR.md](docs/MOTOR.md): cómo se construye el motor
- `profiles/`: perfiles por juego (`_defaults.json` + uno por juego)

`Contents/` es una copia de CrossOver usada solo como referencia. Está en `.gitignore` y nunca se redistribuye.
