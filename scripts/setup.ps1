# OpenTV OS setup: cleans a Google TV / Android TV over Wi-Fi and installs the OpenTV home screen.
# Started by Setup-My-TV.bat. Every app it turns off is disabled (never uninstalled) and written to backup\,
# so Restore-My-TV.bat can undo it. Needs only Windows PowerShell and the internet (it fetches Google's adb).
param([string]$TvIp = '', [string]$Name = '', [string]$City = '')
. (Join-Path $PSScriptRoot 'common.ps1')
$Host.UI.RawUI.WindowTitle = 'OpenTV OS setup'

Write-Host ''
Write-Host '  OpenTV OS  -  a clean, ad-free home screen for your Google TV' -ForegroundColor White
Write-Host '  Built on CleanYourTV (github.com/Gathin23/cleanyourtv). Nothing is uninstalled; Restore-My-TV undoes it.' -ForegroundColor DarkGray
Write-Host ''
Say 'Before you start, on the TV: Settings > Device Preferences > About > press OK on "Build" 7 times,'
Say 'then Developer options > USB debugging ON (and Network debugging if you see it).'
Say 'Find the TV''s IP address in Settings > Network & Internet > your Wi-Fi.'
Write-Host ''

# ---- 1. Questions ------------------------------------------------------------------------------------------
if (-not $Name) { $Name = Ask 'Your name for the greeting ("Good evening, <name>"; leave empty for none)' }
if (-not $City) { $City = Ask 'Your city for the weather (e.g. Jaipur; leave empty to skip weather)' }
if (-not $TvIp) { $TvIp = Ask 'The TV''s IP address (e.g. 192.168.1.50)' }
if ($TvIp -notmatch '^\d{1,3}(\.\d{1,3}){3}(:\d+)?$') { throw "That does not look like an IP address: $TvIp" }

$place = $null
if ($City) {
    Step "Finding $City"
    $q = [uri]::EscapeDataString($City)
    $found = (Invoke-RestMethod "https://geocoding-api.open-meteo.com/v1/search?count=5&format=json&name=$q").results
    if (-not $found) { Warn "No place called $City found; the weather will be off. Run setup again to retry." }
    else {
        $i = 1
        foreach ($r in $found) { Say ("   {0}) {1}, {2}, {3}" -f $i, $r.name, $r.admin1, $r.country); $i++ }
        $pick = [int](Ask 'Which one?' '1')
        $place = $found[[Math]::Max(0, [Math]::Min($found.Count - 1, $pick - 1))]
        Good ("{0}, {1} ({2:N4}, {3:N4})" -f $place.name, $place.country, $place.latitude, $place.longitude)
    }
}

# ---- 2. Connect ----------------------------------------------------------------------------------------------
Get-Adb
Step 'Connecting to the TV'
Connect-Tv $TvIp
$model = Sh 'getprop ro.product.model'
$brand = Sh 'getprop ro.product.manufacturer'
$android = Sh 'getprop ro.build.version.release'
$sdk = [int](Sh 'getprop ro.build.version.sdk')
Good "$brand $model, Android $android (SDK $sdk)"
if ($sdk -lt 26) { throw 'This TV runs Android older than 8.0; the OpenTV home screen needs Android 8 or later.' }
if ((Sh 'pm list features') -notmatch 'android.software.leanback') { throw 'This does not look like an Android TV / Google TV (no leanback feature). Samsung, LG and Fire TV are not supported.' }

# ---- 3. Backup -----------------------------------------------------------------------------------------------
Step 'Backing up the TV''s app list and settings'
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$safeModel = ($model -replace '[^A-Za-z0-9_-]', '_')
$backup = Join-Path $Kit "backup\$safeModel`_$stamp"
New-Item -ItemType Directory -Force $backup | Out-Null
@{ 'packages-all.txt' = 'pm list packages -f'; 'packages-disabled.txt' = 'pm list packages -d'; 'packages-user.txt' = 'pm list packages -3';
   'settings-global.txt' = 'settings list global'; 'settings-secure.txt' = 'settings list secure'; 'settings-system.txt' = 'settings list system';
   'getprop.txt' = 'getprop'; 'home.txt' = 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME';
   'accessibility.txt' = 'settings get secure enabled_accessibility_services' }.GetEnumerator() | ForEach-Object {
    Sh $_.Value | Out-File -Encoding utf8 (Join-Path $backup $_.Key)
}
$disabledLog = Join-Path $backup 'disabled-by-setup.txt'
"# Packages OpenTV OS setup disabled on $brand $model ($stamp). Restore-My-TV.bat turns them back on." | Out-File -Encoding utf8 $disabledLog
Good "saved in backup\$(Split-Path $backup -Leaf)"

