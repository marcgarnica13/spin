# Testing Patterns

**Analysis Date:** 2026-03-30

## Test Framework

**Runner:**
- Not detected - No formal test framework present
- No test configuration files (jest.config.js, vitest.config.js, etc.)

**Assertion Library:**
- Not used - No test suite detected

**Run Commands:**
```bash
# No automated test suite defined
# Testing appears to be manual and integration-based
```

## Manual Testing Approach

This codebase uses **manual testing and integration testing** rather than automated unit tests. The project consists of shell scripts and JavaScript hooks that require:

1. **Interactive shell testing** - Commands must be run in a tmux environment to test behavior
2. **System integration testing** - Requires actual Claude Code CLI, tmux sessions, and Ghostty terminal
3. **Process observation** - Manual verification of spawned processes and terminal state

## Test File Organization

**Location:**
- No test files found
- Testing is performed manually against live systems

**Naming:**
- Not applicable - no test files exist

**Structure:**
- Testing relies on:
  - Makefile installation targets (`make install`, `make uninstall`)
  - User manual testing documented in README.md
  - Real-world usage with `spin claude` and `spin status` commands

## Testing Scope by Component

**Shell Scripts (`lib/` and `bin/`):**
- Tested through actual tmux session creation and management
- Manual verification of window creation, pane operations, and process management
- Terminal content analysis requires real Claude Code execution

**JavaScript Hooks (`.claude/hooks/`):**
- Hooks are invoked by Claude Code during actual sessions
- Testing requires:
  - stdin simulation with JSON input
  - Verification of JSON output parsing
  - File system interaction (reading/writing cache, metrics)
  - Timeout behavior validation

**Specific Testing Scenarios:**

### `spin claude` Command
- Create new tmux session with multiple windows
- Verify each window launches Claude Code with correct `--worktree` argument
- Confirm split-window functionality (left pane for Claude, right pane for shell)
- Validate session naming convention (`spin-<directory>`)
- Test with various name combinations (1-5 windows)

### `spin status` Command
- Enumerate all `spin-*` sessions correctly
- Detect Claude process state:
  - `working`: Claude process running
  - `waiting`: Terminal shows `>` prompt
  - `permission`: Terminal shows permission request patterns
  - `exited`: Claude process no longer present
- Verify refresh interval (2-second auto-refresh)
- Test `--once` flag for single snapshot
- Test with multiple active sessions

### Hook Testing
Hooks are tested via Claude Code's hook system:

**gsd-workflow-guard.js:**
- Input: Write/Edit tool calls with various file paths
- Verify guard only triggers outside `.planning/` and without GSD context
- Confirm advisory warning is injected correctly
- Test that file edits still proceed (non-blocking)

**gsd-context-monitor.js:**
- Input: PostToolUse event with context metrics
- Verify warnings trigger at 35% remaining (WARNING) and 25% remaining (CRITICAL)
- Test debounce mechanism (5 tool uses between warnings)
- Confirm severity escalation bypasses debounce
- Verify metrics file reading and cache management

**gsd-prompt-guard.js:**
- Input: Write/Edit operations targeting `.planning/` files
- Scan content for prompt injection patterns
- Verify detection of injection keywords
- Test for invisible Unicode character detection
- Confirm advisory warning for suspicious content

**gsd-statusline.js:**
- Input: Session metadata with context window data
- Verify progress bar generation (10-segment display)
- Test color thresholds (green < 50%, yellow 50-65%, orange 65-80%, red > 80%)
- Confirm context metrics bridge file creation
- Test task extraction from todos directory
- Verify GSD update notification display

**gsd-check-update.js:**
- Background process creation and detachment
- File write to cache directory
- Version comparison logic
- Stale hook detection by parsing version headers

## Error Scenarios

**Shell Script Testing:**
- Test with missing dependencies (bash, tmux, git, Claude Code, Ghostty)
- Verify error messages with `spin_die` function
- Test with invalid arguments to commands

**Hook Testing:**
- Malformed JSON input → silent exit (exit 0)
- Missing required fields → silent exit (exit 0)
- File system errors (missing directories, permission denied) → graceful degradation
- Timeout scenarios → exit within timeout windows (3-10 seconds depending on hook)

## Testing Commands (Manual Execution)

```bash
# Installation testing
make install PREFIX=$HOME/.local
$HOME/.local/bin/spin --help
$HOME/.local/bin/spin --version

# Session creation testing (requires git repo)
cd /path/to/git/repo
spin claude agent1 agent2
# Verify tmux session created: tmux list-sessions

# Session monitoring testing
spin status
# Observe live updates, verify state detection

# Session status snapshot
spin status --once

# Cleanup testing
make uninstall PREFIX=$HOME/.local
which spin  # Should fail

# Hook invocation testing (simulated)
echo '{"tool_name":"Write","tool_input":{"file_path":"test.txt"}}' | \
  node .claude/hooks/gsd-workflow-guard.js
```

## Coverage Gaps

**Untested Areas:**
- **Error recovery**: What happens if tmux session is killed externally
- **Signal handling**: SIGTERM/SIGINT behavior during session operations
- **Edge cases**: Very long window names, special characters in directory names
- **Concurrent sessions**: Multiple `spin claude` commands running simultaneously
- **Hook stdin pipe failures**: Incomplete JSON transmission scenarios
- **File system race conditions**: Concurrent access to metrics/cache files

**Risk Areas:**
- Process detection logic in `detect_claude_state` depends on `/proc/<pid>/cmdline` format (Linux-specific)
- Color code handling assumes terminal supports ANSI escape sequences
- Tmux session management assumes tmux is properly configured and running
- Hook execution order and timing in Claude Code sessions
- Cross-platform compatibility (Windows Git Bash has different pipe behavior)

## Testing Strategy Moving Forward

**Recommended Approach:**
1. **Unit-level testing**: Add bash/shell testing framework (e.g., BATS, shunit2) for function isolation
2. **Integration testing**: Create isolated tmux session tests with controlled Claude Code mocking
3. **Hook testing**: Create test harness that simulates Claude Code hook invocation with JSON fixtures
4. **Error path testing**: Add negative test cases for dependency failures and edge cases
5. **Process validation**: Use `ps` and `/proc` inspection assertions to verify process states

**Currently:**
- Manual testing through actual usage
- No automated regression testing
- Testing relies on developer familiarity with tmux, Claude Code, and git workflows
- No CI/CD pipeline detected

---

*Testing analysis: 2026-03-30*
