-- Installer: .app / .dmg / .zip / .pkg dosyasını simgenin üzerine bırakın, gerisini o halleder.
-- macOS 15 (Sequoia) + Apple Silicon için hazırlandı.

property appsFolder : "/Applications/"
property nestLevel : 0
property maxNest : 6
global installedPaths

on run
	-- Bilgi ekranı yok: simgeye çift tıklanırsa hiçbir şey göstermeden kapanır.
	-- Dosyalar simgenin üzerine bırakılınca "on open" çalışır.
end run

on open droppedItems
	global installedPaths
	set installedPaths to {}
	set nestLevel to 0
	set report to {}
	set hadProblem to false
	repeat with anItem in droppedItems
		set p to POSIX path of anItem
		try
			set r to processItem(p)
			set end of report to "✓ " & r
		on error errMsg number errNum
			set hadProblem to true
			if errNum is -128 then
				set end of report to "– İptal edildi: " & my baseName(p)
			else
				set end of report to "✗ " & my baseName(p) & ": " & errMsg
			end if
		end try
	end repeat
	
	-- Kurulan uygulamaları Dock'a ekle (zaten varsa dokunmaz)
	set dockChanged to false
	repeat with ap in installedPaths
		try
			if sh("/bin/bash -c " & quoted form of dockScript() & " _ " & quoted form of (contents of ap)) is "added" then set dockChanged to true
		end try
	end repeat
	if dockChanged then
		try
			sh("killall Dock")
		end try
	end if
	
	-- Kurulan uygulamaları otomatik başlat
	repeat with ap in installedPaths
		try
			do shell script "open " & quoted form of (contents of ap)
		on error
			set hadProblem to true
			set end of report to "✗ Başlatılamadı: " & my baseName(contents of ap)
		end try
	end repeat
	
	if hadProblem then
		set AppleScript's text item delimiters to return
		set msg to report as text
		set AppleScript's text item delimiters to ""
		display dialog msg buttons {"Tamam"} default button 1 with title "Installer" with icon caution
	else if (count of installedPaths) > 0 then
		display notification "Kuruldu, Dock'a eklendi ve başlatıldı: " & (count of installedPaths) & " uygulama" with title "Installer"
	end if
end open

on processItem(p)
	if p ends with "/" then set p to text 1 thru -2 of p
	set lowerP to sh("echo " & quoted form of p & " | tr '[:upper:]' '[:lower:]'")
	if lowerP ends with ".app" then return installApp(p)
	if lowerP ends with ".dmg" then return installDMG(p)
	if lowerP ends with ".zip" then return installZip(p)
	if lowerP ends with ".pkg" then return installPkg(p)
	error "Desteklenmeyen dosya türü (.app, .dmg, .zip, .pkg olmalı)"
end processItem

-- ===== Kurulum işleyicileri =====

on installApp(appPath)
	global installedPaths
	set appName to baseName(appPath)
	set dest to appsFolder & appName
	set q to quoted form of dest
	if appPath is not dest then
		-- Kurulu sürüm (aynı ad veya aynı Bundle ID) varsa önce kaldırılır, sonra yenisi kurulur
		shAdmin("/bin/bash -c " & quoted form of replaceScript() & " _ " & quoted form of appPath & " " & quoted form of dest)
	end if
	-- 1) Karantina ve diğer genişletilmiş öznitelikleri temizle
	shAdmin("xattr -cr " & q)
	-- 2) İmza bozuksa ad-hoc imzala (Apple Silicon imzasız kodu çalıştırmaz)
	set notes to ""
	set needSign to false
	try
		sh("codesign --verify --deep --strict " & q & " 2>&1")
	on error
		set needSign to true
	end try
	if needSign then
		try
			shAdmin("codesign --force --deep --sign - " & q)
			set notes to notes & " [imza onarıldı]"
		on error
			set notes to notes & " [imza onarılamadı]"
		end try
	end if
	-- 3) Sadece Intel ise Rosetta kontrolü
	set archs to sh("exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' " & q & "/Contents/Info.plist 2>/dev/null); lipo -archs " & q & "/Contents/MacOS/\"$exe\" 2>/dev/null || true")
	if archs does not contain "arm64" and archs contains "x86_64" then
		set hasRosetta to true
		try
			sh("arch -x86_64 /usr/bin/true")
		on error
			set hasRosetta to false
		end try
		if not hasRosetta then
			display dialog appName & " Intel (x86_64) uygulaması; Rosetta 2 gerekiyor. Şimdi kurulsun mu?" buttons {"Hayır", "Rosetta Kur"} default button 2 with title "Installer"
			if button returned of result is "Rosetta Kur" then
				shAdmin("softwareupdate --install-rosetta --agree-to-license")
				set notes to notes & " [Rosetta kuruldu]"
			end if
		end if
	end if
	set end of installedPaths to dest
	return appName & " kuruldu" & notes
