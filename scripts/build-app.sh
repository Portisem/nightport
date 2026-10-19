#!/bin/bash
# Compila Nightport.app (interfaz + gmac + perfiles + marca) y la instala en ~/Applications.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="${GMAC_APP_DEST:-$HOME/Applications}/Nightport.app"
cd "$REPO"

swift build -c release --product GamingMacApp
swift build -c release --product gmac
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/GamingMacApp" "$APP/Contents/MacOS/GamingMac"
cp "$BIN/gmac" "$APP/Contents/MacOS/gmac"
cp -R profiles "$APP/Contents/Resources/profiles"
iconutil -c icns brand/icon/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
mkdir -p "$APP/Contents/Resources/Fonts"
cp brand/fonts/*.ttf brand/fonts/OFL-*.txt "$APP/Contents/Resources/Fonts/"
# Textos en español e inglés: los .lproj procesados por SwiftPM van directo a Resources (Bundle.main).
RES_BUNDLE="$BIN/GamingMac_GamingMacApp.bundle"
LPROJS=$(find "$RES_BUNDLE" -name '*.lproj' -type d)
[ -n "$LPROJS" ] || { echo "No encontré traducciones en $RES_BUNDLE" >&2; exit 1; }
for lproj in $LPROJS; do cp -R "$lproj" "$APP/Contents/Resources/"; done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Nightport</string>
  <key>CFBundleDisplayName</key><string>Nightport</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
  <key>CFBundleIdentifier</key><string>local.nightport.app</string>
  <key>CFBundleExecutable</key><string>GamingMac</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>$(git rev-list --count HEAD 2>/dev/null || echo 1)</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>ATSApplicationFontsPath</key><string>Fonts</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null
echo "App lista: $APP"
