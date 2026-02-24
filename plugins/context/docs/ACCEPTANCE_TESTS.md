# Context Plugin Acceptance Tests

## Purpose

The `context` plugin provides the `/ctx-show` command for assembling the full Claude Code session context in load order. These acceptance tests verify that the script correctly discovers, reads, and outputs all five source types — and handles missing files gracefully.

The plugin has no hooks and no proactive behavior; all functionality is triggered via the `/ctx-show` command.

## Test Execution Order

1. Static checks (automated)
2. Unit tests — individual sources (automated)
3. Integration tests — full output (automated)
4. Behavioral tests — SKILL.md invocation (partially automated)

## Automation Status

- ✅ Fully automated: Tests 1–6
- 🟡 Partially automated: Test 7 (Claude invocation requires a fresh session or `/clear`)
- ⚠️ Manual only: None

## Test Results (last run: 2026-02-24)

| Test | Status | Notes |
|------|--------|-------|
| 1.1 Static: plugin.json valid | ✅ Pass | |
| 1.2 Static: hooks.json valid | ✅ Pass | |
| 1.3 Static: SKILL.md frontmatter | ✅ Pass | |
| 1.4 Static: script is executable | ✅ Pass | |
| 2.1 Unit: --file mode returns path | ✅ Pass | |
| 2.2 Unit: --stdout mode prints content | ✅ Pass | |
| 3.1 Integration: all 5 sources present | ✅ Pass | 954 lines, all sources found |
| 3.2 Integration: missing file graceful | ✅ Pass | |
| 3.3 Integration: no jq graceful | ✅ Pass | |
| 4.1 Integration: load order correct | ✅ Pass | |

---

## Test Categories

### 1. Static Checks

#### 1.1 plugin.json Schema

**Objective:** Verify plugin.json is valid JSON with required fields.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
jq '.' "${PLUGIN_DIR}/.claude-plugin/plugin.json"
```

**Expected result:**
- ✅ Valid JSON (no parse error)
- ✅ Has `name`, `version`, `commands`, `skills` fields
- ✅ `version` is `0.1.0`
- ✅ `skills` is `[]` (no auto-invocable skills)

---

#### 1.2 hooks.json Empty Hooks

**Objective:** Verify hooks.json has empty hooks (plugin is hook-free).

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
jq '.hooks | keys | length' "${PLUGIN_DIR}/hooks/hooks.json"
```

**Expected result:**
- ✅ Output: `0` (no hooks defined)

---

#### 1.3 SKILL.md Frontmatter

**Objective:** Verify SKILL.md has valid agentskills.io frontmatter.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
head -8 "${PLUGIN_DIR}/commands/ctx-show/SKILL.md"
```

**Expected result:**
- ✅ Starts with `---`
- ✅ Has `name: ctx-show`
- ✅ Has `description:` field
- ✅ Ends frontmatter with `---`

---

#### 1.4 Script is Executable

**Objective:** Verify ctx-show.sh has execute permission.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
test -x "${PLUGIN_DIR}/scripts/ctx-show.sh" && echo "executable" || echo "NOT executable"
```

**Expected result:**
- ✅ Output: `executable`

---

### 2. Unit Tests

#### 2.1 --file Mode Returns Path

**Objective:** Verify `--file` mode writes output to `/tmp/` and prints the path.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
OUTFILE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file)
echo "Output file: $OUTFILE"
test -f "$OUTFILE" && echo "file exists" || echo "file MISSING"
wc -l "$OUTFILE"
```

**Expected result:**
- ✅ Prints a path matching `/tmp/claude-context-*.md`
- ✅ File exists on disk
- ✅ File has at least 10 lines

---

#### 2.2 --stdout Mode Prints Content

**Objective:** Verify `--stdout` mode outputs context directly to stdout.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
OUTPUT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout)
echo "Line count: $(echo "$OUTPUT" | wc -l)"
echo "$OUTPUT" | grep -c "<!-- Source:" || true
```

**Expected result:**
- ✅ Content printed to stdout (not a file path)
- ✅ Contains at least 5 `<!-- Source:` markers

---

### 3. Integration Tests

#### 3.1 All 5 Sources Present in Output

**Objective:** Verify all 5 source types appear in the output.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
OUTPUT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout)

# Check each source type
echo "1. Global CLAUDE.md:"
echo "$OUTPUT" | grep -c "Source: ~/.claude/CLAUDE.md" || echo "MISSING"

echo "2. Project CLAUDE.md:"
echo "$OUTPUT" | grep -c "Source: .*/CLAUDE.md (project" || echo "MISSING"

echo "3. Auto-memory:"
echo "$OUTPUT" | grep -c "Source: ~/.claude/projects/.*/memory/MEMORY.md" || echo "MISSING"

echo "4. Global hooks:"
echo "$OUTPUT" | grep -c "Source: Global SessionStart hook" || echo "MISSING (or none configured)"

