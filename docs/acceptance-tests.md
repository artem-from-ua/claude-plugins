# Acceptance Test Documentation Standard

Every plugin MUST include comprehensive acceptance test documentation at `plugins/<name>/docs/ACCEPTANCE_TESTS.md`. This document serves multiple purposes:
- Pre-release validation checklist
- Regression testing after refactoring
- Onboarding material for new contributors
- CI/CD test specification

---

## Required Sections

### 1. Purpose
Explain what the plugin does and why acceptance tests are critical for this specific plugin.

### 2. Test Execution Order
List test categories in order of execution (static checks → unit tests → integration tests → behavioral tests → end-to-end).

### 3. Automation Status
Clearly mark which tests can be automated and which require manual execution:
- ✅ **Fully automated**: Tests Claude Code can run within a session
- 🟡 **Partially automated**: Tests that work in current session but may need fresh session for full verification
- ⚠️ **Manual only**: Tests requiring human interaction or fresh session setup

### 4. Test Categories
Organize tests by component or functionality:
- **Static checks**: YAML frontmatter, JSON schema validation, file structure
- **Unit tests**: Individual scripts/functions in isolation
- **Integration tests**: Hooks + scripts interaction, tool chain validation
- **Behavioral tests**: Proactive behavior, skill invocation patterns, user experience flows
- **End-to-End**: Complete workflows from user action to final outcome

### 5. Detailed Test Scenarios
For each test, provide:
- **Objective**: What the test verifies
- **Automation status**: Can Claude run this automatically?
- **Steps**: Exact commands or user actions to perform
- **Expected result**: What success looks like (with examples)
- **Acceptance criteria**: Checklist of ✅/❌ conditions
- **Failure modes**: Common issues and troubleshooting (if applicable)

### 6. Manual Test Procedures
For tests requiring manual execution (especially SessionStart hooks, fresh session behavior):
- **Step-by-step instructions** with exact user inputs
- **Expected response** for each step
- **Verification commands** to confirm success
- **Failure mode table** mapping symptoms → root causes → fixes

### 7. Regression Testing Guide
- When to run tests (before release, after refactoring, etc.)
- CI/CD integration instructions
- How to use the document for automated testing (prompt examples)

---

## Template Structure

```markdown
# [Plugin Name] Acceptance Tests

## Purpose
[Why these tests matter for this plugin]

## Test Execution Order
1. Static checks (automated)
2. Unit tests (automated)
3. Integration tests (automated)
4. Behavioral tests (partially automated)
5. End-to-End (automated)

## Automation Status
- ✅ Fully automated: Tests 1-X
- 🟡 Partially automated: Test Y
- ⚠️ Manual only: Test Z

[Optionally include automated test results table if tests were run]

## Test Categories

### 1. [Test Category Name]

**Objective:** [What this verifies]

**Automation:** ✅/🟡/⚠️

**Steps:**
\`\`\`bash
# Use absolute paths — CWD is not guaranteed between Bash tool calls
SCRIPT="/absolute/path/to/plugins/<name>/scripts/my-script.sh"

# Use printf '%s' for JSON — echo interprets \n in zsh
printf '%s' '{"tool_input":{"command":"git checkout -b feature/foo"}}' | bash "$SCRIPT"

# Use git -C instead of cd
git -C /tmp/test-repo init -q

# Use env for environment variable injection
env CLAUDE_PROJECT_DIR=/tmp/test-repo bash "$SCRIPT"
\`\`\`

**Expected result:**
- ✅ [Success criterion 1]
- ✅ [Success criterion 2]

**Acceptance criteria:**
- ✅ [Condition 1]
- ✅ [Condition 2]

[If manual test, include detailed procedure with steps 1-N]

---

[Repeat for each test category]

## Regression Testing Guide
[When and how to use this document]
```

---

## Writing Guidelines

- **Be specific**: Include exact commands, expected outputs, and file paths
- **Show examples**: Use code blocks with real expected output
- **Mark automation**: Every test should have an automation status marker
- **Provide troubleshooting**: For manual tests, include failure mode tables
- **Include results**: If tests were run during development, include results table
- **Use tables**: For comparison data (scenarios, pass/fail, automation status)
- **Reference real files**: Link to actual plugin files in examples

---

## Shell Command Patterns for Bash Tool Compatibility

Tests in `ACCEPTANCE_TESTS.md` are run by Claude Code's Bash tool (zsh on macOS). Follow these patterns to avoid common failures:

| Problem | Wrong | Correct |
|---------|-------|---------|
| CWD not preserved between calls | `SCRIPT="plugins/foo/scripts/bar.sh"` | `SCRIPT="/absolute/path/to/bar.sh"` |
| `echo` interprets `\n` in zsh | `echo '{"cmd":"git commit -m \"msg\""}'` | `printf '%s' '{"cmd":"git commit -m \"msg\""}'` |
| `cd` state lost between Bash calls | `cd /tmp/repo && git status` | `git -C /tmp/repo status` |
| Inline env var scoping | `CLAUDE_PROJECT_DIR=/tmp bash "$SCRIPT"` | `env CLAUDE_PROJECT_DIR=/tmp bash "$SCRIPT"` |

