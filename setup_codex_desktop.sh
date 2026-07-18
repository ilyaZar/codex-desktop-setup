#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok() {
  echo -e "${GREEN}[ok]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[warn]${NC} $1"
}

error() {
  echo -e "${RED}[error]${NC} $1" >&2
}

info() {
  echo -e "${CYAN}[info]${NC} $1"
}

SOURCE_DIR="${CODEX_DESKTOP_SOURCE_DIR:-$HOME/Dropbox/projects/openAI/codex-desktop-linux}"
SOURCE_URL="${CODEX_DESKTOP_SOURCE_URL:-https://github.com/ilysenko/codex-desktop-linux.git}"
SOURCE_BRANCH="${CODEX_DESKTOP_SOURCE_BRANCH:-main}"
BUILD_THREADS="${CODEX_DESKTOP_BUILD_THREADS:-0}"
USER_DESKTOP_FILE="$HOME/.local/share/applications/codex-desktop.desktop"
SYSTEM_DESKTOP_FILE="/usr/share/applications/codex-desktop.desktop"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    error "Missing required command: $command_name"
    exit 1
  fi
}

update_source() {
  if [[ ! -e "$SOURCE_DIR" ]]; then
    info "Cloning Codex Desktop for Linux"
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --branch "$SOURCE_BRANCH" --single-branch "$SOURCE_URL" "$SOURCE_DIR"
  fi

  if [[ ! -d "$SOURCE_DIR/.git" && ! -f "$SOURCE_DIR/.git" ]]; then
    error "Source is not a Git checkout: $SOURCE_DIR"
    exit 1
  fi

  if [[ ! -f "$SOURCE_DIR/install.sh" || ! -f "$SOURCE_DIR/Makefile" ]]; then
    error "Source checkout does not contain the native installer: $SOURCE_DIR"
    exit 1
  fi

  if [[ "$(git -C "$SOURCE_DIR" branch --show-current)" != "$SOURCE_BRANCH" ]]; then
    error "Source must be on branch '$SOURCE_BRANCH': $SOURCE_DIR"
    exit 1
  fi

  if [[ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]]; then
    error "Source checkout has uncommitted changes: $SOURCE_DIR"
    error "Commit or stash them before running this setup"
    exit 1
  fi

  info "Updating Codex Desktop source"
  git -C "$SOURCE_DIR" fetch --prune origin "$SOURCE_BRANCH"
  git -C "$SOURCE_DIR" merge --ff-only "origin/$SOURCE_BRANCH"
}

remove_user_shadow() {
  if [[ ! -f "$USER_DESKTOP_FILE" ]]; then
    return
  fi

  if grep -Fq '/usr/bin/codex-desktop' "$USER_DESKTOP_FILE" &&
      grep -Fq 'Icon=codex-desktop' "$USER_DESKTOP_FILE"; then
    rm "$USER_DESKTOP_FILE"
    ok "Removed stale user-local package launcher"
  else
    warn "Skipped unmanaged desktop entry: $USER_DESKTOP_FILE"
  fi
}

verify_install() {
  if [[ ! -x /usr/bin/codex-desktop ]]; then
    error "Native launcher was not installed: /usr/bin/codex-desktop"
    exit 1
  fi

  if [[ ! -f "$SYSTEM_DESKTOP_FILE" ]] ||
      ! grep -Fxq 'Name=Codex' "$SYSTEM_DESKTOP_FILE"; then
    error "Installed desktop entry is not named Codex"
    exit 1
  fi

  if ! jq -e '.appIdentity.displayName == "Codex"' \
      /opt/codex-desktop/.codex-linux/build-info.json >/dev/null; then
    error "Installed runtime is not named Codex"
    exit 1
  fi
}

echo ""
echo -e "${CYAN}=== Codex Desktop Setup ===${NC}"
echo "Source: $SOURCE_DIR ($SOURCE_BRANCH)"
echo "Name:   Codex"
echo ""

require_command git
require_command jq
require_command make
require_command makepkg
require_command pacman

update_source
"$SCRIPT_DIR/cleanup_codex_desktop.sh"

info "Building and installing the native Codex package"
CODEX_APP_DISPLAY_NAME=Codex \
  PACKAGE_DISPLAY_NAME=Codex \
  PACKAGE_COMMENT='Run Codex Desktop on Linux' \
  PACKAGE_WITH_UPDATER=0 \
  MAX_BUILD_THREADS="$BUILD_THREADS" \
  make -C "$SOURCE_DIR" install-native

verify_install
remove_user_shadow
"$SCRIPT_DIR/cleanup_codex_desktop.sh"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" \
    >/dev/null 2>&1 || true
fi
if command -v omarchy-restart-walker >/dev/null 2>&1; then
  omarchy-restart-walker
fi

ok "Installed Codex Desktop"
warn "Restart the running desktop app once to refresh its window title"
