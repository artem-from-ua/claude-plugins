# Retroscope Plugin — Initial Implementation Plan

> Saved from the planning session (2026-02-23) that preceded v0.1.0 implementation.
> This document captures the original design decisions and rationale.

## Context

Create a `retroscope` plugin for the Tribe Coding marketplace that generates retrospective summary reports from Claude Code session data. The plugin reads JSONL session logs from `~/.claude/projects/` and produces structured markdown reports with status emoji, links, and productivity insights.

**Problem:** No built-in way to review what was accomplished in Claude Code sessions, track open questions, or analyze communication effectiveness.

**Outcome:** `/retro` command generates per-session and daily aggregated reports saved to a dedicated git repo.

## Architecture Overview

```
plugins/retroscope/
├── .claude-plugin/plugin.json          # manifest v0.1.0
├── hooks/hooks.json                    # SessionStart + SessionEnd
├── scripts/
│   ├── inject-rules.sh                 # SessionStart: inject /retro reminder
│   ├── session-end.sh                  # SessionEnd: suggest /retro session
│   └── find-sessions.py               # Session discovery + conversation extraction
├── commands/
│   ├── retro/SKILL.md                  # Main /retro command (session|today|yesterday)
│   └── retroscope-setup/SKILL.md       # Setup wizard
├── templates/
│   └── retroscope.json                 # Default config template
├── docs/
│   └── ACCEPTANCE_TESTS.md
└── README.md
```

**Data flow:** `/retro` SKILL.md → `find-sessions.py` (find + extract session text) → Claude reads extracted text → generates report → saves to storage repo

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Session-end behavior | SessionEnd hook suggests `/retro session` | `SessionEnd` hook exists (query: `prompt_input_exit`); fires on `exit`/`/exit` |
| Report language | Configurable per-project | Default from `settings.json` locale; ask during `/retroscope:setup` |
| Weekly rollup | TODO for v0.2.0 | `this-week`/`last-week` — architecture designed for future extension |
| Session data reading | Python 3.12 | Cross-platform date math, JSON parsing, encoding handling |
| Report generation | Claude (haiku model via agent) | Cheaper for summarization; configurable model in setup |
| Extract mode | Configurable option | On by default; can be disabled for full-context reports |

## Key Technical Decisions

### Model Selection for Report Generation

Claude Code supports model selection via **agents** (`agents/agent-name.md` with `model: haiku` in frontmatter). The `/retro` command can spawn a haiku agent for report generation, significantly reducing cost.

**Implementation:** Create `plugins/retroscope/agents/report-generator.md` with `model: haiku`. The `/retro` SKILL.md instructs Claude to use the Task tool with this agent for `today`/`yesterday` modes.

For `session` mode: use the current session model (inherits context, no agent needed).

**Config option:** `model` field in retroscope config (default: `haiku`, options: `haiku`, `sonnet`, `inherit`).

### Extract Mode (Configurable)

Extract mode pre-processes JSONL via Python script, outputting only user text + assistant text (no tool_result, tool_use, progress, file-history).

| | Extract ON (default) | Extract OFF |
|---|---|---|
| **Token cost** | ~80-90% reduction | Full session data |
| **Report quality** | Good for task tracking, decisions, links | Better for nuanced communication insights |
| **Speed** | Faster (less context) | Slower (more context) |
| **Tool details** | Tool names listed, not inputs/outputs | Full tool call details visible |
| **Recommended for** | Daily/yesterday reports, cost-sensitive | Session mode, deep analysis |

**Config option:** `extractMode` in retroscope config (default: `true`). For `session` mode, extract is always OFF (Claude already has full context).

### SessionEnd Hook

`SessionEnd` hook fires with query `prompt_input_exit` when user types `exit`. The hook script:
1. Reads project config `.claude-plugin/retroscope.json`
2. If `suggestRetroOnExit: true` → outputs suggestion message
3. Output is shown to user before session closes

**Limitation:** SessionEnd hooks are notification-only — they can output text but cannot execute `/retro session` automatically. The hook suggests the command, user must run it manually before exiting.

**Alternative approach:** The hook outputs a message like:
```
💡 Run `/retro session` to save a session summary before exiting.
```

## Files to Create

### 1. `plugins/retroscope/.claude-plugin/plugin.json`

```json
{
  "name": "retroscope",
  "version": "0.1.0",
  "description": "Retrospective session reports: summarize tasks, decisions, open questions from Claude Code sessions",
  "author": { "name": "Tribe Coding" },
  "license": "MIT",
  "commands": ["./commands/"]
}
```

