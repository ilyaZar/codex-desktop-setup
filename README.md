# Codex Desktop Setup

Install the official OpenAI Linux desktop app through Mise. Keep the launcher
named `Codex` so it remains distinct from the existing ChatGPT web app.
The setup lives in `codex-desktop-setup/`; there is no `codex-setup/` directory.

## Install and update

```bash
workflow run --install codex_desktop
```

Or run `./setup_codex_desktop.sh` directly. The setup links `mise-plugin/` as
`codex-desktop`, selects its latest published version globally, and installs a
user launcher. The existing Mise `codex` tool remains the independent CLI.

```bash
mise upgrade codex-desktop
./setup_codex_desktop.sh --repair-launcher
./setup_installation_management.sh
```

The local plugin uses Mise's shell plugin interface because its HTTP backend
does not unpack Debian packages. It fetches OpenAI's signed `InRelease`, verifies
it with the repository key shipped in OpenAI's official package, then checks
the package index and download against their SHA256 values. The key fingerprint
is `3BFA0E4AE8B8CC16A2D9BA684A3B4A566C4660E4`.

Only versions currently listed in the signed repository can be newly installed.
Existing Mise versions remain available until explicitly removed. Package
downloads and extraction staging are temporary and are removed after each run.
The plugin extracts the official payload without running Debian package hooks.
Mise owns app updates; no apt repository is added to Arch.

Prerequisites: Linux x64 or ARM64, Mise, Python 3.11 or newer, curl, gpgv,
bsdtar, and the desktop libraries required by the app. Installation checks the
main executable's shared libraries. `--check` validates installer prerequisites.
Arch/Omarchy is not formally supported by OpenAI's Linux preview.

## User data and removal

The official app uses the existing `~/.config/Codex` profile and `~/.codex`
conversation/configuration data. Setup and removal never delete those paths.
Close the desktop app before running `workflow run --remove codex_desktop`.
The source checkout of the former community port is not removed by this setup.

The September 2026 migration backup is under
`/home-hdd-cold/iz/BACKUPS/apps/codex-chat-archives/optiplex/` in the dated
`2026-09-06-official-app-migration/` directory. See its migration notes before
restoring a profile or database over newer data.

[Official Linux documentation](https://learn.chatgpt.com/docs/linux/linux-app)
