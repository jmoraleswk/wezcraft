# WezTerm Resurrect Configuration

Based on [resurrect.wezterm](https://github.com/MLFlexer/resurrect.wezterm) by MLFlexer.

For full documentation, visit the [upstream repo](https://github.com/MLFlexer/resurrect.wezterm).

## Setup

### 1. Install the plugin

Clone the plugin into your WezTerm config:

```bash
git clone https://github.com/MLFlexer/resurrect.wezterm.git ~/.config/wezterm/plugins/resurrect
```

### 2. Shell helper (optional)

Add this function to your `.zshrc` for quick access to docs:

```bash
resurrect() {
    local base=~/.config/wezterm/elements/resurrect/docs/helpers
    local doc

    case "$1" in
        --keys|-k)        doc="$base/keybindings.md" ;;
        --workflow|-w)    doc="$base/workflow.md" ;;
        --help|-h)
            echo "resurrect - WezTerm session persistence helper"
            echo ""
            echo "Usage: resurrect [OPTION]"
            echo ""
            echo "Options:"
            echo "  -w, --workflow     Show workflow guide (default)"
            echo "  -k, --keys         Show keybindings"
            echo "  -h, --help         Show this help message"
            return 0
            ;;
        "")
            doc="$base/workflow.md"
            ;;
        *)
            echo "resurrect: unrecognized option '$1'" >&2
            echo "Try 'resurrect --help' for more information." >&2
            return 1
            ;;
    esac

    [ -n "$doc" ] && cat "$doc"
}
```

Then run `source ~/.zshrc` or open a new terminal.

Usage:

```bash
resurrect          # Quick reference
resurrect --keys   # Keybindings
resurrect --help   # Help
```

## Keybindings

| Key | Action |
|-----|--------|
| `ALT+SUP+N` | New workspace |
| `SUP+W` | Save snapshot |
| `ALT+R` | Restore session |
| `ALT+D` | Rename workspace |
| `SUP+D` | Delete snapshot |

## Customizations

### State Directory

```lua
resurrect.state_manager.change_state_save_dir(wezterm.home_dir .. "/.local/share/wezterm/resurrect/")
```

### Custom Pane Restore

Replaced `default_on_pane_restore` with a custom implementation that only restores fullscreen applications (nvim, vim, lazygit, htop).

**Reason**: The original callback reinjects terminal visual content via `pane:inject_output(...)`, causing duplicate prompts, empty lines, and incorrect Starship rendering.

### Restore Options

```lua
spawn_in_workspace = true,  -- CRITICAL: restores in original workspace, not "default"
restore_text = false,       -- avoids UTF-8 artifacts and performance issues
resize_window = false,      -- prevents aggressive resizing
on_pane_restore = custom_pane_restore,
```

## Encryption (Optional)

Resurrect supports encrypting saved state using [age](https://github.com/FiloSottile/age).

1. Install: `brew install age`
2. Generate key:
   ```bash
   age-keygen -o ~/.config/wezterm/elements/resurrect/wezterm.key
   ```
   This prints the **public key** to stdout. Copy it.
3. Open `config.lua` and:
   - Set `enable = true`
   - Replace `"age1... YOUR_PUBLIC_KEY_HERE"` with your actual public key
4. Restart WezTerm

```lua
resurrect.state_manager.set_encryption({
    enable      = true,
    method      = "/opt/homebrew/bin/age", -- macOS Apple Silicon; see platform paths below
    private_key = wezterm.home_dir .. "/.config/wezterm/elements/resurrect/wezterm.key",
    public_key  = "age1...",  -- paste your public key here
})
```

### Platform Paths

| OS | Path |
|----|------|
| macOS (Apple Silicon) | `/opt/homebrew/bin/age` |
| macOS (Intel) | `/usr/local/bin/age` |
| Linux | `age` (must be in PATH) |
