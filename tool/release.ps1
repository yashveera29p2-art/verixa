# Builds the shareable APK and publishes it as a GitHub Release.
#
#   .\tool\release.ps1 -ApiUrl https://verixa-api.onrender.com -Version 1.2.0
#
# Bump `version:` in pubspec.yaml first so phones accept the update.
#
# Produces ONE file, Verixa.apk (~42 MB), for every real Android phone
# (32- and 64-bit ARM; emulator-only x86 code is left out to keep it small).
# The download page (https://yashveera29p2-art.github.io/verixa) serves its
# own copy at docs/Verixa.apk; the release asset is also named Verixa.apk:
#   https://github.com/yashveera29p2-art/verixa/releases/latest/download/Verixa.apk

param(
  [Parameter(Mandatory = $true)][string]$ApiUrl,
  [Parameter(Mandatory = $true)][string]$Version,
  [switch]$Draft
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$out = 'build\release-apks'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory $out | Out-Null

flutter build apk --release "--dart-define=VERIXA_API_URL=$ApiUrl" --target-platform android-arm,android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item build\app\outputs\flutter-apk\app-release.apk "$out\Verixa.apk"
New-Item -ItemType Directory release -Force | Out-Null
Copy-Item "$out\Verixa.apk" "release\Verixa-$Version.apk"
# The download page serves the APK from its own site (docs/Verixa.apk), so
# every browser downloads it directly instead of bouncing through GitHub.
Copy-Item "$out\Verixa.apk" "docs\Verixa.apk" -Force
git add docs/Verixa.apk
git commit -m "Download page: Verixa $Version APK"
git push

$notes = @"
Verixa $Version - one APK for every Android phone.

**Easiest install:** open https://yashveera29p2-art.github.io/verixa on the phone and tap Download.

Or download **Verixa.apk** below, open it, and tap **Install** (or **Update**).
If Play Protect warns, tap **More details -> Install anyway**.

Sign-in uses phone numbers registered by the project owner.
"@
# Notes go through a file: PowerShell 5 mangles quotes in long arguments.
$notesFile = Join-Path $out 'notes.md'
$notes | Set-Content -Encoding utf8 $notesFile
$flags = @('--title', "Verixa $Version", '--notes-file', $notesFile, '--latest')
if ($Draft) { $flags += '--draft' }
gh release create "v$Version" "$out\Verixa.apk" @flags
