#!/usr/bin/env bash
# spin-hook.sh — Claude Code hook receiver.
#
# Invoked directly by Claude Code (via --settings hooks) as:
#   spin-hook.sh <event>
# where <event> is one of: prompt_submit | stop | notification_permission |
# notification_idle | session_end.
#
# This script is self-contained (not sourced by spin) — do NOT source
# spin-common.sh here, its path differs between dev and installed layouts
# and isn't guaranteed to sit next to this script.
#
# Writes the current state for the calling tmux window atomically to:
#   ~/.cache/spin/state/<session>/<window>.json
#
# Intentionally no `-e`: a partial failure here (e.g. transcript parsing)
# must never abort the state write or return a non-zero exit that could
# affect Claude Code's own control flow.
set -uo pipefail

STATE_ROOT="$HOME/.cache/spin/state"

event="${1:-}"

state=""
case "$event" in
  prompt_submit)           state="working" ;;
  stop)                    state="waiting" ;;
  notification_permission) state="permission" ;;
  notification_idle)       state="waiting" ;;
  session_end)              state="exited" ;;
  *) exit 0 ;;
esac

input=$(cat)

# Session wasn't launched inside tmux by spin — nothing to do.
[[ -z "${TMUX_PANE:-}" ]] && exit 0

# --- local helpers (duplicated, not sourced) ---

_strip_icon() {
  printf '%s' "$1" | sed -E 's/^[●◉○◌] //'
}

_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslash must be first
  s="${s//\"/\\\"}"    # double quote
  s="${s//$'\n'/\\n}"  # newline
  s="${s//$'\r'/\\r}"  # carriage return
  s="${s//$'\t'/\\t}"  # tab
  printf '%s' "$s"
}

# Resolve identity: which session:window is this hook firing in?
identity=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_name}' 2>/dev/null || true)
[[ -z "$identity" ]] && exit 0

session="${identity%%:*}"
window_raw="${identity#*:}"
[[ -z "$session" || -z "$window_raw" || "$window_raw" == "$identity" ]] && exit 0

window=$(_strip_icon "$window_raw")
[[ -z "$window" ]] && exit 0

session_id=$(printf '%s' "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || true)

last_message=""
if [[ "$event" == "stop" ]]; then
  transcript_path=$(printf '%s' "$input" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || true)
  if [[ -n "$transcript_path" ]]; then
    last_assistant_line=$(tac "$transcript_path" 2>/dev/null | grep -m1 '"role"[[:space:]]*:[[:space:]]*"assistant"' || true)
    if [[ -n "$last_assistant_line" ]]; then
      raw_text=$(printf '%s' "$last_assistant_line" | grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || true)
      if [[ -n "$raw_text" ]]; then
        raw_text="${raw_text//\\n/ }"
        raw_text="${raw_text//\\\"/\"}"
        last_message="${raw_text:0:200}"
      fi
    fi
  fi
fi

state_dir="$STATE_ROOT/$session"
state_file="$state_dir/$window.json"

now=$(date +%s)
since="$now"
if [[ -f "$state_file" ]]; then
  prev_state=$(grep -o '"state"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || true)
  prev_since=$(grep -o '"since"[[:space:]]*:[[:space:]]*[0-9]*' "$state_file" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//' || true)
  if [[ "$prev_state" == "$state" && -n "$prev_since" ]]; then
    since="$prev_since"
  fi
fi

mkdir -p "$state_dir" 2>/dev/null || exit 0

tmp_file=$(mktemp "$state_dir/.tmp.XXXXXX" 2>/dev/null) || exit 0

{
  printf '{\n'
  printf '  "state": "%s",\n' "$(_json_escape "$state")"
  printf '  "since": %d,\n' "$since"
  printf '  "updated": %d,\n' "$now"
  printf '  "session_id": "%s",\n' "$(_json_escape "$session_id")"
  printf '  "last_message": "%s"\n' "$(_json_escape "$last_message")"
  printf '}\n'
} > "$tmp_file" 2>/dev/null

mv -f "$tmp_file" "$state_file" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null

exit 0
