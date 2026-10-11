# Probar en tu Mac (con la sesión desbloqueada)

```bash
cd ~/Desktop/Personal/GamingMac
.build/debug/gmac doctor                    # todo debe salir ✓
.build/debug/gmac steam start Steam         # inicia sesión (QR con la app de Steam o usuario/contraseña)
```

Con Steam abierto y tu sesión iniciada:

```bash
.build/debug/gmac run it-specialist-simulator --hud        # prueba de humo (DXMT)
.build/debug/gmac run halo-mcc --hud                       # DXMT
.build/debug/gmac run halo-mcc --backend d3dmetal --hud    # comparar con D3DMetal
.build/debug/gmac run black-myth-wukong --hud              # D3DMetal + DLSS→MetalFX
```

`--hud` muestra FPS (Metal HUD). Los logs quedan en `~/Library/Logs/GamingMac/`.