function Disable-Pkg([string]$pkg, [string]$why) {
    if (-not (Is-Installed $pkg) -or -not (Is-Enabled $pkg)) { return }
    $out = Sh "pm disable-user --user 0 $pkg"
    if ($out -match 'disabled') { Add-Content -Encoding utf8 $disabledLog $pkg; Good "off: $why ($pkg)" }
    else { Warn "could not turn off $pkg : $out" }
}

# ---- 4. Storage ----------------------------------------------------------------------------------------------
Step 'Checking free storage'
$freeKb = [int64](Sh "df -k /data | tail -n 1 | awk '{print `$4}'")
Say ("   {0:N0} MB free" -f ($freeKb / 1024))
if ($freeKb -lt 400 * 1024) {
    Warn 'Low storage: clearing app caches (apps rebuild them; nothing personal is deleted)'
    Sh 'pm trim-caches 2G' | Out-Null
    $freeKb = [int64](Sh "df -k /data | tail -n 1 | awk '{print `$4}'")
    Good ("{0:N0} MB free now" -f ($freeKb / 1024))
    if ($freeKb -lt 150 * 1024) { throw 'Still under 150 MB free: uninstall an app you do not use from the TV''s settings, then run setup again.' }
}

# ---- 5. Questions about apps, then turn off what the family does not use -------------------------------------
$list = Get-Content (Join-Path $Kit 'lists\debloat.json') -Raw | ConvertFrom-Json
Step 'Choosing what to turn off'
$toDisable = [ordered]@{}
foreach ($g in $list.groups) {
    $present = @($g.packages.PSObject.Properties | Where-Object { (Is-Installed $_.Name) -and (Is-Enabled $_.Name) })
    if ($present.Count -eq 0) { continue }
    if (Yes $g.question $g.default) { foreach ($p in $present) { $toDisable[$p.Name] = $p.Value } }
}
$apps = @($list.apps.PSObject.Properties | Where-Object { $_.Name -ne '_about' -and (Is-Installed $_.Name) -and (Is-Enabled $_.Name) })
if ($apps.Count -gt 0) {
    Say '   Apps on this TV. Answer n for the ones nobody uses (they are turned off, not deleted):'
    foreach ($a in $apps) { if (-not (Yes "   Keep $($a.Value)?" $true)) { $toDisable[$a.Name] = $a.Value } }
}
$smartTube = Yes 'Also install SmartTube (free YouTube app without ads)? Stock YouTube stays, for voice search' $true

Step 'Turning off the chosen apps'
foreach ($k in $toDisable.Keys) { Disable-Pkg $k $toDisable[$k] }

# Google TV's home (launcherx) stays on: it alone shows voice search results and answers the remote's YouTube
# button. It always takes the Home press first (a system app outranks OpenTV), and the launcher's HomeKeyService
# (stock_home_redirect, window events only) brings OpenTV straight back; held Volume keeps ramping.
$claimants = Sh 'cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
$keepGoogleHome = $claimants -match 'com.google.android.apps.tv.launcherx/'
# Google TV's setup wizard claims Home behind the stock launcher; only with that launcher off can it crash-loop Home.
if (-not $keepGoogleHome -and $claimants -match 'com.google.android.tungsten.setupwraith/') {
    $cname = Sh "dumpsys wifi | grep -o 'cname=[^ ]*' | sort -u"
    if ($cname -match 'setupwraith') {
        throw 'The setup wizard owns this TV''s saved Wi-Fi network; turning it off would drop Wi-Fi and this connection. Re-add the Wi-Fi network from TV Settings (so the network belongs to Settings), then run setup again.'
    }
    Disable-Pkg 'com.google.android.tungsten.setupwraith' 'Google TV setup wizard (only used for first-time setup)'
}

