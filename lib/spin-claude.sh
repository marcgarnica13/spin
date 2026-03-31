#!/usr/bin/env bash
# spin-claude.sh — launch parallel Claude Code sessions in tmux

spin_claude() {
  local names=("$@")

  [[ ${#names[@]} -eq 0 ]] && spin_die "no window names provided"

  local session="${SPIN_SESSION_PREFIX}$(basename "$PWD")"

  if tmux has-session -t "$session" 2>/dev/null; then
    spin_warn "tmux session '$session' already exists, killing it"
    tmux kill-session -t "$session"
  fi

  local first=true
  for name in "${names[@]}"; do
    if $first; then
      tmux new-session -d -s "$session" -n "$name"
      first=false
    else
      tmux new-window -t "$session" -n "$name"
    fi
    tmux send-keys -t "$session:$name" "claude --dangerously-skip-permissions --worktree $name" Enter
    echo "Started window '$name'"
  done

  # Store the project directory for spin status
  tmux set-environment -t "$session" SPIN_CWD "$PWD"

  ghostty -e tmux attach -t "$session" &
  disown
}