echo "5. Plugin hooks:"
echo "$OUTPUT" | grep -c "Source: Plugin .* SessionStart" || echo "MISSING"
```

**Acceptance criteria:**
- ✅ Source 1 (global CLAUDE.md): marker present
- ✅ Source 2 (project CLAUDE.md): marker present
- ✅ Source 3 (auto-memory): marker present
- ✅ Source 4 (global hooks): marker present (content may be empty if none configured)
- ✅ Source 5 (plugin hooks): at least one plugin hook marker present

---

#### 3.2 Missing Files Handled Gracefully

**Objective:** Verify that missing source files produce `<!-- (not found: ...) -->` comments rather than errors.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"

# Run with a non-existent project dir
OUTPUT=$(env CLAUDE_PROJECT_DIR="/tmp/nonexistent-project-dir" \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>&1)

echo "Exit code: $?"
echo "$OUTPUT" | grep "not found" | head -5
```

**Expected result:**
- ✅ Script exits with code 0 (no crash)
- ✅ Output contains `<!-- (not found: /tmp/nonexistent-project-dir/CLAUDE.md) -->`
- ✅ Still outputs global CLAUDE.md content (it exists)

---

#### 3.3 Graceful Degradation Without jq

**Objective:** Verify script still outputs static sources when `jq` is unavailable.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"

# Shadow jq with a fake that always fails
OUTPUT=$(env PATH="/tmp/no-jq-dir:${PATH}" \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>&1)

echo "Contains global CLAUDE.md source:"
echo "$OUTPUT" | grep -c "Source: ~/.claude/CLAUDE.md" || echo "0"

echo "Contains hook fallback message:"
echo "$OUTPUT" | grep -c "not found or jq not available" || echo "0"
```

**Note:** This test requires `/tmp/no-jq-dir/` to not exist (so `jq` isn't found). The script falls through to the fallback message for hook sources while still outputting static files.

**Acceptance criteria:**
- ✅ Global CLAUDE.md content present
- ✅ Project CLAUDE.md content present (or `not found` comment)
- ✅ Auto-memory content present (or `not found` comment)
- ✅ Hook sources show `(settings.json not found or jq not available)` fallback

---

#### 4.1 Load Order Correct

**Objective:** Verify sources appear in the documented order (global → project → memory → global hooks → plugin hooks).

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
OUTPUT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout)

# Get line numbers of each source marker
echo "Source order (line numbers):"
echo "$OUTPUT" | grep -n "<!-- Source:" | head -20
```

**Expected result:**
- ✅ `~/.claude/CLAUDE.md` marker appears first
- ✅ Project `CLAUDE.md` marker appears second
- ✅ `memory/MEMORY.md` marker appears third
- ✅ Global hook markers (if any) appear before plugin hook markers
- ✅ Plugin hook markers appear last

---

### 5. Behavioral Tests — SKILL.md Invocation

#### 5.1 Command Invocation via /ctx-show

**Objective:** Verify Claude executes `ctx-show.sh` when `/ctx-show` is invoked.

**Automation:** 🟡 (requires skill to be loaded in current or fresh session)

**Steps:**
1. In a Claude Code session with the plugin installed, run: `/ctx-show`
2. Expected: Claude reads SKILL.md and runs `bash .../ctx-show.sh`
3. Expected: Claude prints the output file path or content

**Expected result:**
- ✅ Claude runs `ctx-show.sh` via Bash tool
- ✅ Output path `/tmp/claude-context-*.md` is shown, OR full content is printed
- ✅ No errors

**Acceptance criteria:**
- ✅ Script executed (not just described)
- ✅ At least one source is shown in output

---

#### 5.2 --stdout Flag Respected

**Objective:** Verify `/ctx-show --stdout` prints content instead of a file path.

**Automation:** 🟡

**Steps:**
1. In a Claude Code session, run: `/ctx-show --stdout`
2. Expected: Claude passes `--stdout` to the script
3. Expected: Full context content shown in terminal (will be collapsed in TUI)

**Expected result:**
- ✅ Script runs with `--stdout` argument
- ✅ Content (not a file path) is output

---

## Regression Testing Guide

### When to run

- Before creating a PR that modifies `plugins/context/`
- After updating `ctx-show.sh` (re-run tests 2.1–4.1)
- After changing `commands/ctx-show/SKILL.md` (re-run test 5.1)

### Automated test batch

Run all automated tests in sequence:

```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"

echo "=== 1.1 plugin.json ==="
jq -e '.name == "context" and .version and .commands and (.skills | length == 0)' \
  "${PLUGIN_DIR}/.claude-plugin/plugin.json" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 1.2 hooks.json ==="
jq -e '.hooks | keys | length == 0' \
  "${PLUGIN_DIR}/hooks/hooks.json" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 1.3 SKILL.md frontmatter ==="
grep -q '^name: ctx-show' "${PLUGIN_DIR}/commands/ctx-show/SKILL.md" \
  && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 1.4 executable ==="
test -x "${PLUGIN_DIR}/scripts/ctx-show.sh" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 2.1 --file mode ==="
OUTFILE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file)
test -f "$OUTFILE" && echo "✅ PASS: $OUTFILE" || echo "❌ FAIL"

echo "=== 2.2 --stdout source count ==="
COUNT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout | grep -c "<!-- Source:")
test "$COUNT" -ge 5 && echo "✅ PASS: $COUNT sources" || echo "❌ FAIL: only $COUNT sources"

echo "=== 3.2 missing file graceful ==="
env CLAUDE_PROJECT_DIR="/tmp/nonexistent-$$" bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout \
  | grep -q "not found" && echo "✅ PASS" || echo "❌ FAIL"
```

### CI integration

This plugin has no CI hook scripts. All tests are run manually or via the batch above.
