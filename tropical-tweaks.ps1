# Tropical Tweaks
# A Windows tweak picker focused on lower overhead, smoother games, and clearer plans.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Continue"

if ($PSCommandPath) {
    $AppDir = Split-Path -Parent $PSCommandPath
} else {
    $AppDir = Join-Path $env:LOCALAPPDATA "TropicalTweaks"
}

if (-not (Test-Path $AppDir)) {
    New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
}

$BackupDir = Join-Path $AppDir "TropicalTweaks_Backups"
$LogoPath = Join-Path $AppDir "tropical-logo.png"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-AsAdmin {
    if (-not $PSCommandPath) {
        [System.Windows.Forms.MessageBox]::Show(
            "This session was started from memory. Use the web launcher so Tropical Tweaks is saved locally before restart-as-admin.",
            "Restart as admin",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    try {
        [Diagnostics.Process]::Start($psi) | Out-Null
        exit
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Tropical Tweaks needs administrator permission for system-level gaming tweaks.",
            "Administrator permission",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
}

function Set-RegValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Save-RegistryBackup {
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $BackupDir "registry_backup_$stamp"
    New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

    $keys = @(
        @{ Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; File = "content_delivery.reg" },
        @{ Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; File = "explorer_advanced.reg" },
        @{ Key = "HKCU\System\GameConfigStore"; File = "game_config_store.reg" },
        @{ Key = "HKCU\Software\Microsoft\GameBar"; File = "game_bar.reg" },
        @{ Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; File = "game_dvr_user.reg" },
        @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; File = "game_dvr_policy.reg" },
        @{ Key = "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; File = "power_throttling.reg" },
        @{ Key = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; File = "graphics_drivers.reg" },
        @{ Key = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; File = "multimedia_profile.reg" }
    )

    foreach ($item in $keys) {
        $target = Join-Path $backupPath $item.File
        & reg.exe export $item.Key $target /y | Out-Null
    }

    return "Registry backup saved to: $backupPath"
}

function New-RestorePoint {
    try {
        Checkpoint-Computer -Description "Before Tropical Tweaks" -RestorePointType "MODIFY_SETTINGS"
        return "Restore point created."
    } catch {
        return "Restore point skipped: $($_.Exception.Message)"
    }
}

function Clear-UserTempFiles {
    $tempPaths = @($env:TEMP, "$env:LOCALAPPDATA\Temp")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Set-HighPerformancePower {
    try {
        powercfg /setactive SCHEME_MIN | Out-Null
        return "High performance power plan enabled."
    } catch {
        return "High performance power plan skipped."
    }
}

function Set-UltimatePerformancePower {
    $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    try {
        powercfg -duplicatescheme $ultimateGuid | Out-Null
        powercfg /setactive $ultimateGuid | Out-Null
        return "Ultimate Performance power plan enabled."
    } catch {
        return "Ultimate Performance unavailable; kept current power plan."
    }
}

function Find-FiveMPaths {
    $paths = New-Object System.Collections.Generic.List[string]
    $candidateRoots = @(
        "$env:LOCALAPPDATA\FiveM",
        "$env:APPDATA\CitizenFX",
        "$env:ProgramFiles\FiveM",
        "${env:ProgramFiles(x86)}\FiveM"
    )

    foreach ($root in $candidateRoots) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "FiveM*.exe" -or $_.Name -like "*GTAProcess*.exe" } |
                ForEach-Object { $paths.Add($_.FullName) }
        }
    }

    return $paths | Select-Object -Unique
}

function Invoke-FiveMTweaks {
    $log = New-Object System.Collections.Generic.List[string]
    $fiveMPaths = Find-FiveMPaths

    if (-not $fiveMPaths -or $fiveMPaths.Count -eq 0) {
        $log.Add("FiveM install not found automatically. Windows gaming tweaks were still applied.")
        return $log
    }

    foreach ($path in $fiveMPaths) {
        $log.Add("Applying FiveM high-performance GPU preference: $path")
        Set-RegValue "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $path "GpuPreference=2;" ([Microsoft.Win32.RegistryValueKind]::String)

        $log.Add("Disabling fullscreen optimizations for: $path")
        Set-RegValue "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" $path "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" ([Microsoft.Win32.RegistryValueKind]::String)
    }

    $log.Add("Setting FiveM launcher CPU priority preference to High.")
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FiveM.exe\PerfOptions" "CpuPriorityClass" 3

    return $log
}

function Clear-FiveMCache {
    $log = New-Object System.Collections.Generic.List[string]
    $cacheRoots = @(
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\cache",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\server-cache",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\server-cache-priv",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\nui-storage"
    )

    foreach ($path in $cacheRoots) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            $log.Add("Cleaned FiveM cache: $path")
        }
    }

    if ($log.Count -eq 0) {
        $log.Add("FiveM cache folders not found.")
    }

    return $log
}