### 2. `plugins/retroscope/hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/inject-rules.sh\"",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/session-end.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### 3. `plugins/retroscope/scripts/inject-rules.sh`

~60 tokens of rules:
- `/retro` command availability (modes: `session`, `today`, `yesterday`)
- Brief format hint

Pattern: follows `plugins/plantuml/scripts/inject-rules.sh` (PLUGIN_ROOT resolution, heredoc).

### 4. `plugins/retroscope/scripts/session-end.sh`

SessionEnd hook:
1. Read `.claude-plugin/retroscope.json` (or `.claude/retroscope.json` fallback) from `$CLAUDE_PROJECT_DIR`
2. If `suggestRetroOnExit` is true → output suggestion text
3. Silent if option is off or config doesn't exist

### 5. `plugins/retroscope/scripts/find-sessions.py`

**Core technical component.** Python 3.12. Two modes:

**List mode:** `find-sessions.py <today|yesterday|YYYY-MM-DD|YYYY-MM-DD:YYYY-MM-DD> [--project-dir DIR] [--tz TIMEZONE]`
- Derives encoded project path: `/Users/artem/devel/foo` → `-Users-artem-devel-foo`
- Lists `~/.claude/projects/<encoded>/*.jsonl`
- For each: mtime quick-filter → first/last line timestamp check
- Returns matching session file paths (one per line)
- **Date range support** (`YYYY-MM-DD:YYYY-MM-DD`) designed for future `this-week`/`last-week`

**Extract mode:** `find-sessions.py --extract <session.jsonl> [--date YYYY-MM-DD]`
- Filters to `user` and `assistant` types
- User: text only (skips tool_result)
- Assistant: text only (skips tool_use, lists tool names)
- Includes `pr-link` as metadata
- `--date` filter: only messages on that date (for multi-day sessions)
- Output: `[YYYY-MM-DDTHH:MM | role | tools: X,Y]\ntext`
- `errors='ignore'` for encoding resilience

**Stats mode:** `find-sessions.py --stats <session.jsonl>`
- Returns JSON with: message counts, token usage totals, tool call counts, time range, branches, model
- Used by report generator for the Productivity Metrics section without reading full content

### 6. `plugins/retroscope/commands/retro/SKILL.md`

Main command (~100 lines, hybrid skill with references).

**Parameter:** Accept mode as arg or ask via `AskUserQuestion`:
- `session` — current session summary
- `today` — all today's sessions
- `yesterday` — yesterday's sessions
- _(future: `this-week`, `last-week`)_

**Mode: `session`**
1. Claude has full conversation in context already
2. Generate report directly (no file reading, no extract mode)
3. Display in console only, do NOT save

**Mode: `today` / `yesterday`**
1. Read config: `.claude-plugin/retroscope.json` → fallback `.claude/retroscope.json` → fallback `~/.claude/retroscope.json`
2. If no config → suggest `/retroscope:setup`
3. Run `find-sessions.py <today|yesterday>` → session file paths
4. Check cached report `{storageDir}/reports/{project}/daily/{YYYY}/{MM}/{DD}/summary.md`:
   - If exists AND mtime > all session files → show cached, done
5. Run `find-sessions.py --stats` for each session → get metrics
6. If `extractMode` enabled: run `find-sessions.py --extract` for each session
7. If `extractMode` disabled: read raw JSONL (filtered to user/assistant via Read tool)
8. If config `model` is `haiku`/`sonnet`: spawn Task agent with that model
9. Generate report using template from `references/report-template.md`
10. Save to storage dir, create directories as needed
11. Git commit in storage repo
12. If `autoPush`: git push

**Report template** in `commands/retro/references/report-template.md`.

### 7. `plugins/retroscope/commands/retroscope-setup/SKILL.md`

Interactive wizard (~110 lines). Pattern: `plugins/git-branch-naming/commands/git-branch-naming-setup/SKILL.md`.

Config schema:
```json
{
  "storageDir": "/Users/artem/devel/retroscope",
  "remoteUrl": "https://github.com/artem-from-ua/retroscope",
  "language": "uk",
  "model": "haiku",
  "extractMode": true,
  "suggestRetroOnExit": true,
  "autoPush": false,
  "timezone": "Europe/Kyiv"
}
```

### 8. `plugins/retroscope/templates/retroscope.json`

Default config template with empty `storageDir`, `remoteUrl`, sensible defaults for the rest.

### 9. `plugins/retroscope/docs/ACCEPTANCE_TESTS.md`

