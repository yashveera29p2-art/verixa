# Builds Verixa in release mode and installs it on the phone connected by
# USB. Run it again after any change to update the app on the phone; your
# sign-in and data are kept.
#
#   .\tool\phone.ps1 -ApiUrl https://<user>-verixa-api.hf.space
#        normal use: the app talks to the hosted backend, no cable needed
#   .\tool\phone.ps1
#        development: backend on this PC, reached over USB (adb reverse)
#   .\tool\phone.ps1 -Link
#        only re-create the USB backend link (after re-plugging)
#   add -Reinstall once when switching signing keys (uninstalls first;
#        your account data is in the cloud, just log in again)

param(
  [string]$ApiUrl = 'http://localhost:8001',
  [switch]$Link,
  [switch]$Reinstall
)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
Set-Location (Join-Path $PSScriptRoot '..')
$usbBackend = $ApiUrl -like 'http://localhost*'

$phones = & $adb devices | Select-String "`tdevice$" | Where-Object { $_ -notmatch 'emulator-' }
if (-not $phones) { Write-Error 'No phone connected. Plug it in and allow USB debugging.' }
$serial = (($phones[0].ToString()) -split "`t")[0]

if (-not $Link) {
  flutter build apk --release "--dart-define=VERIXA_API_URL=$ApiUrl"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  if ($Reinstall) { & $adb -s $serial uninstall com.verixa.verixa | Out-Null }
  & $adb -s $serial install -r build\app\outputs\flutter-apk\app-release.apk
}
if ($usbBackend) { & $adb -s $serial reverse tcp:8001 tcp:8001 }
& $adb -s $serial shell monkey -p com.verixa.verixa -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Host "Verixa is installed and open on $serial (backend: $ApiUrl)"
