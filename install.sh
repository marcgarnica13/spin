#!/usr/bin/env bash
set -euo pipefail

# Standalone installer for spin
# Usage: curl -fsSL https://raw.githubusercontent.com/marcgarnica13/spin/main/install.sh | bash

REPO="https://github.com/marcgarnica13/spin.git"
PREFIX="${PREFIX:-/usr/local}"

main() {
  echo "Installing spin..."

  # Check dependencies
  for cmd in git tmux; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "error: $cmd is required but not installed" >&2
      exit 1
    fi
  done

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  git clone --depth 1 "$REPO" "$tmpdir" 2>/dev/null

  if [[ -w "$PREFIX/bin" ]]; then
    make -C "$tmpdir" PREFIX="$PREFIX" install
  else
    echo "Installing to $PREFIX requires sudo..."
    sudo make -C "$tmpdir" PREFIX="$PREFIX" install
  fi

  echo "Done! Run 'spin --help' to get started."
}

main
