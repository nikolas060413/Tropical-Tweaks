# Tropical Tweaks web launcher
# Host this file as raw text, then run:
# iwr -useb https://your-site.com/tropical-tweaks-web-launcher.ps1 | iex

$ErrorActionPreference = "Stop"

$TropicalTweaksUrl = "https://raw.githubusercontent.com/nikolas060413/Tropical-Tweaks/main/tropical-tweaks.ps1"
$TropicalLogoUrl = "https://raw.githubusercontent.com/nikolas060413/Tropical-Tweaks/main/tropical-logo.png"

$InstallDir = Join-Path $env:LOCALAPPDATA "TropicalTweaks"
$AppPath = Join-Path $InstallDir "TropicalTweaks.ps1"
$LogoPath = Join-Path $InstallDir "tropical-logo.png"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if ($TropicalTweaksUrl -like "https://your-site.com/*") {
    Write-Host "Tropical Tweaks launcher is not configured yet."
    Write-Host "Edit tropical-tweaks-web-launcher.ps1 and replace:"
    Write-Host "  $TropicalTweaksUrl"
    Write-Host "with your real raw script URL."
    return
}

Write-Host "Downloading Tropical Tweaks..."
Invoke-WebRequest -UseBasicParsing -Uri $TropicalTweaksUrl -OutFile $AppPath
Invoke-WebRequest -UseBasicParsing -Uri $TropicalLogoUrl -OutFile $LogoPath

Write-Host "Opening Tropical Tweaks..."
& $AppPath
