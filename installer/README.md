# WezCraft Installer

Set up your WezTerm configuration on a new machine.

## Requirements

### macOS
- [Homebrew](https://brew.sh)
- git (Xcode Command Line Tools)

### Linux
- git
- curl or wget
- rsync

### Windows
- [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [PowerShell 5.1+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- git

## Install

### macOS / Linux
```bash
./installer/install.sh
```

### Windows (PowerShell)
```powershell
.\installer\scripts\windows.ps1
```

### Options (macOS/Linux only)
- `--source <path>` — Use local repo instead of cloning from GitHub
- `--repo <url>` — Custom repo URL (default: `https://github.com/jmoraleswk/wezcraft`)

## Uninstall

### macOS / Linux
```bash
./installer/uninstall.sh
```

### Windows (PowerShell)
```powershell
.\installer\scripts\windows-uninstall.ps1
```

## What it does

### macOS Install
1. Clones repo from GitHub (or uses local source)
2. Backs up existing `~/.config/wezterm/` (timestamped)
3. Copies config files (excluding non-essential dirs)
4. Creates required directories (`~/.local/share/wezterm/resurrect/`)
5. Installs FiraCode Nerd Font via Homebrew
6. Sets up launchd agent for live CPU/RAM stats
7. Installs Starship prompt (if not already installed) + shell integration
8. Creates Starship config with nerd-font-symbols preset (`~/.config/starship/starship.toml`)
9. Installs Atuin shell history (if not already installed) + shell integration
10. Adds `resurrect()` helper function to shell config

### Linux Install
1. Clones repo from GitHub (or uses local source)
2. Backs up existing `~/.config/wezterm/` (timestamped)
3. Copies config files (excluding non-essential dirs)
4. Creates required directories (`~/.local/share/wezterm/resurrect/`)
5. Installs FiraCode Nerd Font (manual download)
6. Installs Starship prompt (if not already installed) + shell integration
7. Creates Starship config with nerd-font-symbols preset (`~/.config/starship/starship.toml`)
8. Installs Atuin shell history (via official script) + shell integration
9. Adds `resurrect()` helper function to shell config

### Windows Install
1. Clones repo from GitHub (or uses local source)
2. Backs up existing `~/.config/wezterm/` (timestamped)
3. Copies config files (excluding non-essential dirs)
4. Creates required directories (`~\AppData\Local\wezterm\resurrect\`)
5. Installs FiraCode Nerd Font (automated download + extract)
6. Installs Starship prompt via WinGet (if not already installed) + shell integration
7. Creates default Starship config
8. Installs Atuin via WinGet (if not already installed) + shell integration

### Uninstall (All Platforms)
- Optionally removes: config, session saves, font, starship, starship config, atuin, backups
- Automatically removes shell integration (starship init, atuin init, resurrect() helper)

## Notes

- Installer pulls latest config from GitHub — no bundling needed
- The resurrect.wezterm plugin is included in the repo
- Stats daemon (CPU/RAM) runs on all platforms:
  - macOS: launchd agent
  - Linux: systemd user service
  - Windows: Task Scheduler
- Starship prompt is installed automatically if not present
- Atuin shell history is installed automatically if not present
- Backup files are timestamped: `~/.config/wezterm.bak.<timestamp>`
