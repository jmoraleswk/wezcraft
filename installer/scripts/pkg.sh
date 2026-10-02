#!/usr/bin/env bash
# pkg.sh — package-manager abstraction for the WezTerm installer (macOS only).
#
# Sourced (NOT executed) by the macOS installer scripts so Homebrew stays the
# preferred manager while MacPorts works as a fallback.
#
# Public API:
#   detect_pkg_manager            # sets PKG_MANAGER to "brew", "macports", or ""
#   pkg_error_no_manager          # actionable "install one of these" error
#   pkg_install <kind> <name>     # kind: cli | font
#   pkg_uninstall <kind> <name>   # kind: cli | font
#
# MacPorts needs administrator rights (it installs into /opt/local), so all
# `port` calls go through a sudo wrapper. The MacPorts font path downloads a
# pinned, SHA-256-verified nerd-fonts release instead of the unverifiable
# mutable "latest" URL.
#
# Bash 3.2 compatible (macOS /bin/bash): no associative arrays, no ${var,,}.
# Safe for callers running under `set -euo pipefail`.

# Detect the available package manager. Homebrew wins when both are installed,
# preserving the original Homebrew-only behavior. Idempotent: PKG_MANAGER is
# always (re)assigned, including to the empty string when neither exists.
detect_pkg_manager() {
  PKG_MANAGER=""
  if command -v brew &>/dev/null; then
    PKG_MANAGER="brew"
  elif command -v port &>/dev/null; then
    PKG_MANAGER="macports"
  fi
}

# Run a `port` subcommand with the privileges MacPorts needs. MacPorts
# installs into a root-owned prefix (/opt/local), so install/uninstall
# normally require sudo. sudo prompts on the controlling terminal (not
# stdin), so this still works under `curl | bash` when a real terminal is
# attached; without one it fails fast instead of hanging.
_pkg_port() {
  if [ "$(id -u)" -eq 0 ]; then
    port "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo port "$@"
  else
    echo "Error: MacPorts needs administrator rights and 'sudo' is unavailable." >&2
    echo "  Run manually as root: port $*" >&2
    return 1
  fi
}

# True when <port> is already installed and active. Used to avoid taking
# ownership of a port the user already had, so the uninstaller never
# removes it.
_pkg_port_installed() {
  port installed "$1" 2>/dev/null | grep -q ' (active)'
}

# Actionable error: neither Homebrew nor MacPorts is available.
pkg_error_no_manager() {
  echo "Error: No supported package manager found (Homebrew or MacPorts)." >&2
  echo "  Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
  echo "  MacPorts: https://www.macports.org/install.php" >&2
}

# Actionable error: invalid <kind> argument (expected cli or font).
pkg_error_bad_kind() {
  echo "Error: $1: unknown kind '$2' (expected cli or font)." >&2
}

# --- Install-state tracking ------------------------------------------------
# Records exactly which MacPorts ports THIS installer installed, so the
# uninstaller never removes a port the user already had (e.g. a pre-existing
# dejavu-fonts). One line per owned port: "port:<portname>".
WEZCRAFT_STATE_DIR="${HOME}/.local/state/wezcraft"
WEZCRAFT_STATE_FILE="${WEZCRAFT_STATE_DIR}/installed-pkgs"

_pkg_state_add() {
  mkdir -p "$WEZCRAFT_STATE_DIR" 2>/dev/null || return 0
  printf '%s\n' "$1" >> "$WEZCRAFT_STATE_FILE" 2>/dev/null || return 0
  sort -u "$WEZCRAFT_STATE_FILE" -o "$WEZCRAFT_STATE_FILE" 2>/dev/null || true
  return 0
}

_pkg_state_has() {
  [ -f "$WEZCRAFT_STATE_FILE" ] && grep -Fxq "$1" "$WEZCRAFT_STATE_FILE" 2>/dev/null
}

