## 0.1.0

Initial release.

- `spin claude <name1> [name2] ...` — launch parallel Claude Code sessions in tmux worktrees
- `spin status` — live monitoring dashboard for all active spin sessions
  - Tree view with session names, project directories, and window statuses
  - Auto-refresh every 2s (use `--once` for single output)
  - Detects: working, waiting for input, needs permission, exited
