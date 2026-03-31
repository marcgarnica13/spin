'use strict';

const { Gio, GLib, St } = imports.gi;
const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;

// ── SpinIndicator ──────────────────────────────────────────────────────────────
// PanelMenu.Button subclass that owns the tray icon lifecycle.
// enable() adds it to the panel; disable() removes it and cleans up all resources.

class SpinIndicator extends PanelMenu.Button {
  constructor() {
    super(0.0, 'Spin Indicator');
    this._icon = null;
    this._timeoutId = null;
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

  // ── Polling (stubbed; Plan 02 implements) ──────────────────────────────────
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
    // Stub — Plan 02 replaces this with spin status --json subprocess call
    log('[spin-indicator] _refreshState() stub called');
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
