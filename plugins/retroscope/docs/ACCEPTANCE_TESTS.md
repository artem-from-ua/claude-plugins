# Retroscope Acceptance Tests

## Purpose

The retroscope plugin generates retrospective summaries from Claude Code session JSONL logs. Acceptance tests verify that session discovery, content extraction, statistics computation, report generation, storage, and hook behavior all work correctly.

Critical components to test:
- `find-sessions.py` (core Python script with 3 modes)
- Config loading (user-level + project-level fallback)
- `/retro` command behavior (session, today, yesterday modes)
- `/retroscope:setup` wizard
- SessionEnd hook suggestion

## Test Execution Order

1. Static checks (automated)
2. find-sessions.py unit tests (automated)
3. Config loading tests (automated)
4. /retro session mode (partially automated)
5. /retro today/yesterday mode (partially automated)
6. Storage and git commit (automated)
7. SessionEnd hook (automated)
8. Setup wizard (manual)

## Automation Status

- ✅ Fully automated: Tests 1, 2, 3, 6, 7
- 🟡 Partially automated: Tests 4, 5 (report quality requires human review)
- ⚠️ Manual only: Test 8 (interactive AskUserQuestion dialog)

## Automated Test Results (Last Run)

| Test | Status | Notes |
|------|--------|-------|
| 1.1 plugin.json valid | ✅ Pass | |
| 1.2 plugin.json has skills field | ✅ Pass | Required for skill discovery |
| 1.3 hooks.json valid | ✅ Pass | |
| 1.4 SKILL.md frontmatter | ✅ Pass | Both commands |
| 2.1 list mode — today | ✅ Pass | Found 3 sessions |
| 2.2 list mode — yesterday | ✅ Pass | 0 sessions (no sessions yesterday) |
| 2.3 stats mode | ✅ Pass | JSON output correct, includes estimated_cost_usd, pricing_model, pricing_source |
| 2.4 extract mode | ✅ Pass | User/assistant text extracted |
| 7.1 session-end.sh | ✅ Pass | Output shown when suggestRetroOnExit=true |
| 7.2 session-end.sh silent | ✅ Pass | No output when suggestRetroOnExit=false |

---

## Test Categories

### 1. Static Checks

**Objective:** Verify file structure, JSON validity, and SKILL.md frontmatter compliance.

**Automation:** ✅

**Steps:**
```bash
PLUGIN="/Users/artem/devel/claude-plugins/plugins/retroscope"

# 1.1 plugin.json is valid JSON
python3 -c "import json; json.load(open('$PLUGIN/.claude-plugin/plugin.json'))" && echo "plugin.json: OK"

# 1.2 plugin.json has required 'skills' field (CRITICAL for skill discovery)
python3 -c "
import json, sys
with open('$PLUGIN/.claude-plugin/plugin.json') as f:
    p = json.load(f)
assert 'skills' in p, 'MISSING skills field — commands will not be discoverable!'
assert isinstance(p['skills'], list) and len(p['skills']) > 0, 'skills field must be non-empty list'
print('plugin.json skills field: OK')
"

# 1.3 hooks.json is valid JSON
python3 -c "import json; json.load(open('$PLUGIN/hooks/hooks.json'))" && echo "hooks.json: OK"

# 1.4 templates/retroscope.json is valid JSON
python3 -c "import json; json.load(open('$PLUGIN/templates/retroscope.json'))" && echo "template: OK"

# 1.5 SKILL.md files have YAML frontmatter
python3 -c "
import re, sys
for path in [
    '$PLUGIN/commands/retro/SKILL.md',
    '$PLUGIN/commands/retroscope-setup/SKILL.md',
]:
    with open(path) as f:
        content = f.read()
    if content.startswith('---'):
        print(f'Frontmatter OK: {path.split(\"/\")[-2]}')
    else:
        print(f'MISSING frontmatter: {path}')
        sys.exit(1)
"

# 1.6 Scripts are executable
ls -la "$PLUGIN/scripts/"
```

**Expected result:**
- ✅ All JSON files parse without error
- ✅ `plugin.json` contains non-empty `"skills"` field (required for skill discovery)
- ✅ Both SKILL.md files start with `---` YAML frontmatter
- ✅ `inject-rules.sh`, `session-end.sh`, `find-sessions.py` are executable (`-rwxr-xr-x`)

