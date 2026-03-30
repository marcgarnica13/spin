# External Integrations

**Analysis Date:** 2026-03-30

## APIs & External Services

**Claude Code API:**
- Claude Code CLI - Parallel AI code assistant sessions
  - SDK/Client: `claude` command-line tool (external)
  - Invocation: `lib/spin-claude.sh` line 24 via `claude --dangerously-skip-permissions --worktree <name>`
  - No authentication tokens required (assumes authenticated locally via Claude Code installation)

## Data Storage

**Databases:**
- None

**File Storage:**
- Local filesystem only - Stores spin session metadata in tmux environment variables
- `.planning/` directory - Planning documents directory (empty at initialization)

**Caching:**
- None

## Authentication & Identity

**Auth Provider:**
- None required for spin tool itself
- Claude Code CLI authentication handled externally by Claude Code installation
- No credential files or secrets management

## Monitoring & Observability

**Error Tracking:**
- None (exit codes only)

**Logs:**
- None (output to stdout/stderr only)
- Process monitoring via `/proc` filesystem (`lib/spin-status.sh` lines 89-103)

## CI/CD & Deployment

**Hosting:**
- Not applicable (local CLI tool)
- GitHub repository: https://github.com/marcgarnica13/spin.git

**CI Pipeline:**
- None detected

**Installation:**
- Distributed via git clone + `make install`
- One-liner installer: `curl -fsSL https://raw.githubusercontent.com/marcgarnica13/spin/main/install.sh | bash`

## Environment Configuration

**Required env vars:**
- None mandatory - Tool operates with system environment
- Session environment uses: `SPIN_CWD` (project directory, set by `lib/spin-claude.sh`)
- HOME environment variable used for path shortening (`lib/spin-status.sh` line 25)

**Secrets location:**
- Not applicable - No credentials needed for spin tool
- Claude Code credentials managed externally by Claude Code CLI

## Tmux Integration

**Session Management:**
- Uses tmux as process manager for parallel Claude sessions
- Session naming: `spin-<directory_basename>` (`lib/spin-claude.sh` line 9)
- Window creation and pane management (`lib/spin-claude.sh` lines 19-26)
- Session enumeration for status monitoring (`lib/spin-status.sh` line 6)

**Process Introspection:**
- Uses `/proc` filesystem to detect claude process state (`lib/spin-status.sh` lines 79-104)
- Process tree inspection via `pgrep -P <pid>` (`lib/spin-status.sh` lines 86, 96)
- Terminal pane content capture via `tmux capture-pane` (`lib/spin-status.sh` line 114)

## Git Integration

**Worktree Management:**
- Claude Code CLI uses `--worktree <name>` flag for isolated git worktrees
- Assumes git repository in current working directory
- No direct git operations by spin tool itself

## Terminal Integration

**Ghostty Terminal:**
- Launches new Ghostty window with attached tmux session (`lib/spin-claude.sh` line 33)
- Spawned as background process with disown

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

---

*Integration audit: 2026-03-30*
