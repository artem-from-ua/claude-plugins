# git-branch-naming Acceptance Tests

## Purpose

The `git-branch-naming` plugin enforces git branch naming conventions via PreToolUse hooks and injected SessionStart rules. These tests verify:
- Branch name validation (format, prefix, kebab-case, ticket, length)
- Config loading from `.claude/git-branch-naming.json`
- Protected branch warnings before push
- Content mismatch detection at `git commit` and `git push`
- SessionStart rules injection
- `/git-branch-naming:setup` interactive flow

## Test Execution Order

1. Static checks (automated)
2. Unit tests — validate-branch.sh (automated)
3. Unit tests — check-content-mismatch.sh (automated)
4. Config loading tests (automated)
5. PreToolUse hook I/O tests (automated)
6. Pre-push hook template tests (automated)
7. Behavioral tests — SessionStart rules (manual, fresh session required)
8. Behavioral tests — `/git-branch-naming:setup` command (manual)
9. Cross-platform tests (manual)
10. Team config sharing (manual)

## Automation Status

- ✅ Fully automated: Tests 1–6
- ⚠️ Manual only: Tests 7–10 (require fresh session or human interaction)

---

## 1. Static Checks

**Objective:** Verify plugin manifest, hooks, and skill frontmatter are valid.

**Automation:** ✅

**Steps:**
```bash
# plugin.json schema
cat plugins/git-branch-naming/.claude-plugin/plugin.json | jq .

# hooks.json structure
cat plugins/git-branch-naming/hooks/hooks.json | jq .

# SKILL.md frontmatter (check for name + description)
head -10 plugins/git-branch-naming/skills/branch-naming-guide/SKILL.md
head -10 plugins/git-branch-naming/commands/git-branch-naming-setup/SKILL.md
```

**Acceptance criteria:**
- ✅ `plugin.json` has `name`, `version`, `author`, `license`, `commands`, `skills`
- ✅ `hooks.json` has `PreToolUse` (matcher: "Bash") and `SessionStart`
- ✅ Both SKILL.md files have `---` frontmatter with `name` and `description`
- ✅ `description` field starts with "Invoked automatically" or "Use when"
- ✅ Scripts are executable (`ls -la plugins/git-branch-naming/scripts/`)

---

## 2. Unit Tests — validate-branch.sh (Branch Creation)

**Objective:** Verify branch name validation for all creation commands.

**Automation:** ✅

**Steps:**
```bash
SCRIPT="plugins/git-branch-naming/scripts/validate-branch.sh"

# Test: valid branch name → passthrough (exit 0, no output)
echo '{"tool_input":{"command":"git checkout -b feature/user-auth"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0

# Test: missing prefix → ask/deny output
echo '{"tool_input":{"command":"git checkout -b my-feature"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0 (default is ask), output JSON

# Test: uppercase → invalid
echo '{"tool_input":{"command":"git branch MyFeature/UserAuth"}}' | bash "$SCRIPT"

# Test: underscore → invalid
echo '{"tool_input":{"command":"git switch -c feature/user_auth"}}' | bash "$SCRIPT"

# Test: valid switch -c
echo '{"tool_input":{"command":"git switch -c bugfix/fix-null-pointer"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0 (passthrough)

# Test: non-git command → passthrough
echo '{"tool_input":{"command":"npm install"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0

# Test: git status → passthrough
echo '{"tool_input":{"command":"git status"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0
```

**Expected results:**
- ✅ Valid names: exit 0, no JSON output
- ✅ Invalid names: exit 0, JSON with `permissionDecision: "ask"` and descriptive reason
- ✅ `permissionDecisionReason` includes suggested fix with `git branch -m`
- ✅ Non-git commands: exit 0, no output (fast exit)

---

## 3. Unit Tests — validate-branch.sh (Commit & Push)

**Objective:** Verify commit and push interception.

**Automation:** ✅ (requires a git repo for full test)

**Steps:**
```bash
SCRIPT="plugins/git-branch-naming/scripts/validate-branch.sh"

# Test: git commit (no git repo — should gracefully skip content check)
echo '{"tool_input":{"command":"git commit -m \"feat: add login\""}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0

# Test: git push (no git repo — should gracefully exit)
echo '{"tool_input":{"command":"git push"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0

# Test: git push origin main (protected branch warning)
# (requires being on main branch in a git repo)
CLAUDE_PROJECT_DIR=/tmp/test-repo bash -c '
  mkdir -p /tmp/test-repo && cd /tmp/test-repo && git init -q && git checkout -q -b main 2>/dev/null || true
  echo "{\"tool_input\":{\"command\":\"git push origin main\"}}" | bash "$SCRIPT"
'
```

**Acceptance criteria:**
- ✅ `git commit` passes through when no git repo (graceful degradation)
- ✅ `git push` to protected branch produces `permissionDecision: "ask"` response
- ✅ Scripts don't crash with missing git repo

---

## 4. Config Loading Tests

**Objective:** Verify config loading from `.claude/git-branch-naming.json`.

**Automation:** ✅

**Setup:**
```bash
# Create test config
mkdir -p /tmp/test-project/.claude
cat > /tmp/test-project/.claude/git-branch-naming.json <<'EOF'
{
  "prefixes": ["feat", "fix"],
  "maxLength": 30,
  "protectedBranches": ["main"],
  "requireKebabCase": true,
  "warnOnContentMismatch": false,
  "enforcement": {
    "invalidName": "deny",
    "protectedBranch": "ask",
    "contentMismatch": "ask"
  }
}
EOF
```

**Tests:**
```bash
SCRIPT="plugins/git-branch-naming/scripts/validate-branch.sh"

# Test: custom prefix allowed
CLAUDE_PROJECT_DIR=/tmp/test-project \
  echo '{"tool_input":{"command":"git checkout -b feat/new-thing"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0 (passthrough)

# Test: default prefix denied (not in custom list)
CLAUDE_PROJECT_DIR=/tmp/test-project \
  echo '{"tool_input":{"command":"git checkout -b feature/new-thing"}}' | bash "$SCRIPT"
# Expected: JSON with permissionDecision: "deny"

# Test: max length enforced (> 30 chars)
# Note: branch name must actually exceed maxLength=30. "feat/this-is-a-really-too-long-name" = 35 chars
CLAUDE_PROJECT_DIR=/tmp/test-project \
  echo '{"tool_input":{"command":"git checkout -b feat/this-is-a-really-too-long-name"}}' | bash "$SCRIPT"
# Expected: JSON with permissionDecision: "deny"
```

**Acceptance criteria:**
- ✅ Custom prefix list overrides defaults
- ✅ Max length from config is respected
- ✅ `enforcement.invalidName: "deny"` produces `permissionDecision: "deny"`
- ✅ Missing config file falls back to defaults

---

## 5. Unit Tests — check-content-mismatch.sh

**Objective:** Verify file classification and mismatch detection logic.

**Automation:** ✅ (requires test git repos)

**Setup:**
```bash
# Create test repo with docs/ branch
mkdir -p /tmp/test-mismatch-repo
cd /tmp/test-mismatch-repo && git init -q
git config user.email "test@test.com" && git config user.name "Test"
echo "Initial" > README.md && git add . && git commit -q -m "init"
git checkout -q -b docs/update-readme
# Stage code files on docs branch
echo "console.log('test')" > app.js
echo "def foo(): pass" > main.py
git add app.js main.py
```

**Tests:**
```bash
SCRIPT="plugins/git-branch-naming/scripts/check-content-mismatch.sh"

# Test: docs branch with 100% code files → mismatch
bash "$SCRIPT" --staged "docs/update-readme" "/tmp/test-mismatch-repo"
# Expected: non-empty warning message

# Test: feature branch with code files → no mismatch
cd /tmp/test-mismatch-repo && git checkout -q -b feature/add-login
echo "auth.ts content" > auth.ts && git add auth.ts
bash "$SCRIPT" --staged "feature/add-login" "/tmp/test-mismatch-repo"
# Expected: empty output (no mismatch)

# Test: release branch → always skip
bash "$SCRIPT" --staged "release/1.0.0" "/tmp/test-mismatch-repo"
# Expected: empty output (release skipped)

# Test: too few files → skip
cd /tmp/test-mismatch-repo && git checkout -q -b docs/tiny
echo "a.ts content" > a.ts && git add a.ts
bash "$SCRIPT" --staged "docs/tiny" "/tmp/test-mismatch-repo"
# Expected: empty output (only 1 file, skip check)
```

