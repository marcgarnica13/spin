#!/usr/bin/env bash
# spin-claude.sh — launch parallel Claude Code sessions in tmux

# spin_generate_hooks_settings — resolves spin-hook.sh + the settings
# template (dev layout under $SPIN_ROOT/libexec, else installed layout
# under $SPIN_LIB), substitutes the real hook path into the template, and
# writes the result to ~/.cache/spin/hooks-settings.json. Echoes the
# settings file path on success. Non-fatal on failure: warns and returns 1
# so callers can fall back to launching without hooks (pane-scraping still
# works).
spin_generate_hooks_settings() {
  local hook_script=""
  local template=""

  if [[ -f "$SPIN_ROOT/libexec/spin-hook.sh" ]]; then
    hook_script="$SPIN_ROOT/libexec/spin-hook.sh"
  elif [[ -f "$SPIN_LIB/spin-hook.sh" ]]; then
    hook_script="$SPIN_LIB/spin-hook.sh"
  fi

  if [[ -f "$SPIN_ROOT/libexec/hooks-settings.json.tmpl" ]]; then
    template="$SPIN_ROOT/libexec/hooks-settings.json.tmpl"
  elif [[ -f "$SPIN_LIB/hooks-settings.json.tmpl" ]]; then
    template="$SPIN_LIB/hooks-settings.json.tmpl"
  fi

  if [[ -z "$hook_script" || -z "$template" ]]; then
    spin_warn "could not locate spin-hook.sh / hooks-settings.json.tmpl; launching without Claude Code hooks (falling back to pane-scraping state detection)"
    return 1
  fi

  chmod +x "$hook_script" 2>/dev/null || true

  mkdir -p "$HOME/.cache/spin/state"

  local settings_file="$HOME/.cache/spin/hooks-settings.json"
  local tmp_settings
  tmp_settings=$(mktemp "$HOME/.cache/spin/.hooks-settings.XXXXXX") || return 1

  sed "s#__SPIN_HOOK__#$hook_script#g" "$template" > "$tmp_settings"
  mv -f "$tmp_settings" "$settings_file"

  echo "$settings_file"
}

spin_claude() {
  local remote=true
  local args=()
  for arg in "$@"; do
    if [[ "$arg" == "--no-remote" ]]; then
      remote=false
    else
      args+=("$arg")
    fi
  done
  local names=("${args[@]}")

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

  # Generate the Claude Code hooks settings file once per invocation. This
  # is non-fatal on failure — launches continue without hooks, falling
  # back to pane-scraping state detection (see spin_generate_hooks_settings).
  local hooks_settings
  hooks_settings=$(spin_generate_hooks_settings) || true

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
    local claude_cmd="claude --dangerously-skip-permissions --worktree $name --name $name"
    $remote && claude_cmd+=" --remote-control $name"
    [[ -n "$hooks_settings" ]] && claude_cmd+=" --settings $hooks_settings"
    tmux send-keys -t "$session:$name" "$claude_cmd" Enter
    echo "Started window '$name'"

    # Seed an initial state file so freshly-launched windows show "working"
    # immediately, avoiding a gap before the first hook fires. Inlined
    # (rather than using spin_strip_icon/spin_state_file) since those
    # helpers don't exist yet at this point in the plan.
    local seed_dir="$HOME/.cache/spin/state/$session"
    mkdir -p "$seed_dir" 2>/dev/null || true
    local seed_now
    seed_now=$(date +%s)
    local seed_tmp
    seed_tmp=$(mktemp "$seed_dir/.tmp.XXXXXX" 2>/dev/null) || seed_tmp=""
    if [[ -n "$seed_tmp" ]]; then
      {
        printf '{\n'
        printf '  "state": "working",\n'
        printf '  "since": %d,\n' "$seed_now"
        printf '  "updated": %d,\n' "$seed_now"
        printf '  "session_id": "",\n'
        printf '  "last_message": ""\n'
        printf '}\n'
      } > "$seed_tmp" 2>/dev/null
      mv -f "$seed_tmp" "$seed_dir/$name.json" 2>/dev/null || rm -f "$seed_tmp" 2>/dev/null
    fi
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
