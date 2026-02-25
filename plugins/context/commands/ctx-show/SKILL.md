---
name: ctx-show
description: >
  Show the full Claude Code session context assembled in load order.
  Outputs all CLAUDE.md files, auto-memory, and SessionStart hook output
  in one document with source separators. Prints a summary table to stderr
  with scope, type, source, status, lines, tokens, and context% per source.
  Keywords: session context, what is loaded, show context, debug context, rules, hooks.
---

# /ctx-show — Show Full Session Context

Assemble and display everything Claude Code loads at session start, in load order.

## Flags

| Flag | Description |
|------|-------------|
| `--file` | (default) Write to `/tmp/claude-context-{timestamp}.md` and print the path |
| `--stdout` | Print full content to terminal |

## Sources (in load order)

1. `~/.claude/CLAUDE.md` — global user instructions
2. `{project}/CLAUDE.md` — project instructions
3. `~/.claude/projects/{hash}/memory/MEMORY.md` — auto-memory
4. Global SessionStart hooks (from `~/.claude/settings.json`)
5. Project SessionStart hooks (from `{project}/.claude/settings.json`)
6. Plugin SessionStart hooks (enabled plugins in `~/.claude/plugins/cache/`)

Each source is wrapped with `<!-- Source: ... -->` comments. Missing files are noted but do not cause errors.

## Summary Table

After the file is written (or content printed), a summary table is printed to **stderr** with:

| Column | Description |
|--------|-------------|
| Scope | `User` (global `~/.claude/`) or `Project` (project-level + plugins) |
| Type | CLAUDE.md · Memory · Plugin hook · User hook · Project hook · Playbook Preset |
| Source/ID | Shortened path (`~/`, `./`) or plugin identifier `name@marketplace (vX.Y.Z)` |
| Status | has content · missing/empty · command failed (shown as "script error" in Lines column) |
| Lines / ~Tokens | Content metrics; tokens ≈ chars/4 |
| Context% | Each source's share of total context |

Playbook presets (from `playbook@tribe-coding`) appear as individual rows when using playbook v0.3.1+.

## Steps

1. Resolve `PLUGIN_DIR` from `${SKILL_DIR}` — it is `${SKILL_DIR}/../../scripts`.

2. Run the script via Bash. It prints two paths on stdout: the context file path and the table file path.

   **Default (write to file):**
   ```bash
   bash "${SKILL_DIR}/../../scripts/ctx-show.sh"
   ```

   **With --stdout flag:**
   ```bash
   bash "${SKILL_DIR}/../../scripts/ctx-show.sh" --stdout
   ```

   **With --file flag (explicit):**
   ```bash
   bash "${SKILL_DIR}/../../scripts/ctx-show.sh" --file
   ```

3. After running the script, **always** read the table file (second line of output) using the Read tool and display its contents verbatim in the response. Example — if the script output is:
   ```
   /tmp/claude-context-20260225-123456.md
   /tmp/claude-ctx-table-20260225-123456.txt
   ```
   Then read `/tmp/claude-ctx-table-20260225-123456.txt` with the Read tool and show the table content.
   - `--file` mode: also show the context file path and offer to open or read it.
   - `--stdout` mode: also show the full context output.

## Notes

- Requires `jq` for parsing `settings.json` and plugin hooks. If `jq` is missing, static file sources (CLAUDE.md, MEMORY.md) are still shown.
- SessionStart hook commands are executed in isolation — their output may differ slightly from a real session start (e.g., different working directory).
- For plugin hooks, the script uses `${CLAUDE_PLUGIN_ROOT}` substitution with the actual cache path.
- Playbook preset splitting requires playbook plugin v0.3.1+ in cache (emits `<!-- Source: Plugin playbook@... Preset NAME -->` markers).
