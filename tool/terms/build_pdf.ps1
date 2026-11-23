# Prints tool/terms/terms.html to docs/terms.pdf with headless Chrome (or Edge).
$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot/../.."
$src = Join-Path $root 'tool/terms/terms.html'
$out = Join-Path $root 'docs/terms.pdf'
$browser = @(
  "$env:ProgramFiles/Google/Chrome/Application/chrome.exe",
  "${env:ProgramFiles(x86)}/Microsoft/Edge/Application/msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw 'Chrome or Edge is needed to print the PDF.' }
& $browser --headless=new --disable-gpu --no-pdf-header-footer "--print-to-pdf=$out" "file:///$($src -replace '\\','/')" | Out-Null
Start-Sleep -Seconds 2
Write-Host "Wrote $out"
