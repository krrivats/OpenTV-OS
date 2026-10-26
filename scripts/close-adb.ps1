# Turns off the TV's debugging (USB and network ADB) and checks that port 5555 is closed.
param([string]$TvIp = '')
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $TvIp) { $TvIp = Ask 'The TV''s IP address' }
Get-Adb
Connect-Tv $TvIp
Sh 'settings put global adb_wifi_enabled 0; settings put global adb_enabled 0' | Out-Null
& $Adb disconnect 2>&1 | Out-Null
Start-Sleep -Seconds 3
$client = New-Object System.Net.Sockets.TcpClient
$open = $false
try { $open = $client.ConnectAsync(($TvIp -replace ':\d+$', ''), 5555).Wait(3000) -and $client.Connected } catch { $open = $false } finally { $client.Close() }
if ($open) { Warn 'port 5555 still answers: turn off USB debugging in Developer options on the TV' }
else { Good 'debugging is off and port 5555 is closed' }
Say '   On the TV, also choose Developer options > "Revoke USB debugging authorisations".'
