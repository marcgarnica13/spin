# Domain Pitfalls: GNOME System Tray Indicator Extensions

**Domain:** GNOME Shell extension development with bash CLI integration
**Researched:** 2026-03-31

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Using Legacy Imports Instead of ESM

**What goes wrong:** Extension fails to load silently in GNOME 45+, or crashes with cryptic error about undefined `imports`

**Why it happens:** Copying code from old GNOME Shell extensions (pre-45) that used `imports.ui.main` instead of ESM `import` statements. The syntax is familiar to developers who skipped GNOME 45 migration docs.

**Consequences:**
- Extension doesn't load at all, user sees "Extension unknown" in Settings
- No error message in normal GNOME Shell logs
- Requires full rebuild with correct imports to fix
- Wasted 2-4 hours debugging non-obvious issue

**Prevention:**
- Use ESM `import` statements exclusively: `import * as Main from 'resource:///org/gnome/shell/ui/main.js'`
- Never use `imports.ui` syntax
- Reference GNOME 45 migration guide before writing any code
- Set up linter (even basic) to flag `imports.` statements

**Detection:**
- Extension doesn't appear in `gnome-extensions list`
- Test launch in `dbus-run-session gnome-shell` to get error output

### Pitfall 2: Blocking the Main Loop with Synchronous Subprocess Calls

**What goes wrong:** GNOME Shell freezes for 100-500ms on each status poll, creating visible UI lag, particularly when `spin status` takes time (many sessions, slow system)

**Why it happens:** Using `proc.wait()` or `communicate_utf8()` (sync variant) instead of `communicate_utf8_async()`. Developers assume subprocess is "fast enough" or forget about GLib main loop thread model.

**Consequences:**
- User experiences jank/lag when hovering over indicator
- Panel becomes unresponsive for 100-500ms per poll
- Looks like GNOME Shell is crashing; users may file bugs
- 20-second polling becomes noticeable stuttering

**Prevention:**
- Always use `Gio.Subprocess` (async-capable)
- Always use `communicate_utf8_async()` with `Gio._promisify()` and async/await
- Never call `wait()` or sync variants
- Test with many sessions (50+) to expose lag
- Profile with `perfetto` or `perf` if unsure

**Detection:**
- `journalctl -f` shows 100+ ms gaps between main loop iterations
- Clicking indicator visibly delays menu appearance
- Scrolling desktop becomes sluggish during poll time

### Pitfall 3: Not Removing GLib Timeouts in disable()

**What goes wrong:** Timeouts keep firing after extension disables, causing memory leaks, stale subprocess calls, and eventual GNOME Shell crash

**Why it happens:** Forgetting to store the timeout ID or calling `GLib.source_remove()` in `disable()`. Easy to miss in small extensions; GNOME review guidelines are strict about this.

**Consequences:**
- Disabling extension doesn't actually stop the polling
- Subprocess calls accumulate in memory
- After several enable/disable cycles, GNOME Shell becomes unstable
- User has to restart GNOME Shell to recover
- Extension gets rejected from GNOME extensions marketplace (if submitted)

**Prevention:**
- Store all GLib timeout IDs: `this._pollId = GLib.timeout_add_seconds(...)`
- In `disable()`, always call `GLib.source_remove(this._pollId)` and null the ID
- Use a cleanup checklist: UI elements, signal handlers, timers, file watches
- Test enable/disable cycle 10+ times before shipping

**Detection:**
- `dbus-run-session gnome-shell --debug` and disable/enable extension in Extension Manager
- Watch `top` or `htop`; memory keeps growing after each disable/enable
- `ps aux | grep spin` shows subprocess accumulating after disabling extension

### Pitfall 4: Hardcoding Assumptions About Session State JSON Structure

**What goes wrong:** Bash `--json` output changes slightly (add a field, rename key), and extension crashes with `undefined` errors or silently fails

**Why it happens:** Extension assumes fixed JSON structure but doesn't validate it. If `spin status` evolution adds optional fields or changes key names, extension is fragile.

**Consequences:**
- Extension breaks without warning when bash CLI updates
- Silent failure mode: menu just disappears
- Requires coordinated version bump to fix
- Discourages future improvements to `spin status` output

