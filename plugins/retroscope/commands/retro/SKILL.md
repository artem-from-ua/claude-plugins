---
name: retro
description: >
  Generate retrospective summaries of Claude Code sessions.
  Use /retro session to summarize the current session (display only).
  Use /retro today or /retro yesterday to generate saved daily reports.
  Keywords: retro, retrospective, session summary, what did I do, daily report, productivity.
---

# /retro — Session Retrospective Report

Generate a retrospective summary of Claude Code session(s).

## Modes

| Mode | Description | Storage |
|------|-------------|---------|
| `session` | Summarize current session from context | Display only (not saved) |
| `today` | Aggregate all today's sessions | Saved to storage repo + git commit |
| `yesterday` | Aggregate all yesterday's sessions | Saved to storage repo + git commit |

Add `--force` to any mode to regenerate even if a cached report exists (e.g., `/retro today --force`).

## Step 1: Load Config

Look for config in this order:
1. `{CLAUDE_PROJECT_DIR}/.claude-plugin/retroscope.json` (project-level, preferred)
2. `{CLAUDE_PROJECT_DIR}/.claude/retroscope.json` (project-level, legacy fallback)
3. `~/.claude/retroscope.json` (user-level)

**If no config found:** ask the user whether to run setup now using AskUserQuestion:
- Option A: "Yes, run setup now" → invoke `/retroscope:setup` skill and **stop**.
- Option B: "No, continue without config" → continue with defaults (`sessionSource: logs`, display-only, no storage).

## Step 2: Determine Mode

**You MUST ask the user which mode they want. Do NOT skip this step or assume a default.**

If the user provided a mode argument (e.g., `/retro session`, `/retro today`), use it.
Otherwise use AskUserQuestion with options: `session`, `today`, `yesterday`.

Parse the user's argument for both mode and flags. If `--force` is present, set `force = true` and strip it from the mode argument before further processing.

**If no config was found** (user chose to continue without config):
- Only `session` mode is available (no storage configured for today/yesterday).
- Skip the mode question and use `session` mode directly, showing a note: "💡 Tip: Run `/retroscope:setup` to enable daily reports (today/yesterday)."

Config fields used:
- `storageDir` — where to save reports (REQUIRED for today/yesterday)
- `language` — report language (default: English)
- `model` — report generation model: `haiku`, `sonnet`, or `inherit` (default: `haiku`)
- `extractMode` — pre-filter sessions to text-only (default: `true`)
- `sessionSource` — data source for `/retro session`: `logs` (default) or `context`
- `scope` — report scope: `project` (default, current project only) or `all` (cross-project daily reports)
- `autoPush` — git push after commit (default: `false`)
- `timezone` — timezone for date calculations (default: system)

## Step 3: Execute Mode

**For `session` mode:** Read `${SKILL_DIR}/references/session-mode.md` and follow the steps there.

**For `today` or `yesterday` mode:** Read `${SKILL_DIR}/references/daily-mode.md` and follow the steps there.
