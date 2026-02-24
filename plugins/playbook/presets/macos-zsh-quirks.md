---
name: macos-zsh-quirks
description: "Zsh Bash tool quirks: CWD persistence, echo escapes, absolute paths, env vars"
tags: [bash, zsh, macos]
---

<!-- RULES -->
## macOS Zsh Quirks — Base Rules

MANDATORY: Shell is `/bin/zsh` 5.9. CWD does NOT persist between Bash tool calls.

- ALWAYS use absolute paths for files and scripts — CWD resets between calls
- NEVER use `cd` to set working directory — use `git -C /path` for git, absolute paths for everything else
- NEVER use `echo` for JSON strings — `echo` interprets `\n` in zsh; use `printf '%s'` instead
- ALWAYS use `env VAR=val command` for environment variable injection (not `VAR=val command`)
- Root cause of most "No such file" errors: CWD not set + relative path — fix with absolute paths
- When running Python scripts: ALWAYS prefix with `PYTHONPATH=""` (see macos-python preset)
- For full reference: invoke `/playbook-browse` and select "macos-zsh-quirks"
<!-- /RULES -->

<!-- REFERENCE -->
## Shell Environment

The Bash tool runs `/bin/zsh` 5.9, not bash. The parent process is `claude`. Key differences from interactive shell usage:

- **CWD does NOT persist** between separate Bash tool calls. Each call may start from the project root or an unpredictable directory.
- **Shell state is not preserved** — aliases, functions, variables set in one call are gone in the next.
- Only the working directory is set by the tool framework, but can drift across calls.

## CWD and Absolute Paths

The most common source of errors is assuming CWD is set correctly:

```bash
# WRONG — CWD may not be what you expect
cat config.json
python scripts/run.py
SCRIPT="plugins/foo/scripts/bar.sh"

# CORRECT — always use absolute paths
cat /absolute/path/to/config.json
PYTHONPATH="" python /absolute/path/to/scripts/run.py
SCRIPT="/absolute/path/to/plugins/foo/scripts/bar.sh"
```

For git operations, use `-C` instead of `cd`:

```bash
# WRONG
cd /path/to/repo && git status

# CORRECT
git -C /path/to/repo status
git -C /path/to/repo log --oneline -5
git -C /path/to/repo diff HEAD
```

## Echo vs Printf

Zsh's built-in `echo` interprets escape sequences (`\n`, `\t`, `\\`) by default, unlike bash. This silently corrupts JSON strings:

```bash
# WRONG — zsh echo turns \n into actual newlines
echo '{"tool_input":{"command":"git commit -m \"msg\""}}'
# May corrupt if message contains \n-like sequences

# CORRECT — printf '%s' passes strings verbatim
printf '%s' '{"tool_input":{"command":"git commit -m \"msg\""}}'
```

**Rule:** Use `printf '%s'` (or `printf '%s\n'` for trailing newline) for any JSON, file paths, or data piped to other commands.

## Environment Variable Injection

When passing environment variables to a command, prefer `env` for reliability:

```bash
# Works but less reliable in edge cases
CLAUDE_PROJECT_DIR=/tmp/test bash /path/to/script.sh

# Preferred — explicit, works everywhere
env CLAUDE_PROJECT_DIR=/tmp/test bash /path/to/script.sh
```

## Common Error Patterns

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| `bash: No such file or directory` | Relative path + wrong CWD | Use absolute path |
| `cd: no such file or directory` | CWD from previous call gone | Use absolute paths, not `cd` |
| JSON output has unexpected newlines | `echo` interpreting `\n` | Use `printf '%s'` |
| Script works manually but fails in Bash tool | CWD assumption wrong | Add absolute path prefix |
| Python import errors in Bash tool | CWD is a Python package dir | Prefix with `PYTHONPATH=""` |

## Debugging Checklist

When a Bash tool command fails unexpectedly:

1. **Check path** — Is it absolute? If relative, make it absolute.
2. **Check echo** — Are you piping JSON through `echo`? Switch to `printf '%s'`.
3. **Check CWD** — Run `pwd` as a separate call to see where you actually are.
4. **Check env vars** — Use `env VAR=val` pattern, not inline assignment.
5. **Check Python** — If running Python, add `PYTHONPATH=""` prefix.
<!-- /REFERENCE -->
