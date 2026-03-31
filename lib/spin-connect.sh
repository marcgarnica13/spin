#!/usr/bin/env bash
# spin-connect.sh — reconnect to existing spin sessions in a new Ghostty window

spin_connect() {
  local target="${1:-}"

  # Step 1: enumerate all spin sessions
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${SPIN_SESSION_PREFIX}" || true)

  # CONN-04 / D-10: no sessions
  if [[ -z "$sessions" ]]; then
    echo "No active spin sessions. Launch one with: spin claude <name1> [name2] ..."
    return 0
  fi

  # Step 2: if a target was given, normalize it (D-06)
  if [[ -n "$target" ]]; then
    # add prefix if user provided bare name
    if [[ ! "$target" =~ ^${SPIN_SESSION_PREFIX} ]]; then
      target="${SPIN_SESSION_PREFIX}${target}"
    fi

    # CONN-03 / D-07 / D-11: validate session exists
    if ! tmux has-session -t "$target" 2>/dev/null; then
      echo "${RED}error:${RESET} session '${target}' not found" >&2
      echo "" >&2
      echo "Available sessions:" >&2
      while IFS= read -r session; do
        local display_name="${session#"${SPIN_SESSION_PREFIX}"}"
        echo "  ${CYAN}${display_name}${RESET}" >&2
      done <<< "$sessions"
      return 1
    fi

    # Attach to named session — CONN-03 / CONN-05 / D-08 / D-09
    ghostty -e tmux attach -t "$target" 2>/dev/null &
    disown
    return 0
  fi

  # Step 3: no target given — count sessions
  local session_count
  session_count=$(echo "$sessions" | wc -l)

  # D-02: exactly one session → auto-connect
  if [[ "$session_count" -eq 1 ]]; then
    local only_session
    only_session=$(echo "$sessions" | head -1)
    ghostty -e tmux attach -t "$only_session" 2>/dev/null &
    disown
    return 0
  fi

  # D-01 / CONN-02 / D-04 / D-05: multiple sessions → list them
  echo "${BOLD}spin sessions${RESET}"
  echo ""
  while IFS= read -r session; do
    local display_name="${session#"${SPIN_SESSION_PREFIX}"}"

    local project_dir
    project_dir=$(tmux show-environment -t "$session" SPIN_CWD 2>/dev/null | cut -d= -f2- || true)
    if [[ -z "$project_dir" || "$project_dir" == "-SPIN_CWD" ]]; then
      project_dir=$(tmux display-message -t "$session:0.0" -p '#{pane_current_path}' 2>/dev/null || echo "unknown")
    fi
    project_dir="${project_dir/#$HOME/~}"

    local windows
    windows=$(tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null)
    local window_count
    window_count=$(echo "$windows" | wc -l)

    echo "  ${BOLD}${CYAN}${display_name}${RESET}  ${DIM}${project_dir}${RESET}  ${DIM}${window_count} window(s)${RESET}"
  done <<< "$sessions"

  echo ""
  echo "Run ${BOLD}spin connect <session>${RESET} to attach."
  return 0
}
