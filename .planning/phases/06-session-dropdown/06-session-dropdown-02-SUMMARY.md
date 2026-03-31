---
phase: 06-session-dropdown
plan: 02
subsystem: ui
tags: [gnome-shell, gjs, popup-menu, extension, tray-indicator]

# Dependency graph
requires:
  - phase: 06-session-dropdown-01
    provides: _buildMenu(), _connectToSession(), PopupSubMenuMenuItem structure
  - phase: 05-gnome-extension-core
    provides: SpinIndicator class, polling lifecycle, _updateUI()
provides:
  - Open-menu guard preventing flicker during 20s background polls
  - Menu cleanup in disable() before destroy() to prevent memory leaks
  - Complete Phase 6 hardened dropdown lifecycle
affects: [future gnome extension phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Open-menu guard: check this.menu.isOpen before structural rebuild to prevent user-visible flicker"
    - "Lifecycle ordering: stopPolling → removeAll → destroy for clean extension disable"

key-files:
  created: []
  modified:
    - gnome-extension/extension.js

key-decisions:
  - "Icon color (icon_name) updates even when menu is open; only structural _buildMenu() is guarded — keeps the tray icon live"
  - "removeAll() in disable() called on _indicator.menu before destroy() for deterministic cleanup ordering"

patterns-established:
  - "Guard pattern: if (!this.menu.isOpen) { this._buildMenu(sessions); } — prevents flicker when polling fires mid-interaction"
  - "Cleanup ordering in disable(): stop timers → remove menu items → destroy widget → null reference"

requirements-completed: [DROP-05]

# Metrics
duration: 5min
completed: 2026-03-31
---

# Phase 6 Plan 02: Session Dropdown Hardening Summary

**Open-menu guard added to _updateUI() prevents dropdown flicker during 20s polls, and disable() now calls removeAll() before destroy() for deterministic memory cleanup**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-31T16:34:17Z
- **Completed:** 2026-03-31T16:39:00Z
- **Tasks:** 1 (Task 2 auto-approved via auto-mode)
- **Files modified:** 1

## Accomplishments

- Added `if (!this.menu.isOpen)` guard in `_updateUI()` — icon color still updates but structural rebuild is skipped while user has dropdown open
- Added `_indicator.menu.removeAll()` call in module-level `disable()` before `_indicator.destroy()` to prevent menu item memory leaks
- Phase 6 complete: full dropdown lifecycle implemented and hardened

## Task Commits

Each task was committed atomically:

1. **Task 1: Add open-menu guard to _updateUI() and removeAll() to disable()** - `ae2e426` (feat)
2. **Task 2: Human verify full dropdown flow in live GNOME Shell** - auto-approved (checkpoint:human-verify, auto-mode)

**Plan metadata:** (docs commit — this file)

## Files Created/Modified

- `gnome-extension/extension.js` - Added open-menu guard in `_updateUI()` and `removeAll()` in `disable()`

## Decisions Made

- Icon color (`icon_name`) continues to update even when menu is open — only the structural `_buildMenu()` call is guarded. This keeps the tray icon live and accurate without disrupting the open dropdown.
- `removeAll()` in `disable()` is called on `_indicator.menu` directly (not via a method on SpinIndicator) — consistent with direct cleanup before `destroy()`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 6 complete: full GNOME Shell extension with tray icon + clickable dropdown + auto-refresh
- Extension hardened against menu flicker and memory leaks on disable
- Ready for v1.1 milestone completion review

---
*Phase: 06-session-dropdown*
*Completed: 2026-03-31*
