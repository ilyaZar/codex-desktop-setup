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
CODEX_CLI_PATH="${CODEX_DESKTOP_CLI_PATH:-$HOME/.local/share/mise/installs/codex/latest/bin/codex}"
INSTALL_METHOD="source"
REQUIRE_EXISTING_SOURCE=0
CHECK_ONLY=0
REPAIR_LAUNCHER=0

usage() {
  cat <<'EOF'
Usage: ./setup_codex_desktop.sh [options]

Options:
  --install-method source   build from the Codex Desktop source checkout
  --source-dir <path>       override the source checkout
  --require-existing-source
                            fail instead of cloning a missing checkout
  --repair-launcher         restore the managed launcher without rebuilding
  --check                   verify prerequisites without changing anything
  -h, --help                show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-method)
      [[ $# -ge 2 ]] || { error "--install-method requires a value"; exit 2; }
      INSTALL_METHOD="$2"
      shift 2
      ;;
    --source-dir)
      [[ $# -ge 2 ]] || { error "--source-dir requires a path"; exit 2; }
      SOURCE_DIR="$2"
      shift 2
      ;;
    --require-existing-source)
      REQUIRE_EXISTING_SOURCE=1
      shift
      ;;
    --repair-launcher)
      REPAIR_LAUNCHER=1
      shift
      ;;
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ "$INSTALL_METHOD" != "source" ]]; then
  error "Codex Desktop supports only --install-method source"
  exit 2
fi

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    error "Missing required command: $command_name"
    exit 1
  fi
}

update_source() {
  if [[ ! -e "$SOURCE_DIR" ]]; then
    if [[ "$REQUIRE_EXISTING_SOURCE" -eq 1 ]]; then
      error "Required source checkout is missing: $SOURCE_DIR"
      exit 1
    fi
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

verify_launcher_inputs() {
  if [[ ! -x /usr/bin/codex-desktop ]]; then
    error "Native launcher was not installed: /usr/bin/codex-desktop"
    exit 1
  fi

  if [[ ! -r "$SYSTEM_DESKTOP_FILE" ]]; then
    error "System desktop entry is missing: $SYSTEM_DESKTOP_FILE"
    exit 1
  fi

  if [[ ! -x "$CODEX_CLI_PATH" ]]; then
    error "Codex CLI is missing or not executable: $CODEX_CLI_PATH"
    exit 1
  fi
}

install_user_launcher() {
  local desktop_dir
  local tmp

  if [[ -f "$USER_DESKTOP_FILE" ]] &&
      ! grep -Fq 'X-Workflow-Managed=codex-desktop-setup' \
        "$USER_DESKTOP_FILE"; then
    warn "Skipped unmanaged desktop entry: $USER_DESKTOP_FILE"
    return 1
  fi

  desktop_dir="$(dirname "$USER_DESKTOP_FILE")"
  mkdir -p "$desktop_dir"
  tmp="$(mktemp --suffix=.desktop "$desktop_dir/.codex-desktop.XXXXXX")"

  awk -v cli="$CODEX_CLI_PATH" '
    /^\[Desktop Action / && !managed {
      print "X-Workflow-Managed=codex-desktop-setup"
      print ""
      managed = 1
    }
    /^Exec=env / {
      print "Exec=env CODEX_CLI_PATH=" cli " " substr($0, 10)
      next
    }
    { print }
    END {
      if (!managed) {
        print "X-Workflow-Managed=codex-desktop-setup"
      }
    }
  ' "$SYSTEM_DESKTOP_FILE" >"$tmp"

  chmod 0644 "$tmp"
  if command -v desktop-file-validate >/dev/null 2>&1; then
    if ! desktop-file-validate "$tmp"; then
      rm -f "$tmp"
      error "Generated desktop entry is invalid"
      exit 1
    fi
  fi
  mv "$tmp" "$USER_DESKTOP_FILE"

  ok "Pinned Codex Desktop CLI: $CODEX_CLI_PATH"
}

refresh_desktop_launcher() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" \
      >/dev/null 2>&1 || true
  fi
}

verify_install() {
  verify_launcher_inputs

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

if [[ "$REPAIR_LAUNCHER" -eq 1 ]]; then
  verify_launcher_inputs
  install_user_launcher
  refresh_desktop_launcher
  ok "Repaired Codex Desktop launcher"
  exit 0
fi

require_command git
require_command jq
require_command make
require_command makepkg
require_command pacman

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if [[ ! -d "$SOURCE_DIR/.git" && ! -f "$SOURCE_DIR/.git" ]]; then
    error "Source is not a Git checkout: $SOURCE_DIR"
    exit 1
  fi
  for marker in install.sh Makefile; do
    if [[ ! -r "$SOURCE_DIR/$marker" ]]; then
      error "Source marker is missing or unreadable: $SOURCE_DIR/$marker"
      exit 1
    fi
  done
  ok "Codex Desktop source prerequisites are available"
  exit 0
fi

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
install_user_launcher
"$SCRIPT_DIR/cleanup_codex_desktop.sh"

refresh_desktop_launcher

ok "Installed Codex Desktop"
warn "Restart the running desktop app once to refresh its window title"
