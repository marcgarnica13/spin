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

spin_die() {
  echo "${RED}error:${RESET} $*" >&2
  exit 1
}

spin_warn() {
  echo "${YELLOW}warning:${RESET} $*" >&2
}
