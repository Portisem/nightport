# Testing a game (with your Mac unlocked)

[Español](../PROBAR.md)

Steam and games freeze when the Mac's display is asleep or the session is locked, so test with the
Mac awake and unlocked.

```bash
cd nightport                                # the repository folder
.build/debug/gmac doctor                    # everything should show ✓
.build/debug/gmac steam start Steam         # sign in (QR with the Steam app, or username/password)
```

With Steam open and signed in:

```bash
.build/debug/gmac run it-specialist-simulator --hud        # smoke test (DXMT)
.build/debug/gmac run halo-mcc --hud                       # DXMT
.build/debug/gmac run halo-mcc --backend d3dmetal --hud    # compare with D3DMetal
.build/debug/gmac run black-myth-wukong --hud              # D3DMetal + DLSS→MetalFX
.build/debug/gmac check left-4-dead-2                      # how well would it run on this Mac?
.build/debug/gmac monitor left-4-dead-2                    # record a session of a running game
.build/debug/gmac sessions                                 # recorded sessions and suggestions
```

`--hud` shows FPS (Metal HUD). Logs go to `~/Library/Logs/GamingMac/`.

**Benchmark method:** pick a fixed scene (a save, 60–120 s), run it once per candidate translator,
and write down FPS average and 1% low together with your Mac model and macOS version.
