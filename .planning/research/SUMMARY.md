# Research Summary: GNOME System Tray Indicator for Spin

**Domain:** GNOME Shell Extension with dropdown menu for session management
**Researched:** 2026-03-31
**Overall confidence:** HIGH

## Executive Summary

Spin v1.1 adds a GNOME top bar indicator showing aggregate session state and enabling one-click reconnection. This requires a GNOME Shell extension written in GJS/JavaScript (official platform standard), integrated with the existing bash CLI via subprocess polling and JSON output.

The technology landscape is clear: GNOME 50 is the current standard, ESM modules are mandatory for extensions (since GNOME 45), and native Shell extensions are superior to AppIndicator both in capability and complexity. The integration pattern is straightforward—the extension spawns `spin status --json` on a 20-second timer, parses the output, and calls `spin connect <session>` on click.

No new external dependencies are required. The existing bash CLI remains pure and untouched in core logic; only a `--json` output flag is added to `spin status`. This keeps the architecture clean and maintainable.

## Key Findings

**Stack:** Native GNOME Shell extension (GJS 1.78+, GNOME 50+) with Gio.Subprocess for bash integration
**Integration:** Subprocess polling (20s interval) + JSON output. No D-Bus services, no daemons
**Architecture:** Extension at `~/.local/share/gnome-shell/extensions/spin@example.local/`, calls `spin status --json` and `spin connect` via Gio.Subprocess
**Critical limitation:** No alternative UI frameworks exist; GNOME Shell extension is the only path for top bar integration

## Implications for Roadmap

Based on research, the phase structure should be:

### Phase 1: Bash CLI Extension (Foundation)
**Goal:** Add `--json` output to existing `spin status` command
- Adds `--json` flag to output current session state as JSON array
- Parses existing status detection logic (state, pid, idle)
- No changes to core session management
- Tests: Verify JSON structure with multiple session states
- **Risk:** None. Backwards compatible, isolated change

### Phase 2: GNOME Shell Extension Scaffolding (Boilerplate)
**Goal:** Create extension structure, metadata, and basic panel button
- Create directory: `~/.local/share/gnome-shell/extensions/spin@example.local/`
- Write `metadata.json` (UUID, GNOME 50+ only, description)
- Write `extension.js` with `enable()`, `disable()`, and `PanelMenu.Button`
- Write `ui/statusIcon.js` for icon color logic
- Write `lib/statusParser.js` for JSON parsing
- Tests: Verify extension loads, button appears in top bar (no functionality yet)
- **Risk:** Low. Standard GNOME extension patterns, well-documented APIs

### Phase 3: Status Polling and Icon Updates
**Goal:** Call `spin status --json`, parse output, update icon color every 20 seconds
- Implement polling timer with `GLib.timeout_add_seconds()`
- Spawn subprocess: `spin status --json` via `Gio.Subprocess`
- Parse JSON output, extract aggregate state (green/yellow/red/hidden)
- Update icon color based on state using St.Icon
- Tests: Mock subprocess output, verify icon color changes; verify timer cleanup on disable
- **Risk:** Moderate. Async subprocess handling and GLib main loop integration; but patterns are documented

### Phase 4: Dropdown Menu with Sessions
**Goal:** Build clickable session menu showing current sessions and states
- Populate `PopupMenu` with session items from status JSON
- Each item shows session name and color-coded state icon
- Add visual tree structure (optional: match `spin status` terminal output)
- Tests: Verify menu opens, items render correctly for 0, 1, 5+ sessions
- **Risk:** Low. Standard PopupMenu patterns; UI complexity is moderate

### Phase 5: One-Click Session Connection
**Goal:** Implement click handler to open Ghostty window via `spin connect`
- Connect `activate` signal on each menu item
- Spawn subprocess: `spin connect <session>` via `Gio.Subprocess`
- Handle subprocess errors gracefully (silent fail or user notification)
- Tests: Verify Ghostty window opens; verify correct session is passed; verify no subprocess errors block UI
- **Risk:** Low. Reuses existing `spin connect` command; minimal new logic

### Phase 6: Installation and Distribution
**Goal:** Integrate extension into spin installation
- Update `Makefile` to install extension to system-wide directory (optional user install)
- Add `gnome-extensions enable` to installer script
- Document extension setup in README
- Tests: Verify `make install` deploys extension correctly; verify `gnome-extensions disable/enable` works
- **Risk:** Low. Standard extension packaging; distro-independent