**Prevention:**
- Define JSON schema in comments: `// [{name: string, state: 'working'|'waiting'|'idle'|'exited', pid: number}]`
- Validate structure: `if (!Array.isArray(status)) throw new Error(...)`
- Use optional chaining: `session?.name ?? 'Unknown'`
- Document contract between extension and bash CLI (this file)
- Version the JSON output: `{version: 1, sessions: [...]}`

**Detection:**
- JSON parsing throws `TypeError: Cannot read property 'name' of undefined`
- Menu renders empty or partial
- Subprocess output doesn't match expected keys

### Pitfall 5: Not Handling JSON Parse Errors

**What goes wrong:** If `spin status` fails or returns malformed JSON, extension silently crashes and menu disappears

**Why it happens:** Wrapping subprocess call in try/catch for file I/O, but not for `JSON.parse()`. Or catching errors but not logging them, so user has no idea what happened.

**Consequences:**
- User clicks indicator, menu doesn't appear, no error message
- Impossible to debug without looking at logs
- User thinks extension is broken
- Bash changes or edge cases cause silent failures

**Prevention:**
- Wrap `JSON.parse()` in try/catch explicitly
- Log errors to console.error with context: `console.error('Failed to parse status JSON:', error)`
- Show fallback UI: "Unable to load sessions" instead of empty menu
- Test with intentionally malformed subprocess output

**Detection:**
- `journalctl /usr/bin/gnome-shell` shows parse errors
- Menu clicks have no effect, no UI feedback
- `dbus-run-session` development environment shows errors in terminal

## Moderate Pitfalls

### Pitfall 6: Subprocess `spin connect` Not Running in Background

**What goes wrong:** Extension waits for `spin connect` to complete before closing menu, blocking UI for 2+ seconds

**Why it happens:** Using `communicate_utf8_async()` without `.fire_and_forget()`, or not understanding that waiting for subprocess is unnecessary

**Consequences:**
- Menu lingers open for 2+ seconds after click
- User can't interact with panel while Ghostty launches
- Feels unresponsive compared to native applications

**Prevention:**
- Don't wait for `spin connect` subprocess to complete
- Fire subprocess and let it run: `Gio.Subprocess.new(['spin', 'connect', name], ...); // no await`
- Only wait for `spin status --json` (need the output)
- Test: measure time from click to menu close; should be <50ms

**Detection:**
- Menu stays open noticeably after clicking session
- Ghostty window appears 2+ seconds later
- `htop` shows spin process lingering after menu close

### Pitfall 7: Icon Color Not Updating When Sessions Change

**What goes wrong:** Icon color sticks at green even though a session is now waiting for input; user has stale state

**Why it happens:** Calling `statusIcon.update(state)` but not triggering icon redraw, or caching color in extension instead of recomputing from status

**Consequences:**
- Visual indicator becomes unreliable
- User misses the fact that a session needs attention
- Defeats primary value of indicator (at-a-glance state)
- User reverts to running `spin status` in terminal

**Prevention:**
- Recompute icon color on every poll: don't cache
- Call `this._icon.set_style_class_name()` or `set_property()` to force redraw
- Test: start session in idle, run something, verify icon changes within 20s
- Test: kill a session, verify color updates

**Detection:**
- Icon color doesn't match actual session state
- Running `spin status` shows different state than icon suggests
- Refreshing manually (disable/enable extension) fixes color

### Pitfall 8: Menu Items Piling Up Instead of Being Replaced

**What goes wrong:** Clicking menu repeatedly creates duplicate items; old items not removed; menu grows unbounded

**Why it happens:** Calling `menu.addMenuItem()` without `menu.removeAll()` first, or using wrong method name for clearing

**Consequences:**
- Menu gets longer every poll
- Duplicate sessions appear in list
- Memory leaks; old PopupMenuItem objects not garbage collected
- Menu becomes unusable with 100+ duplicate items

**Prevention:**
- Always call `this.menu.removeAll()` before rebuilding menu
- Use `menu.addMenuItem()` for adding, not array concatenation
- Test: enable/disable extension 10 times; verify menu item count stays constant

