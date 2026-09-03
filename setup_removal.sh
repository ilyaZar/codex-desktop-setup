#!/bin/bash

set -euo pipefail

install_remove() {
  local package
  package="$(pacman -Qo /usr/bin/codex-desktop 2>/dev/null | awk '{print $5}' || true)"
  if [[ "$package" == codex-desktop* ]]; then
    sudo pacman -Rns --noconfirm "$package"
  fi
  rm -f -- "$HOME/.local/share/applications/codex-desktop.desktop"
  printf '[ok] %s removed\n' 'Codex Desktop'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_remove "$@"
fi
