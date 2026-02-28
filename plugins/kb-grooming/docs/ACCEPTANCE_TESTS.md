# KB Grooming — Acceptance Tests

## Purpose

The kb-grooming plugin performs two-phase documentation analysis (structural + semantic) and proposes fixes or creates GitHub issues. Tests verify that the structural scan script produces correct JSON output, the orchestration SKILL.md drives the pipeline correctly, and the setup wizard creates valid configs.

## Test Execution Order

1. Static checks (automated)
2. Script unit tests (automated)
3. Integration tests (manual)
4. Behavioral / E2E tests (manual)

## Automation Status

- ✅ Static checks — fully automated via bash
- ✅ Script unit tests — fully automated via bash
- ⚠️ Integration tests — manual (require Claude Code session)
- ⚠️ E2E tests — manual (require Claude Code session + GitHub)

---

## 1. Static Checks ✅

### 1.1 plugin.json is valid JSON

```bash
python3 -c "import json; json.load(open('plugins/kb-grooming/.claude-plugin/plugin.json'))" && echo "PASS" || echo "FAIL"
```

### 1.2 hooks.json is valid JSON

```bash
python3 -c "import json; json.load(open('plugins/kb-grooming/hooks/hooks.json'))" && echo "PASS" || echo "FAIL"
```

### 1.3 templates/kb-grooming.json is valid JSON

```bash
python3 -c "import json; json.load(open('plugins/kb-grooming/templates/kb-grooming.json'))" && echo "PASS" || echo "FAIL"
```

### 1.4 SKILL.md files have YAML frontmatter

```bash
for f in plugins/kb-grooming/commands/*/SKILL.md; do
  head -1 "$f" | grep -q '^---$' && echo "PASS: $f" || echo "FAIL: $f"
done
```

### 1.5 kb-structural-scan.sh is executable

```bash
test -x plugins/kb-grooming/scripts/kb-structural-scan.sh && echo "PASS" || echo "FAIL"
```

### 1.6 plugin.json has both commands and skills fields

```bash
python3 -c "
import json
p = json.load(open('plugins/kb-grooming/.claude-plugin/plugin.json'))
assert 'commands' in p, 'missing commands'
assert 'skills' in p, 'missing skills'
print('PASS')
"
```

### 1.7 Plugin registered in marketplace.json

```bash
python3 -c "
import json
m = json.load(open('.claude-plugin/marketplace.json'))
names = [p['name'] for p in m['plugins']]
assert 'kb-grooming' in names, 'not in marketplace'
print('PASS')
"
```

---

## 2. Script Unit Tests ✅

All tests use `env` for variable injection and absolute paths.

### 2.1 Scan produces valid JSON on this repo

**Objective:** Verify kb-structural-scan.sh outputs a valid JSON report path.

```bash
REPORT=$(env CLAUDE_PROJECT_DIR="/path/to/claude-plugins" bash plugins/kb-grooming/scripts/kb-structural-scan.sh)
python3 -c "import json; r = json.load(open('$REPORT')); assert 'findings' in r; assert 'summary' in r; print('PASS')"
```

**Expected:** PASS, report file exists, contains `findings` and `summary` keys.

### 2.2 Scan detects mandatory docs correctly

**Objective:** mandatoryDocs check finds missing README.md.

```bash
TMPDIR=$(mktemp -d)
echo "# Test" > "$TMPDIR/test.md"
REPORT=$(env CLAUDE_PROJECT_DIR="$TMPDIR" bash plugins/kb-grooming/scripts/kb-structural-scan.sh)
python3 -c "
import json
r = json.load(open('$REPORT'))
mandatory = [f for f in r['findings'] if f['check'] == 'mandatoryDocs']
assert len(mandatory) >= 1, f'Expected mandatoryDocs findings, got {len(mandatory)}'
files = [f['file'] for f in mandatory]
assert 'README.md' in files, f'Expected README.md in findings, got {files}'
print('PASS')
"
rm -rf "$TMPDIR"
```

### 2.3 Scan detects broken links

**Objective:** brokenLinks check finds links to non-existent files.

```bash
TMPDIR=$(mktemp -d)
echo "# Test" > "$TMPDIR/README.md"
printf '# Doc\n\nSee [guide](nonexistent.md) for details.\n' > "$TMPDIR/doc.md"
REPORT=$(env CLAUDE_PROJECT_DIR="$TMPDIR" bash plugins/kb-grooming/scripts/kb-structural-scan.sh)
python3 -c "
import json
r = json.load(open('$REPORT'))
broken = [f for f in r['findings'] if f['check'] == 'brokenLinks']
assert len(broken) >= 1, f'Expected broken link finding, got {len(broken)}'
print('PASS')
"
rm -rf "$TMPDIR"
```

### 2.4 Scan detects CLAUDE.md overflow

**Objective:** claudemdOverflow warns when CLAUDE.md exceeds limits.

