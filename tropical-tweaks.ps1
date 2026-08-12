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

function Invoke-MinimalTweaks {
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

    return $log
}

function Invoke-StandardTweaks {
    param(
        [bool]$FiveMMode,
        [bool]$FortniteMode
    )

    $log = Invoke-MinimalTweaks

    $log.Add((Set-HighPerformancePower))

    $log.Add("Enabling Windows Game Mode.")
    Set-RegValue "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    Set-RegValue "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1

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

    return $log
}

$planDetails = @{
    Minimal = @(
        "Best for: light FiveM/Fortnite cleanup, very low risk",
        "FPS target: up to +10 FPS if Windows background overhead was hurting your game",
        "Guarantee: no fixed FPS gain; results depend on game, GPU, CPU, RAM, and thermals",
        "Reduce Windows tips, suggestions, and notification clutter",
        "Disable transparency effects",
        "Clear temporary files"
    )
    Standard = @(
        "Best for: FiveM/Fortnite setup most players should use",
        "FPS target: up to +15 FPS when capture, Game DVR, or power limits were hurting performance",
        "Guarantee: no fixed FPS gain; this plan is mainly for smoother FPS and better 1% lows",
        "Everything in Minimal",
        "Enable High performance power plan",
        "Enable Game Mode",
        "Disable Xbox Game DVR/background capture",
        "Disable Windows power throttling",
        "Game modes: high-performance GPU preference and fullscreen optimization tweak"
    )
    Advanced = @(
        "Best for: FiveM/Fortnite desktop setup where FPS consistency matters most",
        "FPS target: up to +20-25 FPS on PCs limited by Windows overhead or power behavior",
        "Guarantee: no fixed FPS gain; strongest chance is better stutter and 1% lows",
        "Everything in Standard",
        "Optional Ultimate Performance power plan",
        "Optional Hardware-accelerated GPU scheduling",
        "Disable hibernation and Fast Startup",
        "Apply gaming multimedia scheduler priorities"
    )
}

$Deep = [System.Drawing.Color]::FromArgb(8, 20, 19)
$Panel = [System.Drawing.Color]::FromArgb(15, 35, 32)
$Panel2 = [System.Drawing.Color]::FromArgb(20, 49, 44)
$Mint = [System.Drawing.Color]::FromArgb(34, 197, 170)
$MintDark = [System.Drawing.Color]::FromArgb(16, 132, 121)
$Gold = [System.Drawing.Color]::FromArgb(245, 190, 88)
$Text = [System.Drawing.Color]::FromArgb(236, 252, 248)
$Muted = [System.Drawing.Color]::FromArgb(156, 185, 178)
$Border = [System.Drawing.Color]::FromArgb(44, 83, 76)

$form = New-Object System.Windows.Forms.Form
$form.Text = "Tropical Tweaks"
$form.Size = New-Object System.Drawing.Size(900, 620)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(820, 580)
$form.BackColor = $Deep
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(18, 16)
$headerPanel.Size = New-Object System.Drawing.Size(846, 118)
$headerPanel.BackColor = $Panel
$form.Controls.Add($headerPanel)

if (Test-Path $LogoPath) {
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Location = New-Object System.Drawing.Point(20, 16)
    $logo.Size = New-Object System.Drawing.Size(86, 86)
    $logo.SizeMode = "Zoom"
    $logo.Image = [System.Drawing.Image]::FromFile($LogoPath)
    $headerPanel.Controls.Add($logo)
}

$title = New-Object System.Windows.Forms.Label
$title.Text = "Tropical Tweaks"
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 25)
$title.ForeColor = $Text
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(122, 20)
$headerPanel.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Choose a plan for FPS potential, less background overhead, better 1% lows, and smoother response."
$subtitle.ForeColor = $Muted
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(126, 67)
$headerPanel.Controls.Add($subtitle)

$badge = New-Object System.Windows.Forms.Label
$badge.Text = "FiveM focused"
$badge.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$badge.ForeColor = $Deep
$badge.BackColor = $Gold
$badge.AutoSize = $true
$badge.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
$badge.Location = New-Object System.Drawing.Point(700, 22)
$headerPanel.Controls.Add($badge)