**Detection:**
- Menu items duplicate on every poll
- Running `dbus-run-session gnome-shell` shows items piling up visually
- Menu has 2x or 10x more items than actual sessions

### Pitfall 9: Not Handling Zero Sessions (Empty State)

**What goes wrong:** Menu appears blank when no sessions are running; user has no feedback

**Why it happens:** Code assumes there's always at least one session. When `spin status --json` returns `[]`, menu is empty and user sees nothing

**Consequences:**
- Confusing UX: icon appears, menu opens, nothing inside
- User thinks extension is broken
- No indication that having no sessions is valid state

**Prevention:**
- Explicitly handle empty session list: `if (status.length === 0) { menu.addMenuItem(...'No sessions'); return; }`
- Show indicator only when sessions exist: `icon.visible = status.length > 0`
- Test: run `spin status` when no sessions are active; verify menu shows placeholder

**Detection:**
- Menu opens but appears empty
- Icon lingers even when all sessions are killed

## Minor Pitfalls

### Pitfall 10: Not Parsing Colors Correctly in State Mapping

**What goes wrong:** Icon displays wrong color because state enum doesn't match bash output

**Why it happens:** Bash returns `state: 'working'`, extension checks `if (state === 'WORKING')`, color never matches

**Consequences:**
- Icon always shows default color, rendering state visualization useless
- User has to open menu to understand state

**Prevention:**
- Match case and values exactly: bash returns lowercase, extension checks lowercase
- Define state enum: `const StateColor = {working: 'yellow', waiting: 'red', idle: 'green'}`
- Test with all possible states from bash CLI

**Detection:**
- Icon color is always the same regardless of session state
- Menu shows correct states, but icon color is wrong

### Pitfall 11: Memory Leak from Unclosed File Handles

**What goes wrong:** Extension opens files (if caching status to disk) but doesn't close them; file descriptors leak

**Why it happens:** Using `Gio.File.read()` without properly closing the stream, or not using try/finally

**Consequences:**
- Extension accumulates open file descriptors
- After many enable/disable cycles, system runs out of fds
- GNOME Shell can't open new files

**Prevention:**
- Use `Gio.File.replace()` with cleanup: `await file.replace_async()` closes automatically
- Use try/finally to ensure streams close
- Test with `lsof` to verify no stale file descriptors

**Detection:**
- `lsof | grep gnome-shell` shows increasing open files
- GNOME Shell starts failing to open windows ("too many open files")

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: `spin status --json` implementation | Incomplete JSON structure (missing fields) | Document schema in bash and extension; test both together |
| Phase 2: Extension scaffolding | Using old GNOME Shell code as template | Reference GNOME 50 guide, not Stack Overflow from 2020 |
| Phase 3: Polling implementation | Blocking main loop on subprocess wait | Profile with `dbus-run-session`; use async/await |
| Phase 4: Menu rendering | Menu items accumulating instead of clearing | Call `removeAll()` before rebuilding |
| Phase 5: Click handler | `spin connect` waiting blocks UI | Don't await subprocess; fire and forget |
| Phase 6: Installation | Extension installed but not enabled by default | Document `gnome-extensions enable` step |
| Phase 7: Settings schema (if implemented) | GSettings not persisted across restarts | Verify dconf backend working; test enable/disable cycles |

## Sources

- [GNOME Shell Extensions Review Guidelines](https://gjs.guide/extensions/review-guidelines/review-guidelines.html) — Cleanup, resource management expectations
- [GNOME 45 Extension Migration Guide](https://gjs.guide/extensions/upgrading/gnome-shell-45.html) — ESM pitfalls, breaking changes
- [GNOME JavaScript: Async Programming](https://gjs.guide/guides/gjs/asynchronous-programming.html) — Main loop blocking, GLib patterns
- [GNOME JavaScript: Subprocess Execution](https://gjs.guide/guides/gio/subprocesses.html) — Async subprocess patterns
- Real-world extension reviews on [extensions.gnome.org](https://extensions.gnome.org/) — Common rejection reasons

---

*Pitfall research for: GNOME system tray indicator*
*Researched: 2026-03-31*
