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

## Step 1: Determine Mode

If the user provided a mode argument (e.g., `/retro session`, `/retro today`), use it.
Otherwise ask:

```
Use AskUserQuestion with options: session, today, yesterday
```

## Step 2: Load Config (today/yesterday only)

Look for config in this order:
1. `{CLAUDE_PROJECT_DIR}/.claude/retroscope.json` (project-level)
2. `~/.claude/retroscope.json` (user-level)

If no config found → tell the user to run `/retroscope:setup` first and stop.

Config fields used:
- `storageDir` — where to save reports (REQUIRED)
- `language` — report language (default: English)
- `model` — report generation model: `haiku`, `sonnet`, or `inherit` (default: `haiku`)
- `extractMode` — pre-filter sessions to text-only (default: `true`)
- `autoPush` — git push after commit (default: `false`)
- `timezone` — timezone for date calculations (default: system)

## Step 3: Session Mode

**ONLY for `session` mode:**

The full conversation is already in context. Generate the report directly:

1. Read `${SKILL_DIR}/references/report-template.md`
2. Fill in the template from conversation context:
   - Review the full conversation history
   - Project = current working directory name
   - Date = today's date
   - Session count = 1 (current session)
   - All other fields from conversation content
3. Display the report in the terminal
4. **Do NOT save to disk** — session reports are display-only

Stop here for `session` mode.

## Step 4: Find Sessions (today/yesterday)

Run `find-sessions.py` to locate matching session files:

```bash
python3 {SCRIPT_DIR}/find-sessions.py {today|yesterday} \
  --project-dir "{CLAUDE_PROJECT_DIR}" \
  --tz "{config.timezone}"
```

Where `{SCRIPT_DIR}` = `${SKILL_DIR}/../../scripts`.

If no sessions found: inform user and stop.

## Step 5: Check Cache

Determine report output path:
```
{storageDir}/reports/{project_name}/daily/{YYYY}/{MM}/{DD}/summary.md
```

Where `{project_name}` = basename of `CLAUDE_PROJECT_DIR`.

If the file exists:
- Get modification time of summary.md
- Get modification times of all session files
- If summary.md is newer than ALL session files → display cached report and stop

## Step 6: Gather Stats

For each session file, run:
```bash
python3 {SCRIPT_DIR}/find-sessions.py --stats "{session_file}"
```

Collect: token totals, tool counts, duration, branches, models.

Aggregate across all sessions for the Overview and Productivity Metrics sections.

## Step 7: Extract Session Content

**If `extractMode: true` (default):**

For each session file, run:
```bash
python3 {SCRIPT_DIR}/find-sessions.py --extract "{session_file}" --date "{YYYY-MM-DD}"
```

Concatenate all extracted text (with session separators).

**If `extractMode: false`:**

Read raw JSONL files directly (filter to `type: user` and `type: assistant` messages only).

**If combined content exceeds ~100K tokens:**
- Warn user about large session size
- Process only the most recent 50% of exchanges

## Step 8: Generate Report

1. Read `${SKILL_DIR}/references/report-template.md`
2. Generate report content based on the template and extracted session data
3. **If config `model` is `haiku` or `sonnet`**: use the Task tool with `subagent_type: haiku` or `subagent_type: sonnet` to generate the report body. Pass the extracted session text and template as context.
4. **If config `model` is `inherit`**: generate directly (current session model)

## Step 9: Save Report

1. Create directory structure:
   ```bash
   mkdir -p "{storageDir}/reports/{project_name}/daily/{YYYY}/{MM}/{DD}"
   ```

2. Write report to `summary.md`:
   ```
   {storageDir}/reports/{project_name}/daily/{YYYY}/{MM}/{DD}/summary.md
   ```

3. Git commit in storage repo:
   ```bash
   git -C "{storageDir}" add reports/{project_name}/daily/{YYYY}/{MM}/{DD}/summary.md
   git -C "{storageDir}" commit -m "retro({project_name}): {YYYY-MM-DD} daily summary"
   ```

4. If `autoPush: true`:
   ```bash
   git -C "{storageDir}" push
   ```

## Step 10: Display

Show the generated report in the terminal. Include the file path where it was saved.

## Error Handling

- **No sessions found**: `No {today|yesterday} sessions found for project {name}. Sessions are stored per-project directory.`
- **Storage dir doesn't exist**: `Storage directory '{dir}' not found. Run /retroscope:setup to configure.`
- **Git not initialized**: `Storage directory is not a git repo. Run: git -C '{dir}' init`
- **Large session**: warn and offer to process with extract mode ON even if configured OFF
