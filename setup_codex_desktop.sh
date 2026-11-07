#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
ok() { printf '%b[ok]%b %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b[warn]%b %s\n' "$YELLOW" "$NC" "$*"; }
error() { printf '%b[error]%b %s\n' "$RED" "$NC" "$*" >&2; }
info() { printf '%b[info]%b %s\n' "$CYAN" "$NC" "$*"; }

CHECK_ONLY=0
REPAIR_LAUNCHER=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --repair-launcher) REPAIR_LAUNCHER=1; shift ;;
    --install-method)
      [[ "${2:-}" == package ]] || { error 'Only package installation is supported'; exit 2; }
      shift 2 ;;
    -h|--help)
      printf 'Usage: %s [--check] [--repair-launcher] [--install-method package]\n' "$0"
      exit 0 ;;
    *) error "Unknown option: $1"; exit 2 ;;
  esac
done

info "Source: $SCRIPT_DIR/mise-plugin"
info 'Target: Mise codex-desktop (official OpenAI Linux package)'
for command_name in mise python3 curl gpgv bsdtar ldd; do
  command -v "$command_name" >/dev/null || { error "Missing: $command_name"; exit 1; }
done
[[ "$(uname -s)" == Linux ]] || { error 'Linux is required'; exit 1; }
[[ "$CHECK_ONLY" == 0 ]] || { ok 'Prerequisites available'; exit 0; }

plugin_path="${MISE_DATA_DIR:-$HOME/.local/share/mise}/plugins/codex-desktop"
if [[ -e "$plugin_path" || -L "$plugin_path" ]]; then
  [[ "$(readlink -f "$plugin_path")" == "$SCRIPT_DIR/mise-plugin" ]] || {
    error "Unmanaged Mise plugin already exists: $plugin_path"; exit 1;
  }
else
  mise plugins link codex-desktop "$SCRIPT_DIR/mise-plugin"
fi
if [[ "$REPAIR_LAUNCHER" == 0 ]]; then
  mise use --global codex-desktop@latest
fi
app_root="$(mise where codex-desktop)"
[[ -x "$app_root/bin/chatgpt" && -f "$app_root/official-package.txt" ]] || {
  error 'Official Mise installation is missing'; exit 1;
}

# Resolve the active Mise version at launch so upgrades keep this entry valid.
launcher="$HOME/.local/bin/codex-desktop"
mkdir -p "$(dirname "$launcher")" "$HOME/.local/share/applications"
if [[ -e "$launcher" ]] && ! grep -Fq '# Managed by codex-desktop-setup' "$launcher"; then
  error "Unmanaged launcher exists: $launcher"; exit 1
fi
cat > "$launcher" <<LAUNCHER
#!/bin/bash
# Managed by codex-desktop-setup
set -euo pipefail
exec "$(command -v mise)" -C "\$HOME" exec -- chatgpt "\$@"
LAUNCHER
chmod 0755 "$launcher"
desktop="$HOME/.local/share/applications/codex-desktop.desktop"
if [[ -e "$desktop" ]] && ! grep -Fq 'X-Workflow-Managed=codex-desktop-setup' "$desktop"; then
  error "Unmanaged desktop entry exists: $desktop"; exit 1
fi
icon="$app_root/usr/share/pixmaps/chatgpt.png"
[[ -f "$icon" ]] || { error 'Package icon is missing'; exit 1; }
mkdir -p "$HOME/.local/share/icons"
cp "$icon" "$HOME/.local/share/icons/codex-official.png"
cat > "$desktop" <<DESKTOP
[Desktop Entry]
Name=Codex
Comment=Official OpenAI desktop app
Exec="$launcher" %U
Icon=$HOME/.local/share/icons/codex-official.png
Type=Application
StartupNotify=true
Categories=Utility;Development;
MimeType=x-scheme-handler/codex;
X-Workflow-Managed=codex-desktop-setup
DESKTOP
if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$desktop"
fi
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$HOME/.local/share/applications"
fi
ok 'Official desktop installed through Mise; conversations and settings preserved'
info "Verify: $SCRIPT_DIR/setup_installation_management.sh"
