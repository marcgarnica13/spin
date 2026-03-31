# Project Research Summary

**Project:** Spin — tmux Session Manager for Claude Code
**Domain:** Terminal multiplexer-based CLI session manager with idle state detection
**Researched:** 2026-03-31
**Confidence:** HIGH

## Executive Summary

Spin is a tmux-based session manager that enables parallel execution of Claude Code instances with real-time state monitoring. The research validates that a pure-bash, pull-based architecture using tmux's native capabilities is the correct approach—avoiding custom daemons, shell hooks, or external CLIs. The core intelligence lies in a three-layer state detection pipeline: process tree inspection to verify Claude is alive, pane content capture to detect output patterns, and prompt pattern matching to distinguish working/waiting/permission states.

The recommended stack is minimal and battle-tested: tmux 3.0+ for session management, bash 4.0+ for scripting, and `/proc/$pid/cmdline` for process inspection. This approach is already partially validated by the existing implementation. The primary risk is polling overhead at 2s intervals (30 system calls/minute per session), which causes unnecessary CPU/battery drain and terminal flicker. The remediation is straightforward: increase refresh interval to 20s, reducing polling 10x while maintaining human-scale responsiveness.

The roadmap should focus first on performance optimization (20s interval), then on connective features (reconnect to existing sessions), with conditional enhancements (idle state tracking) deferred until user feedback validates the need. All critical pitfalls are preventable through documented patterns that are already in use in the current codebase.

## Key Findings

### Recommended Stack

Spin's technology foundation is minimal and mature. Research validates that the current bash-based approach with tmux commands is correct:

**Core technologies:**
- **tmux 3.0+**: Terminal multiplexer providing session/window/pane management. Critical for reliability; built-in format variables (`window_activity`, `pane_pid`, `pane_unseen_changes`) provide state information without polling complexity.
- **bash 4.0+**: Scripting shell for CLI tool orchestration. Pure bash keeps dependencies minimal; current implementation proves bash is sufficient for all orchestration logic.
- **procfs (`/proc/$pid/cmdline`)**: Direct process inspection for Claude detection. More reliable than `ps` parsing which varies across systems; guaranteed null-separated format works across all Linux variants.
- **Pane content capture** (`tmux capture-pane`): Fast, non-blocking extraction of recent pane output for prompt pattern detection.

