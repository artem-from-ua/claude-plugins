# Context Plugin Acceptance Tests

## Purpose

The `context` plugin provides the `/ctx-show` command for assembling the full Claude Code session context in load order. These acceptance tests verify that the script correctly discovers, reads, and outputs all source types — including skills — and handles missing files gracefully.

The plugin also prints a summary table to stderr showing scope, type, source, status, lines, tokens, and context% for every source — including per-preset rows for playbook presets (v0.3.1+) and per-skill rows for SKILL.md listings.

## Test Execution Order

1. Static checks (automated)
2. Unit tests — individual sources (automated)
3. Integration tests — full output (automated)
4. Summary table tests (automated)
5. Playbook preset splitting tests (automated)
6. Behavioral tests — SKILL.md invocation (partially automated)
7. Threshold warning tests (automated)
8. API token counting tests (automated / partially automated)
9. Skill discovery tests (automated)

## Automation Status

- ✅ Fully automated: Tests 1–5, 7, 8.1–8.2, 9.1–9.5
- 🟡 Partially automated: Test 6 (Claude invocation requires a fresh session or `/clear`), 8.3 (requires valid API key)
- ⚠️ Manual only: None

## Test Results (last run: 2026-03-03)

| Test | Status | Notes |
|------|--------|-------|
| 1.1 Static: plugin.json valid | ✅ Pass | version 0.6.1 |
| 1.2 Static: hooks.json valid | ✅ Pass | |
| 1.3 Static: SKILL.md frontmatter | ✅ Pass | |
| 1.4 Static: script is executable | ✅ Pass | |
| 2.1 Unit: --file mode returns path | ✅ Pass | |
| 2.2 Unit: --stdout mode prints content | ✅ Pass | |
| 3.1 Integration: all 5 sources present | ✅ Pass | all sources found |
| 3.2 Integration: missing file graceful | ✅ Pass | |
| 3.3 Integration: no jq graceful | ✅ Pass | |
| 4.1 Load order correct | ✅ Pass | |
| 5.1 Table printed to stderr | ✅ Pass | |
| 5.2 Table has TOTAL row | ✅ Pass | |
| 5.3 Path shortening (~/. and ./) | ✅ Pass | |
| 5.4 Context% sums to 100% | ✅ Pass | |
| 5.5 Memory hash fix (leading dash) | ✅ Pass | |
| 6.1 Playbook preset splitting | ✅ Pass | requires playbook v0.3.1 in cache |
| 6.2 Legend shown when presets present | ✅ Pass | |
| 7.3 Threshold warning fires when exceeded | ✅ Pass | CTX_WARN_THRESHOLD=1 |
| 7.4 No warning when under threshold | ✅ Pass | CTX_WARN_THRESHOLD=999999 |
| 8.1 Heuristic mode without API key | ✅ Pass | ~Tokens header, heuristic footer |
| 8.2 API fallback with invalid key | ✅ Pass | ~Tokens header, API error footer |
| 8.3 Exact counting with valid key | 🟡 Skip | requires valid ANTHROPIC_API_KEY |
| 9.1 Skill: user skills discovered | ⬜ | |
| 9.2 Skill: plugin skills discovered | ⬜ | |
| 9.3 Skill: deduplication works | ⬜ | |
| 9.4 Skill: malformed SKILL.md skipped | ⬜ | |
| 9.5 Skill: footer legend shown | ⬜ | |

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
- ✅ `version` is `0.6.1`
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
head -9 "${PLUGIN_DIR}/commands/ctx-show/SKILL.md"
```

**Expected result:**
- ✅ Starts with `---`
- ✅ Has `name: ctx-show`
- ✅ Has `description:` field mentioning summary table
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
OUTFILE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null)
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
OUTPUT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>/dev/null)
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
OUTPUT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>/dev/null)

echo "1. Global CLAUDE.md:"
echo "$OUTPUT" | grep -c "Source: ~/.claude/CLAUDE.md" || echo "MISSING"

echo "2. Project CLAUDE.md:"
echo "$OUTPUT" | grep -c "Source: .*/CLAUDE.md" || echo "MISSING"

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

OUTPUT=$(env PATH="/tmp/no-jq-dir:${PATH}" \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>&1)

echo "Contains global CLAUDE.md source:"
echo "$OUTPUT" | grep -c "Source: ~/.claude/CLAUDE.md" || echo "0"

echo "Contains hook fallback message:"
echo "$OUTPUT" | grep -c "not found or jq not available" || echo "0"
```

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
OUTPUT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>/dev/null)

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

