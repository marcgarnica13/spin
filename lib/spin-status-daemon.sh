#!/usr/bin/env bash
# spin-status-daemon.sh — background poller that injects state icons into tmux window names

spin_status_daemon() {
  local session="$1"

  while tmux has-session -t "$session" 2>/dev/null; do
    local widx
    for widx in $(tmux list-windows -t "$session" -F '#{window_index}' 2>/dev/null); do
      local state
      state=$(detect_claude_state "$session" "$widx")
      local icon
      icon=$(state_to_icon_char "$state")

      local current_name
      current_name=$(tmux display-message -t "$session:$widx" -p '#{window_name}' 2>/dev/null) || continue

      # Strip any existing icon prefix (● ◉ ○ followed by space)
      local base_name
      base_name=$(echo "$current_name" | sed 's/^[●◉○] //')

      local new_name="$icon $base_name"
      if [[ "$new_name" != "$current_name" ]]; then
        tmux rename-window -t "$session:$widx" "$new_name" 2>/dev/null
      fi
    done
    sleep 5
  done
}
