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
1. `{CLAUDE_PROJECT_DIR}/.claude/retroscope.json` (project-level)
2. `~/.claude/retroscope.json` (user-level)

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
- `autoPush` — git push after commit (default: `false`)
- `timezone` — timezone for date calculations (default: system)

## Step 3: Session Mode

**ONLY for `session` mode.**

### 3a. Determine session data source

Read `sessionSource` from config (default: `logs`).

| Value | Behavior |
|-------|----------|
| `logs` (default) | Read JSONL session file — complete and reliable even if context was compressed or cleared |
| `context` | Use current conversation context — faster, no file I/O, but may miss earlier turns if context was compressed (`/compact`) or cleared (`/clear`) |

### 3b. Source: `logs`

Find the JSONL file for the current session:

1. Get current session ID — read `$CLAUDE_SESSION_ID` env var, or fall back to extracting it from `~/.claude/projects/` by finding the most recently modified JSONL file under the encoded current project path.

2. Resolve script path — `SCRIPT_DIR` = `${SKILL_DIR}/../../scripts` (i.e., `scripts/` at the plugin root).

3. Run stats first:
   ```bash
   PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --stats "{session_file}"
   ```

4. Extract conversation text:
   ```bash
   PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --extract "{session_file}"
   ```
   (No `--date` filter — include all messages regardless of when session started.)

5. Read `${SKILL_DIR}/references/report-template.md`

6. Generate the report from the extracted text. Use `inherit` model (generate directly, no subagent — session reports don't benefit from a haiku subagent since Claude already has context).

7. Display in terminal. **Do NOT save to disk** — session reports are display-only.

### 3c. Source: `context`

> ⚠️ **Note:** Context may be incomplete if the conversation was compacted or cleared. Use `logs` for reliable coverage of the full session.

1. Read `${SKILL_DIR}/references/report-template.md`
2. Fill in the template from the current conversation history in context:
   - Review all visible conversation turns
   - Project = current working directory name
   - Date = today's date
   - Session count = 1 (current session)
3. Display in terminal. **Do NOT save to disk.**

Stop here for `session` mode.

## Step 4: Find Sessions (today/yesterday)

Run `find-sessions.py` to locate matching session files:

```bash
PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py {today|yesterday} \
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

If `force` is set: skip cache check entirely, always regenerate.

Otherwise, if the file exists:
- Get modification time of summary.md
- Get modification times of all session files
- If summary.md is newer than ALL session files → display cached report and stop

## Step 6: Gather Stats

For each session file, run:
```bash
PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --stats "{session_file}"
```

Collect: token totals, tool counts, duration, branches, models.

From each stats JSON, collect both `estimated_cost_usd` (actual cost with cache discounts) and `naive_cost_usd` (all input tokens at full rate, matches Claude Code UI display). Show both in the Productivity Metrics section.

Aggregate across all sessions for the Overview and Productivity Metrics sections.

## Step 7: Extract Session Content

**If `extractMode: true` (default):**

For each session file, run:
```bash
PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --extract "{session_file}" --date "{YYYY-MM-DD}"
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
3. **If config `model` is `haiku`**: use the Task tool with `subagent_type: general-purpose` and `model: haiku` to generate the report body. Pass the extracted session text and template as context.
4. **If config `model` is `sonnet`**: use the Task tool with `subagent_type: general-purpose` and `model: sonnet` to generate the report body. Pass the extracted session text and template as context.
5. **If config `model` is `inherit`**: generate directly (current session model)

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
