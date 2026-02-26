# Proactive Plugin Behavior

Reference for plugin authors. Explains the three mechanisms for proactive behavior and how to combine them. See also [`docs/AUTHORING.md`](AUTHORING.md) for SKILL.md and preset authoring guidelines.

---

## Three Mechanisms

Plugins should work without explicit user invocation where possible. There are three mechanisms, each suited for a different level of autonomy:

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

---

## Choosing the Right Mechanism

| Need | Mechanism | Context cost |
|------|-----------|--------------|
| Claude must always follow a rule | SessionStart hook | Per-session (fixed) |
| Claude should use a skill when relevant | Skill description trigger | Only the description line |
| Action must happen after every matching tool call | PostToolUse hook | Zero (runs externally) |

When designing a new plugin, combine these layers. Typical setup:
1. SessionStart injects **base rules** (what to always do)
2. Skill descriptions provide **trigger signals** (when to load more context)
3. PostToolUse hooks handle **automatic actions** (no Claude involvement needed)

---

## PlantUML ASCII Rendering (v1.5.6+)

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