> **Note:** The `"skills"` field in `plugin.json` is required by Claude Code to register SKILL.md files in the skill system. Without it, `/retro` and `/retroscope:setup` won't be discoverable even if the SKILL.md files exist in the cache. This was discovered during testing (see `docs/INITIAL_PLAN.md`).

---

### 2. find-sessions.py Unit Tests

**Objective:** Verify session discovery, extraction, and statistics for all three modes.

**Automation:** ✅

#### 2.1 List Mode — Today

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/retroscope/scripts/find-sessions.py"

PYTHONPATH="" python3 "$SCRIPT" today --project-dir /Users/artem/devel/claude-plugins 2>&1
```

**Expected result:**
- ✅ Outputs one or more `.jsonl` file paths
- ✅ Paths exist and are readable
- ✅ No errors on stderr
- ✅ Files are from `~/.claude/projects/-Users-artem-devel-claude-plugins/`

#### 2.2 List Mode — Yesterday

```bash
PYTHONPATH="" python3 "$SCRIPT" yesterday --project-dir /Users/artem/devel/claude-plugins 2>&1
```

**Expected result:**
- ✅ Outputs 0 or more `.jsonl` paths (empty is valid if no sessions yesterday)
- ✅ No crash even if no sessions found (stderr message is acceptable)

#### 2.3 List Mode — Date Range

```bash
PYTHONPATH="" python3 "$SCRIPT" "2026-02-01:2026-02-23" --project-dir /Users/artem/devel/claude-plugins 2>&1
```

**Expected result:**
- ✅ Returns sessions spanning the date range
- ✅ Handles date ranges with `:` separator

#### 2.4 List Mode — Unknown Project

```bash
PYTHONPATH="" python3 "$SCRIPT" today --project-dir /tmp/nonexistent-project-xyz 2>&1
```

**Expected result:**
- ✅ Error message on stderr: "No session directory found for: /tmp/nonexistent-project-xyz"
- ✅ Exit without crash

#### 2.5 Stats Mode

```bash
RECENT=$(ls -t ~/.claude/projects/-Users-artem-devel-claude-plugins/*.jsonl 2>/dev/null | head -1)
PYTHONPATH="" python3 "$SCRIPT" --stats "$RECENT" 2>&1
```

**Expected result:**
- ✅ Valid JSON on stdout
- ✅ Contains: `session_id`, `slug`, `branches`, `models`, `time_range`, `message_counts`, `token_usage`, `tool_counts`
- ✅ Contains: `estimated_cost_usd` (float, ≥0), `naive_cost_usd` (float, ≥ estimated_cost_usd), `pricing_model` (string like `sonnet-4.6`), `pricing_source` (string: `fetched`, `cached`, or `static`)
- ✅ `message_counts.user > 0` and `message_counts.assistant > 0`
- ✅ `time_range.start` and `time_range.end` are valid ISO timestamps
- ✅ `token_usage.output_tokens > 0`

Verify JSON structure:
```bash
RECENT=$(ls -t ~/.claude/projects/-Users-artem-devel-claude-plugins/*.jsonl 2>/dev/null | head -1)
PYTHONPATH="" python3 "$SCRIPT" --stats "$RECENT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['session_id'], 'session_id missing'
assert data['time_range']['start'], 'time_range.start missing'
assert data['message_counts']['user'] > 0, 'no user messages'
assert data['message_counts']['assistant'] > 0, 'no assistant messages'
assert data['token_usage']['output_tokens'] > 0, 'no output tokens'
assert 'estimated_cost_usd' in data, 'estimated_cost_usd missing'
assert isinstance(data['estimated_cost_usd'], (int, float)), 'estimated_cost_usd must be numeric'
assert data['estimated_cost_usd'] >= 0, 'cost must be non-negative'
assert 'naive_cost_usd' in data, 'naive_cost_usd missing'
assert isinstance(data['naive_cost_usd'], (int, float)), 'naive_cost_usd must be numeric'
assert data['naive_cost_usd'] >= data['estimated_cost_usd'], 'naive_cost must be >= estimated_cost'
assert 'pricing_model' in data, 'pricing_model missing'
assert isinstance(data['pricing_model'], str), 'pricing_model must be a string'
assert data.get('pricing_source') in ('fetched', 'cached', 'static'), f'unexpected pricing_source: {data.get(\"pricing_source\")}'
actual = data['estimated_cost_usd']
naive = data['naive_cost_usd']
ratio = naive / actual if actual > 0 else 0
print(f'Stats validation: OK (actual: \${actual:.4f}, naive: \${naive:.4f}, ratio: {ratio:.1f}x, model: {data[\"pricing_model\"]} [{data[\"pricing_source\"]}])')
"
```

#### 2.6 Extract Mode

```bash
RECENT=$(ls -t ~/.claude/projects/-Users-artem-devel-claude-plugins/*.jsonl 2>/dev/null | head -1)
PYTHONPATH="" python3 "$SCRIPT" --extract "$RECENT" --date 2026-02-23 2>&1 | head -20
```

**Expected result:**
- ✅ Output contains `[YYYY-MM-DDTHH:MM | user]` headers
- ✅ Output contains `[YYYY-MM-DDTHH:MM | assistant` headers (possibly with `| tools: ToolName`)
- ✅ No `tool_result` or `tool_use` JSON blobs in output
- ✅ Tool names listed after `tools:` separator

#### 2.7 Extract Mode — Date Filter

```bash
RECENT=$(ls -t ~/.claude/projects/-Users-artem-devel-claude-plugins/*.jsonl 2>/dev/null | head -1)
# Test with wrong date (should produce no output)
PYTHONPATH="" python3 "$SCRIPT" --extract "$RECENT" --date 2020-01-01 2>&1
```

**Expected result:**
- ✅ No output (no messages from that date)
- ✅ No crash

---

### 3. Config Loading Tests

**Objective:** Verify config file fallback logic works correctly.

**Automation:** ✅

#### 3.1 Template Config Valid

```bash
PLUGIN="/Users/artem/devel/claude-plugins/plugins/retroscope"
python3 -c "
import json
with open('$PLUGIN/templates/retroscope.json') as f:
    cfg = json.load(f)
required = ['storageDir', 'language', 'model', 'extractMode', 'suggestRetroOnExit', 'autoPush']
for key in required:
    assert key in cfg, f'Missing key: {key}'
assert cfg['model'] in ('haiku', 'sonnet', 'inherit'), f'Invalid model: {cfg[\"model\"]}'
assert isinstance(cfg['extractMode'], bool), 'extractMode must be bool'
assert isinstance(cfg['suggestRetroOnExit'], bool), 'suggestRetroOnExit must be bool'
assert isinstance(cfg['autoPush'], bool), 'autoPush must be bool'
print('Template config: all fields valid')
"
```

**Expected result:**
- ✅ All required keys present
- ✅ `model` is one of `haiku`, `sonnet`, `inherit`
- ✅ Boolean fields are actual booleans (not strings)

---

### 4. /retro Session Mode

**Objective:** Verify that `/retro session` generates a report from current conversation context without saving.

**Automation:** 🟡 (automated invocation; report quality requires human review)

#### 4.1 Session Report Generation

**Steps:**
1. In an active Claude Code session with retroscope enabled:
   ```
   /retro session
   ```
2. Claude should NOT read any JSONL files (it uses current context)
3. Claude should NOT save any files
4. Report should appear in terminal

**Expected result:**
- ✅ Report displayed in terminal with all sections from template
- ✅ No file writes (check with `git status` in storage dir)
- ✅ Contains correct project name, date, branch
- ✅ No error messages

---

### 5. /retro Today/Yesterday Mode

**Objective:** Verify session discovery, extraction, report generation, and storage for daily reports.

**Automation:** 🟡 (requires configured storage dir)

#### 5.1 No Config → Setup Prompt First

When retroscope config is absent, `/retro` must ask about setup **before** offering a mode choice.

**Steps:**
1. Ensure no config exists:
   ```bash
   ls ~/.claude/retroscope.json 2>/dev/null && echo "exists" || echo "not found"
   ls .claude/retroscope.json 2>/dev/null && echo "exists" || echo "not found"
   ```
2. Run any `/retro` command (with or without mode argument):
   ```
   /retro
   ```

**Expected result:**
- ✅ Claude detects missing config **before** asking which mode to use
- ✅ AskUserQuestion dialog appears with two options:
  - "Yes, run setup now" → invokes `/retroscope:setup` and stops
  - "No, continue without config" → proceeds in `session` mode only (no mode selection dialog shown)
- ✅ If user picks "No, continue without config" → session report shown with tip: "💡 Tip: Run `/retroscope:setup` to enable daily reports (today/yesterday)."
- ✅ Does NOT show mode selection dialog when no config found
- ✅ Does NOT crash or generate empty report

**Negative test — explicit mode with no config:**
```
/retro today
```
- ✅ Still shows setup prompt first (config check precedes mode resolution)
- ✅ If user picks "No, continue without config" → Claude explains that today/yesterday mode requires storage config and shows session report instead

#### 5.2 Today Report (with config)

Prereq: Run `/retroscope:setup` first (see Test 8).

```
/retro today
```

**Expected result:**
- ✅ Lists session files found
- ✅ Generates report with all template sections
- ✅ Saves to `{storageDir}/reports/{project}/daily/{YYYY}/{MM}/{DD}/summary.md`
- ✅ Git commit created in storage repo
- ✅ Report path shown to user

#### 5.3 Caching — Second Run

Run `/retro today` again immediately after 5.2.

**Expected result:**
- ✅ Claude detects existing summary.md is newer than session files
- ✅ Shows cached report without regenerating
- ✅ Message indicates cached result (or simply displays quickly without running extraction)

#### 5.4 Force Regenerate (`--force` flag)

Run `/retro today --force` immediately after 5.3 (when cache is still fresh).

**Expected result:**
- ✅ Claude skips cache check entirely (does NOT display cached report)
- ✅ Runs full extraction and regeneration pipeline
- ✅ New report written to summary.md and git-committed
- ✅ Works with all modes: `/retro today --force`, `/retro yesterday --force`, `/retro session --force`

#### 5.5 Report Template Sections

After generating a report (5.2 or 5.4), inspect `summary.md`:

```bash
STORAGE_DIR="/tmp/retroscope-test"
PROJECT="claude-plugins"
DATE=$(date +%Y/%m/%d)
grep "^##" "$STORAGE_DIR/reports/$PROJECT/daily/$DATE/summary.md"
```

**Expected result:**
- ✅ Contains `## 📊 Overview`
- ✅ Contains `## 🎯 Performance Assessment`
- ✅ Contains `## 📝 Tasks & Outcomes`
- ✅ Contains `## 📄 Documentation Changes`
- ✅ Contains `## 💬 Communication Insights`
- ✅ Contains `## 📈 Productivity Metrics`
- ✅ Contains `## 🔮 Next Steps`
- ✅ Does NOT contain `## 🔗 References` (removed in v0.1.3)

#### 5.6 Dual Cost Display

Inspect the Productivity Metrics section of a generated report:

```bash
grep -A3 "Productivity Metrics" "$STORAGE_DIR/reports/$PROJECT/daily/$DATE/summary.md"
```

**Expected result:**
- ✅ Contains `Estimated cost:` line
- ✅ Shows actual cost with `(with cache discounts)` label
- ✅ Shows naive cost with `(without cache discounts` or `as shown in Claude Code UI)` label
- ✅ Naive cost ≥ actual cost

---

### 6. Storage and Git Commit

**Objective:** Verify report file is created at correct path and git commit is made.

**Automation:** ✅ (after running a `/retro today` test)

```bash
# Assumes storageDir is set to /tmp/retroscope-test
STORAGE_DIR="/tmp/retroscope-test"
PROJECT="claude-plugins"
DATE=$(date +%Y/%m/%d)

# Check file exists
test -f "$STORAGE_DIR/reports/$PROJECT/daily/$DATE/summary.md" && echo "Report file: OK"

# Check git log
git -C "$STORAGE_DIR" log --oneline -3
```

**Expected result:**
- ✅ `summary.md` exists at expected path
- ✅ Git log shows commit like `retro(claude-plugins): 2026-02-23 daily summary`
- ✅ File contains all template sections (Overview, Tasks & Outcomes, Documentation Changes, Communication Insights, Productivity Metrics, Next Steps)
- ✅ No `## 🔗 References` section (removed in v0.1.3 — references are now inline in Links column)

---

### 7. SessionEnd Hook

**Objective:** Verify session-end.sh outputs suggestion when configured.

**Automation:** ✅

#### 7.1 Suggestion Shown (suggestRetroOnExit=true)

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/retroscope/scripts/session-end.sh"

# Create temp config with suggestRetroOnExit=true
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
printf '%s' '{"suggestRetroOnExit": true}' > "$TMPDIR/.claude/retroscope.json"

env CLAUDE_PROJECT_DIR="$TMPDIR" bash "$SCRIPT"
rm -rf "$TMPDIR"
```

**Expected result:**
- ✅ Output contains: `💡 Run `/retro session` to save a session summary before exiting.`

#### 7.2 Silent When Disabled (suggestRetroOnExit=false)

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/retroscope/scripts/session-end.sh"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
printf '%s' '{"suggestRetroOnExit": false}' > "$TMPDIR/.claude/retroscope.json"

OUTPUT=$(env CLAUDE_PROJECT_DIR="$TMPDIR" bash "$SCRIPT")
if [ -z "$(echo "$OUTPUT" | tr -d '[:space:]')" ]; then
    echo "Silent mode: OK"
else
    echo "ERROR: unexpected output: $OUTPUT"
fi
rm -rf "$TMPDIR"
```

**Expected result:**
- ✅ No output (empty stdout after trimming whitespace)

#### 7.3 Default When No Config (no config file)

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/retroscope/scripts/session-end.sh"

env CLAUDE_PROJECT_DIR="/tmp/nonexistent-project-xyz-retroscope" bash "$SCRIPT"
```

**Expected result:**
- ✅ Suggestion shown (default behavior when no config found)
- ✅ No crash, no error on stderr

---

### 8. Setup Wizard

**Objective:** Verify `/retroscope:setup` creates valid config files and initializes storage repo.

**Automation:** ⚠️ Manual only (interactive AskUserQuestion dialog)

#### Manual Test Procedure

**Step 1:** Start a fresh Claude Code session with retroscope plugin enabled.

**Step 2:** Ensure no existing retroscope config:
```bash
ls ~/.claude/retroscope.json 2>/dev/null && echo "exists" || echo "not found"
ls .claude/retroscope.json 2>/dev/null && echo "exists" || echo "not found"
```

**Step 3:** Run setup wizard:
```
/retroscope:setup
```

**Step 4:** Answer questions in the dialog:
- Storage directory: `/tmp/retroscope-test`
- Remote URL: Skip
- Language: English
- Model: haiku
- Extract mode: On
- Suggest on exit: Yes
- Auto-push: No

**Step 5:** Verify config files created:
```bash
cat ~/.claude/retroscope.json
cat .claude/retroscope.json
```

**Step 6:** Verify storage repo initialized:
```bash
ls /tmp/retroscope-test/
git -C /tmp/retroscope-test log --oneline
```

**Expected result at each step:**

| Step | Expected |
|------|----------|
| Step 3 | AskUserQuestion dialog appears with all 7 questions |
| Step 4 | Each question has sensible options; storage path allows text input |
| Step 5 | Both config files exist with all required fields |
| Step 6 | Storage dir exists, is a git repo, has initial commit |

**Failure modes:**

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Wizard doesn't start | Plugin not loaded | Check `/skills \| grep retroscope` |
| Config not written | Permission issue | Check directory permissions |
| git init failed | git not installed | Install git |
| Questions skipped | Plugin skill not in context | Restart session |

---

## Regression Testing Guide

### When to Run

Run acceptance tests:
1. Before creating any PR that modifies retroscope plugin files
2. After refactoring `find-sessions.py`
3. After adding new config options to templates
4. When Claude Code updates might affect JSONL format

### Quick Automated Suite

Run tests 1, 2, 3, 7 in one session:

```
Please run the retroscope acceptance tests: static checks, find-sessions.py unit tests, config validation, and SessionEnd hook tests. Use the steps from plugins/retroscope/docs/ACCEPTANCE_TESTS.md. Report pass/fail for each test.
```

### CI Integration

For CI pipelines, run static checks and unit tests:

```bash
# In CI: skip tests requiring ~/.claude/projects/ (no session data)
PLUGIN="/path/to/plugins/retroscope"
SCRIPT="$PLUGIN/scripts/find-sessions.py"

# Static checks
python3 -c "import json; json.load(open('$PLUGIN/.claude-plugin/plugin.json'))" || exit 1
python3 -c "import json; json.load(open('$PLUGIN/hooks/hooks.json'))" || exit 1
python3 -c "import json; json.load(open('$PLUGIN/templates/retroscope.json'))" || exit 1

# Script syntax check
PYTHONPATH="" python3 -m py_compile "$SCRIPT" && echo "find-sessions.py syntax: OK"

# Help text (no session data needed)
PYTHONPATH="" python3 "$SCRIPT" --help >/dev/null && echo "find-sessions.py --help: OK"
```

### Expected Success Rate

Based on plugin architecture:
- **find-sessions.py tests**: >99% (pure Python, no external dependencies beyond stdlib)
- **SessionEnd hook**: >99% (simple bash script)
- **Session report (session mode)**: ~90% (depends on model following SKILL.md instructions)
- **Daily report (today mode)**: ~85% (depends on session data availability and storage config)
