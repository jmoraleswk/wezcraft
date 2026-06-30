#!/usr/bin/env bash
set -euo pipefail

# WezCraft TUI Installer
# Interactive installer using fzf for component selection

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check for fzf and install if missing
check_fzf() {
    if ! command -v fzf &>/dev/null; then
        echo -e "${YELLOW}fzf not found. Installing...${NC}"
        echo ""
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &>/dev/null; then
                brew install fzf
            else
                echo -e "${RED}Error: Homebrew not found. Install manually:${NC}"
                echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                exit 1
            fi
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

# Show progress
show_progress() {
    local component="$1"
    local status="$2"
    
    if [[ "$status" == "installing" ]]; then
        echo -ne "${CYAN}⏳ Installing ${component}...${NC}"
    elif [[ "$status" == "done" ]]; then
        echo -e "\r${GREEN}✓ ${component} installed${NC}"
    elif [[ "$status" == "skip" ]]; then
        echo -e "\r${YELLOW}⊘ ${component} already installed${NC}"
    elif [[ "$status" == "error" ]]; then
        echo -e "\r${RED}✗ ${component} failed${NC}"
    fi
}

# Main installation logic
main() {
    check_fzf
    show_banner
    
    # Parse --source parameter
    local source_dir=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source) source_dir="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    # Check if running from repo or needs to clone
    if [[ -z "$source_dir" ]]; then
        if [[ -d "$(dirname "$0")/../wezterm.lua" ]]; then
            source_dir="$(dirname "$0")/.."
        fi
    fi
    
    if [[ -z "$source_dir" ]]; then
        echo -e "${YELLOW}Cloning repository...${NC}"
        local tmpdir
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        
        if ! command -v git &>/dev/null; then
            echo -e "${RED}Error: git not found${NC}"
            exit 1
        fi
        
        git clone --depth 1 "https://github.com/jmoraleswk/wezcraft" "$tmpdir/wezcraft" 2>/dev/null
        source_dir="$tmpdir/wezcraft"
    fi
    
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