### Phase 7: Preferences and Configuration (Stretch)
**Goal:** Allow user customization via GSettings
- Create `schemas/org.gnome.shell.extensions.spin.gschema.xml`
- Add preferences UI in extension (refresh interval, session filter, icon style)
- Store preferences in GSettings/dconf
- Tests: Verify preferences persist; verify UI reflects settings
- **Risk:** Low. GSettings is standard GNOME pattern; not critical for MVP
- **Recommendation:** Defer to v1.2 if timeline is tight

## Phase Ordering Rationale

1. **CLI extension first** (Phase 1) — Unblocks extension development; simple, low-risk foundation
2. **Extension boilerplate second** (Phase 2) — Establish GNOME integration; validates development environment
3. **Polling and status** (Phase 3) — Core value: show live state; heaviest technical lift but well-documented
4. **Menu and UI** (Phase 4, 5) — Build on polling; straightforward PopupMenu usage
5. **Installation** (Phase 6) — Defer to avoid blocking core feature development; standard packaging
6. **Preferences** (Phase 7) — Polish; not critical for MVP

This order ensures rapid value delivery (icon + menu in phases 3-5) before installation complexity (phase 6).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | GNOME 50 is current standard. GJS/ESM mandatory and stable. APIs (PanelMenu, Gio.Subprocess) well-documented. |
| Integration Pattern | **HIGH** | Subprocess polling with JSON output is straightforward, proven pattern in GNOME extensions. No blockers identified. |
| Architecture | **HIGH** | Clean separation: extension spawns bash commands, bash returns data. No daemon, no new IPC infrastructure. |
| Feasibility | **HIGH** | All required APIs are built into GNOME 50. No third-party libraries needed. Extension development is mature. |
| Implementation | **HIGH** | Patterns documented in official GNOME JavaScript guide. Example extensions available for reference. |

## Gaps to Address

- **Version compatibility:** Research assumes GNOME 50+. If user has GNOME 40-47, extension requires legacy imports (not ESM). Recommend GNOME 50+ as minimum target; mention in documentation.
- **Alternative terminal emulators:** Extension currently hardcoded to use `spin connect` (which uses Ghostty). If future requirement to support other terminals, will need to parameterize terminal in extension preferences.
- **Extension marketplace:** Research did not detail publishing to extensions.gnome.org. For v1.1 MVP, recommend distributing via GitHub; marketplace publication deferred to v1.2.
- **Error handling in subprocess:** What happens if `spin status --json` fails? Current research recommends silent fail (no UI notification); refine error strategy in Phase 3.
- **Performance at scale:** Subprocess polling every 20 seconds adds ~1-2ms per cycle. Research did not benchmark; confirm acceptable in Phase 3 integration testing.

## Recommended Development Environment

- **OS:** Linux (GNOME 50 required; Ubuntu 26.04, Fedora 44, or Arch with GNOME 50)
- **Editor:** GNOME Builder or VS Code with GNOME Shell extension support
- **Testing:** `dbus-run-session gnome-shell` to test in isolated session
- **No additional package dependencies** — all tools and libraries are built into GNOME 50

## Sources

- [GNOME JavaScript Guide: Extension Development](https://gjs.guide/extensions/development/creating.html) — Official source for extension structure, ESM modules, API reference
- [GNOME JavaScript: PanelMenu and PopupMenu](https://gjs.guide/extensions/topics/popup-menu.html) — Official source for UI patterns
- [GNOME JavaScript: Subprocess Execution](https://gjs.guide/guides/gio/subprocesses.html) — Official source for process spawning
- [GNOME Shell Extensions Review Guidelines](https://gjs.guide/extensions/review-guidelines/review-guidelines.html) — Best practices for extension cleanup and resource management
- [GNOME 45 Extension Migration Guide](https://gjs.guide/extensions/upgrading/gnome-shell-45.html) — ESM module requirements and breaking changes
- [GNOME 50 Release Notes](https://release.gnome.org/50/) — Current target version, API stability
- [AppIndicator Support Extension](https://extensions.gnome.org/extension/615/appindicator-support/) — Context for why native extension is better
- [GitHub: Ubuntu gnome-shell-extension-appindicator](https://github.com/ubuntu/gnome-shell-extension-appindicator) — Reference implementation for AppIndicator (for comparison)

---

*Research Summary for: Spin v1.1 GNOME System Tray Indicator*
*Researched: 2026-03-31*
