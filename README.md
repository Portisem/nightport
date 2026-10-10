# GamingMac

Lanzador personal de juegos de Windows para macOS (Apple Silicon), construido sobre piezas
abiertas: Wine (fuentes FOSS de CrossOver), DXMT, DXVK y MoltenVK, más D3DMetal de Apple
(GPTK, lo provee el usuario). Cada juego tiene un **perfil curado** con el traductor gráfico y
los ajustes que mejor le funcionan, medidos con benchmarks.

## Uso

```bash
swift build
.build/debug/gmac doctor                 # estado del sistema
.build/debug/gmac profiles               # juegos con perfil
.build/debug/gmac run halo-mcc --dry-run # muestra exactamente cómo se lanzaría
.build/debug/gmac run halo-mcc --backend d3dmetal --hud
```

## Documentación

- [docs/FASE0.md](docs/FASE0.md): estrategia, orden de juegos y cómo superar a CrossOver
- [docs/JUEGOS.md](docs/JUEGOS.md): matriz de compatibilidad de la biblioteca
- [docs/MOTOR.md](docs/MOTOR.md): cómo se construye el motor
- `profiles/`: perfiles por juego (`_defaults.json` + uno por juego)

`Contents/` es una copia de CrossOver usada solo como referencia. Está en `.gitignore` y nunca se redistribuye.