function Find-FortnitePaths {
    $paths = New-Object System.Collections.Generic.List[string]
    $candidateRoots = @(
        "$env:ProgramFiles\Epic Games\Fortnite",
        "${env:ProgramFiles(x86)}\Epic Games\Fortnite",
        "C:\Epic Games\Fortnite",
        "D:\Epic Games\Fortnite",
        "E:\Epic Games\Fortnite",
        "C:\Games\Fortnite",
        "D:\Games\Fortnite",
        "E:\Games\Fortnite"
    )

    foreach ($root in $candidateRoots) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -eq "FortniteClient-Win64-Shipping.exe" -or
                    $_.Name -eq "FortniteLauncher.exe" -or
                    $_.Name -eq "FortniteClient-Win64-Shipping_EAC.exe" -or
                    $_.Name -eq "FortniteClient-Win64-Shipping_BE.exe"
                } |
                ForEach-Object { $paths.Add($_.FullName) }
        }
    }

    return $paths | Select-Object -Unique
}

function Invoke-FortniteTweaks {
    $log = New-Object System.Collections.Generic.List[string]
    $fortnitePaths = Find-FortnitePaths

    if (-not $fortnitePaths -or $fortnitePaths.Count -eq 0) {
        $log.Add("Fortnite install not found automatically. Windows gaming tweaks were still applied.")
        return $log
    }

    foreach ($path in $fortnitePaths) {
        $log.Add("Applying Fortnite high-performance GPU preference: $path")
        Set-RegValue "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $path "GpuPreference=2;" ([Microsoft.Win32.RegistryValueKind]::String)

        $log.Add("Disabling fullscreen optimizations for: $path")
        Set-RegValue "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" $path "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" ([Microsoft.Win32.RegistryValueKind]::String)
    }

    $log.Add("Setting Fortnite CPU priority preference to High.")
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FortniteClient-Win64-Shipping.exe\PerfOptions" "CpuPriorityClass" 3

    return $log
}

function Clear-FortniteCache {
    $log = New-Object System.Collections.Generic.List[string]
    $cacheRoots = @(
        "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache",
        "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache_4147",
        "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache_4430",
        "$env:LOCALAPPDATA\FortniteGame\Saved\Logs",
        "$env:TEMP\FortniteGame"
    )

    foreach ($path in $cacheRoots) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            $log.Add("Cleaned Fortnite/Epic cache: $path")
        }
    }

    if ($log.Count -eq 0) {
        $log.Add("Fortnite/Epic cache folders not found.")
    }

    return $log
}

function Invoke-MinimalTweaks {
    param(
        [bool]$FiveMMode,
        [bool]$FortniteMode
    )

    $log = New-Object System.Collections.Generic.List[string]

    $log.Add("Reducing Windows tips and suggested content.")
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-310093Enabled" 0
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0

    $log.Add("Disabling transparency effects to lower desktop overhead.")
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

    $log.Add("Making menus feel faster.")
    Set-RegValue "HKCU:\Control Panel\Desktop" "MenuShowDelay" "100" ([Microsoft.Win32.RegistryValueKind]::String)

    $log.Add("Clearing user temporary files.")
    Clear-UserTempFiles

    $log.Add("Enabling Windows Game Mode.")
    Set-RegValue "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    Set-RegValue "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1

    $log.Add("Disabling Windows background game capture.")
    Set-RegValue "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0

    if ($FiveMMode) {
        foreach ($line in (Invoke-FiveMTweaks)) {
            $log.Add($line)
        }
    }

    if ($FortniteMode) {
        foreach ($line in (Invoke-FortniteTweaks)) {
            $log.Add($line)
        }
    }

    return $log
}

