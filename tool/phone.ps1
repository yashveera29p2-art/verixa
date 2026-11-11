# Builds Verixa in release mode (fast, smooth) and installs it on the
# phone connected by USB. Run it again after any change to update the app
# on the phone; your sign-in and data are kept.
#
#   .\tool\phone.ps1            build + install + open on the phone
#   .\tool\phone.ps1 -Link      only re-create the backend link (after re-plugging)
#
# The app reaches the backend (uvicorn on this PC, port 8001) through the
# USB cable via `adb reverse`, so it works on any Wi-Fi, including campus
# networks that block device-to-device traffic. Resume upload, scan and
# match need the cable plugged in and the backend running.

param([switch]$Link)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
Set-Location (Join-Path $PSScriptRoot '..')

$phones = & $adb devices | Select-String "`tdevice$" | Where-Object { $_ -notmatch 'emulator-' }
if (-not $phones) { Write-Error 'No phone connected. Plug it in and allow USB debugging.' }
$serial = (($phones[0].ToString()) -split "`t")[0]

if (-not $Link) {
  flutter build apk --release '--dart-define=VERIXA_API_URL=http://localhost:8001'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $adb -s $serial install -r build\app\outputs\flutter-apk\app-release.apk
}
& $adb -s $serial reverse tcp:8001 tcp:8001
& $adb -s $serial shell monkey -p com.verixa.verixa -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Host "Verixa is installed and open on $serial"