**Why NOT used:**
- ❌ Custom shell hooks (Claude Code doesn't expose hook system; would require wrapping binary)
- ❌ Process CPU/memory monitoring (Claude can be idle while child processes consume resources)
- ❌ Terminal emulator-specific monitoring (Ghostty commands don't generalize; tmux is cross-terminal)
- ❌ `ps` parsing for process detection (fragile output format; special character handling nightmare)

### Expected Features

Current MVP is feature-complete for core use case. Research identifies clear table-stake vs. differentiator vs. defer boundaries.

**Must have (table stakes):**
- Launch parallel sessions (`spin claude name1 name2`)
- Monitor all active sessions with state dashboard (`spin status`)
- Detect session states: working, waiting, permission, exited
- List active panes per session (tree-based hierarchy display)

**Should have (competitive differentiators):**
- Live 20s refresh rate (responsive without system thrashing)
- Permission state detection (prevents silent hangs; shows "needs approval" clearly)
- Single-command session launch (convenience over manual tmux)

**Defer to v2+ (not essential for launch):**
- Reconnect to existing sessions (`spin connect`) — Phase 2, depends on session existence
- Idle state detection (time-based "idle for 5+ min") — Phase 3+, only if UX testing shows need
- Multi-terminal emulator support (Ghostty-only for now; users can use `tmux attach` in other terminals)
- Real-time alerting, SSH session management, session recording/playback (scope creep; tmux handles natively)

### Architecture Approach

Spin follows a proven layered architecture: CLI dispatcher → task-specific modules → state detector → tmux interface → process inspection. The design is intentionally simple—pull-based polling loop instead of daemon, direct command execution instead of state machine.

**Major components:**
1. **bin/spin** — CLI entry point and command dispatcher; no business logic
2. **spin-claude.sh** — Session creation and launch; stores metadata in tmux environment
3. **spin-status.sh** — Live session monitoring dashboard; refreshes on interval (currently 2s, should be 20s)
4. **detect_claude_state()** — Three-layer state detection: (1) process alive check via pgrep, (2) pane content capture, (3) pattern matching against prompts
5. **spin-common.sh** — Shared utilities (colors, icons, error handling)

**Critical design decisions:**
- State detection is **content-based, not process-based**: The prompt `>` is ground truth for "waiting for input", not OS process state codes
- Refresh is **pull-based, not event-driven**: Simple foreground loop with trap handlers avoids daemon complexity
- Session metadata stored **in tmux environment**: Uses `tmux set-environment` for CWD, enabling later enhancements without code changes

### Critical Pitfalls & Prevention

**1. Fragile Process Tree Inspection via ps**
- What fails: `ps aux | grep claude` breaks on special characters, system variants, grep self-matches
- Prevent: Use `/proc/$pid/cmdline` directly (guaranteed format, works across all Linux)
- Current code: ✓ Already uses correct pattern

**2. Polling Overhead at 2s Interval**
- What fails: 30 system calls/minute per session → CPU/battery drain, terminal flicker, fan spin-up
- Prevent: Increase to 20s interval (10x reduction, still human-responsive)
- Current code: ❌ Uses 2s; needs immediate fix (1-line change)

**3. Hardcoded Prompt Patterns**
- What fails: If Claude changes prompt from `>` to `claude>`, pattern breaks silently
- Prevent: Document pattern dependency; monitor Claude release notes; add pattern test cases
- Current code: ✓ Pattern is permissive (`^\s*>\s*$`); documented in code

**4. Assuming Single Pane Per Session**
- What fails: If user creates split panes or multiple windows, only first pane checked
- Prevent: Iterate through all windows and panes (current code does this correctly for windows)
- Current code: ✓ Loops through all windows; currently checks pane 0 only (acceptable for MVP)

**5. Terminal Capture Timing Race**
- What fails: Between checking "Claude is running" and capturing content, Claude could exit
- Prevent: Accept small race window as acceptable at 20s interval; handle empty content gracefully
- Current code: ✓ Uses safe default (treat as "working" if empty)

## Implications for Roadmap

Based on research, the recommended phase structure prioritizes performance, then feature completion, with conditional enhancements deferred.

### Phase 1: Performance Optimization & Interval Tuning
**Rationale:** Current 2s refresh interval is the top performance pitfall. 10x overhead reduction is a 1-line change with immediate user benefit (lower CPU/battery drain, no terminal flicker). Must happen before deploying to users.

**Delivers:**
- Refresh interval: 2s → 20s
- 10x reduction in polling overhead (30 calls/min → 3 calls/min per session)
- Performance validation testing (compare CPU metrics at 2s vs. 20s with 5+ sessions)

**Implements:** Core polling loop optimization from ARCHITECTURE.md

**Avoids:** Pitfall #2 (Polling Overhead) and unnecessary system load

**Research flags:** ❌ No additional research needed — change is straightforward and well-documented

---

### Phase 2: Session Reconnection (spin connect)
**Rationale:** Current MVP can launch sessions but not reconnect if Ghostty closes. This is expected functionality for a session manager; research shows low complexity.

**Delivers:**
- `spin connect <session-name>` subcommand
- Spawns Ghostty with `tmux attach -t $session`
- Validates session exists before attempt
- Handles edge cases (session already attached, Ghostty launch failure)

**Implements:** Ghostty window lifecycle patterns from ARCHITECTURE.md; avoids Pitfall #1 (Ghostty attachment edge cases)

**Uses:** Existing tmux metadata (SPIN_CWD, session environment)

**Research flags:** ⚠️ Medium — Research Ghostty's behavior when attaching already-attached sessions; test multiple client scenarios

**Testing requirement:** Verify session attachment from multiple terminals simultaneously doesn't cause conflicts

---

### Phase 3: Idle State Detection (Conditional)
**Rationale:** Only pursue if Phase 1-2 user testing shows demand. Current "waiting" state already indicates readiness; adding "idle for 5+ min" is nice-to-have, not essential.

**Delivers:**
- Time-tracking of state changes using tmux environment timestamps
- Display "idle" label for sessions waiting 5+ minutes
- Requires timestamp comparison logic

**Implements:** Future enhancement point from ARCHITECTURE.md (timestamp tracking in tmux env)

**Avoids:** Over-building; validates user need before coding

**Research flags:** ✓ High confidence — Pattern documented and feasible, but defer until UX testing validates need

---

### Phase Ordering Rationale

1. **Phase 1 first:** Performance fix unblocks everything else. A 2s polling interval will break testing and user trust; fixing immediately ensures all subsequent phases are evaluated on good foundation.
2. **Phase 2 next:** Extends core capability (reconnect to sessions). Low complexity, high user value. Depends on Phase 1 being stable.
3. **Phase 3 conditional:** Idle detection is enhancement layer. Only pursue if Phase 1-2 feedback indicates need. Current "waiting" state provides 80% of value with 20% complexity.

Dependencies:
- Phase 2 depends on Phase 1 (needs stable, tested polling before adding features)
- Phase 3 independent of Phases 1-2 (can be added anytime after Phase 1)

---

### Research Flags

**Phases needing deeper research:**
- **Phase 2 (Session Reconnection):** Research Ghostty's window spawning behavior, multiple-client attachment scenarios, and error handling edge cases (session doesn't exist, Ghostty fails to launch). Medium scope, well-defined problem.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Interval Tuning):** Straightforward configuration change. No research needed.
- **Phase 3 (Idle Detection):** Pattern already documented in ARCHITECTURE.md. Research only needed if pivoting to alternative approaches.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | All technologies verified via tmux man pages, current implementation, and POSIX standards. No version conflicts or surprising requirements. |
| Features | **HIGH** | Table-stake features already implemented and working. Differentiators and anti-features validated by domain expertise. MVP clearly defined. |
| Architecture | **HIGH** | Three-layer state detection pattern proven in current code. Component boundaries clear and enforced. Refresh loop architecture simple and well-tested. |
| Pitfalls | **HIGH** | All pitfalls extracted from current implementation; prevention strategies already in use or documented. Testing checklist provided for validation. |

