#!/bin/bash
# elmakurdu.app'i derler (yerelde ve GitHub Actions'ta aynı betik kullanılır).
set -e
cd "$(dirname "$0")"
APP="build/elmakurdu.app"
PL="$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy

for f in src/elmakurdu.applescript src/expand.sh assets/elmakurdu.icns; do
  [ -f "$f" ] || { echo "✗ Eksik dosya: $f (repoya eklendiğinden emin olun)"; exit 1; }
done

rm -rf "$APP"; mkdir -p build
osacompile -o "$APP" src/elmakurdu.applescript

# Varsayılan simgeyi kaldır, kendi simgemizi ekle
find "$APP/Contents/Resources" \( -name 'Assets.car' -o -name 'applet.icns' \) -delete
cp assets/elmakurdu.icns "$APP/Contents/Resources/elmakurdu.icns"
cp src/expand.sh "$APP/Contents/Resources/expand.sh"

$PB -c "Delete :CFBundleIconName" "$PL" 2>/dev/null || true
$PB -c "Set :CFBundleIconFile elmakurdu" "$PL" 2>/dev/null || $PB -c "Add :CFBundleIconFile string elmakurdu" "$PL"
$PB -c "Set :CFBundleName elmakurdu" "$PL" 2>/dev/null || $PB -c "Add :CFBundleName string elmakurdu" "$PL"
$PB -c "Set :CFBundleDisplayName elmakurdu" "$PL" 2>/dev/null || $PB -c "Add :CFBundleDisplayName string elmakurdu" "$PL"
$PB -c "Set :CFBundleIdentifier local.elmakurdu.app" "$PL" 2>/dev/null || true

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

# Doğrulama (GitHub günlüğünde de görünür)
echo "--- Resources ---"; ls -la "$APP/Contents/Resources"
echo "--- Info.plist simge anahtarları ---"; grep -A1 -E "CFBundleIcon" "$PL" || true
cmp assets/elmakurdu.icns "$APP/Contents/Resources/elmakurdu.icns" && echo "✓ Simge pakette"
echo "✓ Derlendi: $APP"
