#!/bin/bash
# Compila GamingMac.app (interfaz + gmac + perfiles) y la instala en ~/Applications.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="${GMAC_APP_DEST:-$HOME/Applications}/GamingMac.app"
cd "$REPO"

swift build -c release --product GamingMacApp
swift build -c release --product gmac
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/GamingMacApp" "$APP/Contents/MacOS/GamingMac"
cp "$BIN/gmac" "$APP/Contents/MacOS/gmac"
cp -R profiles "$APP/Contents/Resources/profiles"
swift tools/app/make-icon.swift "$APP/Contents/Resources/AppIcon.icns" >/dev/null

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>GamingMac</string>
  <key>CFBundleDisplayName</key><string>GamingMac</string>
  <key>CFBundleIdentifier</key><string>local.gamingmac.app</string>
  <key>CFBundleExecutable</key><string>GamingMac</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>$(git rev-list --count HEAD 2>/dev/null || echo 1)</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null
echo "App lista: $APP"
