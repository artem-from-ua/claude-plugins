# Playbook Acceptance Tests

## Purpose

The playbook plugin injects curated coding guideline presets into Claude Code sessions. These tests verify that preset selection, config merging, RULES extraction, and on-demand REFERENCE browsing work correctly across both global and project config levels.

## Test Execution Order

1. Static checks (automated)
2. Script unit tests (automated)
3. Config merge tests (automated)
4. SessionStart integration (manual — requires fresh session)
5. Skill invocation tests (manual — requires fresh session)

## Automation Status

- ✅ Fully automated: Tests 1-3
- ⚠️ Manual only: Tests 4-5 (require fresh Claude Code session)

---

## 1. Static Checks

**Objective:** Validate plugin structure and file formats.

**Automation:** ✅

**Steps:**

```bash
PLUGIN="/Users/artem/devel/claude-plugins/plugins/playbook"

# plugin.json is valid JSON with required fields
jq -e '.name, .version, .commands, .skills' "$PLUGIN/.claude-plugin/plugin.json"

# hooks.json is valid JSON with SessionStart hook
jq -e '.hooks.SessionStart' "$PLUGIN/hooks/hooks.json"

# All presets have YAML frontmatter and both zones
for f in "$PLUGIN"/presets/*.md; do
  head -1 "$f" | grep -q '^---' && echo "✅ frontmatter: $(basename "$f")" || echo "❌ frontmatter: $(basename "$f")"
  grep -q '<!-- RULES -->' "$f" && echo "✅ RULES zone: $(basename "$f")" || echo "❌ RULES zone: $(basename "$f")"
  grep -q '<!-- REFERENCE -->' "$f" && echo "✅ REFERENCE zone: $(basename "$f")" || echo "❌ REFERENCE zone: $(basename "$f")"
done

# SKILL.md files have YAML frontmatter
for f in "$PLUGIN"/commands/*/SKILL.md "$PLUGIN"/skills/*/SKILL.md; do
  head -1 "$f" | grep -q '^---' && echo "✅ frontmatter: $f" || echo "❌ frontmatter: $f"
done
```

**Expected result:**
- ✅ All JSON files parse successfully
- ✅ All presets have frontmatter, RULES zone, and REFERENCE zone
- ✅ All SKILL.md files have frontmatter

---

## 2. Script Unit Tests — inject-rules.sh

**Objective:** Verify RULES extraction, config loading, silent exit, and `<!-- Source: ... Preset ... -->` markers.

**Automation:** ✅

**Steps:**

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/playbook/scripts/inject-rules.sh"
PLUGIN="/Users/artem/devel/claude-plugins/plugins/playbook"

