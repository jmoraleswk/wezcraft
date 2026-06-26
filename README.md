# WezCraft

Modular WezTerm terminal configuration.

## Requirements

- [WezTerm](https://wezfurlong.org/wezterm/) installed
- **FiraCode Nerd Font** installed (ligatures + icons):
  ```bash
  brew install --cask font-firacode-nerd-font
  ```
- **Emoji font** (auto-detected per OS):
  - macOS: Apple Color Emoji (built-in)
  - Windows: Segoe UI Emoji (built-in)

## Setup

```bash
mkdir -p ~/.config/wezterm
cp wezterm.lua ~/.config/wezterm/
cp -r themes constants utils commands assets ~/.config/wezterm/
```

## Structure

- `wezterm.lua` — Main config, loads theme and registers events
- `themes/` — Color themes (default, kanagawa)
- `constants/` — Theme constants (background images, etc.)
- `utils/` — Utilities (theme loader, status messages)
- `commands/` — Custom commands for command palette
- `assets/` — Background images and resources
- `elements/resurrect/` — Session persistence config ([docs](elements/resurrect/README.md))

## Themes

- **Default** — FiraMono Nerd Font, background image, blur, transparency toggle
- **Kanagawa** — Dark palette inspired by [kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim)

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

### Command Palette Notes

Commands appear in the palette regardless of the active theme. The transparency toggle checks the theme at runtime and shows an error if not in default theme. Future improvement: conditionally register commands based on theme capabilities.
