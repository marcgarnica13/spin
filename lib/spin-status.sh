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
    project_dir=$(tmux show-environment -t "$session" SPIN_CWD 2>/dev/null | cut -d= -f2-)
    if [[ -z "$project_dir" || "$project_dir" == "-SPIN_CWD" ]]; then
      # Fallback: get cwd from pane 1 (the shell pane)
      project_dir=$(tmux display-message -t "$session:0.1" -p '#{pane_current_path}' 2>/dev/null || echo "unknown")
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
  echo " ${ICON_WORKING} working  ${ICON_WAITING} needs input  ${ICON_PERMISSION} needs permission  ${ICON_EXITED} exited"
}

detect_claude_state() {
  local session="$1"
  local widx="$2"

  # Step 1: Check if Claude process is still running in pane 0
  local pane_pid
  pane_pid=$(tmux list-panes -t "$session:$widx" -F '#{pane_pid}' 2>/dev/null | head -1)

  if [[ -n "$pane_pid" ]]; then
    local has_claude=false
    # Check the pane's foreground process and its children
    local children
    children=$(pgrep -P "$pane_pid" 2>/dev/null || true)
    for pid in $pane_pid $children; do
      local cmdline
      cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || true)
      if [[ "$cmdline" == *claude* || "$cmdline" == *node* ]]; then
        has_claude=true
        break
      fi
      # Also check grandchildren (claude spawns node)
      local grandchildren
      grandchildren=$(pgrep -P "$pid" 2>/dev/null || true)
      for gpid in $grandchildren; do
        cmdline=$(cat "/proc/$gpid/cmdline" 2>/dev/null | tr '\0' ' ' || true)
        if [[ "$cmdline" == *claude* || "$cmdline" == *node* ]]; then
          has_claude=true
          break 2
        fi
      done
    done

    if ! $has_claude; then
      echo "exited"
      return
    fi
  fi

  # Step 2: Capture pane content and analyze
  local pane_content
  pane_content=$(tmux capture-pane -p -t "$session:$widx.0" -S -10 2>/dev/null || true)

  if [[ -z "$pane_content" ]]; then
    echo "working"
    return
  fi

  # Check for Claude's input prompt — the last non-empty line contains just ">"
  local last_lines
  last_lines=$(echo "$pane_content" | grep -v '^$' | tail -3)

  # Claude's prompt is a ">" character (possibly with ANSI codes stripped by capture-pane)
  if echo "$last_lines" | grep -qE '^\s*>\s*$'; then
    echo "waiting"
    return
  fi

  # Check for permission prompt patterns
  if echo "$last_lines" | grep -qiE '(Allow|Deny|yes.*no|approve|permission|Do you want)'; then
    echo "permission"
    return
  fi

  echo "working"
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
  trap 'tput cnorm 2>/dev/null; exit 0' INT TERM
  tput civis 2>/dev/null  # hide cursor

  while true; do
    clear
    echo "${BOLD}spin status${RESET} ${DIM}(refreshing every 2s — press Ctrl-C to exit)${RESET}"
    echo ""
    spin_status_once
    sleep 2
  done
}
