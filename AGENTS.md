# Codex Desktop Setup Rules

## Scope

- Build and install Codex Desktop from the trusted Linux source checkout.
- Keep display naming and generated-output cleanup in this workflow overlay.
- Do not patch generated files in `codex-app/` or copy upstream build logic.
- Keep the packaged updater disabled; `workflow/setup_all.sh` owns updates.

## Conventions

- Keep scripts idempotent and use `#!/bin/bash` with `set -euo pipefail`.
- Prefer environment overrides exposed by the upstream build.
- Restrict cleanup to generated Codex Desktop paths.
- Keep human-maintained Markdown wrapped at 80 columns.
