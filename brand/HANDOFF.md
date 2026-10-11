# Handoff para Claude Code: aplicar la marca Nightport a GamingMac

Pega esto en Claude Code desde la raíz del repo:

> Lee `brand/HANDOFF.md` y `brand/README.md`, revisa los mockups en `brand/mockups/*.png` y aplica la
> marca Nightport a la app siguiendo los pasos en orden. Compila con `swift build` después de cada paso.

---

## 0. Alcance y decisiones ya tomadas

- **Nombre visible:** Nightport. El código interno puede seguir llamándose GamingMac por ahora
  (targets de SwiftPM, `GMCore`, CLI `gmac`). Renombrarlos no aporta nada al usuario y rompe rutas.
- **No mover datos del usuario:** `Paths.appSupport` (`~/Library/Application Support/GamingMac`) y
  `Paths.logs` se quedan igual en este cambio. Si después se renombran, hay que migrar bottles y motores.
- **Solo tema oscuro.** La marca está diseñada para la noche; la ventana fuerza `.dark`.
- **Fuente de verdad visual:** `brand/mockups/*.png` (y su HTML junto a cada uno). Tokens en
  `brand/tokens/tokens.json`, ya traducidos a Swift en `brand/swift/NightportTheme.swift`.
- **No copiar nada de `Contents/`** (es CrossOver, propietario).

## 1. Tema

1. Copia `brand/swift/NightportTheme.swift` a `Sources/GamingMacApp/NightportTheme.swift`.
2. En `GamingMacApp.init()` llama `NP.registerFonts()` (cubre `swift run`; en la .app las fuentes también
   se registran por Info.plist, ver paso 3).
3. Compila. El archivo no depende de GMCore.

## 2. Ícono

En `scripts/build-app.sh` reemplaza la línea de `make-icon.swift` por el iconset ya exportado
(pixel-perfecto, idéntico a los SVG):

```bash
iconutil -c icns brand/icon/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
```

Alternativa sin PNGs: sustituye `tools/app/make-icon.swift` por `brand/swift/make-icon.swift`
(mismo uso, dibuja el logo en vector). Úsala si prefieres generar el ícono en cada build.

## 3. Bundle y fuentes en la .app

En `scripts/build-app.sh`:

- Destino: `APP=".../Nightport.app"` (en vez de `GamingMac.app`). Si existe la vieja en
  `~/Applications/GamingMac.app`, bórrala una vez a mano.
- Ejecutable: puede seguir siendo `GamingMac` dentro del bundle; no se ve.
- Copia fuentes y licencias:
  ```bash
  mkdir -p "$APP/Contents/Resources/Fonts"
  cp brand/fonts/*.ttf brand/fonts/OFL-*.txt "$APP/Contents/Resources/Fonts/"
  ```
- Info.plist:
  - `CFBundleName` y `CFBundleDisplayName` = `Nightport`
  - `CFBundleIdentifier` = `local.nightport.app` (cambiar a dominio real cuando exista)
  - agregar `<key>ATSApplicationFontsPath</key><string>Fonts</string>`

## 4. Ventana

```swift
WindowGroup("Nightport") {
    RootView()
        .environmentObject(model)
        .frame(minWidth: 1000, minHeight: 640)
        .preferredColorScheme(.dark)
        .background(NP.background)
}
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentMinSize)
```

`RootView` = barra lateral fija de `NP.sidebarWidth` con fondo `NP.surface` y borde derecho `NP.elevated`,
más el contenido. Barra lateral: `NightportLockup()` arriba, luego navegación:
**Biblioteca** (por defecto) y **Ajustes**. Agregar juego, Compatibilidad y Descargas aparecen en los
mockups pero aún no tienen backend: no los muestres hasta que existan (o muéstralos deshabilitados con
"Próximamente"). Ítem activo: fondo `NP.elevated`, ícono `NP.portalSoft`, texto `NP.textPrimary`;
inactivos en `NP.textSecondary`. Alto mínimo de cada ítem: 44.

## 5. Biblioteca (`brand/mockups/01-biblioteca.png`)

Reemplaza la `List` actual de `ContentView`. Todo sale de `AppModel` como hoy:

