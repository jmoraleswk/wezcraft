#!/usr/bin/env bash
set -euo pipefail

SOURCE="$1"
TARGET="${HOME}/.config/wezterm"

echo "=== WezTerm Installer (Linux) ==="
echo "Source: $SOURCE"
echo "Target: $TARGET"
echo ""

# --- 1. Check git ---
if ! command -v git &>/dev/null; then
  echo "Error: git not found. Install it with your package manager:"
  echo "  Ubuntu/Debian: sudo apt install git"
  echo "  Fedora: sudo dnf install git"
  echo "  Arch: sudo pacman -S git"
  exit 1
fi

# --- 2. Backup existing config ---
if [[ -d "$TARGET" ]]; then
  BACKUP="${HOME}/.config/wezterm.bak.$(date +%s)"
  echo "Backing up existing config → $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

# --- 3. Copy config ---
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

# --- 4. Create required directories ---
mkdir -p "${HOME}/.local/share/wezterm/resurrect"
mkdir -p "${HOME}/.local/state/wezterm"

# --- 5. Install font ---
echo ""
echo "Installing FiraCode Nerd Font..."
FONT_DIR="${HOME}/.local/share/fonts"
mkdir -p "$FONT_DIR"

if [[ ! -f "$FONT_DIR/FiraCodeNerdFont-Regular.ttf" ]]; then
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz"
  echo "Downloading from: $FONT_URL"
  TEMP_DIR="$(mktemp -d)"
  trap 'rm -f "$TEMP_DIR/FiraCode.tar.xz"; rm -rf "$TEMP_DIR"' EXIT
  
  if command -v curl &>/dev/null; then
    curl -L -o "$TEMP_DIR/FiraCode.tar.xz" "$FONT_URL"
  elif command -v wget &>/dev/null; then
    wget -O "$TEMP_DIR/FiraCode.tar.xz" "$FONT_URL"
  else
    echo "Warning: curl or wget not found. Please install FiraCode Nerd Font manually."
    echo "  Visit: https://www.nerdfonts.com/font-downloads"
  fi
  
  if [[ -f "$TEMP_DIR/FiraCode.tar.xz" ]]; then
    tar -xf "$TEMP_DIR/FiraCode.tar.xz" -C "$TEMP_DIR"
    find "$TEMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
    fc-cache -fv 2>/dev/null || true
    echo "FiraCode Nerd Font installed."
  fi
else
  echo "FiraCode Nerd Font already installed."
fi

# --- 6. Install Starship prompt ---
echo ""
if command -v starship &>/dev/null; then
  echo "Starship already installed: $(starship --version | head -1)"
else
  read -rp "Install Starship prompt? [Y/n] " INSTALL_STARSHIP
  INSTALL_STARSHIP="${INSTALL_STARSHIP:-Y}"
  if [[ "$INSTALL_STARSHIP" =~ ^[Yy]$ ]]; then
    echo "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    echo "Starship installed."
  fi
fi

# --- 7. Starship config ---
STARSHIP_CONFIG="${HOME}/.config/starship/starship.toml"
if [[ ! -f "$STARSHIP_CONFIG" ]]; then
  echo "Creating Starship config with nerd-font-symbols preset..."
  mkdir -p "${HOME}/.config/starship"
  starship preset nerd-font-symbols -o "$STARSHIP_CONFIG"
  echo "Starship config created at: $STARSHIP_CONFIG"
fi

# --- 8. Shell integration (Starship) ---
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

# --- 9. Install Atuin shell history ---
echo ""
if command -v atuin &>/dev/null; then
  echo "Atuin already installed: $(atuin --version)"
else
  read -rp "Install Atuin (shell history)? [Y/n] " INSTALL_ATUIN
  INSTALL_ATUIN="${INSTALL_ATUIN:-Y}"
  if [[ "$INSTALL_ATUIN" =~ ^[Yy]$ ]]; then
    echo "Installing Atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    echo "Atuin installed."
  fi
fi

# --- 9. Stats daemon (systemd) ---
echo ""
echo "Installing stats daemon (CPU/RAM)..."

# Make stats script executable
chmod +x "$TARGET/elements/statusbar/update_stats_linux.sh"

# Create systemd service
SYSTEMD_DIR="${HOME}/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

cat > "$SYSTEMD_DIR/wezterm-stats.service" <<EOF
[Unit]
Description=WezTerm Stats Daemon (CPU/RAM)
After=graphical-session.target

[Service]
Type=simple
ExecStart=$TARGET/elements/statusbar/update_stats_linux.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Enable and start the service
systemctl --user daemon-reload
systemctl --user enable wezterm-stats.service
systemctl --user start wezterm-stats.service

echo "Stats daemon installed and started."
echo "Service file: $SYSTEMD_DIR/wezterm-stats.service"

# --- 10. Summary ---
echo ""
echo "=== Done ==="
echo "Config installed to: $TARGET"
echo "Plugin: resurrect.wezterm (bundled)"
echo "Font: FiraCode Nerd Font"
if command -v starship &>/dev/null; then
  echo "Starship: installed"
fi
if command -v atuin &>/dev/null; then
  echo "Atuin: installed"
fi
echo "Stats daemon: active (systemd)"
echo ""
echo "Restart your terminal to apply changes."
