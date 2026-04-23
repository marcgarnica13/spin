<!-- GSD:project-start source:PROJECT.md -->
## Project

**Spin**

A parallel Claude Code session manager. Spin launches multiple Claude instances in tmux worktrees, monitors them from a live dashboard, and provides quick session management — all from the terminal. Built for developers running multiple Claude Code agents simultaneously.

**Core Value:** Effortless management of parallel Claude Code sessions — launch, monitor, and reconnect without manual tmux juggling.

### Constraints

- **Tech stack**: Pure bash, no compiled dependencies — must stay simple and portable
- **Terminal**: Ghostty-specific for window creation (uses `ghostty -e`)
- **Platform**: Linux (uses `/proc/$pid/cmdline` for process inspection)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Bash 4+ - All executable scripts and library modules
- None
## Runtime
- POSIX-compatible Unix shell (bash 4 or later)
- No external language runtimes required
- None (pure system dependencies)
- Lockfile: Not applicable
## Frameworks
- None (standalone bash scripts)
- Not implemented
- GNU Make - Installation and uninstallation via `Makefile`
## Key Dependencies
- tmux 3+ - Terminal multiplexer for session management (`lib/spin-claude.sh`)
- git - Version control and worktree operations (implicit via Claude Code usage)
- bash 4+ - Shell interpreter with bash-specific features like arrays
- ghostty - Terminal emulator for launching tmux sessions (`lib/spin-claude.sh` line 33)
- claude - Claude Code CLI tool (external dependency, invoked via `lib/spin-claude.sh` line 24)
## Configuration
- Configured via command-line arguments and tmux environment variables
- Session prefix: `SPIN_SESSION_PREFIX="spin-"` (`lib/spin-common.sh` line 5)
- Project directory stored in tmux environment: `SPIN_CWD` (`lib/spin-claude.sh` line 31)
- `Makefile` - Installation to `$(PREFIX)/bin` and `$(PREFIX)/lib/spin` (default: `/usr/local`)
- No build configuration files (yaml, toml, etc.)
## Platform Requirements
- bash 4+ installed
- tmux 3+ installed
- git installed
- Ghostty terminal installed
- Claude Code CLI installed
- Same as development (all tools required at runtime)
- Installation via `make install` or `install.sh` script
- Requires sudo for system-wide installation (when `/usr/local/bin` not writable)
## Version Control
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Shell scripts: `spin-<purpose>.sh` format (e.g., `spin-claude.sh`, `spin-status.sh`, `spin-common.sh`)
- Main entry point: `spin` (no extension)
- Hook files: `gsd-<purpose>.js` format (e.g., `gsd-workflow-guard.js`, `gsd-context-monitor.js`)
- All lowercase with hyphens separating words
- Shell: `snake_case` with underscore separator (e.g., `spin_die`, `spin_warn`, `spin_claude`, `spin_status_once`, `detect_claude_state`)
- JavaScript: `camelCase` for named functions and utility functions (e.g., `detectConfigDir`, `spawnProcess`)
- Prefix with namespace: Shell functions use `spin_` prefix for public functions
- Shell: `UPPER_CASE` for constants and environment variables (e.g., `SPIN_VERSION`, `SPIN_SESSION_PREFIX`, `SPIN_ROOT`, `SPIN_LIB`)
- Shell: `snake_case` for local/temporary variables (e.g., `first`, `tmpdir`, `current`, `session_count`)
- Shell: Loop variables use conventional names (e.g., `for name in`, `while IFS= read -r`)
- JavaScript: `camelCase` for variables and constants (e.g., `sessionId`, `projectDir`, `staleHooks`)
- Shell: Color codes defined as variables: `RED`, `GREEN`, `YELLOW`, `CYAN`, `BOLD`, `DIM`, `RESET`
- Shell: Status icons as constants: `ICON_WORKING`, `ICON_WAITING`, `ICON_PERMISSION`, `ICON_EXITED`
- Shell: Tree drawing characters: `TREE_BRANCH`, `TREE_LAST`, `TREE_PIPE`
## Code Style
- Shell scripts: 2-space indentation (observed in `lib/spin-status.sh` and other files)
- JavaScript hooks: 2-space indentation (observed in all hook files)
- Line length: Generally kept reasonable, with comments not exceeding typical terminal width
- Blank lines: Used between logical sections for readability
- Shell: Use of `shellcheck` is indicated by `# shellcheck source=` annotations (e.g., in `bin/spin`)
- Shell: Strict mode enabled with `set -euo pipefail` (error on undefined variables, exit on error, fail on pipe errors)
- JavaScript: Follows Node.js/CommonJS conventions
- No formal linter configuration detected (no .eslintrc, .prettierrc files)
## Import Organization
- Use `source` directive to load library files from relative paths
- Source directives include shellcheck annotations for static analysis
- Order: source common utilities first, then specialized modules
- Example from `bin/spin`:
- Use `const` for require statements and module imports
- Group imports by type: standard library (fs, path, os, child_process) first, then local modules
- Example from hooks:
## Error Handling
- Shell: Use `spin_die` function for fatal errors (logs error to stderr and exits with code 1)
- Shell: Use `spin_warn` function for non-fatal warnings (logs to stderr but continues)
- Shell: Defensive checks with `[[ condition ]] &&` pattern for quick exits
- JavaScript: Try-catch blocks with silent fail-through (exit 0) to prevent hook execution blocking
- JavaScript: Error messages logged to stderr where appropriate, with fallback silent exits
## Logging
- Shell: Direct output using `echo` with color variables for styling
- JavaScript: `console.error` for errors, `process.stdout.write` for structured output
- Shell: Always check if stdout is a terminal before using colors: `if [[ -t 1 ]]`
- Shell: Include context in messages: `echo "${RED}error:${RESET} $*"`
- JavaScript hooks: Output JSON for structured hook responses via `process.stdout.write(JSON.stringify(output))`
- JavaScript: Timeout guards to prevent hanging (e.g., 3000-10000ms depending on operation)
- Silent failure is preferred in hooks (exit 0) rather than generating visible errors
## Comments
- Comment shell source directives with `# shellcheck source=<path>` for static analysis
- Hook files include detailed header comments with version info and behavior explanation
- Complex logic explained (e.g., color threshold logic in `gsd-statusline.js`)
- Process tree inspection and state detection logic documented
- Not used in this codebase
- Comments are generally inline and pragmatic rather than formal documentation style
## Function Design
- Functions kept relatively small and focused (typically 10-40 lines)
- Helper functions broken out for reusability (e.g., `detect_claude_state` is separated from `spin_status_once`)
- Shell: Functions accept positional arguments, typically passed as arrays or multiple args
- Shell: Early argument validation with die/warn functions
- JavaScript: Functions accept single configuration object or multiple parameters as needed
- Shell: Functions return exit codes (0 for success)
- Shell: Status information passed via output (echo)
- JavaScript: Exit codes used to signal success/failure, stdout for structured data
- Shell functions use `return` for early exit or specific status codes
## Module Design
- Shell: Modules export functions and constants (sourced globally)
- Shell: No module.exports pattern - everything sourced is available
- JavaScript: CommonJS require pattern, with implicit exports (functions and constants defined at module level)
- Hooks are standalone executables with no exports
- Not applicable to this codebase (no barrel files detected)
## Specific Conventions
- All executable scripts use `set -euo pipefail` to:
- All variables wrapped in quotes to handle spaces: `"$var"` not `$var`
- Array expansion: `"${array[@]}"` pattern used for proper handling
- Prefer `[[ ]]` (bash) over `[ ]` (POSIX) for modern bash features
- Use `&&` and `||` for short-circuit evaluation where appropriate
- Use `tmux` commands with proper session/window/pane references
- Check process existence with `pgrep` and examine `/proc/<pid>/cmdline` for process validation
- Detach background processes with `disown` to prevent termination
- Capture terminal content with `tmux capture-pane` for state detection
- Parse captured content for specific patterns (prompts, permissions, errors)
- Handle terminal control sequences (ANSI escape codes) in output
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Single entry point with subcommand routing
- Shared library layer for common utilities
- Clear separation between command implementations
- No external dependencies beyond standard Unix tools (bash, tmux, git)
## Layers
- Purpose: Parses command arguments and routes to appropriate subcommand
- Location: `bin/spin`
- Contains: Main script with usage info and dispatch logic
- Depends on: `lib/spin-common.sh` for shared utilities
- Used by: Direct CLI invocation
- Purpose: Provides shared constants, utilities, and status detection logic
- Location: `lib/spin-common.sh`, `lib/spin-status.sh`, `lib/spin-claude.sh`
- Contains: Error handling, color output, tree drawing, session detection
- Depends on: bash builtins, Unix utilities (tmux, pgrep, ps)
- Used by: All command implementations
- Purpose: Implement specific features (launching sessions, monitoring status)
- Location: `lib/spin-claude.sh`, `lib/spin-status.sh`
- Contains: Business logic for each command
- Depends on: Common library, tmux, Claude CLI
- Used by: Entry point dispatcher
## Data Flow
- Session persistence: Stored in tmux session (requires tmux to remain running)
- Project context: Stored in tmux environment variable `SPIN_CWD`
- Process tracking: Detected dynamically via `/proc` filesystem inspection
- Output inspection: Live terminal content capture via `tmux capture-pane`
## Key Abstractions
- Purpose: Container for parallel Claude instances, each with isolated workspace
- Examples: `spin-assistant`, `spin-myproject` (named `spin-<dirname>`)
- Pattern: One session per project, multiple windows per session
- Purpose: Isolated execution context for Claude and manual shell access
- Examples: Left pane (Claude), right pane (shell)
- Pattern: Each window split horizontally into 2 panes for dual interaction
- Purpose: Determine what Claude is doing without active monitoring
- Examples: Check `/proc/<pid>/cmdline`, parse pane output
- Pattern: Multi-step detection - process alive check → output analysis → state classification
- Purpose: Visual indication of parallel session state
- Examples: `●` (working), `◉` (waiting), `○` (exited)
- Pattern: Consistent icon set across all output
## Entry Points
- Location: `/home/marc/Development/spin/bin/spin`
- Triggers: Direct invocation from shell
- Responsibilities:
- Location: `/home/marc/Development/spin/lib/spin-claude.sh`
- Triggers: When `bin/spin` receives `claude` subcommand
- Responsibilities:
- Location: `/home/marc/Development/spin/lib/spin-status.sh`
- Triggers: When `bin/spin` receives `status` subcommand
- Responsibilities:
## Error Handling
- `spin_die()`: Prints error message with RED prefix, exits with code 1
- `spin_warn()`: Prints warning message with YELLOW prefix, continues execution
- Validations: Check for minimum argument count, session existence, command validity
- Process errors: Gracefully handle missing panes, unavailable environment variables
- Invalid command: `spin_die "unknown command: $1"`
- Missing arguments: `[[ $# -eq 0 ]] && spin_die "no window names provided"`
- Existing session: `spin_warn "tmux session already exists, killing it"`
## Cross-Cutting Concerns
- Command arity check (correct number of arguments)
- Subcommand existence check
- Session name validation (no spaces, special chars)
- Automatically disabled when not a terminal (respects `[[ -t 1 ]]`)
- Uses ANSI escape codes stored in variables for easy customization
- Consistent use across all commands
- Tree drawing with branch and last-child connectors
- Status icons with color coding
- Cursor hiding during auto-refresh mode
- Signal handling for graceful exit
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
