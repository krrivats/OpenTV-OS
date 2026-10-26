# OpenTV OS restore: turns back on everything setup turned off and gives Home back to the TV's own launcher.
# Started by Restore-My-TV.bat. Uses the newest backup\ folder unless you pick another.
param([string]$TvIp = '')
. (Join-Path $PSScriptRoot 'common.ps1')
$Host.UI.RawUI.WindowTitle = 'OpenTV OS restore'

$backups = @(Get-ChildItem (Join-Path $Kit 'backup') -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
if ($backups.Count -eq 0) { throw 'No backup folder found: setup was never run from this folder.' }
$i = 1
foreach ($b in $backups) { Say "   $i) $($b.Name)"; $i++ }
$backup = $backups[[Math]::Max(0, [int](Ask 'Which backup to restore?' '1') - 1)]
if (-not $TvIp) { $TvIp = Ask 'The TV''s IP address' }

Get-Adb
Step 'Connecting to the TV'
Connect-Tv $TvIp

Step 'Turning apps back on'
$log = Join-Path $backup.FullName 'disabled-by-setup.txt'
$pkgs = @(Get-Content $log | Where-Object { $_ -and -not $_.StartsWith('#') } | Select-Object -Unique)
foreach ($p in $pkgs) {
    $out = Sh "pm enable --user 0 $p"
    if ($out -match 'enabled') { Good "on: $p" } else { Warn "$p : $out" }
}

Step 'Giving Home back to the TV''s launcher'
$stockFile = Join-Path $backup.FullName 'stock-home.txt'
if (Test-Path $stockFile) {
    $stock = ((Get-Content $stockFile) -replace '^stock-home=', '').Trim()
    $component = (Sh "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME $stock").Split("`n")[-1].Trim()
    Sh "cmd package set-home-activity --user 0 $component" | Out-Null
    Good "Home: $component"
}
# The OpenTV key helpers off; other accessibility services stay as they were.
$before = Sh 'settings get secure enabled_accessibility_services'
$kept = ($before -split ':' | Where-Object { $_ -and $_ -ne 'null' -and $_ -notmatch 'com.gathin.tvhome|remotebuttons' }) -join ':'
Sh "settings put secure enabled_accessibility_services '$kept'" | Out-Null
Sh 'am force-stop com.gathin.tvhome; input keyevent KEYCODE_HOME' | Out-Null
Good 'restored. The OpenTV apps are still installed (unused); remove them from TV Settings > Apps if you like.'
if (Yes 'Turn off TV debugging now?' $true) {
    Sh 'settings put global adb_wifi_enabled 0; settings put global adb_enabled 0' | Out-Null
    Good 'debugging off'
}
