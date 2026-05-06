# Fresh Guides Acceptance Tests

## Purpose

The fresh-guides plugin verifies advice against official docs for fast-changing technologies. These tests verify config reading, watchlist merging, SessionStart output formatting, silent exits, and skill invocation.

## Test Execution Order

1. Static checks (automated)
2. Script unit tests (automated)
3. SessionStart integration (manual — requires fresh session)
4. Skill invocation tests (manual — requires fresh session)

## Automation Status

- Fully automated: Tests 1-2
- Manual only: Tests 3-5 (require fresh Claude Code session)

---

## 1. Static Checks

**Objective:** Validate plugin structure and file formats.

**Automation:** Yes

**Steps:**

```bash
PLUGIN="/Users/artem/devel/claude-plugins/plugins/fresh-guides"

# plugin.json is valid JSON with required fields
jq -e '.name, .version, .commands, .skills' "$PLUGIN/.claude-plugin/plugin.json"

# hooks.json is valid JSON with SessionStart hook
jq -e '.hooks.SessionStart' "$PLUGIN/hooks/hooks.json"

# Template is valid JSON with required structure
jq -e '.watchlist' "$PLUGIN/templates/fresh-guides.json"

# SKILL.md files have YAML frontmatter
for f in "$PLUGIN"/commands/*/SKILL.md "$PLUGIN"/skills/*/SKILL.md; do
  head -1 "$f" | grep -q '^---' && echo "OK frontmatter: $f" || echo "FAIL frontmatter: $f"
done

# inject-rules.sh is executable
[[ -x "$PLUGIN/scripts/inject-rules.sh" ]] && echo "OK inject-rules.sh is executable" || echo "FAIL inject-rules.sh is not executable"
```

**Expected result:**
- All JSON files parse successfully
- All SKILL.md files have frontmatter
- inject-rules.sh is executable

---

## 2. Script Unit Tests — inject-rules.sh

**Objective:** Verify config reading, watchlist merging, output format, and silent exit.

**Automation:** Yes

**Steps:**

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/fresh-guides/scripts/inject-rules.sh"
PLUGIN="/Users/artem/devel/claude-plugins/plugins/fresh-guides"

# Test 2.1: Full config with watchlist entries
FAKE_HOME="/tmp/fg-test-1"
mkdir -p "$FAKE_HOME/.claude"
cat > "$FAKE_HOME/.claude/fresh-guides.json" <<'JSON'
{
  "watchlist": [
    {
      "name": "terraform",
      "docs": ["https://developer.hashicorp.com/terraform/docs", "https://github.com/hashicorp/terraform/releases"]
    },
    {
      "name": "aws terraform provider",
      "docs": ["https://registry.terraform.io/providers/hashicorp/aws/latest/docs"]
    }
  ]
}
JSON
output=$(env HOME="$FAKE_HOME" CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="/tmp/nonexistent" bash "$SCRIPT")
echo "$output" | grep -q '## Fresh Guides' && echo "OK 2.1: Header present" || echo "FAIL 2.1: Header missing"
echo "$output" | grep -q 'terraform' && echo "OK 2.1: Terraform entry" || echo "FAIL 2.1: Terraform missing"
echo "$output" | grep -q 'aws terraform provider' && echo "OK 2.1: AWS provider entry" || echo "FAIL 2.1: AWS provider missing"
echo "$output" | grep -q 'fresh-guides-verify' && echo "OK 2.1: Skill pointer" || echo "FAIL 2.1: Skill pointer missing"
echo "$output" | grep -q '<!-- Source: Plugin fresh-guides@artem-from-ua' && echo "OK 2.1: Source marker" || echo "FAIL 2.1: Source marker missing"

# Test 2.2: Silent exit with no config
output=$(env HOME=/tmp/nonexistent CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="/tmp/nonexistent" bash "$SCRIPT")
[[ -z "$output" ]] && echo "OK 2.2: Silent exit (no config)" || echo "FAIL 2.2: Unexpected output: $output"

# Test 2.3: Silent exit with empty watchlist
FAKE_HOME2="/tmp/fg-test-3"
mkdir -p "$FAKE_HOME2/.claude"
cat > "$FAKE_HOME2/.claude/fresh-guides.json" <<'JSON'
{
  "watchlist": []
}
JSON
output=$(env HOME="$FAKE_HOME2" CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="/tmp/nonexistent" bash "$SCRIPT")
[[ -z "$output" ]] && echo "OK 2.3: Silent exit (empty watchlist)" || echo "FAIL 2.3: Unexpected output: $output"

