# Architecture Patterns: Spin Session Manager

**Domain:** tmux-based parallel CLI session manager
**Researched:** 2026-03-31

## Recommended Architecture

Spin follows a simple, proven layered architecture:

```
┌─────────────────────────────────────────────────────────┐
│                      User Shell                         │
│        (spin claude ... / spin status / spin connect)   │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ↓                         ↓
    ┌─────────────┐        ┌──────────────┐
    │   CLI Core  │        │   Dashboard  │
    │ (bin/spin)  │        │ (spin-status)│
    └──────┬──────┘        └──────┬───────┘
           │                      │
    ┌──────┴──────────────────────┴──────┐
    │                                     │
    ↓                                     ↓
┌─────────────────────┐        ┌──────────────────────┐
│  Session Launcher   │        │  State Detector      │
│  (spin-claude)      │        │  (detect_claude_    │
│                     │        │   state)             │
│ - Create tmux sess  │        │                      │
│ - Launch Claude CLI │        │ - Walk process tree  │
│ - Store metadata    │        │ - Analyze pane text  │
└────────┬────────────┘        └────────┬─────────────┘
         │                             │
         └─────────────┬───────────────┘
                       ↓
            ┌──────────────────────┐
            │  Tmux Interface      │
            │                      │
            │ - list-sessions      │
            │ - list-panes         │
            │ - capture-pane       │
            │ - display-message    │
            │ - set-environment    │
            │ - send-keys          │
            └────────┬─────────────┘
                     │
           ┌─────────┴──────────┐
           ↓                    ↓
    ┌──────────────┐    ┌──────────────┐
    │  Tmux State  │    │   Ghostty    │
    │              │    │              │
    │ - Sessions   │    │ - Window     │
    │ - Windows    │    │   creation   │
    │ - Panes      │    │ - Attach cmds│
    │ - Metadata   │    │              │
    └──────────────┘    └──────────────┘
           │                    │
           └────────┬───────────┘
                    ↓
         ┌──────────────────────┐
         │  /proc Filesystem    │
         │  (Process Inspection)│
         │                      │
         │ - /proc/$pid/cmdline │
         │ - pgrep tree walk    │
         └──────────────────────┘
```

## Component Boundaries

| Component | Responsibility | Communicates With | Design Notes |
|-----------|---------------|-------------------|--------------|
| **bin/spin** | CLI entry point, command dispatch | lib/spin-*.sh files | Pure dispatcher; no business logic |
| **spin-claude.sh** | Session creation and launch | tmux, Ghostty | Creates sessions, stores CWD metadata, spawns Ghostty |
| **spin-status.sh** | Live session monitoring | tmux, /proc | Refreshes every 2s (soon 20s), displays dashboard |
| **detect_claude_state()** | State detection logic | tmux capture-pane, pgrep, /proc | Three-layer state machine: process alive, pane content analysis |
| **spin-common.sh** | Shared utilities | All modules | Colors, icons, error handling, constants |

## State Detection Pipeline

The core intelligence: how spin determines what Claude is doing.

```
Input: session:window index
  │
  ├─ Layer 1: Is Claude running?
  │   └─ Get pane PID: tmux list-panes -F '#{pane_pid}'
  │   └─ Walk process tree: pgrep -P $pane_pid (2 levels)
  │   └─ Search cmdline: grep claude /proc/$pid/cmdline
  │   └─ Result: alive=true or alive=false
  │      └─ If false → return "exited"
  │
  ├─ Layer 2: Analyze pane content
  │   └─ Capture last 10 lines: tmux capture-pane -p -S -10
  │   └─ Remove empty lines, get last 3 meaningful lines
  │
  └─ Layer 3: Pattern matching
      ├─ Pattern: "^\s*>\s*$" (Claude's input prompt)
      │  └─ Match → return "waiting"
      │
      ├─ Pattern: "(Allow once|Deny|Yes.*No)" (permission)
      │  └─ Match → return "permission"
      │
      └─ No match → return "working"

Output: state string (exited | waiting | permission | working)
```

**Why this layered approach:**
1. **Layer 1 (Process check)**: Early exit if Claude isn't running; cheap operation
2. **Layer 2 (Content capture)**: One tmux call gets all info needed for layers 3+
3. **Layer 3 (Pattern matching)**: Pure bash string matching; no external tools

