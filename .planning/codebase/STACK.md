# Technology Stack

**Analysis Date:** 2026-03-30

## Languages

**Primary:**
- Bash 4+ - All executable scripts and library modules

**Secondary:**
- None

## Runtime

**Environment:**
- POSIX-compatible Unix shell (bash 4 or later)
- No external language runtimes required

**Package Manager:**
- None (pure system dependencies)
- Lockfile: Not applicable

## Frameworks

**Core:**
- None (standalone bash scripts)

**Testing:**
- Not implemented

**Build/Dev:**
- GNU Make - Installation and uninstallation via `Makefile`

## Key Dependencies

**Critical:**
- tmux 3+ - Terminal multiplexer for session management (`lib/spin-claude.sh`)
- git - Version control and worktree operations (implicit via Claude Code usage)
- bash 4+ - Shell interpreter with bash-specific features like arrays

**System Tools:**
- ghostty - Terminal emulator for launching tmux sessions (`lib/spin-claude.sh` line 33)
- claude - Claude Code CLI tool (external dependency, invoked via `lib/spin-claude.sh` line 24)

## Configuration

**Environment:**
- Configured via command-line arguments and tmux environment variables
- Session prefix: `SPIN_SESSION_PREFIX="spin-"` (`lib/spin-common.sh` line 5)
- Project directory stored in tmux environment: `SPIN_CWD` (`lib/spin-claude.sh` line 31)

**Build:**
- `Makefile` - Installation to `$(PREFIX)/bin` and `$(PREFIX)/lib/spin` (default: `/usr/local`)
- No build configuration files (yaml, toml, etc.)

## Platform Requirements

**Development:**
- bash 4+ installed
- tmux 3+ installed
- git installed
- Ghostty terminal installed
- Claude Code CLI installed

**Production:**
- Same as development (all tools required at runtime)
- Installation via `make install` or `install.sh` script
- Requires sudo for system-wide installation (when `/usr/local/bin` not writable)

## Version Control

**Current Version:** 0.1.0 (as defined in `lib/spin-common.sh`)

**Repository:** https://github.com/marcgarnica13/spin.git

---

*Stack analysis: 2026-03-30*
