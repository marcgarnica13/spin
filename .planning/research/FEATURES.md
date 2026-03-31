# Feature Landscape: Spin Session Manager

**Domain:** tmux-based parallel CLI session manager
**Researched:** 2026-03-31

## Table Stakes

Features users expect from a tmux session manager. Missing = tool feels incomplete.

| Feature | Why Expected | Complexity | Status |
|---------|--------------|------------|--------|
| Launch parallel sessions | Core use case: "I want to run Claude multiple times" | Low | ✓ Implemented |
| Monitor all active sessions | Essential dashboard: "What's the status of my work?" | Medium | ✓ Implemented (2s refresh) |
| Show session state (working/waiting/done) | UX clarity: "Which sessions need my attention?" | Medium | ✓ Implemented |
| Reconnect to existing session | Recovery: "Ghostty crashed, I want my session back" | Low | ✗ Pending (Phase 2) |
| List active panes per session | Detail view: "What windows are in this session?" | Low | ✓ Implemented |
| Detect when Claude exits | Completion signal: "This session is done" | Low | ✓ Implemented (exited state) |

## Differentiators

Features that set spin apart. Not expected, but valued by power users.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Live 20s refresh rate | Responsive monitoring without system thrashing | Medium | Trades 20s latency for 10x less polling overhead |
| Permission state detection | Shows when Claude needs user approval | Medium | Prevents silent hangs; users see "needs permission" clearly |
| Tree-based pane hierarchy display | Visual clarity of window→pane structure | Low | Current implementation uses tree drawing (├─, └─) |
| Single-command session launch | `spin claude name1 name2 name3` vs manual tmux | Low | Convenience over manual tmux commands |
| Environment variable storage | Persists metadata (CWD) in tmux for later retrieval | Low | Foundation for future features (idle time tracking, session tags) |

## Anti-Features

Features to explicitly NOT build (and why).

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Multi-terminal emulator support | Ghostty abstraction adds complexity; user's tool choice should be respected | Let user script Ghostty window creation; recommend tmux attach for other terminals |
| Session persistence across reboots | tmux handles this natively; duplicating it adds state management burden | Rely on `tmux show-session` and session survival across terminal restarts |
| Custom Claude prompt wrappers | Modifying Claude's CLI adds maintenance burden; breaks with Claude updates | Use Claude's native terminal prompts; analyze pane content instead |
| Real-time alerting system | Would require daemons, listeners, notification system | Use `spin status --once` in cron if polling needed; otherwise dashboard is passive monitor |
| SSH session management | Out of scope; requires network auth, key forwarding, remote tmux | Document workaround: users can tmux attach over SSH manually |
| Session recording/playback | Tmux has built-in logging; adds little value over `tmux capture-pane` | Recommend tmux's logging feature or asciinema for demos |

## Feature Dependencies

```
Launch Sessions (spin claude)
  ↓
Monitor Sessions (spin status) — depends on launched sessions
  ├─ Needs: Process tree inspection (pgrep)
  └─ Needs: Pane content analysis (capture-pane)
      ├─ Detect: Working state
      ├─ Detect: Waiting state
      └─ Detect: Permission state

Reconnect to Session (spin connect)
  ├─ Depends on: Session existence (launched earlier)
  └─ Needs: Ghostty window spawning

Idle State Detection (future)
  ├─ Depends on: Waiting state detection (already exists)
  ├─ Needs: Timestamp tracking (tmux env variables)
  └─ Needs: Time-based state machine
```

## MVP Recommendation

**Current MVP includes:**
1. ✓ Launch parallel sessions (`spin claude`)
2. ✓ Monitor all states (`spin status`)
3. ✓ State detection (working/waiting/permission/exited)

**Next milestone (roadmap Phase 1-2):**
1. Lower refresh interval from 2s to 20s
2. Add `spin connect` subcommand
3. (Conditional) Idle state if testing shows need

**Defer:**
- Multi-terminal support
- Remote session management
- Custom prompts or wrappers
- Alert system
- Session persistence features (tmux native)

## Scalability Considerations

| Concern | At 1-2 sessions | At 5 sessions | At 10+ sessions |
|---------|-----------------|---------------|-----------------|
| Refresh latency | 2s/20s acceptable | 20s still responsive | 20s preferred (less system load) |
| Process tree walk | <10ms per check | <50ms per check | <100ms per check (all session panes) |
| pane content capture | ~1ms per pane | ~5ms per pane | ~10ms per pane (capture-pane scales linearly) |
| Terminal flicker | Noticeable at 2s | Still visible | Becomes distracting (switch to 20s) |
| Dashboard responsiveness | Immediate | Snappy | Good (key reason for 20s change) |

---

## Feature Prioritization for Active Milestone

**Phase 1 (This Week):**
- [ ] Reduce refresh interval 2s → 20s (1 line change, HIGH ROI)

**Phase 2 (Following Week):**
- [ ] Add `spin connect` subcommand (new command, medium effort)

**Phase 3+ (Conditional):**
- [ ] Idle state detection (only if UX testing shows need)
- [ ] Additional state refinements (based on user feedback)

---

*Feature research for: tmux-based parallel session manager*
*Researched: 2026-03-31*
