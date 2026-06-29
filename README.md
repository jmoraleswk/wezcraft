# wezcraft-base

Modular WezTerm terminal configuration with cross-platform installer.

## Features

- **Multi-theme support** — Toggle between default and kanagawa themes
- **Status bar** — Real-time CPU/RAM stats with Nerd Font icons
- **Session persistence** — Auto-save/restore with resurrect.wezterm
- **Transparency toggle** — Blur and transparency effects
- **Cross-platform installer** — macOS, Linux, Windows support

## Quick Start

### Using the Installer (Recommended)

```bash
# Clone the repo
git clone https://github.com/jmoraleswk/wezcraft.git
cd wezcraft

# Run installer (auto-detects OS)
./installer/install.sh
```

The installer will:
- Install FiraCode Nerd Font (auto-download if needed)
- Install Starship prompt (optional)
- Install Atuin shell history (optional)
- Configure shell integration automatically
- Start stats daemon (CPU/RAM) in background

### Manual Setup

```bash
mkdir -p ~/.config/wezterm
cp wezterm.lua ~/.config/wezterm/
cp -r themes constants utils commands assets elements ~/.config/wezterm/
```

## Requirements

- [WezTerm](https://wezfurlong.org/wezterm/) installed
- **FiraCode Nerd Font** (ligatures + icons)
- **Emoji font** (auto-detected per OS):
  - macOS: Apple Color Emoji (built-in)
  - Windows: Segoe UI Emoji (built-in)

## Structure

- `wezterm.lua` — Main config, loads theme and registers events
- `themes/` — Color themes (default, kanagawa)
- `constants/` — Theme constants (background images, fonts, global config)
- `utils/` — Utilities (theme loader, status messages)
- `commands/` — Custom commands for command palette
- `assets/` — Background images and resources
- `elements/resurrect/` — Session persistence config ([docs](elements/resurrect/README.md))
- `elements/statusbar/` — Status bar config and stats daemon scripts
- `installer/` — Cross-platform installer ([docs](installer/README.md))

## Themes

- **Default** — FiraCode Nerd Font, background image, blur, transparency toggle
- **Kanagawa** — Dark palette inspired by [kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim)

## Status Bar

Real-time system stats in the status bar:

```
󰍛 CPU: 25% | 󰘚 RAM: 8.5GB/16GB
```

The stats daemon runs automatically on all platforms:
- **macOS**: launchd agent
- **Linux**: systemd user service
- **Windows**: Task Scheduler

## Usage

- **CMD+Shift+P** — Command palette
  - **Toggle terminal transparency** — Only works with default theme (shows error otherwise)
  - **Toggle theme** — Switch between default and kanagawa
- **CMD+Shift+L** — Debug logs
- `resurrect` — Session persistence quick reference ([full docs](elements/resurrect/README.md))

### Resurrect Keybindings

| Key | Action |
|-----|--------|
| `ALT+SUP+N` | New workspace |
| `SUP+W` | Save snapshot |
| `ALT+R` | Restore session |
| `ALT+D` | Rename workspace |
| `SUP+D` | Delete snapshot |

## Installer Options

See [installer/README.md](installer/README.md) for detailed documentation including:
- Platform-specific instructions
- Uninstall procedures
- Troubleshooting guide

### Command Palette Notes

Commands appear in the palette regardless of the active theme. The transparency toggle checks the theme at runtime and shows an error if not in default theme. Future improvement: conditionally register commands based on theme capabilities.
