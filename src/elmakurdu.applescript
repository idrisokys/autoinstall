-- elmakurdu: .app / .dmg / .zip / .pkg dosyasını simgenin üzerine bırakın, gerisini o halleder.
-- macOS 15 (Sequoia) + Apple Silicon için hazırlandı.
-- Açılışta hiçbir bilgilendirme ekranı gösterilmez.

property appsFolder : "/Applications/"
global installedPaths

on run
	-- Bilerek boş: çift tıklayınca hiçbir pencere açılmaz.
end run

on open droppedItems
	set installedPaths to {}
	set report to {}
	set hadProblem to false
	repeat with anItem in droppedItems
		set p to POSIX path of anItem
		try
			processItem(p)
		on error errMsg number errNum
			if errNum is not -128 then
				set hadProblem to true
				set end of report to "✗ " & my baseName(p) & ": " & errMsg
			end if
		end try
	end repeat
	
	-- Kurulan uygulamaları başlat
	repeat with ap in installedPaths
		try
			do shell script "open " & quoted form of (contents of ap)
		on error
			set hadProblem to true
			set end of report to "✗ Başlatılamadı: " & my baseName(contents of ap)
		end try
	end repeat
	
	-- Yalnızca hata olursa pencere göster
	if hadProblem then
		set AppleScript's text item delimiters to return
		set msg to report as text
		set AppleScript's text item delimiters to ""
		display dialog msg buttons {"Tamam"} default button 1 with title "elmakurdu" with icon caution
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
		-- Aynı adlı uygulama varsa önce kapat, sonra sil, sonra yenisini kur
		removeExisting(dest)
		shAdmin("ditto " & quoted form of appPath & " " & q)
	end if
	-- 1) Karantina ve diğer genişletilmiş öznitelikleri temizle
	shAdmin("xattr -cr " & q)
	-- 2) İmza bozuksa ad-hoc imzala (Apple Silicon imzasız kodu çalıştırmaz)
	set needSign to false
	try
		sh("codesign --verify --deep --strict " & q & " 2>&1")
	on error
		set needSign to true
	end try
	if needSign then
		try
			shAdmin("codesign --force --deep --sign - " & q)
		end try
	end if
	-- 3) Sadece Intel ise Rosetta'yı sessizce kur
	set archs to sh("exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' " & q & "/Contents/Info.plist 2>/dev/null); lipo -archs " & q & "/Contents/MacOS/\"$exe\" 2>/dev/null || true")
	if archs does not contain "arm64" and archs contains "x86_64" then
		try
			sh("arch -x86_64 /usr/bin/true")
		on error
			try
				shAdmin("softwareupdate --install-rosetta --agree-to-license")
			end try
		end try
	end if
	set end of installedPaths to dest
	return appName & " kuruldu"
end installApp

on removeExisting(dest)
	set q to quoted form of dest
	if sh("[ -e " & q & " ] && echo 1 || echo 0") is not "1" then return
	-- Çalışıyorsa önce nazikçe kapat
	if runningPids(dest) is not "" then
		set bid to sh("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & q & "/Contents/Info.plist 2>/dev/null || true")
		if bid is not "" then
			try
				sh("osascript -e " & quoted form of ("if application id \"" & bid & "\" is running then tell application id \"" & bid & "\" to quit") & " >/dev/null 2>&1 || true")
			end try
		end if
		repeat 12 times
			if runningPids(dest) is "" then exit repeat
			delay 0.5
		end repeat
		-- Hâlâ kapanmadıysa zorla kapat
		set pids to runningPids(dest)
		if pids is not "" then
			try
				sh("kill -9 " & pids)
			end try
			delay 0.5
		end if
	end if
	-- Sil
	shAdmin("rm -rf " & q)
end removeExisting

on runningPids(dest)
	-- dest/Contents/ altından çalışan işlemlerin PID'leri (boşsa çalışmıyor)
	return sh("ps -axo pid=,comm= | awk -v p=" & quoted form of (dest & "/Contents/") & " 'index($0,p){printf \"%s \", $1}'")
end runningPids

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
		set found to paragraphs of sh("find " & quoted form of mountPoint & " -maxdepth 2 -name '*.app' -type d -not -path '*/.*' || true")
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
	set tmp to sh("mktemp -d /tmp/elmakurdu.XXXXXX")
	set helper to POSIX path of (path to resource "expand.sh")
	set keepTmp to false
	try
		-- İç içe zip'leri de aç
		sh("/bin/bash " & quoted form of helper & " " & quoted form of zipPath & " " & quoted form of tmp)
		-- Tercih sırası: .app  >  .dmg  >  .pkg  (hangisi varsa yalnızca o tür kurulur)
		set apps to paragraphs of sh("find " & quoted form of tmp & " -path '*/__MACOSX' -prune -o -name '*.app' -type d -prune -print || true")
		set dmgs to paragraphs of sh("find " & quoted form of tmp & " -path '*/__MACOSX' -prune -o -name '*.app' -type d -prune -o -type f -iname '*.dmg' -print || true")
		set pkgs to paragraphs of sh("find " & quoted form of tmp & " -path '*/__MACOSX' -prune -o -name '*.app' -type d -prune -o -type f -iname '*.pkg' -print || true")
		if (count of apps) > 0 and (item 1 of apps) is not "" then
			set r to installMany(apps)
		else if (count of dmgs) > 0 and (item 1 of dmgs) is not "" then
			set out to {}
			repeat with d in dmgs
				set end of out to installDMG(contents of d)
			end repeat
			set AppleScript's text item delimiters to return & "✓ "
			set r to out as text
			set AppleScript's text item delimiters to ""
		else if (count of pkgs) > 0 and (item 1 of pkgs) is not "" then
			set r to installPkg(item 1 of pkgs)
			set keepTmp to true
		else
			error "Zip içinde .app, .dmg veya .pkg bulunamadı"
		end if
	on error m number n
		try
			sh("rm -rf " & quoted form of tmp)
		end try
		error m number n
	end try
	-- .pkg Yükleyici'de açık kalabilsin diye bu durumda geçici klasör silinmez
	if not keepTmp then sh("rm -rf " & quoted form of tmp)
	return r
end installZip

on installPkg(pkgPath)
	sh("xattr -c " & quoted form of pkgPath)
	sh("open " & quoted form of pkgPath)
	return baseName(pkgPath) & " Yükleyici ile açıldı"
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