end installApp

-- Yeni sürümü önce geçici adla kopyalar (kopyalama başarısız olursa eski uygulama silinmez),
-- sonra aynı ada veya aynı Bundle ID'ye sahip kurulu uygulamaları kapatıp siler ve yenisini yerine koyar.
on replaceScript()
	set L to {}
	set end of L to "set -e"
	set end of L to "src=\"$1\"; dest=\"$2\""
	set end of L to "pb=/usr/libexec/PlistBuddy"
	set end of L to "bid=$($pb -c 'Print :CFBundleIdentifier' \"$src/Contents/Info.plist\" 2>/dev/null || true)"
	set end of L to "new=\"$dest.kknew\""
	set end of L to "rm -rf \"$new\""
	set end of L to "ditto \"$src\" \"$new\""
	set end of L to "for a in /Applications/*.app; do"
	set end of L to "  [ -d \"$a\" ] || continue"
	set end of L to "  [ \"$a\" = \"$src\" ] && continue"
	set end of L to "  id=$($pb -c 'Print :CFBundleIdentifier' \"$a/Contents/Info.plist\" 2>/dev/null || true)"
	set end of L to "  if [ \"$a\" = \"$dest\" ] || { [ -n \"$bid\" ] && [ \"$id\" = \"$bid\" ]; }; then"
	set end of L to "    if [ -n \"$id\" ]; then osascript -e \"if application id \\\"$id\\\" is running then tell application id \\\"$id\\\" to quit\" >/dev/null 2>&1 || true; fi"
	set end of L to "    sleep 1"
	set end of L to "    pkill -f \"$a/Contents/MacOS/\" 2>/dev/null || true"
	set end of L to "    rm -rf \"$a\""
	set end of L to "  fi"
	set end of L to "done"
	set end of L to "rm -rf \"$dest\""
	set end of L to "mv \"$new\" \"$dest\""
	set AppleScript's text item delimiters to linefeed
	set t to L as text
	set AppleScript's text item delimiters to ""
	return t
end replaceScript

-- Uygulamayı kullanıcının Dock'una ekler. Dock'ta zaten varsa "exists", eklediyse "added" döner.
on dockScript()
	set L to {}
	set end of L to "p=\"$1\""
	set end of L to "enc=$(printf %s \"$p\" | sed 's/%/%25/g; s/ /%20/g; s/&/%26/g; s/</%3C/g; s/>/%3E/g; s/#/%23/g')"
	set end of L to "cur=$(defaults read com.apple.dock persistent-apps 2>/dev/null || true)"
	set end of L to "if printf %s \"$cur\" | grep -qF \"file://$enc/\"; then echo exists; exit 0; fi"
	set end of L to "defaults write com.apple.dock persistent-apps -array-add \"<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://$enc/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>\""
	set end of L to "echo added"
	set AppleScript's text item delimiters to linefeed
	set t to L as text
	set AppleScript's text item delimiters to ""
	return t
end dockScript

on installMany(appList)
	set out to {}
	repeat with a in appList
		if (contents of a) is not "" then set end of out to installApp(contents of a)
	end repeat
	if (count of out) is 0 then error "İçinde .app bulunamadı"
	return joinResults(out)
end installMany

on joinResults(lst)
	set AppleScript's text item delimiters to return & "✓ "
	set t to lst as text
	set AppleScript's text item delimiters to ""
	return t
end joinResults

on nonEmpty(lst)
	set out to {}
	repeat with a in lst
		if (contents of a) is not "" then set end of out to (contents of a)
	end repeat
	return out
end nonEmpty

