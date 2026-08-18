#!/usr/bin/env bash
# spin-status.sh — monitor active spin sessions

spin_status_once() {
  spin_cleanup_orphaned_sessions
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${SPIN_SESSION_PREFIX}" || true)

  if [[ -z "$sessions" ]]; then
    echo "${DIM}No active spin sessions.${RESET}"
    return 0
  fi

  local now
  now=$(date +%s)

  # Detection pass: call detect_claude_state exactly once per window, and
  # cache state/since/last_message for reuse by both the NEEDS YOU block
  # and the tree below.
  local -A row_state row_since row_msg row_has_state
  local attention=()

  while IFS= read -r session; do
    spin_cleanup_stale_state "$session"

    local windows
    windows=$(tmux list-windows -t "$session" -F '#{window_name}:#{window_index}' 2>/dev/null)

    while IFS=: read -r wname widx; do
      [[ -z "$wname" ]] && continue
      local key="$session:$widx"

      local state
      state=$(detect_claude_state "$session" "$widx")
      row_state["$key"]="$state"

      local stripped_wname state_file since msg has_state
      stripped_wname=$(spin_strip_icon "$wname")
      state_file=$(spin_state_file "$session" "$stripped_wname")
      since="$now"
      msg=""
      has_state=false
      if [[ -f "$state_file" ]]; then
        has_state=true
        local file_since
        file_since=$(spin_json_field "$state_file" "since")
        [[ -n "$file_since" ]] && since="$file_since"
        msg=$(spin_json_field "$state_file" "last_message")
      fi
      row_since["$key"]="$since"
      row_msg["$key"]="$msg"
      row_has_state["$key"]="$has_state"

      if [[ "$state" == "waiting" || "$state" == "permission" ]]; then
        attention+=("$key|$session|$wname")
      fi
    done <<< "$windows"
  done <<< "$sessions"

  # NEEDS YOU pass: attention rows (waiting/permission) first, above the tree.
  if [[ ${#attention[@]} -gt 0 ]]; then
    echo " ${BOLD}▌ NEEDS YOU${RESET}"

    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local avail=$(( cols - 30 ))
    [[ $avail -lt 20 ]] && avail=20

    local entry
    for entry in "${attention[@]}"; do
      local key ent_session rest ent_wname
      key="${entry%%|*}"
      rest="${entry#*|}"
      ent_session="${rest%%|*}"
      ent_wname="${rest#*|}"
      ent_wname=$(spin_strip_icon "$ent_wname")

      local state icon label
      state="${row_state[$key]}"
      if [[ "$state" == "permission" ]]; then
        icon="$ICON_PERMISSION"
        label="${RED}${BOLD}needs permission${RESET}"
      else
        icon="$ICON_WAITING"
        label="${GREEN}${BOLD}waiting for input${RESET}"
      fi

      local elapsed=""
      if [[ "${row_has_state[$key]}" == "true" ]]; then
        elapsed=$(spin_humanize_duration $(( now - row_since[$key] )))
      fi

      local msg="${row_msg[$key]}"
      if [[ -n "$elapsed" && -n "$msg" ]]; then
        printf ' %s %s:%s  %s  %s  %s%s%s\n' "$icon" "$ent_session" "$ent_wname" "$label" "$elapsed" "$DIM" "${msg:0:avail}" "$RESET"
      elif [[ -n "$elapsed" ]]; then
        printf ' %s %s:%s  %s  %s\n' "$icon" "$ent_session" "$ent_wname" "$label" "$elapsed"
      elif [[ -n "$msg" ]]; then
        printf ' %s %s:%s  %s  %s%s%s\n' "$icon" "$ent_session" "$ent_wname" "$label" "$DIM" "${msg:0:avail}" "$RESET"
      else
        printf ' %s %s:%s  %s\n' "$icon" "$ent_session" "$ent_wname" "$label"
      fi
    done

    echo ""
  fi

  # Tree pass: same structure/output as before, but reuses cached state.
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

      local key="$session:$widx"
      local state="${row_state[$key]}"

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
        auto)
          icon="$ICON_AUTO"
          label="${YELLOW}${DIM}auto — will resume${RESET}"
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

      local elapsed=""
      if [[ "${row_has_state[$key]}" == "true" ]]; then
        elapsed=$(spin_humanize_duration $(( now - row_since[$key] )))
      fi

      local display_wname
      display_wname=$(spin_strip_icon "$wname")
      if [[ -n "$elapsed" ]]; then
        printf " %s %-12s %s %s  %s%s%s\n" "$connector" "$display_wname" "$icon" "$label" "$DIM" "$elapsed" "$RESET"
      else
        printf " %s %-12s %s %s\n" "$connector" "$display_wname" "$icon" "$label"
      fi
    done <<< "$windows"

    echo ""
  done <<< "$sessions"

  # Legend
  echo " ${ICON_WORKING} working  ${ICON_WAITING} needs input  ${ICON_PERMISSION} needs permission  ${ICON_AUTO} auto — will resume  ${ICON_IDLE} idle  ${ICON_EXITED} exited"
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

  # Step 2: Capture pane content once, early — raised to -S -15 so the
  # footer/status-bar line (spinner summary, "esc to interrupt") is
  # reliably included. Used both to cross-check a state file (Step 2b)
  # and as the pane-scraping fallback (Step 3) when no state file exists.
  local pane_content
  pane_content=$(tmux capture-pane -p -t "$session:$widx.0" -S -15 2>/dev/null || true)

  local active_run=false
  local auto_resume=false
  if [[ -n "$pane_content" ]]; then
    if echo "$pane_content" | grep -qF 'esc to interrupt'; then
      active_run=true
    fi
    if echo "$pane_content" | grep -qP '\d+\s+(shell|monitor|task|agent)s?\s+still running'; then
      auto_resume=true
    fi
  fi

  # Step 2b: State file (hook-written ground truth) takes priority, but is
  # reconciled against live pane evidence rather than trusted blindly — the
  # hook layer has no event for "permission answered" or a background-task
  # notification silently re-invoking Claude, so the file can go stale.
  local window_name
  window_name=$(tmux display-message -t "$session:$widx" -p '#{window_name}' 2>/dev/null || true)
  if [[ -n "$window_name" ]]; then
    local stripped_name state_file file_state
    stripped_name=$(spin_strip_icon "$window_name")
    state_file=$(spin_state_file "$session" "$stripped_name")
    if [[ -f "$state_file" ]]; then
      file_state=$(spin_json_field "$state_file" "state")
      if [[ -n "$file_state" ]]; then
        if $active_run; then
          echo "working"
          return
        fi
        if [[ "$file_state" == "waiting" ]] && $auto_resume; then
          echo "auto"
          return
        fi
        echo "$file_state"
        return
      fi
    fi
  fi

  # Step 3: No state file — pane-scraping fallback. Same two live-evidence
  # checks apply first, then the existing last-lines heuristics.
  if $active_run; then
    echo "working"
    return
  fi

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
    if $auto_resume; then
      echo "auto"
    else
      echo "waiting"
    fi
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

# spin_cleanup_orphaned_sessions — removes state directories for tmux
# sessions that no longer exist at all. Complements spin_cleanup_stale_state,
# which only prunes individual windows within a still-live session; this
# handles the case where the entire session was killed and its state
# directory would otherwise linger forever under the state root.
spin_cleanup_orphaned_sessions() {
  local root
  root="$(spin_state_dir)"
  [[ -d "$root" ]] || return 0

  local dir session_dir
  for dir in "$root"/*/; do
    [[ -d "$dir" ]] || continue
    session_dir="$(basename "$dir")"
    if ! tmux has-session -t "$session_dir" 2>/dev/null; then
      rm -rf -- "$dir"
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
  spin_cleanup_orphaned_sessions
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

      local since last_message elapsed_seconds
      if [[ -f "$state_file" ]]; then
        since="$now"
        local file_since
        file_since=$(spin_json_field "$state_file" "since")
        [[ -n "$file_since" ]] && since="$file_since"
        last_message=$(spin_json_field "$state_file" "last_message")
        elapsed_seconds=$(( now - since ))
      else
        since=0
        last_message=""
        elapsed_seconds=-1
      fi

      if $first_session; then
        first_session=false
      else
        printf ',\n'
      fi

      printf '  {\n'
      printf '    "name": "%s",\n' "$(spin_json_escape "$session")"
      printf '    "window": "%s",\n' "$(spin_json_escape "$stripped_wname")"
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
