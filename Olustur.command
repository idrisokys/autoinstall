#!/bin/bash
# elmakurdu.app dosyasını kaynaktan derler ve /Applications içine kurar. Mac'te çift tıklayarak çalıştırın.
cd "$(dirname "$0")" || exit 1
./build.sh || { echo "Derleme başarısız"; exit 1; }

osascript -e 'tell application "elmakurdu" to quit' >/dev/null 2>&1
rm -rf "/Applications/elmakurdu.app"
cp -R "build/elmakurdu.app" /Applications/ && echo "✓ /Applications içine kopyalandı"
touch "/Applications/elmakurdu.app"

# Simge önbelleğini yenile
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSR" -f "/Applications/elmakurdu.app" >/dev/null 2>&1
rm -rf ~/Library/Caches/com.apple.iconservices* 2>/dev/null
killall iconservicesagent iconservicesd Dock Finder >/dev/null 2>&1
open -R "/Applications/elmakurdu.app"
