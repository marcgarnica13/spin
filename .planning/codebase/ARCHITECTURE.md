# Architecture

**Analysis Date:** 2026-03-30

## Pattern Overview

**Overall:** Modular CLI application with command dispatch and pluggable subcommands

**Key Characteristics:**
- Single entry point with subcommand routing
- Shared library layer for common utilities
- Clear separation between command implementations
- No external dependencies beyond standard Unix tools (bash, tmux, git)

## Layers

**Entry Point Layer:**
- Purpose: Parses command arguments and routes to appropriate subcommand
- Location: `bin/spin`
- Contains: Main script with usage info and dispatch logic
- Depends on: `lib/spin-common.sh` for shared utilities
- Used by: Direct CLI invocation

**Library/Utilities Layer:**
- Purpose: Provides shared constants, utilities, and status detection logic
- Location: `lib/spin-common.sh`, `lib/spin-status.sh`, `lib/spin-claude.sh`
- Contains: Error handling, color output, tree drawing, session detection
- Depends on: bash builtins, Unix utilities (tmux, pgrep, ps)
- Used by: All command implementations

**Command Implementations:**
- Purpose: Implement specific features (launching sessions, monitoring status)
- Location: `lib/spin-claude.sh`, `lib/spin-status.sh`
- Contains: Business logic for each command
- Depends on: Common library, tmux, Claude CLI
- Used by: Entry point dispatcher

## Data Flow

**Session Launch Flow:**

1. User runs: `spin claude <names...>`
2. Entry point (`bin/spin`) validates args and sources `spin-claude.sh`
3. `spin_claude()` function:
   - Generates session name from project directory
   - Kills existing session if present
   - Creates tmux session with multiple windows (one per name)
   - Starts `claude --worktree <name>` in each window's left pane
   - Adds shell pane on right side for manual interaction
   - Stores project directory in tmux environment
   - Opens tmux in new Ghostty terminal window
4. Claude instances run in parallel, each with isolated worktree

**Status Monitoring Flow:**

1. User runs: `spin status [--once]`
2. Entry point sources `spin-status.sh`
3. `spin_status()` function:
   - Lists all tmux sessions matching `spin-*` prefix
   - For each session, retrieves project directory from tmux environment
   - For each window in session, calls `detect_claude_state()`
   - Renders tree view with status icons
   - If not `--once`, loops with 2s refresh and cursor hiding
4. `detect_claude_state()` function:
   - Checks if Claude process exists in window's pane 0
   - Analyzes pane content (last 10 lines) for output patterns
   - Returns state: "exited", "waiting", "permission", or "working"

**State Management:**

- Session persistence: Stored in tmux session (requires tmux to remain running)
- Project context: Stored in tmux environment variable `SPIN_CWD`
- Process tracking: Detected dynamically via `/proc` filesystem inspection
- Output inspection: Live terminal content capture via `tmux capture-pane`

## Key Abstractions

**tmux Session:**
- Purpose: Container for parallel Claude instances, each with isolated workspace
- Examples: `spin-assistant`, `spin-myproject` (named `spin-<dirname>`)
- Pattern: One session per project, multiple windows per session

**Window Pane:**
- Purpose: Isolated execution context for Claude and manual shell access
- Examples: Left pane (Claude), right pane (shell)
- Pattern: Each window split horizontally into 2 panes for dual interaction

**Process State Detection:**
- Purpose: Determine what Claude is doing without active monitoring
- Examples: Check `/proc/<pid>/cmdline`, parse pane output
- Pattern: Multi-step detection - process alive check → output analysis → state classification

**Status Icons:**
- Purpose: Visual indication of parallel session state
- Examples: `●` (working), `◉` (waiting), `○` (exited)
- Pattern: Consistent icon set across all output

## Entry Points

**`bin/spin`:**
- Location: `/home/marc/Development/spin/bin/spin`
- Triggers: Direct invocation from shell
- Responsibilities:
  - Parse command and arguments
  - Validate inputs
  - Source appropriate library
  - Dispatch to correct function

**`lib/spin-claude.sh` — `spin_claude()` function:**
- Location: `/home/marc/Development/spin/lib/spin-claude.sh`
- Triggers: When `bin/spin` receives `claude` subcommand
- Responsibilities:
  - Create or reuse tmux session
  - Launch Claude in parallel windows
  - Set up shell panes for manual interaction
  - Open Ghostty terminal

**`lib/spin-status.sh` — `spin_status()` function:**
- Location: `/home/marc/Development/spin/lib/spin-status.sh`
- Triggers: When `bin/spin` receives `status` subcommand
- Responsibilities:
  - Enumerate active tmux sessions
  - Monitor state of each Claude instance
  - Render live dashboard or static snapshot
  - Handle refresh loop with Ctrl-C cleanup

## Error Handling

**Strategy:** Fail-fast with immediate stderr message and exit code

**Patterns:**
- `spin_die()`: Prints error message with RED prefix, exits with code 1
- `spin_warn()`: Prints warning message with YELLOW prefix, continues execution
- Validations: Check for minimum argument count, session existence, command validity
- Process errors: Gracefully handle missing panes, unavailable environment variables

**Examples:**
- Invalid command: `spin_die "unknown command: $1"`
- Missing arguments: `[[ $# -eq 0 ]] && spin_die "no window names provided"`
- Existing session: `spin_warn "tmux session already exists, killing it"`

## Cross-Cutting Concerns

**Logging:** Uses stderr for errors/warnings, stdout for status output. No log files.

**Validation:**
- Command arity check (correct number of arguments)
- Subcommand existence check
- Session name validation (no spaces, special chars)

**Color Output:**
- Automatically disabled when not a terminal (respects `[[ -t 1 ]]`)
- Uses ANSI escape codes stored in variables for easy customization
- Consistent use across all commands

**Terminal UI:**
- Tree drawing with branch and last-child connectors
- Status icons with color coding
- Cursor hiding during auto-refresh mode
- Signal handling for graceful exit

---

*Architecture analysis: 2026-03-30*