$planGroup = New-Object System.Windows.Forms.GroupBox
$planGroup.Text = "Plan"
$planGroup.Location = New-Object System.Drawing.Point(28, 154)
$planGroup.Size = New-Object System.Drawing.Size(260, 176)
$planGroup.ForeColor = $Mint
$planGroup.BackColor = $Deep
$form.Controls.Add($planGroup)

$minimalRadio = New-Object System.Windows.Forms.RadioButton
$minimalRadio.Text = "Minimal"
$minimalRadio.Location = New-Object System.Drawing.Point(18, 34)
$minimalRadio.AutoSize = $true
$minimalRadio.ForeColor = $Text
$minimalRadio.Checked = $true
$planGroup.Controls.Add($minimalRadio)

$standardRadio = New-Object System.Windows.Forms.RadioButton
$standardRadio.Text = "Standard"
$standardRadio.Location = New-Object System.Drawing.Point(18, 76)
$standardRadio.AutoSize = $true
$standardRadio.ForeColor = $Text
$planGroup.Controls.Add($standardRadio)

$advancedRadio = New-Object System.Windows.Forms.RadioButton
$advancedRadio.Text = "Advanced"
$advancedRadio.Location = New-Object System.Drawing.Point(18, 118)
$advancedRadio.AutoSize = $true
$advancedRadio.ForeColor = $Text
$planGroup.Controls.Add($advancedRadio)

$safetyGroup = New-Object System.Windows.Forms.GroupBox
$safetyGroup.Text = "Safety"
$safetyGroup.Location = New-Object System.Drawing.Point(28, 346)
$safetyGroup.Size = New-Object System.Drawing.Size(260, 100)
$safetyGroup.ForeColor = $Mint
$safetyGroup.BackColor = $Deep
$form.Controls.Add($safetyGroup)

$restoreCheck = New-Object System.Windows.Forms.CheckBox
$restoreCheck.Text = "Create restore point"
$restoreCheck.Checked = $true
$restoreCheck.AutoSize = $true
$restoreCheck.ForeColor = $Text
$restoreCheck.Location = New-Object System.Drawing.Point(16, 30)
$safetyGroup.Controls.Add($restoreCheck)

$backupCheck = New-Object System.Windows.Forms.CheckBox
$backupCheck.Text = "Export registry backup"
$backupCheck.Checked = $true
$backupCheck.AutoSize = $true
$backupCheck.ForeColor = $Text
$backupCheck.Location = New-Object System.Drawing.Point(16, 60)
$safetyGroup.Controls.Add($backupCheck)

$advancedGroup = New-Object System.Windows.Forms.GroupBox
$advancedGroup.Text = "Options"
$advancedGroup.Location = New-Object System.Drawing.Point(314, 346)
$advancedGroup.Size = New-Object System.Drawing.Size(550, 98)
$advancedGroup.ForeColor = $Mint
$advancedGroup.BackColor = $Deep
$form.Controls.Add($advancedGroup)

$ultimateCheck = New-Object System.Windows.Forms.CheckBox
$ultimateCheck.Text = "Use Ultimate Performance power plan"
$ultimateCheck.Checked = $true
$ultimateCheck.AutoSize = $true
$ultimateCheck.ForeColor = $Text
$ultimateCheck.Location = New-Object System.Drawing.Point(16, 27)
$advancedGroup.Controls.Add($ultimateCheck)

$hagsCheck = New-Object System.Windows.Forms.CheckBox
$hagsCheck.Text = "Enable HAGS"
$hagsCheck.Checked = $false
$hagsCheck.AutoSize = $true
$hagsCheck.ForeColor = $Text
$hagsCheck.Location = New-Object System.Drawing.Point(282, 27)
$advancedGroup.Controls.Add($hagsCheck)

$fiveMCheck = New-Object System.Windows.Forms.CheckBox
$fiveMCheck.Text = "FiveM mode"
$fiveMCheck.Checked = $true
$fiveMCheck.AutoSize = $true
$fiveMCheck.ForeColor = $Text
$fiveMCheck.Location = New-Object System.Drawing.Point(16, 62)
$advancedGroup.Controls.Add($fiveMCheck)

