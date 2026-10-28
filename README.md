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
- herdr integration for agent session tracking

### Gemini CLI hooks (`agents/gemini/`)
herdr hooks report agent state.

### Shell aliases (`shell/bashrc-aliases.snippet`)
`settings`, `rust`, `zed`, and Wi-Fi hotspot control aliases for `.bashrc`.

### Wi-Fi hotspot (`bin/omarchy-hotspot`, `shell/bashrc-aliases.snippet`)
Shares Ethernet internet over `wlan0` through NetworkManager's `ipv4.method=shared` AP mode. `omarchy-hotspot` backs six `.bashrc` aliases:
- `hotspot-setup <ssid> <password>` — installs `dnsmasq`, opens UFW rules on `wlan0`, and creates the `Hotspot` profile
- `hotspot-on` / `hotspot-off` — unblocks the Wi-Fi radio and starts or stops the AP
- `hotspot-new-name <ssid>` — renames the broadcast SSID and reloads if active
- `hotspot-new-pin <password>` — updates the 8–63 character WPA2 passphrase and reloads if active
- `hotspot-status` — prints active state, terminal QR code, and connected clients

Hardware and firewall fixes built into `omarchy-hotspot`:
- Installs the `dnsmasq` package without enabling `dnsmasq.service`, letting NetworkManager spawn a scoped DHCP/DNS instance on `10.42.0.1` alongside `systemd-resolved`
- Opens UFW `67/udp` (DHCP), `53` (DNS), and `ufw route allow in on wlan0` (`FORWARD` + `DOCKER-USER`)
- Clears Dell platform `rfkill` (`dell-wifi` → `phy0`) and polls until `wlan0` leaves `unavailable` before activating AP mode
- Pins 2.4 GHz (`band bg`) to bypass Intel AX201 (`iwlwifi`) 5 GHz LAR `No-IR` blocks, using WPA2-CCMP (`proto rsn`, `ccmp`, `pmf 1`)
- Disables WPS beacon advertisement (`wps-method 1` / `wps_disabled=1`) so Windows 10/11 clients ask for the Wi-Fi password instead of an 8-digit router WPS PIN

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
