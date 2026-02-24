---
name: ctx-show
description: >
  Show the full Claude Code session context assembled in load order.
  Outputs all CLAUDE.md files, auto-memory, and SessionStart hook output
  in one document with source separators.
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
5. Plugin SessionStart hooks (enabled plugins in `~/.claude/plugins/cache/`)

Each source is wrapped with `<!-- Source: ... -->` comments. Missing files are noted but do not cause errors.

## Steps

1. Resolve `PLUGIN_DIR` from `${SKILL_DIR}` — it is `${SKILL_DIR}/../../scripts`.

2. Run the script via Bash:

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

3. Display the result:
   - `--file` mode: show the file path. Offer to open or read the file.
   - `--stdout` mode: show the full output.

## Notes

- Requires `jq` for parsing `settings.json` and plugin hooks. If `jq` is missing, static file sources (CLAUDE.md, MEMORY.md) are still shown.
- SessionStart hook commands are executed in isolation — their output may differ slightly from a real session start (e.g., different working directory).
- For plugin hooks, the script uses `${CLAUDE_PLUGIN_ROOT}` substitution with the actual cache path.
