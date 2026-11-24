#!/bin/bash
# Kolay Kurulum.app dosyasını kaynaktan derler. Mac'te çift tıklayarak çalıştırın.
cd "$(dirname "$0")" || exit 1
rm -rf "build/Kolay Kurulum.app"; mkdir -p build
osacompile -o "build/Kolay Kurulum.app" src/KolayKurulum.applescript || { echo "Derleme başarısız"; exit 1; }
xattr -cr "build/Kolay Kurulum.app"
codesign --force --deep --sign - "build/Kolay Kurulum.app" 2>/dev/null
rm -rf "/Applications/Kolay Kurulum.app"
cp -R "build/Kolay Kurulum.app" /Applications/ && echo "✓ /Applications içine kopyalandı"
echo "✓ Hazır: $(pwd)/build/Kolay Kurulum.app"
open -R "/Applications/Kolay Kurulum.app"