**Acceptance criteria:**
- ✅ `docs/` branch with >80% code files → warning produced
- ✅ `feature/` branch with code files → no warning
- ✅ `release/` branch → always skipped
- ✅ <2 staged files → skipped (insufficient signal)
- ✅ No crash when repo has no remote base branch

---

## 6. Pre-push Hook Template Tests

**Objective:** Verify the standalone git pre-push hook works correctly.

**Automation:** ✅

**Steps:**
```bash
# Test: valid branch passes
mkdir -p /tmp/test-hook-repo && cd /tmp/test-hook-repo
git init -q
git config user.email "test@test.com" && git config user.name "Test"
echo "init" > README.md && git add . && git commit -q -m "init"
git checkout -q -b feature/test-feature

mkdir -p .githooks
cp /path/to/plugins/git-branch-naming/templates/pre-push .githooks/pre-push
chmod +x .githooks/pre-push
git config core.hooksPath .githooks

# Simulate pre-push run
bash .githooks/pre-push
echo "Exit: $?"  # Expected: 0

# Test: invalid branch (no prefix) → warning (ask mode)
git checkout -q -b my-bad-branch
bash .githooks/pre-push
echo "Exit: $?"  # Expected: 0 (ask = warn, don't block)

# Test: deny enforcement → exit 1
cat > .claude/git-branch-naming.json <<'EOF'
{"prefixes":["feature"],"enforcement":{"invalidName":"deny","protectedBranch":"deny","contentMismatch":"ask"}}
EOF
git checkout -q -b my-bad-branch2
bash .githooks/pre-push
echo "Exit: $?"  # Expected: 1 (deny = block)
```

**Acceptance criteria:**
- ✅ Valid branch name: exit 0, no output
- ✅ Invalid name + `ask` enforcement: exit 0, warning to stderr
- ✅ Invalid name + `deny` enforcement: exit 1, error to stderr
- ✅ Works without jq installed (falls back to defaults)

---

## 7. SessionStart Rules Injection (Manual)

**Objective:** Verify SessionStart hook outputs rules and Claude follows them.

**Automation:** ⚠️ Manual only (requires fresh session)

**Steps:**
1. Start fresh Claude Code session in a git repo:
   ```bash
   cd /tmp/test-project && git init && claude
   ```

2. Verify rules loaded:
   Ask: "What are the rules for git branch naming in this session?"
   Expected: Claude mentions prefixes, kebab-case, and `.claude/git-branch-naming.json`

3. Test proactive enforcement:
   Ask: "Create a git branch called `my-new-feature`"
   Expected: Claude warns about missing prefix, suggests `feature/my-new-feature`

4. Test valid name passes:
   Ask: "Create a git branch called `feature/add-user-login`"
   Expected: Claude runs `git checkout -b feature/add-user-login` without warning

5. Verify hook output token count:
   ```bash
   bash plugins/git-branch-naming/scripts/inject-rules.sh | wc -w
   ```
   Expected: < 200 words (~130 tokens)

**Acceptance criteria:**
- ✅ Hook exits 0
- ✅ Output is < 200 words
- ✅ Output contains valid prefixes list
- ✅ Claude enforces conventions proactively

**Known failure modes:**

If rules are NOT enforced in your test session:

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Claude ignores prefix requirement | Plugin cache stale | Run `claude-marketplace-sync --force` |
| Hook doesn't run | SessionStart race condition ([#10997](https://github.com/anthropics/claude-code/issues/10997)) | Run `/clear` to restart session |
| Rules partially followed | API timeout | Set `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000` |