**Rules:**
- ALWAYS use absolute paths for scripts referenced in test steps
- ALWAYS use `printf '%s'` (not `echo`) when passing JSON to hook scripts
- ALWAYS use `git -C /path` instead of `cd /path && git`
- ALWAYS use `env VAR=val cmd` for environment variable injection
- NEVER rely on CWD being set correctly — each Bash tool call may start from project root

---

## Testing SessionStart Hooks and Proactive Behavior

**Critical insight from [issue #28](https://github.com/Tribe-Coding/claude-plugins/issues/28):** SessionStart hooks that inject MANDATORY instructions work correctly, but testing them requires understanding environmental failure modes.

### Test Design Recommendations

1. **Always test in fresh sessions** — SessionStart hooks only execute on session start. Tests within an existing session are invalid for verifying hook behavior.

2. **Test across multiple models** — Different models (Opus 4.6, Sonnet 4.5) may have different compliance levels with MANDATORY instructions. Test on at least two models.

3. **Document environmental failure modes** — Not all test failures indicate bugs. Common environmental causes:
   - **API timeouts** (32K token limit) — Claude may skip "optional" steps to finish before timeout
   - **SessionStart race conditions** (upstream [#10997](https://github.com/anthropics/claude-code/issues/10997), [#19491](https://github.com/anthropics/claude-code/issues/19491)) — Hooks may execute before plugins fully load
   - **Plugin not loaded** — Restart Claude Code

4. **Provide mitigation steps** — For each failure mode, document workarounds:
   ```markdown
   **Known failure modes:**

   If skill does NOT invoke in your test:

   1. **API timeout** — Set `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`
   2. **Race condition** — Run `/clear` to restart session
   3. **Plugin not loaded** — Verify with `/skills | grep plugin-name`
   ```

5. **Include test result matrix** — Show actual test runs with different conditions:

   ```markdown
   | Test | Model | Skill invoked? | Duration | Notes |
   |------|-------|----------------|----------|-------|
   | Test 1 | Sonnet 4.5 | ❌ No | 4m 33s | API timeout (32K limit) |
   | Test 2 (retry) | Sonnet 4.5 | ✅ Yes | 35s | Fresh session |
   | Test 3 | Opus 4.6 | ✅ Yes | 32s | Fresh session |
   ```

6. **Test both positive and negative cases** — Verify MANDATORY instructions are followed (positive) and verify they don't trigger when inappropriate (negative):
   - Positive: "create docs/architecture.md" → skill SHOULD invoke
   - Negative: "create a sequence diagram" (type specified) → skill should NOT invoke

7. **Distinguish UI display bugs from functionality bugs** — Skill invocation may work even if not displayed in UI. Test outcomes (e.g., correct diagram type selection) not just UI output.

8. **Provide step-by-step manual test procedures** — For SessionStart tests that MUST be manual:

   ```markdown
   #### Manual Test Procedure (5 steps)

   **Step 1:** Start fresh session
   \`\`\`bash
   mkdir /tmp/test && cd /tmp/test && git init && claude
   \`\`\`

   **Step 2:** Verify rules loaded
   Ask: "What are the rules for [feature X]?"
   Expected: Claude mentions specific rules from SessionStart hook

   **Step 3:** Test proactive behavior
   Ask: "Create docs/example.md with [relevant content]"
   Expected: Claude proactively invokes skill before creating content

   **Step 4:** Verify UI shows invocation
   Expected: See `⏺ Skill(plugin-name:skill-name)` in output

   **Step 5:** Test failure mode recovery
   If skill doesn't invoke: Run `/clear` and retry from Step 3
   ```

9. **Link to upstream issues** — When environmental failures occur due to known Claude Code bugs, link to the relevant issues so readers understand it's not a plugin problem:
   - SessionStart race conditions: [#10997](https://github.com/anthropics/claude-code/issues/10997), [#19491](https://github.com/anthropics/claude-code/issues/19491)
   - Plugin skills visibility: [#15178](https://github.com/anthropics/claude-code/issues/15178)
   - CLAUDE.md compliance: [#18454](https://github.com/anthropics/claude-code/issues/18454), [#2544](https://github.com/anthropics/claude-code/issues/2544)

10. **Document expected success rate** — Based on community research ([Scott Spence](https://scottspence.com/posts/how-to-make-claude-code-skills-activate-reliably)), different approaches have different success rates:
    - SessionStart MANDATORY instructions: ~90%+ (in fresh sessions without environmental issues)
    - Passive skill descriptions: ~20%
    - Forced evaluation hooks: ~84%

    Set realistic expectations in acceptance tests: "This feature should work in >90% of fresh session tests. Occasional failures due to API timeouts or race conditions are expected and documented below."

### Example

See `plugins/plantuml/docs/ACCEPTANCE_TESTS.md`. This document demonstrates:
- Clear automation status for 11 test categories
- Automated test results table (tests 8.1, 8.2, 8.6, 8.7)
- Detailed 5-step manual procedure for SessionStart verification (test 8.4)
- Failure mode troubleshooting tables
- Mix of bash commands, user prompts, and expected Claude behavior

### When NOT to Automate

- SessionStart hook verification (requires fresh session)
- User interaction flows (keyboard shortcuts, UI responses)
- Cross-machine scenarios (OAuth, credentials, platform differences)
- Time-dependent behavior (cache expiry, rate limits)

For these cases, provide **step-by-step manual procedures** with clear expected outcomes at each step.
