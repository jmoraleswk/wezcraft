#!/usr/bin/env bash
set -euo pipefail

SOURCE="$1"
TARGET="${HOME}/.config/wezterm"

echo "=== WezTerm Installer (macOS) ==="
echo "Source: $SOURCE"
echo "Target: $TARGET"
echo ""

# --- 1. Check brew ---
if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew not found. Install it first:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

# --- 2. Check git ---
if ! command -v git &>/dev/null; then
  echo "Error: git not found. Install Xcode Command Line Tools:"
  echo '  xcode-select --install'
  exit 1
fi

# --- 3. Backup existing config ---
if [[ -d "$TARGET" ]]; then
  BACKUP="${HOME}/.config/wezterm.bak.$(date +%s)"
  echo "Backing up existing config → $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

# --- 4. Copy config ---
echo "Copying config files..."
mkdir -p "$TARGET"
rsync -a --exclude='.git' \
          --exclude='.gitignore' \
          --exclude='.DS_Store' \
          --exclude='.atl' \
          --exclude='codebase' \
          --exclude='installer' \
          --exclude='/docs' \
          --exclude='README.md' \
          "$SOURCE/" "$TARGET/"

# --- 5. Create required directories ---
mkdir -p "${HOME}/.local/share/wezterm/resurrect"
mkdir -p "${HOME}/.local/state/wezterm"

# --- 6. Install font ---
echo "Installing FiraCode Nerd Font..."
if [[ -f "${HOME}/Library/Fonts/FiraCodeNerdFont-Regular.ttf" ]]; then
  echo "FiraCode Nerd Font already installed."
else
  # Remove old font files if they exist to avoid brew errors
  rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFont-*.ttf
  rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFontMono-*.ttf
  rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFontPropo-*.ttf
  brew install --cask font-fira-code-nerd-font 2>/dev/null || true
fi

# --- 7. Setup launchd agent ---
echo "Setting up stats daemon..."
STATS_SCRIPT="$TARGET/elements/statusbar/update_stats.sh"
chmod +x "$STATS_SCRIPT"

PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.user.wezterm-stats.plist"
mkdir -p "$PLIST_DIR"

cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.wezterm-stats</string>
    <key>ProgramArguments</key>
    <array>
        <string>${STATS_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST

launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE"

# --- 8. Starship prompt ---
echo ""
if command -v starship &>/dev/null; then
  echo "Starship already installed: $(starship --version | head -1)"
else
  read -rp "Install Starship prompt? [Y/n] " INSTALL_STARSHIP
  INSTALL_STARSHIP="${INSTALL_STARSHIP:-Y}"
  if [[ "$INSTALL_STARSHIP" =~ ^[Yy]$ ]]; then
    echo "Installing Starship..."
    brew install starship
    echo "Starship installed."
  fi
fi

# --- 9. Starship config ---
STARSHIP_CONFIG="${HOME}/.config/starship/starship.toml"
if [[ ! -f "$STARSHIP_CONFIG" ]]; then
  echo "Creating Starship config with nerd-font-symbols preset..."
  mkdir -p "${HOME}/.config/starship"
  starship preset nerd-font-symbols -o "$STARSHIP_CONFIG"
  echo "Starship config created at: $STARSHIP_CONFIG"
fi

# --- 10. Shell integration (Starship) ---
if command -v starship &>/dev/null; then
  SHELL_NAME="$(basename "$SHELL")"
  case "$SHELL_NAME" in
    zsh)  STARSHIP_RC="${HOME}/.zshrc" ;;
    bash) STARSHIP_RC="${HOME}/.bashrc" ;;
    fish) STARSHIP_RC="${HOME}/.config/fish/config.fish" ;;
    *)    STARSHIP_RC="" ;;
  esac

  if [[ -n "$STARSHIP_RC" ]] && [[ -f "$STARSHIP_RC" ]]; then
    if ! grep -q "starship init" "$STARSHIP_RC" 2>/dev/null; then
      echo "Adding Starship to $STARSHIP_RC..."
      case "$SHELL_NAME" in
        fish) echo 'starship init fish | source' >> "$STARSHIP_RC" ;;
        *)    echo "eval \"\$(starship init $SHELL_NAME)\"" >> "$STARSHIP_RC" ;;
      esac
    fi
    # Add resurrect() helper function
    if ! grep -q "resurrect()" "$STARSHIP_RC" 2>/dev/null; then
      echo "Adding resurrect() helper to $STARSHIP_RC..."
      cat >> "$STARSHIP_RC" <<'RESURRECT'

# WezTerm Resurrect helper
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
RESURRECT
    fi
  fi
fi

# --- 11. Atuin shell history ---
echo ""
if command -v atuin &>/dev/null; then
  echo "Atuin already installed: $(atuin --version)"
else
  read -rp "Install Atuin (shell history)? [Y/n] " INSTALL_ATUIN
  INSTALL_ATUIN="${INSTALL_ATUIN:-Y}"
  if [[ "$INSTALL_ATUIN" =~ ^[Yy]$ ]]; then
    echo "Installing Atuin..."
    brew install atuin
    echo "Atuin installed."
  fi
fi

# --- 11. Atuin shell plugin ---
if command -v atuin &>/dev/null; then
  SHELL_NAME="$(basename "$SHELL")"
  case "$SHELL_NAME" in
    zsh)  ATUIN_RC="${HOME}/.zshrc" ;;
    bash) ATUIN_RC="${HOME}/.bashrc" ;;
    fish) ATUIN_RC="${HOME}/.config/fish/config.fish" ;;
    *)    ATUIN_RC="" ;;
  esac

  if [[ -n "$ATUIN_RC" ]] && [[ -f "$ATUIN_RC" ]]; then
    if ! grep -q "atuin init" "$ATUIN_RC" 2>/dev/null; then
      echo "Adding Atuin to $ATUIN_RC..."
      case "$SHELL_NAME" in
        fish) echo 'if status is-interactive
    atuin init fish | source
end' >> "$ATUIN_RC" ;;
        *)    echo "eval \"\$(atuin init $SHELL_NAME)\"" >> "$ATUIN_RC" ;;
      esac
    fi
  fi
fi

# --- 12. Summary ---
echo ""
echo "=== Done ==="
echo "Config installed to: $TARGET"
echo "Plugin: resurrect.wezterm (bundled)"
echo "Stats daemon: running (launchd)"
echo "Font: FiraCode Nerd Font"
if command -v starship &>/dev/null; then
  echo "Starship: installed"
fi
if command -v atuin &>/dev/null; then
  echo "Atuin: installed"
fi
echo ""
echo "Restart WezTerm to apply changes."
