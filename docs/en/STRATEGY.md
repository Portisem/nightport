# Strategy

[Español](../FASE0.md)

## 1. Start with AAA games or old ones?

**Neither, in pure form.** We use a "tracer bullet": a small set that goes through every layer of
the system, with the most-played games as the north star.

| Order | Game | Why |
|---|---|---|
| 1 | **IT Specialist Simulator** | Smoke test: light (2.5 GB), DX11/Unity. Validates engine + bottle + Steam + launcher end to end. If it fails, the problem is ours, not the game's |
| 2 | **Halo MCC** | Runs poorly elsewhere = biggest possible gain. DX11 → we can choose the translator (DXMT vs D3DMetal), which is where we can beat CrossOver |
| 3 | **Black Myth: Wukong** | The heaviest (DX12/UE5). D3DMetal only (closed), so gains come from frame pacing, caches and in-game settings, not the translator |
| 4 | **Valve GoldSrc/Source family** | ~20 games macOS no longer runs natively. One piece of work (32-bit + OpenGL/DX9) unlocks many. Best effort/games ratio |
| 5 | **Third-party launchers** | AC3 (Ubisoft Connect), Dead Space / RA3 / Mirror's Edge / MoH (EA app). Each launcher is its own problem |

**Why not AAA first:** without measuring infrastructure we wouldn't know if we improved or regressed.
**Why not old games first:** they don't stress the GPU or shaders.

Games with a **native Mac version** (Cyberpunk 2077, Civ VI, Dota 2, Warframe, LOTRO, Realm of the
Mad God, Rust, Garry's Mod) stay native by default: they almost always perform better.

**A limit nobody can break:** kernel-level or Windows-only anti-cheat (EAC/BattlEye without Wine
support). Rust online and Halo MCC matchmaking are out. MCC campaign, Forge and custom games do run
in no-anti-cheat mode.

## 2. How to beat CrossOver

CrossOver is a very good generic base. Our edge is **curating game by game and measuring**.

1. **Measure before optimizing.** Fixed scene (a save, 60–120 s), record FPS average, 1% low and
   frame-time variance. Baseline = the same game in CrossOver. No number, no improvement.
2. **Per-game translator, chosen with data.** CrossOver uses one default per bottle; we test
   D3DMetal / DXMT / DXVK per game and keep the winner (`graphics.candidates`).
3. **Newer components than CrossOver.** DXMT moves fast (CrossOver 26 ships 0.72; upstream is at
   0.80). We can update DXMT/DXVK/MoltenVK without waiting for CodeWeavers.
4. **Frame pacing.** FPS caps aligned to the display (120 Hz ProMotion → 40/60/120). A stable cap
   usually feels better than high FPS with drops.
5. **Shader caches.** Persistent per game, surviving engine updates, later pre-warmed.
6. **In-game settings.** Profiles can also patch game configs (`.ini`). Example: Wukong's texture
   streaming pool is 384 MB, far too low for a Mac with lots of unified memory.
7. **Our own engine.** We build Wine from CrossOver's free sources, so we can apply patches (from
   Proton, wine-staging or our own) that CrossOver doesn't ship.

## 3. Architecture

```
gmac (CLI) ──┐
             ├── GMCore (Swift): profiles, engines, bottles, launcher, doctor
SwiftUI app ─┘

~/Library/Application Support/GamingMac/
  Engines/<engine>/   Wine + lib/dxmt + lib/dxvk + lib64/apple_gptk (D3DMetal, if imported)
  Bottles/<bottle>/   WINEPREFIX
~/Library/Logs/GamingMac/   one log per launch (profile + translator + date)
profiles/*.json             curated profiles (versioned in the repo)
```

## 4. Redistribution

- Our code: GPL-3.0-or-later; profiles: CC BY-SA 4.0 (see `THIRD_PARTY_NOTICES.md`).
- Wine/DXMT/DXVK/MoltenVK: LGPL/zlib/Apache. Redistributable, publishing sources and patches.
- **D3DMetal (Apple GPTK):** its license only allows **non-commercial** distribution (sections
  2A-iii and 2C). Decision: Nightport **never ships it**; each user downloads it from Apple and
  imports it (`scripts/import-gptk.sh`). `scripts/package-engine.sh` excludes it.
- **No proprietary CrossOver files** (UI, Perl/Python scripts, cxcompatdb, .tie database) ever enter
  the repository.

## 5. Phases

- **Phase 0** ✅ strategy, first profiles and the `gmac` CLI.
- **Phase 1** ✅ own engine + bottle + Steam + measuring. Goal: IT Specialist → Halo MCC → Wukong
  running with `gmac run`.
- **Phase 2** SwiftUI app (library, editable profiles, HUD, logs, activity) + automatic A/B benchmark.
- **Phase 3** Wine patches, shader caches, Valve 32-bit family, EA/Ubisoft launchers.
- **Phase 4** redistributable packaging (GPTK importer, updates, signed app).
