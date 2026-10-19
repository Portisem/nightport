<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/logo/png/nightport-lockup-dark-bg.png">
    <img src="brand/logo/png/nightport-lockup-light-bg.png" alt="Nightport" width="360">
  </picture>
</p>

<p align="center"><b>Your Windows games, at home on your Mac.</b></p>

<p align="center">
  <a href="README.es.md">Español</a> ·
  <a href="LICENSE">GPL-3.0</a> ·
  <a href="docs/en/ENGINE.md">How the engine is built</a> ·
  <a href="docs/en/GAMES.md">Compatibility</a>
</p>

---

Nightport is an open-source launcher that runs Windows games (mainly from Steam) on Apple Silicon
Macs. It is built on Wine and open graphics translation layers, and its main idea is simple:
**every game gets a curated profile**, with the graphics translator and settings that work best
for it, chosen by **measuring** frame rate and frame-time stability instead of guessing.

> **Personal project.** I build Nightport in my spare time, mainly to play my own library. You are
> welcome to use it, fork it and send improvements, but there is no guaranteed support. Back up
> your saves. If it's useful to you and you want to chip in, see [Support](#support).

<p align="center">
  <img src="brand/mockups/01-biblioteca.png" alt="Library screen (design mockup)" width="720">
</p>

## What it does

- **Per-game graphics translator**: D3DMetal (Apple), DXMT, DXVK or wined3d, picked per game from
  the profile, with alternatives you can benchmark against each other.
- **Steam library integration**: games installed in Steam show up automatically; curated profiles
  improve them. Not-yet-downloaded games open Steam's install dialog.
- **"Will it run on my Mac?"**: compares a game's published Windows requirements with your Mac's
  GPU, unified memory and disk, accounting for each translator's overhead.
- **Activity**: records play sessions (CPU, GPU, memory, temperature, FPS where available) with
  suggestions. Everything stays on your Mac.
- **`gmac` CLI** for everything the app does, plus dry runs that show exactly how a game would be
  launched.

## How it works

```
Windows game (.exe)
 └─ Wine 11 (built from CodeWeavers' CrossOver 26.3 free sources + Nightport patches)
     └─ graphics translator, chosen per game:
          D3DMetal (Apple GPTK, provided by the user)   DX11/DX12 → Metal
          DXMT                                          DX10/DX11 → Metal
          DXVK + MoltenVK                               DX9–11 → Vulkan → Metal
          wined3d                                       DX1–11 → OpenGL
 └─ Rosetta 2 (the engine is x86_64)
```

| Part | What it is |
|---|---|
| `Sources/GMCore` | Swift library: engines, bottles (Wine prefixes), profiles, launcher, Steam, diagnostics |
| `Sources/GamingMacApp` | SwiftUI app (Nightport.app) |
| `Sources/gmac` | Command-line tool |
| `patches/wine` | Wine patches (see below) |
| `profiles/` | One JSON profile per game + `_defaults.json` ([format](docs/PROFILES.md)) |
| `scripts/` | Fetch dependencies, build and package the engine, build the app |
| `tools/gmtest` | Small DX11/DX12/display/network test programs |
| `brand/` | Logo, icon, colors, fonts and mockups |

### Engineering highlights

- **Per-game translator selection without proprietary code.** CrossOver picks D3DMetal/DXMT through
  a closed component. Nightport adds a `WINEDLLPATH_PRIORITY` search path to Wine's loader
  (`patches/wine/0001`) so each game can load a different translator.
- **A clang ABI bug that froze Steam.** Apple clang assumes `BOOLEAN` (1-byte) arguments arrive
  sign/zero-extended to 32 bits; Windows code only writes the low byte. Steam passed
  `restart=FALSE` to `NtQueryDirectoryObject` with garbage in the upper bits, Wine read it as
  `TRUE` and looped forever (6 million calls in 25 s). Fixed in 36 syscalls (`patches/wine/0002`).
