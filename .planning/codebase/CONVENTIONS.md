# Coding Conventions

**Analysis Date:** 2026-03-30

## Naming Patterns

**Files:**
- Shell scripts: `spin-<purpose>.sh` format (e.g., `spin-claude.sh`, `spin-status.sh`, `spin-common.sh`)
- Main entry point: `spin` (no extension)
- Hook files: `gsd-<purpose>.js` format (e.g., `gsd-workflow-guard.js`, `gsd-context-monitor.js`)
- All lowercase with hyphens separating words

**Functions:**
- Shell: `snake_case` with underscore separator (e.g., `spin_die`, `spin_warn`, `spin_claude`, `spin_status_once`, `detect_claude_state`)
- JavaScript: `camelCase` for named functions and utility functions (e.g., `detectConfigDir`, `spawnProcess`)
- Prefix with namespace: Shell functions use `spin_` prefix for public functions

**Variables:**
- Shell: `UPPER_CASE` for constants and environment variables (e.g., `SPIN_VERSION`, `SPIN_SESSION_PREFIX`, `SPIN_ROOT`, `SPIN_LIB`)
- Shell: `snake_case` for local/temporary variables (e.g., `first`, `tmpdir`, `current`, `session_count`)
- Shell: Loop variables use conventional names (e.g., `for name in`, `while IFS= read -r`)
- JavaScript: `camelCase` for variables and constants (e.g., `sessionId`, `projectDir`, `staleHooks`)

**Types/Constants:**
- Shell: Color codes defined as variables: `RED`, `GREEN`, `YELLOW`, `CYAN`, `BOLD`, `DIM`, `RESET`
- Shell: Status icons as constants: `ICON_WORKING`, `ICON_WAITING`, `ICON_PERMISSION`, `ICON_EXITED`
- Shell: Tree drawing characters: `TREE_BRANCH`, `TREE_LAST`, `TREE_PIPE`

## Code Style

**Formatting:**
- Shell scripts: 2-space indentation (observed in `lib/spin-status.sh` and other files)
- JavaScript hooks: 2-space indentation (observed in all hook files)
- Line length: Generally kept reasonable, with comments not exceeding typical terminal width
- Blank lines: Used between logical sections for readability

**Linting:**
- Shell: Use of `shellcheck` is indicated by `# shellcheck source=` annotations (e.g., in `bin/spin`)
- Shell: Strict mode enabled with `set -euo pipefail` (error on undefined variables, exit on error, fail on pipe errors)
- JavaScript: Follows Node.js/CommonJS conventions
- No formal linter configuration detected (no .eslintrc, .prettierrc files)

## Import Organization

**Shell:**
- Use `source` directive to load library files from relative paths
- Source directives include shellcheck annotations for static analysis
- Order: source common utilities first, then specialized modules
- Example from `bin/spin`:
  ```bash
  source "$SPIN_LIB/spin-common.sh"
  # ... later ...
  source "$SPIN_LIB/spin-claude.sh"
  ```

**JavaScript:**
- Use `const` for require statements and module imports
- Group imports by type: standard library (fs, path, os, child_process) first, then local modules
- Example from hooks:
  ```javascript
  const fs = require('fs');
  const path = require('path');
  const os = require('os');
  const { spawn } = require('child_process');
  ```

## Error Handling

**Patterns:**
- Shell: Use `spin_die` function for fatal errors (logs error to stderr and exits with code 1)
- Shell: Use `spin_warn` function for non-fatal warnings (logs to stderr but continues)
- Shell: Defensive checks with `[[ condition ]] &&` pattern for quick exits
- JavaScript: Try-catch blocks with silent fail-through (exit 0) to prevent hook execution blocking
- JavaScript: Error messages logged to stderr where appropriate, with fallback silent exits

**Examples:**
```bash
# Shell error handling
[[ $# -eq 0 ]] && spin_die "usage: spin claude <name1> [name2] ..."
spin_warn "tmux session '$session' already exists, killing it"

# JavaScript error handling
try {
  // operation
} catch (e) {
  // Silent fail — never block tool execution
  process.exit(0);
}
```

## Logging

**Framework:**
- Shell: Direct output using `echo` with color variables for styling
- JavaScript: `console.error` for errors, `process.stdout.write` for structured output

**Patterns:**
- Shell: Always check if stdout is a terminal before using colors: `if [[ -t 1 ]]`
- Shell: Include context in messages: `echo "${RED}error:${RESET} $*"`
- JavaScript hooks: Output JSON for structured hook responses via `process.stdout.write(JSON.stringify(output))`
- JavaScript: Timeout guards to prevent hanging (e.g., 3000-10000ms depending on operation)
- Silent failure is preferred in hooks (exit 0) rather than generating visible errors

## Comments

**When to Comment:**
- Comment shell source directives with `# shellcheck source=<path>` for static analysis
- Hook files include detailed header comments with version info and behavior explanation
- Complex logic explained (e.g., color threshold logic in `gsd-statusline.js`)
- Process tree inspection and state detection logic documented

**JSDoc/TSDoc:**
- Not used in this codebase
- Comments are generally inline and pragmatic rather than formal documentation style

## Function Design

**Size:**
- Functions kept relatively small and focused (typically 10-40 lines)
- Helper functions broken out for reusability (e.g., `detect_claude_state` is separated from `spin_status_once`)

**Parameters:**
- Shell: Functions accept positional arguments, typically passed as arrays or multiple args
- Shell: Early argument validation with die/warn functions
- JavaScript: Functions accept single configuration object or multiple parameters as needed

**Return Values:**
- Shell: Functions return exit codes (0 for success)
- Shell: Status information passed via output (echo)
- JavaScript: Exit codes used to signal success/failure, stdout for structured data
- Shell functions use `return` for early exit or specific status codes

## Module Design

**Exports:**
- Shell: Modules export functions and constants (sourced globally)
- Shell: No module.exports pattern - everything sourced is available
- JavaScript: CommonJS require pattern, with implicit exports (functions and constants defined at module level)
- Hooks are standalone executables with no exports

**Barrel Files:**
- Not applicable to this codebase (no barrel files detected)

## Specific Conventions

**Bash Strict Mode:**
- All executable scripts use `set -euo pipefail` to:
  - `e`: exit on error
  - `u`: error on undefined variables
  - `o pipefail`: fail if any command in pipe fails

**Variable Quoting:**
- All variables wrapped in quotes to handle spaces: `"$var"` not `$var`
- Array expansion: `"${array[@]}"` pattern used for proper handling

**Conditional Style:**
- Prefer `[[ ]]` (bash) over `[ ]` (POSIX) for modern bash features
- Use `&&` and `||` for short-circuit evaluation where appropriate

**Process Management:**
- Use `tmux` commands with proper session/window/pane references
- Check process existence with `pgrep` and examine `/proc/<pid>/cmdline` for process validation
- Detach background processes with `disown` to prevent termination

**Terminal Interaction:**
- Capture terminal content with `tmux capture-pane` for state detection
- Parse captured content for specific patterns (prompts, permissions, errors)
- Handle terminal control sequences (ANSI escape codes) in output

---

*Convention analysis: 2026-03-30*
