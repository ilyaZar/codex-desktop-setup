#!/bin/bash

set -euo pipefail

install_verify() {
  [[ -x /usr/bin/codex-desktop ]] &&
    [[ -x "$HOME/.local/share/mise/installs/codex/latest/bin/codex" ]] &&
    grep -Fq \
      "CODEX_CLI_PATH=$HOME/.local/share/mise/installs/codex/latest/bin/codex" \
      "$HOME/.local/share/applications/codex-desktop.desktop"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if install_verify; then
    exit 0
  fi
  exit 1
fi
