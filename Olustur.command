#!/bin/bash
# Installer.app dosyasını kaynaktan derler. Mac'te çift tıklayarak çalıştırın.
cd "$(dirname "$0")" || exit 1
rm -rf "build/Installer.app"; mkdir -p build
osacompile -o "build/Installer.app" src/Installer.applescript || { echo "Derleme başarısız"; exit 1; }
cp assets/AppIcon.icns "build/Installer.app/Contents/Resources/applet.icns"
touch "build/Installer.app"
xattr -cr "build/Installer.app"
codesign --force --deep --sign - "build/Installer.app" 2>/dev/null
rm -rf "/Applications/Kolay Kurulum.app" "/Applications/Installer.app"
cp -R "build/Installer.app" /Applications/ && echo "✓ /Applications içine kopyalandı"
echo "✓ Hazır: $(pwd)/build/Installer.app"
open -R "/Applications/Installer.app"
