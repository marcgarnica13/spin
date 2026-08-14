# spin

Parallel [Claude Code](https://docs.anthropic.com/en/docs/claude-code) session manager. Launch multiple Claude instances in tmux worktrees and monitor them from a single dashboard.

## Features

- **`spin claude`** -- Spin up parallel Claude Code sessions, each in its own git worktree and tmux window
- **`spin status`** -- Live dashboard showing all sessions, worktrees, and whether Claude is working, waiting, idle, or exited (refreshes every 20s)
- **`spin connect`** -- Reconnect to existing sessions in a new Ghostty window (auto-attaches when one session exists, lists available sessions when multiple)

## Requirements

- bash 4+
- tmux 3+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [Ghostty](https://ghostty.org) terminal
- git

## Install

### From source

```bash
git clone https://github.com/marcgarnica13/spin.git
cd spin
make install
```

This installs the `spin` CLI and the GNOME Shell extension files.

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/marcgarnica13/spin/main/install.sh | bash
```

### Uninstall

```bash
make uninstall
```

## GNOME Extension Setup

After running `make install`, the extension files are copied to
`~/.local/share/gnome-shell/extensions/spin@gsd.local/` but the extension is not yet active.
Follow these steps to enable it.

### Step 1: Enable the extension

#### Method 1: Command line (recommended)

```bash
gnome-extensions enable spin@gsd.local
```

#### Method 2: GNOME Extensions app (GUI)

1. Open the **Extensions** application
2. Find **Spin Session Indicator** in the list
3. Toggle the switch to **ON**

### Step 2: Restart GNOME Shell (recommended)

For the icon to appear immediately, restart the shell:

- Press `Alt+F2`, type `r`, and press `Enter`
- Or log out and back in

> The extension will appear automatically after your next login if you skip this step.

### Verify

Confirm the extension is active:

```bash
gnome-extensions list --enabled | grep spin@gsd.local
```

You should see `spin@gsd.local` in the output.

## Usage

### Launch sessions

From any git repository:

```bash
spin claude planner reviewer coder
```

Creates a tmux session with three windows, each running Claude Code in its own `--worktree`. Opens in a new Ghostty terminal.

### Monitor sessions

```bash
spin status
```

Attention-first dashboard: any window that's `waiting` for input or `needs permission` is surfaced up top in a `▌ NEEDS YOU` block, with how long it's been in that state and a snippet of Claude's last message -- so you know at a glance which sessions actually need you, before scanning the full tree below (which also shows elapsed time per window):

```
spin status (refreshing every 20s -- press Ctrl-C to exit)

 ▌ NEEDS YOU
 ◉ spin-assistant:reviewer  waiting for input  4m  Looks good overall, one nit: the retry loop...

 spin-assistant  ~/Development/assistant
 ├─ planner    ● working  1m
 ├─ reviewer   ◉ waiting for input  4m
 └─ coder      ◌ idle  12m

 spin-myproject  ~/Development/myproject
 ├─ api        ● working  32s
 └─ tests      ○ exited  8m

 ● working  ◉ needs input  ◉ needs permission  ◌ idle  ○ exited
```

Use `--once` for a single snapshot, or `--json` for machine-readable output (used by the GNOME extension):

```bash
spin status --once
spin status --json
```

### Reconnect to sessions

```bash
spin connect           # auto-attaches if one session, lists if multiple
spin connect myproject # attach to spin-myproject in a new Ghostty window
```

## How it works

`spin claude` creates a tmux session named `spin-<directory>` with one window per name. Each window has two panes: the left pane runs `claude --dangerously-skip-permissions --worktree <name>`, and the right pane is a shell in the project directory.

`spin claude` also registers Claude Code lifecycle hooks (via `--settings`) that write a ground-truth state file per window whenever Claude actually finishes responding, needs a permission prompt answered, or exits -- turning state detection from guesswork into real events. `spin status` enumerates all `spin-*` tmux sessions and reads each window's state file first; it only falls back to inspecting the pane's process tree and terminal content when no hook data exists yet (e.g. a session launched by an older `spin` version, or the hook hasn't fired yet).

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
