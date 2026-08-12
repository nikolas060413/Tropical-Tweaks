# Tropical Tweaks

Tropical Tweaks is a small Windows app that lets you choose a tweak plan before applying anything. It is tuned for FiveM and Fortnite-focused Windows gaming settings, not fake "FPS miracle" registry tweaks.

## Main app

Double-click:

```text
Run_Tropical_Tweaks.cmd
```

Or use the EXE launcher:

```text
TropicalTweaks.exe
```

The EXE opens PowerShell as administrator and runs the GitHub launcher command.

Then choose:

- `Minimal`: FiveM/Fortnite starter performance setup.
- `Standard`: recommended FiveM/Fortnite setup for most PCs.
- `Advanced`: stronger FiveM/Fortnite performance setup; read the plan details before applying.

## How to run

If Windows blocks scripts, open PowerShell in this folder and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\TropicalTweaks.ps1
```

For best results, use the app's `Restart as admin` button before applying tweaks.

## Recommendation

Start with Standard for a gaming PC. It enables High performance power mode, Game Mode, disables Xbox background capture, disables Windows power throttling, and applies FiveM/Fortnite high-performance GPU preferences when the games are found.

Use Advanced only if you want stronger desktop gaming tuning and are comfortable with changes like Ultimate Performance mode, disabling hibernation/Fast Startup, and optional Hardware-accelerated GPU scheduling.

FPS targets:

- Minimal: targets `+20-25 FPS` if background capture/GPU preference was hurting the game.
- Standard: targets `+35-40 FPS` when capture, Game DVR, power limits, or bad GPU preference were hurting the game.
- Advanced: targets `+45-50 FPS` on PCs heavily limited by Windows overhead, cache, power behavior, or bad GPU preference.

These are potential gains, not guaranteed gains. Real FPS depends on the game, GPU, CPU, RAM, drivers, thermals, and in-game settings.

The separate `01_minimal_tweaks.ps1`, `02_standard_tweaks.ps1`, and `03_advanced_tweaks.ps1` files are still included for people who prefer running a plan directly.
