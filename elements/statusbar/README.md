# STATUS BAR

Status bar components for WezTerm with CPU/RAM stats.

## Features

- Workspace name (left side)
- Current directory (right side)
- Clock (right side)
- CPU/RAM stats (right side, requires setup)

## Files

| File | Description |
|------|-------------|
| `config.lua` | Main status bar configuration |
| `install.sh` | Installs the LaunchAgent to run stats in background |
| `update_stats.sh` | Script that collects CPU/RAM and writes to `/tmp/wezterm_stats.txt` |

## Quick Setup

### 1. Install the stats script

```bash
./install.sh
```

This will:
- Set executable permissions on `update_stats.sh`
- Create a LaunchAgent to run the script in background
- Start the service immediately

### 2. Restart WezTerm

The status bar will appear with workspace, directory, and stats.

## Manual Setup (without install.sh)

```bash
chmod +x update_stats.sh
./update_stats.sh &
```

## Configuration

Edit `config.lua` to enable/disable sections:

```lua
local SHOW_WORKSPACE = true     -- workspace name (left)
local SHOW_BATTERY   = false    -- battery level (right)
local SHOW_CLOCK     = true     -- HH:MM (right)
local SHOW_GIT       = false    -- git branch (right)
local SHOW_CWD       = true     -- current directory (right)
```

## Stats (CPU/RAM)

The `update_stats.sh` script runs every 5 seconds:
- **CPU**: uses `top` to get instant usage (0-100%)
- **RAM**: uses `vm_stat` and `sysctl` to calculate used memory like macOS Activity Monitor

Output is written to a temp file and displayed in the status bar with Nerd Font styling.

### Output Format

```
󰍛 CPU: 12% | 󰘚 RAM: 8.24GB/16GB
```

### Stats File Path

The stats file path is defined in `constants/global.lua`:

```lua
M.STATUS_BAR = {
  stats_file = "/tmp/wezterm_stats.txt",
}
```

**Important**: If you change this path, you must update it in BOTH places:
1. `constants/global.lua` (Lua config reads from here)
2. `update_stats.sh` (shell script writes to here)

The script has a comment reminding you of this dependency.

## Requirements

- WezTerm
- Font with Nerd Font support (for stats icons)
- macOS (scripts use macOS-specific commands)