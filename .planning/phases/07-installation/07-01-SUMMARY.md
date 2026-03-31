---
phase: 07-installation
plan: 01
subsystem: infra
tags: [makefile, gnome-extensions, readme, installation]

# Dependency graph
requires:
  - phase: 06-session-dropdown
    provides: extension.js and metadata.json in gnome-extension/ directory
provides:
  - Makefile install-extension and uninstall-extension targets
  - EXTENSION_UUID and EXTENSION_DEST variables in Makefile
  - README GNOME Extension Setup section with enable/verify steps
affects: [end-users installing the GNOME extension]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Split install/uninstall into -cli and -extension sub-targets for composability"
    - "EXTENSION_DEST variable for DRY extension path management"

key-files:
  created: []
  modified:
    - Makefile
    - README.md

key-decisions:
  - "Extension installs to ~/.local (no sudo) while CLI installs to /usr/local (may need sudo) — different privilege levels"
  - "make install depends on both install-cli and install-extension for single-command setup"

patterns-established:
  - "Sub-target composition: top-level targets depend on -cli and -extension sub-targets"

requirements-completed: [INST-01, INST-02, INST-03]

# Metrics
duration: 8min
completed: 2026-03-31
---

# Phase 7 Plan 1: Installation Summary

**Makefile extended with GNOME extension install/uninstall targets and README updated with 3-step enable process (CLI + GUI methods)**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-31T17:00:00Z
- **Completed:** 2026-03-31T17:08:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Makefile now deploys gnome-extension/metadata.json and gnome-extension/extension.js to ~/.local/share/gnome-shell/extensions/spin@gsd.local/ on `make install`
- Makefile `make uninstall` removes extension directory via `rm -rf $(EXTENSION_DEST)`
- README documents complete 3-step setup: install → enable (CLI or GUI) → optional restart → verify

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend Makefile with extension install/uninstall targets** - `99718ef` (feat)
2. **Task 2: Add GNOME extension installation section to README** - `3340a58` (docs)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `Makefile` - Added EXTENSION_UUID/EXTENSION_DEST variables, install-cli/install-extension/uninstall-cli/uninstall-extension targets
- `README.md` - Added GNOME Extension Setup section with enable CLI command, GUI method, shell restart steps, and verify command

## Decisions Made
- Extension installs to user-local `~/.local` path (no sudo required) while CLI still installs to PREFIX (may need sudo) — different privilege levels handled correctly by separate sub-targets
- Dropped `sudo` from README `make install`/`make uninstall` examples since extension target runs without privilege (user installs to their own home)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Installation phase complete. Users can now `make install` then `gnome-extensions enable spin@gsd.local` to activate the GNOME tray indicator.
- v1.1 milestone complete: GNOME System Tray Indicator with color-coded state, dropdown menu, and one-click reconnection — fully installable via single make command.

## Self-Check: PASSED

- FOUND: Makefile
- FOUND: README.md
- FOUND: .planning/phases/07-installation/07-01-SUMMARY.md
- FOUND: commit 99718ef (feat: Makefile extension targets)
- FOUND: commit 3340a58 (docs: README GNOME extension setup)

---
*Phase: 07-installation*
*Completed: 2026-03-31*