# ---- 6. Apps -------------------------------------------------------------------------------------------------
Step 'Installing the OpenTV apps'
$appsDir = Join-Path $Kit 'apps'
foreach ($a in @(@('OpenTV-Launcher.apk', 'OpenTV home screen'), @('Weather.apk', 'Weather'), @('WorldClock.apk', 'World Clock'))) {
    $apk = Join-Path $appsDir $a[0]
    if (-not (Test-Path $apk)) { throw "apps\$($a[0]) is missing: download the full OpenTV-OS zip from the GitHub Releases page." }
    Install-Apk $apk $a[1]
}

if ($smartTube) {
    Step 'SmartTube (official yuliskov/SmartTube release)'
    $abis = Sh 'getprop ro.product.cpu.abilist'
    $abi = if ($abis -match 'arm64-v8a') { 'arm64-v8a' } elseif ($abis -match 'armeabi-v7a') { 'armeabi-v7a' } else { 'universal' }
    $release = (Invoke-RestMethod 'https://api.github.com/repos/yuliskov/SmartTube/releases?per_page=10') | Where-Object { -not $_.prerelease } | Select-Object -First 1
    $asset = $release.assets | Where-Object { $_.name -like "SmartTube_stable_*_$abi.apk" } | Select-Object -First 1
    if (-not $asset) { Warn "no stable SmartTube for $abi; skipped" }
    else {
        $dl = Join-Path $ToolsDir $asset.name
        Say "   $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)"
        Invoke-WebRequest $asset.browser_download_url -OutFile $dl -UseBasicParsing
        $want = "$($asset.digest)" -replace '^sha256:', ''
        if ($want -and $want -ne (Get-FileHash $dl -Algorithm SHA256).Hash.ToLower()) { Remove-Item $dl; throw 'SmartTube download failed its SHA-256 check; nothing was installed.' }
        Install-Apk $dl 'SmartTube'
    }
}

