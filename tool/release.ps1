# Builds the shareable APKs and publishes them.
#
#   .\tool\release.ps1 -ApiUrl https://verixa-api.onrender.com -Version 1.6.0
#
# Bump `version:` in pubspec.yaml first so phones accept the update.
#
# Produces:
#   Verixa.apk        (~21 MB) 64-bit phones: practically every phone from
#                     the last 6-7 years. This is what the one link downloads.
#   Verixa-32bit.apk  (~19 MB) for very old 32-bit-only phones.
#   docs/app/         the iPhone web app (Safari → Add to Home Screen),
#                     served at https://yashveera29p2-art.github.io/verixa/app/
# Both are built with obfuscation and stripped debug info to keep them small.
#
# The download page https://yashveera29p2-art.github.io/verixa serves
# docs/Verixa.apk (and docs/Verixa-32bit.apk) from its own site, so the
# link never changes and always gives the newest version.

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
$common = @('--release', "--dart-define=VERIXA_API_URL=$ApiUrl", "--dart-define=VERIXA_VERSION=$Version", '--obfuscate', '--split-debug-info=build\debug-info')

flutter build apk @common --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item build\app\outputs\flutter-apk\app-release.apk "$out\Verixa.apk"

flutter build apk @common --target-platform android-arm
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item build\app\outputs\flutter-apk\app-release.apk "$out\Verixa-32bit.apk"

# iPhone web app. WebAssembly renderer where Safari supports it; Flutter
# falls back to the JavaScript one on older iPhones by itself.
flutter build web --release --wasm --base-href /verixa/app/ "--dart-define=VERIXA_API_URL=$ApiUrl" "--dart-define=VERIXA_VERSION=$Version"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (Test-Path docs/app) { Remove-Item -Recurse -Force docs/app }
Copy-Item -Recurse build/web docs/app

New-Item -ItemType Directory release -Force | Out-Null
Copy-Item "$out\Verixa.apk" "release\Verixa-$Version.apk"
Copy-Item "$out\Verixa.apk" "docs\Verixa.apk" -Force
Copy-Item "$out\Verixa-32bit.apk" "docs\Verixa-32bit.apk" -Force
git add docs/Verixa.apk docs/Verixa-32bit.apk docs/app
git commit -m "Download page: Verixa $Version APK"
git push

$notes = @"
Verixa $Version

**Install:** open https://yashveera29p2-art.github.io/verixa on the phone. Android: tap Download.
iPhone: tap Open Verixa, then Share → Add to Home Screen.
The same link always gives the newest version; to update, download again and tap **Update**.

Files: **Verixa.apk** for almost all phones; **Verixa-32bit.apk** only for very old phones
where Verixa.apk says "App not installed".
"@
# Notes go through a file: PowerShell 5 mangles quotes in long arguments.
$notesFile = Join-Path $out 'notes.md'
$notes | Set-Content -Encoding utf8 $notesFile
$flags = @('--title', "Verixa $Version", '--notes-file', $notesFile, '--latest')
if ($Draft) { $flags += '--draft' }
gh release create "v$Version" "$out\Verixa.apk" "$out\Verixa-32bit.apk" @flags
