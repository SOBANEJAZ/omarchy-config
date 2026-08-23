# omarchy-config

Personal config for Omarchy Quattro (Arch Linux + Hyprland) on a laptop with an external monitor. This readme lists the major changes from stock Omarchy and how to restore them on a fresh machine.

## Major changes

### Dual-monitor layout (`hypr/monitors.lua`)
External 2560x1440 monitor (DP-2) sits left of the laptop screen (eDP-1). Workspaces 1–5 live on the external monitor, 6–10 on the laptop screen.

### Input tuning (`hypr/input.lua`)
- Mouse sensitivity 1.7 with flat (no acceleration) profile
- Keyboard repeat rate 40 / delay 600 ms
- Touchpad: natural scroll, scroll factor 0.5, clickfinger right-click, drag lock
- Three-finger horizontal swipe switches workspaces

### Look and feel (`hypr/looknfeel.lua`)
Tighter window gaps: 2 px inside and out.

### Bar (`omarchy/shell.toml`, `omarchy/shell.json`)
Bar height 28, base font size 16, custom clock formats.

### Custom omarchy-shell plugins (`omarchy/plugins/`)
- **soban.emojis** — emoji picker with search
- **soban.clipboard** — clipboard history panel, includes a migration script for older history files

### Voice dictation pipeline (`voxtype/`, `systemd/user/voxtype.service`)
Voxtype records on a hotkey and transcribes with whisper-large-v3 through the Groq remote API. A post-processing script (`voxtype/groq-cleanup.sh`) cleans the transcript with an LLM before typing it at the cursor. A systemd user service runs the daemon, and `bin/omarchy-voxtype-status` reports state in the bar.

Notable fix shipped here: `groq-cleanup.sh` flattens newlines and tabs before output. Without it, whisper's segment-boundary `\n` characters reached the keyboard layer and pressed Enter mid-sentence during dictation.

### opencode setup (`opencode/`)
- MCP servers: chrome-devtools, context7, tavily, supabase
- Notification plugin and global AGENTS.md rules
- herdr integration that syncs session titles

### Gemini CLI hooks (`agents/gemini/`)
herdr hooks report agent state and session titles.

### Shell aliases (`shell/bashrc-aliases.snippet`)
`settings`, `rust`, and `zed` aliases for `.bashrc`.

## Restore

On a fresh Omarchy machine:

```bash
git clone https://github.com/SOBANEJAZ/omarchy-config.git
cd omarchy-config
cp secrets.env.example .local/secrets.env   # then fill in your keys
./install.sh
```

The script restores files, substitutes secrets from `.local/secrets.env`, installs and starts the voxtype user service, and prompts before overwriting anything that already exists. It reports manual steps at the end (opencode skills, Claude skill mirrors).

## Secrets

API keys are never committed. Configs carry `${VAR}` placeholders in `voxtype/config.toml` and `opencode/opencode.json`. Real values live in `.local/secrets.env`, which `.gitignore` excludes.
