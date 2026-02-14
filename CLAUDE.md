# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ CRITICAL: Version Bump Requirement

**BEFORE merging ANY plugin changes to `main`: MUST bump version in `plugins/<name>/.claude-plugin/plugin.json`**

- ANY change to plugin files merged to main (code, docs, config) → version bump REQUIRED
- Semantic versioning: MAJOR.MINOR.PATCH (see [Version Bump Requirements](#version-bump-requirements))
- Commit version bump in feature branch before merging
- **Without version bump, `claude-marketplace-sync` won't update plugin cache**

## What This Is

A marketplace of reusable Claude Code plugins (`Tribe Coding`). Each plugin lives under `plugins/<name>/` and follows the Claude Code plugin spec. The marketplace manifest is `.claude-plugin/marketplace.json`.

## Plugins

### plantuml
Keeps PlantUML diagram image URLs in sync with their source blocks in markdown files. Provides ASCII diagram rendering in terminal without permission prompts.

Key components:
- `scripts/plantuml-encode.py` — core encoder/validator. Modes: `--sync` (auto-fix), `--check` (CI validation), stdin (encode raw text). Uses zlib deflate + PlantUML's custom base64 alphabet.
- `scripts/sync-plantuml.sh` — PostToolUse hook (runs after every Write/Edit on `.md` files), calls `plantuml-encode.py --sync`
- `scripts/inject-base-rules.sh` — SessionStart hook, outputs ~200 tokens of formatting rules. Includes ASCII rendering workflow: encode source → WebFetch from plantuml.com/txt/{encoded} → display diagram.
- `scripts/allow-rendering.sh` — PreToolUse hook, auto-allows PlantUML operations without prompts: encoding commands, /tmp/*.puml file operations (create/delete via Bash or Write tool)
- `scripts/setup-project.sh` — SessionStart hook, installs git pre-commit hook in `.githooks/` and sets `core.hooksPath`
- `templates/pre-commit` — blocks commits when PlantUML URLs are stale
- `templates/plantuml.yml` — GitHub Actions workflow for PR checks
- `skills/plantuml-diagram-guide/` — on-demand skill with full diagram type catalog
- `commands/plantuml-validate/` — user-invocable `/plantuml-validate` command

### statusline
Two-line Claude Code statusline: progress bars (line 1) + session info (line 2). Tracks 5h/7d rate limits, extra usage (monthly billing), context window, git branch, and model. Features warning icons (❌ at 100%, ⚠️ at >90%) and pacing visualization.

**Layout:**
- **Line 1:** ⏳ 5h limit | 📅 7d limit | 💸 extra usage (status icon, progress bar, money spent)
- **Line 2:** 📁 directory | 🌿 branch | 🤖 model | 📚 context%

**Key components:**
- `scripts/statusline.sh` — main script, reads JSON from stdin (piped by Claude Code), outputs two ANSI-colored lines. Fetches Anthropic OAuth usage API (cached 60s in `/tmp/claude-statusline-usage-cache`), reads OAuth token from macOS Keychain or Linux credentials file
- `scripts/setup-statusline.sh` — SessionStart hook, copies `statusline.sh` to `~/.claude/statusline.sh`
- `commands/statusline-setup/` — user-invocable `/statusline-setup` command, configures `~/.claude/settings.json`
- `docs/ACCEPTANCE_TESTS.md` — comprehensive test documentation (8 categories, 17+ tests)

## Plugin Structure Convention

```
plugins/<name>/
├── .claude-plugin/plugin.json    # manifest (name, version, commands, skills, hooks)
├── hooks/hooks.json              # hook definitions (PostToolUse, SessionStart)
├── scripts/                      # shell/python scripts called by hooks
├── commands/<cmd>/SKILL.md       # user-invocable slash commands
├── skills/<skill>/SKILL.md       # on-demand context-efficient skills
├── templates/                    # project templates (pre-commit, CI)
└── docs/
    └── ACCEPTANCE_TESTS.md       # comprehensive test documentation (REQUIRED)
```

## Skills Standard

All SKILL.md files must follow the [agentskills.io specification](https://agentskills.io/specification):
- YAML frontmatter with `name` and `description` is required
- Optional: `compatibility`, `license`, `metadata`
- When creating or editing SKILL.md files, always include valid frontmatter

### Hybrid Skill Design

SKILL.md is loaded entirely into context when the skill is invoked. Keep it **small** — under ~100 lines — containing only the decision logic and orchestration steps. Move bulky reference data (catalogs, examples, templates) into separate files that the skill reads on demand.

**Pattern: routing SKILL.md + external reference files**

```
skills/<name>/
├── SKILL.md              # ≤100 lines: routing logic, step descriptions
└── references/
    ├── catalog.md        # large lookup table, loaded only when needed
    ├── examples.md       # code examples / templates
    └── ...
```

In SKILL.md, instruct Claude to read only the files it needs:

```markdown
## Steps

1. Ask the user which category they need (A, B, or C).
2. Based on the answer, read the matching reference file:
   - A → `references/category-a.md`
   - B → `references/category-b.md`
   - C → `references/category-c.md`
3. Follow the instructions from the loaded file.
```

**Guidelines:**

- **SKILL.md** contains: purpose, decision tree / routing logic, step-by-step orchestration, pointers to reference files. No large data.
- **Reference files** contain: lookup tables, catalogs, examples, templates, verbose instructions. Read via `Read` tool at runtime.
- Use `${SKILL_DIR}` (resolves to the SKILL.md directory) or relative paths from the skill directory to reference sibling files.
- If the skill has a single reference that is always needed, it's fine to keep everything in SKILL.md — the hybrid pattern is for cases where content is large or conditionally needed.

**Anti-patterns:**

- Inlining a 200-line catalog directly in SKILL.md (wastes context on every invocation).
- A SKILL.md that just says "read everything in `references/`" without routing logic (defeats the purpose — Claude loads all files anyway).
- Splitting a 40-line skill into 5 tiny files (unnecessary overhead for small skills).

## Proactive Plugin Behavior

Plugins should work without explicit user invocation where possible. There are three mechanisms for proactive behavior, each suited for a different level of autonomy:

### 1. SessionStart hook — always-on context rules

Inject a short block of rules (~100–200 tokens) into every session via a SessionStart hook. This is the strongest mechanism: Claude sees the rules in its system prompt and follows them automatically.

Use for: formatting conventions, mandatory patterns, "always do X when you see Y" rules.

Example (plantuml `inject-base-rules.sh`):
```
Proactive usage:
- When creating or updating `.md` documentation files, proactively add PlantUML diagrams…
- **ALWAYS invoke the `plantuml-diagram-guide` skill BEFORE creating any PlantUML diagram**.
  This is MANDATORY — do not skip this step even if you think you know which type to use.
```

**Budget:** Keep injected text minimal. Every token costs context in every session, even when the plugin is irrelevant. Rules only — no catalogs, no examples.

**Language:** Use imperative, unambiguous language for critical behavior. Words like "ALWAYS", "MUST", "MANDATORY" enforce strict compliance. Avoid soft language like "consider", "you may", "it's recommended".

### 2. Skill description — trigger-based suggestion

The `description` field in SKILL.md frontmatter is shown in the skill list at session start. Write it so Claude can decide when to invoke the skill without being asked.

Use for: on-demand reference data, catalogs, guides that are useful in specific situations.

**Guidelines for description:**
- State **when** to use, not just **what** it does: `"Use when choosing which diagram type fits a documentation task"` (good) vs `"Diagram type catalog"` (bad — no trigger signal).
- If the skill has a "When to suggest" table (like `plantuml-diagram-guide`), that logic belongs inside the skill body. The description should summarize the trigger concisely.

**Best practices for maximum effectiveness** (based on [testing](https://github.com/Tribe-Coding/claude-plugins/issues/28) and [community research](https://scottspence.com/posts/how-to-make-claude-code-skills-activate-reliably)):

1. **Lead with action state** — Use "Invoked automatically" or "Use when" at the start, not just "Catalog of..." or "Guide for...". This signals when/how the skill activates.

   ```yaml
   # Good
   description: "Invoked automatically before creating PlantUML diagrams to select the correct type."

   # Bad
   description: "Comprehensive catalog of PlantUML diagram types with selection guidance."
   ```

2. **Include specific keywords** — Add common user phrases that should trigger the skill. This improves natural language intent matching.

   ```yaml
   description: >
     Invoked automatically before creating PlantUML diagrams to select the correct type.
     Keywords: diagram type, which diagram, best diagram, choose diagram, UML.
   ```

3. **Add WHEN NOT clause** — Explicitly state when NOT to use the skill. This follows the [Scott Spence best practice](https://scottspence.com/posts/how-to-make-claude-code-skills-activate-reliably) pattern.

   ```yaml
   description: >
     Invoked automatically before creating PlantUML diagrams to select the correct type.
     Do NOT create PlantUML without consulting this guide.
   ```

4. **List concrete examples** — Include specific types/categories the skill covers. This helps Claude match user requests to skills.

   ```yaml
   description: >
     Covers 17 types: sequence, activity, state, class, ER, component, deployment,
     timing, mindmap, gantt, WBS, JSON, YAML, network, object, usecase, wireframe.
   ```

5. **Keep it concise** — Description budget is 2% of context window (~16K chars total for ALL skills). Aim for 60-100 tokens per skill. Use the combined pattern below for maximum effectiveness without bloat.

**Recommended combined pattern** (90 tokens, +30 over minimal):

```yaml
description: >
  Invoked automatically before creating [X] to [purpose].
  Covers [N] types: [type1], [type2], [type3]...
  Do NOT [action] without consulting this [skill].
  Keywords: [phrase1], [phrase2], [phrase3].
```

**Example** (plantuml-diagram-guide):

```yaml
description: >
  Invoked automatically before creating PlantUML diagrams to select the correct type.
  Covers 17 types: sequence, activity, state, class, ER, component, deployment,
  timing, mindmap, gantt, WBS, JSON, YAML, network, object, usecase, wireframe.
  Do NOT create PlantUML without consulting this guide.
  Keywords: diagram type, which diagram, best diagram, choose diagram, UML.
```

**Token cost impact:** +30 tokens (~$0.00009 per session with Sonnet at $0.003/1K input tokens). Negligible cost for measurably better discoverability.

### 3. PostToolUse hook — automatic action

Run a script automatically after specific tool calls (Write, Edit, Bash, etc.) via PostToolUse hooks. This is fully autonomous — no Claude reasoning needed.

Use for: validation, auto-fixing, syncing derived artifacts.

Example (plantuml `sync-plantuml.sh`): runs after every Write/Edit on `.md` files to update diagram URLs.

**Guidelines:**
- Keep hooks fast (timeout ≤30s) and silent on success — noisy output on every edit is distracting.
- Use the `matcher` field to scope to relevant tools (e.g., `"Write|Edit"` not all tools).
- Hooks should be idempotent — running twice produces the same result.

### Choosing the right mechanism

| Need | Mechanism | Context cost |
|------|-----------|--------------|
| Claude must always follow a rule | SessionStart hook | Per-session (fixed) |
| Claude should use a skill when relevant | Skill description trigger | Only the description line |
| Action must happen after every matching tool call | PostToolUse hook | Zero (runs externally) |

When designing a new plugin, combine these layers. Typical setup:
1. SessionStart injects **base rules** (what to always do)
2. Skill descriptions provide **trigger signals** (when to load more context)
3. PostToolUse hooks handle **automatic actions** (no Claude involvement needed)

### PlantUML ASCII Rendering (v1.5.6+)

**Problem solved:** ASCII diagrams in terminal without permission prompts or UI collapse.

**Workflow:**
1. SessionStart hook (inject-base-rules.sh) outputs instructions: encode PlantUML source → WebFetch from `plantuml.com/txt/{encoded}` → display
2. PreToolUse hook (allow-rendering.sh) auto-allows all PlantUML operations without prompts

**Why WebFetch, not Bash:**
- Claude Code UI automatically **collapses all Bash tool results >40-50 lines** ("… +60 lines (ctrl+o to expand)")
- **WebFetch results are NOT collapsed** — full ASCII diagram always visible
- Versions 1.4.0-1.5.5 used Bash commands (regression), 1.5.6+ reverted to WebFetch

**PreToolUse auto-allow patterns:**
- `plantuml-encode.py` (encoding, with or without flags)
- `cat > /tmp/*.puml` (Bash heredoc/redirect for temp files)
- `rm /tmp/*.puml` (cleanup)
- Write tool for `/tmp/*.puml` files

**Security:** Patterns restricted to `/tmp` directory and `.puml` extension only.

**SessionStart path resolution:**
- Script resolves `PLUGIN_ROOT` dynamically: `${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}`
- Outputs absolute paths in heredoc (e.g., `/Users/.../cache/tribe-coding/plantuml/1.5.8/scripts/plantuml-encode.py`)
- Never use `${CLAUDE_PLUGIN_ROOT}` in heredoc text (only works in hooks.json command fields)

## Hook Scripts Convention

In `hooks.json`, always use `${CLAUDE_PLUGIN_ROOT}` to reference plugin files — never `$(dirname "$0")` (it resolves to the shell binary path, not the plugin directory):

```json
{
  "type": "command",
  "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh\""
}
```

Inside scripts, use a fallback so they work both as hooks and when run directly:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
```

## Cross-Platform Compatibility

All scripts must work on both macOS and Linux. Use these patterns:

**Platform detection:**
```bash
if [ "$(uname)" = "Darwin" ]; then
  # macOS
else
  # Linux
fi
```

**`stat` — file modification time:**
- macOS: `stat -f %m "$file"`
- Linux: `stat -c %Y "$file"`

**`date` — parsing ISO timestamps:**
- macOS: `date -juf "%Y-%m-%dT%H:%M:%S" "$str" +%s`
- Linux: `date -ud "$str" +%s`

**OAuth credentials** (priority order):
1. `$CLAUDE_CODE_OAUTH_TOKEN` env var (any platform)
2. macOS Keychain: `security find-generic-password -s "Claude Code-credentials" -w`
3. Linux credentials file: `~/.claude/.credentials.json`

**Shared `/tmp` files:** Always append `-${UID}` to avoid collisions in multi-user environments.

## Plugin Cache Sync

Claude Code has a bug where the plugin cache is not invalidated on auto-update ([#14061](https://github.com/anthropics/claude-code/issues/14061), [#15621](https://github.com/anthropics/claude-code/issues/15621), [#15642](https://github.com/anthropics/claude-code/issues/15642)).

**Solution:** The standalone `scripts/claude-marketplace-sync` script runs _before_ Claude Code starts, pulling marketplace repos and rsyncing into cache. Run `scripts/install-sync.sh` to install — it configures PATH and shell alias automatically. See README for details.

## Adding a New Plugin

1. Create `plugins/<name>/` with the structure above
2. Add `.claude-plugin/plugin.json` manifest with version `0.1.0`
3. All SKILL.md files must include YAML frontmatter per the [agentskills.io spec](https://agentskills.io/specification)
4. In hooks.json, use `${CLAUDE_PLUGIN_ROOT}` for script paths (see Hook Scripts Convention)
5. Register in `.claude-plugin/marketplace.json`
6. **Create acceptance test documentation** in `plugins/<name>/docs/ACCEPTANCE_TESTS.md`

## Version Bump Requirements

**CRITICAL:** Before merging any PR to `main`, you MUST bump the version of affected plugins. This is required for `claude-marketplace-sync` to pick up changes (see Plugin Cache Sync section).

### When to Bump Version

Bump version in `plugins/<name>/.claude-plugin/plugin.json` for ANY change to that plugin:
- Code changes (scripts, hooks, templates)
- Documentation changes (SKILL.md, ACCEPTANCE_TESTS.md)
- Configuration changes (plugin.json, hooks.json)

**Exception:** Changes to root-level files (CLAUDE.md, README.md) or other plugins do NOT require version bump.

### Semantic Versioning Rules

Follow [Semantic Versioning 2.0.0](https://semver.org/):

**MAJOR version (X.0.0)** — Breaking changes:
- Removed features or commands
- Changed command/skill names or signatures
- Incompatible hook behavior changes
- Requires user action to migrate

Examples:
- Renamed skill from `plantuml-validate` to `validate-plantuml` → `1.5.3` to `2.0.0`
- Removed deprecated command → `1.8.2` to `2.0.0`
- Changed hook output format breaking downstream tools → `1.3.1` to `2.0.0`

**MINOR version (x.Y.0)** — New features, backwards-compatible:
- New commands or skills
- New hooks
- New configuration options (with defaults)
- Enhanced functionality that doesn't break existing usage
- Non-breaking behavior changes

Examples:
- Added new diagram type to plantuml-diagram-guide → `1.2.0` to `1.3.0`
- Added `--force` flag to existing command → `1.1.5` to `1.2.0`
- New PostToolUse hook for additional file types → `1.4.2` to `1.5.0`
- Made SessionStart rules more strict (PR #27) → `1.0.0` to `1.1.0`

**PATCH version (x.y.Z)** — Bug fixes, no new features:
- Fixed bugs in existing functionality
- Performance improvements
- Documentation fixes (typos, clarifications)
- Updated acceptance tests without behavior changes
- Refactoring without behavior changes

Examples:
- Fixed encoder crash on empty input → `1.2.3` to `1.2.4`
- Corrected typo in SKILL.md → `1.3.0` to `1.3.1`
- Performance optimization in sync script → `1.1.8` to `1.1.9`
- Updated ACCEPTANCE_TESTS.md to reflect current behavior → `1.2.5` to `1.2.6`

### Version Bump Workflow

1. **Make your changes** in a feature branch
2. **Before merging:** Create a version bump commit:
   ```bash
   # Edit plugins/<name>/.claude-plugin/plugin.json
   # Change "version": "1.2.3" to "1.3.0" (for example)

   git add plugins/<name>/.claude-plugin/plugin.json
   git commit -m "Bump <plugin-name> version to 1.3.0

   Version bump for PR #XX: <description>

   Changes in 1.3.0:
   - <list key changes>

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
   ```

3. **Merge to main** (version bump included)
4. **Sync plugin cache:** Run `claude-marketplace-sync --force` after merge

### Multiple Plugins Changed

If your PR affects multiple plugins, bump ALL of them:

```bash
# PR changed both plantuml and statusline
# Bump both versions in separate commits or one commit

git add plugins/plantuml/.claude-plugin/plugin.json
git add plugins/statusline/.claude-plugin/plugin.json
git commit -m "Bump plugin versions: plantuml 1.2.0, statusline 1.1.0

Version bumps for PR #XX: <description>

plantuml 1.1.5 → 1.2.0:
- <changes>

statusline 1.0.3 → 1.1.0:
- <changes>"
```

### Verification

After version bump:
1. Check `plugin.json` contains new version
2. After merge, run `claude-marketplace-sync --force --verbose`
3. Verify new version appears in `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`
4. Test in fresh Claude Code session

### Why This Matters

Without version bumps, `claude-marketplace-sync` won't update plugin files in cache because it only syncs when version changes. This means:
- ❌ Users won't see your changes (old version still loaded)
- ❌ Manual testing becomes invalid (testing old code)
- ❌ Bug fixes won't reach users

**Always bump versions before merge!**

## Acceptance Test Documentation Standard

Every plugin MUST include comprehensive acceptance test documentation at `plugins/<name>/docs/ACCEPTANCE_TESTS.md`. This document serves multiple purposes:
- Pre-release validation checklist
- Regression testing after refactoring
- Onboarding material for new contributors
- CI/CD test specification

**Required sections:**

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

**Template structure:**

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
```bash
[commands]
```

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

**Guidelines:**

- **Be specific**: Include exact commands, expected outputs, and file paths
- **Show examples**: Use code blocks with real expected output
- **Mark automation**: Every test should have an automation status marker
- **Provide troubleshooting**: For manual tests, include failure mode tables
- **Include results**: If tests were run during development, include results table
- **Use tables**: For comparison data (scenarios, pass/fail, automation status)
- **Reference real files**: Link to actual plugin files in examples

### 8. Testing SessionStart Hooks and Proactive Behavior

**Critical insight from [issue #28](https://github.com/Tribe-Coding/claude-plugins/issues/28):** SessionStart hooks that inject MANDATORY instructions work correctly, but testing them requires understanding environmental failure modes.

**Test design recommendations:**

1. **Always test in fresh sessions** — SessionStart hooks only execute on session start. Tests within an existing session are invalid for verifying hook behavior.

2. **Test across multiple models** — Different models (Opus 4.6, Sonnet 4.5) may have different compliance levels with MANDATORY instructions. Test on at least two models.

3. **Document environmental failure modes** — Not all test failures indicate bugs. Common environmental causes:
   - **API timeouts** (32K token limit) — Claude may skip "optional" steps to finish before timeout
   - **SessionStart race conditions** (upstream [#10997](https://github.com/anthropics/claude-code/issues/10997), [#19491](https://github.com/anthropics/claude-code/issues/19491)) — Hooks may execute before plugins fully load
   - **Plugin cache not synced** — Changes not yet in `~/.claude/plugins/cache/`

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
   ```bash
   mkdir /tmp/test && cd /tmp/test && git init && claude
   ```

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

**Example: See `plugins/plantuml/docs/ACCEPTANCE_TESTS.md`**

This document demonstrates:
- Clear automation status for 11 test categories
- Automated test results table (tests 8.1, 8.2, 8.6, 8.7)
- Detailed 5-step manual procedure for SessionStart verification (test 8.4)
- Failure mode troubleshooting tables
- Mix of bash commands, user prompts, and expected Claude behavior

**When NOT to automate:**

- SessionStart hook verification (requires fresh session)
- User interaction flows (keyboard shortcuts, UI responses)
- Cross-machine scenarios (OAuth, credentials, platform differences)
- Time-dependent behavior (cache expiry, rate limits)

For these cases, provide **step-by-step manual procedures** with clear expected outcomes at each step.

## Dependencies

- plantuml: Python 3.x, git
- statusline: jq, curl, python3; macOS Keychain or ~/.claude/.credentials.json on Linux (for Anthropic OAuth token)