### 5. Summary Table Tests

#### 5.1 Table Printed to stderr

**Objective:** Verify summary table appears on stderr, not stdout.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"

# Table should NOT appear on stdout
STDOUT_ONLY=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>/dev/null)
echo "Table on stdout (should be 0):"
echo "$STDOUT_ONLY" | grep -c "Context%" || echo "0"

# Table SHOULD appear on stderr
TABLE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>&1 >/dev/null)
echo "Table on stderr (should be 1):"
echo "$TABLE" | grep -c "Context%" || echo "0"
```

**Expected result:**
- ✅ `Context%` header NOT in stdout output
- ✅ `Context%` header present in stderr output

---

#### 5.2 Table Has TOTAL Row and Correct Columns

**Objective:** Verify TOTAL row appears and columns are correct.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>&1 >/dev/null)

echo "Has TOTAL row:"
echo "$TABLE" | grep -c "TOTAL" || echo "0"

echo "Has Scope column:"
echo "$TABLE" | grep -c "Scope" || echo "0"

echo "Has Status column:"
echo "$TABLE" | grep -c "Status" || echo "0"

echo "Has ~Tokens column:"
echo "$TABLE" | grep -c "~Tokens" || echo "0"
```

**Expected result:**
- ✅ `TOTAL` row present
- ✅ Column headers: `Scope`, `Type`, `Source/ID`, `Status`, `Lines`, `~Tokens`, `Context%`

---

#### 5.3 Path Shortening

**Objective:** Verify paths use `~/` for HOME and `./` for project dir.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>&1 >/dev/null)

echo "Uses ~/ for home paths (should be 1+):"
echo "$TABLE" | grep -c '~/' || echo "0"

echo "Uses ./ for project paths (should be 1+):"
echo "$TABLE" | grep -c '\.\/' || echo "0"

echo "No raw /Users/ in table (should be 0):"
echo "$TABLE" | grep -c '/Users/' || echo "0"
```

**Expected result:**
- ✅ At least one `~/` path in table
- ✅ At least one `./` path when project CLAUDE.md exists
- ✅ No raw `/Users/` in table output

---

#### 5.4 Context% Sums to 100%

**Objective:** Verify TOTAL row shows 100% and individual percentages are non-negative.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>&1 >/dev/null)

echo "TOTAL row shows 100%:"
echo "$TABLE" | grep "TOTAL" | grep -c "100%" || echo "0"
```

**Expected result:**
- ✅ TOTAL row contains `100%`

---

#### 5.5 Memory Path Hash (Leading Dash)

**Objective:** Verify memory path uses `-Users-...` hash (with leading dash, matching Claude Code's encoding).

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>&1 >/dev/null)

echo "Memory row present (✅ or ⚠️):"
echo "$TABLE" | grep "Memory" | head -1

echo "Memory hash starts with - (leading dash preserved):"
echo "$TABLE" | grep "Memory" | grep -c '\-Users' || echo "0"
```

**Expected result:**
- ✅ Memory row visible in table
- ✅ Source path contains `~/.claude/projects/-Users-...` (with leading dash)

---

### 6. Playbook Preset Splitting Tests

#### 6.1 Individual Preset Rows

**Objective:** Verify playbook presets appear as individual `📚 Playbook Preset` rows when playbook v0.3.1+ is in cache.

**Automation:** ✅ (uses local plugin directory to simulate v0.3.1 cache)

**Steps:**
```bash
PLAYBOOK_PLUGIN="/Users/artem/devel/claude-plugins/plugins/playbook"
CONTEXT_PLUGIN="/Users/artem/devel/claude-plugins/plugins/context"

