#!/usr/bin/env bash
set -euo pipefail

# WezTerm Config Installer
# Usage: ./installer/install.sh [--source <path>] [--repo <url>] [--tui]
#
# Bootstrap (piped) usage — this is the entry point documented in the README:
#   curl -fsSL https://raw.githubusercontent.com/jmoraleswk/wezcraft/main/installer/install.sh | bash -s -- --tui
#
# When piped, BASH_SOURCE is empty, so this script clones the repo to a temp
# directory and re-runs itself FROM the clone in a child process (normal mode),
# which owns source resolution and platform dispatch. The clone doubles as the
# default config source, and the temp directory is removed on exit.

REPO_URL="https://github.com/jmoraleswk/wezcraft"
SOURCE=""
USE_LOCAL=false
USE_TUI=false

# Preserve the original arguments BEFORE parsing: the bootstrap path must
# forward them verbatim to the cloned script.
ORIG_ARGS=("$@")

# ---------------------------------------------------------------------------
# 1. Parse args first — no BASH_SOURCE reference until mode is known.
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; USE_LOCAL=true; shift 2 ;;
    --repo)   REPO_URL="$2"; shift 2 ;;
    --tui)    USE_TUI=true; shift ;;
    *)        echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# 2. Mode detection.
#    BOOTSTRAP: piped (`curl | bash`), path is not a regular file
#               (process substitution, stdin), or the script does not live in
#               a wezcraft checkout (no ../wezterm.lua repo marker).
#    NORMAL:    running from inside a checkout of the repo.
#    Use ${BASH_SOURCE[0]:-} — a bare expansion fails under `set -u` when
#    the script is piped to bash.
# ---------------------------------------------------------------------------
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
BOOTSTRAP=false
SCRIPT_DIR=""

if [[ -z "$SCRIPT_PATH" || ! -f "$SCRIPT_PATH" ]]; then
  BOOTSTRAP=true
else
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [[ ! -f "$SCRIPT_DIR/../wezterm.lua" ]]; then
    BOOTSTRAP=true
  fi
fi

# Single clone path shared by bootstrap and the defensive normal-mode
# fallback — git clone logic lives ONLY here.
clone_repo() {
  local dest="$1"

  if ! command -v git &>/dev/null; then
    echo "Error: git not found. Install Xcode Command Line Tools:"
    echo '  xcode-select --install'
    exit 1
  fi

  echo "=== WezCraft Installer ==="
  echo ""
  echo "Cloning from: $REPO_URL"
  echo ""

  git clone --depth 1 "$REPO_URL" "$dest" 2>/dev/null
}

# ---------------------------------------------------------------------------
# 3. BOOTSTRAP mode — the only flow that clones in practice.
# ---------------------------------------------------------------------------
if [[ "$BOOTSTRAP" == true ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  clone_repo "$TMP/wezcraft"

  # Forward the user's original args; the config source is the fresh clone
  # unless the user explicitly chose one with --source.
  if [[ "$USE_LOCAL" == true ]]; then
    CHILD_SOURCE="$SOURCE"
  else
    CHILD_SOURCE="$TMP/wezcraft"
  fi

  # Run the cloned script as a CHILD process (never exec: the EXIT trap above
  # must still remove the temp directory), then propagate its exit status.
  set +e
  bash "$TMP/wezcraft/installer/install.sh" \
    ${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"} \
    --source "$CHILD_SOURCE"
  CHILD_STATUS=$?
  set -e
  exit "$CHILD_STATUS"
fi

# ---------------------------------------------------------------------------
# 4. NORMAL mode — running from inside a checkout.
#    SOURCE resolution: explicit --source > repo root > defensive clone.
# ---------------------------------------------------------------------------
if [[ "$USE_LOCAL" == false ]]; then
  if [[ -f "$SCRIPT_DIR/../wezterm.lua" ]]; then
    SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"
  else
    # Defensive fallback: mode detection guarantees the repo root above,
    # so this only protects against the marker disappearing mid-run.
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    clone_repo "$TMP/wezcraft"
    SOURCE="$TMP/wezcraft"
  fi
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "Error: Source directory not found: $SOURCE"
  exit 1
fi

if [[ "$USE_TUI" == true ]]; then
  # Always pass --source explicitly; tui-install.sh requires it.
  exec bash "$SCRIPT_DIR/tui-install.sh" --source "$SOURCE"
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
