# git-branch-naming Acceptance Tests

## Purpose

The `git-branch-naming` plugin enforces git branch naming conventions via PreToolUse hooks and injected SessionStart rules. These tests verify:
- Branch name validation (format, prefix, kebab-case, ticket, length)
- Config loading from `.claude-plugin/git-branch-naming.json`
- Protected branch warnings before push
- Content mismatch detection at `git commit` and `git push`
- SessionStart rules injection
- `/git-branch-naming:setup` interactive flow

## Test Execution Order

1. Static checks (automated)
2. Unit tests — validate-branch.sh (automated)
3. Unit tests — validate-branch.sh commit & push (automated)
3b. Unit tests — open PR check (automated, partial manual)
4. Config loading tests (automated)
5. Unit tests — check-content-mismatch.sh (automated)
6. Pre-push hook template tests (automated)
7. Behavioral tests — SessionStart rules (manual, fresh session required)
8. Behavioral tests — `/git-branch-naming:setup` command (manual)
9. Cross-platform tests (manual)
10. Team config sharing (manual)

## Automation Status

- ✅ Fully automated: Tests 1–6 (3b partially — foreign PR tests require a real repo with another user's PR)
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
# Use absolute path — CWD is not guaranteed between Bash tool calls
SCRIPT="/path/to/plugins/git-branch-naming/scripts/validate-branch.sh"

# Test: valid branch name → passthrough (exit 0, no output)
printf '%s' '{"tool_input":{"command":"git checkout -b feature/user-auth"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0

# Test: missing prefix → ask/deny output
printf '%s' '{"tool_input":{"command":"git checkout -b my-feature"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0 (default is ask), output JSON

# Test: uppercase → invalid
printf '%s' '{"tool_input":{"command":"git branch MyFeature/UserAuth"}}' | bash "$SCRIPT"

# Test: underscore → invalid
printf '%s' '{"tool_input":{"command":"git switch -c feature/user_auth"}}' | bash "$SCRIPT"

# Test: valid switch -c
printf '%s' '{"tool_input":{"command":"git switch -c bugfix/fix-null-pointer"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0 (passthrough)

# Test: non-git command → passthrough
printf '%s' '{"tool_input":{"command":"npm install"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0

# Test: git status → passthrough
printf '%s' '{"tool_input":{"command":"git status"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0
```

**Expected results:**
- ✅ Valid names: exit 0, no JSON output
- ✅ Invalid names: exit 0, JSON with `permissionDecision: "ask"` and descriptive reason
- ✅ `permissionDecisionReason` includes suggested fix with `git branch -m`
- ✅ Non-git commands: exit 0, no output (fast exit)

---

## 3. Unit Tests — validate-branch.sh (Commit & Push)

**Objective:** Verify commit and push interception, including direct commits to protected branches.

**Automation:** ✅ (requires a git repo for full test)

**Steps:**
```bash
SCRIPT="/path/to/plugins/git-branch-naming/scripts/validate-branch.sh"

# Setup: repo on main
rm -rf /tmp/test-commit-protect
mkdir /tmp/test-commit-protect
git -C /tmp/test-commit-protect init -q
git -C /tmp/test-commit-protect -c user.email=t@t.com -c user.name=T commit -q --allow-empty -m "init"

# Test: git commit on main → protected branch warning
printf '%s' '{"tool_input":{"command":"git commit -m \"feat: add login\""}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-commit-protect bash "$SCRIPT"
# Expected: JSON with permissionDecision: "ask", mentions "protected branch 'main'"

# Test: git commit on master → protected branch warning
rm -rf /tmp/test-commit-master
mkdir /tmp/test-commit-master
git -C /tmp/test-commit-master init -q -b master
git -C /tmp/test-commit-master -c user.email=t@t.com -c user.name=T commit -q --allow-empty -m "init"
printf '%s' '{"tool_input":{"command":"git commit -m \"fix: something\""}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-commit-master bash "$SCRIPT"
# Expected: JSON with permissionDecision: "ask", mentions "protected branch 'master'"

# Test: git commit on feature branch → passthrough (no output)
git -C /tmp/test-commit-protect checkout -q -b feature/my-thing
printf '%s' '{"tool_input":{"command":"git commit -m \"feat: add login\""}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-commit-protect bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0, empty output

# Test: git push (no git repo — graceful exit)
printf '%s' '{"tool_input":{"command":"git push"}}' | bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0

# Test: git push origin main → protected branch warning
printf '%s' '{"tool_input":{"command":"git push origin main"}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-commit-protect bash "$SCRIPT"
# Expected: JSON with permissionDecision: "ask"
```

**Acceptance criteria:**
- ✅ `git commit` on `main` → `permissionDecision: "ask"` with PR workflow suggestion
- ✅ `git commit` on `master` → same warning
- ✅ `git commit` on feature branch → silent passthrough (exit 0, no output)
- ✅ `git push` to protected branch → `permissionDecision: "ask"` response
- ✅ Scripts don't crash with missing git repo

---

## 3b. Unit Tests — Open PR Check

**Objective:** Verify `check_open_pr()` detects foreign PRs and respects config.

**Automation:** ✅ (requires `gh` CLI and authenticated GitHub session for full test; graceful skip otherwise)

**Steps:**
```bash
SCRIPT="/path/to/plugins/git-branch-naming/scripts/validate-branch.sh"

# Setup: repo on a feature branch
rm -rf /tmp/test-open-pr && mkdir /tmp/test-open-pr
git -C /tmp/test-open-pr init -q
git -C /tmp/test-open-pr -c user.email=t@t.com -c user.name=T commit -q --allow-empty -m "init"
git -C /tmp/test-open-pr checkout -q -b feature/no-pr-here

# Test 1: Branch without open PR → passthrough (no output)
printf '%s' '{"tool_input":{"command":"git commit -m \"test\""}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-open-pr bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0, no JSON output

# Test 2: checkOpenPR: "off" → passthrough without calling gh
mkdir -p /tmp/test-open-pr/.claude-plugin
cat > /tmp/test-open-pr/.claude-plugin/git-branch-naming.json <<'CONF'
{"checkOpenPR": "off", "protectedBranches": ["main"]}
CONF
printf '%s' '{"tool_input":{"command":"git commit -m \"test\""}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-open-pr bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0, no output (skipped immediately)
rm /tmp/test-open-pr/.claude-plugin/git-branch-naming.json

# Test 3: gh not installed → silent passthrough
# (simulate by temporarily hiding gh from PATH)
printf '%s' '{"tool_input":{"command":"git commit -m \"test\""}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-open-pr PATH=/usr/bin:/bin bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0, no output

# Test 4: gh not authenticated → silent passthrough
# (requires mock — skip in automated runs, verify manually)

# Test 5: PR by same author → passthrough
# (requires a repo with an open PR by the current gh user — verify manually)

# Test 6: PR by different author + ask → JSON with permissionDecision: "ask"
# (requires a repo with an open PR by another user)
# On branch with foreign PR:
# printf '%s' '{"tool_input":{"command":"git commit -m \"test\""}}' \
#   | env CLAUDE_PROJECT_DIR=/path/to/repo bash "$SCRIPT"
# Expected: JSON with permissionDecision: "ask", message mentions PR author

# Test 7: PR by different author + deny → JSON with permissionDecision: "deny"
# (same as Test 6 but with config checkOpenPR: "deny")
# mkdir -p /path/to/repo/.claude-plugin
# echo '{"checkOpenPR": "deny"}' > /path/to/repo/.claude-plugin/git-branch-naming.json
# Expected: JSON with permissionDecision: "deny"

# Test 8: git push also triggers the check
# printf '%s' '{"tool_input":{"command":"git push"}}' \
#   | env CLAUDE_PROJECT_DIR=/path/to/repo-with-foreign-pr bash "$SCRIPT"
# Expected: same warning as git commit
```

**Acceptance criteria:**
- ✅ Branch without open PR: exit 0, no JSON output
- ✅ `checkOpenPR: "off"`: exit 0, no output, no `gh` calls
- ✅ `gh` not installed (`command -v gh` fails): silent passthrough
- ✅ `gh` not authenticated (`gh auth status` fails): silent passthrough
- ✅ PR by same author (`pr_author == my_login`): silent passthrough
- ✅ PR by different author + `ask`: JSON with `permissionDecision: "ask"`, message includes PR number, title, and author
- ✅ PR by different author + `deny`: JSON with `permissionDecision: "deny"`
- ✅ Check triggers on both `git commit` and `git push` code paths

---

## 4. Config Loading Tests

**Objective:** Verify config loading from `.claude-plugin/git-branch-naming.json`.

**Automation:** ✅

**Setup:**
```bash
# Create test config (new path .claude-plugin/)
mkdir -p /tmp/test-project/.claude-plugin
cat > /tmp/test-project/.claude-plugin/git-branch-naming.json <<'EOF'
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
SCRIPT="/path/to/plugins/git-branch-naming/scripts/validate-branch.sh"

# Test: custom prefix allowed
printf '%s' '{"tool_input":{"command":"git checkout -b feat/new-thing"}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-project bash "$SCRIPT"
echo "Exit: $?"  # Expected: 0 (passthrough)

# Test: default prefix denied (not in custom list)
printf '%s' '{"tool_input":{"command":"git checkout -b feature/new-thing"}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-project bash "$SCRIPT"
# Expected: JSON with permissionDecision: "deny"

# Test: max length enforced (> 30 chars)
# Note: branch name must actually exceed maxLength=30. "feat/this-is-a-really-too-long-name" = 35 chars
printf '%s' '{"tool_input":{"command":"git checkout -b feat/this-is-a-really-too-long-name"}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-project bash "$SCRIPT"
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
# Use git -C instead of cd — CWD does not persist between Bash tool calls
SCRIPT="/path/to/plugins/git-branch-naming/scripts/check-content-mismatch.sh"

rm -rf /tmp/test-mismatch-repo
mkdir /tmp/test-mismatch-repo
git -C /tmp/test-mismatch-repo init -q
git -C /tmp/test-mismatch-repo -c user.email=t@t.com -c user.name=T commit -q --allow-empty -m "init"
git -C /tmp/test-mismatch-repo checkout -q -b docs/update-readme
# Stage code files on docs branch
printf '%s\n' "console.log('test')" > /tmp/test-mismatch-repo/app.js
printf '%s\n' "def foo(): pass" > /tmp/test-mismatch-repo/main.py
git -C /tmp/test-mismatch-repo add app.js main.py
```

**Tests:**
```bash
# Test: docs branch with 100% code files → mismatch
bash "$SCRIPT" --staged "docs/update-readme" "/tmp/test-mismatch-repo"
# Expected: non-empty warning message

# Test: feature branch with code files → no mismatch
git -C /tmp/test-mismatch-repo checkout -q -b feature/add-login
printf '%s\n' "auth.ts content" > /tmp/test-mismatch-repo/auth.ts
git -C /tmp/test-mismatch-repo add auth.ts
bash "$SCRIPT" --staged "feature/add-login" "/tmp/test-mismatch-repo"
# Expected: empty output (no mismatch)

# Test: release branch → always skip
bash "$SCRIPT" --staged "release/1.0.0" "/tmp/test-mismatch-repo"
# Expected: empty output (release skipped)

# Test: too few files → skip
rm -rf /tmp/test-mismatch-tiny && mkdir /tmp/test-mismatch-tiny
git -C /tmp/test-mismatch-tiny init -q
git -C /tmp/test-mismatch-tiny -c user.email=t@t.com -c user.name=T commit -q --allow-empty -m "init"
git -C /tmp/test-mismatch-tiny checkout -q -b docs/tiny
printf '%s\n' "a.ts content" > /tmp/test-mismatch-tiny/a.ts
git -C /tmp/test-mismatch-tiny add a.ts
bash "$SCRIPT" --staged "docs/tiny" "/tmp/test-mismatch-tiny"
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
mkdir -p .claude-plugin
cat > .claude-plugin/git-branch-naming.json <<'EOF'
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
   Expected: Claude mentions prefixes, kebab-case, and `.claude-plugin/git-branch-naming.json`

3. Test proactive enforcement — invalid branch name:
   Ask: "Create a git branch called `my-new-feature`"
   Expected: Claude warns about missing prefix, suggests `feature/my-new-feature`

4. Test proactive enforcement — direct commit to main:
   Ask: "Commit these changes directly to main"
   Expected: Claude refuses, explains protected branch rule, suggests creating a feature branch

5. Test valid name passes:
   Ask: "Create a git branch called `feature/add-user-login`"
   Expected: Claude runs `git checkout -b feature/add-user-login` without warning

6. Verify hook output token count:
   ```bash
   bash plugins/git-branch-naming/scripts/inject-rules.sh | wc -w
   ```
   Expected: < 200 words (~147 tokens)

**Acceptance criteria:**
- ✅ Hook exits 0
- ✅ Output is < 200 words
- ✅ Output contains valid prefixes list
- ✅ Output contains rule about NOT committing directly to main/master
- ✅ Claude enforces commit conventions proactively (not just branch creation)

**Known failure modes:**

If rules are NOT enforced in your test session:

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Claude ignores prefix requirement | Plugin cache stale | Restart Claude Code |
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
6. When prompted for content mismatch: select "Enable"
7. When prompted for open PR check: select "Ask (warn)"
8. When prompted for pre-push hook: select "No"
9. Verify file created: `cat .claude-plugin/git-branch-naming.json`
10. Verify JSON is valid: `jq . .claude-plugin/git-branch-naming.json`
11. Verify `checkOpenPR` field exists: `jq '.checkOpenPR' .claude-plugin/git-branch-naming.json`

**Acceptance criteria:**
- ✅ Wizard asks all 8 questions
- ✅ Config file created at `.claude-plugin/git-branch-naming.json`
- ✅ File is valid JSON
- ✅ All selected values appear in output, including `checkOpenPR`
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
- ✅ Cloned repo has `.claude-plugin/git-branch-naming.json`
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
SCRIPT="/path/to/plugins/git-branch-naming/scripts/validate-branch.sh"
echo "=== validate-branch.sh ==="
printf '%s' '{"tool_input":{"command":"git checkout -b feature/valid"}}' | bash "$SCRIPT"; echo "valid name: $?"
printf '%s' '{"tool_input":{"command":"git checkout -b bad-name"}}' | bash "$SCRIPT" | python3 -c "import sys,json; print(json.load(sys.stdin)['hookSpecificOutput']['permissionDecision'])"

# Setup repo for commit-on-protected test
rm -rf /tmp/test-protected && mkdir /tmp/test-protected
git -C /tmp/test-protected init -q
git -C /tmp/test-protected -c user.email=t@t.com -c user.name=T commit -q --allow-empty -m "init"
echo "=== commit on main → ask ==="
printf '%s' '{"tool_input":{"command":"git commit -m \"test\""}}' \
  | env CLAUDE_PROJECT_DIR=/tmp/test-protected bash "$SCRIPT" | python3 -c "import sys,json; print(json.load(sys.stdin)['hookSpecificOutput']['permissionDecision'])"
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
