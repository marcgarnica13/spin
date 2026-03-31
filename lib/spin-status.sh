#!/usr/bin/env bash
# spin-status.sh — monitor active spin sessions

spin_status_once() {
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${SPIN_SESSION_PREFIX}" || true)

  if [[ -z "$sessions" ]]; then
    echo "${DIM}No active spin sessions.${RESET}"
    return 0
  fi

  local session_count=0
  while IFS= read -r session; do
    session_count=$((session_count + 1))

    # Get project directory
    local project_dir
    project_dir=$(tmux show-environment -t "$session" SPIN_CWD 2>/dev/null | cut -d= -f2- || true)
    if [[ -z "$project_dir" || "$project_dir" == "-SPIN_CWD" ]]; then
      # Fallback: get cwd from pane 0
      project_dir=$(tmux display-message -t "$session:0.0" -p '#{pane_current_path}' 2>/dev/null || echo "unknown")
    fi
    # Shorten home prefix
    project_dir="${project_dir/#$HOME/~}"

    echo " ${BOLD}${CYAN}${session}${RESET}  ${DIM}${project_dir}${RESET}"

    # Get windows
    local windows
    windows=$(tmux list-windows -t "$session" -F '#{window_name}:#{window_index}' 2>/dev/null)
    local window_count
    window_count=$(echo "$windows" | wc -l)
    local current=0

    while IFS=: read -r wname widx; do
      current=$((current + 1))
      local connector="$TREE_BRANCH"
      [[ $current -eq $window_count ]] && connector="$TREE_LAST"

      local state
      state=$(detect_claude_state "$session" "$widx")

      local icon label
      case "$state" in
        waiting)
          icon="$ICON_WAITING"
          label="${GREEN}${BOLD}waiting for input${RESET}"
          ;;
        permission)
          icon="$ICON_PERMISSION"
          label="${RED}${BOLD}needs permission${RESET}"
          ;;
        idle)
          icon="$ICON_IDLE"
          label="${CYAN}${DIM}idle${RESET}"
          ;;
        exited)
          icon="$ICON_EXITED"
          label="${DIM}exited${RESET}"
          ;;
        *)
          icon="$ICON_WORKING"
          label="${YELLOW}working${RESET}"
          ;;
      esac

      printf " %s %-12s %s %s\n" "$connector" "$wname" "$icon" "$label"
    done <<< "$windows"

    echo ""
  done <<< "$sessions"

  # Legend
  echo " ${ICON_WORKING} working  ${ICON_WAITING} needs input  ${ICON_PERMISSION} needs permission  ${ICON_IDLE} idle  ${ICON_EXITED} exited"
}

detect_claude_state() {
  local session="$1"
  local widx="$2"

  # Step 1: Check if Claude process is still running in pane 0
  local pane_pid
  pane_pid=$(tmux list-panes -t "$session:$widx" -F '#{pane_pid}' 2>/dev/null | head -1)

  if [[ -n "$pane_pid" ]]; then
    local has_claude=false
    # Walk the process tree: shell -> claude -> node
    local all_pids="$pane_pid"
    local children
    children=$(pgrep -P "$pane_pid" 2>/dev/null || true)
    for pid in $children; do
      all_pids="$all_pids $pid"
      local grandchildren
      grandchildren=$(pgrep -P "$pid" 2>/dev/null || true)
      for gpid in $grandchildren; do
        all_pids="$all_pids $gpid"
      done
    done

    for pid in $all_pids; do
      local cmdline
      cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || true)
      if [[ "$cmdline" == *claude* ]]; then
        has_claude=true
        break
      fi
    done

    if ! $has_claude; then
      echo "exited"
      return
    fi
  fi

  # Step 2: Capture pane content and analyze last visible lines
  local pane_content
  pane_content=$(tmux capture-pane -p -t "$session:$widx.0" -S -10 2>/dev/null || true)

  if [[ -z "$pane_content" ]]; then
    echo "working"
    return
  fi

  # Get last non-empty lines (guard against grep returning 1 on no match)
  local last_lines
  last_lines=$(echo "$pane_content" | grep -v '^$' | tail -5 || true)

  if [[ -z "$last_lines" ]]; then
    echo "working"
    return
  fi

  # Claude Code's input prompt: a line that is just ">" (possibly with ANSI escapes stripped)
  if echo "$last_lines" | grep -qE '^\s*>\s*$'; then
    echo "waiting"
    return
  fi

  # Claude Code's interactive selection menu (AskUserQuestion)
  if echo "$last_lines" | grep -qF 'Esc to cancel'; then
    echo "waiting"
    return
  fi

  # Claude Code's plan approval or selection arrow (❯ followed by digit)
  if echo "$last_lines" | grep -qP '\x{276F}\s*\d'; then
    echo "waiting"
    return
  fi

  # Permission prompt: Claude shows "Allow" / "Deny" choices or "Yes" / "No" on the same line
  # Be specific to avoid matching tool output that mentions these words in normal text
  if echo "$last_lines" | grep -qE '(Allow once|Allow always|Deny|Yes.*No.*\?)'; then
    echo "permission"
    return
  fi

  # Claude Code actively streaming: spinner characters (✻✢✳✶⏺) in recent output
  # Only match spinners in the last few lines to avoid matching historical output
  if echo "$last_lines" | grep -qP '[\x{2720}-\x{2767}\x{23FA}]'; then
    echo "working"
    return
  fi

  # Idle detection: compare pane content hash across polls (D-01, D-02, D-03)
  # State is persisted in tmux environment per session:window to survive across CLI invocations
  local content_hash
  content_hash=$(echo "$pane_content" | md5sum | cut -d' ' -f1)

  local last_hash
  last_hash=$(tmux show-environment -t "$session" "SPIN_LAST_CONTENT_${session}_${widx}" 2>/dev/null | cut -d= -f2- || true)

  local unchanged_polls
  unchanged_polls=$(tmux show-environment -t "$session" "SPIN_IDLE_POLLS_${session}_${widx}" 2>/dev/null | cut -d= -f2- || echo 0)

  if [[ "$content_hash" != "$last_hash" ]]; then
    unchanged_polls=0
  else
    unchanged_polls=$((unchanged_polls + 1))
  fi

  tmux set-environment -t "$session" "SPIN_LAST_CONTENT_${session}_${widx}" "$content_hash"
  tmux set-environment -t "$session" "SPIN_IDLE_POLLS_${session}_${widx}" "$unchanged_polls"

  # Threshold: 3 consecutive polls with unchanged content = ~60s at 20s interval (D-04, D-05)
  if [[ $unchanged_polls -ge 3 ]]; then
    echo "idle"
    return
  fi

  echo "working"
}

