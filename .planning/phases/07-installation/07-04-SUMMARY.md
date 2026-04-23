---
phase: 07-installation
plan: 04
subsystem: gnome-extension
tags: [gnome-shell, esm, gjs, extension, makefile]

# Dependency graph
requires:
  - phase: 07-installation-01
    provides: Makefile install-extension target and gnome-extension scaffold
  - phase: 06-session-dropdown
    provides: SpinIndicator business logic (polling, menu, connect)
provides:
  - ESM-format extension.js compatible with GNOME 45+ (gi:// imports, export default class)
  - metadata.json scoped to shell-version 45-48 only
  - Hardened Makefile uninstall-extension with existence check and diagnostic output
affects: [07-installation-UAT, future-gnome-releases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ESM GNOME Shell extension pattern: import from gi:// and resource:// URLs, export default class extending Extension"
    - "Makefile defensive uninstall: existence check before rm with diagnostic output and sudo hint"

key-files:
  created: []
  modified:
    - gnome-extension/extension.js
    - gnome-extension/metadata.json
    - Makefile

key-decisions:
  - "ESM import format required for GNOME 45+: gi://St, gi://Gio, gi://GLib instead of imports.gi destructuring"
  - "shell-version restricted to 45-48 — pre-45 versions use incompatible legacy import system"
  - "Makefile uninstall-extension uses POSIX [ -d ] test with warning + sudo hint when directory absent"

patterns-established:
  - "GNOME 45+ extension: no init(), use export default class extending Extension with enable()/disable()"
  - "Instance state on this._indicator, not module-level variable"

requirements-completed: [INST-01, INST-02]

# Metrics
duration: 8min
completed: 2026-04-01
---

# Phase 07 Plan 04: ESM Extension Rewrite and Uninstall Hardening Summary

**ESM-format GNOME Shell extension with gi:// imports and export default class, fixing GNOME 45+ incompatibility caused by legacy imports.gi syntax**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-01T00:00:00Z
- **Completed:** 2026-04-01T00:08:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Rewrote extension.js from legacy `imports.gi` / standalone functions to ESM `gi://` imports and `export default class SpinExtension extends Extension` — GNOME 45+ will now load the extension without error
- Updated metadata.json to declare shell-version ["45", "46", "47", "48"], removing pre-ESM entries that implied compatibility with incompatible GNOME versions
- Hardened Makefile `uninstall-extension` target to print a diagnostic warning with sudo hint when the extension directory doesn't exist, instead of silently succeeding

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite extension.js to ESM format for GNOME 45+** - `8c6dd66` (feat)
2. **Task 2: Update metadata.json and harden Makefile uninstall** - `b13e280` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `gnome-extension/extension.js` - Full ESM rewrite: gi:// imports, resource:// imports, export default class SpinExtension; all SpinIndicator business logic preserved unchanged
- `gnome-extension/metadata.json` - shell-version updated to ["45", "46", "47", "48"], removed 42/43/44
- `Makefile` - uninstall-extension target now checks directory existence before rm and emits diagnostic

## Decisions Made
- ESM import format (gi://St, gi://Gio, gi://GLib) is the only format accepted by GNOME Shell 45+
- shell-version capped at 48 as forward-compat entries; GNOME doesn't guarantee future compatibility but current stable releases are included
- Used POSIX `[ -d ]` in Makefile (not bash `[[ ]]`) for maximum make compatibility

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. After make install, user runs `gnome-extensions enable spin@gsd.local` and restarts GNOME Shell.

## Next Phase Readiness
- Extension is now GNOME 45+ compatible — ready for UAT: `gnome-extensions enable spin@gsd.local` should succeed
- `make uninstall-extension` will provide clear feedback on directory presence
- All UAT failure conditions from the plan are resolved

---
*Phase: 07-installation*
*Completed: 2026-04-01*
