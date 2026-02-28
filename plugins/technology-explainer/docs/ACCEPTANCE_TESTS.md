# Technology Explainer Acceptance Tests

## Purpose

The technology-explainer plugin adapts Claude's explanation depth based on user proficiency per technology. These tests verify that config reading, SessionStart output formatting, silent exits, and skill invocation work correctly.

## Test Execution Order

1. Static checks (automated)
2. Script unit tests (automated)
3. SessionStart integration (manual — requires fresh session)
4. Skill invocation tests (manual — requires fresh session)

## Automation Status

- ✅ Fully automated: Tests 1-2
- ⚠️ Manual only: Tests 3-4 (require fresh Claude Code session)

---

## 1. Static Checks

**Objective:** Validate plugin structure and file formats.

**Automation:** ✅

**Steps:**

```bash
PLUGIN="/Users/artem/devel/claude-plugins/plugins/technology-explainer"

# plugin.json is valid JSON with required fields
jq -e '.name, .version, .commands, .skills' "$PLUGIN/.claude-plugin/plugin.json"

# hooks.json is valid JSON with SessionStart hook
jq -e '.hooks.SessionStart' "$PLUGIN/hooks/hooks.json"

# Template is valid JSON with required structure
jq -e '.technologies.expert, .technologies.intermediate, .technologies.learning, .defaultLevel' "$PLUGIN/templates/technology-explainer.json"

# SKILL.md files have YAML frontmatter
for f in "$PLUGIN"/commands/*/SKILL.md "$PLUGIN"/skills/*/SKILL.md; do
  head -1 "$f" | grep -q '^---' && echo "✅ frontmatter: $f" || echo "❌ frontmatter: $f"
done

# inject-rules.sh is executable
[[ -x "$PLUGIN/scripts/inject-rules.sh" ]] && echo "✅ inject-rules.sh is executable" || echo "❌ inject-rules.sh is not executable"
```

**Expected result:**
- ✅ All JSON files parse successfully
- ✅ All SKILL.md files have frontmatter
- ✅ inject-rules.sh is executable

---

## 2. Script Unit Tests — inject-rules.sh

**Objective:** Verify config reading, output format, silent exit, and source formatting.

**Automation:** ✅

**Steps:**

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/technology-explainer/scripts/inject-rules.sh"
PLUGIN="/Users/artem/devel/claude-plugins/plugins/technology-explainer"

