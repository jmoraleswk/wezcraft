#!/usr/bin/env bash
set -euo pipefail

# WezTerm Config Uninstaller
# Usage: ./installer/uninstall.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OS="$(uname -s)"
case "$OS" in
  Darwin) bash "$SCRIPT_DIR/scripts/macos-uninstall.sh" ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "Detected Windows environment (Git Bash/MSYS)."
    echo ""
    echo "Please run the PowerShell uninstaller instead:"
    echo "  .\installer\scripts\windows-uninstall.ps1"
    ;;
  Linux)
    bash "$SCRIPT_DIR/scripts/linux-uninstall.sh"
    ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac
