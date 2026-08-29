#!/bin/sh
# user hook: show the Antigravity conversation title in the Herdr top tab.
# Lives beside the herdr-managed hook and is registered under its own hooks.json
# key, so herdr integration reinstalls and uninstalls leave it alone.

set -eu

emit_and_exit() {
  printf '{}\n'
  exit 0
}

[ "${HERDR_ENV:-}" = "1" ] || emit_and_exit
[ -n "${HERDR_SOCKET_PATH:-}" ] || emit_and_exit
[ -n "${HERDR_TAB_ID:-}" ] || emit_and_exit
command -v python3 >/dev/null 2>&1 || emit_and_exit

python3 -c '
import json
import os
import socket
import sqlite3
import sys
import time

try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

if not isinstance(payload, dict):
    raise SystemExit(0)

conversation_id = payload.get("conversationId")
if not isinstance(conversation_id, str) or not conversation_id:
    raise SystemExit(0)

def title_from_db():
    db = os.path.expanduser("~/.gemini/antigravity-cli/conversation_summaries.db")
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        try:
            row = con.execute(
                "select title from conversation_summaries where conversation_id = ?",
                (conversation_id,),
            ).fetchone()
            if row and row[0] and row[0].strip():
                return row[0].strip()
        finally:
            con.close()
    except Exception:
        pass
    return None

title = title_from_db() or "Antigravity"
if title:
    title = " ".join(title.split())[:80]

seq = time.time_ns()

request = json.dumps({
    "id": f"user:antigravity-session-title:{seq}",
    "method": "tab.rename",
    "params": {
        "tab_id": os.environ["HERDR_TAB_ID"],
        "label": title,
    },
})
try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(0.5)
        client.connect(os.environ["HERDR_SOCKET_PATH"])
        client.sendall((request + "\n").encode())
        client.recv(4096)
except Exception:
    pass
' 2>/dev/null || true

emit_and_exit