# Test 2.1: Project config with both presets (new path .claude-plugin/)
mkdir -p /tmp/playbook-test-2/.claude-plugin
printf '{"presets":["documentation-principles","github-workflow"]}' > /tmp/playbook-test-2/.claude-plugin/playbook.json
output=$(env CLAUDE_PROJECT_DIR=/tmp/playbook-test-2 CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q "MANDATORY" && echo "✅ 2.1: RULES extracted" || echo "❌ 2.1: RULES not found"
echo "$output" | grep -q "Documentation" && echo "✅ 2.1: doc preset" || echo "❌ 2.1: doc preset missing"
echo "$output" | grep -q "GitHub Workflow" && echo "✅ 2.1: github preset" || echo "❌ 2.1: github preset missing"

# Test 2.2: Silent exit with no config
output=$(env HOME=/tmp/nonexistent CLAUDE_PROJECT_DIR=/tmp/nonexistent CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
[[ -z "$output" ]] && echo "✅ 2.2: Silent exit" || echo "❌ 2.2: Unexpected output: $output"

# Test 2.3: Nonexistent preset name (graceful skip)
mkdir -p /tmp/playbook-test-3/.claude-plugin
printf '{"presets":["nonexistent-preset"]}' > /tmp/playbook-test-3/.claude-plugin/playbook.json
output=$(env CLAUDE_PROJECT_DIR=/tmp/playbook-test-3 HOME=/tmp/nonexistent CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
[[ -z "$output" ]] && echo "✅ 2.3: Nonexistent preset skipped silently" || echo "❌ 2.3: Unexpected output"

# Test 2.4: Backwards compatibility — old path .claude/ still works
mkdir -p /tmp/playbook-test-4/.claude
printf '{"presets":["documentation-principles"]}' > /tmp/playbook-test-4/.claude/playbook.json
output=$(env CLAUDE_PROJECT_DIR=/tmp/playbook-test-4 CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q "MANDATORY" && echo "✅ 2.4: Old path fallback works" || echo "❌ 2.4: Old path fallback broken"

# Test 2.5: New path takes priority over old path
mkdir -p /tmp/playbook-test-5/.claude-plugin /tmp/playbook-test-5/.claude
printf '{"presets":["documentation-principles"]}' > /tmp/playbook-test-5/.claude-plugin/playbook.json
printf '{"presets":["github-workflow"]}' > /tmp/playbook-test-5/.claude/playbook.json
output=$(env CLAUDE_PROJECT_DIR=/tmp/playbook-test-5 CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q "Documentation" && echo "✅ 2.5: New path wins" || echo "❌ 2.5: New path not prioritized"
echo "$output" | grep -q "GitHub Workflow" && echo "❌ 2.5: Old path should not win" || echo "✅ 2.5: Old path correctly ignored"

# Test 2.6: Preset markers emitted before each preset (v0.3.1+)
# Each preset output must be preceded by:
# <!-- Source: Plugin playbook@tribe-coding (vX.Y.Z) Preset <name> -->
mkdir -p /tmp/playbook-test-6/.claude-plugin
printf '{"presets":["documentation-principles","github-workflow"]}' > /tmp/playbook-test-6/.claude-plugin/playbook.json
output=$(env CLAUDE_PROJECT_DIR=/tmp/playbook-test-6 CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
marker_count=$(echo "$output" | grep -c '<!-- Source: Plugin playbook@tribe-coding (v[^)]*) Preset ' || true)
[[ "$marker_count" -ge 2 ]] && echo "✅ 2.6: Preset markers present ($marker_count)" || echo "❌ 2.6: Expected ≥2 markers, got $marker_count"
# Verify marker format
echo "$output" | grep -q '<!-- Source: Plugin playbook@tribe-coding (v[0-9]*\.[0-9]*\.[0-9]*) Preset documentation-principles -->' \
  && echo "✅ 2.6: documentation-principles marker correct" || echo "❌ 2.6: documentation-principles marker missing or wrong format"
echo "$output" | grep -q '<!-- Source: Plugin playbook@tribe-coding (v[0-9]*\.[0-9]*\.[0-9]*) Preset github-workflow -->' \
  && echo "✅ 2.6: github-workflow marker correct" || echo "❌ 2.6: github-workflow marker missing or wrong format"
# Verify marker appears BEFORE preset content (not after)
first_marker_line=$(echo "$output" | grep -n '<!-- Source: Plugin playbook' | head -1 | cut -d: -f1)
first_content_line=$(echo "$output" | grep -n "^MANDATORY\|^## Documentation\|^## GitHub" | head -1 | cut -d: -f1)
[[ -n "$first_marker_line" && -n "$first_content_line" && "$first_marker_line" -lt "$first_content_line" ]] \
  && echo "✅ 2.6: Marker precedes content" || echo "❌ 2.6: Marker order wrong"

# Cleanup
rm -rf /tmp/playbook-test-2 /tmp/playbook-test-3 /tmp/playbook-test-4 /tmp/playbook-test-5 /tmp/playbook-test-6
```

**Expected result:**
- ✅ 2.1: Both presets extracted with MANDATORY rules
- ✅ 2.2: Zero output when no config exists
- ✅ 2.3: Nonexistent presets skipped without error
- ✅ 2.6: Preset markers `<!-- Source: Plugin playbook@tribe-coding (vX.Y.Z) Preset NAME -->` emitted before each preset
- ✅ 2.6: Marker format matches `playbook@tribe-coding (v{semver}) Preset {name}`
- ✅ 2.6: Marker appears on the line immediately before preset content

---

## 3. Config Merge Tests

**Objective:** Verify union + exclude merge logic across global and project configs.

**Automation:** ✅

**Steps:**

```bash
SCRIPT="/Users/artem/devel/claude-plugins/plugins/playbook/scripts/inject-rules.sh"
PLUGIN="/Users/artem/devel/claude-plugins/plugins/playbook"

# Setup fake HOME with global config
FAKE_HOME="/tmp/playbook-home-test"
mkdir -p "$FAKE_HOME/.claude"
printf '{"presets":["documentation-principles","github-workflow"]}' > "$FAKE_HOME/.claude/playbook.json"

# Test 3.1: Global only (no project config)
output=$(env HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR=/tmp/nonexistent CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q "Documentation" && echo "✅ 3.1: Global doc preset" || echo "❌ 3.1"
echo "$output" | grep -q "GitHub Workflow" && echo "✅ 3.1: Global github preset" || echo "❌ 3.1"

# Test 3.2: Project excludes one global preset
mkdir -p /tmp/playbook-proj-test/.claude-plugin
printf '{"presets":[],"exclude":["documentation-principles"]}' > /tmp/playbook-proj-test/.claude-plugin/playbook.json
output=$(env HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR=/tmp/playbook-proj-test CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
echo "$output" | grep -q "Documentation" && echo "❌ 3.2: Doc should be excluded" || echo "✅ 3.2: Doc excluded"
echo "$output" | grep -q "GitHub Workflow" && echo "✅ 3.2: Github kept" || echo "❌ 3.2: Github missing"

# Test 3.3: Deduplication (same preset in both configs)
printf '{"presets":["documentation-principles"]}' > /tmp/playbook-proj-test/.claude-plugin/playbook.json
output=$(env HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR=/tmp/playbook-proj-test CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$SCRIPT")
count=$(echo "$output" | grep -c "Documentation — Base Rules")
[[ "$count" -eq 1 ]] && echo "✅ 3.3: No duplication" || echo "❌ 3.3: Duplicated ($count times)"

# Cleanup
rm -rf "$FAKE_HOME" /tmp/playbook-proj-test
```

**Expected result:**
- ✅ 3.1: Both global presets output
- ✅ 3.2: Excluded preset not in output, other preset kept
- ✅ 3.3: Same preset in both configs outputs only once

---

## 4. SessionStart Integration

**Objective:** Verify that RULES are injected into Claude Code session context.

**Automation:** ⚠️ Manual only (requires fresh session)

### Manual Test Procedure

**Step 1:** Create a test config:
```bash
mkdir -p ~/.claude
printf '{"presets":["documentation-principles"]}' > ~/.claude/playbook.json
```

**Step 2:** Start a fresh Claude Code session in any git repo.

**Step 3:** Ask Claude: "What are the documentation rules?"

**Expected:** Claude should mention:
- Documentation is part of the codebase
- Commit checklist (architecture, API, ADR, conventions, cross-links)
- NEVER leave `TODO: document this`

**Step 4:** Clean up:
```bash
rm ~/.claude/playbook.json
```

---

## 5. Skill Invocation Tests

**Objective:** Verify `/playbook-setup` and `/playbook-browse` work correctly.

**Automation:** ⚠️ Manual only (requires Claude Code session)

### Test 5.1: /playbook-setup

**Step 1:** In a Claude Code session, run `/playbook-setup`

**Expected:**
- Lists available presets with descriptions
- Asks which to enable (multiSelect)
- Asks global vs project level
- Writes config JSON to chosen location
- Shows confirmation

### Test 5.2: /playbook-browse

**Step 1:** In a Claude Code session, run `/playbook-browse`

**Expected:**
- Lists available presets
- After selection, displays REFERENCE zone content
- Content includes full documentation (not just RULES)

---

## Regression Testing Guide

Run tests 1-3 automatically before every release:
```bash
# Run all automated tests
bash /Users/artem/devel/claude-plugins/plugins/playbook/docs/ACCEPTANCE_TESTS.md
```

Run tests 4-5 manually:
- After any change to `inject-rules.sh`
- After adding new presets
- After changing hooks.json
