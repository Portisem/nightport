# Matriz de juegos (tu biblioteca)

API y bits son la mejor estimación inicial; se confirman al probar cada juego.
Estado: 🎯 foco · 🟢 nativo Mac · ⏳ pendiente · ⛔ bloqueado (anti-cheat)

| Juego | API probable | Traductor a probar | Estado | Notas |
|---|---|---|---|---|
| Halo: MCC | DX11 64-bit | DXMT → D3DMetal | 🎯 | Sin anti-cheat: campaña/custom sí, matchmaking no |
| Black Myth: Wukong | DX12 64-bit | D3DMetal | 🎯 | DLSS→MetalFX; drops = shaders/streaming/pacing |
| IT Specialist Simulator | DX11 Unity | DXMT | 🎯 | Prueba de humo |
| Cyberpunk 2077 | — | — | 🟢 | Nativo Mac con MetalFX: dejar nativo |
| Sid Meier's Civilization VI | — | — | 🟢 | Nativo |
| Dota 2 | — | — | 🟢 | Nativo |
| Warframe | — | — | 🟢 | Nativo |
| The Lord of the Rings Online | — | — | 🟢 | Nativo |
| Realm of the Mad God Exalt | — | — | 🟢 | Nativo |
| Garry's Mod | — | — | 🟢 | Nativo (rama x86-64) |
| Rust / Rust Staging | — | — | 🟢/⛔ | Nativo existe; versión Windows con EAC no aplica |
| Counter-Strike 2 | DX11/Vulkan 64-bit | D3DMetal/DXMT | ⏳ | VAC (no kernel); online con riesgo |
| Age of Empires II: DE | DX11 64-bit | DXMT | ⏳ | |
| Assassin's Creed III | DX11 32-bit | DXMT/DXVK | ⏳ | Ubisoft Connect |
| Burnout Paradise | DX9/DX11 | DXVK/DXMT | ⏳ | EA app |
| C&C Red Alert 3 | DX9 32-bit | DXVK/wined3d | ⏳ | EA app |
| Crysis 2 Maximum Edition | DX11 | DXMT | ⏳ | |
| Dead Space (2008) | DX9 32-bit | DXVK/wined3d | ⏳ | EA app |
| Skyrim (original) | DX9 32-bit | DXVK/wined3d | ⏳ | |
| Grand Theft Auto IV: Complete | DX9 32-bit | DXVK | ⏳ | Rockstar launcher |
| Medal of Honor (SP/MP) | DX9 32-bit | DXVK/wined3d | ⏳ | MP con servidores cerrados |
| Mirror's Edge | DX9 32-bit | DXVK/wined3d | ⏳ | PhysX: desactivar |
| PAYDAY 2 | DX9 | DXVK | ⏳ | |
| Saints Row: The Third | DX9/DX11 32-bit | DXVK/DXMT | ⏳ | |
| The Walking Dead | DX9 32-bit | wined3d/DXVK | ⏳ | |
| **Familia Source** (HL2, HL2:DM, HL:Source, HLDM:S, CS:Source, DoD:Source, Portal, Portal 2, L4D, L4D2, TF2, CS:CZ Deleted Scenes) | DX9 | DXVK/wined3d | ⏳ | Un perfil base para todos |
| **Familia GoldSrc** (Half-Life, Opposing Force, Blue Shift, CS 1.6, CS:CZ, DoD, TFC, Ricochet, Deathmatch Classic) | OpenGL 32-bit | wined3d (GL directo) | ⏳ | Un perfil base para todos |
