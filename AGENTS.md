# Codex Desktop Setup Rules

- Install the official OpenAI Linux package with the local Mise plugin.
- Keep the desktop tool `codex-desktop` separate from the `codex` CLI.
- Verify signed repository metadata and package SHA256 before extraction.
- Preserve `~/.codex`, `~/.config/Codex`, credentials, and all backups.
- Do not rebuild the community macOS port or patch the official app payload.
- Keep the launcher named Codex to distinguish the ChatGPT web app.
- Do not uninstall runtimes still referenced by live sessions.
- Keep Bash scripts idempotent and human-maintained Markdown wrapped at 80.
