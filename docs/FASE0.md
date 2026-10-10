# Fase 0: Estrategia

## 1. ¿Empezar por los AAA o por los viejos?

**Ninguno de los dos en estado puro.** Usamos un enfoque de "bala trazadora": un set pequeño
que atraviesa todas las capas del sistema, con los juegos que más juegas como estrella polar.

| Orden | Juego | Por qué |
|---|---|---|
| 1 | **IT Specialist Simulator** | Prueba de humo: ligero (2.5 GB), DX11/Unity. Valida motor + bottle + Steam + lanzador de punta a punta. Si falla, el problema es nuestro y no del juego. |
| 2 | **Halo MCC** | Lo juegas y funciona mal = mayor ganancia posible. DX11 → podemos elegir traductor (DXMT vs D3DMetal), y ahí sí podemos superar a CrossOver. |
| 3 | **Black Myth: Wukong** | El más pesado (DX12/UE5). Solo D3DMetal (cerrado), así que la mejora viene de ritmo de frames, cachés y ajustes del juego, no del traductor. |
| 4 | **Familia Valve/GoldSrc/Source (⊘)** | ~20 juegos que macOS ya no corre nativos. Un solo trabajo (soporte 32-bit + OpenGL/DX9) habilita muchos. Mejor relación esfuerzo/juegos. |
| 5 | **Launchers de terceros** | AC3 (Ubisoft Connect), Dead Space / RA3 / Mirror's Edge / MoH (EA app). Cada launcher es su propio problema. |

**Por qué no "AAA primero":** sin infraestructura de medición, no sabríamos si mejoramos o empeoramos.
**Por qué no "viejos primero":** los viejos no estresan GPU/shaders y te dejarían sin poder jugar lo que juegas hoy.

Juegos con **versión nativa de Mac**: Cyberpunk 2077, Civ VI, Dota 2, Warframe, LOTRO, Realm of the Mad God,
Rust, Garry's Mod. Por defecto se quedan nativos: casi siempre rinden mejor que traducidos. Los
evaluamos solo si el nativo falla.

**Límite que nadie puede romper:** los anti-cheat a nivel kernel o con módulo solo para Windows
(EAC/BattlEye sin soporte Wine). Rust online y el matchmaking de Halo MCC quedan fuera. MCC sí
corre campaña, Forge y custom en modo sin anti-cheat.

## 2. ¿Cómo superamos a CrossOver?

CrossOver es una muy buena base genérica. Nuestra ventaja es **curar juego por juego y medir**.

1. **Medir antes de optimizar.** Escena fija (un save, 60–120 s), registrar FPS promedio, 1% low y
   varianza de frametime. Línea base = el mismo juego en CrossOver. Sin número, no hay mejora.
2. **Traductor por juego, elegido con datos.** CrossOver usa un default por bottle; nosotros
   probamos D3DMetal / DXMT / DXVK por juego y nos quedamos con el ganador (`graphics.candidates`).
3. **Componentes más nuevos que CrossOver.** DXMT avanza rápido (CrossOver 26 trae 0.72; el
   upstream va en 0.80). Podemos actualizar DXMT/DXVK/MoltenVK sin esperar a CodeWeavers.
4. **Ritmo de frames.** Tope de FPS alineado a la pantalla (120 Hz ProMotion → 40/60/120). Un
   tope estable suele sentirse mejor que FPS altos con drops.
5. **Cachés de shaders.** Persistentes por juego, que sobrevivan actualizaciones del motor y,
   después, precalentadas.
6. **Ajustes dentro del juego.** El perfil también puede parchear configs del juego (`.ini`).
   Ejemplo: el pool de streaming de Wukong está en 384 MB, absurdo con 48 GB de memoria unificada.
7. **Motor propio.** Compilamos Wine desde las fuentes FOSS de CrossOver, así que podemos aplicar
   parches (de Proton, wine-staging o propios) que CrossOver no trae.

## 3. Arquitectura

```
gmac (CLI) ──┐
             ├── GMCore (Swift): perfiles, motores, bottles, lanzador, doctor
App SwiftUI ─┘   (Fase 2: misma lógica con interfaz)

~/Library/Application Support/GamingMac/
  Engines/<motor>/   Wine + lib/dxmt + lib/dxvk + lib64/apple_gptk (D3DMetal)
  Bottles/<bottle>/  WINEPREFIX
~/Library/Logs/GamingMac/   un log por lanzamiento (perfil + traductor + fecha)
profiles/*.json             perfiles curados (en el repo, versionados)
```

## 4. Redistribución (cuando toque)

- Nuestro código: licencia abierta (MIT o GPL, a decidir).
- Wine/DXMT/DXVK/MoltenVK: (L)GPL/zlib/Apache. Se pueden redistribuir publicando fuentes y parches.
- **D3DMetal (Apple GPTK 3.0):** la licencia permite distribuir el Framework y los
  Redistributables **solo sin fines comerciales** (secciones 2A-iii y 2C), conservando los avisos
  de copyright. Si algún día se cobra, hay que volver al modelo de "el usuario importa su GPTK".
- **Nada de CrossOver propietario** (UI, scripts Perl/Python, cxcompatdb, base .tie) entra al repo.
  `Contents/` está en `.gitignore` y es solo referencia.

## 5. Fases

- **Fase 0** ✅ estrategia, perfiles iniciales y CLI `gmac` (esqueleto funcional).
- **Fase 1** motor propio + bottle + Steam + juegos compartidos con CrossOver (sin duplicar 186 GB)
  + medición. Meta: IT Specialist → Halo MCC → Wukong corriendo con `gmac run`.
- **Fase 2** app SwiftUI (biblioteca, perfiles editables, HUD, logs) + benchmark A/B automático.
- **Fase 3** parches de Wine, cachés de shaders, familia Valve 32-bit, launchers EA/Ubisoft.
- **Fase 4** empaquetado redistribuible (importador de GPTK, actualizaciones).
