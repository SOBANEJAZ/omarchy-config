#!/bin/bash

set -euo pipefail

emoji="${1:-}"
[[ -n $emoji ]] || exit 0

# Copy to the clipboard without --paste-once: the clipboard history watcher
# (wl-paste --watch) would consume the single offer and clear the clipboard
# before the target app pastes. The clipboard stays owned until the next copy.
printf '%s' "$emoji" | wl-copy --type text/plain --sensitive

sleep 0.15

is_terminal=false
if hyprctl activewindow -j 2>/dev/null | jq -e '
  any(.tags[]?; sub("\\*$"; "") == "terminal")
' >/dev/null; then
  is_terminal=true
fi

if [[ $is_terminal == true ]]; then
  paste_mods="SHIFT"
  paste_key="Insert"
else
  paste_mods="CTRL"
  paste_key="V"
fi

send_key_state() {
  local state="$1"
  local code="hl.dispatch(hl.dsp.send_key_state({ mods = \"$paste_mods\", key = \"$paste_key\", state = \"$state\" }))"
  hyprctl eval "$code" >/dev/null 2>&1
}

# Explicit key states reach normal application surfaces more consistently than
# a virtual keyboard, especially in browser text inputs.
if ! send_key_state down || ! sleep 0.05 || ! send_key_state up; then
  if [[ $is_terminal == true ]]; then
    wtype -M shift -d 100 -k Insert -d 100 -m shift 2>/dev/null || true
  else
    wtype -M ctrl -d 100 -k v -d 100 -m ctrl 2>/dev/null || true
  fi
fi
