#!/usr/bin/env bash
set -euo pipefail

# WezTerm Config Installer
# Usage: ./installer/install.sh [--source <path>] [--repo <url>] [--tui]

REPO_URL="https://github.com/jmoraleswk/wezcraft"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE=""
USE_LOCAL=false
USE_TUI=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; USE_LOCAL=true; shift 2 ;;
    --repo)   REPO_URL="$2"; shift 2 ;;
    --tui)    USE_TUI=true; shift ;;
    *)        echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check for TUI mode
if [[ "$USE_TUI" == true ]]; then
  # Check for fzf and install if missing
  if ! command -v fzf &>/dev/null; then
    echo "fzf not found. Installing..."
    echo ""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      if command -v brew &>/dev/null; then
        brew install fzf
      else
        echo "Error: Homebrew not found. Install manually:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
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
        echo "Error: Could not detect package manager. Install fzf manually:"
        echo "  https://github.com/junegunn/fzf#installation"
        exit 1
      fi
    else
      echo "Error: Unsupported OS. Install fzf manually:"
      echo "  https://github.com/junegunn/fzf#installation"
      exit 1
    fi
    
    # Verify installation
    if ! command -v fzf &>/dev/null; then
      echo "Error: fzf installation failed"
      exit 1
    fi
    
    echo "✓ fzf installed"
    echo ""
  fi
  
  # Run TUI installer
  tui_args=()
  if [[ -n "$SOURCE" ]]; then
    tui_args+=("--source" "$SOURCE")
  fi
  exec bash "$SCRIPT_DIR/tui-install.sh" "${tui_args[@]}"
fi

# If no --source, clone from GitHub
if [[ "$USE_LOCAL" == false ]]; then
  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT

  echo "=== WezCraft Installer ==="
  echo ""
  echo "Cloning from: $REPO_URL"
  echo ""

  if ! command -v git &>/dev/null; then
    echo "Error: git not found. Install Xcode Command Line Tools:"
    echo '  xcode-select --install'
    exit 1
  fi

  git clone --depth 1 "$REPO_URL" "$TMPDIR/wezcraft" 2>/dev/null
  SOURCE="$TMPDIR/wezcraft"
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "Error: Source directory not found: $SOURCE"
  exit 1
fi

OS="$(uname -s)"
case "$OS" in
  Darwin) bash "$SCRIPT_DIR/scripts/macos.sh" "$SOURCE" ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "Detected Windows environment (Git Bash/MSYS)."
    echo ""
    echo "Please run the PowerShell installer instead:"
    echo "  .\installer\scripts\windows.ps1"
    ;;
  Linux)
    bash "$SCRIPT_DIR/scripts/linux.sh" "$SOURCE"
    ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac
