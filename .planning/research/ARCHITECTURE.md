# Architecture Patterns: GNOME System Tray Indicator

**Domain:** GNOME Shell extension for session monitoring and connection
**Researched:** 2026-03-31

## Recommended Architecture

```
GNOME Shell (Display Server)
  │
  ├── Extension Process (GJS/JavaScript in GNOME 50 runtime)
  │   │
  │   ├── extension.js (Extension class, entry point)
  │   ├── ui/statusIcon.js (Icon color logic)
  │   ├── ui/panelMenu.js (Menu rendering)
  │   └── lib/statusParser.js (JSON parsing)
  │
  └── [Subprocess] → spin status --json (Bash CLI)
        │
        └── [Read] → tmux session state
              │
              └── [IPC] → tmux socket at /tmp/tmux-*/
                    │
                    └── [Inspect] → /proc/$pid/cmdline, pane content

User Click → PanelMenu.activate() → [Subprocess] → spin connect <session>
  │
  └── [Execute] → ghostty -e tmux attach -t <session>
```

## Component Boundaries

| Component | Responsibility | Communicates With | Technology |
|-----------|---------------|-------------------|-----------|
| **extension.js** | Extension lifecycle (enable/disable), main loop integration | GNOME Shell API, ui/* modules | GJS, PanelMenu, GLib |
| **ui/statusIcon.js** | Map session state → icon color/visibility | statusParser.js, extension.js | GJS, St.Icon |
| **ui/panelMenu.js** | Render menu items dynamically from status | statusParser.js, extension.js | GJS, PopupMenu |
| **lib/statusParser.js** | Parse `spin status --json` output into data structure | subprocess stdout | JavaScript |
| **spin status --json** | Query tmux for session state, output JSON | tmux CLI | Bash 4+ |
| **spin connect <session>** | Open Ghostty window attached to session | tmux, ghostty | Bash 4+, Ghostty |

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Extension Startup (enable())                                │
├─────────────────────────────────────────────────────────────┤
│ 1. Create PanelMenu.Button()                                │
│ 2. Add St.Icon() with status color                          │
│ 3. Create PopupMenu instance                                │
│ 4. Register GLib.timeout_add_seconds(20, updateStatus)      │
│ 5. Return early; timer will trigger first update            │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ Every 20 Seconds (updateStatus callback)                    │
├─────────────────────────────────────────────────────────────┤
│ 1. Spawn: Gio.Subprocess(['spin', 'status', '--json'])      │
│ 2. Wait: communicate_utf8_async() → collect stdout          │
│ 3. Parse: JSON.parse(stdout) → [{name, state, pid}, ...]    │
│ 4. Update icon color based on aggregate state               │
│ 5. Rebuild menu: remove old items, add new from JSON        │
│ 6. Connect activate handlers to items                       │
│ 7. Return GLib.SOURCE_CONTINUE to keep polling              │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ User Clicks Menu Item                                       │
├─────────────────────────────────────────────────────────────┤
│ 1. activate signal fires on PopupMenuItem                   │
│ 2. Handler extracts session name                            │
│ 3. Spawn: Gio.Subprocess(['spin', 'connect', name])         │
│ 4. Don't wait; let subprocess run in background             │
│ 5. Menu closes naturally                                    │
│ 6. Ghostty window opens (user sees new terminal)            │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ Extension Shutdown (disable())                              │
├─────────────────────────────────────────────────────────────┤
│ 1. GLib.source_remove(updateStatusId)                       │
│ 2. Main.panel.remove(indicator)                             │
│ 3. Cleanup: null out references (good practice)             │
└─────────────────────────────────────────────────────────────┘
```

## Patterns to Follow

### Pattern 1: ESM Module Imports (GNOME 45+)

**What:** Use ES6 `import` statements; never use legacy `imports.ui`

**When:** All GNOME Shell extensions targeting GNOME 45 or later (mandatory)

**Example:**
```javascript
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import Gio from 'gi://Gio';

export default class SpinExtension extends Extension {
  // ...
}
```

### Pattern 2: Async Subprocess with Promisified Methods

**What:** Use `Gio._promisify()` to convert callback-based async to async/await

**When:** Spawning external processes; cleaner code, easier error handling

**Example:**
```javascript
Gio._promisify(Gio.Subprocess.prototype, 'communicate_utf8_async');

async _updateStatus() {
  try {
    const proc = Gio.Subprocess.new(
      ['spin', 'status', '--json'],
      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
    );
    const [stdout] = await proc.communicate_utf8_async(null, null);
    const status = JSON.parse(stdout);
    this._renderMenu(status);
  } catch (error) {
    console.error('Failed to get status:', error);
  }
}
```

### Pattern 3: GLib Main Loop Integration for Polling

**What:** Use `GLib.timeout_add_seconds()` for periodic tasks; always remove in `disable()`

**When:** Anything that needs to repeat (polling, timers, refresh)

**Example:**
```javascript
enable() {
  this._updateStatusId = GLib.timeout_add_seconds(
    GLib.PRIORITY_DEFAULT,
    20,
    () => {
      this._updateStatus();
      return GLib.SOURCE_CONTINUE;  // Keep polling
    }
  );
  this._updateStatus();  // Run once immediately
}

disable() {
  if (this._updateStatusId) {
    GLib.source_remove(this._updateStatusId);
    this._updateStatusId = null;
  }
}
```

### Pattern 4: Dynamic Menu Population with Event Handlers

**What:** Clear menu, rebuild from data, connect handlers to each item

**When:** Data changes (status update, user input) and menu needs refresh

**Example:**
```javascript
_renderMenu(status) {
  this.menu.removeAll();
  
  if (status.length === 0) {
    this.menu.addMenuItem(new PopupMenu.PopupMenuItem('No sessions'));
    this._showIndicator(false);
    return;
  }
  
  this._showIndicator(true);
  
  for (const session of status) {
    const item = new PopupMenu.PopupMenuItem(
      `${session.name} — ${session.state}`
    );
    item.connect('activate', () => this._connectSession(session.name));
    this.menu.addMenuItem(item);
  }
}
```

### Pattern 5: Resource Cleanup on disable()

**What:** Remove all listeners, timers, and UI elements in `disable()`

**When:** Extension is disabled or GNOME Shell restarts

**Example:**
```javascript
disable() {
  if (this._updateStatusId) {
    GLib.source_remove(this._updateStatusId);
    this._updateStatusId = null;
  }
  
  // Disconnect all signal handlers
  this._signalConnections?.forEach(id => {
    this._indicator?.disconnect(id);
  });
  this._signalConnections = [];
  
  // Remove UI elements
  if (this._indicator) {
    Main.panel.statusArea.remove(this._indicator);
    this._indicator = null;
  }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Blocking the Main Loop with Synchronous Subprocess

**What:** Using `Gio.Subprocess.new()` without async, or calling `wait()` on same thread

**Why bad:** Freezes GNOME Shell UI for 100+ ms while waiting for subprocess. Users see laggy indicator.

**Instead:** Always use `communicate_utf8_async()` with async/await; execution continues on main loop

### Anti-Pattern 2: Forgetting to Remove Timers in disable()

**What:** Creating GLib timeouts but not removing them in `disable()`

**Why bad:** Timeouts keep firing after extension disables, causing memory leaks and crashes

**Instead:** Store timeout ID, always call `GLib.source_remove()` in `disable()`

### Anti-Pattern 3: Updating Menu Without Clearing Old Items

**What:** Calling `this.menu.addMenuItem()` repeatedly without `removeAll()`

**Why bad:** Menu grows unbounded; old items leak memory; duplicate entries visible

**Instead:** Call `this.menu.removeAll()` before rebuilding from data

### Anti-Pattern 4: Parsing JSON with String Manipulation

**What:** Using regex or substring operations on subprocess output

**Why bad:** Fragile, error-prone, hard to maintain when output changes

**Instead:** Always `JSON.parse()` structured output; structure is contract

### Anti-Pattern 5: Legacy imports (`imports.ui`)

**What:** Using `const Main = imports.ui.main` instead of ESM imports

**Why bad:** Broken in GNOME 45+; extension fails to load

**Instead:** Use `import * as Main from 'resource:///org/gnome/shell/ui/main.js'`

## Scalability Considerations

| Concern | At 1-5 Sessions | At 10-20 Sessions | At 100+ Sessions |
|---------|-----------------|-------------------|------------------|
| **Menu rendering time** | <10ms, instant | ~20ms, perceptible | ~100ms, noticeable lag |
| **Subprocess spawn overhead** | Minimal (~1ms) | Acceptable | Consider caching |
| **JSON parse time** | <1ms | <5ms | <10ms |
| **Memory footprint** | ~5MB | ~8MB | ~15MB |
| **Polling frequency impact** | 20s safe | 20s safe | Consider 30-60s interval |
| **Recommended action** | Use as-is | Use as-is | Add session filtering/search |

**Current design targets 5-20 sessions.** If users run 100+:
- Implement session filtering (show only "active" sessions)
- Allow customizing refresh interval via preferences
- Cache subprocess output between timer ticks
- Add quick-search dialog (Shift+Click)

## Error Handling Strategy

| Error | Current Handling | User Impact | Mitigation |
|-------|------------------|-------------|------------|
| **`spin status --json` command not found** | Silent fail, menu shows "No sessions" | Confusing; looks like no sessions active | Check `$PATH`, show notification if spinning not installed |
| **Invalid JSON output** | Catch parse error, log to console | Icon appears, clicking does nothing | Add debug logging, validate schema |
| **`spin connect` fails** | Fire subprocess, ignore exit code | User sees Ghostty error | Log stderr, (optional) show GNOME notification |
| **tmux socket missing** | `spin status` returns empty JSON | Icon hides; appears healthy | Document that tmux must be running |
| **subprocess timeout** | GIO has built-in timeout handling | Long gap between updates | Use `communicate_utf8_async()` with timeout parameter |

## Extension vs Daemon Decision

**Why not a persistent daemon in bash?**

1. **Adds complexity:** Daemon lifecycle, socket management, crash recovery
2. **Breaks Spin philosophy:** Stateless, simple CLI tool
3. **Unnecessary:** Polling from extension is simpler and sufficient
4. **Less integrated:** Extension lives in GNOME; daemon is separate process
5. **Harder to distribute:** Daemon requires systemd unit or similar

**Why subprocess polling is better:**

1. **No extra processes:** Only subprocess runs on demand
2. **Clean integration:** Extension lifecycle tied to GNOME Shell
3. **Simple testing:** `spin status --json` output is testable
4. **Stateless:** No daemon state to manage
5. **Portable:** Works on any Linux with tmux + bash

## Testing Strategy

| Scenario | Test Approach | Success Criteria |
|----------|---------------|------------------|
| **Extension loads** | `gnome-extensions list` shows spin enabled | Extension appears in list |
| **Icon appears in top bar** | Launch GNOME Shell, check panel | Icon visible with correct color |
| **Status polling works** | Watch icon color change as sessions start/stop | Color updates within 20s |
| **Menu renders correctly** | Click icon, inspect menu items | All sessions listed with correct names |
| **Click-to-open works** | Click menu item, observe Ghostty | Window opens, tmux attached to correct session |
| **Cleanup on disable** | Disable extension, check `ps aux` | No subprocess processes left running |

## Sources

- [GNOME JavaScript: Extension Development](https://gjs.guide/extensions/development/creating.html) — Module structure, lifecycle
- [GNOME JavaScript: Subprocess Execution](https://gjs.guide/guides/gio/subprocesses.html) — Process spawning patterns
- [GNOME JavaScript: PanelMenu and PopupMenu](https://gjs.guide/extensions/topics/popup-menu.html) — UI patterns
- [GNOME Shell Extensions Review Guidelines](https://gjs.guide/extensions/review-guidelines/review-guidelines.html) — Cleanup requirements, resource management

---

*Architecture research for: GNOME system tray indicator*
*Researched: 2026-03-31*
