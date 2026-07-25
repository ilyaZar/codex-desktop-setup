# Codex Desktop Setup

Build and install [Codex Desktop for Linux][linux-port] with the native product
name `Codex`. This keeps it distinct from the `ChatGPT` web app in the Omarchy
launcher.

The setup delegates to the upstream build and only supplies local policy:

- the generated runtime and native desktop entry are both named `Codex`
- the package updater is disabled so `workflow/setup_all.sh` owns updates
- generated rollback copies and package files are removed after installation
- the cached DMG and current `codex-app/` build remain available for reuse

The source checkout defaults to
`~/Dropbox/projects/openAI/codex-desktop-linux`. A missing checkout is cloned
from the [Linux port repository][linux-port].

## Install

```bash
./setup_codex_desktop.sh
```

The setup requires an interactive or cached `sudo` session when the generated
native package is installed.

Use a different source checkout when needed:

```bash
CODEX_DESKTOP_SOURCE_DIR=~/src/codex-desktop-linux \
  ./setup_codex_desktop.sh
```

`~/Dropbox/workflow/setup_all.sh` runs this setup by default. It can also be run
on its own:

```bash
~/Dropbox/workflow/setup_all.sh --only codex_desktop
```

## Cleanup

```bash
./cleanup_codex_desktop.sh
```

Cleanup removes only timestamped `codex-app.backup-*` directories and `dist/`
package output from the source checkout. It does not remove the installed
package, cached DMG, or current generated app.

[linux-port]: https://github.com/ilysenko/codex-desktop-linux

## Automation interface

The Codex Desktop build remains source-only. Catalog and TUI callers may use:

```bash
./setup_codex_desktop.sh --install-method source \
  --source-dir /path/to/codex-desktop-linux \
  --require-existing-source
./setup_codex_desktop.sh --check --source-dir /path/to/codex-desktop-linux
```

`--require-existing-source` prevents a selectively unsynced checkout from
being cloned during a TUI run.
