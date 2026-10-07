#!/usr/bin/env bash
set -euo pipefail

# WezCraft TUI Installer
# Interactive installer using fzf for component selection
# Internal — invoked via installer/install.sh, which always passes --source.

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# macOS package-manager layer (MacPorts on Intel x86_64, Homebrew on Apple
# Silicon arm64). Sourced at the top so a missing pkg.sh fails fast at
# startup rather than mid-install; the layer is macOS-only, so skip it
# elsewhere.
if [[ "$OSTYPE" == "darwin"* ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/scripts/pkg.sh"
fi

# Check for fzf and install if missing
check_fzf() {
    if ! command -v fzf &>/dev/null; then
        echo -e "${YELLOW}fzf not found. Installing...${NC}"
        echo ""
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS — package manager chosen by CPU architecture (layer
            # sourced at the top of this script)
            detect_pkg_manager
            if [[ -z "$PKG_MANAGER" ]]; then
                # Required manager missing (MacPorts on Intel, Homebrew on
                # Apple Silicon): consent flow before giving up (no-op on
                # any other architecture; exit 1 on decline/failure).
                pkg_bootstrap_manager
            fi
            if [[ -z "$PKG_MANAGER" ]]; then
                echo -e "${RED}Error: No supported package manager found (Homebrew or MacPorts). Install manually:${NC}"
                echo "  Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                echo "  MacPorts: https://www.macports.org/install.php"
                exit 1
            fi
            pkg_install cli fzf
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y fzf
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y fzf
            elif command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm fzf
            else
                echo -e "${RED}Error: Could not detect package manager. Install fzf manually:${NC}"
                echo "  https://github.com/junegunn/fzf#installation"
                exit 1
            fi
        else
            echo -e "${RED}Error: Unsupported OS. Install fzf manually:${NC}"
            echo "  https://github.com/junegunn/fzf#installation"
            exit 1
        fi
        
        # Verify installation
        if ! command -v fzf &>/dev/null; then
            echo -e "${RED}Error: fzf installation failed${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ fzf installed${NC}"
        echo ""
    fi
}

# Welcome banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "██╗    ██╗███████╗███████╗ ██████╗██████╗  █████╗ ███████╗████████╗"
    echo "██║    ██║██╔════╝╚══███╔╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
    echo "██║ █╗ ██║█████╗    ███╔╝ ██║     ██████╔╝███████║█████╗     ██║   "
    echo "██║███╗██║██╔══╝   ███╔╝  ██║     ██╔══██╗██╔══██║██╔══╝     ██║   "
    echo "╚███╔███╔╝███████╗███████╗╚██████╗██║  ██║██║  ██║██║        ██║   "
    echo " ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝   "
    echo -e "${NC}"
    echo -e "${BLUE}WezCraft Configuration${NC}"
    echo -e "${CYAN}Customize your WezTerm setup with optimized tools${NC}"
    echo ""
}

# Component selection menu
select_components() {
    echo -e "${BOLD}Select components to install:${NC}" >&2
    echo "" >&2
    
    # Define components with descriptions
    local components=(
        "✅ all      - Select all components"
        "⭐ starship - Cross-platform prompt"
        "📜 atuin    - Shell history with sync"
        "📊 stats    - CPU/RAM stats in status bar"
        "🔤 font     - FiraCode Nerd Font"
    )
    
    # Use fzf for multi-selection
    local selected
    selected=$(printf '%s\n' "${components[@]}" | \
        fzf --multi \
            --prompt="Select components> " \
            --height=40% \
            --reverse \
            --header="TAB select | CTRL+A all | ENTER confirm | ESC exit" \
            --bind="ctrl-a:select-all" \
            --ansi \
            --color=pointer:bold:blue,prompt:bold:cyan)
    
    # ESC pressed (empty selection = cancel)
    if [[ -z "$selected" ]]; then
        echo ""
        read -rp "Are you sure you want to exit? [Y/n] " confirm
        confirm="${confirm:-Y}"
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Installation cancelled.${NC}"
            exit 1
        else
            # User wants to continue, re-run selection
            select_components
            return $?
        fi
    fi
    
    echo "$selected"
}

# Confirm installation
confirm_install() {
    local selected="$1"
    
    echo ""
    echo -e "${BOLD}Selected components:${NC}"
    echo "$selected" | while read -r line; do
        # Extract just the emoji and name (before the dash)
        local display
        display=$(echo "$line" | sed 's/ -.*$//')
        echo -e "  ${GREEN}✓${NC} $display"
    done
    echo ""
    
    read -rp "Proceed with installation? [Y/n] " confirm
    confirm="${confirm:-Y}"
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Returning to selection...${NC}"
        echo ""
        select_components
        return $?
    fi
}

# Component progress (⏳/✓/⊘/✗ single-line updates, log capture, failure
# recording) is handled by show_progress + pkg_run_component, defined in
# scripts/pkg.sh — the ONE file sourced by this script and both macOS
# installers, because macos.sh / macos-tui.sh are separate processes and
# cannot see a helper defined only here.

# Main installation logic
main() {
    # Resolve and validate the source BEFORE anything with side effects:
    # a missing-source invocation must fail fast instead of triggering
    # check_fzf (which may install fzf through the package-manager layer).
    local source_dir=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source) source_dir="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$source_dir" ]]; then
        echo -e "${RED}Error: --source is required.${NC}"
        echo "Run this script via installer/install.sh, or pass --source <path>."
        exit 1
    fi

    if [[ ! -d "$source_dir" ]]; then
        echo -e "${RED}Error: Source directory not found: $source_dir${NC}"
        exit 1
    fi

    check_fzf
    show_banner
    
    # Select components
    local selected
    if ! selected=$(select_components); then
        exit 0
    fi
    
    # Confirm
    confirm_install "$selected"
    
    echo ""
    echo -e "${BOLD}Starting installation...${NC}"
    echo ""
    
    # Parse selections and install
    local install_starship=false
    local install_atuin=false
    local install_stats=false
    local install_font=false
    
    if echo "$selected" | grep -q "all"; then
        install_starship=true
        install_atuin=true
        install_stats=true
        install_font=true
    else
        if echo "$selected" | grep -q "starship"; then
            install_starship=true
        fi
        if echo "$selected" | grep -q "atuin"; then
            install_atuin=true
        fi
        if echo "$selected" | grep -q "stats"; then
            install_stats=true
        fi
        if echo "$selected" | grep -q "font"; then
            install_font=true
        fi
    fi
    
    # Delegate to platform-specific installer with flags
    local os
    os="$(uname -s)"
    
    case "$os" in
        Darwin)
            bash "$(dirname "$0")/scripts/macos-tui.sh" "$source_dir" \
                --starship="$install_starship" \
                --atuin="$install_atuin" \
                --stats="$install_stats" \
                --font="$install_font"
            ;;
        Linux)
            bash "$(dirname "$0")/scripts/linux-tui.sh" "$source_dir" \
                --starship="$install_starship" \
                --atuin="$install_atuin" \
                --stats="$install_stats" \
                --font="$install_font"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $os${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo -e "Restart your terminal to apply changes."
}

main "$@"
