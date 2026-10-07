# WezCraft Installer

Set up your WezTerm configuration on a new machine.

## Requirements

### macOS
- [MacPorts](https://www.macports.org/) on Intel (`x86_64`), [Homebrew](https://brew.sh) on Apple Silicon (`arm64`) — the installer picks the manager from the CPU architecture, with no fallback between them
- git (Xcode Command Line Tools)

#### Why MacPorts on Intel

This is not belt-and-suspenders: Homebrew's own support policy is why the
MacPorts path exists (see [Homebrew Support Tiers](https://docs.brew.sh/Support-Tiers)):

- **September 2026** — Homebrew moved macOS Intel `x86_64` to **Tier 3**:
  Homebrew keeps running, but no new bottles (prebuilt binaries) are built,
  so installs and upgrades fall back to compiling from source, and the
  official `.pkg` installer is Apple Silicon only.
- **September 2027** — Homebrew drops macOS Intel support entirely.

Homebrew's own 7.0.0 announcement states it plainly: *"MacPorts still
supports macOS Intel x86_64 and is likely to provide better results on this
platform."* On Intel Macs, MacPorts ships complete binary packages today,
which makes it the reliable package manager there — so the installer treats
it as a supported path, not an afterthought.

On MacPorts-only systems (no Homebrew), the FiraCode Nerd Font step
downloads a pinned, SHA-256-verified nerd-fonts release into
`~/Library/Fonts` (see the fallback chain below), degrading to the
symbols-only font (no ligatures) when offline. MacPorts installs need
administrator rights, so `port install` runs through `sudo` (it prompts on
the terminal); any port you already had is left untouched.

### Linux
- git
- curl or wget
- rsync

### Windows
- [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [PowerShell 5.1+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- git

## Install

### One-liner (macOS/Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/jmoraleswk/wezcraft/main/installer/install.sh | bash -s -- --tui
```

When piped, the installer bootstraps itself: it clones the repo to a temp
directory, re-runs itself from the clone, launches the interactive TUI, and
removes the temp directory on exit.

### From a local checkout (macOS/Linux)

```bash
./installer/install.sh
# or, interactive component picker:
./installer/install.sh --tui
```

Running from a checkout installs the local checkout's config (it does not
re-clone from GitHub).

### Windows (PowerShell)
```powershell
.\installer\scripts\windows.ps1
```

### Options (macOS/Linux only)
- `--tui` — Interactive component picker. Requires `fzf`; if it is missing, the installer asks for consent before installing it (see Notes)
- `--source <path>` — Config source directory (default: the local repo root)
- `--repo <url>` — Custom repo URL used when bootstrapping via curl (default: `https://github.com/jmoraleswk/wezcraft`)

### Source resolution

1. Explicit `--source <path>`, if provided
2. The local checkout (repo root), when running from a clone of the repo
3. A fresh `--depth 1` clone of the repo into a temp directory — only when
   bootstrapped via `curl | bash` (the clone supplies both the installer
   scripts and the default config source; it is removed when the installer
   exits)

`installer/tui-install.sh` is internal: it is always invoked by
`installer/install.sh`, which passes `--source` explicitly. Running it
directly without `--source` exits with an error before any side effects.

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
1. Resolves config source (local checkout, `--source`, or a fresh GitHub clone when piped)
2. Backs up existing `~/.config/wezterm/` (timestamped)
3. Copies config files (excluding non-essential dirs)
4. Creates required directories (`~/.local/share/wezterm/resurrect/`)
5. Installs FiraCode Nerd Font (Homebrew cask; on MacPorts-only systems: pinned SHA-256-verified download from the official nerd-fonts release, symbols-only fallback when offline)
6. Sets up launchd agent for live CPU/RAM stats
7. Installs Starship prompt (if not already installed) + shell integration
8. Creates Starship config with nerd-font-symbols preset (`~/.config/starship/starship.toml`)
9. Installs Atuin shell history (if not already installed) + shell integration
10. Adds `resurrect()` helper function to shell config

### Linux Install
1. Resolves config source (local checkout, `--source`, or a fresh GitHub clone when piped)
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
- Optionally removes: config, session saves, font, starship, starship config, atuin, fzf (only if this installer installed it), backups
- Automatically removes shell integration (starship init, atuin init, resurrect() helper)

## Notes

- **macOS font fallback chain (MacPorts-only systems)** — Homebrew installs
  the font as a cask and needs no chain. Without Homebrew, `pkg_install font`
  escalates in order:
  1. Download the **pinned** `FiraCode.zip` (`v3.5.1`) and verify its
     **SHA-256** against the release's `SHA-256.txt`; refuse to install on
     mismatch. The mutable `latest` URL is intentionally not used: bytes
     that can change without notice cannot be verified.
  2. If that fails (offline, asset missing, checksum mismatch):
     `sudo port install ttf-nerd-fonts-symbols` +
     `sudo port install dejavu-fonts` — status-bar icons and base text keep
     working, ligatures are lost, and a yellow warning explains that. A port
     you already had is never reinstalled, and the uninstaller removes only
     the ports this installer actually installed.

  Why it matters: MacPorts ships **no ligature monospace font at all** (no
  FiraCode, JetBrains Mono, Hack, …), and its only Nerd Font port is the
  symbols-only one — hence the direct download as the primary path.
- **MacPorts needs administrator rights** — it installs into `/opt/local`,
  so `port install`/`port uninstall` run through `sudo`. When no terminal is
  available to prompt for a password (e.g. a fully non-interactive run), the
  installer fails with an actionable message instead of hanging.
- **`fzf` is a hard requirement of `--tui`** — it powers the component picker,
  so it is installed through the detected package manager (`sudo port install`
  on Intel, `brew install` on Apple Silicon) before the picker opens. That
  install asks for **explicit consent on the terminal** and warns that it needs
  administrator rights and may compile from source; declining, or running
  without a terminal, aborts with an actionable message and exit 1. The
  uninstaller offers to remove `fzf` **only when this installer installed it**
  (tracked in `~/.local/state/wezcraft/installed-pkgs`), so a pre-existing
  `fzf` is never touched. If you do not want `fzf` installed, use the
  non-TUI installer: `./installer/install.sh`.
- One-liner (`curl | bash`) installs pull the latest config from GitHub — no bundling needed; local checkouts install their own files
- The resurrect.wezterm plugin is included in the repo
- Stats daemon (CPU/RAM) runs on all platforms:
  - macOS: launchd agent
  - Linux: systemd user service
  - Windows: Task Scheduler
- Starship prompt is installed automatically if not present
- Atuin shell history is installed automatically if not present
- Backup files are timestamped: `~/.config/wezterm.bak.<timestamp>`
