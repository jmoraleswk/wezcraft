#!/usr/bin/env bash
set -euo pipefail

echo "=== WezTerm Uninstaller (Linux) ==="
echo ""

# --- 1. Prompt: remove config ---
read -rp "Remove ~/.config/wezterm/? [y/N] " ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
  rm -rf "${HOME}/.config/wezterm"
  echo "  Removed ~/.config/wezterm/"
  # Remove resurrect() helper from .zshrc
  SHELL_RC="${HOME}/.zshrc"
  if [[ -f "$SHELL_RC" ]] && grep -q "resurrect()" "$SHELL_RC" 2>/dev/null; then
    sed -i '/^resurrect() {/,/^}/d' "$SHELL_RC"
    # Remove empty lines left after deletion
    sed -i '/^$/N;/^\n$/d' "$SHELL_RC"
    echo "  Removed resurrect() from shell config"
  fi
fi

# --- 2. Prompt: remove session saves ---
read -rp "Remove ~/.local/share/wezterm/ (session saves)? [y/N] " ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
  rm -rf "${HOME}/.local/share/wezterm"
  echo "  Removed ~/.local/share/wezterm/"
fi

# --- 3. Prompt: remove font ---
read -rp "Remove FiraCode Nerd Font? [y/N] " ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
  FONT_DIR="${HOME}/.local/share/fonts"
  rm -f "$FONT_DIR"/FiraCodeNerdFont-*.ttf
  fc-cache -fv 2>/dev/null || true
  echo "  Removed FiraCode Nerd Font"
fi

# --- 4. Prompt: remove Starship ---
if command -v starship &>/dev/null; then
  STARSHIP_BIN="$(which starship)"
  read -rp "Remove Starship? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    rm -f "$STARSHIP_BIN"
    # Remove shell integration from .zshrc
    SHELL_RC="${HOME}/.zshrc"
    if [[ -f "$SHELL_RC" ]]; then
      sed -i '/starship init/d' "$SHELL_RC"
      echo "  Removed Starship from shell config"
    fi
    echo "  Removed Starship binary: $STARSHIP_BIN"
  fi
fi

# --- 5. Prompt: remove Starship config ---
STARSHIP_CONFIG_DIR="${HOME}/.config/starship"
if [[ -d "$STARSHIP_CONFIG_DIR" ]]; then
  read -rp "Remove Starship config (~/.config/starship/)? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    rm -rf "$STARSHIP_CONFIG_DIR"
    echo "  Removed Starship config"
  fi
fi

# --- 6. Prompt: remove Atuin ---
if command -v atuin &>/dev/null; then
  ATUIN_BIN="$(which atuin)"
  read -rp "Remove Atuin? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    rm -f "$ATUIN_BIN"
    rm -rf "${HOME}/.local/share/atuin"
    # Remove shell integration from .zshrc
    SHELL_RC="${HOME}/.zshrc"
    if [[ -f "$SHELL_RC" ]]; then
      sed -i '/atuin init/d' "$SHELL_RC"
      echo "  Removed Atuin from shell config"
    fi
    echo "  Removed Atuin: $ATUIN_BIN"
  fi
fi

# --- 7. Prompt: remove stats daemon ---
SYSTEMD_DIR="${HOME}/.config/systemd/user"
if [[ -f "$SYSTEMD_DIR/wezterm-stats.service" ]]; then
  read -rp "Remove stats daemon (CPU/RAM)? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    systemctl --user stop wezterm-stats.service 2>/dev/null || true
    systemctl --user disable wezterm-stats.service 2>/dev/null || true
    rm -f "$SYSTEMD_DIR/wezterm-stats.service"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "  Removed stats daemon"
  fi
fi

# --- 9. Prompt: remove backups ---
BACKUPS=($(ls -d "${HOME}"/.config/wezterm.bak.* 2>/dev/null || true))
if [[ ${#BACKUPS[@]} -gt 0 ]]; then
  echo "Found ${#BACKUPS[@]} backup(s):"
  for b in "${BACKUPS[@]}"; do echo "  $b"; done
  read -rp "Remove all backups? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    rm -rf "${HOME}"/.config/wezterm.bak.*
    echo "  Removed backups"
  fi
fi

echo ""
echo "=== Uninstall complete ==="
