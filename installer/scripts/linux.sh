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
          --exclude='docs' \
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
STARSHIP_CONFIG="${HOME}/.config/starship.toml"
if [[ ! -f "$STARSHIP_CONFIG" ]]; then
  echo "Creating default Starship config..."
  mkdir -p "${HOME}/.config"
  cat > "$STARSHIP_CONFIG" <<'TOML'
# Starship config for WezCraft
format = """
$directory\
$git_branch\
$git_status\
$nodejs\
$lua\
$docker_context\
$shell\
$character"""

[directory]
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = " "

[git_status]
deleted = "✘"
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇡${count}⇣${count}"

[nodejs]
symbol = " "

[lua]
symbol = " "

[docker_context]
symbol = " "

[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"
TOML
  echo "Starship config created at: $STARSHIP_CONFIG"
fi

# --- 8. Install Atuin shell history ---
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

# --- 9. Shell integration (Starship + Atuin) ---
SHELL_NAME="$(basename "$SHELL")"
SHELL_RC=""
case "$SHELL_NAME" in
  zsh)  SHELL_RC="${HOME}/.zshrc" ;;
  bash) SHELL_RC="${HOME}/.bashrc" ;;
  fish) SHELL_RC="${HOME}/.config/fish/config.fish" ;;
esac

if [[ -n "$SHELL_RC" ]] && [[ -f "$SHELL_RC" ]]; then
  # Starship
  if command -v starship &>/dev/null; then
    if ! grep -q "starship init" "$SHELL_RC" 2>/dev/null; then
      echo "Adding Starship to $SHELL_RC..."
      case "$SHELL_NAME" in
        fish) echo 'starship init fish | source' >> "$SHELL_RC" ;;
        *)    echo "eval \"\$(starship init $SHELL_NAME)\"" >> "$SHELL_RC" ;;
      esac
    fi
  fi

  # Atuin
  if command -v atuin &>/dev/null; then
    if ! grep -q "atuin init" "$SHELL_RC" 2>/dev/null; then
      echo "Adding Atuin to $SHELL_RC..."
      case "$SHELL_NAME" in
        fish) echo 'if status is-interactive
    atuin init fish | source
end' >> "$SHELL_RC" ;;
        *)    echo "eval \"\$(atuin init $SHELL_NAME)\"" >> "$SHELL_RC" ;;
      esac
    fi
  fi
fi

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
echo ""
echo "Note: Stats daemon (CPU/RAM) is not available on Linux."
echo "Restart your terminal or run: source $SHELL_RC"