_pkg_state_remove() {
  [ -f "$WEZCRAFT_STATE_FILE" ] || return 0
  if grep -Fxv "$1" "$WEZCRAFT_STATE_FILE" > "${WEZCRAFT_STATE_FILE}.tmp" 2>/dev/null; then
    mv "${WEZCRAFT_STATE_FILE}.tmp" "$WEZCRAFT_STATE_FILE" 2>/dev/null \
      || rm -f "${WEZCRAFT_STATE_FILE}.tmp"
  else
    : > "$WEZCRAFT_STATE_FILE" 2>/dev/null || true
    rm -f "${WEZCRAFT_STATE_FILE}.tmp"
  fi
  return 0
}

# --- MacPorts font helpers -------------------------------------------------
# MacPorts ships NO FiraCode Nerd Font port (verified 2026-09-30: `port
# search fira` finds nothing; its only Nerd Font port is the symbols-only
# ttf-nerd-fonts-symbols, and it has no ligature monospace fonts at all).
# So on MacPorts-only machines the font kind works in two stages:
#   1. PRIMARY — download the official FiraCode Nerd Font release ZIP from
#      the nerd-fonts GitHub repository and extract the .ttf files into
#      ~/Library/Fonts: full experience (icons AND ligatures), idempotent.
#   2. FALLBACK — if the download or unzip fails for ANY reason (offline,
#      HTTP error, missing curl/wget/unzip), install the symbols-only Nerd
#      Font plus DejaVu via MacPorts: status-bar icons and base text keep
#      working, ligatures are lost, and a yellow warning explains that.
# These helpers are internal: they never run on the Homebrew path and never
# recurse into pkg_install (which would re-run detect_pkg_manager and could
# loop). Bash 3.2 compatible, safe under `set -euo pipefail`.

# Pinned nerd-fonts release asset. The mutable "latest" URL is NOT used: a
# release whose bytes can change without notice cannot be verified, and
# integrity matters more than auto-updating here. The checksum comes from the
# same release's SHA-256.txt asset and was verified against the real download
# (28602426 bytes, 2026-10-02). Bump _PKG_FONT_VERSION and _PKG_FONT_SHA256
# together.
_PKG_FONT_VERSION="v3.5.1"
_PKG_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${_PKG_FONT_VERSION}/FiraCode.zip"
_PKG_FONT_SHA256="239395baf60c89b2eaf4862b6b09db0ef95605cd3e8eef51c00345822a81a665"

# _pkg_fetch <url> <dest> — download url to dest with curl (preferred) or
# wget as fallback; returns 1 when neither tool exists. Callers must invoke
# it inside an `if`/`||` context so a failing download degrades instead of
# aborting a `set -e` caller shell.
_pkg_fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    return 1
  fi
}

# _pkg_sha256 <file> — print the lowercase SHA-256 of <file> using the first
# available tool (macOS ships shasum and openssl). Returns 1 when none exist
# or the file cannot be read, so callers must treat empty output as failure.
_pkg_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    return 1
  fi
}

