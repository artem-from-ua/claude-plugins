# Semver Plugin Acceptance Tests

## Purpose

The semver plugin enforces semantic versioning before commits, pushes, and PR creation/merge. These tests verify that the PreToolUse hook correctly detects missing version bumps, passes through valid scenarios, and that SessionStart rules inject correctly.

## Test Execution Order

1. Static checks (automated)
2. Script unit tests — inject-rules.sh (automated)
3. Script unit tests — validate-bump.sh (automated)
4. Integration tests — config loading (automated)
5. Behavioral tests — SessionStart rules (manual, fresh session)
6. End-to-end — full workflow (manual)

## Automation Status

- ✅ Fully automated: Tests 1–4
- ⚠️ Manual only: Tests 5–6 (require fresh session or real git operations)

---

## Test Categories

### 1. Static Checks

**Objective:** Verify file structure, YAML frontmatter, and JSON schema validity.

**Automation:** ✅

```bash
PLUGIN="/Users/artem/devel/claude-plugins/plugins/semver"

# 1.1 Check all required files exist
for f in \
  ".claude-plugin/plugin.json" \
  "hooks/hooks.json" \
  "scripts/inject-rules.sh" \
  "scripts/validate-bump.sh" \
  "commands/semver-setup/SKILL.md" \
  "skills/semver-guide/SKILL.md" \
  "templates/semver.json" \
  "docs/ACCEPTANCE_TESTS.md"; do
  test -f "$PLUGIN/$f" && echo "✅ $f" || echo "❌ MISSING: $f"
done

# 1.2 Validate JSON files
for f in ".claude-plugin/plugin.json" "hooks/hooks.json" "templates/semver.json"; do
  jq empty "$PLUGIN/$f" 2>/dev/null && echo "✅ JSON valid: $f" || echo "❌ Invalid JSON: $f"
done

# 1.3 Validate YAML frontmatter in SKILL.md files
for f in "commands/semver-setup/SKILL.md" "skills/semver-guide/SKILL.md"; do
  PYTHONPATH="" python3 -c "
import re
content = open('$PLUGIN/$f').read()
m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
print('✅ frontmatter OK' if m else '❌ no frontmatter')
"
done

# 1.4 Check scripts are executable
for s in inject-rules.sh validate-bump.sh; do
  test -x "$PLUGIN/scripts/$s" && echo "✅ executable: $s" || echo "❌ not executable: $s"
done
```

**Acceptance criteria:**
- ✅ All required files exist
- ✅ All JSON files parse without error
- ✅ Both SKILL.md files have valid YAML frontmatter
- ✅ Both scripts are executable

---

### 2. inject-rules.sh Unit Tests

**Objective:** Verify SessionStart output for both trigger strategies.

**Automation:** ✅

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/semver/scripts/inject-rules.sh"

# 2.1 No config — defaults to "auto" strategy
output=$(env CLAUDE_PLUGIN_ROOT=/Users/artem/devel/claude-plugins/plugins/semver \
  CLAUDE_PROJECT_DIR=/tmp bash "$SCRIPT")
echo "$output" | grep -q "auto" && echo "✅ auto strategy in output" || echo "❌ strategy missing"
echo "$output" | grep -q "MANDATORY" && echo "✅ MANDATORY keyword present" || echo "❌ MANDATORY missing"
echo "$output" | grep -q "semver:setup" && echo "✅ setup pointer present" || echo "❌ setup pointer missing"

# 2.2 Config with "always" strategy (new path .claude-plugin/)
mkdir -p /tmp/semver-test/.claude-plugin
printf '%s' '{"triggerStrategy":"always"}' > /tmp/semver-test/.claude-plugin/semver.json
output=$(env CLAUDE_PLUGIN_ROOT=/Users/artem/devel/claude-plugins/plugins/semver \
  CLAUDE_PROJECT_DIR=/tmp/semver-test bash "$SCRIPT")
echo "$output" | grep -q "always" && echo "✅ always strategy in output" || echo "❌ always strategy missing"
echo "$output" | grep -q "no exceptions" && echo "✅ strict rule present" || echo "❌ strict rule missing"
rm -rf /tmp/semver-test
```

**Acceptance criteria:**
- ✅ Outputs ~150 tokens with MANDATORY keyword
- ✅ Strategy-specific rule line changes based on config
- ✅ Both setup and guide pointers present

---

### 3. validate-bump.sh Unit Tests

**Automation:** ✅

These tests simulate PreToolUse JSON input and check the output.

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/semver/scripts/validate-bump.sh"

# 3.1 Passthrough: non-git command
result=$(printf '%s' '{"tool_input":{"command":"npm install"}}' | \
  env CLAUDE_PLUGIN_ROOT=/Users/artem/devel/claude-plugins/plugins/semver bash "$SCRIPT"; echo "exit:$?")
echo "$result" | grep -q "exit:0" && echo "✅ non-git passes through" || echo "❌ unexpected block"

# 3.2 Passthrough: irrelevant git subcommand
result=$(printf '%s' '{"tool_input":{"command":"git status"}}' | \
  env CLAUDE_PLUGIN_ROOT=/Users/artem/devel/claude-plugins/plugins/semver bash "$SCRIPT"; echo "exit:$?")
echo "$result" | grep -q "exit:0" && ! echo "$result" | grep -q "permissionDecision" && \
  echo "✅ git status passes through" || echo "❌ unexpected output"

# 3.3 Passthrough: enforcement "allow"
mkdir -p /tmp/semver-test2/.claude-plugin
printf '%s' '{"versionFiles":[{"path":"package.json","field":"version","format":"json"}],"enforcement":{"missingBump":"allow"}}' \
  > /tmp/semver-test2/.claude-plugin/semver.json
result=$(printf '%s' '{"tool_input":{"command":"git commit -m \"test\""}}' | \
  env CLAUDE_PLUGIN_ROOT=/Users/artem/devel/claude-plugins/plugins/semver \
      CLAUDE_PROJECT_DIR=/tmp/semver-test2 bash "$SCRIPT"; echo "exit:$?")
echo "$result" | grep -q "exit:0" && ! echo "$result" | grep -q "permissionDecision" && \
  echo "✅ enforcement=allow passes through" || echo "❌ unexpected block"
rm -rf /tmp/semver-test2
```

