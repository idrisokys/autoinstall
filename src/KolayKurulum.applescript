-- Kolay Kurulum: .app / .dmg / .zip / .pkg dosyasını simgenin üzerine bırakın, gerisini o halleder.
-- macOS 15 (Sequoia) + Apple Silicon için hazırlandı.

property appsFolder : "/Applications/"
global installedPaths

on run
	display dialog "Kurulacak dosyayı (.app, .dmg, .zip veya .pkg) bu simgenin üzerine sürükleyip bırakın." & return & return & "Otomatik yapılanlar:" & return & "• /Applications klasörüne kopyalama" & return & "• Karantina (\"hasarlı/doğrulanamadı\") işaretini kaldırma" & return & "• Gerekirse imzayı onarma (ad-hoc)" & return & "• Gerekirse Rosetta kurulumu" & return & "• Kurulum bitince uygulamayı otomatik başlatma" buttons {"Tamam"} default button 1 with title "Kolay Kurulum" with icon note
end run

on open droppedItems
	set installedPaths to {}
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
		display dialog msg buttons {"Tamam"} default button 1 with title "Kolay Kurulum" with icon caution
	else if (count of installedPaths) > 0 then
		display notification "Kuruldu ve başlatıldı: " & (count of installedPaths) & " uygulama" with title "Kolay Kurulum"
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
	set appName to baseName(appPath)
	set dest to appsFolder & appName
	set q to quoted form of dest
	if appPath is not dest then
		set alreadyThere to (sh("[ -e " & q & " ] && echo 1 || echo 0") is "1")
		if alreadyThere then
			display dialog appName & " zaten kurulu. Üzerine yazılsın mı?" buttons {"İptal", "Değiştir"} default button 2 cancel button 1 with title "Kolay Kurulum" with icon caution
			shAdmin("rm -rf " & q)
		end if
		shAdmin("ditto " & quoted form of appPath & " " & q)
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
			display dialog appName & " Intel (x86_64) uygulaması; Rosetta 2 gerekiyor. Şimdi kurulsun mu?" buttons {"Hayır", "Rosetta Kur"} default button 2 with title "Kolay Kurulum"
			if button returned of result is "Rosetta Kur" then
				shAdmin("softwareupdate --install-rosetta --agree-to-license")
				set notes to notes & " [Rosetta kuruldu]"
			end if
		end if
	end if
	set end of installedPaths to dest
	return appName & " kuruldu" & notes
end installApp

on installMany(appList)
	set out to {}
	repeat with a in appList
		if (contents of a) is not "" then set end of out to installApp(contents of a)
	end repeat
	if (count of out) is 0 then error "İçinde .app bulunamadı"
	set AppleScript's text item delimiters to return & "✓ "
	set t to out as text
	set AppleScript's text item delimiters to ""
	return t
end installMany

on installDMG(dmgPath)
	set outp to sh("yes | hdiutil attach -nobrowse -readonly -noverify " & quoted form of dmgPath & " | tail -1")
	set mountPoint to sh("echo " & quoted form of outp & " | cut -f3-")
	if mountPoint is "" then error "DMG bağlanamadı"
	try
		set found to paragraphs of sh("find " & quoted form of mountPoint & " -maxdepth 2 -name '*.app' -not -path '*/.*' || true")
		set r to installMany(found)
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
	set tmp to sh("mktemp -d")
	try
		sh("ditto -x -k " & quoted form of zipPath & " " & quoted form of tmp)
		set found to paragraphs of sh("find " & quoted form of tmp & " -maxdepth 3 -name '*.app' -not -path '*/__MACOSX/*' || true")
		set r to installMany(found)
	on error m number n
		try
			sh("rm -rf " & quoted form of tmp)
		end try
		error m number n
	end try
	sh("rm -rf " & quoted form of tmp)
	return r
end installZip

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