-- Bir klasörün içinde (.dmg bağlama noktası veya açılmış .zip) önce .app arar;
-- .app yoksa iç içe arşivleri (zip içinde zip / dmg / pkg) bulup aynı işlemi onlar için tekrarlar.
on installFromFolder(folder, md)
	set qf to quoted form of folder
	set skip to "\\( -name __MACOSX -o -name '._*' \\) -prune -o "
	set apps to nonEmpty(paragraphs of sh("find " & qf & " -maxdepth " & md & " " & skip & "-type d -iname '*.app' -prune -print || true"))
	if (count of apps) > 0 then return installMany(apps)

	set nested to nonEmpty(paragraphs of sh("find " & qf & " -maxdepth " & md & " " & skip & "-type d -iname '*.app' -prune -o -type f \\( -iname '*.zip' -o -iname '*.dmg' -o -iname '*.pkg' \\) -print || true"))
	set isOdd to false
	if (count of nested) is 0 then
		-- Uzantısı eksik/yanlış olan iç zip dosyaları (içeriğine bakarak bulunur)
		set nested to nonEmpty(paragraphs of sh("find " & qf & " -maxdepth " & md & " " & skip & "-type d -iname '*.app' -prune -o -type f -print | while IFS= read -r f; do case \"$(file -b \"$f\")\" in Zip\\ archive*) echo \"$f\";; esac; done || true"))
		set isOdd to true
	end if
	if (count of nested) is 0 then error "İçinde .app bulunamadı"

	set results to {}
	set lastErr to ""
	repeat with n in nested
		set np to contents of n
		try
			if isOdd then
				set end of results to installZip(np)
			else
				set end of results to processNested(np)
			end if
		on error m number num
			if num is -128 then error m number num
			set lastErr to m
		end try
	end repeat
	if (count of results) is 0 then error lastErr
	return joinResults(results)
end installFromFolder

on processNested(p)
	set lowerP to sh("echo " & quoted form of p & " | tr '[:upper:]' '[:lower:]'")
	if lowerP ends with ".dmg" then return installDMG(p)
	if lowerP ends with ".pkg" then
		-- Geçici klasör silineceği için pkg'yi kalıcı bir yere kopyalayıp öyle aç
		set keepDir to sh("mktemp -d")
		sh("cp " & quoted form of p & " " & quoted form of keepDir & "/")
		return installPkg(keepDir & "/" & baseName(p))
	end if
	return installZip(p)
end processNested

on installDMG(dmgPath)
	set outp to sh("yes | hdiutil attach -nobrowse -readonly -noverify " & quoted form of dmgPath & " | tail -1")
	set mountPoint to sh("echo " & quoted form of outp & " | cut -f3-")
	if mountPoint is "" then error "DMG bağlanamadı"
	try
		set r to installFromFolder(mountPoint, 2)
	on error m number n
		try
			sh("hdiutil detach " & quoted form of mountPoint & " -force")
		end try
		error m number n
	end try
	try
		sh("hdiutil detach " & quoted form of mountPoint & " -force")
	end try
	return r
end installDMG

on installZip(zipPath)
	if nestLevel ≥ maxNest then error "Arşiv çok fazla iç içe (en fazla " & maxNest & " kat)"
	set nestLevel to nestLevel + 1
	set tmp to sh("mktemp -d")
	try
		extractZip(zipPath, tmp)
		set r to installFromFolder(tmp, 4)
	on error m number n
		set nestLevel to nestLevel - 1
		try
			sh("rm -rf " & quoted form of tmp)
		end try
		error m number n
	end try
	set nestLevel to nestLevel - 1
	sh("rm -rf " & quoted form of tmp)
	return r
end installZip

on extractZip(zipPath, destDir)
	try
		sh("ditto -x -k " & quoted form of zipPath & " " & quoted form of destDir)
	on error
		-- ditto bazı zip'leri açamazsa unzip ile dene
		sh("/usr/bin/unzip -qq -o " & quoted form of zipPath & " -d " & quoted form of destDir)
	end try
end extractZip

on installPkg(pkgPath)
	sh("xattr -c " & quoted form of pkgPath)
	sh("open " & quoted form of pkgPath)
	return baseName(pkgPath) & " Yükleyici ile açıldı (karantina kaldırıldı)"
end installPkg

-- ===== Yardımcılar =====

on sh(cmd)
	return do shell script cmd
end sh

on shAdmin(cmd)
	try
		return do shell script cmd
	on error
		return do shell script cmd with administrator privileges
	end try
end shAdmin

on baseName(p)
	return do shell script "basename " & quoted form of p
end baseName
