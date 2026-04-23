# Stack Research: GNOME System Tray Indicator

**Domain:** GNOME Shell Extension for system tray status indicator with dropdown menu
**Researched:** 2026-03-31
**Confidence:** HIGH

## Executive Summary

Add a GNOME Shell extension (written in GJS/JavaScript) that displays a system tray icon in the top bar with color-coded session state and a dropdown menu for one-click session connection. The extension bridges the existing bash CLI (`spin status`) with GNOME Shell's panel via subprocess execution and file polling.

**Technology Stack Decision:** GNOME Shell Extension (native) over AppIndicator because:
- GNOME 50+ standardized on ESM modules and native extensions
- AppIndicator relies on deprecated DBus interface
- AppIndicator requires separate library and extension enablement
- Direct extension approach gives full UI control and simpler distribution

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **GNOME Shell Extension Framework** | 50+ | Native panel integration | Standard GNOME architecture. ESM module system (GNOME 45+) is stable. Extensions are first-class citizens in GNOME UI. |
| **GJS (GNOME JavaScript)** | 1.78+ | JavaScript runtime for extensions | Official GNOME language bindings. Full access to Shell APIs. Better DX than C/Vala for UI. |
| **ES6 Modules (ESM)** | GNOME 45+ | Extension module system | Mandatory in GNOME 45+. Modern JavaScript standard. Better than legacy imports. |
| **PanelMenu (Shell UI)** | Built-in | Create top bar button and dropdown menu | Standard GNOME pattern. `PanelMenu.Button` provides button + menu + activate signals. |
| **Gio.Subprocess** | Built-in | Execute bash CLI from extension | Official API for spawning external processes. Handles I/O safely. Preferred over raw GLib spawn. |

### Supporting Libraries & APIs

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **GLib.timeout_add_seconds()** | Built-in | Polling timer | Refresh status every 20s (align with `spin status` interval). Part of main loop integration. |
| **Gio.File** | Built-in | File system access | Read cached status from temporary file if polling subprocess proves too slow. |
| **St (Shell Toolkit)** | Built-in | UI elements | `St.Icon`, `St.Label` for visual status indicators in dropdown menu. |
| **Main.panel.addToStatusArea()** | Built-in | Add button to top bar | Standard integration point for status area indicators. |

## Integration Pattern: Bash ↔ Extension

### Recommended: Subprocess Polling with JSON Output

**Flow:**
1. Extension calls `spin status --json` every 20 seconds via `Gio.Subprocess`
2. Bash script outputs JSON with current session states: `[{name, state, pid}, ...]`
3. Extension parses JSON, updates icon color (green/yellow/red), refreshes dropdown menu
4. On click, extension calls `spin connect <session>` via `Gio.Subprocess`

**Why this approach:**
- Avoids D-Bus complexity (no need to register service)
- Reuses existing bash infrastructure (`spin status`, `spin connect`)
- Stateless: no daemon, no IPC infrastructure
- Straightforward testing: subprocess output is predictable

### Alternative (Not Recommended): D-Bus Service

- Requires registering D-Bus service in bash (complex)
- Adds daemon complexity for what should be polling
- Breaks portable bash philosophy

### Not Viable: Direct File Monitoring

- `inotify` requires setting up watches on tmux state
- tmux env vars don't trigger filesystem events
- File polling is simpler and aligns with current refresh interval

## Installation & Distribution

| Aspect | Approach | Notes |
|--------|----------|-------|
| **Extension Directory** | `~/.local/share/gnome-shell/extensions/spin@example.local/` | User-level installation. System-wide via `/usr/share/gnome-shell/extensions/` if shipped with `make install`. |
| **Metadata** | `metadata.json` | UUID: `spin@example.local`, name: "Spin", description, shell-version: `[50]` (or range). |
| **Settings Schema** | GSettings via `schemas/org.gnome.shell.extensions.spin.gschema.xml` | Optional: store preferences like refresh interval, session filter. |
| **Enable/Disable** | `gnome-extensions enable spin@example.local` | User or installer script. Extensions auto-load after restart. |
| **Configuration** | Via Extension Manager UI or `gsettings set` | Preference GUI optional; CLI fully supports it. |

## Project Structure

```
extensions/
  spin@example.local/
    extension.js          # Main extension class, PanelMenu setup
    ui/
      panelMenu.js        # Menu item rendering
      statusIcon.js       # Icon color logic
    lib/
      statusParser.js     # Parse JSON from spin status
    metadata.json         # Extension metadata
    schemas/
      org.gnome.shell.extensions.spin.gschema.xml  # (Optional) Settings
```

## Development Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| **GNOME JavaScript SDK** | 1.78+ | GJS interpreter, bindings, type definitions. `gnome-shell` package provides runtime. |
| **gnome-shell** | 50+ | GNOME Shell runtime for testing. `apt install gnome-shell` or distro equivalent. |
| **Text Editor / IDE** | Any | GNOME JavaScript guide recommends GNOME Builder or VS Code with GNOME Shell extension support. |
| **`dbus-run-session`** | Included in dbus | Run test extension in isolated DBus session. Prevents conflicts with live shell. |

## Key API Patterns

### 1. Create Panel Button with Menu

```javascript
import * as PanelMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const button = new PanelMenu.Button(0.0, 'Spin Indicator');
const icon = new St.Icon({
  icon_name: 'media-record-symbolic',
  style_class: 'system-status-icon',
});
button.add_child(icon);
Main.panel.addToStatusArea('spin-indicator', button);
```

### 2. Spawn Subprocess with JSON Output