# _pkg_font_download_macports — PRIMARY path. Downloads the pinned
# FiraCode.zip release into a temp dir, verifies its SHA-256, unzips it, and
# copies every .ttf into ~/Library/Fonts. Idempotent: files already present
# are skipped, never overwritten or duplicated. Returns 0 only after
# verifying that at least one FiraCode Nerd Font .ttf is present in
# ~/Library/Fonts (freshly copied or pre-existing on a re-run); 1 on any
# failure so the caller can fall back to ports.
_pkg_font_download_macports() {
  local font_dir="${HOME}/Library/Fonts"
  local tmp_dir f base total rc=1 copied=0 actual old_trap

  command -v unzip >/dev/null 2>&1 || return 1
  tmp_dir="$(mktemp -d 2>/dev/null)" || return 1
  # Expand $tmp_dir NOW (double quotes, not single): the trap must clean
  # the exact directory even if the shell exits while these locals are
  # still in scope. Any EXIT trap the caller already had is saved first and
  # restored at the end, so this never clobbers it.
  old_trap="$(trap -p EXIT)"
  trap "rm -rf -- '$tmp_dir'" EXIT

  if _pkg_fetch "$_PKG_FONT_URL" "$tmp_dir/FiraCode.zip"; then
    actual="$(_pkg_sha256 "$tmp_dir/FiraCode.zip" 2>/dev/null || true)"
    if [ -z "$actual" ]; then
      echo "Warning: no sha256 tool (shasum/sha256sum/openssl) available; skipping font download." >&2
    elif [ "$actual" != "$_PKG_FONT_SHA256" ]; then
      echo "Warning: FiraCode.zip checksum mismatch — refusing to install." >&2
      echo "  expected: $_PKG_FONT_SHA256" >&2
      echo "  got:      $actual" >&2
    elif unzip -o -q "$tmp_dir/FiraCode.zip" -d "$tmp_dir" 2>/dev/null \
      && compgen -G "$tmp_dir/*.ttf" >/dev/null 2>&1
    then
      if mkdir -p "$font_dir" 2>/dev/null; then
        for f in "$tmp_dir"/*.ttf; do
          [ -f "$f" ] || continue               # glob matched nothing
          base="${f##*/}"
          if [ -e "$font_dir/$base" ]; then
            continue                            # already installed (idempotent)
          fi
          if cp "$f" "$font_dir/$base" 2>/dev/null; then
            copied=$((copied + 1))
          fi
        done
        # Verify a .ttf actually landed: count FiraCode Nerd Font files in
        # ~/Library/Fonts. On a re-run copied=0 but pre-existing files count,
        # which is exactly the idempotent success case.
        total=0
        for f in "$font_dir"/FiraCode*Nerd*.ttf; do
          [ -f "$f" ] || continue
          total=$((total + 1))
        done
        if [ "$total" -gt 0 ]; then
          rc=0
          echo -e "\033[0;32m✓ FiraCode Nerd Font installed → ${font_dir} (${total} .ttf, ${copied} new)\033[0m"
        fi
      fi
    fi
  fi

  rm -rf -- "$tmp_dir"
  # Restore the caller's EXIT trap (or clear ours when there was none).
  if [ -n "$old_trap" ]; then
    eval "$old_trap"
  else
    trap - EXIT
  fi
  return $rc
}

# _pkg_font_fallback_macports — FALLBACK path, reached only when the
# download failed: ttf-nerd-fonts-symbols keeps Nerd Font icons (status
# bar) working, dejavu-fonts provides a usable monospace base. A port the
# user already had is left untouched and NOT recorded as ours, so the
# uninstaller never removes it. Returns 1 if either install fails (caller
# turns that into a hard error).
_pkg_font_fallback_macports() {
  local rc=0 p
  for p in ttf-nerd-fonts-symbols dejavu-fonts; do
    if _pkg_port_installed "$p"; then
      continue                      # pre-existing: never take ownership
    fi
    if _pkg_port install "$p"; then
      _pkg_state_add "port:$p"      # we installed it -> we may remove it
    else
      rc=1
    fi
  done
  return $rc
}

# _pkg_font_macports — entry point for `pkg_install font` when
# PKG_MANAGER=macports (never reached when Homebrew is installed).
_pkg_font_macports() {
  if _pkg_font_download_macports; then
    return 0
  fi
  if ! _pkg_font_fallback_macports; then
    echo "Error: could not download FiraCode Nerd Font and MacPorts fallback installs failed." >&2
    echo "  Download URL: $_PKG_FONT_URL" >&2
    echo "  Manual fallback: https://www.nerdfonts.com/font-downloads" >&2
    return 1
  fi
  # Yellow warning matching the installer's color conventions
  # (YELLOW='\033[1;33m', NC='\033[0m' in the calling scripts).
  echo -e "\033[1;33m⚠ FiraCode Nerd Font could not be downloaded; symbols-only font installed instead — ligatures will be unavailable.\033[0m"
  echo -e "\033[1;33m  Manual fallback: https://www.nerdfonts.com/font-downloads\033[0m"
  return 0
}

