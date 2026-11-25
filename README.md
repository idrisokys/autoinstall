# Installer

macOS 15 (Sequoia) ve Apple Silicon için sürükle-bırak uygulama kurucusu.
`.app`, `.dmg`, `.zip` veya `.pkg` dosyasını simgenin üzerine bırakın; gerisini otomatik halleder.

*A drag-and-drop app installer for macOS 15 on Apple Silicon: drop an `.app`, `.dmg`, `.zip` or `.pkg` onto it and it does the rest.*

## Ne yapar?

- Uygulamayı `/Applications` klasörüne kopyalar; aynı uygulama (aynı ad veya aynı Bundle ID) zaten kuruluysa önce onu kapatıp siler, sonra yenisini kurar (soru sormaz)
- Karantina işaretini kaldırır (`xattr -cr`), böylece "hasarlı / doğrulanamadı" uyarısı çıkmaz
- İmza doğrulanamıyorsa ad-hoc imzalar (`codesign --sign -`)
- Uygulama yalnızca Intel ise ve Rosetta yoksa kurulumunu önerir
- `.dmg` dosyasını bağlar, içindeki uygulamaları kurar, dmg'yi çıkarır
- `.zip` dosyasını açıp içindeki uygulamaları kurar; iki kere (iç içe) zip'lenmiş uygulamalarda da çalışır (zip içinde zip / dmg / pkg, en fazla 6 kat)
- `.pkg` dosyasının karantinasını kaldırıp Yükleyici ile açar
- Kurulan uygulamayı Dock'a ekler (zaten ekliyse dokunmaz)
- Kurulum bitince uygulamayı otomatik başlatır

## Kurulum

### Hazır sürüm
[Releases](../../releases) sayfasından `Installer-macOS.zip` dosyasını indirin, açın ve `Installer.app` dosyasını `/Applications` içine taşıyın.

İndirilen dosya noterlenmiş (notarized) olmadığı için macOS ilk açılışta engelleyebilir. Çözüm: sağ tık → **Aç**, ya da Terminal'de:

```bash
xattr -cr "/Applications/Installer.app"
```

### Kaynaktan derleme
```bash
git clone https://github.com/<kullanici>/Installer.git
cd Installer
./Olustur.command
```
Çıktı: `build/Installer.app` (ayrıca `/Applications` içine kopyalanır).

## Kullanım

Kurulacak dosyayı `Installer` simgesinin (Finder, Dock veya masaüstü) üzerine sürükleyip bırakın. Gerekirse yönetici şifresi sorulur.

Uygulama açılış/bilgi ekranı göstermez. Kurulan uygulamalar otomatik olarak Dock'a eklenir (Dock kısa süre yeniden başlar).

Simge (aşağı oklu kutu) `assets/AppIcon.icns` dosyasıdır; `python3 assets/make_icon.py` ile yeniden üretilebilir (Pillow gerekir).

## Proje yapısı

```
src/Installer.applescript   Uygulamanın kaynak kodu (droplet)
assets/AppIcon.icns            Uygulama simgesi
assets/make_icon.py            Simgeyi üreten betik
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
