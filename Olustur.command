#!/bin/bash
# elmakurdu.app dosyasını kaynaktan derler. Mac'te çift tıklayarak çalıştırın.
cd "$(dirname "$0")" || exit 1
APP="build/elmakurdu.app"
rm -rf "$APP"; mkdir -p build
osacompile -o "$APP" src/elmakurdu.applescript || { echo "Derleme başarısız"; exit 1; }

# Simge ve yardımcı betik
rm -f "$APP/Contents/Resources/Assets.car"
cp assets/elmakurdu.icns "$APP/Contents/Resources/applet.icns"
cp src/expand.sh "$APP/Contents/Resources/expand.sh"
PL="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PL" 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile applet" "$PL" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string applet" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleName elmakurdu" "$PL" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleName string elmakurdu" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName elmakurdu" "$PL" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string elmakurdu" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier local.elmakurdu.app" "$PL" 2>/dev/null

xattr -cr "$APP"
codesign --force --deep --sign - "$APP" 2>/dev/null

# Çalışan eski sürümü kapat, sil, yenisini kopyala
osascript -e 'tell application "elmakurdu" to quit' >/dev/null 2>&1
rm -rf "/Applications/elmakurdu.app"
cp -R "$APP" /Applications/ && echo "✓ /Applications içine kopyalandı"
touch "/Applications/elmakurdu.app"
echo "✓ Hazır: $(pwd)/$APP"
open -R "/Applications/elmakurdu.app"
