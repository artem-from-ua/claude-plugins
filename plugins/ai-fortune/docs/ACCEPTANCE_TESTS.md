# AI Fortune Acceptance Tests

## Purpose

The ai-fortune plugin generates personalized career direction reports based on AI usage data and an adaptive interview. Acceptance tests verify that scripts parse data correctly, the command orchestrates all phases, and the report generates even with missing data sources.

Critical components to test:
- `parse-insights.py` (HTML → JSON extraction)
- `aggregate-sessions.py` (session metadata aggregation)
- `/ai-fortune` command (full orchestration flow)
- Persistent state (save/load `~/.claude/ai-fortune.json`)
- Graceful degradation (missing sources)

## Test Execution Order

1. Static checks (automated)
2. parse-insights.py tests (automated)
3. aggregate-sessions.py tests (automated)
4. Data access tests (automated)
5. Full flow (manual)
6. Graceful degradation (manual)

## Automation Status

- ✅ Fully automated: Tests 1, 2, 3, 4
- ⚠️ Manual only: Tests 5, 6 (require interactive interview + report quality review)

## Automated Test Results (Last Run)

| Test | Status | Notes |
|------|--------|-------|
| 1.1 plugin.json valid | | |
| 1.2 SKILL.md frontmatter | | |
| 1.3 Scripts compile | | |
| 2.1 parse-insights.py with real report | | |
| 2.2 parse-insights.py missing file | | |
| 3.1 aggregate-sessions.py --days 7 | | |
| 3.2 aggregate-sessions.py --days 0 | | |
| 4.1 settings.json readable | | |
| 4.2 technology-explainer.json readable | | |
| 4.3 session-meta directory exists | | |

---

## Test Categories

### 1. Static Checks

**Objective:** Verify file structure, JSON validity, script compilation, and SKILL.md frontmatter.

**Automation:** ✅

**Steps:**
```bash
PLUGIN="plugins/ai-fortune"

# 1.1 plugin.json is valid JSON with required fields
python3 -c "
import json, sys
with open('$PLUGIN/.claude-plugin/plugin.json') as f:
    p = json.load(f)
assert p['name'] == 'ai-fortune', f'wrong name: {p[\"name\"]}'
assert p['version'] == '0.1.0', f'wrong version: {p[\"version\"]}'
assert 'commands' in p, 'missing commands field'
print('plugin.json: OK')
"

# 1.2 SKILL.md has valid YAML frontmatter
python3 -c "
import re
with open('$PLUGIN/commands/ai-fortune/SKILL.md') as f:
    content = f.read()
assert content.startswith('---'), 'Missing YAML frontmatter delimiter'
parts = content.split('---', 2)
assert len(parts) >= 3, 'Incomplete frontmatter'
fm = parts[1]
assert 'name:' in fm, 'Missing name in frontmatter'
assert 'description:' in fm, 'Missing description in frontmatter'
print('SKILL.md frontmatter: OK')
"

# 1.3 Python scripts compile without errors
python3 -m py_compile $PLUGIN/scripts/parse-insights.py && echo "parse-insights.py: OK"
python3 -m py_compile $PLUGIN/scripts/aggregate-sessions.py && echo "aggregate-sessions.py: OK"

# 1.4 templates/ai-fortune.json is valid JSON
python3 -c "import json; json.load(open('$PLUGIN/templates/ai-fortune.json'))" && echo "template: OK"

# 1.5 Reference files exist
for f in interview-questions.md analysis-framework.md report-template.md; do
  test -f "$PLUGIN/commands/ai-fortune/references/$f" && echo "$f: OK" || echo "$f: MISSING"
done
```

**Expected:**
- ✅ All checks pass
- ✅ plugin.json has name `ai-fortune`, version `0.1.0`
- ✅ SKILL.md starts with `---` and has `name:` + `description:` in frontmatter
- ✅ Both scripts compile without errors

### 2. parse-insights.py

**Objective:** Verify HTML parsing extracts expected data structure from real report.

**Automation:** ✅

**Steps:**
```bash
PLUGIN="plugins/ai-fortune"
REPORT="$HOME/.claude/usage-data/report.html"

# 2.1 Parse real report — check output is valid JSON with expected keys
python3 $PLUGIN/scripts/parse-insights.py "$REPORT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
required = ['stats', 'project_areas', 'top_tools', 'languages', 'session_types', 'usage_narrative']
missing = [k for k in required if k not in data]
assert not missing, f'Missing keys: {missing}'
assert len(data['project_areas']) > 0, 'No project areas extracted'
assert len(data['top_tools']) > 0, 'No tools extracted'
assert data['stats'].get('messages', 0) > 0, 'No message count in stats'
print(f'parse-insights OK: {len(data[\"project_areas\"])} areas, {len(data[\"top_tools\"])} tools, {data[\"stats\"][\"messages\"]} messages')
"

# 2.2 Missing file — should exit 1 with error message
python3 $PLUGIN/scripts/parse-insights.py /nonexistent/file.html 2>&1; echo "exit: $?"
# Expected: stderr contains "Error: file not found", exit code 1
```

**Expected:**
- ✅ 2.1: Valid JSON output with `stats`, `project_areas`, `top_tools`, `languages`, `session_types`, `usage_narrative`
- ✅ 2.2: Exit code 1, stderr message about missing file

### 3. aggregate-sessions.py

**Objective:** Verify session metadata aggregation with different time windows.

**Automation:** ✅

