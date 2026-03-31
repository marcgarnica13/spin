'use strict';

const { Gio, GLib, St } = imports.gi;
const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;

// ── SpinIndicator ──────────────────────────────────────────────────────────────
// PanelMenu.Button subclass that owns the tray icon lifecycle.
// enable() adds it to the panel; disable() removes it and cleans up all resources.

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
      20,
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
      return;
    }

    this._showIndicator();
    const aggregateState = this._aggregateState(sessions);
    const iconName = this._stateToIconName(aggregateState);
    this._icon.icon_name = iconName;
  }

  _aggregateState(sessions) {
    // Priority: error (red) > waiting (yellow) > working > idle
    let result = 'idle';

    for (const session of sessions) {
      const state = session.state;

      if (state === 'permission' || state === 'exited') {
        return 'error'; // Highest priority — stop checking immediately
      }

      if (state === 'waiting') {
        result = 'waiting';
      } else if (state === 'working' && result === 'idle') {
        result = 'working';
      }
    }

    return result;
  }

  _stateToIconName(aggregateState) {
    const iconMap = {
      'error':   'dialog-error-symbolic',    // red   — permission or exited
      'waiting': 'dialog-warning-symbolic',  // amber — awaiting user input
      'working': 'spinner',                  // active — Claude running
      'idle':    'dialog-information-symbolic', // grey — no activity
    };
    return iconMap[aggregateState] || 'dialog-information-symbolic';
  }

  _groupSessionsByName(sessions) {
    // sessions is a flat array: [{name, window, state, pid, idle_duration}, ...]
    // Returns a Map<string, Array<{window, state}>>
    const grouped = new Map();
    for (const entry of sessions) {
      const sessionName = String(entry.name || '');
      if (!sessionName) continue;
      if (!grouped.has(sessionName)) {
        grouped.set(sessionName, []);
      }
      grouped.get(sessionName).push({
        window: String(entry.window || ''),
        state: String(entry.state || 'idle'),
      });
    }
    return grouped;
  }

  _stateToIconSymbol(state) {
    const symbolMap = {
      'working':    '\u25CF', // ● filled circle (active)
      'waiting':    '\u25C9', // ◉ fisheye (awaiting input)
      'idle':       '\u25CC', // ◌ dotted circle (no activity)
      'exited':     '\u25CB', // ○ open circle (exited)
      'permission': '\u25CB', // ○ open circle (needs permission)
    };
    return symbolMap[state] || '\u25CB';
  }

  // ── Visibility ─────────────────────────────────────────────────────────────
  _showIndicator() {
    this.visible = true;
  }

  _hideIndicator() {
    this.visible = false;
  }
}

// ── Extension lifecycle ────────────────────────────────────────────────────────
let _indicator = null;

function init() {
  log('[spin-indicator] init()');
}

function enable() {
  log('[spin-indicator] enable()');
  _indicator = new SpinIndicator();
  _indicator._createUI();
  Main.panel.addToStatusArea('spin-indicator', _indicator);
  _indicator._startPolling();
}

function disable() {
  log('[spin-indicator] disable()');
  if (_indicator !== null) {
    _indicator._stopPolling();
    _indicator.destroy();
    _indicator = null;
  }
}
