---
phase: 05-gnome-extension-core
plan: 02
subsystem: gnome-extension
tags: [gnome, gjs, subprocess, state-aggregation, icon-color]
dependency_graph:
  requires:
    - 05-01  # Extension skeleton with PanelMenu.Button structure
    - 04-01  # spin status --json CLI output
  provides:
    - async Gio.Subprocess polling of spin status --json
    - _aggregateState() priority logic (error > waiting > working > idle)
    - _stateToIconName() mapping to GNOME symbolic icons
    - show/hide indicator based on session count
  affects:
    - gnome-extension/extension.js
tech_stack:
  added: []
  patterns:
    - Gio.Subprocess.new + communicate_utf8_async for non-blocking subprocess I/O
    - GLib.find_program_in_path() for portable CLI path resolution
    - Priority aggregation with early-exit for highest-severity state
key_files:
  created: []
  modified:
    - gnome-extension/extension.js
decisions:
  - Use Gio.Subprocess.new (not GLib.spawn_command_line_sync) to keep GNOME Shell main thread unblocked
  - GLib.find_program_in_path('spin') at constructor time, fallback to bare 'spin' string
  - Early-exit loop on permission/exited (return 'error' immediately, stop iterating)
metrics:
  duration_seconds: 75
  completed_date: "2026-03-31"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 1
requirements:
  - TRAY-02
  - TRAY-03
  - TRAY-04
  - TRAY-05
  - TRAY-06
---

# Phase 05 Plan 02: Async Subprocess Polling and Icon State Logic Summary

**One-liner:** Async Gio.Subprocess polling of `spin status --json` with priority-based state aggregation mapping session states to GNOME symbolic icon colors.

## What Was Built

Replaced the stub `_refreshState()` from Plan 01 with a complete async polling implementation:

- `_refreshState()` — spawns `spin status --json` via `Gio.Subprocess.new` with `STDOUT_PIPE | STDERR_SILENCE`, reads stdout asynchronously via `communicate_utf8_async`, parses JSON, and calls `_updateUI()`. On any error, hides the indicator.
- `_updateUI(sessions)` — hides indicator on empty array (no sessions); on non-empty, shows indicator and sets icon name based on aggregate state.
- `_aggregateState(sessions)` — iterates sessions applying red > yellow > green priority: returns `'error'` immediately on first `permission` or `exited` state; upgrades to `'waiting'` on `waiting`; upgrades to `'working'` only if still `'idle'`.
- `_stateToIconName(aggregateState)` — maps four aggregate states to GNOME symbolic icon names: `dialog-error-symbolic` (red), `dialog-warning-symbolic` (amber), `spinner` (active), `dialog-information-symbolic` (grey).
- Constructor updated with `this._spinPath = GLib.find_program_in_path('spin') || 'spin'` for portable path resolution.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement async spin polling and visibility logic | 732812e | gnome-extension/extension.js |
| 2 | Verify extension in live GNOME Shell | (auto-approved) | — |

## Deviations from Plan

None — plan executed exactly as written.

## Checkpoint Notes

Task 2 (human-verify) was auto-approved per `auto_advance: true` configuration. Live GNOME Shell verification (icon visibility, color behavior across session states) requires a running GNOME desktop session and should be performed manually before shipping.

## Known Stubs

None. All logic paths are wired: subprocess spawn → JSON parse → state aggregation → icon name lookup → icon_name assignment.

## Self-Check: PASSED

- gnome-extension/extension.js contains all required methods and patterns
- Commit 732812e exists in git log
- All 11 acceptance criteria verified with grep checks (all PASS)
- File is 158 lines (requirement: >= 130)
