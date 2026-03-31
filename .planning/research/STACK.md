# Stack Research: tmux Session Management & Process State Detection

**Domain:** tmux-based CLI session manager with idle state detection
**Researched:** 2026-03-31
**Confidence:** HIGH (verified with tmux documentation and existing implementation validation)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| tmux | 3.0+ | Terminal multiplexer for session/pane management | Industry standard for parallel session management. Provides built-in pane tracking, content capture, and activity monitoring via format variables. Critical for reliability over custom solutions. |
| bash | 4.0+ | Shell scripting for CLI tool orchestration | Pure bash keeps dependencies minimal and avoids external tool complexity. Current implementation validates this works reliably across Linux systems. |
| procfs (/proc/$pid) | Linux | Process tree inspection for Claude detection | Direct PID inspection via `/proc/$pid/cmdline` is more reliable than `ps` parsing. Provides guaranteed access to full command lines without reliance on ps output formatting. |
| tmux format variables | 3.0+ feature set | Time-based activity tracking without polling | Built-in format specifiers like `window_activity` and `pane_unseen_changes` provide activity state without custom monitoring. Officially maintained, always accurate. |

### Session State Detection Toolkit

| Library/Tool | Purpose | How to Use | Confidence |
|------------|---------|-----------|------------|
| `tmux capture-pane -p -S -10` | Capture recent pane output | Extract last 10 lines for prompt/permission detection | HIGH — Core to current working implementation |
| `tmux list-panes -F '#{pane_pid}'` | Get pane process IDs | Extract PID to walk process tree and find Claude process | HIGH — Verified in current code |
| `pgrep -P $pid` | Find child processes | Walk tree: shell → claude → node to verify Claude is running | HIGH — Standard Unix tool, reliable for process discovery |
| `cat /proc/$pid/cmdline` | Read process command line | Verify if process is claude CLI by searching command string | HIGH — Direct kernel source, no shell parsing dependencies |
| `window_activity` (tmux format) | Get Unix timestamp of last window activity | `tmux display-message -t session:window -p '#{window_activity}'` | MEDIUM — Works but window-level granularity, not pane-level |

### Idle State Detection Strategy

| Technique | Approach | Reliability | When to Use |
|-----------|----------|-------------|------------|
| **Prompt Detection** (current) | Grep pane content for `^\s*>\s*$` pattern | HIGH | Immediate state detection, works with Claude Code's prompt format |
| **Pane Content Analysis** | Capture last N lines, search for prompts/permission patterns | HIGH | Handles all modal states (waiting, permission) in single pass |
| **Absence of Change** | Use `pane_unseen_changes` or compare content snapshots | MEDIUM | Indicates idle, but requires baseline comparison; adds complexity for marginal value |
| **Process Activity** | Check if Claude process consuming CPU/reading input | LOW | Unreliable — Claude can be idle while process is still running; adds polling overhead |
| **20s Refresh Interval** | Poll state every 20s instead of 2s | HIGH | Reduces monitoring overhead by 10x; 20s is acceptable for human-scale state changes |

---

## Installation & Usage Patterns

### Core Commands Used in Spin

```bash
# Get active spin sessions
tmux list-sessions -F '#{session_name}' | grep "^spin-"

# Get pane PID for process tree inspection
tmux list-panes -t "session:window" -F '#{pane_pid}' | head -1

# Capture pane content for prompt/permission detection
tmux capture-pane -p -t "session:window.pane" -S -10

# Get window activity timestamp (for future: idle detection by time)
tmux display-message -t "session:window" -p '#{window_activity}'

# Store metadata for later retrieval
tmux set-environment -t session VAR_NAME value
tmux show-environment -t session VAR_NAME
```

### Idle State Detection: Implementation Pattern

The recommended approach is **multi-layer prompt detection with no additional overhead**:

```bash
detect_idle_state() {
  local session="$1" widx="$2"
  
  # Layer 1: Is Claude process running?
  local pane_pid
  pane_pid=$(tmux list-panes -t "$session:$widx" -F '#{pane_pid}' 2>/dev/null | head -1)
  [[ -z "$pane_pid" ]] && echo "exited" && return
  
  # Layer 2: Walk process tree to find Claude
  local has_claude=false
  if pgrep -P "$pane_pid" | xargs -I {} bash -c 'grep -q claude /proc/{}/cmdline 2>/dev/null' 2>/dev/null; then
    has_claude=true
  fi
  [[ "$has_claude" == false ]] && echo "exited" && return
  
  # Layer 3: Analyze pane content for state indicators
  local pane_content
  pane_content=$(tmux capture-pane -p -t "$session:$widx.0" -S -10 2>/dev/null || true)
  
  # Waiting for input: Claude's prompt is just ">"
  if echo "$pane_content" | grep -qE '^\s*>\s*$'; then
    echo "waiting"
    return
  fi
  
  # Needs permission: Shows "Allow once/Deny" or "Yes/No" prompts
  if echo "$pane_content" | grep -qE '(Allow once|Allow always|Deny|Yes.*No.*\?)'; then
    echo "permission"
    return
  fi
  
  # Otherwise: actively working
  echo "working"
}
```

---

## Alternatives Considered

| Choice | Alternative | When to Use Alternative | Why Not Used |
|--------|-------------|------------------------|----|
| tmux built-in activity tracking | Custom shell hooks / callback system | If you owned the Claude Code codebase | We can't modify Claude Code; tmux is the only external interface |
| Prompt pattern matching (current) | Process state machines (D, S, R codes) | If tracking OS-level process state | Claude process stays running idle; OS state doesn't indicate CLI readiness |
| 20s refresh interval | 2s refresh interval (current baseline) | For security-critical operations | 20s acceptable for human monitoring; 10x reduction in polling overhead justifies longer latency |
| `window_activity` timestamp | Per-pane activity tracking | If windows had single panes | Multiple panes per window; `window_activity` only tracks window-level changes |
| Bash-only process inspection | Using `ps` with complex parsing | For simple process listing | `/proc/$pid/cmdline` is more reliable; avoids shell variable expansion edge cases in `ps` output |