spin_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslash must be first
  s="${s//\"/\\\"}"    # double quote
  s="${s//$'\n'/\\n}"  # newline
  s="${s//$'\r'/\\r}"  # carriage return
  s="${s//$'\t'/\\t}"  # tab
  printf '%s' "$s"
}

spin_status_json() {
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${SPIN_SESSION_PREFIX}" || true)

  if [[ -z "$sessions" ]]; then
    echo "[]"
    return 0
  fi

  local first_session=true
  printf '[\n'

  while IFS= read -r session; do
    # Get windows for this session
    local windows
    windows=$(tmux list-windows -t "$session" -F '#{window_name}:#{window_index}' 2>/dev/null)

    while IFS=: read -r wname widx; do
      # State — bare string, no icons or color codes
      local state
      state=$(detect_claude_state "$session" "$widx")

      # PID of the Claude pane
      local pane_pid
      pane_pid=$(tmux list-panes -t "$session:$widx" -F '#{pane_pid}' 2>/dev/null | head -1)
      pane_pid=$((pane_pid + 0))  # ensure numeric, 0 if empty

      # Idle duration (raw poll count; 1 poll ≈ 20s)
      local unchanged_polls
      unchanged_polls=$(tmux show-environment -t "$session" "SPIN_IDLE_POLLS_${session}_${widx}" 2>/dev/null | cut -d= -f2- || echo 0)
      # Handle the case where tmux returns "-VARNAME" when the variable is unset
      if [[ "$unchanged_polls" == -* ]]; then
        unchanged_polls=0
      fi
      unchanged_polls=$((unchanged_polls + 0))  # ensure numeric

      if $first_session; then
        first_session=false
      else
        printf ',\n'
      fi

      printf '  {\n'
      printf '    "name": "%s",\n' "$(spin_json_escape "$session")"
      printf '    "window": "%s",\n' "$(spin_json_escape "$wname")"
      printf '    "state": "%s",\n' "$(spin_json_escape "$state")"
      printf '    "pid": %d,\n' "$pane_pid"
      printf '    "idle_duration": %d\n' "$unchanged_polls"
      printf '  }'
    done <<< "$windows"

  done <<< "$sessions"

  printf '\n]\n'
}

spin_status() {
  local once=false

  for arg in "$@"; do
    case "$arg" in
      --once) once=true ;;
      *) spin_die "unknown option: $arg" ;;
    esac
  done

  if $once; then
    spin_status_once
    return
  fi

  # Auto-refresh mode
  trap 'tput cnorm 2>/dev/null || true; exit 0' INT TERM
  tput civis 2>/dev/null || true  # hide cursor

  while true; do
    clear
    echo "${BOLD}spin status${RESET} ${DIM}(refreshing every 20s — press Ctrl-C to exit)${RESET}"
    echo ""
    spin_status_once
    sleep 20
  done
}
