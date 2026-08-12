# Tropical Tweaks web launcher
# Host this file as raw text, then run:
# iwr -useb https://your-site.com/tropical-tweaks-web-launcher.ps1 | iex

$ErrorActionPreference = "Stop"

# Replace this with the raw URL of tropical-tweaks.ps1 after you upload it.
$TropicalTweaksUrl = "https://your-site.com/tropical-tweaks.ps1"

$InstallDir = Join-Path $env:LOCALAPPDATA "TropicalTweaks"
$AppPath = Join-Path $InstallDir "TropicalTweaks.ps1"

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

Write-Host "Opening Tropical Tweaks..."
Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile",
    "-STA",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "`"$AppPath`""
) -WindowStyle Hidden

