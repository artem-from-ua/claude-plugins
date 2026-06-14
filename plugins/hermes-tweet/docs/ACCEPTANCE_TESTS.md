# Hermes Tweet Acceptance Tests

## Purpose

The hermes-tweet plugin guides Hermes Agent X/Twitter workflows while keeping endpoint discovery read-first and account-changing actions approval-gated.

## Test Execution Order

1. Static checks
2. Skill behavior review
3. Manual Hermes runtime validation

## Automation Status

- Fully automated: Test 1
- Manual only: Tests 2-3

---

## 1. Static Checks

**Objective:** Validate plugin structure and metadata.

**Automation:** Yes

**Steps:**

```bash
PLUGIN="plugins/hermes-tweet"

jq -e '.name == "hermes-tweet"' "$PLUGIN/.claude-plugin/plugin.json"
jq -e '.version == "0.1.0"' "$PLUGIN/.claude-plugin/plugin.json"
jq -e '.skills[0] == "./skills/"' "$PLUGIN/.claude-plugin/plugin.json"
test -f "$PLUGIN/skills/hermes-tweet/SKILL.md"
head -1 "$PLUGIN/skills/hermes-tweet/SKILL.md" | grep -q '^---'
```

**Expected result:**
- `plugin.json` parses successfully
- `skills` points to `./skills/`
- `SKILL.md` exists and starts with YAML frontmatter

---

## 2. Skill Behavior Review

**Objective:** Verify the skill preserves read-first and approval-gated behavior.

**Automation:** Manual

**Steps:**

1. Read `plugins/hermes-tweet/skills/hermes-tweet/SKILL.md`.
2. Confirm `tweet_explore` is the first step for endpoint discovery.
3. Confirm `tweet_read` requires a known read endpoint.
4. Confirm `tweet_action` requires enabled actions and user approval.
5. Confirm secret handling says not to request key values in chat.

**Expected result:**
- The workflow never guesses endpoint paths.
- Account-changing actions require an explicit approval step.
- `XQUIK_API_KEY` remains in the Hermes runtime environment.

---

## 3. Manual Hermes Runtime Validation

**Objective:** Verify the guidance matches upstream Hermes Tweet runtime behavior.

**Automation:** Manual

**Steps:**

1. Install and enable the upstream `hermes-tweet` Hermes Agent plugin.
2. Run `hermes plugins list` and confirm `hermes-tweet` is enabled.
3. Run `hermes tools list` and confirm `tweet_explore` is available.
4. Configure `XQUIK_API_KEY` in the Hermes runtime and confirm `tweet_read` is available.
5. Leave `HERMES_TWEET_ENABLE_ACTIONS` unset or false and confirm `tweet_action` is hidden or disabled.
6. Set `HERMES_TWEET_ENABLE_ACTIONS=true` only in a test runtime and confirm `tweet_action` appears.

**Expected result:**
- `tweet_explore` is available without the API key.
- `tweet_read` is available only with `XQUIK_API_KEY`.
- `tweet_action` remains gated unless actions are explicitly enabled.