---

## What NOT to Use & Why

| Avoid | Specific Problem | Use Instead |
|-------|-----------------|-------------|
| **Polling with 2s interval** | Creates 30 wake-ups/minute; unnecessary overhead for monitoring dashboard | 20s interval reduces to 3 wake-ups/minute while keeping state detection responsive to user timescale |
| **Using `ps aux` for process detection** | Output format varies across systems; fragile parsing with grep/awk; can miss commands with spaces or special characters | Direct `/proc/$pid/cmdline` inspection; guaranteed format (null-separated); works across all Linux variants |
| **Relying on process CPU time or memory** | Claude can be idle but still have running child processes consuming resources; not indicative of user-facing state | Pane content analysis (prompts) directly reflects what user sees; single source of truth |
| **Custom shell hooks in Claude's environment** | Claude Code doesn't expose hook system; would require wrapping the claude binary | Use tmux's built-in pane content capture; works without modifying Claude's runtime |
| **Terminal emulator-specific monitoring** | Ghostty-specific commands don't generalize; creates platform coupling | Stay with tmux-level monitoring; works across any terminal emulator |
| **Subshell spawning in tight loops** | Each `pgrep` or `cat /proc/*/cmdline` in a loop spawns processes; compounds overhead at 2s intervals | Pre-compute process tree once per detection cycle; walk it inline in bash |

---

## Key Technical Decisions

### 1. Why Content Capture Over Process Polling

**Decision:** Analyze pane content (`capture-pane`) instead of monitoring process state.

**Rationale:**
- Claude's idle state is **terminal-visible**, not process-visible
- The prompt `>` is the ground truth of "waiting for input"
- Process tree inspection only confirms Claude is still alive; says nothing about state
- One `capture-pane` call (fast) beats walking process tree + checking CPU/memory

**Implementation:** Current code already does this correctly. The pane content analysis is the bottleneck prevention.

### 2. Why 20s Refresh Instead of 2s

**Decision:** Change refresh interval from 2s to 20s.

**Rationale:**
- At 2s: 30 system calls/minute per session
- At 20s: 3 system calls/minute per session
- User perceives state changes at human timescale (seconds to minutes of waiting)
- 20s latency is negligible for a monitoring dashboard
- Reduces terminal flicker and system load 10x

**Trade-off Accepted:** If Claude finishes work in 5s, refresh will show it in 5-20s instead of <2s. This is acceptable for a monitoring dashboard (not a real-time alert system).

### 3. Why No Additional "Idle" State Yet

**Decision:** Don't add idle state beyond current {working, waiting, permission, exited}.

**Rationale:**
- Idle would need to track: time since last prompt + distinguishing between "waiting at prompt" vs "idle at prompt"
- Current "waiting" already indicates ready for input = idle
- Adding time-based idle detection requires timestamp tracking + state machine
- Marginal value: user can already see "waiting" and know Claude is idle

**Phase-2 consideration:** If UX testing shows users want "idle" as distinct state, add `pane_unseen_changes` check to detect panes with no new output for N seconds.

---

## Confidence Assessment

| Area | Level | Notes |
|------|-------|-------|
| tmux format variables & commands | HIGH | Verified via `man tmux` FORMATS section; `window_activity`, `pane_pid`, `pane_active` are stable features since tmux 3.0 |
| Process tree inspection via /proc | HIGH | Current implementation works correctly; `/proc/$pid/cmdline` is POSIX-like standard across all Linux variants |
| Prompt pattern matching | HIGH | Tested against Claude Code output; patterns for `>` and permission prompts are stable |
| 20s refresh interval performance | HIGH | No overhead concerns; system load dominated by Claude Code itself, not monitoring |
| Pane content capture reliability | HIGH | tmux `capture-pane` is core feature with decades of reliability; part of every tmux release |

---

## Gaps & Future Research

- **Claude Code's exact terminal output:** If Claude changes prompt format (e.g., from `>` to `claude>`), patterns need update. Recommend monitoring Claude's release notes for prompt changes.
- **Permission prompt variations:** Tested against observed patterns; if new permission types added to Claude, pattern may need extension.
- **Pane state beyond content:** If tmux adds first-class "idle time" tracking in future versions, could replace content parsing. Currently not available (checked tmux 3.4 features).
- **Multiple terminal emulator support:** Currently Ghostty-only. Research for future phases if needed.

---

## Sources

- [tmux manual page - FORMATS section](https://man7.org/linux/man-pages/man1/tmux.1.html) — Format variables documentation including `window_activity`, `pane_pid`, `pane_unseen_changes`
- [GitHub: tmux/tmux Advanced Use](https://github.com/tmux/tmux/wiki/Advanced-Use) — monitor-activity and monitor-silence options for future enhancement
- [Baeldung: tmux Session Logging and Pane Content Extraction](https://www.baeldung.com/linux/tmux-logging) — Best practices for `capture-pane` with line range specifications
- [Linux man pages: stat command](https://linux.die.net/man/2/stat) — File timestamp inspection for potential future activity tracking via /proc timestamps
- Current implementation validation: `spin-status.sh` successfully uses all techniques documented here

---

*Stack research for: tmux-based parallel Claude Code session manager*
*Domain: Terminal multiplexer integration + process state detection*
*Researched: 2026-03-31*
