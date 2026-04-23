# Feature Landscape: GNOME System Tray Indicator

**Domain:** GNOME Shell extension with session state visualization
**Researched:** 2026-03-31

## Table Stakes

Features users expect from a system tray indicator for session management.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **System tray icon in top bar** | Standard GNOME UI pattern for background/system services | Low | `PanelMenu.Button` + `Main.panel.addToStatusArea()` — built-in API |
| **Color-coded state (green/yellow/red)** | Visual affordance to understand session health at a glance | Low | Icon color maps to aggregate state. Green = all idle, Yellow = working, Red = waiting/error |
| **Icon hides when no sessions exist** | Clutter reduction; users expect indicators to only appear when relevant | Low | Simple `if (sessionCount > 0)` toggle to show/hide via `Main.panel.remove()` |
| **Dropdown menu showing all sessions** | Users need to see what sessions exist; critical for multi-session management | Medium | Build `PopupMenu` dynamically from `spin status --json` output; update on timer |
| **Session name and state display in menu** | Users must identify which session is which | Low | Display `[icon] Session Name — State` for each session item |
| **Click-to-open session** | One-click reconnection is core value proposition | Low | `item.connect('activate', ...)` → `spin connect <session>` |

## Differentiators

Features that set Spin apart from generic GNOME extensions.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|----------|-------|
| **Tree-like visual structure (terminal output style)** | Matches `spin status` terminal UI; feels native to existing Spin users | Medium | Optional: render menu items with tree branch characters (`├──`, `└──`). Low priority if timeline tight. |
| **Live polling with 20-second refresh** | Shows real-time session state without user refresh action | Low | Aligns with existing `spin status` interval. `GLib.timeout_add_seconds()` + subprocess polling |
| **Session state icons in menu** | Consistent with terminal `spin status` icons; reinforces visual language | Low | Reuse terminal icon mapping (●, ◉, ○, ⏸); render as Unicode or custom glyphs |
| **Idle duration display in tooltip** | Users understand why a session is idle; helpful for session hygiene | Low | Extract `idle_duration` from `spin status --json`, display in item tooltip or label |
| **Session filtering/search in menu** | For power users with 10+ sessions; quick access without scrolling | High | Optional; defer to v1.2 |
| **Quick launch dialog on Shift+Click** | Alternative UX: show session list in searchable dialog instead of menu | High | Alternative implementation; skip for MVP |
| **Hotkey to launch session** | Power users can open any session without menu navigation | High | Requires keybinding registration with GNOME Settings; skip for MVP |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Remote session support** | Scope creep; Spin is local-only. Adding SSH/remote tmux would double complexity. | Use existing bash constraint: local tmux inspection only. Document as "local sessions only." |
| **Session creation from extension UI** | Duplication of `spin claude`; users should use CLI for setup. | Point users to `spin claude` command for launching new sessions. |
| **Session destruction/killing** | High-risk action; accidental clicks could lose work. Safer to require `spin` CLI. | Require `spin status` menu click to avoid accidents; document that `spin kill <session>` exists in CLI. |
| **Persistent session state in extension** | Would require storing tmux state outside tmux; breaks architecture. | Let tmux handle persistence; extension reads live state only. |
| **Theming/custom colors** | Too much UI surface area for v1.1; uses GNOME theme system. | Use GNOME Shell default theme; defer custom theming to v1.2. |
| **Multi-desktop support (KDE, XFCE)** | Out of scope; AppIndicator adds OS-level complexity. | Recommend GNOME-only for MVP; document as "GNOME 50+ only." |
| **Deep linking to session windows** | Would require reverse-mapping Ghostty window → tmux session; too complex. | Stick with one-click to Ghostty main window; users navigate to session inside. |

## Feature Dependencies

```
System tray icon (base)
  ├── Color-coded state (depends on icon)
  ├── Dropdown menu (depends on icon/button)
  │   ├── Session list (depends on menu)
  │   ├── Session state display (depends on session list)
  │   └── Click-to-open (depends on session list items)
  └── Hide when no sessions (depends on state detection)

Live polling (independent)
  └── Updates all of above on 20s timer
```

## MVP Recommendation

**Phase 1.1 Minimum Viable Product:**
1. System tray icon in top bar
2. Color-coded state (green/yellow/red)
3. Dropdown menu listing all sessions
4. Session name display in menu
5. Click-to-open (launches Ghostty via `spin connect`)
6. Live polling every 20 seconds
7. Icon hides when no sessions

**Complexity estimate:** 200-300 LOC JavaScript

**Out of MVP (defer to v1.2):**
- Tree-like visual structure
- Idle duration in tooltip
- Session filtering/search
- Custom theming
- Multi-desktop support

## State Mapping

| Terminal State | Icon Color | Rationale |
|---|---|---|
| All sessions idle | **Green** ◉ | Healthy state; all sessions are waiting |
| At least one working | **Yellow** ● | Active work happening; no issues |
| At least one waiting | **Red** ◉ | Human intervention needed (permission, input prompt) |
| No sessions | **Hidden** | Indicator disappears; no sessions to manage |

## Sources

- [GNOME Shell Extensions](https://extensions.gnome.org/) — Ecosystem examples: System Monitor Tray, Dash to Panel, Top Bar Organizer
- [Spin v1.0 Status Output](../../lib/spin-status.sh) — Existing feature set to mirror in extension
- [Spin CLI Architecture](../../CLAUDE.md) — Constraints on integration points

---

*Feature research for: GNOME system tray indicator*
*Researched: 2026-03-31*
