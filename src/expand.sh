#!/bin/bash
# Kullanım: expand.sh <zip> <hedef-klasör>
# Zip'i açar; içindeki zip'leri (iç içe, en fazla 10 kat) de açar.
# .app paketlerinin içindeki zip'lere dokunmaz.
zip="$1"; out="$2"
mkdir -p "$out"
ditto -x -k "$zip" "$out" || exit 1
for i in 1 2 3 4 5 6 7 8 9 10; do
  list=$(find "$out" -path '*/__MACOSX' -prune -o -name '*.app' -type d -prune -o -type f -iname '*.zip' -print 2>/dev/null)
  [ -z "$list" ] && break
  printf '%s\n' "$list" | while IFS= read -r z; do
    mkdir -p "$z.x"
    ditto -x -k "$z" "$z.x" >/dev/null 2>&1
    mv "$z" "$z.done"   # tekrar açılmasın
  done
done
exit 0
