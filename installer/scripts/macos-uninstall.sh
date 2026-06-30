#!/usr/bin/env bash
set -euo pipefail

echo "=== WezTerm Uninstaller (macOS) ==="
echo ""

# --- 1. Stop launchd agent (always) ---
PLIST="${HOME}/Library/LaunchAgents/com.user.wezterm-stats.plist"
if [[ -f "$PLIST" ]]; then
  echo "Stopping stats daemon..."
  launchctl unload "$PLIST" 2>/dev/null || true
  rm "$PLIST"
  echo "  Removed launchd agent"
fi

# Remove stats file
rm -f /tmp/wezterm_stats.txt

# --- 2. Prompt: remove config ---
read -rp "Remove ~/.config/wezterm/? [y/N] " ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
  rm -rf "${HOME}/.config/wezterm"
  echo "  Removed ~/.config/wezterm/"
  # Remove resurrect() helper from .zshrc
  SHELL_RC="${HOME}/.zshrc"
  if [[ -f "$SHELL_RC" ]] && grep -q "resurrect()" "$SHELL_RC" 2>/dev/null; then
    sed -i '' '/^resurrect() {/,/^}/d' "$SHELL_RC"
    # Remove empty lines left after deletion
    sed -i '' '/^$/N;/^\n$/d' "$SHELL_RC"
    echo "  Removed resurrect() from shell config"
  fi
fi

# --- 3. Prompt: remove session saves ---
read -rp "Remove ~/.local/share/wezterm/ (session saves)? [y/N] " ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
  rm -rf "${HOME}/.local/share/wezterm"
  echo "  Removed ~/.local/share/wezterm/"
fi

# --- 4. Prompt: remove font ---
if [[ -f "${HOME}/Library/Fonts/FiraCodeNerdFont-Regular.ttf" ]]; then
  read -rp "Remove FiraCode Nerd Font? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    brew uninstall --cask font-fira-code-nerd-font 2>/dev/null || true
    rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFont-*.ttf
    rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFontMono-*.ttf
    rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFontPropo-*.ttf
    echo "  Removed FiraCode Nerd Font"
  fi
fi

# --- 5. Prompt: remove starship ---
if command -v starship &>/dev/null; then
  read -rp "Remove Starship? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    brew uninstall starship 2>/dev/null || true
    # Remove shell integration from .zshrc
    SHELL_RC="${HOME}/.zshrc"
    if [[ -f "$SHELL_RC" ]]; then
      sed -i '' '/starship init/d' "$SHELL_RC"
      echo "  Removed Starship from shell config"
    fi
    echo "  Removed Starship"
  fi
fi

# --- 6. Prompt: remove atuin ---
if command -v atuin &>/dev/null; then
  read -rp "Remove Atuin? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    brew uninstall atuin 2>/dev/null || true
    # Remove shell integration from .zshrc
    SHELL_RC="${HOME}/.zshrc"
    if [[ -f "$SHELL_RC" ]]; then
      sed -i '' '/atuin init/d' "$SHELL_RC"
      echo "  Removed Atuin from shell config"
    fi
    echo "  Removed Atuin"
  fi
fi

# --- 7. Prompt: remove starship config ---
STARSHIP_CONFIG_DIR="${HOME}/.config/starship"
if [[ -d "$STARSHIP_CONFIG_DIR" ]]; then
  read -rp "Remove Starship config (~/.config/starship/)? [y/N] " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    rm -rf "$STARSHIP_CONFIG_DIR"
    echo "  Removed Starship config"
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
