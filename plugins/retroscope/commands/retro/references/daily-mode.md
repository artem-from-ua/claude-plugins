# Daily Mode — Implementation Reference (today/yesterday)

## Step 4: Find Sessions

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

Parse JSONL files via Bash — **never use the Read tool on `.jsonl` files** (they can exceed 256 KB / 25K tokens):
```bash
PYTHONPATH="" python3 -c "
import json, sys
for line in open(sys.argv[1]):
    obj = json.loads(line)
    if obj.get('type') in ('user', 'assistant'):
        print(json.dumps(obj))
" "{session_file}"
```

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
   **If the file already exists: Read it first, then use Edit to replace the content.** The Write tool blocks overwriting an unread file. Never skip the Read step when the file may exist from a previous run.

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
