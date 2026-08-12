$ErrorActionPreference = "Stop"

$TropicalTweaksUrl = "https://raw.githubusercontent.com/nikolas060413/Tropical-Tweaks/main/tropical-tweaks.ps1"

$InstallDir = Join-Path $env:LOCALAPPDATA "TropicalTweaks"
$AppPath = Join-Path $InstallDir "TropicalTweaks.ps1"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Write-Host "Downloading Tropical Tweaks..."
Invoke-WebRequest -UseBasicParsing -Uri $TropicalTweaksUrl -OutFile $AppPath

Write-Host "Opening Tropical Tweaks..."
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $AppPath
