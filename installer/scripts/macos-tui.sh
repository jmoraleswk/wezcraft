#!/usr/bin/env bash
set -euo pipefail

# WezCraft macOS TUI Installer
# Called from tui-install.sh with component flags

SOURCE="$1"
shift

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --starship=*) STARSHIP_INSTALL="${arg#*=}" ;;
        --atuin=*)    ATUIN_INSTALL="${arg#*=}" ;;
        --stats=*)    STATS_INSTALL="${arg#*=}" ;;
        --font=*)     FONT_INSTALL="${arg#*=}" ;;
    esac
done

# Defaults
STARSHIP_INSTALL="${STARSHIP_INSTALL:-false}"
ATUIN_INSTALL="${ATUIN_INSTALL:-false}"
STATS_INSTALL="${STATS_INSTALL:-false}"
FONT_INSTALL="${FONT_INSTALL:-false}"

TARGET="${HOME}/.config/wezterm"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== WezCraft macOS Installer ===${NC}"
echo ""

# --- 1. Backup existing config ---
if [[ -d "$TARGET" ]]; then
    BACKUP="${HOME}/.config/wezterm.bak.$(date +%s)"
    echo -e "${YELLOW}Backing up existing config → $BACKUP${NC}"
    mv "$TARGET" "$BACKUP"
fi

# --- 2. Copy config ---
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

# --- 3. Create required directories ---
mkdir -p "${HOME}/.local/share/wezterm/resurrect"
mkdir -p "${HOME}/.local/state/wezterm"

# --- 4. Install font (Homebrew) ---
if [[ "$FONT_INSTALL" == "true" ]]; then
    echo ""
    echo "Installing FiraCode Nerd Font..."
    if [[ -f "${HOME}/Library/Fonts/FiraCodeNerdFont-Regular.ttf" ]]; then
        echo -e "${YELLOW}⊘ FiraCode Nerd Font already installed${NC}"
    else
        # Remove old font files if they exist to avoid brew errors
        rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFont-*.ttf
        rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFontMono-*.ttf
        rm -f "${HOME}"/Library/Fonts/FiraCodeNerdFontPropo-*.ttf
        brew install --cask font-fira-code-nerd-font
        echo -e "${GREEN}✓ FiraCode Nerd Font installed${NC}"
    fi
fi

# --- 5. Install Starship prompt ---
if [[ "$STARSHIP_INSTALL" == "true" ]]; then
    echo ""
    if ! command -v starship &>/dev/null; then
        echo "Installing Starship..."
        brew install starship
        echo -e "${GREEN}✓ Starship installed${NC}"
    else
        echo -e "${YELLOW}⊘ Starship already installed${NC}"
    fi
    
    # Starship config - nerd-font-symbols preset
    STARSHIP_CONFIG="${HOME}/.config/starship/starship.toml"
    if [[ ! -f "$STARSHIP_CONFIG" ]]; then
        echo "Creating Starship config with nerd-font-symbols preset..."
        mkdir -p "${HOME}/.config/starship"
        starship preset nerd-font-symbols -o "$STARSHIP_CONFIG"
        echo -e "${GREEN}✓ Starship config created${NC}"
    fi
    
    # Shell integration - add starship init to shell RC
    SHELL_NAME="$(basename "$SHELL")"
    SHELL_RC=""
    case "$SHELL_NAME" in
        zsh)  SHELL_RC="${HOME}/.zshrc" ;;
        bash) SHELL_RC="${HOME}/.bashrc" ;;
    esac
    
    if [[ -n "$SHELL_RC" ]] && [[ -f "$SHELL_RC" ]]; then
        if ! grep -q "starship init" "$SHELL_RC" 2>/dev/null; then
            echo "Adding Starship to $SHELL_RC..."
            echo "eval \"\$(starship init $SHELL_NAME)\"" >> "$SHELL_RC"
            echo -e "${GREEN}✓ Starship added to shell${NC}"
        fi
    fi
    
    # Add resurrect() helper function
    if [[ -n "$SHELL_RC" ]] && [[ -f "$SHELL_RC" ]]; then
        if ! grep -q "resurrect()" "$SHELL_RC" 2>/dev/null; then
            echo "Adding resurrect() helper to $SHELL_RC..."
            cat >> "$SHELL_RC" <<'RESURRECT'

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
            echo -e "${GREEN}✓ resurrect() helper added to shell${NC}"
        fi
    fi
fi

# --- 6. Install Atuin shell history ---
if [[ "$ATUIN_INSTALL" == "true" ]]; then
    echo ""
    if ! command -v atuin &>/dev/null; then
        echo "Installing Atuin..."
        brew install atuin
        echo -e "${GREEN}✓ Atuin installed${NC}"
    else
        echo -e "${YELLOW}⊘ Atuin already installed${NC}"
    fi
    
    # Shell integration - add atuin init to shell RC
    SHELL_NAME="$(basename "$SHELL")"
    SHELL_RC=""
    case "$SHELL_NAME" in
        zsh)  SHELL_RC="${HOME}/.zshrc" ;;
        bash) SHELL_RC="${HOME}/.bashrc" ;;
    esac
    
    if [[ -n "$SHELL_RC" ]] && [[ -f "$SHELL_RC" ]]; then
        if ! grep -q "atuin init" "$SHELL_RC" 2>/dev/null; then
            echo "Adding Atuin to $SHELL_RC..."
            echo "eval \"\$(atuin init $SHELL_NAME)\"" >> "$SHELL_RC"
            echo -e "${GREEN}✓ Atuin added to shell${NC}"
        fi
    fi
fi

# --- 8. Stats daemon (launchd) ---
if [[ "$STATS_INSTALL" == "true" ]]; then
    echo ""
    echo "Installing stats daemon..."
    
    chmod +x "$TARGET/elements/statusbar/update_stats.sh"
    
    PLIST_DIR="${HOME}/Library/LaunchAgents"
    mkdir -p "$PLIST_DIR"
    PLIST_FILE="${PLIST_DIR}/com.user.wezterm-stats.plist"
    
    cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.wezterm-stats</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$TARGET/elements/statusbar/update_stats.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    
    # Unload if already loaded, then load
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    
    echo -e "${GREEN}✓ Stats daemon installed and started${NC}"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
