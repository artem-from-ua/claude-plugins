---
name: ctx-dump
description: >
  Dump the verbatim session context from Claude's memory to a file.
  Writes ALL context sources exactly as they appear in the context window —
  no re-reading from disk, no re-executing hooks.
  Complementary to ctx-show (disk audit vs memory dump).
  Keywords: dump context, memory dump, what does Claude see, in-memory context, verbatim context.
---

# /ctx-dump — Dump In-Memory Session Context

Dump the verbatim content from Claude's context window to a file.
Unlike `/ctx-show` (which re-reads disk), this outputs what Claude actually sees.

## Flags

| Flag | Description |
|------|-------------|
| `--file` | (default) Write to `/tmp/claude-context-dump-{timestamp}.md` and print the path |
| `--stdout` | Print full content to terminal instead of writing to file |

## Sources to Dump (in load order)

Scan your context window and extract ALL of the following. Each appears inside
`<system-reminder>` tags or as `claudeMd` blocks injected at session start.

1. **`~/.claude/CLAUDE.md`** — global user instructions (labeled "user's private global instructions for all projects")
2. **`{project}/CLAUDE.md`** — project instructions (labeled "project instructions, checked into the codebase")
3. **`~/.claude/projects/{hash}/memory/MEMORY.md`** — auto-memory (labeled "user's auto-memory, persists across conversations")
4. **All SessionStart hook outputs** — any other content blocks in `system-reminder` tags (plugin-injected rules, playbook presets, git-branch-naming rules, etc.)
5. **Available skills list** — the skill names and descriptions loaded at session start
6. **gitStatus** — the git status snapshot from conversation start
7. **currentDate** — the date injected at session start

## Output Format

```
# Session Context Dump (from memory)

Generated: {YYYY-MM-DD HH:MM}

---

## Source: ~/.claude/CLAUDE.md (global user instructions)

{verbatim content}

---

## Source: {project}/CLAUDE.md (project instructions)

{verbatim content}

---

## Source: Auto-memory (MEMORY.md)

{verbatim content}

---

## Source: SessionStart hook — {identifier}

{verbatim content for each hook output, repeat section as needed}

---

## Source: Available skills

{skill listing as it appears in context}

---

## Source: gitStatus

{verbatim git status block}

---

## Source: currentDate

{verbatim date value}
```

## Steps

1. Parse the flag argument. Default is `--file`.
2. Scan your current context window for all sources listed above.
3. For EACH source: copy the content **verbatim** — no translation, no abbreviation, no omission of "large blocks", no reformatting. Preserve original markdown, code blocks, and whitespace exactly as they appear.
4. Assemble the output following the format above.
5. **`--file` mode:** Use the Write tool to save to `/tmp/claude-context-dump-{timestamp}.md` (timestamp: `YYYYMMDD-HHMMSS`). Report the file path.
6. **`--stdout` mode:** Output the full assembled content directly in the response.

## Exclusions

Do NOT include:
- Claude Code's internal system prompt (tool descriptions, behavioral rules, tone instructions)
- The content of this SKILL.md itself
- Conversation history or user messages
