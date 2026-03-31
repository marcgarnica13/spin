# Requirements: Spin

**Defined:** 2026-03-31
**Core Value:** Effortless management of parallel Claude Code sessions — launch, monitor, and reconnect without manual tmux juggling.

## v1.1 Requirements

Requirements for GNOME System Tray Indicator. Each maps to roadmap phases.

### CLI

- [x] **CLI-01**: spin status supports --json flag outputting session states as structured JSON
- [x] **CLI-02**: JSON output includes session name, state, pid, and idle duration for each session

### Tray Icon

- [x] **TRAY-01**: GNOME Shell extension displays icon in top bar when spin sessions exist
- [x] **TRAY-02**: Icon is hidden when no spin sessions are running
- [x] **TRAY-03**: Icon shows green when all sessions are working
- [x] **TRAY-04**: Icon shows yellow when any session needs user input
- [x] **TRAY-05**: Icon shows red when any session needs permission approval
- [x] **TRAY-06**: Icon color priority: red > yellow > green (worst state wins)

### Dropdown Menu

- [ ] **DROP-01**: Clicking the icon opens a dropdown menu listing all active sessions
- [ ] **DROP-02**: Each session shows name and current state with matching status icon
- [ ] **DROP-03**: Dropdown uses tree-like visual structure matching spin status terminal output
- [ ] **DROP-04**: Clicking a session spawns spin connect to open Ghostty window
- [ ] **DROP-05**: Session list auto-refreshes every 20 seconds via polling

### Installation

- [ ] **INST-01**: make install deploys GNOME extension alongside CLI tools
- [ ] **INST-02**: make uninstall removes GNOME extension cleanly
- [ ] **INST-03**: README documents manual extension installation and enabling

## v1.2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Preferences

- **PREF-01**: User can configure refresh interval via GSettings
- **PREF-02**: User can configure icon style/theme

### Advanced Features

- **ADV-01**: Session filtering/search in dropdown for power users
- **ADV-02**: Idle duration display in tooltip
- **ADV-03**: Keyboard shortcut to open dropdown

## Out of Scope

| Feature | Reason |
|---------|--------|
| Session creation from extension UI | Duplication of `spin claude`; users should use CLI for setup |
| Session killing from extension UI | High-risk action; accidental clicks could lose work |
| Remote session support | Spin is local-only; adding SSH/remote tmux doubles complexity |
| Multi-desktop support (KDE, XFCE) | GNOME-only for now; AppIndicator adds OS-level complexity |
| Custom theming/colors | Uses GNOME Shell default theme; defer to v1.2 |
| extensions.gnome.org publishing | Distribute via GitHub for v1.1; marketplace deferred to v1.2 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLI-01 | Phase 4 | Complete |
| CLI-02 | Phase 4 | Complete |
| TRAY-01 | Phase 5 | Complete |
| TRAY-02 | Phase 5 | Complete |
| TRAY-03 | Phase 5 | Complete |
| TRAY-04 | Phase 5 | Complete |
| TRAY-05 | Phase 5 | Complete |
| TRAY-06 | Phase 5 | Complete |
| DROP-01 | Phase 6 | Pending |
| DROP-02 | Phase 6 | Pending |
| DROP-03 | Phase 6 | Pending |
| DROP-04 | Phase 6 | Pending |
| DROP-05 | Phase 6 | Pending |
| INST-01 | Phase 7 | Pending |
| INST-02 | Phase 7 | Pending |
| INST-03 | Phase 7 | Pending |

**Coverage:**
- v1.1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 — traceability updated after roadmap creation*
