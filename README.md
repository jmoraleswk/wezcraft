# WezCraft

Modular WezTerm terminal configuration with cross-platform installer.

## Features

- **Multi-theme support** — Toggle between default and kanagawa themes
- **Status bar** — Real-time CPU/RAM stats with Nerd Font icons
- **Session persistence** — Auto-save/restore with resurrect.wezterm
- **Transparency toggle** — Blur and transparency effects
- **Cross-platform installer** — macOS, Linux, Windows support

## Quick Start

### Option 1: One-liner (Recommended)

```bash
# macOS/Linux - install directly from GitHub
curl -fsSL https://raw.githubusercontent.com/jmoraleswk/wezcraft/main/installer/install.sh | bash -s -- --tui
```

This will:
1. Clone the repo to a temp directory
2. Install `fzf` if needed (it asks for consent first)
3. Launch interactive TUI installer
4. Clean up temp files when done

### Option 2: Clone and Run

```bash
git clone https://github.com/jmoraleswk/wezcraft.git
cd wezcraft
./installer/install.sh --tui
```

### Option 3: Manual Setup

```bash
mkdir -p ~/.config/wezterm
cp wezterm.lua ~/.config/wezterm/
cp -r themes constants utils commands assets elements ~/.config/wezterm/
```

### What the Installer Does

- Installs FiraCode Nerd Font (auto-download if needed)
- Installs Starship prompt (optional) with nerd-font-symbols preset
- Installs Atuin shell history (optional)
- Configures shell integration automatically (starship init, atuin init)
- Adds `resurrect()` helper function to shell config
- Starts stats daemon (CPU/RAM) in background

## Requirements

- [WezTerm](https://wezfurlong.org/wezterm/) installed
- **FiraCode Nerd Font** (ligatures + icons)
- **Emoji font** (auto-detected per OS):
  - macOS: Apple Color Emoji (built-in)
  - Windows: Segoe UI Emoji (built-in)
- **macOS**: a package manager — MacPorts on Intel, Homebrew on Apple Silicon (see below)
- **Linux**: `git`, `curl` or `wget`, and `rsync`
- **Windows**: WinGet and PowerShell 5.1+

### macOS package manager

The installer picks the package manager from the CPU architecture (`uname -m`)
and never falls back between them:

| CPU | Manager | Why |
| --- | --- | --- |
| Intel `x86_64` | **MacPorts** | Homebrew moved macOS Intel to [Tier 3](https://docs.brew.sh/Support-Tiers) in September 2026: no new bottles are built, so every install compiles from source (11+ minutes, and it may fail). Homebrew drops macOS Intel entirely in September 2027. **brew is never used for packages on Intel.** |
| Apple Silicon `arm64` | **Homebrew** | MacPorts is not accepted as a fallback there. |

**The flows, in order:**

1. **Manager present** — it is used directly, and no prompt appears.
2. **Manager missing** — the installer offers to install it, with an **explicit
   consent prompt on the terminal** (never a silent `sudo`, and never read from
   piped stdin). Intel gets the pinned MacPorts `.pkg` for its macOS version;
   Apple Silicon gets the official Homebrew installer. A decline, or a run with
   no terminal available, ends in an actionable message and exit 1 — it never
   hangs waiting for a password.
3. **Fonts are the one exception to the CPU rule.** The FiraCode Nerd Font is
   installed with the Homebrew **cask** on *any* architecture — a cask is a zip
   of font files, so it compiles nothing. Without Homebrew it falls back to a
   **pinned, SHA-256-verified** download from the official nerd-fonts release,
   and to the MacPorts symbols-only font (icons work, ligatures are lost) when
   that download fails.

The full rationale and fallback chain are in
[installer/README.md](installer/README.md#requirements).

## Structure

- `wezterm.lua` — Main config, loads theme and registers events
- `themes/` — Color themes (default, kanagawa)
- `constants/` — Theme constants (background images, fonts, global config)
- `utils/` — Utilities (theme loader, status messages)
- `commands/` — Custom commands for command palette
- `assets/` — Background images and resources
- `elements/resurrect/` — Session persistence config ([docs](elements/resurrect/README.md))
- `elements/statusbar/` — Status bar config and stats daemon scripts
- `elements/theme-switcher/` — Dynamic theme switcher with fuzzy picker
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

- **ALT + T** — Switch theme (fuzzy picker)
- **ALT + 1** — Pipe character (`|`)
- **ALT + 2** — At sign (`@`)
- **ALT + 3** — Hash (`#`)
- **ALT + ñ** — Tilde (`~`)
- **ALT + º** — Backslash (`\`)
- **ALT + º** — Backslash (`\`)
- **ALT + +** — Closing bracket (`]`)
- **ALT + ç** — Closing brace (`}`)
- **CMD+Shift+P** — Command palette
  - **Toggle terminal transparency** — Only works with default theme (shows error otherwise)
  - **Switch theme** — Fuzzy picker to select any available theme
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

Commands appear in the palette regardless of the active theme. The transparency toggle checks the theme at runtime and shows an error if not in default theme.