# ---- 7. Make OpenTV the Home screen (start it, disable the stock home, set it, then check) ----------------------
Step 'Making OpenTV your Home screen'
$known = @('com.google.android.tvlauncher', 'com.google.android.apps.tv.launcherx', 'com.google.android.leanbacklauncher', 'com.mitv.tvhome')
$homeNow = (Sh 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME').Split("`n")[-1].Trim()
$stock = $homeNow.Split('/')[0]
if ($stock -eq 'android') {
    $found = @($known | Where-Object { $claimants -match ([regex]::Escape($_) + '/') })
    $stock = if ($found.Count -eq 1) { $found[0] } else { '' }
}
if ($stock -eq 'com.gathin.tvhome') { $stock = 'none' }
if ($stock -ne 'none' -and $known -notcontains $stock) { throw "Home belongs to '$homeNow', which setup does not know, so it was left alone. Ask for help with the TV model." }
Sh 'am force-stop com.gathin.tvhome' | Out-Null
$set = Sh 'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity'
if ($set -match 'Error') { throw "Could not set the new Home ($set); the stock home was left on." }
$start = Sh 'am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity'
if ($start -notmatch 'Status: ok') { throw "The OpenTV home did not start; the stock home was left on. $start" }
Sh 'pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION 2>/dev/null; cmd package compile -m speed -f com.gathin.tvhome' | Out-Null
if ($stock -eq 'com.google.android.apps.tv.launcherx') { $stock = 'kept' }
if ($stock -notin @('none', 'kept')) {
    Sh "pm disable-user --user 0 $stock" | Out-Null
    Add-Content -Encoding utf8 $disabledLog $stock
    "stock-home=$stock" | Out-File -Encoding utf8 (Join-Path $backup 'stock-home.txt')
}
Sh 'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity' | Out-Null
$homeNow = (Sh 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME').Split("`n")[-1].Trim()
if ($stock -eq 'kept') {
    Good 'OpenTV is Home (the Google TV home stays on for voice search; the Home button always opens OpenTV)'
} elseif ($homeNow -notlike 'com.gathin.tvhome/*') {
    if ($stock -ne 'none') { Sh "pm enable --user 0 $stock" | Out-Null }
    throw "Home resolves to '$homeNow', not OpenTV; the stock home ($stock) was turned back on."
} else { Good 'OpenTV is Home' }

# ---- 8. Theme: your name, city, festivals, weather, wallpapers ------------------------------------------------
Step 'Applying your theme'
$cfg = Get-Content (Join-Path $Kit 'theme\config.json') -Raw | ConvertFrom-Json
$cfg.greeting_name = $Name
if ($place) {
    $cfg.weather_latitude = ('{0:0.0000}' -f $place.latitude).Replace(',', '.')
    $cfg.weather_longitude = ('{0:0.0000}' -f $place.longitude).Replace(',', '.')
    $cfg.weather_place = $place.name
} else {
    $cfg.weather_mood = $false; $cfg.weather_pill = $false
}
$cfgFile = Join-Path $backup 'theme-config.json'
# UTF-8 without a BOM: a Hindi or other non-English name survives, and the launcher's JSON reader takes it.
[IO.File]::WriteAllText($cfgFile, ($cfg | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))
$dir = '/sdcard/Android/data/com.gathin.tvhome/files'
$uri = 'content://com.gathin.tvhome.theme'
function Put-ThemeFile([string]$local, [string]$name) {
    $tmp = '/data/local/tmp/opentv-' + ($name -replace '/', '-')
    & $Adb -s $script:Device push $local $tmp 2>&1 | Out-Null
    # The launcher's provider first (the file then belongs to the launcher), a plain copy where there is none.
    Sh "rm -f $dir/$name 2>/dev/null; { o=`$(content write --uri $uri/$name < $tmp 2>&1) && case `"`$o`" in *'Unsupported operation'*) false ;; esac; } || cp $tmp $dir/$name 2>/dev/null; rm -f $tmp" | Out-Null
}
Sh "mkdir -p $dir/wallpapers 2>/dev/null; true" | Out-Null
Put-ThemeFile $cfgFile 'config.json'
foreach ($w in Get-ChildItem (Join-Path $Kit 'theme\wallpapers') -Filter 'festival-*.jpg') { Put-ThemeFile $w.FullName "wallpapers/$($w.Name)" }
$rev = Join-Path $backup 'theme_revision'
[guid]::NewGuid().ToString('N') | Out-File -Encoding ascii -NoNewline $rev
Put-ThemeFile $rev 'theme_revision'
Good 'theme on the TV'

# ---- 9. Remote buttons ---------------------------------------------------------------------------------------
Step 'Remote buttons'
Enable-Service 'com.gathin.tvhome/.HomeKeyService'           # Google TV's home screen -> OpenTV (stock_home_redirect)
Sh 'cmd appops set com.gathin.tvhome AUTO_START allow 2>/dev/null; appops write-settings 2>/dev/null; true' | Out-Null
# Restart Home so it reads the theme, then bind the helper again (a force stop unbinds it). Android sometimes
# leaves it enabled but unbound after that, so check and retry.
$svc = Sh 'settings get secure enabled_accessibility_services'
Sh 'am force-stop com.gathin.tvhome; am start -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity' | Out-Null
for ($i = 0; $i -lt 4; $i++) {
    Sh ('sleep 2; settings put secure enabled_accessibility_services ""; settings put secure accessibility_enabled 0; sleep 3; settings put secure enabled_accessibility_services "' + $svc + '"; settings put secure accessibility_enabled 1; sleep 5') | Out-Null
    if ((Sh 'dumpsys accessibility | grep -c "com.gathin.tvhome/com.gathin.tvhome.HomeKeyService\|label=Home button"') -ne '0') { break }
}
Good 'Home lands on OpenTV; Volume ramps; voice search and the YouTube button use stock YouTube'

# ---- 10. Done --------------------------------------------------------------------------------------------------
Start-Sleep -Seconds 4
# Through a file on the TV: PowerShell 5.1 would corrupt binary output redirected with >.
Sh 'screencap -p /data/local/tmp/opentv-home.png' | Out-Null
& $Adb -s $script:Device pull /data/local/tmp/opentv-home.png (Join-Path $backup 'home.png') 2>&1 | Out-Null
Sh 'rm -f /data/local/tmp/opentv-home.png' | Out-Null
Step 'All done'
Say '   On the TV: open Weather once and pick your city; World Clock: add any cities you like.'
Say '   Remote Buttons app: change what an app button opens. Undo everything: double-click Restore-My-TV.bat.'
Say "   Backup and screenshot: backup\$(Split-Path $backup -Leaf)"
if (Yes 'Turn off TV debugging now? (recommended; turn it on again for changes)' $true) {
    Sh 'settings put global adb_wifi_enabled 0; settings put global adb_enabled 0' | Out-Null
    Good 'debugging off. Also choose "Revoke USB debugging authorisations" in Developer options on the TV.'
}
