# wezcraft-base

Modular WezTerm terminal configuration.

## Requirements

- [WezTerm](https://wezfurlong.org/wezterm/) installed
- **FiraMono Nerd Font** installed:
  ```bash
  brew install --cask font-firamono-nerd-font
  ```

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

## Usage

- **CMD+Shift+P** — Command palette (toggle transparency)
- **CTRL+CMD+S** — Test status message
- **CMD+Shift+L** — Debug logs
