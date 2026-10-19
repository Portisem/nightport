# Compatibility matrix

[Español](../JUEGOS.md)

Working list: games with a profile and candidates to test. API and bitness are a best initial
guess, confirmed when each game is tested.

Games installed in the bottle's Steam show up in the app automatically (`gmac steam games Steam`)
even without a profile; they launch through Steam's Play button. A curated profile improves them.

"Will it run on my Mac?" (`gmac check <profile>` and the General tab of each game) compares the
Windows requirements Steam publishes with the Mac's GPU, unified memory and disk, adding the
translator's overhead (D3DMetal ×1.35, DXMT ×1.3, DXVK ×1.5, wined3d ×1.6). It's an estimate:
each profile's benchmarks take precedence.

Status: 🎯 focus · 🟢 native Mac version · ⏳ pending · ⛔ blocked (anti-cheat)

| Game | Likely API | Translator to try | Status | Notes |
|---|---|---|---|---|
| Halo: MCC | DX11 64-bit | **D3DMetal** (DXMT 0.80 crashes in Reach) | ✅ playable | Reach ~60 FPS stable. No anti-cheat: campaign/custom yes, matchmaking no |
| Black Myth: Wukong | DX12 64-bit | D3DMetal | 🎯 | DLSS→MetalFX; drops = shaders/streaming/pacing |
| IT Specialist Simulator | DX11 Unity | DXMT | 🎯 | Smoke test |
| Cyberpunk 2077 | — | — | 🟢 | Native with MetalFX: keep native |
| Sid Meier's Civilization VI | — | — | 🟢 | Native |
| Dota 2 | — | — | 🟢 | Native |
| Warframe | — | — | 🟢 | Native |
| The Lord of the Rings Online | — | — | 🟢 | Native |
| Realm of the Mad God Exalt | — | — | 🟢 | Native |
| Garry's Mod | — | — | 🟢 | Native (x86-64 branch) |
| Rust / Rust Staging | — | — | 🟢/⛔ | Native exists; Windows version with EAC doesn't apply |
| Counter-Strike 2 | DX11/Vulkan 64-bit | D3DMetal/DXMT | ⏳ | VAC (not kernel); online at your own risk |
| Age of Empires II: DE | DX11 64-bit | DXMT | ⏳ | |
| Assassin's Creed III | DX11 32-bit | DXMT/DXVK | ⏳ | Ubisoft Connect |
| Burnout Paradise | DX9/DX11 | DXVK/DXMT | ⏳ | EA app |
| C&C Red Alert 3 | DX9 32-bit | DXVK/wined3d | ⏳ | EA app |
| Crysis 2 Maximum Edition | DX11 | DXMT | ⏳ | |
| Dead Space (2008) | DX9 32-bit | DXVK/wined3d | ⏳ | EA app |
| Skyrim (original) | DX9 32-bit | DXVK/wined3d | ⏳ | |
| Grand Theft Auto IV: Complete | DX9 32-bit | DXVK | ⏳ | Rockstar launcher |
| Medal of Honor (SP/MP) | DX9 32-bit | DXVK/wined3d | ⏳ | MP servers closed |
| Mirror's Edge | DX9 32-bit | DXVK/wined3d | ⏳ | Disable PhysX |
| PAYDAY 2 | DX9 | DXVK | ⏳ | |
| Saints Row: The Third | DX9/DX11 32-bit | DXVK/DXMT | ⏳ | |
| The Walking Dead | DX9 32-bit | wined3d/DXVK | ⏳ | |
| **Source family** (HL2, HL2:DM, HL:Source, HLDM:S, CS:Source, DoD:Source, Portal, Portal 2, L4D, L4D2, TF2, CS:CZ Deleted Scenes) | DX9 32-bit | wined3d (the engine doesn't ship DXVK yet) | ⏳ | Profiles `left-4-dead` and `left-4-dead-2`; L4D2 can try `-vulkan` (winevulkan + MoltenVK) |
| **GoldSrc family** (Half-Life, Opposing Force, Blue Shift, CS 1.6, CS:CZ, DoD, TFC, Ricochet, Deathmatch Classic) | OpenGL 32-bit | wined3d (direct GL) | ⏳ | One base profile for all |
