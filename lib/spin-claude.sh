#!/usr/bin/env bash
# spin-claude.sh — launch parallel Claude Code sessions in tmux

spin_claude() {
  local names=("$@")

  [[ ${#names[@]} -eq 0 ]] && spin_die "no window names provided"

  local session="${SPIN_SESSION_PREFIX}$(basename "$PWD")"

  # Detect whether the session already exists; we branch on this below to
  # decide between "create new session" and "append to existing session".
  local session_exists=false
  if tmux has-session -t "$session" 2>/dev/null; then
    session_exists=true
  fi

  # Fail-fast duplicate-name validation: if the session already exists,
  # reject the entire invocation before creating any windows when any
  # requested name collides with an existing window. Window names may have
  # been prefixed with a status icon by spin_status_daemon (e.g. "● foo"),
  # so we strip the icon to compare against the base name.
  if $session_exists; then
    local existing_windows
    existing_windows=$(tmux list-windows -t "$session" -F '#W' 2>/dev/null || true)

    local name existing_name base
    while IFS= read -r existing_name; do
      [[ -z "$existing_name" ]] && continue
      # Strip any leading status-icon prefix the daemon may have injected.
      # Icons come from ICON_* in spin-common.sh: ● ◉ ○ ◌
      base=$(echo "$existing_name" | sed 's/^[●◉○◌] //')
      for name in "${names[@]}"; do
        if [[ "$name" == "$base" ]]; then
          spin_die "window '$name' already exists in session '$session'"
        fi
      done
    done <<< "$existing_windows"
  fi

  # Create or append windows. On first-time creation the first name seeds
  # the session via new-session; subsequent names (and all names on the
  # append path) use new-window against the existing session.
  local first=true
  for name in "${names[@]}"; do
    if ! $session_exists && $first; then
      tmux new-session -d -s "$session" -n "$name"
      first=false
    else
      tmux new-window -t "$session" -n "$name"
    fi
    tmux send-keys -t "$session:$name" "claude --dangerously-skip-permissions --worktree $name" Enter
    echo "Started window '$name'"
  done

  # SPIN_CWD is already set on an existing session; only set it on first
  # creation to avoid a redundant tmux set-environment round-trip.
  if ! $session_exists; then
    tmux set-environment -t "$session" SPIN_CWD "$PWD"
  fi

  # Start background status daemon to inject state icons into tmux window
  # names — but only if one is not already running for this session. We
  # track the daemon's PID via a tmux session environment variable so we
  # can detect and respawn if the previous daemon died while the session
  # lived on. tmux show-environment prints "-SPIN_DAEMON_PID" when unset.
  local daemon_pid=""
  if $session_exists; then
    daemon_pid=$(tmux show-environment -t "$session" SPIN_DAEMON_PID 2>/dev/null | cut -d= -f2- || true)
    [[ "$daemon_pid" == -* ]] && daemon_pid=""
  fi
  if [[ -z "$daemon_pid" ]] || ! kill -0 "$daemon_pid" 2>/dev/null; then
    spin_status_daemon "$session" &
    local new_daemon_pid=$!
    disown
    tmux set-environment -t "$session" SPIN_DAEMON_PID "$new_daemon_pid"
  fi

  ghostty -e tmux attach -t "$session" 2>/dev/null &
  disown
}
