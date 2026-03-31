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
sudo make install
```

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/marcgarnica13/spin/main/install.sh | bash
```

### Uninstall

```bash
sudo make uninstall
```

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

Live-updating tree view of all active spin sessions:

```
spin status (refreshing every 20s -- press Ctrl-C to exit)

 spin-assistant  ~/Development/assistant
 ├─ planner    ● working
 ├─ reviewer   ◉ waiting for input
 └─ coder      ◌ idle

 spin-myproject  ~/Development/myproject
 ├─ api        ● working
 └─ tests      ○ exited

 ● working  ◉ needs input  ◉ needs permission  ◌ idle  ○ exited
```

Use `--once` for a single snapshot:

```bash
spin status --once
```

### Reconnect to sessions

```bash
spin connect           # auto-attaches if one session, lists if multiple
spin connect myproject # attach to spin-myproject in a new Ghostty window
```

## How it works

`spin claude` creates a tmux session named `spin-<directory>` with one window per name. Each window has two panes: the left pane runs `claude --dangerously-skip-permissions --worktree <name>`, and the right pane is a shell in the project directory.

`spin status` enumerates all `spin-*` tmux sessions, inspects each pane's process tree and terminal content to determine whether Claude is actively working, waiting for input, or has exited.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
