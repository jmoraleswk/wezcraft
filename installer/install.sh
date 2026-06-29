#!/usr/bin/env bash
set -euo pipefail

# WezTerm Config Installer
# Usage: ./installer/install.sh [--source <path>] [--repo <url>]

REPO_URL="https://github.com/jmoraleswk/wezcraft"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE=""
USE_LOCAL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; USE_LOCAL=true; shift 2 ;;
    --repo)   REPO_URL="$2"; shift 2 ;;
    *)        echo "Unknown option: $1"; exit 1 ;;
  esac
done

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
