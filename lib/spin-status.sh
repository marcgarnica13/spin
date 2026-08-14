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

  # Step 2: State file (hook-written ground truth) takes priority. Only
  # fall back to pane-scraping when it's absent or empty (e.g. a session
  # launched by an older spin, or the hook hasn't fired yet).
  local window_name
  window_name=$(tmux display-message -t "$session:$widx" -p '#{window_name}' 2>/dev/null || true)
  if [[ -n "$window_name" ]]; then
    local stripped_name state_file file_state
    stripped_name=$(spin_strip_icon "$window_name")
    state_file=$(spin_state_file "$session" "$stripped_name")
    if [[ -f "$state_file" ]]; then
      file_state=$(spin_json_field "$state_file" "state")
      if [[ -n "$file_state" ]]; then
        echo "$file_state"
        return
      fi
    fi
  fi

  # Step 3: Capture pane content and analyze last visible lines
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

  # No pane-scraping pattern matched and no state file data was available —
  # default to working (same default used when pane content is empty).
  echo "working"
}

# spin_cleanup_stale_state <session> — removes state files for windows that
# no longer exist in the given tmux session (e.g. a window was closed).
# Not yet wired into any caller.
spin_cleanup_stale_state() {
  local session="$1"
  local dir
  dir="$(spin_state_dir)/$session"
  [[ -d "$dir" ]] || return 0

  local -A live
  local wname
  while IFS= read -r wname; do
    [[ -z "$wname" ]] && continue
    live["$(spin_strip_icon "$wname")"]=1
  done < <(tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null || true)

  local file base
  for file in "$dir"/*.json; do
    [[ -e "$file" ]] || continue
    base="$(basename "$file" .json)"
    if [[ -z "${live[$base]+x}" ]]; then
      rm -f "$file"
    fi
  done
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

      # since / last_message from the hook-written state file, when present
      local now
      now=$(date +%s)
      local stripped_wname state_file
      stripped_wname=$(spin_strip_icon "$wname")
      state_file=$(spin_state_file "$session" "$stripped_wname")

      local since last_message
      since="$now"
      last_message=""
      if [[ -f "$state_file" ]]; then
        local file_since
        file_since=$(spin_json_field "$state_file" "since")
        [[ -n "$file_since" ]] && since="$file_since"
        last_message=$(spin_json_field "$state_file" "last_message")
      fi
      local elapsed_seconds=$(( now - since ))

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
      printf '    "since": %d,\n' "$since"
      printf '    "elapsed_seconds": %d,\n' "$elapsed_seconds"
      printf '    "last_message": "%s"\n' "$(spin_json_escape "$last_message")"
      printf '  }'
    done <<< "$windows"

  done <<< "$sessions"

  printf '\n]\n'
}

spin_status() {
  local once=false
  local json_output=false

  for arg in "$@"; do
    case "$arg" in
      --once) once=true ;;
      --json) json_output=true ;;
      *) spin_die "unknown option: $arg" ;;
    esac
  done

  if $json_output; then
    spin_status_json
    return
  fi

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