## Refresh Loop Architecture

Dashboard polling cycle (to be optimized from 2s to 20s):

```
┌─ Main Loop: while true; do
│
├─ Clear screen
├─ Display header with refresh interval info
│
├─ Get all active spin sessions
│  └─ tmux list-sessions -F '#{session_name}' | grep "^spin-"
│
├─ For each session:
│  │
│  ├─ Get project directory from environment
│  │  └─ tmux show-environment -t session SPIN_CWD
│  │
│  ├─ List windows in session
│  │  └─ tmux list-windows -t session -F '#{window_name}:#{window_index}'
│  │
│  └─ For each window:
│     │
│     ├─ Detect state → detect_claude_state(session, window_idx)
│     ├─ Map state to icon + label + color
│     └─ Print formatted output with tree drawing
│
├─ Print legend
│
├─ Sleep 20 seconds (CHANGE FROM 2s)
│
└─ Loop

Signals handled:
  - SIGINT (Ctrl-C) → Cleanup cursor, exit gracefully
  - SIGTERM → Same cleanup, exit
```

**Key design decision:** Refresh is pull-based (poll every 20s), not push-based (event hooks). This avoids complexity of inotify, dbus, or daemon processes.

## Anti-Patterns Avoided

| Anti-Pattern | Why We Avoid | Our Approach |
|--------------|-------------|-------------|
| Spawning subshells in tight loop | Each `$(...)` spawns a process; 30/min at 2s interval | Pre-compute once per refresh cycle; store in variables |
| Parsing `ps` output | Format varies by system; fragile with special characters | Direct `/proc/$pid/cmdline` inspection |
| Background daemon | Would need state management, signal handling, logging | Simple foreground loop with trap handlers |
| Hardcoded prompt patterns | Claude could change prompt format | Pattern matches observed behavior; documented as "may need update if Claude changes" |
| Custom state machine | Adds complexity; multiple sources of truth | Three-layer check produces definitive state; no state machine needed |
| Using `watch` command | Loses control over display formatting, color management | Custom loop with full control |

## Scaling Considerations

### At 1-2 sessions (single user typical case)
- Process tree walk: <10ms
- Content capture: ~1ms per pane
- Pattern matching: <1ms
- Total refresh: <20ms
- Acceptable at 2s or 20s interval

### At 5 sessions (power user case)
- 5 windows typical = 5 state detections
- Process tree walks: 5 × 10ms = 50ms
- Content captures: 5 × 1ms = 5ms
- Pattern matching: 5 × 1ms = 5ms
- Total refresh: ~60ms
- Adequate for 20s interval

### At 10+ sessions (edge case)
- Multiple windows per session = 10-20 state checks
- Process tree walks: 100-200ms
- Content captures: 10-20ms
- Pattern matching: 10-20ms
- Total refresh: 120-240ms
- **Latency grows linearly with pane count**
- **20s interval essential at this scale**

**No bottleneck is problematic:** Even at 10 sessions with 240ms refresh, we're well within the 20s window.

## Future Enhancement Points

### 1. Idle State Detection (Phase 3+)
When users want to know "idle at prompt for 5+ minutes":
- Store `state_changed_at` timestamp in tmux environment
- Compare current time to timestamp
- If waiting state for 5+ min, show "idle" label
- Requires: `date +%s` call, time arithmetic

### 2. Configurable Refresh Rate
Add `--interval N` flag to `spin status`:
- Current: hardcoded 2s or 20s
- Future: user-configurable 5s, 10s, 30s, 60s
- For power users who want different tradeoffs

### 3. Activity Notification
Extend status with `pane_unseen_changes` tracking:
- Current: shows current state only
- Future: mark panes that changed since last check
- Requires: tracking previous state snapshot

### 4. Remote Session Support
Today: local tmux only. Future: over SSH.
- Would require: SSH config, key forwarding, remote tmux
- Out of scope for Phase 1-2

---

## Sources

- Current implementation: `lib/spin-status.sh`, `lib/spin-claude.sh` validate all documented patterns
- tmux man page: FORMATS section for command reference
- Community patterns: Standard tmux pane/session traversal approaches

*Architecture documentation for: spin tmux session manager*
*Researched: 2026-03-31*