# Test 2.4: Project config overrides global
FAKE_HOME3="/tmp/fg-test-4"
FAKE_PROJECT="/tmp/fg-test-4-proj"
mkdir -p "$FAKE_HOME3/.claude" "$FAKE_PROJECT/.claude-plugin"
cat > "$FAKE_HOME3/.claude/fresh-guides.json" <<'JSON'
{
  "watchlist": [
    {
      "name": "terraform",
      "docs": ["https://global.example.com"]
    },
    {
      "name": "ansible",
      "docs": ["https://docs.ansible.com"]
    }
  ]
}
JSON
cat > "$FAKE_PROJECT/.claude-plugin/fresh-guides.json" <<'JSON'
{
  "watchlist": [
    {
      "name": "terraform",
      "docs": ["https://project.example.com"]
    }
  ]
}
JSON
output=$(env HOME="$FAKE_HOME3" CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$FAKE_PROJECT" bash "$SCRIPT")
echo "$output" | grep -q 'project.example.com' && echo "OK 2.4: Project terraform overrides global" || echo "FAIL 2.4: Project override failed"
echo "$output" | grep -q 'ansible' && echo "OK 2.4: Global-only ansible preserved" || echo "FAIL 2.4: Global ansible lost"
echo "$output" | grep -qv 'global.example.com' && echo "OK 2.4: Global terraform URL not present" || echo "FAIL 2.4: Global terraform URL leaked"

# Test 2.5: Source marker includes version
output=$(env HOME="$FAKE_HOME" CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="/tmp/nonexistent" bash "$SCRIPT")
echo "$output" | grep -q 'v0.1.0' && echo "OK 2.5: Version in source marker" || echo "FAIL 2.5: Version missing"

# Cleanup
rm -rf /tmp/fg-test-1 /tmp/fg-test-3 /tmp/fg-test-4 /tmp/fg-test-4-proj
```

**Expected result:**
- 2.1: Full output with header, entries, skill pointer, source marker
- 2.2: Zero output when no config exists
- 2.3: Zero output when watchlist is empty
- 2.4: Project entries override global entries with same name; global-only entries preserved
- 2.5: Version number present in source marker

---

## 3. SessionStart Integration

**Objective:** Verify that watchlist rules are injected into Claude Code session context.

**Automation:** Manual only (requires fresh session)

### Manual Test Procedure

**Step 1:** Create a test config:
```bash
mkdir -p ~/.claude
cat > ~/.claude/fresh-guides.json <<'JSON'
{
  "watchlist": [
    {
      "name": "terraform",
      "docs": ["https://developer.hashicorp.com/terraform/docs", "https://github.com/hashicorp/terraform/releases"]
    }
  ]
}
JSON
```

**Step 2:** Start a fresh Claude Code session.

**Step 3:** Ask Claude: "What's the syntax for terraform import block?"

**Expected:**
- Claude invokes `fresh-guides-verify` skill
- Claude detects terraform version from project or runtime
- Claude fetches official Terraform docs
- Response includes version-specific inline citations

**Step 4:** Ask Claude a general question: "What is infrastructure as code?"

**Expected:** No fresh-guides verification (general concept, not version-specific).

**Step 5:** Clean up:
```bash
rm ~/.claude/fresh-guides.json
```

---

## 4. Skill Invocation Tests

**Objective:** Verify `/fresh-guides-setup`, `/fresh-guides-show`, and `/fresh-guides-update` work correctly.

**Automation:** Manual only (requires Claude Code session)

### Test 4.1: /fresh-guides-setup

**Step 1:** In a Claude Code session, run `/fresh-guides-setup`

**Expected:**
- Explains what fresh-guides does
- Asks for technologies to watch
- For each technology, probes candidate doc URLs via WebFetch
- Presents working URLs as checkboxes with pre-selected defaults + "Other" option
- Asks for config scope (global vs project)
- Writes config file
- Shows summary table and restart reminder

### Test 4.2: /fresh-guides-show

**Step 1:** After setup, run `/fresh-guides-show`

**Expected:**
- Displays watchlist as a table with technology and docs
- Lists available update commands

### Test 4.3: /fresh-guides-update

**Step 1:** Run `/fresh-guides-update add kubernetes https://kubernetes.io/docs/`

**Expected:**
- Kubernetes added to watchlist
- Confirmation message shown

**Step 2:** Run `/fresh-guides-update url terraform https://github.com/hashicorp/terraform/releases`

**Expected:**
- URL added to terraform's docs array
- Confirmation message shown

**Step 3:** Run `/fresh-guides-update remove kubernetes`

**Expected:**
- Kubernetes removed from watchlist
- Confirmation message shown

---

## 5. Verification Behavior

**Objective:** Verify that the `fresh-guides-verify` skill correctly detects version, fetches docs, and cites sources.

**Automation:** Manual only (requires fresh session with WebFetch access)

### Test 5.1: Version detection and doc verification

**Step 1:** Configure terraform on watchlist, ensure terraform is installed locally.

**Step 2:** Ask about a terraform feature.

**Expected:**
- Claude runs `terraform version` to detect current version
- Claude fetches version-specific docs
- Response includes version-aware advice with inline citations

### Test 5.2: Feature not available in user's version

**Step 1:** Ask about a feature introduced in a version newer than the user's.

**Expected:** Claude warns: "Requires vX.Y+. Your vA.B does not support it." and suggests workaround if available.

### Test 5.3: Verification fails

**Step 1:** Configure a technology with an invalid doc URL, ask a version-specific question.

**Expected:** Claude explicitly states: "I could not verify this against official docs. My answer is based on training data." Lists configured URLs for manual check.

---

## Regression Testing Guide

Run tests 1-2 automatically before every release:
```bash
# Run all automated tests (copy and paste the bash blocks from sections 1-2)
```

Run tests 3-5 manually:
- After any change to `inject-rules.sh`
- After changing hooks.json
- After modifying SKILL.md files