$fortniteCheck = New-Object System.Windows.Forms.CheckBox
$fortniteCheck.Text = "Fortnite mode"
$fortniteCheck.Checked = $true
$fortniteCheck.AutoSize = $true
$fortniteCheck.ForeColor = $Text
$fortniteCheck.Location = New-Object System.Drawing.Point(140, 62)
$advancedGroup.Controls.Add($fortniteCheck)

$detailsLabel = New-Object System.Windows.Forms.Label
$detailsLabel.Text = "What this plan changes"
$detailsLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$detailsLabel.ForeColor = $Mint
$detailsLabel.AutoSize = $true
$detailsLabel.Location = New-Object System.Drawing.Point(310, 156)
$form.Controls.Add($detailsLabel)

$detailsBox = New-Object System.Windows.Forms.ListBox
$detailsBox.Location = New-Object System.Drawing.Point(314, 186)
$detailsBox.Size = New-Object System.Drawing.Size(550, 144)
$detailsBox.BackColor = $Panel2
$detailsBox.ForeColor = $Text
$detailsBox.BorderStyle = "FixedSingle"
$form.Controls.Add($detailsBox)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "Log"
$logLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$logLabel.ForeColor = $Mint
$logLabel.AutoSize = $true
$logLabel.Location = New-Object System.Drawing.Point(310, 458)
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(314, 488)
$logBox.Size = New-Object System.Drawing.Size(550, 62)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = $Panel2
$logBox.ForeColor = $Text
$logBox.BorderStyle = "FixedSingle"
$form.Controls.Add($logBox)

$adminButton = New-Object System.Windows.Forms.Button
$adminButton.Text = "Restart as admin"
$adminButton.Location = New-Object System.Drawing.Point(28, 472)
$adminButton.Size = New-Object System.Drawing.Size(142, 38)
$adminButton.BackColor = $Panel2
$adminButton.ForeColor = $Text
$adminButton.FlatStyle = "Flat"
$adminButton.FlatAppearance.BorderColor = $Border
$form.Controls.Add($adminButton)

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = "Apply selected plan"
$applyButton.Location = New-Object System.Drawing.Point(28, 516)
$applyButton.Size = New-Object System.Drawing.Size(190, 38)
$applyButton.BackColor = $MintDark
$applyButton.ForeColor = $Text
$applyButton.FlatStyle = "Flat"
$applyButton.FlatAppearance.BorderColor = $Mint
$form.Controls.Add($applyButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(236, 526)
$statusLabel.ForeColor = $Muted
$form.Controls.Add($statusLabel)

function Get-SelectedPlan {
    if ($advancedRadio.Checked) { return "Advanced" }
    if ($standardRadio.Checked) { return "Standard" }
    return "Minimal"
}

function Update-Details {
    $detailsBox.Items.Clear()
    $plan = Get-SelectedPlan
    foreach ($item in $planDetails[$plan]) {
        [void]$detailsBox.Items.Add($item)
    }

    $isAdvanced = ($plan -eq "Advanced")
    $ultimateCheck.Enabled = $isAdvanced
    $hagsCheck.Enabled = $isAdvanced
    $gameModeEnabled = ($plan -ne "Minimal")
    $fiveMCheck.Enabled = $gameModeEnabled
    $fortniteCheck.Enabled = $gameModeEnabled
}

function Update-AdminState {
    if (Test-IsAdmin) {
        $statusLabel.Text = "Running as administrator."
        $adminButton.Enabled = $false
    } else {
        $statusLabel.Text = "Not running as administrator. Standard/Advanced need admin permission."
        $adminButton.Enabled = $true
    }
}

$minimalRadio.Add_CheckedChanged({ Update-Details })
$standardRadio.Add_CheckedChanged({ Update-Details })
$advancedRadio.Add_CheckedChanged({ Update-Details })
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
        $result = Invoke-MinimalTweaks
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