---

## 8. /git-branch-naming:setup Command (Manual)

**Objective:** Verify the setup wizard creates correct config.

**Automation:** ⚠️ Manual only (interactive dialog)

**Steps:**
1. In Claude Code session: run `/git-branch-naming:setup`
2. When prompted for prefixes: select all defaults
3. When prompted for ticket pattern: select "No ticket required"
4. When prompted for max length: select 60
5. When prompted for enforcement: select "Ask (warn)"
6. When prompted for pre-push hook: select "No"
7. Verify file created: `cat .claude/git-branch-naming.json`
8. Verify JSON is valid: `jq . .claude/git-branch-naming.json`

**Acceptance criteria:**
- ✅ Wizard asks all 7 questions
- ✅ Config file created at `.claude/git-branch-naming.json`
- ✅ File is valid JSON
- ✅ All selected values appear in output
- ✅ Summary with "next steps" shown after completion

---

## 9. Cross-Platform Tests (Manual)

**Objective:** Verify scripts work on both macOS and Linux.

**Automation:** ⚠️ Manual only

**macOS tests:**
```bash
uname  # Darwin
bash plugins/git-branch-naming/scripts/inject-rules.sh
bash plugins/git-branch-naming/scripts/validate-branch.sh <<< '{"tool_input":{"command":"git checkout -b feature/test"}}'
```

**Linux tests** (or Docker):
```bash
docker run --rm -v $(pwd):/plugins alpine sh -c \
  "apk add -q bash git jq && bash /plugins/plugins/git-branch-naming/scripts/inject-rules.sh"
```

**Acceptance criteria:**
- ✅ All scripts exit 0 on macOS
- ✅ All scripts exit 0 on Linux (Alpine/Ubuntu)
- ✅ No bash-specific syntax that requires bash 4+ (macOS ships bash 3.2)
- ✅ `stat` command not used (cross-platform issue)

---

## 10. Team Config Sharing (Manual)

**Objective:** Verify committed config is respected by all team members.

**Automation:** ⚠️ Manual only

**Steps:**
1. In project A: run `/git-branch-naming:setup`, commit config
2. Clone project A to a new directory
3. Start Claude Code in cloned directory
4. Try to create branch with invalid name → should warn based on committed config
5. Verify same enforcement levels apply

**Acceptance criteria:**
- ✅ Cloned repo has `.claude/git-branch-naming.json`
- ✅ Plugin reads config from cloned repo
- ✅ Same enforcement levels apply in both repos

---

## Regression Testing Guide

### When to run

- Before releasing a new version
- After modifying any script under `scripts/`
- After changing hook configuration in `hooks/hooks.json`
- After updating config schema in `templates/git-branch-naming.json`

### Automated test run

```bash
# Run all automated tests (tests 1-6) in sequence
cd /path/to/claude-plugins

# 1. Static checks
echo "=== Static Checks ==="
jq . plugins/git-branch-naming/.claude-plugin/plugin.json >/dev/null && echo "plugin.json OK"
jq . plugins/git-branch-naming/hooks/hooks.json >/dev/null && echo "hooks.json OK"

# 2. Token count check
echo "=== Token Budget ==="
plugins/git-branch-naming/scripts/inject-rules.sh | wc -w

# 3. validate-branch.sh tests
echo "=== validate-branch.sh ==="
echo '{"tool_input":{"command":"git checkout -b feature/valid"}}' | bash plugins/git-branch-naming/scripts/validate-branch.sh; echo "valid name: $?"
echo '{"tool_input":{"command":"git checkout -b bad-name"}}' | bash plugins/git-branch-naming/scripts/validate-branch.sh | jq -r '.hookSpecificOutput.permissionDecision'
```

### CI integration

The plugin follows the same CI pattern as `plantuml` — add to your project's GitHub Actions:
```yaml
- name: Validate branch name
  run: |
    BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF#refs/heads/}}"
    echo "{\"tool_input\":{\"command\":\"git checkout -b $BRANCH\"}}" | \
      bash .githooks/pre-push
```