# Test 2.1: Full config with all levels and sources
FAKE_HOME="/tmp/te-test-1"
mkdir -p "$FAKE_HOME/.claude"
cat > "$FAKE_HOME/.claude/technology-explainer.json" <<'JSON'
{
  "technologies": {
    "expert": ["linux", "git"],
    "intermediate": ["docker", "k8s"],
    "learning": ["terraform", "aws"]
  },
  "defaultLevel": "learning",
  "sources": {
    "terraform": ["https://developer.hashicorp.com/terraform/docs"],
    "aws": ["https://docs.aws.amazon.com"]
  }
}
JSON
output=$(env HOME="$FAKE_HOME" CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q '## Technology Explainer' && echo "✅ 2.1: Header present" || echo "❌ 2.1: Header missing"
echo "$output" | grep -q 'Expert.*linux, git' && echo "✅ 2.1: Expert list" || echo "❌ 2.1: Expert list missing"
echo "$output" | grep -q 'Intermediate.*docker, k8s' && echo "✅ 2.1: Intermediate list" || echo "❌ 2.1: Intermediate list missing"
echo "$output" | grep -q 'Learning.*terraform, aws' && echo "✅ 2.1: Learning list" || echo "❌ 2.1: Learning list missing"
echo "$output" | grep -q 'Default for unlisted.*learning' && echo "✅ 2.1: Default level" || echo "❌ 2.1: Default level missing"
echo "$output" | grep -q 'Sources.*terraform' && echo "✅ 2.1: Sources present" || echo "❌ 2.1: Sources missing"
echo "$output" | grep -q 'proficiency-guide-expert' && echo "✅ 2.1: Expert skill pointer" || echo "❌ 2.1: Expert skill pointer missing"
echo "$output" | grep -q 'proficiency-guide-intermediate' && echo "✅ 2.1: Intermediate skill pointer" || echo "❌ 2.1: Intermediate skill pointer missing"
echo "$output" | grep -q 'proficiency-guide-learning' && echo "✅ 2.1: Learning skill pointer" || echo "❌ 2.1: Learning skill pointer missing"
echo "$output" | grep -q '<!-- Source: Plugin technology-explainer@tribe-coding' && echo "✅ 2.1: Source marker" || echo "❌ 2.1: Source marker missing"

# Test 2.2: Silent exit with no config
output=$(env HOME=/tmp/nonexistent CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
[[ -z "$output" ]] && echo "✅ 2.2: Silent exit (no config)" || echo "❌ 2.2: Unexpected output: $output"

# Test 2.3: Silent exit with empty arrays
FAKE_HOME2="/tmp/te-test-3"
mkdir -p "$FAKE_HOME2/.claude"
cat > "$FAKE_HOME2/.claude/technology-explainer.json" <<'JSON'
{
  "technologies": {
    "expert": [],
    "intermediate": [],
    "learning": []
  },
  "defaultLevel": "learning",
  "sources": {}
}
JSON
output=$(env HOME="$FAKE_HOME2" CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
[[ -z "$output" ]] && echo "✅ 2.3: Silent exit (empty arrays)" || echo "❌ 2.3: Unexpected output: $output"

# Test 2.4: Partial config (only expert)
FAKE_HOME3="/tmp/te-test-4"
mkdir -p "$FAKE_HOME3/.claude"
cat > "$FAKE_HOME3/.claude/technology-explainer.json" <<'JSON'
{
  "technologies": {
    "expert": ["linux"],
    "intermediate": [],
    "learning": []
  },
  "defaultLevel": "intermediate"
}
JSON
output=$(env HOME="$FAKE_HOME3" CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q 'Expert.*linux' && echo "✅ 2.4: Expert only" || echo "❌ 2.4: Expert missing"
echo "$output" | grep -qv 'Intermediate' && echo "✅ 2.4: No intermediate line" || echo "❌ 2.4: Unexpected intermediate line"
echo "$output" | grep -qv 'Learning' && echo "✅ 2.4: No learning line" || echo "❌ 2.4: Unexpected learning line"
echo "$output" | grep -q 'Default for unlisted.*intermediate' && echo "✅ 2.4: Custom default" || echo "❌ 2.4: Custom default missing"

# Test 2.5: Config with no sources key
FAKE_HOME4="/tmp/te-test-5"
mkdir -p "$FAKE_HOME4/.claude"
cat > "$FAKE_HOME4/.claude/technology-explainer.json" <<'JSON'
{
  "technologies": {
    "expert": ["git"],
    "intermediate": [],
    "learning": ["python"]
  },
  "defaultLevel": "learning"
}
JSON
output=$(env HOME="$FAKE_HOME4" CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -qv 'Sources' && echo "✅ 2.5: No sources line" || echo "❌ 2.5: Unexpected sources line"

# Test 2.6: Scope restriction is present
output=$(env HOME="$FAKE_HOME" CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q 'ONLY.*terminal dialogue' && echo "✅ 2.6: Scope restriction" || echo "❌ 2.6: Scope restriction missing"

# Cleanup
rm -rf /tmp/te-test-1 /tmp/te-test-3 /tmp/te-test-4 /tmp/te-test-5
```

**Expected result:**
- ✅ 2.1: Full output with all sections, skill pointers, source marker
- ✅ 2.2: Zero output when no config exists
- ✅ 2.3: Zero output when all tech arrays are empty
- ✅ 2.4: Only populated levels shown, custom default level
- ✅ 2.5: No sources line when sources key is missing
- ✅ 2.6: Scope restriction present in output

---

## 3. SessionStart Integration

**Objective:** Verify that proficiency context is injected into Claude Code session.

**Automation:** ⚠️ Manual only (requires fresh session)

### Manual Test Procedure

**Step 1:** Create a test config:
```bash
mkdir -p ~/.claude
cat > ~/.claude/technology-explainer.json <<'JSON'
{
  "technologies": {
    "expert": ["linux", "git"],
    "intermediate": ["docker"],
    "learning": ["terraform"]
  },
  "defaultLevel": "learning",
  "sources": {
    "terraform": ["https://developer.hashicorp.com/terraform/docs"]
  }
}
JSON
```

**Step 2:** Start a fresh Claude Code session.

**Step 3:** Ask Claude: "Explain how git stash works."

**Expected:** Brief, no-theory answer (git is expert-level).

**Step 4:** Ask Claude: "Explain Docker networking."

**Expected:** Nuanced answer covering gotchas, skipping basics (Docker is intermediate-level).

**Step 5:** Ask Claude: "Explain Terraform modules."

**Expected:** Detailed explanation with theory, examples, step-by-step, referencing HashiCorp docs (Terraform is learning-level with custom source).

**Step 6:** Clean up:
```bash
rm ~/.claude/technology-explainer.json
```

---

## 4. Skill Invocation Tests

**Objective:** Verify `/technology-explainer-setup`, `/technology-explainer-show`, and `/technology-explainer-update` work correctly.

**Automation:** ⚠️ Manual only (requires Claude Code session)

### Test 4.1: /technology-explainer-setup

**Step 1:** In a Claude Code session, run `/technology-explainer-setup`

**Expected:**
- Explains the three proficiency levels
- Asks for expert, learning, then intermediate technologies
- Asks for default level
- Optionally asks for custom sources
- Writes `~/.claude/technology-explainer.json`
- Shows confirmation summary

### Test 4.2: /technology-explainer-show

**Step 1:** After setup, run `/technology-explainer-show`

**Expected:**
- Displays technologies grouped by level in a table
- Shows default level
- Shows custom sources if configured
- Lists available update commands

### Test 4.3: /technology-explainer-update

**Step 1:** Run `/technology-explainer-update docker expert`

**Expected:**
- Docker moved from intermediate to expert
- Confirmation message shown

**Step 2:** Run `/technology-explainer-update default intermediate`

**Expected:**
- Default level changed to intermediate
- Confirmation message shown

**Step 3:** Run `/technology-explainer-update source python "PEP 8 style guide"`

**Expected:**
- Source added for python
- Confirmation message shown

---

## Regression Testing Guide

Run tests 1-2 automatically before every release:
```bash
# Run all automated tests (copy and paste the bash blocks from sections 1-2)
```

Run tests 3-4 manually:
- After any change to `inject-rules.sh`
- After changing hooks.json
- After modifying skill SKILL.md files