**Overall confidence:** **HIGH**

### Gaps to Address

1. **Ghostty-specific behavior:** Current research assumes Ghostty as terminal emulator. If other emulators become primary, window spawning logic may differ.
   - *Handling:* Phase 2 research should document Ghostty's attach semantics. Future enhancement could abstract emulator choice, but defer for now.

2. **Claude prompt format stability:** Hardcoded pattern `^\s*>\s*$` depends on Claude maintaining this format.
   - *Handling:* Document in code with clear version dependency. Monitor Claude's release notes for prompt changes. Add pattern test cases during Phase 1 validation.

3. **ANSI color codes in pane output:** Research notes that ANSI escape sequences could interfere with pattern matching.
   - *Handling:* Current patterns are permissive enough to work. If pattern matching fails in testing, add ANSI stripping via sed. Low priority; address only if observed.

4. **Multiple panes per window:** Current implementation only checks pane 0.
   - *Handling:* Acceptable for MVP (rare use case). Phase 2 can extend to support split panes if users report the need. Document limitation.

## Sources

### Primary (HIGH confidence)
- **tmux man page (FORMATS section)** — Format variables, `window_activity`, `pane_pid`, `pane_unseen_changes`
- **POSIX /proc filesystem** — `/proc/$pid/cmdline` format and availability
- **Current implementation (spin-status.sh, spin-claude.sh)** — Validates all documented patterns work in practice

### Secondary (MEDIUM confidence)
- **GitHub: tmux/tmux Advanced Use** — monitor-activity and monitor-silence options
- **Linux process inspection best practices** — pgrep reliability, process tree walking
- **Community tmux patterns** — Pane/session traversal approaches (Reddit, Stack Overflow)

### Tertiary (LOW confidence)
- **Ghostty documentation** — Limited public documentation; behavior inferred from testing and user reports
- **Claude Code prompt stability** — No official guarantee; monitored via release notes

---

*Research completed: 2026-03-31*
*Ready for roadmap: yes*
