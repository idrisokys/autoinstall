# Kolay Kurulum

macOS 15 (Sequoia) ve Apple Silicon için sürükle-bırak uygulama kurucusu.
`.app`, `.dmg`, `.zip` veya `.pkg` dosyasını simgenin üzerine bırakın; gerisini otomatik halleder.

*A drag-and-drop app installer for macOS 15 on Apple Silicon: drop an `.app`, `.dmg`, `.zip` or `.pkg` onto it and it does the rest.*

## Ne yapar?

- Uygulamayı `/Applications` klasörüne kopyalar (varsa üzerine yazmadan önce sorar)
- Karantina işaretini kaldırır (`xattr -cr`), böylece "hasarlı / doğrulanamadı" uyarısı çıkmaz
- İmza doğrulanamıyorsa ad-hoc imzalar (`codesign --sign -`)
- Uygulama yalnızca Intel ise ve Rosetta yoksa kurulumunu önerir
- `.dmg` dosyasını bağlar, içindeki uygulamaları kurar, dmg'yi çıkarır
- `.zip` dosyasını açıp içindeki uygulamaları kurar
- `.pkg` dosyasının karantinasını kaldırıp Yükleyici ile açar
- Kurulum bitince uygulamayı otomatik başlatır

## Kurulum

### Hazır sürüm
[Releases](../../releases) sayfasından `KolayKurulum-macOS.zip` dosyasını indirin, açın ve `Kolay Kurulum.app` dosyasını `/Applications` içine taşıyın.

İndirilen dosya noterlenmiş (notarized) olmadığı için macOS ilk açılışta engelleyebilir. Çözüm: sağ tık → **Aç**, ya da Terminal'de:

```bash
xattr -cr "/Applications/Kolay Kurulum.app"
```

### Kaynaktan derleme
```bash
git clone https://github.com/<kullanici>/KolayKurulum.git
cd KolayKurulum
./Olustur.command
```
Çıktı: `build/Kolay Kurulum.app` (ayrıca `/Applications` içine kopyalanır).

## Kullanım

Kurulacak dosyayı `Kolay Kurulum` simgesinin (Finder, Dock veya masaüstü) üzerine sürükleyip bırakın. Gerekirse yönetici şifresi sorulur.

## Proje yapısı

```
src/KolayKurulum.applescript   Uygulamanın kaynak kodu (droplet)
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
