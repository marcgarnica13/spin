# Roadmap: Spin

**Project:** Spin — Parallel Claude Code Session Manager

## Milestones

- ✅ **v1.0 MVP** — Phases 1-3 (shipped 2026-03-31)
- 🚧 **v1.1 GNOME System Tray Indicator** — Phases 4-7 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-3) — SHIPPED 2026-03-31</summary>

- [x] Phase 1: Status Monitor (1/1 plans) — completed 2026-03-31
- [x] Phase 2: Idle Detection (1/1 plans) — completed 2026-03-31
- [x] Phase 3: Session Reconnection (1/1 plans) — completed 2026-03-31

</details>

### 🚧 v1.1 GNOME System Tray Indicator (In Progress)

**Milestone Goal:** Add a GNOME top bar indicator showing aggregate session state with one-click reconnection via Ghostty.

- [x] **Phase 4: JSON Status Output** — Add `--json` flag to `spin status` as the data bridge for the extension (completed 2026-03-31)
- [ ] **Phase 5: GNOME Extension Core** — Scaffold GNOME Shell extension with live color-coded tray icon
- [ ] **Phase 6: Session Dropdown** — Build interactive dropdown listing sessions with click-to-reconnect
- [ ] **Phase 7: Installation** — Integrate extension into `make install`/`make uninstall` and document setup

## Phase Details

### Phase 4: JSON Status Output
**Goal**: `spin status --json` emits structured session data that can drive the GNOME extension
**Depends on**: Nothing (self-contained CLI change)
**Requirements**: CLI-01, CLI-02
**Success Criteria** (what must be TRUE):
  1. `spin status --json` exits 0 and prints valid JSON to stdout (not human-formatted output)
  2. JSON array contains one object per session with `name`, `state`, `pid`, and `idle_duration` fields
  3. Running `spin status` without `--json` still displays the existing colored terminal dashboard unchanged
  4. JSON output reflects real session states across all four states: working, waiting, permission, exited
**Plans**: 1 plan
Plans:
- [x] 04-01-PLAN.md — Add json_escape(), spin_status_json(), and --json flag to lib/spin-status.sh

### Phase 5: GNOME Extension Core
**Goal**: A GNOME Shell extension is loaded that shows a color-coded spin icon in the top bar whenever sessions exist and hides itself when none do
**Depends on**: Phase 4
**Requirements**: TRAY-01, TRAY-02, TRAY-03, TRAY-04, TRAY-05, TRAY-06
**Success Criteria** (what must be TRUE):
  1. Extension appears in `gnome-extensions list` and can be enabled/disabled without errors
  2. When spin sessions are running, an icon appears in the GNOME top bar
  3. When no spin sessions exist, the icon is absent from the top bar
  4. Icon is green when all sessions are in working/idle state, yellow when any session awaits input, red when any session needs permission approval
  5. Icon color follows red > yellow > green priority (worst session state determines icon color)
**Plans**: TBD
**UI hint**: yes

### Phase 6: Session Dropdown
**Goal**: Clicking the tray icon opens a dropdown that lists all sessions with their states and lets the user open any session in Ghostty with one click
**Depends on**: Phase 5
**Requirements**: DROP-01, DROP-02, DROP-03, DROP-04, DROP-05
**Success Criteria** (what must be TRUE):
  1. Clicking the tray icon opens a dropdown menu listing every active spin session
  2. Each session row shows the session name and a state icon matching the terminal `spin status` visual language
  3. Clicking a session row opens a new Ghostty window connected to that session (equivalent to `spin connect <session>`)
  4. Session list refreshes automatically every 20 seconds without requiring user interaction
  5. Sessions are displayed in a tree-like structure consistent with `spin status` terminal output
**Plans**: TBD
**UI hint**: yes

### Phase 7: Installation
**Goal**: The GNOME extension is deployed alongside the CLI tools via the standard `make install` workflow and users can find setup instructions in the README
**Depends on**: Phase 6
**Requirements**: INST-01, INST-02, INST-03
**Success Criteria** (what must be TRUE):
  1. Running `make install` deploys the extension files to the correct GNOME extension directory
  2. Running `make uninstall` removes all extension files cleanly, leaving no orphaned files
  3. README contains step-by-step instructions for enabling the extension after installation
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Status Monitor | v1.0 | 1/1 | Complete | 2026-03-31 |
| 2. Idle Detection | v1.0 | 1/1 | Complete | 2026-03-31 |
| 3. Session Reconnection | v1.0 | 1/1 | Complete | 2026-03-31 |
| 4. JSON Status Output | v1.1 | 1/1 | Complete   | 2026-03-31 |
| 5. GNOME Extension Core | v1.1 | 0/? | Not started | - |
| 6. Session Dropdown | v1.1 | 0/? | Not started | - |
| 7. Installation | v1.1 | 0/? | Not started | - |

---

*Roadmap created: 2026-03-31*
*Last updated: 2026-03-31 (v1.1 milestone planned)*
*Updated: 2026-03-31 — Phase 4 planned (1 plan)*
