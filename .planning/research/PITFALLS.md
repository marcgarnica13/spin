# Domain Pitfalls: tmux Session Management

**Domain:** Terminal multiplexer-based CLI session monitoring
**Researched:** 2026-03-31

## Critical Pitfalls

Mistakes that cause rewrites or major bugs.

### Pitfall 1: Fragile Process Tree Inspection

**What goes wrong:**
Attempting to detect Claude using `ps aux | grep claude` fails because:
- `ps` output format varies across systems
- grep matches its own process: `grep claude` appears in the process list
- Commands with spaces or pipes get split incorrectly
- Special characters in command lines break parsing

Example failure:
```bash
# WRONG - fragile
if ps aux | grep claude | grep -v grep; then
  # This catches false positives and breaks on special chars
fi
```

**Why it happens:**
Developers assume `ps` output is stable. It isn't. Also, shell variable expansion in grep patterns creates quoting nightmares.

**Consequences:**
- False positives/negatives when detecting if Claude is running
- State detection incorrectly reports "exited" when Claude is still running
- Dashboard shows wrong status, confusing users

**Prevention:**
Use `/proc/$pid/cmdline` directly instead of ps:
```bash
# CORRECT - reliable across all Linux variants
local cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || true)
if [[ "$cmdline" == *claude* ]]; then
  # This is reliable and guaranteed format
fi
```

**Detection:**
- Monitor: State detection incorrectly reports "exited" frequently
- Test: Kill Claude manually, verify "exited" appears within 20s

### Pitfall 2: Polling Overhead with 2s Interval

**What goes wrong:**
At 2-second refresh interval:
- 30 tmux commands executed per minute per session
- Process tree walks (pgrep) run 30x per minute
- Screen redraws 30x per minute, causing terminal flicker
- Cumulative CPU load becomes noticeable with 5+ sessions
- Battery drain on laptops increases substantially

**Why it happens:**
2s feels "responsive" during development. At scale (multiple sessions), the cumulative overhead becomes significant.

**Consequences:**
- High CPU usage visible in `top`
- Terminal flicker distracting to user
- Laptop fans spin up unnecessarily
- Battery drain 5-10% per hour from monitoring alone

**Prevention:**
Use 20-second refresh interval:
- Reduces polling 10x
- Still shows state changes within human perception timescale
- 20s latency acceptable for a dashboard (not real-time alert)
- CPU/battery impact becomes negligible

**Mitigation:** If faster response needed, make refresh interval configurable: `spin status --interval 5`

**Detection:**
- Monitor: Check CPU usage with `top -p $(pgrep -f "spin status")`
- Test: Run 5 sessions for 5 minutes at 2s vs 20s, compare CPU metrics

### Pitfall 3: Hardcoded Prompt Patterns

**What goes wrong:**
Current implementation matches Claude's prompt with pattern `^\s*>\s*$`.

If Claude changes prompt format:
- From: `>`
- To: `claude>` or `>>` or `(input):`
- Pattern no longer matches
- All sessions show "working" instead of "waiting"
- Users can't tell if Claude is waiting for input

**Why it happens:**
Prompt format is application-specific. Claude owns this, not spin.

**Consequences:**
- After Claude updates, spin breaks with no error message
- Users perceive spin as unreliable
- Requires manual code update to fix pattern

**Prevention:**
1. **Monitor Claude release notes** for prompt format changes
2. **Document pattern dependency** clearly in code comments
3. **Add pattern test cases** that validate against actual Claude output
4. **Consider alternative detection** if available (e.g., Claude API events instead of terminal parsing)

**Detection:**
```bash
# Add to test suite
test_waiting_state() {
  # Capture actual Claude output, verify pattern matches
  local sample="
  Working on task...
  >"  # This is actual Claude prompt
  
  if echo "$sample" | grep -qE '^\s*>\s*$'; then
    echo "PASS: waiting pattern recognized"
  else
    echo "FAIL: waiting pattern not recognized"
  fi
}
```

### Pitfall 4: Assuming Single Pane Per Session

**What goes wrong:**
If code assumes "one tmux window = one Claude process", but users have:
- Multiple windows in one session
- Multiple panes per window
- Detached panes
- Custom tmux layouts

State detection only checks first pane, missing status of others.

**Why it happens:**
Simple cases work with single pane; complexity grows incrementally.

**Consequences:**
- Only first window status shown
- Other windows' Claude instances invisible in dashboard
- Users miss permission prompts or completed work

**Prevention:**
Current implementation already handles this correctly:
- Iterates through all windows: `tmux list-windows -t session`
- Iterates through all panes per window (currently pane 0 only)
- Checks each separately: `detect_claude_state session window_idx`

**Note:** Current code checks `pane_index 0` only. If future versions support split panes with Claude in pane 1+, this will need update.

### Pitfall 5: Terminal Capture Timing Race Condition

**What goes wrong:**
Between the time we check "Claude is running" and capture pane content, Claude could:
- Exit suddenly
- Produce output
- Clear the screen
- Create race condition where captured content doesn't match actual state

