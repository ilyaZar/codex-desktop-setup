#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok() {
  echo -e "${GREEN}[ok]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[warn]${NC} $1"
}

SOURCE_DIR="${CODEX_DESKTOP_SOURCE_DIR:-$HOME/Dropbox/projects/openAI/codex-desktop-linux}"

echo ""
echo -e "${CYAN}=== Clean Codex Desktop Build Output ===${NC}"
echo "Source: $SOURCE_DIR"
echo ""

if [[ ! -d "$SOURCE_DIR" ]]; then
  warn "Source checkout is absent"
  exit 0
fi

removed_backups=0
while IFS= read -r -d '' backup; do
  name="$(basename "$backup")"
  if [[ ! "$name" =~ ^codex-app\.backup-[0-9]{14}(-[0-9]+)?$ ]]; then
    warn "Skipped unrecognized backup path: $backup"
    continue
  fi

  rm -rf -- "$backup"
  ok "Removed generated rollback copy: $backup"
  removed_backups=$((removed_backups + 1))
done < <(
  find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d \
    -name 'codex-app.backup-*' -print0
)

if [[ $removed_backups -eq 0 ]]; then
  ok "No generated rollback copies found"
fi

if [[ -d "$SOURCE_DIR/dist" ]]; then
  rm -rf -- "$SOURCE_DIR/dist"
  ok "Removed generated native packages: $SOURCE_DIR/dist"
else
  ok "No generated native packages found"
fi