function Invoke-StandardTweaks {
    param(
        [bool]$FiveMMode,
        [bool]$FortniteMode
    )

    $log = Invoke-MinimalTweaks -FiveMMode $FiveMMode -FortniteMode $FortniteMode

    $log.Add((Set-HighPerformancePower))

    $log.Add("Disabling Xbox Game DVR and background capture.")
    Set-RegValue "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-RegValue "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0

    $log.Add("Disabling Windows power throttling for stronger foreground performance.")
    Set-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1

    $log.Add("Reducing app launch tracking and advertising ID.")
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0

    $log.Add("Enabling Storage Sense.")
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 1

    return $log
}

function Invoke-AdvancedTweaks {
    param(
        [bool]$EnableHags,
        [bool]$UseUltimatePower,
        [bool]$FiveMMode,
        [bool]$FortniteMode
    )

    $log = Invoke-StandardTweaks -FiveMMode $FiveMMode -FortniteMode $FortniteMode

    if ($UseUltimatePower) {
        $log.Add((Set-UltimatePerformancePower))
    }

    if ($EnableHags) {
        $log.Add("Enabling Hardware-accelerated GPU scheduling. Restart required.")
        Set-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
    }

    $log.Add("Disabling hibernation and Fast Startup.")
    powercfg /hibernate off

    $log.Add("Applying gaming-focused multimedia scheduler priorities.")
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 10
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xffffffff
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" "High" ([Microsoft.Win32.RegistryValueKind]::String)

    $log.Add("Setting visual effects toward performance while keeping font smoothing.")
    Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
    Set-RegValue "HKCU:\Control Panel\Desktop" "FontSmoothing" "2" ([Microsoft.Win32.RegistryValueKind]::String)

    if ($FiveMMode) {
        foreach ($line in (Clear-FiveMCache)) {
            $log.Add($line)
        }
    }

    if ($FortniteMode) {
        foreach ($line in (Clear-FortniteCache)) {
            $log.Add($line)
        }
    }

    return $log
}

$planDetails = @{
    Minimal = @(
        "Best for: fast FiveM/Fortnite setup with low risk",
        "FPS target: +20-25 FPS when background capture/GPU preference was hurting your game",
        "Note: FPS is not guaranteed; it depends on server, map, GPU, CPU, RAM, drivers, and thermals",
        "Reduce Windows tips, suggestions, and notification clutter",
        "Disable transparency effects",
        "Clear temporary files",
        "Enable Game Mode and disable background capture",
        "Apply selected game GPU preference/fullscreen optimization tweaks"
    )
    Standard = @(
        "Best for: FiveM/Fortnite setup most players should use",
        "FPS target: +35-40 FPS when capture, Game DVR, power limits, or bad GPU preference were hurting performance",
        "Note: strongest improvements are usually smoother FPS and better 1% lows",
        "Everything in Minimal",
        "Enable High performance power plan",
        "Disable Xbox Game DVR/background capture",
        "Disable Windows power throttling",
        "Game modes: high-performance GPU preference and fullscreen optimization tweak"
    )
    Advanced = @(
        "Best for: FiveM/Fortnite desktop setup where FPS consistency matters most",
        "FPS target: +45-50 FPS on PCs heavily limited by Windows overhead, cache, or power behavior",
        "Note: no honest optimizer can guarantee the same FPS gain on every PC/server",
        "Everything in Standard",
        "Optional Ultimate Performance power plan",
        "Optional Hardware-accelerated GPU scheduling",
        "Disable hibernation and Fast Startup",
        "Apply gaming multimedia scheduler priorities",
        "Clean selected FiveM/Fortnite cache folders"
    )
}

$Deep = [System.Drawing.Color]::FromArgb(236, 253, 245)
$Surface = [System.Drawing.Color]::FromArgb(255, 255, 255)
$Surface2 = [System.Drawing.Color]::FromArgb(248, 255, 251)
$Surface3 = [System.Drawing.Color]::FromArgb(232, 250, 242)
$Mint = [System.Drawing.Color]::FromArgb(13, 148, 136)
$MintDark = [System.Drawing.Color]::FromArgb(15, 118, 110)
$Cyan = [System.Drawing.Color]::FromArgb(8, 145, 178)
$Gold = [System.Drawing.Color]::FromArgb(245, 181, 61)
$Text = [System.Drawing.Color]::FromArgb(13, 38, 35)
$Muted = [System.Drawing.Color]::FromArgb(78, 104, 99)
$Border = [System.Drawing.Color]::FromArgb(176, 223, 211)
$Danger = [System.Drawing.Color]::FromArgb(190, 18, 60)

