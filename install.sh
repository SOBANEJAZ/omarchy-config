#!/usr/bin/env bash
# Restore Omarchy Quattro personal config from this backup.
# Idempotent: prompts before overwriting an existing file, skips if identical.
set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:?}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ->\033[0m %s\n' "$*"; }

command -v omarchy >/dev/null 2>&1 || {
  echo "This does not look like an Omarchy system (omarchy command not found). Aborting." >&2
  exit 1
}

# --- Secrets -----------------------------------------------------------------
SECRETS="$BACKUP_DIR/.local/secrets.env"
if [[ -f $SECRETS ]]; then
  # shellcheck disable=SC1090
  set -a; source "$SECRETS"; set +a
  log "Secrets loaded from .local/secrets.env"
else
  warn "No .local/secrets.env found — placeholders will remain unsubstituted."
fi

substitute() { envsubst < "$1"; }

# file <src> <dest> [substitute]
install_file() {
  local src=$1 dest=$2 subst=${3:-}
  [[ -f $src ]] || { warn "missing in backup: $src (skipped)"; return; }
  mkdir -p "$(dirname "$dest")"
  if [[ -f $dest ]] && diff -q "$src" "$dest" >/dev/null 2>&1; then
    log "identical: $dest"
    return
  fi
  if [[ -f $dest ]]; then
    read -rp "Overwrite $dest with backup copy? [y/N] " a
    [[ $a == y ]] || { warn "skipped: $dest"; return; }
    cp "$dest" "$dest.pre-restore.$(date +%Y%m%d%H%M%S).bak"
  fi
  if [[ $subst == subst && -n ${GROQ_API_KEY:-}${CONTEXT7_API_KEY:-}${TAVILY_API_KEY:-}${SUPABASE_ACCESS_TOKEN:-} ]]; then
    substitute "$src" > "$dest"
  else
    cp "$src" "$dest"
  fi
  log "restored: $dest"
}

# --- Hyprland ----------------------------------------------------------------
for f in monitors.lua input.lua looknfeel.lua; do
  install_file "$BACKUP_DIR/hypr/$f" "$HOME_DIR/.config/hypr/$f"
done

# --- Omarchy shell + plugins ---------------------------------------------------
install_file "$BACKUP_DIR/omarchy/shell.toml" "$HOME_DIR/.config/omarchy/shell.toml"
install_file "$BACKUP_DIR/omarchy/shell.json" "$HOME_DIR/.config/omarchy/shell.json"
for p in soban.emojis soban.clipboard; do
  if [[ -d $HOME_DIR/.config/omarchy/plugins/$p ]]; then
    warn "plugin dir exists: $p — merging files without overwrite of manifest"
  fi
  mkdir -p "$HOME_DIR/.config/omarchy/plugins/$p"
  cp -rn "$BACKUP_DIR/omarchy/plugins/$p/." "$HOME_DIR/.config/omarchy/plugins/$p/" 2>/dev/null || true
  cp -f "$BACKUP_DIR"/omarchy/plugins/$p/*.sh "$HOME_DIR/.config/omarchy/plugins/$p/" 2>/dev/null || true
  chmod +x "$HOME_DIR"/.config/omarchy/plugins/$p/*.sh 2>/dev/null || true
  log "plugin synced: $p"
done

# --- Voxtype -----------------------------------------------------------------
install_file "$BACKUP_DIR/voxtype/config.toml" "$HOME_DIR/.config/voxtype/config.toml" subst
install_file "$BACKUP_DIR/voxtype/groq-cleanup.sh" "$HOME_DIR/.config/voxtype/groq-cleanup.sh"
chmod +x "$HOME_DIR/.config/voxtype/groq-cleanup.sh" 2>/dev/null || true

install_file "$BACKUP_DIR/bin/omarchy-voxtype-status" "$HOME_DIR/.local/bin/omarchy-voxtype-status"
chmod +x "$HOME_DIR/.local/bin/omarchy-voxtype-status" 2>/dev/null || true

if systemctl --user cat voxtype.service >/dev/null 2>&1; then
  log "voxtype.service already installed"
else
  install_file "$BACKUP_DIR/systemd/user/voxtype.service" "$HOME_DIR/.config/systemd/user/voxtype.service"
  systemctl --user daemon-reload
  systemctl --user enable --now voxtype.service && log "voxtype.service enabled and started"
fi

# --- opencode ------------------------------------------------------------------
install_file "$BACKUP_DIR/opencode/opencode.json" "$HOME_DIR/.config/opencode/opencode.json" subst
install_file "$BACKUP_DIR/opencode/AGENTS.md" "$HOME_DIR/.config/opencode/AGENTS.md"
[[ -f $BACKUP_DIR/opencode/tui.json ]] && install_file "$BACKUP_DIR/opencode/tui.json" "$HOME_DIR/.config/opencode/tui.json"
[[ -f $BACKUP_DIR/opencode/tui.jsonc ]] && install_file "$BACKUP_DIR/opencode/tui.jsonc" "$HOME_DIR/.config/opencode/tui.jsonc"
install_file "$BACKUP_DIR/opencode/herdr-opencode-session-title.js" "$HOME_DIR/.config/opencode/herdr-opencode-session-title.js"

# --- Gemini hooks ----------------------------------------------------------------
install_file "$BACKUP_DIR/agents/gemini/hooks.json" "$HOME_DIR/.gemini/config/hooks.json"
install_file "$BACKUP_DIR/agents/gemini/hooks/herdr-agent-session-title.sh" "$HOME_DIR/.gemini/config/hooks/herdr-agent-session-title.sh"
chmod +x "$HOME_DIR/.gemini/config/hooks/herdr-agent-session-title.sh" 2>/dev/null || true

# --- Shell aliases ----------------------------------------------------------------
if grep -q "alias settings=" "$HOME_DIR/.bashrc" 2>/dev/null; then
  log "bashrc aliases already present"
else
  warn "manual step: append shell/bashrc-aliases.snippet to ~/.bashrc"
fi

cat <<'EOF'

Manual steps not automated:
  1. opencode skills: reinstall per opencode/skills-manifest.txt
  2. Claude skill mirrors: copy shared skills into ~/.claude/skills/
  3. If secrets were missing, fill API keys into voxtype config + opencode MCP config now.
EOF
log "Restore complete. Reload Hyprland to apply monitor/input changes."