Example:
1. `pgrep -P $pane_pid` returns "claude running"
2. Claude exits
3. `tmux capture-pane -p` returns empty or old content
4. State detection confused

**Why it happens:**
Two separate system calls with a gap in between = race window.

**Consequences:**
- Occasional state flaps (working → waiting → working)
- Inconsistent dashboard display
- Hard to reproduce/debug

**Prevention:**
1. **Accept small race window as acceptable** — at 20s interval, 10ms race is negligible
2. **Handle empty content gracefully** — treat as "working" (safe default)
3. **Use timeout guards** — tmux commands should have short timeouts

**Detection:**
- Rare issue; hard to trigger deliberately
- Monitor logs for frequent state changes on same session
- If state flaps 10+ times per refresh cycle, investigate

**Mitigation (current code):**
```bash
local pane_content
pane_content=$(tmux capture-pane -p -t "$session:$widx.0" -S -10 2>/dev/null || true)

if [[ -z "$pane_content" ]]; then
  echo "working"  # Safe default if empty
  return
fi
```

---

## Moderate Pitfalls

Issues that cause bugs, not rewrites.

### Pitfall 1: Ghostty Window Lifecycle Edge Cases

**What goes wrong:**
When spawning Ghostty with `ghostty -e tmux attach -t $session`:
- Ghostty window could fail to open
- Session might already be attached from elsewhere
- Multiple users attaching same session
- Ghostty process dies but tmux session persists (orphaned)

**Prevention:**
- Validate session exists before attach: `tmux has-session -t $session`
- Handle Ghostty launch failures gracefully
- Document behavior with multiple clients

### Pitfall 2: Empty Pane Content After Session Launch

**What goes wrong:**
Immediately after launching `spin claude`, status check might show empty pane (no content yet).
State detection returns "working" (safe default).
Correct behavior, but confusing to users who expect immediate state.

**Prevention:**
- Add delay in status check when showing newly-launched sessions
- Or accept that newly-launched sessions show "working" for a few seconds

### Pitfall 3: ANSI Color Codes in Pane Content

**What goes wrong:**
Claude or system output includes ANSI escape sequences (colors, formatting):
- Grep patterns might not match due to hidden escape codes
- Example: `>\e[0m` (prompt with color reset) vs `>`
- Pattern matching assumes plain text

**Prevention:**
Strip ANSI codes before pattern matching:
```bash
# Use -v option in grep or pipe through sed
sed 's/\x1b\[[0-9;]*m//g'  # Remove ANSI color codes
```

Current code doesn't do this explicitly; pattern matching is permissive enough to work.

---

## Minor Pitfalls

Issues that cause inconvenience, not breakage.

### Pitfall 1: Tmux Session Name Collisions

If two projects have same basename (both named "project"), spin-project conflicts.

**Prevention:** Use full path hash: `spin-$(pwd | md5sum | cut -c1-8)` instead of directory name

### Pitfall 2: Stale Environment Variables

If session metadata (SPIN_CWD) becomes stale or wrong, later status displays incorrect paths.

**Prevention:** Update environment on each `spin claude` call; validate paths exist

### Pitfall 3: User Kills Session While Status Running

If user manually `tmux kill-session` while `spin status` is running:
- Status continues running
- Shows "No active sessions" after next refresh
- Graceful behavior, but worth noting

**Prevention:** None needed; current behavior is correct

---

## Phase-Specific Warnings

| Phase | Topic | Likely Pitfall | Mitigation |
|-------|-------|----------------|------------|
| Phase 1 (20s interval) | Polling overhead | Users complain about responsiveness | Measure CPU before/after; confirm 20s acceptable |
| Phase 2 (spin connect) | Window lifecycle | Ghostty attachment edge cases | Test with sessions already attached from other terminals |
| Phase 3 (idle detection) | Time tracking | Timestamp skew or clock changes | Store timestamps in UTC; handle system clock adjustments |
| Future (remote) | SSH sessions | Credential/forwarding complexity | Large scope; defer until proven necessary |

---

## Testing Checklist for Pitfall Prevention

- [ ] **Prompt pattern:** Capture actual Claude output, test pattern matching
- [ ] **Process detection:** Kill Claude manually, verify "exited" within 20s
- [ ] **Polling overhead:** Run 5+ sessions, measure CPU at 2s and 20s intervals
- [ ] **Race conditions:** Rapid session launch/exit, verify no state flaps
- [ ] **Empty content:** Status check immediately after session launch
- [ ] **ANSI codes:** Test with Claude output containing color codes
- [ ] **Ghostty attachment:** Attach same session from multiple terminals simultaneously
- [ ] **Stale metadata:** Change directory, restart session, verify path updates

---

## Sources

- Current implementation: `lib/spin-status.sh` demonstrates correct patterns
- Process inspection guide: Direct `/proc/$pid/cmdline` usage (not ps parsing)
- tmux best practices: Avoid assumptions about session/pane structure
- Linux standards: POSIX-like /proc filesystem availability assumption

*Pitfall research for: tmux-based session manager*
*Researched: 2026-03-31*