# Setup fake cache with v0.3.1 playbook
FAKE_CACHE="/tmp/fake-cache-ctx-test-$$"
mkdir -p "$FAKE_CACHE/tribe-coding/playbook/0.3.1"
cp -r "$PLAYBOOK_PLUGIN/." "$FAKE_CACHE/tribe-coding/playbook/0.3.1/"

# Setup fake HOME with settings.json enabling only playbook
FAKE_HOME="/tmp/fake-home-ctx-test-$$"
mkdir -p "$FAKE_HOME/.claude/plugins"
rsync -a "$FAKE_CACHE/" "$FAKE_HOME/.claude/plugins/cache/"
jq '.enabledPlugins = {"playbook@tribe-coding": true}' \
  "$HOME/.claude/settings.json" > "$FAKE_HOME/.claude/settings.json"

# Setup fake project with playbook config
FAKE_PROJ="/tmp/fake-proj-ctx-test-$$"
mkdir -p "$FAKE_PROJ/.claude-plugin"
printf '{"presets":["documentation-principles","github-workflow"]}' \
  > "$FAKE_PROJ/.claude-plugin/playbook.json"

TABLE=$(env HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$FAKE_PROJ" \
  bash "${CONTEXT_PLUGIN}/scripts/ctx-show.sh" --file 2>&1 >/dev/null)

echo "Playbook Preset rows (should be 2+):"
echo "$TABLE" | grep -c "Playbook Preset" || echo "0"

echo "documentation-principles row:"
echo "$TABLE" | grep "documentation-principles" | head -1

echo "github-workflow row:"
echo "$TABLE" | grep "github-workflow" | head -1

rm -rf "$FAKE_CACHE" "$FAKE_HOME" "$FAKE_PROJ"
```

**Expected result:**
- ✅ At least 2 `Playbook Preset` rows (one per enabled preset)
- ✅ `documentation-principles` and `github-workflow` rows visible
- ✅ Each preset row shows `✅` status and non-zero lines/tokens

---

#### 6.2 Legend Shown When Presets Present

**Objective:** Verify the Legend line appears when playbook presets are in the table.

**Automation:** ✅

**Steps:** (same setup as 6.1, reuse FAKE_* vars or re-create)

```bash
PLAYBOOK_PLUGIN="/Users/artem/devel/claude-plugins/plugins/playbook"
CONTEXT_PLUGIN="/Users/artem/devel/claude-plugins/plugins/context"

FAKE_CACHE="/tmp/fake-cache-legend-$$"
mkdir -p "$FAKE_CACHE/tribe-coding/playbook/0.3.1"
cp -r "$PLAYBOOK_PLUGIN/." "$FAKE_CACHE/tribe-coding/playbook/0.3.1/"

FAKE_HOME="/tmp/fake-home-legend-$$"
mkdir -p "$FAKE_HOME/.claude/plugins"
rsync -a "$FAKE_CACHE/" "$FAKE_HOME/.claude/plugins/cache/"
jq '.enabledPlugins = {"playbook@tribe-coding": true}' \
  "$HOME/.claude/settings.json" > "$FAKE_HOME/.claude/settings.json"

FAKE_PROJ="/tmp/fake-proj-legend-$$"
mkdir -p "$FAKE_PROJ/.claude-plugin"
printf '{"presets":["documentation-principles"]}' \
  > "$FAKE_PROJ/.claude-plugin/playbook.json"

TABLE=$(env HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$FAKE_PROJ" \
  bash "${CONTEXT_PLUGIN}/scripts/ctx-show.sh" --file 2>&1 >/dev/null)

echo "Legend line present (should be 1):"
echo "$TABLE" | grep -c "Legend:" || echo "0"

echo "Legend mentions playbook:"
echo "$TABLE" | grep "Legend:" | head -1

rm -rf "$FAKE_CACHE" "$FAKE_HOME" "$FAKE_PROJ"
```

**Expected result:**
- ✅ `Legend:` line present at bottom of table
- ✅ Legend mentions `playbook@tribe-coding`

---

### 7. Behavioral Tests — SKILL.md Invocation

#### 7.1 Command Invocation via /ctx-show

**Objective:** Verify Claude executes `ctx-show.sh` when `/ctx-show` is invoked.

**Automation:** 🟡 (requires skill to be loaded in current or fresh session)

**Steps:**
1. In a Claude Code session with the plugin installed, run: `/ctx-show`
2. Expected: Claude reads SKILL.md and runs `bash .../ctx-show.sh`
3. Expected: Claude prints the output file path and shows summary table

**Expected result:**
- ✅ Claude runs `ctx-show.sh` via Bash tool
- ✅ Output path `/tmp/claude-context-*.md` is shown
- ✅ Summary table visible in terminal output
- ✅ No errors

---

#### 7.2 --stdout Flag Respected

**Objective:** Verify `/ctx-show --stdout` prints content instead of a file path.

**Automation:** 🟡

**Steps:**
1. In a Claude Code session, run: `/ctx-show --stdout`
2. Expected: Claude passes `--stdout` to the script
3. Expected: Full context content shown in terminal (may be collapsed in TUI)

**Expected result:**
- ✅ Script runs with `--stdout` argument
- ✅ Content (not a file path) is output

---

### 7. Threshold Warning Tests

#### 7.3 Warning Fires When Exceeded

**Objective:** Verify ⚠️ warning appears when total tokens exceed `CTX_WARN_THRESHOLD`.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE_FILE=$(env CTX_WARN_THRESHOLD=1 \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "Warning present (should be 1):"
grep -c "exceeds threshold" "$TABLE_FILE" || echo "0"
```

**Expected result:**
- ✅ Output contains `⚠️  Context load` warning line
- ✅ Warning mentions threshold value and context window percentage

---

#### 7.4 No Warning When Under Threshold

**Objective:** Verify no warning when total tokens are below `CTX_WARN_THRESHOLD`.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE_FILE=$(env CTX_WARN_THRESHOLD=999999 \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "Warning absent (should be 0):"
grep -c "exceeds threshold" "$TABLE_FILE" || echo "0"
```

**Expected result:**
- ✅ No `⚠️` warning line in output
- ✅ Table still has TOTAL row

---

### 8. API Token Counting Tests

#### 8.1 Heuristic Mode Without API Key

**Objective:** Verify heuristic mode when `ANTHROPIC_API_KEY` is not set.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE_FILE=$(env -u ANTHROPIC_API_KEY \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "Column header is ~Tokens (should be 1):"
grep -c '~Tokens' "$TABLE_FILE" || echo "0"

echo "Footer says estimated (should be 1):"
grep -c 'estimated (chars/3.6; set ANTHROPIC_API_KEY for exact)' "$TABLE_FILE" || echo "0"
```

**Expected result:**
- ✅ Column header is `~Tokens`
- ✅ Footer: `Token counts: estimated (chars/3.6; set ANTHROPIC_API_KEY for exact)`

---

#### 8.2 API Fallback With Invalid Key

**Objective:** Verify graceful fallback when API key is invalid.

**Automation:** ✅

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
TABLE_FILE=$(env ANTHROPIC_API_KEY="sk-ant-invalid-key" \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "Column header is ~Tokens (should be 1):"
grep -c '~Tokens' "$TABLE_FILE" || echo "0"

echo "Footer says API error (should be 1):"
grep -c 'API error, fell back to chars/3.6' "$TABLE_FILE" || echo "0"
```

**Expected result:**
- ✅ Column header is `~Tokens` (fallback)
- ✅ Footer: `Token counts: estimated (API error, fell back to chars/3.6)`

---

#### 8.3 Exact Counting With Valid API Key

**Objective:** Verify exact token counting when `ANTHROPIC_API_KEY` is valid.

**Automation:** 🟡 (requires valid API key)

**Steps:**
```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"
# Requires ANTHROPIC_API_KEY to be set to a valid key
TABLE_FILE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "Column header is Tokens (not ~Tokens):"
grep -c '| Tokens |' "$TABLE_FILE" || echo "0"

echo "Footer says exact (should be 1):"
grep -c 'exact (Anthropic count_tokens API)' "$TABLE_FILE" || echo "0"
```

**Expected result:**
- ✅ Column header is `Tokens` (not `~Tokens`)
- ✅ Footer: `Token counts: exact (Anthropic count_tokens API)`
- ✅ Token values differ from chars/3.6 heuristic (typically lower)

---

### 9. Skill Discovery Tests

#### 9.1 User Skills Discovered

**Objective:** Verify user skills from `~/.claude/commands/` and `~/.claude/skills/` appear as User/Skill rows.

**Automation:** ✅

**Steps:**
```bash
CONTEXT_PLUGIN="/Users/artem/devel/claude-plugins/plugins/context"

FAKE_HOME="/tmp/fake-home-skills-$$"
mkdir -p "$FAKE_HOME/.claude/skills/test-skill"
cat > "$FAKE_HOME/.claude/skills/test-skill/SKILL.md" <<'SKILLEOF'
---
name: test-skill
description: A test skill for acceptance testing
---
# Test Skill
SKILLEOF
mkdir -p "$FAKE_HOME/.claude/plugins"
echo '{}' > "$FAKE_HOME/.claude/settings.json"

TABLE_FILE=$(HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="/tmp" \
  bash "${CONTEXT_PLUGIN}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "User skill row present (should be 1):"
grep -c 'User.*Skill.*test-skill' "$TABLE_FILE" || echo "0"

rm -rf "$FAKE_HOME"
```

**Expected result:**
- ✅ `test-skill` appears as a User/Skill row

---

#### 9.2 Plugin Skills Discovered

**Objective:** Verify plugin skills from enabled plugins appear as Project/Skill rows with `plugin:name` format.

**Automation:** ✅

**Steps:**
```bash
CONTEXT_PLUGIN="/Users/artem/devel/claude-plugins/plugins/context"
PLANTUML_PLUGIN="/Users/artem/devel/claude-plugins/plugins/plantuml"

FAKE_HOME="/tmp/fake-home-plugskill-$$"
FAKE_CACHE="$FAKE_HOME/.claude/plugins/cache/tribe-coding/plantuml/1.0.0"
mkdir -p "$FAKE_CACHE"
cp -r "$PLANTUML_PLUGIN/." "$FAKE_CACHE/"
jq '.enabledPlugins = {"plantuml@tribe-coding": true}' \
  "$HOME/.claude/settings.json" > "$FAKE_HOME/.claude/settings.json"

TABLE_FILE=$(HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="/tmp" \
  bash "${CONTEXT_PLUGIN}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "Plugin skill rows (should be 3+):"
grep -c 'plantuml:' "$TABLE_FILE" || echo "0"

echo "plantuml-diagram-guide present:"
grep -c 'plantuml:plantuml-diagram-guide' "$TABLE_FILE" || echo "0"

rm -rf "$FAKE_HOME"
```

**Expected result:**
- ✅ Plugin skills appear with `plantuml:skill-name` format
- ✅ `plantuml:plantuml-diagram-guide` is present

---

#### 9.3 Deduplication Works

**Objective:** Verify that the same SKILL.md is not counted twice when commands/ and skills/ dirs overlap.

**Automation:** ✅

**Steps:**
```bash
CONTEXT_PLUGIN="/Users/artem/devel/claude-plugins/plugins/context"

FAKE_HOME="/tmp/fake-home-dedup-$$"
mkdir -p "$FAKE_HOME/.claude/plugins/cache/tribe-coding/testplugin/1.0.0/.claude-plugin"
mkdir -p "$FAKE_HOME/.claude/plugins/cache/tribe-coding/testplugin/1.0.0/commands/foo"
mkdir -p "$FAKE_HOME/.claude/plugins/cache/tribe-coding/testplugin/1.0.0/skills"

cat > "$FAKE_HOME/.claude/plugins/cache/tribe-coding/testplugin/1.0.0/.claude-plugin/plugin.json" <<'EOF'
{"name":"testplugin","version":"1.0.0","commands":["./commands/"],"skills":["./commands/"]}
EOF

cat > "$FAKE_HOME/.claude/plugins/cache/tribe-coding/testplugin/1.0.0/commands/foo/SKILL.md" <<'EOF'
---
name: foo
description: Duplicate test skill
---
EOF

mkdir -p "$FAKE_HOME/.claude/plugins/cache/tribe-coding/testplugin/1.0.0/hooks"
echo '{"hooks":{}}' > "$FAKE_HOME/.claude/plugins/cache/tribe-coding/testplugin/1.0.0/hooks/hooks.json"

jq '.enabledPlugins = {"testplugin@tribe-coding": true}' \
  "$HOME/.claude/settings.json" > "$FAKE_HOME/.claude/settings.json"

TABLE_FILE=$(HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="/tmp" \
  bash "${CONTEXT_PLUGIN}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "foo skill count (should be 1, not 2):"
grep -c 'testplugin:foo' "$TABLE_FILE" || echo "0"

rm -rf "$FAKE_HOME"
```

**Expected result:**
- ✅ `testplugin:foo` appears exactly once (not duplicated)

---

#### 9.4 Malformed SKILL.md Skipped

**Objective:** Verify that SKILL.md without a `name:` field is silently skipped.

**Automation:** ✅

**Steps:**
```bash
CONTEXT_PLUGIN="/Users/artem/devel/claude-plugins/plugins/context"

FAKE_HOME="/tmp/fake-home-malform-$$"
mkdir -p "$FAKE_HOME/.claude/skills/bad-skill"
cat > "$FAKE_HOME/.claude/skills/bad-skill/SKILL.md" <<'EOF'
---
description: No name field here
---
# Bad Skill
EOF
mkdir -p "$FAKE_HOME/.claude/plugins"
echo '{}' > "$FAKE_HOME/.claude/settings.json"

TABLE_FILE=$(HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="/tmp" \
  bash "${CONTEXT_PLUGIN}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "bad-skill NOT in table (should be 0):"
grep -c 'bad-skill' "$TABLE_FILE" || echo "0"

rm -rf "$FAKE_HOME"
```

**Expected result:**
- ✅ `bad-skill` does NOT appear in the table

---

#### 9.5 Footer Legend Shown When Skills Present

**Objective:** Verify the Skills footer legend appears when skill rows are in the table.

**Automation:** ✅

**Steps:**
```bash
CONTEXT_PLUGIN="/Users/artem/devel/claude-plugins/plugins/context"

FAKE_HOME="/tmp/fake-home-legend-skill-$$"
mkdir -p "$FAKE_HOME/.claude/skills/test-legend"
cat > "$FAKE_HOME/.claude/skills/test-legend/SKILL.md" <<'EOF'
---
name: test-legend
description: Legend test skill
---
EOF
mkdir -p "$FAKE_HOME/.claude/plugins"
echo '{}' > "$FAKE_HOME/.claude/settings.json"

TABLE_FILE=$(HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="/tmp" \
  bash "${CONTEXT_PLUGIN}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)

echo "Skills footer legend (should be 1):"
grep -c 'Skills: names + descriptions loaded at session start' "$TABLE_FILE" || echo "0"

rm -rf "$FAKE_HOME"
```

**Expected result:**
- ✅ Footer contains `Skills: names + descriptions loaded at session start (full SKILL.md on-demand)`

---

## Regression Testing Guide

### When to run

- Before creating a PR that modifies `plugins/context/`
- After updating `ctx-show.sh` (re-run tests 2.1–6.2)
- After changing `commands/ctx-show/SKILL.md` (re-run test 7.1)

### Automated test batch

Run all automated tests in sequence:

```bash
PLUGIN_DIR="/Users/artem/devel/claude-plugins/plugins/context"

echo "=== 1.1 plugin.json ==="
jq -e '.name == "context" and .version == "0.6.1" and .commands and (.skills | length == 0)' \
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
OUTFILE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null)
test -f "$OUTFILE" && echo "✅ PASS: $OUTFILE" || echo "❌ FAIL"

echo "=== 2.2 --stdout source count ==="
COUNT=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>/dev/null | grep -c "<!-- Source:")
test "$COUNT" -ge 5 && echo "✅ PASS: $COUNT sources" || echo "❌ FAIL: only $COUNT sources"

echo "=== 3.2 missing file graceful ==="
env CLAUDE_PROJECT_DIR="/tmp/nonexistent-$$" bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --stdout 2>/dev/null \
  | grep -q "not found" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 5.1 table on stderr ==="
TABLE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>&1 >/dev/null)
echo "$TABLE" | grep -q "Context%" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 5.2 TOTAL row ==="
echo "$TABLE" | grep -q "TOTAL" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 5.3 path shortening ==="
echo "$TABLE" | grep -q '~/' && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 5.4 100% in TOTAL ==="
echo "$TABLE" | grep "TOTAL" | grep -q "100%" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 5.5 memory hash leading dash ==="
echo "$TABLE" | grep "Memory" | grep -q '\-Users' && echo "✅ PASS" || echo "⚠️  Memory not found in this env"

echo "=== 7.3 threshold warning fires ==="
TABLE_WARN=$(env CTX_WARN_THRESHOLD=1 \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)
grep -q "exceeds threshold" "$TABLE_WARN" && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 7.4 no warning under threshold ==="
TABLE_NOWARN=$(env CTX_WARN_THRESHOLD=999999 \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)
grep -q "exceeds threshold" "$TABLE_NOWARN" && echo "❌ FAIL" || echo "✅ PASS"

echo "=== 8.1 heuristic mode without API key ==="
TABLE_NOKEY=$(env -u ANTHROPIC_API_KEY \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)
grep -q '~Tokens' "$TABLE_NOKEY" && grep -q 'set ANTHROPIC_API_KEY for exact' "$TABLE_NOKEY" \
  && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 8.2 API fallback with invalid key ==="
TABLE_BADKEY=$(env ANTHROPIC_API_KEY="sk-ant-invalid" \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)
grep -q '~Tokens' "$TABLE_BADKEY" && grep -q 'API error, fell back to chars/3.6' "$TABLE_BADKEY" \
  && echo "✅ PASS" || echo "❌ FAIL"

echo "=== 9.1 user skills discovered ==="
FAKE_HOME_91="/tmp/fake-home-skill91-$$"
mkdir -p "$FAKE_HOME_91/.claude/skills/test-skill91"
printf -- '---\nname: test-skill91\ndescription: test\n---\n' \
  > "$FAKE_HOME_91/.claude/skills/test-skill91/SKILL.md"
echo '{}' > "$FAKE_HOME_91/.claude/settings.json"
TABLE_91=$(HOME="$FAKE_HOME_91" CLAUDE_PROJECT_DIR="/tmp" \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)
grep -q 'User.*Skill.*test-skill91' "$TABLE_91" && echo "✅ PASS" || echo "❌ FAIL"
rm -rf "$FAKE_HOME_91"

echo "=== 9.4 malformed SKILL.md skipped ==="
FAKE_HOME_94="/tmp/fake-home-skill94-$$"
mkdir -p "$FAKE_HOME_94/.claude/skills/bad-skill"
printf -- '---\ndescription: no name\n---\n' \
  > "$FAKE_HOME_94/.claude/skills/bad-skill/SKILL.md"
echo '{}' > "$FAKE_HOME_94/.claude/settings.json"
TABLE_94=$(HOME="$FAKE_HOME_94" CLAUDE_PROJECT_DIR="/tmp" \
  bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)
grep -q 'bad-skill' "$TABLE_94" && echo "❌ FAIL" || echo "✅ PASS"
rm -rf "$FAKE_HOME_94"

echo "=== 9.5 skills footer legend ==="
TABLE=$(bash "${PLUGIN_DIR}/scripts/ctx-show.sh" --file 2>/dev/null | tail -1)
grep -q 'Skills: names + descriptions' "$TABLE" && echo "✅ PASS" || echo "❌ FAIL"
```

### CI integration

This plugin has no CI hook scripts. All tests are run manually or via the batch above.