**Acceptance criteria:**
- ✅ Non-git commands pass through silently (exit 0, no output)
- ✅ Irrelevant git commands (status, fetch, log) pass through
- ✅ `enforcement: allow` suppresses all checks
- ✅ `git commit` without staged version file → `ask` response with message

---

### 4. Config Loading Tests

**Objective:** Verify project config takes priority over global config.

**Automation:** ✅

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/semver/scripts/inject-rules.sh"

# 4.1 Global config used when no project config
mkdir -p /tmp/semver-global-test
printf '%s' '{"triggerStrategy":"always"}' > /tmp/semver-global-test/semver.json

output=$(env CLAUDE_PLUGIN_ROOT=/Users/artem/devel/claude-plugins/plugins/semver \
  CLAUDE_PROJECT_DIR=/tmp/semver-no-project HOME=/tmp/semver-global-test bash "$SCRIPT")
echo "$output" | grep -q "always" && echo "✅ global config used" || echo "❌ global config not picked up"

# 4.2 Project config overrides global (new path .claude-plugin/)
mkdir -p /tmp/semver-project-test/.claude-plugin
printf '%s' '{"triggerStrategy":"auto"}' > /tmp/semver-project-test/.claude-plugin/semver.json

output=$(env CLAUDE_PLUGIN_ROOT=/Users/artem/devel/claude-plugins/plugins/semver \
  CLAUDE_PROJECT_DIR=/tmp/semver-project-test HOME=/tmp/semver-global-test bash "$SCRIPT")
echo "$output" | grep -q "auto" && echo "✅ project config overrides global" || echo "❌ project config not used"

rm -rf /tmp/semver-global-test /tmp/semver-project-test
```

---

### 5. SessionStart Rules — Manual Test

**Automation:** ⚠️ Manual only (requires fresh session)

#### Manual Test Procedure

**Step 1:** Start fresh Claude Code session in any project:
```bash
mkdir /tmp/semver-session-test && cd /tmp/semver-session-test && git init && claude
```

**Step 3:** Ask Claude: "What are the SemVer rules I should follow in this session?"

**Expected:** Claude mentions MANDATORY SemVer rules, MAJOR/MINOR/PATCH, and trigger strategy.

**Step 4:** Ask Claude: "How do I set up versioning for this project?"

**Expected:** Claude mentions `/semver:setup` command.

**Known failure modes:**

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| No SemVer rules mentioned | Plugin not loaded | Restart Claude Code |
| Rules appear but strategy is wrong | Old config cached | Restart Claude Code |
| SessionStart hook error | Script not executable | `chmod +x plugins/semver/scripts/*.sh` |

---

### 6. End-to-End Workflow — Manual Test

**Automation:** ⚠️ Manual only (requires real git repo with version file)

#### Procedure

**Setup:**
```bash
mkdir /tmp/e2e-semver && cd /tmp/e2e-semver && git init
printf '%s' '{"name":"test","version":"1.0.0"}' > package.json
git add . && git commit -m "initial"
git checkout -b feature/test-semver
echo "// new feature" > src.js
git add src.js
```

**Run `/semver:setup`** in Claude → configure: `package.json`, strategy `auto`, enforcement `ask`, base branch `main`.

**Attempt commit without bump:**
Ask Claude: "commit with message 'feat: add new feature'"

**Expected:** Claude's PreToolUse hook fires, warns about missing version bump. Claude asks user whether to bump first.

**Attempt commit with bump:**
Ask Claude: "bump version to 1.1.0 and commit"

**Expected:** Claude updates `package.json` version, stages it, and commits. No hook warning.

---

## Regression Testing Guide

Run automated tests (categories 1–4) before:
- Any release to main
- After modifying `inject-rules.sh` or `validate-bump.sh`
- After changing config schema

Run the full suite including manual tests (5–6) when:
- Upgrading to a new Claude Code version
- After significant structural changes to the plugin

To run all automated tests in one session:
```
Run all acceptance tests for the semver plugin at /Users/artem/devel/claude-plugins/plugins/semver — categories 1 through 4 from docs/ACCEPTANCE_TESTS.md
```
