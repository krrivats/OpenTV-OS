# Shared helpers for the OpenTV OS scripts: Google's adb, talking to the TV, and small prompts.
# Dot-sourced by setup.ps1, restore.ps1 and close-adb.ps1. Windows PowerShell 5.1 or later; nothing else needed.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # 5.1 downloads many times slower while it draws a progress bar
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Kit = Split-Path -Parent $PSScriptRoot
$ToolsDir = Join-Path $Kit 'tools'
$Adb = Join-Path $ToolsDir 'platform-tools\adb.exe'
$script:Device = ''

function Say([string]$text, [string]$colour = 'Gray') { Write-Host $text -ForegroundColor $colour }
function Step([string]$text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }
function Good([string]$text) { Write-Host "   OK  $text" -ForegroundColor Green }
function Warn([string]$text) { Write-Host "   !!  $text" -ForegroundColor Yellow }

function Ask([string]$question, [string]$default = '') {
    $hint = if ($default) { " [$default]" } else { '' }
    $answer = Read-Host "$question$hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim()
}

function Yes([string]$question, [bool]$default = $true) {
    $hint = if ($default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        $a = (Read-Host "$question ($hint)").Trim().ToLower()
        if ($a -eq '') { return $default }
        if ($a -in @('y', 'yes', 'haan', 'ha')) { return $true }
        if ($a -in @('n', 'no', 'nahi')) { return $false }
    }
}

# Google's official Android platform tools (adb), downloaded once into tools\.
function Get-Adb {
    if (Test-Path $Adb) { return }
    Step 'Downloading Google Android platform tools (adb, about 7 MB)'
    New-Item -ItemType Directory -Force $ToolsDir | Out-Null
    $zip = Join-Path $ToolsDir 'platform-tools.zip'
    Invoke-WebRequest 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $ToolsDir -Force
    Remove-Item $zip
    if (-not (Test-Path $Adb)) { throw 'adb.exe was not found after the download' }
    Good 'adb ready'
}

# Connect to the TV over Wi-Fi; the first time, the TV asks "Allow USB debugging?".
function Connect-Tv([string]$ip) {
    $script:Device = if ($ip -match ':\d+$') { $ip } else { "${ip}:5555" }
    & $Adb start-server 2>&1 | Out-Null
    Say "   Connecting to $script:Device ..."
    Say '   If the TV shows "Allow USB debugging?", tick "Always allow from this computer" and choose OK.' 'Yellow'
    for ($i = 0; $i -lt 40; $i++) {
        & $Adb connect $script:Device 2>&1 | Out-Null
        $state = (& $Adb -s $script:Device get-state 2>&1 | Out-String).Trim()
        if ($state -eq 'device') { Good "connected to $script:Device"; return }
        Start-Sleep -Seconds 3
    }
    throw "Could not connect to $script:Device. Check: TV on, same Wi-Fi, USB debugging on, the IP is right, and the prompt on the TV was accepted."
}

# One shell command on the TV, through stdin (5.1 mangles quotes in native arguments). Returns its output.
function Sh([string]$command) {
    $out = $command | & $Adb -s $script:Device shell 2>&1
    return (($out | ForEach-Object { "$_" }) -join "`n").Trim()
}

function Install-Apk([string]$apk, [string]$name) {
    $out = (& $Adb -s $script:Device install -r $apk 2>&1 | Out-String)
    if ($out -notmatch 'Success') { throw "$name did not install: $out" }
    Good "$name installed"
}

function Is-Installed([string]$pkg) { return (Sh "pm list packages $pkg") -match "package:$([regex]::Escape($pkg))(\s|$)" }
function Is-Enabled([string]$pkg) { return -not ((Sh 'pm list packages -d') -match "package:$([regex]::Escape($pkg))(\s|$)") }

# Adds an accessibility service to the enabled list without dropping the others.
function Enable-Service([string]$component) {
    $name = $component.Split('/')[1].TrimStart('.')
    Sh ('s=$(settings get secure enabled_accessibility_services); case "$s" in *' + $name + '*) ;; null|"") settings put secure enabled_accessibility_services ' + $component + ' ;; *) settings put secure enabled_accessibility_services "$s:' + $component + '" ;; esac; settings put secure accessibility_enabled 1') | Out-Null
}

function Latest-Backup {
    $root = Join-Path $Kit 'backup'
    if (-not (Test-Path $root)) { return $null }
    return Get-ChildItem $root -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
