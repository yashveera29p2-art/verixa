# Builds the shareable APKs and publishes them as a GitHub Release.
#
#   .\tool\release.ps1 -ApiUrl https://<user>-verixa-api.hf.space -Version 1.0.0
#
# Produces:
#   Verixa-<version>-arm64.apk     most phones from the last ~7 years (smaller)
#   Verixa-<version>-universal.apk any Android phone (larger)

param(
  [Parameter(Mandatory = $true)][string]$ApiUrl,
  [Parameter(Mandatory = $true)][string]$Version,
  [switch]$Draft
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$define = "--dart-define=VERIXA_API_URL=$ApiUrl"
$out = 'build\release-apks'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory $out | Out-Null

flutter build apk --release $define --split-per-abi
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item build\app\outputs\flutter-apk\app-arm64-v8a-release.apk "$out\Verixa-$Version-arm64.apk"

flutter build apk --release $define
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item build\app\outputs\flutter-apk\app-release.apk "$out\Verixa-$Version-universal.apk"

$notes = @"
Verixa $Version - AI resume intelligence and builder (academic NLP project).

## Install
1. Download **Verixa-$Version-arm64.apk** (works on most phones). If it says
   "App not installed", use the **universal** APK instead.
2. Open the file. If Android asks, allow **Install unknown apps** for your
   browser or file manager, then tap **Install**.
3. If Play Protect warns that the app is unknown, tap **More details ->
   Install anyway** (the app isn't on the Play Store).

## Log in
During this project phase, sign-in uses phone numbers registered by the
project owner. Ask them to add your number and give you your code.

## Notes
- Resume upload, scanning, job matching and Word export use the hosted
  backend; the first request after a quiet period can take about a minute.
- Your resume files are processed in memory and never stored.
"@
# Notes go through a file: PowerShell 5 mangles quotes in long arguments.
$notesFile = Join-Path $out 'notes.md'
$notes | Set-Content -Encoding utf8 $notesFile
$flags = @('--title', "Verixa $Version", '--notes-file', $notesFile)
if ($Draft) { $flags += '--draft' }
gh release create "v$Version" "$out\Verixa-$Version-arm64.apk" "$out\Verixa-$Version-universal.apk" @flags
