# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A marketplace of reusable Claude Code plugins (`Tribe Coding`). Each plugin lives under `plugins/<name>/` and follows the Claude Code plugin spec. The marketplace manifest is `.claude-plugin/marketplace.json`.

## Plugins

### plantuml
Keeps PlantUML diagram image URLs in sync with their source blocks in markdown files.

Key components:
- `scripts/plantuml-encode.py` — core encoder/validator. Modes: `--sync` (auto-fix), `--check` (CI validation), stdin (encode raw text). Uses zlib deflate + PlantUML's custom base64 alphabet.
- `scripts/sync-plantuml.sh` — PostToolUse hook (runs after every Write/Edit on `.md` files), calls `plantuml-encode.py --sync`
- `scripts/inject-base-rules.sh` — SessionStart hook, outputs ~200 tokens of formatting rules so Claude knows the two-part pattern (code block + image link)
- `scripts/setup-project.sh` — SessionStart hook, installs git pre-commit hook in `.githooks/` and sets `core.hooksPath`
- `templates/pre-commit` — blocks commits when PlantUML URLs are stale
- `templates/plantuml.yml` — GitHub Actions workflow for PR checks
- `skills/plantuml-diagram-guide/` — on-demand skill with full diagram type catalog
- `commands/plantuml-validate/` — user-invocable `/plantuml-validate` command

### statusline
Custom Claude Code statusline showing real-time session info.

Key components:
- `scripts/statusline.sh` — main script, reads JSON from stdin (piped by Claude Code), outputs ANSI-colored status line. Fetches Anthropic OAuth usage API (cached 60s in `/tmp/claude-statusline-usage-cache`), reads OAuth token from macOS Keychain
- `scripts/setup-statusline.sh` — SessionStart hook, copies `statusline.sh` to `~/.claude/statusline.sh`
- `commands/statusline-setup/` — user-invocable `/statusline-setup` command, configures `~/.claude/settings.json`

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
- Use the `plantuml-diagram-guide` skill to choose the right diagram type.
```

**Budget:** Keep injected text minimal. Every token costs context in every session, even when the plugin is irrelevant. Rules only — no catalogs, no examples.

### 2. Skill description — trigger-based suggestion

The `description` field in SKILL.md frontmatter is shown in the skill list at session start. Write it so Claude can decide when to invoke the skill without being asked.

Use for: on-demand reference data, catalogs, guides that are useful in specific situations.

**Guidelines for description:**
- State **when** to use, not just **what** it does: `"Use when choosing which diagram type fits a documentation task"` (good) vs `"Diagram type catalog"` (bad — no trigger signal).
- If the skill has a "When to suggest" table (like `plantuml-diagram-guide`), that logic belongs inside the skill body. The description should summarize the trigger concisely.

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

**Solution:** The standalone `scripts/claude-sync` script runs _before_ Claude Code starts, pulling marketplace repos and rsyncing into cache. Run `scripts/install-sync.sh` to install — it configures PATH and shell alias automatically. See README for details.

## Adding a New Plugin

1. Create `plugins/<name>/` with the structure above
2. Add `.claude-plugin/plugin.json` manifest
3. All SKILL.md files must include YAML frontmatter per the [agentskills.io spec](https://agentskills.io/specification)
4. In hooks.json, use `${CLAUDE_PLUGIN_ROOT}` for script paths (see Hook Scripts Convention)
5. Register in `.claude-plugin/marketplace.json`
6. **Create acceptance test documentation** in `plugins/<name>/docs/ACCEPTANCE_TESTS.md`

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
