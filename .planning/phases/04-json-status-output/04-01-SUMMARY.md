---
phase: 04-json-status-output
plan: 01
subsystem: api
tags: [bash, json, tmux, spin-status]

# Dependency graph
requires: []
provides:
  - "spin_json_escape() helper for safe JSON string embedding in bash"
  - "spin_status_json() function emitting structured JSON array of all spin sessions"
  - "--json flag in spin_status() delegating to spin_status_json()"
affects: [05-gnome-extension]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "JSON output via printf format strings (no color variables, no ANSI codes)"
    - "Numeric coercion with $((var + 0)) for tmux environment variable values"
    - "tmux -VARNAME unset guard using [[ var == -* ]] pattern"

key-files:
  created: []
  modified:
    - lib/spin-status.sh

key-decisions:
  - "idle_duration emits raw poll count (1 poll ≈ 20s), not seconds — Phase 5 must account for this"
  - "window field added to JSON schema (not in original spec) to allow callers to address individual windows within a session"
  - "-* prefix guard on unchanged_polls handles tmux returning -VARNAME when env var is unset"
  - "--json branch checked first in spin_status() so it's a clean exit path before --once or auto-refresh"

patterns-established:
  - "JSON output: use printf format strings, never echo with color variables"
  - "Numeric guard: pane_pid=$((pane_pid + 0)) to coerce empty/missing tmux values to 0"

requirements-completed: [CLI-01, CLI-02]

# Metrics
duration: 5min
completed: 2026-03-31
---

# Phase 4 Plan 1: JSON Status Output Summary

**`spin status --json` emits a structured JSON array of session objects (name, window, state, pid, idle_duration) parseable by jq and consumable by the Phase 5 GNOME extension**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-31T15:35:35Z
- **Completed:** 2026-03-31T15:41:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added `spin_json_escape()` helper with 5 escape substitutions (backslash, double-quote, newline, carriage-return, tab)
- Added `spin_status_json()` that mirrors `spin_status_once()` logic without any ANSI codes or terminal icons
- Wired `--json` flag into `spin_status()` as the first branch (before `--once` and auto-refresh)
- All backwards-compatible: `spin status` and `spin status --once` behavior unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Add spin_json_escape() and spin_status_json()** - `018f738` (feat)
2. **Task 2: Wire --json flag into spin_status()** - `274cf96` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `lib/spin-status.sh` - Added spin_json_escape(), spin_status_json(), and --json flag in spin_status()

## Decisions Made
- `idle_duration` field emits raw poll count (1 poll ≈ 20s), not seconds. Phase 5 GNOME extension must convert if it needs wall-clock duration.
- `window` field was added to each JSON object (not in original spec). This allows callers to target individual tmux windows within a session, which is useful for the extension's per-window indicators.
- The `-*` prefix guard on `unchanged_polls` is required because tmux `show-environment` returns `-VARNAME` (with leading dash) when the variable is not set, rather than an empty string.
- `--json` branch is checked before `--once` in `spin_status()` so it exits cleanly without any terminal setup code running.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `spin status --json` is fully operational; Phase 5 GNOME extension can poll it every 20s
- JSON schema: `[{ "name": string, "window": string, "state": "working"|"waiting"|"permission"|"exited"|"idle", "pid": int, "idle_duration": int }]`
- Extension must handle `idle_duration` as raw poll count (multiply by 20 for seconds)
- Extension requires GNOME 50+; user must confirm GNOME version before Phase 5 begins

## Self-Check: PASSED

All files present and commits verified.

---
*Phase: 04-json-status-output*
*Completed: 2026-03-31*
