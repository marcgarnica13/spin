#!/usr/bin/env bash
# spin-common.sh — shared constants and utilities for spin

SPIN_VERSION="0.1.0"
SPIN_SESSION_PREFIX="spin-"

# Colors (disabled when not a terminal)
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED="" GREEN="" YELLOW="" CYAN="" BOLD="" DIM="" RESET=""
fi

# Status icons
ICON_WORKING="${YELLOW}●${RESET}"
ICON_WAITING="${GREEN}${BOLD}◉${RESET}"
ICON_PERMISSION="${RED}${BOLD}◉${RESET}"
ICON_EXITED="${DIM}○${RESET}"
ICON_IDLE="${CYAN}${DIM}◌${RESET}"

# Tree drawing
TREE_BRANCH="├─"
TREE_LAST="└─"
TREE_PIPE="│"

state_to_icon_char() {
  case "$1" in
    working)    echo "●" ;;
    waiting)    echo "◉" ;;
    permission) echo "◉" ;;
    idle)       echo "○" ;;
    exited)     echo "○" ;;
    *)          echo "○" ;;
  esac
}

# spin_strip_icon <name> — echoes <name> with a leading status-icon prefix
# (injected by spin_status_daemon) stripped. Single source of truth for
# icon-prefix stripping, shared by spin-claude.sh, the daemon, and
# spin-status.sh.
spin_strip_icon() {
  printf '%s' "$1" | sed -E 's/^[●◉○◌] //'
}

# spin_state_dir — the root directory under which per-window state files
# (written by libexec/spin-hook.sh) live.
spin_state_dir() {
  printf '%s/.cache/spin/state' "$HOME"
}

# spin_state_file <session> <window> — the canonical per-window state-file
# path. <window> must already be icon-stripped.
spin_state_file() {
  printf '%s/%s/%s.json' "$(spin_state_dir)" "$1" "$2"
}

# spin_json_field <file> <field> — best-effort single-field extractor for
# the simple flat JSON written by libexec/spin-hook.sh. Tries a
# quoted-string match first, then falls back to a bare-number match. Every
# stage guarded so a missing field returns empty rather than aborting the
# caller under set -e.
spin_json_field() {
  local file="$1"
  local field="$2"
  local value
  value=$(grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || true)
  if [[ -z "$value" ]]; then
    value=$(grep -o "\"$field\"[[:space:]]*:[[:space:]]*[0-9]*" "$file" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//' || true)
  fi
  printf '%s' "$value"
}

spin_die() {
  echo "${RED}error:${RESET} $*" >&2
  exit 1
}

spin_warn() {
  echo "${YELLOW}warning:${RESET} $*" >&2
}