```javascript
import Gio from 'gi://Gio';

Gio._promisify(Gio.Subprocess.prototype, 'communicate_utf8_async');

const proc = Gio.Subprocess.new(
  ['spin', 'status', '--json'],
  Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
);

const [stdout, stderr] = await proc.communicate_utf8_async(null, null);
const status = JSON.parse(stdout);
```

### 3. Polling Timer

```javascript
const updateStatusId = GLib.timeout_add_seconds(
  GLib.PRIORITY_DEFAULT,
  20,  // seconds, aligned with spin status interval
  () => {
    this._updateStatus();
    return GLib.SOURCE_CONTINUE;  // Keep polling
  }
);

// In disable():
GLib.source_remove(updateStatusId);
```

### 4. Menu Item Click Handler

```javascript
const item = new PopupMenu.PopupMenuItem('Session Name');
item.connect('activate', () => {
  // Execute: spin connect <session>
  Gio.Subprocess.new(
    ['spin', 'connect', sessionName],
    Gio.SubprocessFlags.STDOUT_PIPE
  );
});
menu.addMenuItem(item);
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **GNOME Shell Extension (native)** | AppIndicator + libappindicator | If supporting KDE Plasma or non-GNOME desktops. Adds complexity; most Spin users are on GNOME. |
| **GNOME Shell Extension (native)** | D-Bus service in bash | If needing two-way event signaling (bash → extension). Adds daemon overhead; polling is sufficient. |
| **Subprocess polling** | File-based status cache | If subprocess overhead is high. Requires inotify or periodic file reading; more complex. |
| **GSettings schema (optional)** | Hardcoded config | If user wants to customize refresh interval or hide indicator. Not critical for MVP. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Legacy imports (`imports.ui.main`)** | Broken in GNOME 45+. ESM is mandatory. | Use `resource:///org/gnome/shell/...` with `import` statements. |
| **libappindicator library** | Deprecated. AppIndicator extension adds extra dependency and enable step. | Write native GNOME Shell extension; simpler and standard. |
| **Shell Command Execution via shell** | Unsafe, shell injection risk. | Use `Gio.Subprocess.new()` with array args; no shell parsing needed. |
| **Callback-based async** | Old GJS pattern. Verbose, error-prone. | Use `Gio._promisify()` + async/await (GJS 1.76+). |
| **Persistent background service** | Breaks pure bash philosophy, adds complexity. | Use polling in extension; stateless, simple. |
| **Direct socket/named pipes** | Manual protocol implementation. | Use D-Bus (if IPC needed) or subprocess stdout. |

## Version Compatibility

| Component | Version | Rationale |
|-----------|---------|-----------|
| **GNOME Shell target** | 50+ | Current LTS/standard. ESM mandatory. Earlier versions (40-47) need legacy code; not worth complexity. |
| **GJS** | 1.78+ | Async/await support. ESM module system. Bundled with GNOME 50. |
| **Bash** | 4+ | Already required by spin CLI. No new dependency. |
| **Linux kernel** | 5.10+ | Modern systemd, DBus, `/proc` filesystem. Spin already requires this. |

## Bash Integration Points

### New CLI Commands

| Command | Purpose | Output Format |
|---------|---------|----------------|
| `spin status --json` | Get session status for extension | JSON array: `[{name, state, pid, idle}]` |
| `spin connect <session>` | Existing; extension calls this on menu click | Opens Ghostty window (existing behavior) |

**Minimal changes to existing bash:**
- Add `--json` flag to `spin status` command
- No refactoring of core logic
- Backwards compatible with existing terminal output

## Stack Summary Table

| Layer | Technology | Version | Status |
|-------|-----------|---------|--------|
| **UI Framework** | GNOME Shell | 50+ | Existing infrastructure |
| **Language** | GJS/JavaScript | 1.78+ | Bundled with GNOME 50 |
| **Panel Integration** | PanelMenu API | Built-in | Stable, well-documented |
| **Process Execution** | Gio.Subprocess | Built-in | Recommended by GNOME |
| **Polling** | GLib.timeout_add_seconds | Built-in | Standard main loop integration |
| **Backend** | spin bash CLI | 1.0+ | Existing, no changes to core |
| **IPC** | Subprocess JSON stdout | — | Simple, no new dependencies |

## Sources

- [GNOME JavaScript Guide: Extension Development](https://gjs.guide/extensions/development/creating.html) — Core extension structure, ESM modules
- [GNOME JavaScript: PanelMenu and PopupMenu](https://gjs.guide/extensions/topics/popup-menu.html) — UI patterns, menu item handlers
- [GNOME JavaScript: Subprocess Execution](https://gjs.guide/guides/gio/subprocesses.html) — Process spawning, async I/O
- [GNOME JavaScript: D-Bus Integration](https://gjs.guide/guides/gio/dbus.html) — Context for why subprocess preferred
- [GNOME 45 Extension Migration Guide](https://gjs.guide/extensions/upgrading/gnome-shell-45.html) — ESM requirements, version breaking changes
- [GNOME 50 Release Notes](https://release.gnome.org/50/) — Current stable target, no indicator changes
- [AppIndicator Support Extension](https://extensions.gnome.org/extension/615/appindicator-support/) — AppIndicator architecture reference
- [Ubuntu gnome-shell-extension-appindicator Repository](https://github.com/ubuntu/gnome-shell-extension-appindicator) — AppIndicator architecture reference

---

*Stack research for: GNOME system tray indicator with dropdown menu*
*Researched: 2026-03-31*