function New-Panel {
    param(
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [System.Drawing.Color]$BackColor
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($X, $Y)
    $panel.Size = New-Object System.Drawing.Size($W, $H)
    $panel.BackColor = $BackColor
    $panel.BorderStyle = "FixedSingle"
    return $panel
}

function New-TextLabel {
    param(
        [string]$TextValue,
        [int]$X,
        [int]$Y,
        [System.Drawing.Font]$Font,
        [System.Drawing.Color]$ForeColor
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $TextValue
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Font = $Font
    $label.ForeColor = $ForeColor
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.AutoSize = $true
    return $label
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Tropical Tweaks"
$form.Size = New-Object System.Drawing.Size(980, 665)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(930, 625)
$form.BackColor = $Deep
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$shellPanel = New-Panel 18 16 928 600 $Surface
$form.Controls.Add($shellPanel)

$headerPanel = New-Panel 20 18 888 128 $Surface2
$shellPanel.Controls.Add($headerPanel)

if (Test-Path $LogoPath) {
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Location = New-Object System.Drawing.Point(22, 17)
    $logo.Size = New-Object System.Drawing.Size(96, 96)
    $logo.SizeMode = "Zoom"
    $logo.Image = [System.Drawing.Image]::FromFile($LogoPath)
    $headerPanel.Controls.Add($logo)
}

$title = New-TextLabel "Tropical Tweaks" 136 22 (New-Object System.Drawing.Font("Segoe UI Semibold", 27)) $Text
$headerPanel.Controls.Add($title)

$subtitle = New-TextLabel "FiveM-first performance tuning with clean presets, backups, and game profiles." 140 72 (New-Object System.Drawing.Font("Segoe UI", 10)) $Muted
$headerPanel.Controls.Add($subtitle)

$badge = New-TextLabel "FIVEM PERFORMANCE SUITE" 674 24 (New-Object System.Drawing.Font("Segoe UI Semibold", 8)) $Deep
$badge.BackColor = $Gold
$badge.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
$headerPanel.Controls.Add($badge)

$versionBadge = New-TextLabel "v2 premium" 770 72 (New-Object System.Drawing.Font("Segoe UI Semibold", 9)) $Cyan
$headerPanel.Controls.Add($versionBadge)

$plansTitle = New-TextLabel "Choose Plan" 24 164 (New-Object System.Drawing.Font("Segoe UI Semibold", 13)) $Text
$shellPanel.Controls.Add($plansTitle)

$minimalCard = New-Panel 24 198 260 88 $Surface2
$standardCard = New-Panel 24 298 260 88 $Surface2
$advancedCard = New-Panel 24 398 260 88 $Surface2
$shellPanel.Controls.Add($minimalCard)
$shellPanel.Controls.Add($standardCard)
$shellPanel.Controls.Add($advancedCard)

$minimalRadio = New-Object System.Windows.Forms.RadioButton
$minimalRadio.Text = "Minimal"
$minimalRadio.Location = New-Object System.Drawing.Point(18, 16)
$minimalRadio.AutoSize = $true
$minimalRadio.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$minimalRadio.ForeColor = $Text
$minimalRadio.Checked = $true
$minimalCard.Controls.Add($minimalRadio)
$minimalCard.Controls.Add((New-TextLabel "+20-25 FPS target" 38 48 (New-Object System.Drawing.Font("Segoe UI", 9)) $Muted))

$standardRadio = New-Object System.Windows.Forms.RadioButton
$standardRadio.Text = "Standard"
$standardRadio.Location = New-Object System.Drawing.Point(18, 16)
$standardRadio.AutoSize = $true
$standardRadio.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$standardRadio.ForeColor = $Text
$standardCard.Controls.Add($standardRadio)
$standardCard.Controls.Add((New-TextLabel "+35-40 FPS target" 38 48 (New-Object System.Drawing.Font("Segoe UI", 9)) $Muted))

$advancedRadio = New-Object System.Windows.Forms.RadioButton
$advancedRadio.Text = "Advanced"
$advancedRadio.Location = New-Object System.Drawing.Point(18, 16)
$advancedRadio.AutoSize = $true
$advancedRadio.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$advancedRadio.ForeColor = $Text
$advancedCard.Controls.Add($advancedRadio)
$advancedCard.Controls.Add((New-TextLabel "+45-50 FPS target" 38 48 (New-Object System.Drawing.Font("Segoe UI", 9)) $Muted))

$mainPanel = New-Panel 308 164 600 322 $Surface2
$shellPanel.Controls.Add($mainPanel)

$detailsLabel = New-TextLabel "Plan Details" 20 18 (New-Object System.Drawing.Font("Segoe UI Semibold", 13)) $Text
$mainPanel.Controls.Add($detailsLabel)

$detailsBox = New-Object System.Windows.Forms.ListBox
$detailsBox.Location = New-Object System.Drawing.Point(22, 54)
$detailsBox.Size = New-Object System.Drawing.Size(556, 178)
$detailsBox.BackColor = $Surface3
$detailsBox.ForeColor = $Text
$detailsBox.BorderStyle = "FixedSingle"
$detailsBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$mainPanel.Controls.Add($detailsBox)

$optionsTitle = New-TextLabel "Options" 20 250 (New-Object System.Drawing.Font("Segoe UI Semibold", 11)) $Mint
$mainPanel.Controls.Add($optionsTitle)

$ultimateCheck = New-Object System.Windows.Forms.CheckBox
$ultimateCheck.Text = "Ultimate Performance"
$ultimateCheck.Checked = $true
$ultimateCheck.AutoSize = $true
$ultimateCheck.ForeColor = $Text
$ultimateCheck.Location = New-Object System.Drawing.Point(22, 282)
$mainPanel.Controls.Add($ultimateCheck)

$hagsCheck = New-Object System.Windows.Forms.CheckBox
$hagsCheck.Text = "HAGS"
$hagsCheck.Checked = $false
$hagsCheck.AutoSize = $true
$hagsCheck.ForeColor = $Text
$hagsCheck.Location = New-Object System.Drawing.Point(206, 282)
$mainPanel.Controls.Add($hagsCheck)

$fiveMCheck = New-Object System.Windows.Forms.CheckBox
$fiveMCheck.Text = "FiveM mode"
$fiveMCheck.Checked = $true
$fiveMCheck.AutoSize = $true
$fiveMCheck.ForeColor = $Text
$fiveMCheck.Location = New-Object System.Drawing.Point(302, 282)
$mainPanel.Controls.Add($fiveMCheck)

$fortniteCheck = New-Object System.Windows.Forms.CheckBox
$fortniteCheck.Text = "Fortnite mode"
$fortniteCheck.Checked = $false
$fortniteCheck.AutoSize = $true
$fortniteCheck.ForeColor = $Text
$fortniteCheck.Location = New-Object System.Drawing.Point(420, 282)
$mainPanel.Controls.Add($fortniteCheck)

$safetyPanel = New-Panel 24 506 260 72 $Surface2
$shellPanel.Controls.Add($safetyPanel)
$safetyPanel.Controls.Add((New-TextLabel "Safety" 18 12 (New-Object System.Drawing.Font("Segoe UI Semibold", 11)) $Mint))

$restoreCheck = New-Object System.Windows.Forms.CheckBox
$restoreCheck.Text = "Restore point"
$restoreCheck.Checked = $true
$restoreCheck.AutoSize = $true
$restoreCheck.ForeColor = $Text
$restoreCheck.Location = New-Object System.Drawing.Point(18, 42)
$safetyPanel.Controls.Add($restoreCheck)

$backupCheck = New-Object System.Windows.Forms.CheckBox
$backupCheck.Text = "Registry backup"
$backupCheck.Checked = $true
$backupCheck.AutoSize = $true
$backupCheck.ForeColor = $Text
$backupCheck.Location = New-Object System.Drawing.Point(138, 42)
$safetyPanel.Controls.Add($backupCheck)

$actionPanel = New-Panel 308 506 600 72 $Surface2
$shellPanel.Controls.Add($actionPanel)

$adminButton = New-Object System.Windows.Forms.Button
$adminButton.Text = "Restart as Admin"
$adminButton.Location = New-Object System.Drawing.Point(18, 17)
$adminButton.Size = New-Object System.Drawing.Size(150, 38)
$adminButton.BackColor = $Surface3
$adminButton.ForeColor = $Text
$adminButton.FlatStyle = "Flat"
$adminButton.FlatAppearance.BorderColor = $Border
$actionPanel.Controls.Add($adminButton)

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = "Apply Selected Plan"
$applyButton.Location = New-Object System.Drawing.Point(182, 17)
$applyButton.Size = New-Object System.Drawing.Size(190, 38)
$applyButton.BackColor = $MintDark
$applyButton.ForeColor = $Text
$applyButton.FlatStyle = "Flat"
$applyButton.FlatAppearance.BorderColor = $Mint
$actionPanel.Controls.Add($applyButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.AutoSize = $false
$statusLabel.Location = New-Object System.Drawing.Point(392, 16)
$statusLabel.Size = New-Object System.Drawing.Size(190, 40)
$statusLabel.ForeColor = $Muted
$statusLabel.BackColor = [System.Drawing.Color]::Transparent
$statusLabel.TextAlign = "MiddleLeft"
$actionPanel.Controls.Add($statusLabel)

$logLabel = New-TextLabel "Activity Log" 626 490 (New-Object System.Drawing.Font("Segoe UI Semibold", 10)) $Mint
$shellPanel.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(626, 516)
$logBox.Size = New-Object System.Drawing.Size(282, 62)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = $Surface3
$logBox.ForeColor = $Text
$logBox.BorderStyle = "FixedSingle"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$shellPanel.Controls.Add($logBox)

function Get-SelectedPlan {
    if ($advancedRadio.Checked) { return "Advanced" }
    if ($standardRadio.Checked) { return "Standard" }
    return "Minimal"
}

function Set-PlanCardStyle {
    param(
        [System.Windows.Forms.Panel]$Card,
        [bool]$Selected
    )

    if ($Selected) {
        $Card.BackColor = $Surface3
    } else {
        $Card.BackColor = $Surface2
    }
}

function Update-Details {
    $detailsBox.Items.Clear()
    $plan = Get-SelectedPlan
    foreach ($item in $planDetails[$plan]) {
        [void]$detailsBox.Items.Add($item)
    }

    Set-PlanCardStyle $minimalCard ($plan -eq "Minimal")
    Set-PlanCardStyle $standardCard ($plan -eq "Standard")
    Set-PlanCardStyle $advancedCard ($plan -eq "Advanced")

    $isAdvanced = ($plan -eq "Advanced")
    $ultimateCheck.Enabled = $isAdvanced
    $hagsCheck.Enabled = $isAdvanced
    $fiveMCheck.Enabled = $true
    $fortniteCheck.Enabled = $true
}

function Update-AdminState {
    if (Test-IsAdmin) {
        $statusLabel.Text = "Admin mode active."
        $adminButton.Enabled = $false
    } else {
        $statusLabel.Text = "Admin recommended."
        $adminButton.Enabled = $true
    }
}

$minimalRadio.Add_CheckedChanged({ Update-Details })
$standardRadio.Add_CheckedChanged({ Update-Details })
$advancedRadio.Add_CheckedChanged({ Update-Details })
$minimalCard.Add_Click({ $minimalRadio.Checked = $true })
$standardCard.Add_Click({ $standardRadio.Checked = $true })
$advancedCard.Add_Click({ $advancedRadio.Checked = $true })
$adminButton.Add_Click({ Restart-AsAdmin })

$applyButton.Add_Click({
    $plan = Get-SelectedPlan
    $message = "Apply the $plan plan now?"
    if ($plan -eq "Advanced") {
        $message = "Apply the Advanced plan now? This changes power behavior, disables hibernation/Fast Startup, and may require a restart."
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        $message,
        "Confirm Tropical Tweaks",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    $applyButton.Enabled = $false
    $logBox.Clear()
    $logBox.AppendText("Applying $plan plan...`r`n")

    if ($backupCheck.Checked) {
        $logBox.AppendText((Save-RegistryBackup) + "`r`n")
    }

    if ($restoreCheck.Checked) {
        $logBox.AppendText((New-RestorePoint) + "`r`n")
    }

    if ($plan -eq "Advanced") {
        $result = Invoke-AdvancedTweaks -EnableHags $hagsCheck.Checked -UseUltimatePower $ultimateCheck.Checked -FiveMMode $fiveMCheck.Checked -FortniteMode $fortniteCheck.Checked
    } elseif ($plan -eq "Standard") {
        $result = Invoke-StandardTweaks -FiveMMode $fiveMCheck.Checked -FortniteMode $fortniteCheck.Checked
    } else {
        $result = Invoke-MinimalTweaks -FiveMMode $fiveMCheck.Checked -FortniteMode $fortniteCheck.Checked
    }

    foreach ($line in $result) {
        $logBox.AppendText($line + "`r`n")
    }

    $logBox.AppendText("Done. Restart recommended, especially after Standard or Advanced.`r`n")
    $applyButton.Enabled = $true
})

Update-Details
Update-AdminState

[void]$form.ShowDialog()
