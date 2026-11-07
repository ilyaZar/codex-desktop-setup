#!/bin/bash
set -euo pipefail

install_remove() {
  local launcher="$HOME/.local/bin/codex-desktop"
  local desktop="$HOME/.local/share/applications/codex-desktop.desktop"
  if pgrep -u "$UID" -f '/mise/installs/codex-desktop/[^ ]*/usr/lib/chatgpt/ChatGPT' >/dev/null; then
    printf '[error] Close the official desktop app before removing its runtime\n' >&2
    return 1
  fi
  mise unuse --global codex-desktop
  mise uninstall --all codex-desktop
  if [[ -f "$launcher" ]] && grep -Fq '# Managed by codex-desktop-setup' "$launcher"; then
    rm -- "$launcher"
  fi
  if [[ -f "$desktop" ]] && grep -Fq 'X-Workflow-Managed=codex-desktop-setup' "$desktop"; then
    rm -- "$desktop" "$HOME/.local/share/icons/codex-official.png"
  fi
  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$HOME/.local/share/applications"
  fi
  printf '[ok] Official desktop removed; all user data and the CLI preserved\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_remove "$@"
fi