# pkg_install <kind> <name> — install a package through the detected manager.
#   brew + cli      → brew install <name>
#   brew + font     → brew install --cask <name>
#   macports + cli  → sudo port install <name>
#   macports + font → download the pinned, SHA-256-verified FiraCode Nerd Font
#                     release into ~/Library/Fonts, degrading to MacPorts
#                     ports when offline (see _pkg_font_macports; the <name>
#                     cask is unused because MacPorts has no such port)
# Returns 1 (with an actionable error) when no manager is available.
pkg_install() {
  local kind="$1"
  local name="$2"
  detect_pkg_manager
  case "$PKG_MANAGER" in
    brew)
      case "$kind" in
        cli)  brew install "$name" ;;
        font) brew install --cask "$name" ;;
        *)    pkg_error_bad_kind pkg_install "$kind"; return 1 ;;
      esac
      ;;
    macports)
      case "$kind" in
        cli)
          _pkg_port install "$name" && _pkg_state_add "port:$name"
          ;;
        font)
          # MacPorts has no FiraCode Nerd Font port (verified 2026-09-30),
          # so we download the official nerd-fonts release manually and
          # degrade to ports when offline. See _pkg_font_macports.
          _pkg_font_macports
          ;;
        *)    pkg_error_bad_kind pkg_install "$kind"; return 1 ;;
      esac
      ;;
    "")
      pkg_error_no_manager
      return 1
      ;;
    *)
      echo "Error: pkg_install: unknown PKG_MANAGER '$PKG_MANAGER'." >&2
      return 1
      ;;
  esac
}

# pkg_uninstall <kind> <name> — same mapping with `brew uninstall [--cask]`
# / `sudo port uninstall`. Uninstall failures are ALWAYS tolerated (|| true),
# matching the existing uninstall scripts; only a missing package manager
# or an invalid kind returns 1 (call sites additionally guard with || true).
# The macports font kind is state-gated: it removes ONLY the ports this
# installer installed (see _pkg_state_*), never a pre-existing one.
pkg_uninstall() {
  local kind="$1"
  local name="$2"
  detect_pkg_manager
  case "$PKG_MANAGER" in
    brew)
      case "$kind" in
        cli)  brew uninstall "$name" || true ;;
        font) brew uninstall --cask "$name" || true ;;
        *)    pkg_error_bad_kind pkg_uninstall "$kind"; return 1 ;;
      esac
      ;;
    macports)
      case "$kind" in
        cli)  _pkg_port uninstall "$name" || true ;;
        # Font artifacts:
        #  1. Ports installed ONLY by the offline fallback path. Remove ONLY
        #     the ones this installer installed (recorded at install time):
        #     a pre-existing dejavu-fonts or ttf-nerd-fonts-symbols the user
        #     already had is never touched.
        #  2. The .ttf files we copied manually into ~/Library/Fonts on the
        #     download path. The glob is deliberately conservative
        #     (FiraCode*Nerd*.ttf): it matches exactly what this installer
        #     installs — FiraCodeNerdFont{,Mono,Propo}-*.ttf — and nothing
        #     else, so unrelated user fonts are never touched.
        font)
          local p
          for p in ttf-nerd-fonts-symbols dejavu-fonts; do
            if _pkg_state_has "port:$p"; then
              _pkg_port uninstall "$p" || true
              _pkg_state_remove "port:$p"
            fi
          done
          rm -f "${HOME}/Library/Fonts/"FiraCode*Nerd*.ttf
          ;;
        *)    pkg_error_bad_kind pkg_uninstall "$kind"; return 1 ;;
      esac
      ;;
    "")
      pkg_error_no_manager
      return 1
      ;;
    *)
      echo "Error: pkg_uninstall: unknown PKG_MANAGER '$PKG_MANAGER'." >&2
      return 1
      ;;
  esac
}
