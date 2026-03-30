---
description: "Create conventional commits for current changes"
allowed-tools: ["Bash"]
argument-hint: "[commit-message-hint]"
---

# Git Commit Workflow

Create conventional commits for current changes. Optional hint: $ARGUMENTS

## Workflow

### See what has changed

!git status
!git diff --stat

### Apply these requirements

1. **Branch Check**: If on a protected branch (`dev`, `DEV`, `staging`, `STAGING`, `main`, `master`, `prod`, `PROD`), create a feature branch named after the changes
2. **Commit Strategy**: Group related changes into logical conventional commits (feat, fix, chore, docs, etc.)
3. **Keep Commits Atomic and Focused**: Group related changes into logical commits. Unrelated changes (e.g., local configs, WIP experiments, unrelated fixes) should be committed separately or excluded to maintain the atomic commit principle. Each commit should represent a single, cohesive change.
4. **Commit Creation**: Stage and commit each group with clear messages
5. **Verification**: Run `git status` to confirm all intended changes are committed

### Use conventional commit format

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation
- `chore:` for maintenance
- `style:` for formatting
- `refactor:` for code restructuring
- `test:` for test additions

### Never

- use `--no-verify` flag (bypasses quality checks)
- attempt to bypass tests or quality checks
- skip tests or quality checks
- mix unrelated changes in the same commit (keep commits atomic)

### Acceptable Git Workflows

While keeping commits atomic and focused:
- **Stashing**: Use `git stash` to temporarily shelve changes when switching contexts
- **Selective Staging**: Stage only related files with `git add <specific-files>` for atomic commits
- **WIP Commits**: Leave uncommitted work-in-progress changes when experimenting
- **User Prompts**: Claude may ask which files to include in a commit to ensure atomicity

## Execute

Execute the workflow now.