```bash
TMPDIR=$(mktemp -d)
echo "# Test" > "$TMPDIR/README.md"
python3 -c "print('# CLAUDE\n' + 'line\n' * 250)" > "$TMPDIR/CLAUDE.md"
REPORT=$(env CLAUDE_PROJECT_DIR="$TMPDIR" bash plugins/kb-grooming/scripts/kb-structural-scan.sh)
python3 -c "
import json
r = json.load(open('$REPORT'))
overflow = [f for f in r['findings'] if f['check'] == 'claudemdOverflow']
assert len(overflow) >= 1, f'Expected overflow finding, got {len(overflow)}'
print('PASS')
"
rm -rf "$TMPDIR"
```

### 2.5 Scan respects disabled checks via config

**Objective:** Disabled checks are not run.

```bash
TMPDIR=$(mktemp -d)
echo "# Test" > "$TMPDIR/README.md"
CONFIG=$(mktemp)
printf '{"checks":{"brokenLinks":false,"orphanDocs":false,"duplicateContent":false,"claudemdOverflow":false,"mandatoryDocs":false},"scope":{"include":["*.md"],"exclude":[]}}\n' > "$CONFIG"
REPORT=$(env CLAUDE_PROJECT_DIR="$TMPDIR" KB_CONFIG_FILE="$CONFIG" bash plugins/kb-grooming/scripts/kb-structural-scan.sh)
python3 -c "
import json
r = json.load(open('$REPORT'))
assert len(r['checksRun']) == 0, f'Expected no checks, got {r[\"checksRun\"]}'
assert len(r['findings']) == 0, f'Expected no findings, got {len(r[\"findings\"])}'
print('PASS')
"
rm -rf "$TMPDIR" "$CONFIG"
```

### 2.6 Scan with no markdown files produces empty report

**Objective:** Empty directory produces valid empty JSON report.

```bash
TMPDIR=$(mktemp -d)
REPORT=$(env CLAUDE_PROJECT_DIR="$TMPDIR" bash plugins/kb-grooming/scripts/kb-structural-scan.sh)
python3 -c "
import json
r = json.load(open('$REPORT'))
assert r['summary']['filesScanned'] == 0
assert r['summary']['total'] == 0
print('PASS')
"
rm -rf "$TMPDIR"
```

### 2.7 Scan detects orphan documents

**Objective:** orphanDocs finds files with zero incoming references.

```bash
TMPDIR=$(mktemp -d)
echo "# Project" > "$TMPDIR/README.md"
echo "# Orphan" > "$TMPDIR/orphan.md"
echo "See [readme](README.md)" > "$TMPDIR/linked.md"
REPORT=$(env CLAUDE_PROJECT_DIR="$TMPDIR" bash plugins/kb-grooming/scripts/kb-structural-scan.sh)
python3 -c "
import json
r = json.load(open('$REPORT'))
orphans = [f for f in r['findings'] if f['check'] == 'orphanDocs']
orphan_files = [f['file'] for f in orphans]
assert 'orphan.md' in orphan_files, f'Expected orphan.md, got {orphan_files}'
print('PASS')
"
rm -rf "$TMPDIR"
```

---

## 3. Integration Tests ⚠️

### 3.1 /kb-groom on this repo

**Objective:** Full pipeline runs on claude-plugins repo.

**Steps:**
1. Start fresh Claude Code session with kb-grooming plugin enabled
2. Run `/kb-groom`
3. Verify: config loaded (defaults or existing)
4. Verify: structural scan completes, status block displayed
5. Verify: semantic analysis runs (if semantic checks enabled)
6. Verify: findings displayed by type with counts
7. Verify: GitHub issues offered (epic + child issues)
8. Verify: declining issues produces report file in `docs/audit/`

**Expected:** Complete pipeline with no errors. Findings should be accurate for this repo.

### 3.2 /kb-groom with all checks disabled

**Steps:**
1. Create config with all checks set to `false`
2. Run `/kb-groom`

**Expected:** "No checks enabled" message or empty results.

### 3.3 /kb-grooming-setup wizard

**Steps:**
1. Run `/kb-grooming-setup`
2. Walk through all wizard steps
3. Verify config file written at chosen location
4. Verify JSON is valid and contains all selected options

**Expected:** Config file created with correct content.

---

## 4. E2E Tests ⚠️

### 4.1 GitHub issue creation

**Steps:**
1. Run `/kb-groom` on a repo with `gh` authenticated
2. Select issues to create
3. Verify epic issue created with status summary in body
4. Verify child issues created with correct labels and body
5. Verify child issues reference parent epic

**Expected:** Epic + child issues created with `documentation` and `kb-grooming` labels.

### 4.2 Decline issues — report file fallback

**Steps:**
1. Run `/kb-groom` on a repo with findings
2. Decline all issue options
3. Verify report file created at `docs/audit/kb-grooming-report-YYYY-MM-DD.md`
4. Verify report contains all findings grouped by type

**Expected:** Report file with full findings, no issues created.

---

## Regression Testing

- **Run tests 1.x and 2.x** automatically before any release (version bump)
- **Run test 3.1** after changes to `kb-structural-scan.sh` or `kb-groom/SKILL.md`
- **Run test 3.3** after changes to `kb-grooming-setup/SKILL.md`
- **Run tests 4.x** after changes to GitHub issue or report file logic
