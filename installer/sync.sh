#!/usr/bin/env bash
set -euo pipefail

# Test installer with local repo (instead of cloning from GitHub)
# Usage: ./installer/sync.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Testing installer with local repo ==="
echo "Source: $REPO_ROOT"
echo ""

bash "$SCRIPT_DIR/install.sh" --source "$REPO_ROOT"
