# Proactive Plugin Behavior

Reference for plugin authors. Explains delivery mechanisms for proactive behavior and how to combine them. See also [`docs/AUTHORING.md`](AUTHORING.md) for SKILL.md and preset authoring guidelines.

---

## Three Mechanisms

Plugins should work without explicit user invocation where possible. There are three mechanisms, each suited for a different level of autonomy:

### 1. SessionStart hook — always-on context rules

Inject a short block of rules (~100–200 tokens) into every session via a SessionStart hook. This is the strongest mechanism: Claude sees the rules in its system prompt and follows them automatically.

Use for: formatting conventions, mandatory patterns, "always do X when you see Y" rules.

Example (plantuml `inject-rules.sh`):
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

5. **Keep it concise** — Description budget is 2% of context window (~80K chars with 1M context, though per-skill limits of 60-100 tokens are the practical constraint). Aim for 60-100 tokens per skill. Use the combined pattern below for maximum effectiveness without bloat.

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

## Choosing the Right Delivery Mechanism

### §1 Mechanism Overview

Seven delivery mechanisms, each suited for different autonomy levels and cost profiles:

| Mechanism | What it delivers | Fired by | Per-session cost | Examples |
|-----------|-----------------|----------|-----------------|---------|
| Playbook preset | ~100–150 token RULES block | Playbook SessionStart | RULES zone tokens | `action-over-planning`, `git-safety` |
| Skill description trigger | SKILL.md body on-demand | Claude's skill selection | Description only (~60–100 tokens) | `plantuml-diagram-guide`, `semver-guide` |
| SessionStart hook | Config-dependent rules block | Session init | Hook output tokens (≤300) | `plantuml`, `semver`, `technology-explainer` |
| Event hooks (Pre/Post/other) | Shell script on hook events | Tool matcher or event name | Zero (external) | `plantuml` (PostToolUse sync), `git-branch-naming` (PreToolUse validate) |
| HTTP/Prompt/Agent hook | Webhook POST, LLM judgment, or subagent validation | Hook event + type field | Per-invocation (network/model cost) | External CI notification, content policy check |
| Subagent | Heavy analysis delegated to cheaper model | SKILL.md orchestration | Per-invocation model cost | `kb-grooming` (semantic analysis) |
| Pure script | All logic in bash/python | User-invoked command | Zero | `statusline`, `context` |

