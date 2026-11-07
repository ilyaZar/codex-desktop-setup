#!/bin/bash
set -euo pipefail

install_verify() {
  local app_root
  app_root="$(mise where codex-desktop 2>/dev/null)" || return 1
  [[ -x "$app_root/bin/chatgpt" && -f "$app_root/official-package.txt" ]] &&
    [[ -x "$HOME/.local/bin/codex-desktop" ]] &&
    grep -Fq '# Managed by codex-desktop-setup' "$HOME/.local/bin/codex-desktop" &&
    grep -Fq 'Comment=Official OpenAI desktop app' \
      "$HOME/.local/share/applications/codex-desktop.desktop" &&
    ! pacman -Q codex-desktop >/dev/null 2>&1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_verify
fi