| Elemento del mockup | Dato real |
|---|---|
| Píldora "Steam abierto / cerrado" | `model.steamRunning` (punto Tide si abierto, Mist si cerrado) |
| Botón primario del header | Mientras no exista "Agregar juego": **Abrir Steam** (`model.openSteam()`, `NPPrimaryButtonStyle`, deshabilitado si ya está abierto) |
| Búsqueda | filtra `model.games` por `name` |
| Tarjeta "Continúa jugando" | último juego lanzado (guarda `profile.id` en `UserDefaults` dentro de `play`); si no hay, el primero |
| Badge de compatibilidad | `CompatBadge(status: CompatStatus(profileStatus: profile.status))` |
| Chips | origen (`launch.mode == .steam` → "Steam", si no "Ejecutable") y traductor `NPChip(text: backend.label, mono: true)` |
| Botón Jugar | `model.play(profile)` con `NPPlayButtonStyle`. Es el **único** naranja de la pantalla |
| "Ajustes del juego" | navega a la pantalla del paso 6 con ese perfil (`NPSecondaryButtonStyle`) |
| Cuadrícula | `LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 20)])`, tarjetas `npCard()` |
| Portadas | placeholder: rectángulo `NP.elevated` con una forma de color. Opcional: cargar en tiempo de ejecución la imagen de cabecera de Steam por `steamAppId`. **Nunca empaquetar arte de juegos en la app.** |
| Filtros (Todos / Steam / …) | opcional en esta fase |
| Tarjeta "Apoyar" | placeholder, sin precio hasta definir el modelo de cobro |

Además:
- `model.displayAsleep` → banner arriba del contenido: borde `NP.energy`, ícono `exclamationmark.triangle.fill`,
  texto "La pantalla está dormida o la sesión bloqueada: Steam y los juegos se pausan hasta que vuelvas."
- `model.status` → línea inferior en `NP.mono(12)` color `NP.textSecondary`.
- "Ver logs" y "Cerrar todo" → menú de la app (`.commands`) o sección General de Ajustes, no en la biblioteca.

## 6. Ajustes del juego (`brand/mockups/03-ajustes-del-juego.png`)

| Control | Dato real | Estado |
|---|---|---|
| Traducción gráfica (Picker) | `model.backendChoice[profile.id]`, opciones de `profile.graphics?.candidates`. Primera opción: "Automático (perfil: \(backend.label))" = sin override | existe |
| HUD de Metal | hoy `model.hud` es global; convertirlo en override por juego | existe (global) |
| DLSS → MetalFX | `profile.metalFX`; solo visible si el traductor es D3DMetal | **falta override** |
| Raytracing (DXR) | `profile.dxr`; solo D3DMetal | **falta override** |
| Modo Retina | `profile.retina` | **falta override** |
| Límite de FPS 40/60/120/Sin tope | el motor aún no lo soporta | mostrar deshabilitado, "Próximamente" |
| "Estás usando el perfil recomendado" + Restaurar | `true` si el juego no tiene overrides; Restaurar los borra | nuevo |
| Vista previa del HUD | estática, valores de ejemplo | decorativo |
| Control conectado | `GCController.controllers()` (GameController) | opcional |

Para los que faltan: extiende `Launcher.Overrides` con `metalFX: Bool?`, `dxr: Bool?`, `retina: Bool?` y
aplícalos encima del perfil en `Launcher.plan` (igual que `backend` y `metalHUD`). Guarda los overrides del
usuario en `Paths.appSupport/overrides.json` (por `profile.id`). **Nunca** escribir en `profiles/*.json`:
son los perfiles curados.

Interruptores: `Toggle` con `.toggleStyle(.switch)` y `.tint(NP.accent)`. Filas separadas por divisores
`NP.elevated` dentro de un `npCard()`.

## 7. Textos

- Español primero. Sin jerga: "espacio aislado" en vez de bottle; "traductor gráfico" está bien.
- Errores: qué pasó + qué hacer. Ej.: "No hay ningún espacio creado. Crea uno con: gmac bottle create Steam"
  se queda así en la CLI, pero en la app: "Aún no hay un espacio para Steam. [Crear espacio]".
- Ver ejemplos de voz en `brand/README.md`.

## 8. Accesibilidad

- Objetivos táctiles de al menos 44 pt.
- Todo color de estado lleva su texto (badge) o ícono.
- Botones solo con ícono: `.accessibilityLabel`.
- Contraste ya verificado en la paleta: no inventes grises nuevos para texto.

## 9. Criterios de aceptación

- [ ] `swift build` y `scripts/build-app.sh` sin errores; se instala `~/Applications/Nightport.app`.
- [ ] El Dock y Finder muestran el ícono nuevo (puede requerir `killall Dock` por la caché).
- [ ] Títulos en Unbounded y texto en Manrope dentro de la .app (no la fuente del sistema).
- [ ] Biblioteca y Ajustes coinciden con los PNG de `brand/mockups/` en color, jerarquía y espaciado.
- [ ] Jugar, Abrir Steam, selector de traductor y HUD siguen funcionando igual que antes.
- [ ] Los overrides por juego persisten entre reinicios y "Restaurar" los borra.
- [ ] Ningún asset proviene de `Contents/`.