See [Available Hook Events](conventions.md#available-hook-events) and [Hook Types](conventions.md#hook-types) for the full list of events and type options.

### §2 Decision Factors

| Factor | Question | Impact on mechanism choice |
|--------|----------|---------------------------|
| Frequency | How often does it fire? | Every session → preset or SessionStart hook. On demand → skill or pure script. |
| Latency | How fast must it respond? | <1s → PreToolUse hook (bash only). <30s → PostToolUse hook. Minutes → subagent. |
| Context pollution | Does output consume context tokens? | High → skill (loaded on demand). Low → SessionStart hook or preset. Zero → Pre/PostToolUse hook or pure script. |
| Data volume | How much data does it process? | <500 tokens → inline. Large datasets → subagent or pure script. |
| Model needs | Does it require LLM reasoning? | No → pure script or Pre/PostToolUse hook. Yes → skill, preset, or subagent. |
| User interaction | Does it need conversational back-and-forth? | Yes → skill (main session). No → subagent or pure script. |

### §3 Decision Tree

Use this branching logic to pick a mechanism:

1. **Does it need to fire without the user asking?**
   - No → **skill** (on-demand reference) or **pure script** (user-invoked command)
   - Yes → continue ↓

2. **Is it a simple rule (≤150 tokens, no config dependency)?**
   - Yes, general → **playbook preset**
   - Yes, but config-dependent → **SessionStart hook**
   - No → continue ↓

3. **Does it react to a specific tool call or event?**
   - Yes, validation (<1s, must block) → **PreToolUse hook** (bash only, no LLM)
   - Yes, sync/transform (<30s) → **PostToolUse hook**
   - Yes, reacts to context compaction → **PostCompact hook** (re-inject lost state)
   - Yes, reacts to worktree/subagent lifecycle → corresponding event hook
   - No → continue ↓

4. **Is it data-heavy, separable work?**
   - Yes → **subagent** (haiku for mechanical tasks, sonnet for semantic analysis)
   - No → reconsider — likely a combination of mechanisms above

**Quick-reference shortcuts:**

| I need to… | Use |
|------------|-----|
| Enforce a coding convention in every session | Playbook preset |
| Inject project-specific rules based on config | SessionStart hook |
| Provide a reference guide Claude loads when relevant | Skill description trigger |
| Validate input before a tool executes | PreToolUse hook |
| Auto-fix artifacts after Write/Edit | PostToolUse hook |
| Run heavy analysis on a codebase | Subagent |
| Display computed data to the user | Pure script |
| Re-inject critical state after context compaction | PostCompact hook |
| Notify external service on events | HTTP hook |
| Validate content requiring LLM judgment | Prompt hook |
| Combine mandatory rules with optional deep reference | SessionStart hook + Skill |

### §4 Cost Profile

| Mechanism | Per-session cost | Per-invocation cost | Notes |
|-----------|-----------------|---------------------|-------|
| Playbook preset | RULES zone tokens (~100–150) | — | Loaded every session via playbook SessionStart |
| Skill description trigger | Description tokens (~60–100) | Full SKILL.md when invoked | On-demand — no cost when unused |
| SessionStart hook | Hook output tokens (≤300) | — | Budget enforced by convention (see [Token Budget](conventions.md#token-budget)) |
| Event hooks (command type) | Zero | Zero (external script) | No context cost; runs outside the model |
| HTTP/Prompt/Agent hook | Zero | Network/model cost per invocation | Use sparingly — adds latency |
| Subagent | Zero | Model cost per invocation | e.g., kb-grooming semantic scan: ~$0.004/invocation with haiku |
| Pure script | Zero | Zero | All logic in bash/python, no model involvement |

Cross-ref: [Token Budget](conventions.md#token-budget) for per-component budgets, [Cache Determinism](conventions.md#cache-determinism) for SessionStart caching rules.

### §5 Subagent Design Guidelines

Plugins that delegate work to subagents MUST make the model configurable. This follows the established pattern from `kb-grooming` and `retroscope`.

**Config convention:**

For single-subagent plugins — one `model` field:
```json
{ "model": "sonnet" }
```

For multi-subagent plugins — named model fields per phase:
```json
{
  "models": {
    "dataCollection": "haiku",
    "analysis": "sonnet",
    "reportGeneration": "haiku"
  }
}
```

Valid values: `"haiku"`, `"sonnet"`, `"opus"`, `"best"`, `"inherit"` (use parent session model).

**Model resolution:** `"best"` resolves to the latest flagship model at runtime — convenient for future-proofing but makes behavior less reproducible across model releases. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable overrides the configured model for all subagents in the session.

Cross-ref: [Subagent Model Configuration](conventions.md#subagent-model-configuration) for the config field convention.

**Setup wizard model question pattern:**

Each subagent's model selection should include a plugin-specific recommendation explaining WHY that model fits the task:

- kb-grooming semantic analysis: "**Sonnet (Recommended)** — Best balance of quality and speed for documentation analysis" / "**Haiku** — Faster and cheaper, good for large codebases"
- retroscope report generation: "**Haiku (Recommended)** — Sufficient for structured summarization, 12x cheaper" / "**Sonnet** — Richer narrative, better for detailed reports"
- Data collection / extraction phases: "**Haiku (Recommended)** — Mechanical task: run scripts, collect JSON, no reasoning needed"
- Semantic judgment phases: "**Sonnet (Recommended)** — Requires nuanced evaluation of content quality and consistency"

**Default model selection rules:**

| Subagent task type | Default model | Rationale |
|-------------------|---------------|-----------|
| Classification, extraction, counting | `haiku` | Mechanical — no reasoning needed |
| Template-based generation (reports, issues) | `haiku` | Structured output from templates |
| Semantic analysis, compliance checking | `sonnet` | Requires nuanced judgment |
| Web research, synthesis | `sonnet` | Needs to evaluate and integrate diverse sources |
| Multi-step reasoning with large context (architecture analysis, security audit) | `opus` | Complex interdependencies, high cost of error |
| Future-proof default (no specific task constraint) | `best` | Always resolves to newest flagship; avoids hardcoding model names |
| User-facing conversational phases | `inherit` | Must match parent session quality |

**When to use opus in subagents:**

Opus is the most expensive model (~15x haiku, ~5x sonnet). Use it only when ALL three conditions are met:
1. The task requires **multi-step reasoning** with complex interdependencies (not just pattern matching)
2. **Error cost is high** — a missed finding is more expensive than the model price difference (security audit, compliance, architecture impact analysis)
3. **The task processes large context** where subtle cross-references matter (50+ files, multi-module dependency chains)

If only conditions 1–2 apply but context is small — sonnet is sufficient. If only condition 3 applies but reasoning is mechanical — haiku with good prompting handles it.

**Anti-pattern:** defaulting subagents to opus "for quality". Subagents lose the main advantage of opus (conversation rapport, iterative refinement with the user). If a task truly needs opus-level reasoning AND user interaction, it belongs in the main session, not a subagent.

**When NOT to use subagents:**

- Analysis input < 500 tokens — overhead exceeds benefit, do inline
- Task requires conversational context from the current session — subagent can't access it
- PreToolUse hooks — subagent latency (2–10s) is unacceptable for validation that blocks tool execution
- The plugin fires on every tool call — per-invocation cost adds up fast

### §6 Reasoning Effort for Subagents

Claude Code supports effort levels that control reasoning depth before generating a response.

**Effort levels:**

| Level | Behavior | Token cost | Latency |
|-------|----------|-----------|---------|
| `low` | Minimal reasoning, pattern-matching | Lowest | Fastest |
| `medium` | Moderate reasoning, handles routine tasks | Medium | Medium |
| `high` | Deep reasoning, handles complex analysis | High | Slower |
| `max` | Unconstrained reasoning (Opus 4.6 only) | Highest | Slowest |

**Plugin config format:**

Single-subagent plugin:
```json
{
  "model": "sonnet",
  "effort": "medium"
}
```

Multi-subagent plugin:
```json
{
  "models": {
    "dataCollection": "haiku",
    "analysis": "sonnet"
  },
  "efforts": {
    "dataCollection": "low",
    "analysis": "high"
  }
}
```

**Default effort recommendations by task type:**

| Subagent task type | Model | Effort | Rationale |
|-------------------|-------|--------|-----------|
| Classification, extraction, counting | `haiku` | `low` | Mechanical — pattern matching, no deep reasoning |
| Template-based generation (reports, issues) | `haiku` | `medium` | Needs some judgment for natural phrasing |
| Linting, format validation | `haiku` | `low` | Rule-based checks, deterministic |
| Documentation analysis, compliance checking | `sonnet` | `high` | Requires nuanced judgment across multiple criteria |
| Web research, synthesis | `sonnet` | `medium` | Needs evaluation but well-structured task |
| Architecture analysis, security audit | `opus` | `high` | Complex interdependencies, high cost of error |
| Multi-step reasoning with ambiguous inputs | `opus` | `max` | Unconstrained reasoning for highest quality |

**Effort + model interaction:**

Effort and model are independent knobs. The model determines *capability ceiling*; effort determines *how much of that ceiling is used*.

| Combination | Result | When to use |
|-------------|--------|-------------|
| `haiku` + `low` | Cheapest, fastest, least capable | Trivial extraction |
| `haiku` + `high` | Diminishing returns — haiku's ceiling is lower | Rarely useful |
| `sonnet` + `low` | Fast with decent capability | Quick summaries |
| `sonnet` + `high` | Best quality-to-cost ratio for most tasks | Default recommendation |
| `opus` + `low` | Wastes opus pricing for shallow work | Avoid |
| `opus` + `max` | Maximum quality, maximum cost | Security audits, architecture |

**Rule of thumb:** Match effort to task complexity, not to model tier. Using `opus` + `low` wastes money; using `haiku` + `max` hits capability ceiling. The sweet spot is usually `sonnet` + `high` or `haiku` + `low`.

**Setup wizard integration:**

When a plugin's setup wizard asks about model selection, also ask about effort:

```
Select reasoning effort for semantic analysis:
  1. Low — faster, cheaper, less thorough
  2. Medium — balanced (Recommended)
  3. High — slower, more thorough
  4. Max — deepest reasoning (Opus only, highest cost)
```

Default to the recommended level from the task-type table above. Show cost/quality trade-off in the option label — users care about both.

### §7 Anti-Patterns

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| SessionStart with heavy output (>300 tokens) | Wastes context in every session, even when irrelevant | Move reference content to a skill; keep SessionStart ≤300 tokens |
| Subagent for <500 token analysis | Subagent overhead (cold start, model call) exceeds benefit | Do analysis inline in the main session |
| PreToolUse hook calling LLM | 2–10s latency blocks tool execution; unacceptable UX | Bash-only validation, <1s |
| Playbook preset for project-specific rules | Presets are global; project config varies per repo | Use SessionStart hook that reads `.claude-plugin/<name>.json` |
| Skill as only mechanism for mandatory behavior | Claude may not invoke the skill voluntarily | Pair with SessionStart mandate: "ALWAYS invoke skill X BEFORE..." |
| Subagent for every common action | Per-invocation cost adds up; most actions don't need a separate model call | Reserve subagents for on-demand, data-heavy analysis |
| Pure script pretending to be a skill | No description trigger — Claude never discovers it automatically | Add proper SKILL.md with description frontmatter |
| Hardcoded subagent model | Users can't optimize cost/quality tradeoff for their use case | Always make model configurable with plugin-specific recommendation |
| Hardcoded subagent effort | Users can't tune cost/quality per-task | Make effort configurable alongside model (see §6) |

### §8 Combining Mechanisms

Most plugins combine multiple mechanisms. Five named patterns:

| Pattern | Mechanisms | Example plugins |
|---------|-----------|-----------------|
| **Enforcement** | SessionStart + Skill + PreToolUse | `semver`, `git-branch-naming` — inject rules, provide guide, validate on action |
| **Automation** | SessionStart + Skill + PreToolUse + PostToolUse | `plantuml` — inject rules, guide type selection, auto-allow rendering, sync URLs (see [PlantUML case study](#plantuml-ascii-rendering-v156) below) |
| **Analysis** | Skill + Pure script + Subagent | `kb-grooming` — user invokes command, scripts collect data, subagent analyzes |
| **Display** | Pure script + Setup command | `statusline`, `context` — compute and display data, setup wizard configures |
| **Rule injection** | SessionStart only | `technology-explainer` — reads config, injects proficiency-adapted rules |

When designing a new plugin, start with the pattern that best matches your use case, then add or remove mechanisms as needed.

---

## PlantUML ASCII Rendering (v1.5.6+)

**Problem solved:** ASCII diagrams in terminal without permission prompts or UI collapse.

**Workflow:**
1. SessionStart hook (inject-rules.sh) outputs instructions: encode PlantUML source → WebFetch from `plantuml.com/txt/{encoded}` → display
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
