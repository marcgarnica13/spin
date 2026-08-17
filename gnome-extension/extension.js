import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

// ── SpinIndicator ──────────────────────────────────────────────────────────────
// PanelMenu.Button subclass that owns the tray icon lifecycle.
// enable() adds it to the panel; disable() removes it and cleans up all resources.

const SpinIndicator = GObject.registerClass(
class SpinIndicator extends PanelMenu.Button {
  constructor() {
    super(0.0, 'Spin Indicator');
    this._icon = null;
    this._timeoutId = null;
    this._spinPath = GLib.find_program_in_path('spin') || 'spin';
  }

  _createUI() {
    this._icon = new St.Icon({
      style_class: 'system-status-icon',
      icon_name: 'dialog-information-symbolic',
    });
    this.add_child(this._icon);
    this._updateTooltip('Spin: initializing\u2026');
  }

  _updateTooltip(text) {
    // accessible_name sets the AT-SPI label used by screen readers and tooltip popups
    this.accessible_name = text;
  }

  // ── Polling ────────────────────────────────────────────────────────────────
  _startPolling() {
    this._refreshState();
    this._timeoutId = GLib.timeout_add_seconds(
      GLib.PRIORITY_DEFAULT,
      5,
      () => {
        this._refreshState();
        return GLib.SOURCE_CONTINUE;
      }
    );
  }

  _stopPolling() {
    if (this._timeoutId !== null) {
      GLib.source_remove(this._timeoutId);
      this._timeoutId = null;
    }
  }

  _refreshState() {
    let proc;
    try {
      proc = Gio.Subprocess.new(
        [this._spinPath, 'status', '--json'],
        Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE
      );
    } catch (e) {
      logError(e, '[spin-indicator] Failed to spawn spin status --json');
      this._hideIndicator();
      return;
    }

    proc.communicate_utf8_async(null, null, (proc, res) => {
      try {
        const [, stdout] = proc.communicate_utf8_finish(res);
        const sessions = JSON.parse(stdout.trim());

        if (!Array.isArray(sessions)) {
          throw new Error('Expected JSON array, got: ' + typeof sessions);
        }

        this._updateUI(sessions);
      } catch (e) {
        logError(e, '[spin-indicator] Failed to parse spin status output');
        this._hideIndicator();
      }
    });
  }

  _updateUI(sessions) {
    if (sessions.length === 0) {
      this._hideIndicator();
      this.menu.removeAll();
      return;
    }

    this._showIndicator();
    const aggregateState = this._aggregateState(sessions);
    const iconName = this._stateToIconName(aggregateState);
    this._icon.icon_name = iconName;

    // Skip menu rebuild if menu is currently open — prevents visible flicker/collapse
    // while the user is interacting with the dropdown (20s polling fires in background)
    if (!this.menu.isOpen) {
      this._buildMenu(sessions);
    }
  }

  _aggregateState(sessions) {
    // Priority: attention (yellow) > working (red) > idle (blank)
    let result = 'idle';

    for (const session of sessions) {
      const state = session.state;

      if (state === 'permission' || state === 'waiting') {
        return 'attention'; // Highest priority — needs user input
      }

      if (state === 'working' && result === 'idle') {
        result = 'working';
      }
      // exited maps to idle — nothing actionable
    }

    return result;
  }

  _stateToIconName(aggregateState) {
    const iconMap = {
      'attention': 'dialog-warning-symbolic',     // yellow — needs user input
      'working':   'dialog-error-symbolic',        // red    — Claude running
      'idle':      'dialog-information-symbolic',   // blank  — nothing happening
    };
    return iconMap[aggregateState] || 'dialog-information-symbolic';
  }

  _groupSessionsByName(sessions) {
    // sessions is a flat array:
    // [{name, window, state, pid, since, elapsed_seconds, last_message}, ...]
    // elapsed_seconds is -1 for fallback windows with no hook-written state
    // file (see lib/spin-status.sh spin_status_json) — treat that as "no
    // elapsed data available", not "just started".
    // Returns a Map<string, Array<{window, state, elapsedSeconds, lastMessage}>>
    const grouped = new Map();
    for (const entry of sessions) {
      const sessionName = String(entry.name || '');
      if (!sessionName) continue;
      if (!grouped.has(sessionName)) {
        grouped.set(sessionName, []);
      }
      const elapsedSeconds = Number.isFinite(entry.elapsed_seconds) ? entry.elapsed_seconds : -1;
      grouped.get(sessionName).push({
        window: String(entry.window || ''),
        state: String(entry.state || 'idle'),
        elapsedSeconds,
        lastMessage: String(entry.last_message || ''),
      });
    }
    return grouped;
  }

  _stateToIconSymbol(state) {
    const symbolMap = {
      'working':    '\u25CF', // ● filled circle (Claude running)
      'waiting':    '\u25C9', // ◉ fisheye (awaiting input)
      'permission': '\u25C9', // ◉ fisheye (needs permission)
      'idle':       '\u25CB', // ○ open circle (no activity)
      'exited':     '\u25CB', // ○ open circle (finished)
    };
    return symbolMap[state] || '\u25CB';
  }

  _humanizeDuration(seconds) {
    // Mirrors spin_humanize_duration in lib/spin-common.sh.
    let s = seconds;
    if (s < 0) s = 0;
    if (s < 60) return `${s}s`;
    if (s < 3600) return `${Math.floor(s / 60)}m`;
    const hours = Math.floor(s / 3600);
    const mins = Math.floor((s % 3600) / 60);
    return `${hours}h${mins}m`;
  }

  _truncateMessage(text, maxLen) {
    if (text.length <= maxLen) return text;
    return `${text.slice(0, maxLen)}\u2026`;
  }

  _buildMenu(sessions) {
    this.menu.removeAll();

    const grouped = this._groupSessionsByName(sessions);

    for (const [sessionName, windows] of grouped) {
      // Session row: expandable submenu node
      const sessionItem = new PopupMenu.PopupSubMenuMenuItem(sessionName, false);

      for (const win of windows) {
        const symbol = this._stateToIconSymbol(win.state);
        let label = `${win.window}  ${symbol}`;

        // Fallback windows (elapsedSeconds === -1, no hook state file) have
        // no reliable elapsed time — omit rather than show a misleading value.
        if (win.elapsedSeconds >= 0) {
          label += `  ${this._humanizeDuration(win.elapsedSeconds)}`;
        }

        if ((win.state === 'waiting' || win.state === 'permission') && win.lastMessage) {
          label += `  ${this._truncateMessage(win.lastMessage, 40)}`;
        }

        const windowItem = new PopupMenu.PopupMenuItem(label);

        // Capture sessionName/windowName by value via arrow function (avoids loop-closure bug)
        windowItem.connect('activate', () => {
          this._connectToSession(sessionName, win.window);
        });

        sessionItem.menu.addMenuItem(windowItem);
      }

      this.menu.addMenuItem(sessionItem);
    }
  }

  _connectToSession(sessionName, windowName) {
    const launcher = new Gio.SubprocessLauncher({
      flags: Gio.SubprocessFlags.NONE,
    });

    const display = GLib.getenv('DISPLAY') || ':0';
    launcher.setenv('DISPLAY', display, true);

    try {
      const args = [this._spinPath, 'connect', sessionName];
      if (windowName) {
        args.push(windowName);
      }
      launcher.spawnv(args);
      log(`[spin-indicator] Connected to session: ${sessionName} window: ${windowName || '(default)'}`);
    } catch (e) {
      logError(e, `[spin-indicator] Failed to connect to session: ${sessionName}`);
    }

    this.menu.close(PopupMenu.BoxPointer.PopupAnimation.FULL);
  }

  // ── Visibility ─────────────────────────────────────────────────────────────
  _showIndicator() {
    this.visible = true;
  }

  _hideIndicator() {
    this.visible = false;
  }
});

// ── Extension lifecycle ────────────────────────────────────────────────────────
export default class SpinExtension extends Extension {
  enable() {
    log('[spin-indicator] enable()');
    this._indicator = new SpinIndicator();
    this._indicator._createUI();
    Main.panel.addToStatusArea('spin-indicator', this._indicator);
    this._indicator._startPolling();
  }

  disable() {
    log('[spin-indicator] disable()');
    if (this._indicator !== null) {
      this._indicator._stopPolling();
      this._indicator.menu.removeAll(); // Clean up menu items before destroy to prevent memory leaks
      this._indicator.destroy();
      this._indicator = null;
    }
  }
}
