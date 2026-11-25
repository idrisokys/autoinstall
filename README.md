# elmakurdu

macOS 15 (Sequoia) ve Apple Silicon için sürükle-bırak uygulama kurucusu.
`.app`, `.dmg`, `.zip` veya `.pkg` dosyasını simgenin üzerine bırakın; gerisini otomatik halleder.

*A drag-and-drop app elmakurdu for macOS 15 on Apple Silicon: drop an `.app`, `.dmg`, `.zip` or `.pkg` onto it and it does the rest.*

## Ne yapar?

- Açılışta hiçbir bilgilendirme ekranı göstermez (yalnızca hata olursa pencere çıkar)
- Aynı adlı uygulama kuruluysa önce kapatır (gerekirse zorla), siler, sonra yenisini kurar; onay sormaz
- İç içe zip'leri (zip içinde zip) otomatik açar
- Arşivde hem `.app` hem `.dmg` varsa yalnızca `.app` kurulur; `.app` yoksa `.dmg`, o da yoksa `.pkg`
- Karantina işaretini kaldırır (`xattr -cr`), imza bozuksa ad-hoc imzalar
- Uygulama yalnızca Intel ise Rosetta'yı sessizce kurar
- Kurulum bitince uygulamayı başlatır

## Kurulum

### Hazır sürüm
[Releases](../../releases) sayfasından `elmakurdu-macOS.zip` dosyasını indirin, açın ve `elmakurdu.app` dosyasını `/Applications` içine taşıyın.

İndirilen dosya noterlenmiş (notarized) olmadığı için macOS ilk açılışta engelleyebilir. Çözüm: sağ tık → **Aç**, ya da Terminal'de:

```bash
xattr -cr "/Applications/elmakurdu.app"
```

### Kaynaktan derleme
```bash
git clone https://github.com/<kullanici>/elmakurdu.git
cd elmakurdu
./Olustur.command
```
Çıktı: `build/elmakurdu.app` (ayrıca `/Applications` içine kopyalanır).

## Kullanım

Kurulacak dosyayı `elmakurdu` simgesinin (Finder, Dock veya masaüstü) üzerine sürükleyip bırakın. Gerekirse yönetici şifresi sorulur.

## Proje yapısı

```
src/elmakurdu.applescript   Uygulamanın kaynak kodu (droplet)
src/expand.sh                İç içe zip açıcı (uygulamanın içine gömülür)
assets/elmakurdu.icns        Uygulama simgesi
Olustur.command                Yerel derleme betiği
.github/workflows/build.yml    CI: derler, zip'ler, v* etiketinde Release oluşturur
```

## Sürüm yayınlama

```bash
git tag v1.0.0
git push origin v1.0.0
```
GitHub Actions `macos-15` üzerinde derler ve zip'i Release'e ekler.

## Güvenlik notu

Bu araç Gatekeeper'ın karantina kontrolünü bilerek atlar. Yalnızca güvendiğiniz kaynaklardan indirdiğiniz uygulamalarda kullanın.

## Lisans

MIT, bkz. [LICENSE](LICENSE).