Test categories:
1. Static checks — plugin.json, hooks.json, SKILL.md frontmatter
2. find-sessions.py — list mode, extract mode, stats mode, date filtering, edge cases
3. Config loading — user-level/project-level fallback, missing config
4. Report generation: session mode
5. Report generation: today/yesterday (with and without extract mode)
6. Storage and git commit
7. SessionEnd hook — suggestion output
8. Setup wizard

### 10. Register in marketplace

Add entry to `.claude-plugin/marketplace.json`.

## Future Roadmap (v0.2.0+)

**Designed in architecture, not yet implemented:**
- `/retro this-week` — aggregate daily reports Mon–today
- `/retro last-week` — aggregate daily reports Mon–Sun of previous week
- `find-sessions.py` already supports date ranges (`YYYY-MM-DD:YYYY-MM-DD`)
- Storage structure ready: `{storageDir}/reports/{project}/weekly/{YYYY}/W{WW}/summary.md`

**Other ideas:**
- **Streak tracking** — consecutive productive days, longest session, daily activity heatmap
- **Comparative analysis** — "today vs yesterday" productivity delta, trend charts
- **CLAUDE.md audit** — suggest CLAUDE.md rules based on repeated patterns across sessions
- **Cost tracking** — estimated $ per session/day/week from token usage data
- **Focus score** — ratio of on-task vs tangential exchanges, context switch frequency
- **Git stats integration** — lines added/removed, commits per session, files changed correlation
- **Export formats** — JSON, CSV for integration with external dashboards (Grafana, Notion, etc.)
- **Team mode** — shared storage repo, aggregated team reports, peer comparison
- **Smart reminders** — detect recurring open questions across sessions, escalate unresolved items
- **Session tagging** — auto-tag sessions by activity type (debugging, feature dev, review, docs)
- **Burnout detection** — flag long sessions with declining productivity, suggest breaks
- **CLAUDE.md changelog** — track CLAUDE.md changes and correlate with productivity shifts

## Drawbacks & Mitigations

| Drawback | Impact | Mitigation |
|----------|--------|------------|
| **Token cost** | `/retro today` uses ~20-60K tokens ($0.06-$0.18 Sonnet) | Extract mode (80-90% reduction), haiku model option, caching |
| **SessionEnd limitation** | Hook can suggest but not execute `/retro` | Output reminder text; user runs command manually |
| **Session data is internal API** | JSONL format may change | Python script isolates parsing; single file to update |
| **Multi-day sessions** | Needs per-message date filtering | `--date` flag in extract mode |
| **Large sessions (400+ msgs)** | May exceed context | Chunking in SKILL.md + extract mode |
| **Privacy** | Session data pushed to GitHub | Private repo; `.gitignore` for sensitive projects |
| **Haiku quality** | Cheaper model = potentially weaker summaries | Configurable; sonnet/inherit available |

## Implementation Order

1. Plugin skeleton: `plugin.json`, `hooks/hooks.json`, `inject-rules.sh`, `session-end.sh`
2. `find-sessions.py` (list + extract + stats modes)
3. `templates/retroscope.json`
4. `commands/retroscope-setup/SKILL.md`
5. `commands/retro/SKILL.md` + `commands/retro/references/report-template.md`
6. `docs/ACCEPTANCE_TESTS.md`
7. `README.md`
8. Register in `marketplace.json`
9. Version is already 0.1.0 (initial)
10. Create PR

## Verification

1. **find-sessions.py list**: `python3 find-sessions.py today --project-dir /Users/artem/devel/claude-plugins`
2. **find-sessions.py extract**: `python3 find-sessions.py --extract <session>.jsonl --date 2026-02-23`
3. **find-sessions.py stats**: `python3 find-sessions.py --stats <session>.jsonl`
4. **Setup**: run `/retroscope:setup` in a session with this plugin enabled
5. **Session report**: `/retro session` during active session
6. **Daily report**: `/retro today` — verify file created, git committed
7. **Caching**: `/retro today` again — shows cached without regeneration
8. **SessionEnd**: type `exit` — verify suggestion message appears (if enabled)

## Key Reference Files

- `plugins/git-branch-naming/commands/git-branch-naming-setup/SKILL.md` — setup wizard pattern
- `plugins/plantuml/scripts/inject-rules.sh` — SessionStart hook pattern
- `plugins/plantuml/.claude-plugin/plugin.json` — manifest format
- `plugins/plantuml/hooks/hooks.json` — hooks structure
- `~/.claude/projects/-Users-artem-devel-claude-plugins/*.jsonl` — real session data for testing