- **FPS for Metal translators without hooks.** wined3d reports FPS through Wine's `trace+fps`
  channel, but DXMT and D3DMetal have no FPS log. macOS's Metal Performance HUD
  (`libMTLHud.dylib`) can: with `MTL_HUD_ENABLED=1 MTL_HUD_LOG_ENABLED=1 MTL_HUD_HIDDEN=1` it draws
  nothing and writes a `metal-HUD:` line to stderr about every 0.8 s: a running frame counter, then
  the interval of each frame that reached the screen, in ms. Nightport sets these for every
  non-wined3d launch (profile field `frameStats`). Wine sends the game's stderr to its log; the
  session recorder divides the counter's increase by the time those intervals cover, so FPS counts
  every Present like wined3d's does (on a 120 Hz display, gmtest showed 220 FPS presented and 114
  displayed). Checked on macOS 26 with gmtest on DXMT (224 vs 222 self-reported) and D3DMetal (219
  vs 219). The format belongs to Apple's private HUD library and may change. DXVK is untested, and the
  HUD skips windows that are too small (320×200 logged nothing).
- **Per-executable arguments** (`GMAC_APPEND_ARGS`, `patches/wine/0003`) to give Steam's
  Chromium-based UI the flags it needs.
- **Reproducible toolchain without Homebrew**: x86_64 dependencies from conda-forge via
  micromamba, PE DLLs with llvm-mingw, no `sudo`.

## Requirements

- Mac with Apple Silicon and Rosetta 2.
- macOS 13 or later for the app; macOS 15 or later to use Apple's D3DMetal.
- Xcode Command Line Tools (Swift 5.9+) to build from source.
- About 10 GB free for the toolchain and build, plus space for your games.

## Build from source

There are no prebuilt downloads yet. To build everything yourself:

```bash
git clone https://github.com/Portisem/nightport.git
cd nightport
scripts/fetch-deps.sh            # toolchain + sources (~a few GB, no sudo)
scripts/build-engine.sh all      # compile Wine (30–60 min the first time)
scripts/assemble-engine.sh       # add DXMT, libraries, Wine Mono/Gecko
scripts/build-app.sh             # installs ~/Applications/Nightport.app
```

Optional, for DX12 games: download Apple's **Game Porting Toolkit** from
[developer.apple.com](https://developer.apple.com/games/) (free Apple account), mount the DMG and
run `scripts/import-gptk.sh`. Nightport never includes Apple's software.

Then create a bottle and install Steam:

```bash
swift build
.build/debug/gmac doctor                    # system check
.build/debug/gmac bottle create Steam
.build/debug/gmac steam install Steam
.build/debug/gmac steam start Steam         # sign in to Steam
.build/debug/gmac run halo-mcc --dry-run    # see exactly how a game would launch
.build/debug/gmac run halo-mcc --hud        # launch with the Metal performance HUD
```

More: [docs/en/ENGINE.md](docs/en/ENGINE.md) (engine build and findings),
[docs/en/TESTING.md](docs/en/TESTING.md) (how to test and benchmark a game).

## Compatibility

Early days: a handful of games are profiled and many more are pending. See
[docs/en/GAMES.md](docs/en/GAMES.md).

**What cannot work:** online modes protected by kernel-level or Windows-only anti-cheat (Easy
Anti-Cheat without Wine support, BattlEye, Vanguard). Games with a native Mac version usually run
better natively.

## Contributing

Bug reports, game reports and profiles are the most valuable contributions. Use the issue forms
(game request, compatibility report, bug) and see [CONTRIBUTING.md](CONTRIBUTING.md).
Piracy-related requests are closed.

## Support

Nightport is free and will stay free. If it saves you time and you'd like to support it,
voluntary donations help cover costs such as Apple's developer membership (needed to sign the app
so macOS opens it without warnings). Donation links will appear on this repository's **Sponsor**
button once they are set up.

## License

- Code: [GPL-3.0-or-later](LICENSE).
- Game profiles: [CC BY-SA 4.0](profiles/LICENSE).
- The Nightport name and logo: see [TRADEMARKS.md](TRADEMARKS.md).
- Third-party components: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Nightport is not affiliated with Apple, Microsoft, Valve or CodeWeavers. Its engine is built from
the free Wine sources that CodeWeavers publishes; thanks to them and to the Wine, DXMT, DXVK and
MoltenVK projects.
