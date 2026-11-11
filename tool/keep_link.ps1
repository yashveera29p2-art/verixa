# Keeps the phone's USB link to the backend alive: every few seconds,
# re-creates `adb reverse tcp:8001` if the phone reconnected and lost it.
# Leave it running in a terminal tab while you use Verixa on the phone.

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
Write-Host 'Keeping the Verixa backend link to your phone alive (Ctrl+C to stop)...'
while ($true) {
  $phones = & $adb devices | Select-String "`tdevice$" | Where-Object { $_ -notmatch 'emulator-' }
  foreach ($p in $phones) {
    $serial = (($p.ToString()) -split "`t")[0]
    $links = & $adb -s $serial reverse --list
    if (-not ($links -match 'tcp:8001')) {
      & $adb -s $serial reverse tcp:8001 tcp:8001 | Out-Null
      Write-Host "$(Get-Date -Format HH:mm:ss) link restored for $serial"
    }
  }
  Start-Sleep -Seconds 3
}
