# AGENTS.md

## What this repo is

Personal Omarchy (Arch Linux + Hyprland) config backup. Not a software project: no build, lint, or test suite. `install.sh` restores everything onto a machine. See `README.md` for what each config changes from stock Omarchy.

## Layout mirrors live config

Repo paths map to `$HOME` targets during restore:

- `hypr/*` → `~/.config/hypr/`
- `omarchy/*`, `voxtype/*`, `opencode/*` → `~/.config/<same dir>/`
- `agents/gemini/*` → `~/.gemini/config/`
- `agents/antigravity/*` → `~/.gemini/antigravity-cli/`
- `bin/*` → `~/.local/bin/`
- `systemd/user/*` → `~/.config/systemd/user/`

Adding new config requires a matching entry in `install.sh` — nothing is discovered automatically.

## Secrets

- This repository is **public**. Never commit real API keys, tokens, passwords, or private network details (such as home Wi-Fi SSIDs).
- `${GROQ_API_KEY}` and other `${VAR}` placeholders in `voxtype/config.toml` and `opencode/opencode.json` are intentional. Never replace them with real values or strip them.
- Never copy live `~/.config/voxtype/config.toml` or `~/.config/opencode/opencode.json` directly into this repo; edit the tracked templates or keep placeholders intact.
- Never run blind `git add -A` or `git add .`. Stage files by explicit path and review `git diff --staged` before every commit.
- Real keys live in `.local/secrets.env` (gitignored; template: `secrets.env.example`). `install.sh` sources it and substitutes only defined variables plus `${HOME}`.
- Keep the secret-blocking pre-commit hook active (`.githooks/pre-commit`, linked from `.git/hooks/pre-commit`).

## Gotchas

- Avoid hardcoded `/home/<user>` paths: use `${HOME}` in files restored with `subst` (such as `voxtype/config.toml`) or `$HOME` in shell-invoked commands (such as `agents/gemini/hooks.json`).

- `opencode/AGENTS.md` is a deployed artifact, not this repo's instruction file: `install.sh` copies it to `~/.config/opencode/AGENTS.md` as global agent rules on every machine. Edit it deliberately.
- `hypr/*.lua` use Omarchy's Lua config API (`hl.monitor()`, `hl.workspace_rule()`), not native `hyprland.conf` syntax.
- `hypr/bindings.lua` maps workspace keys to fixed monitors: `Super+1-5` to `DP-2` (LED), `Super+6-0` to `eDP-1` (laptop) workspaces 1-5. Omarchy 4.5 manages per-monitor workspace IDs; do not re-add `workspace_rule({ monitor = ... })` pinning, which conflicts with it. See `docs/workspaces.md`.
- `omarchy/plugins/soban.*` are omarchy-shell plugins: `manifest.json` declares the QML entry point; helper `.sh` files must stay executable.
- `install.sh` prompts before overwriting and saves timestamped `.pre-restore.*.bak` copies. Plugin directories merge via `cp -rn`, so existing installed manifests are not overwritten.

## Applying changes on a live system

- Hyprland settings need a reload to take effect.
- `install.sh` only enables `voxtype.service` if it doesn't exist yet. After changing `voxtype/config.toml`, restart manually: `systemctl --user restart voxtype`.

## Validation

No automated checks. Sanity-check shell edits with `bash -n` or shellcheck before committing.