**Steps:**
```bash
PLUGIN="plugins/ai-fortune"

# 3.1 Aggregate last 7 days — check output structure
python3 $PLUGIN/scripts/aggregate-sessions.py --days 7 | python3 -c "
import json, sys
data = json.load(sys.stdin)
required = ['sessions_total', 'projects', 'tool_distribution', 'complexity_indicators', 'averages']
missing = [k for k in required if k not in data]
assert not missing, f'Missing keys: {missing}'
assert data['period_days'] == 7
assert isinstance(data['projects'], list)
assert isinstance(data['complexity_indicators'], dict)
print(f'aggregate OK: {data[\"sessions_total\"]} sessions, {len(data[\"projects\"])} projects')
"

# 3.2 Aggregate 0 days — should return 0 sessions with empty lists
python3 $PLUGIN/scripts/aggregate-sessions.py --days 0 | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['sessions_total'] == 0, f'Expected 0 sessions, got {data[\"sessions_total\"]}'
assert data['averages']['messages_per_session'] == 0
print('aggregate --days 0: OK (0 sessions)')
"
```

**Expected:**
- ✅ 3.1: Valid JSON with `sessions_total > 0`, non-empty `projects` and `tool_distribution`
- ✅ 3.2: `sessions_total == 0`, all averages are 0

### 4. Data Access Tests

**Objective:** Verify the command can access required data sources.

**Automation:** ✅

**Steps:**
```bash
# 4.1 settings.json exists and has enabledPlugins
python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    s = json.load(f)
plugins = s.get('enabledPlugins', s.get('projects', {}).get('*', {}).get('enabledPlugins', []))
print(f'settings.json: {len(plugins)} plugins found')
"

# 4.2 technology-explainer.json (optional)
python3 -c "
import json, os
path = os.path.expanduser('~/.claude/technology-explainer.json')
if os.path.exists(path):
    with open(path) as f:
        t = json.load(f)
    techs = t.get('technologies', {})
    print(f'technology-explainer: {len(techs)} technologies configured')
else:
    print('technology-explainer: not found (optional)')
"

# 4.3 session-meta directory has files
python3 -c "
import os
d = os.path.expanduser('~/.claude/usage-data/session-meta')
if os.path.isdir(d):
    files = [f for f in os.listdir(d) if f.endswith('.json')]
    print(f'session-meta: {len(files)} files')
else:
    print('session-meta: directory not found')
"
```

**Expected:**
- ✅ 4.1: `settings.json` readable, reports plugin count
- ✅ 4.2: Reports technology count or "not found (optional)"
- ✅ 4.3: Reports session file count

### 5. Full Flow (Manual)

**Objective:** Verify end-to-end `/ai-fortune` command execution.

**Automation:** ⚠️ Manual

**Procedure:**
1. Start fresh Claude Code session
2. Run `/ai-fortune`
3. Verify Phase 1 data collection:
   - Asks for memory file path (or uses saved)
   - Asks for insights report path (or uses saved)
   - Runs both Python scripts successfully
   - Reads technology-explainer, settings, stats-cache
4. Verify Phase 2 interview:
   - Shows previous answers for questions < 6 months old
   - Re-asks questions >= 6 months old with previous answer as default
   - Skips questions answerable from data
   - Uses `AskUserQuestion` with proper options
5. Verify Phase 3 report:
   - Runs 3-5 WebSearch queries
   - Generates report matching template structure
   - Report includes all completed sections
   - Report displays in terminal (not saved to disk)
6. Verify state saved to `~/.claude/ai-fortune.json`

**Outcomes:**

| Step | Expected | Actual |
|------|----------|--------|
| Data collection | All available sources read | |
| Interview | 10-15 questions, adaptive logic works | |
| Web research | 3-5 searches executed | |
| Report | Full structure, evidence-based | |
| State save | File written with answers + paths | |

### 6. Graceful Degradation (Manual)

**Objective:** Verify the report generates even when most data sources are missing.

**Automation:** ⚠️ Manual

**Procedure:**
1. Temporarily rename `~/.claude/usage-data/report.html`
2. Temporarily rename `~/.claude/technology-explainer.json`
3. Run `/ai-fortune`, skip memory file
4. Verify:
   - Script failures noted but don't crash the flow
   - Interview runs normally
   - Report generates with available data
   - Data Sources table shows ❌ for missing sources
5. Restore renamed files

---

## Regression Testing Guide

### When to run:
- After modifying `parse-insights.py` or `aggregate-sessions.py`
- After changing SKILL.md orchestration flow
- After changing interview-questions.md
- After updating report-template.md or analysis-framework.md

### Quick automated suite:
```bash
PLUGIN="plugins/ai-fortune"
echo "=== Static Checks ==="
python3 -c "import json; json.load(open('$PLUGIN/.claude-plugin/plugin.json'))" && echo "PASS: plugin.json"
python3 -m py_compile $PLUGIN/scripts/parse-insights.py && echo "PASS: parse-insights.py compiles"
python3 -m py_compile $PLUGIN/scripts/aggregate-sessions.py && echo "PASS: aggregate-sessions.py compiles"

echo "=== Script Tests ==="
python3 $PLUGIN/scripts/parse-insights.py ~/.claude/usage-data/report.html > /dev/null && echo "PASS: parse-insights"
python3 $PLUGIN/scripts/aggregate-sessions.py --days 7 > /dev/null && echo "PASS: aggregate-sessions"
python3 $PLUGIN/scripts/aggregate-sessions.py --days 0 | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['sessions_total']==0" && echo "PASS: aggregate-sessions --days 0"
```

### Expected success rate:
- Automated tests: 100% (all should pass)
- Manual tests: Dependent on available data sources; minimum viable with just interview
