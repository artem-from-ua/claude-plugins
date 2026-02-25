# Skill & Preset Authoring Guide

Reference for writing SKILL.md files and playbook presets. Read this before creating or reviewing either.

---

## §1. Two-Zone Architecture (Presets)

Every playbook preset has two zones with different loading semantics:

| Zone | Markers | Loaded when | Budget | Purpose |
|------|---------|------------|--------|---------|
| **RULES** | `<!-- RULES -->` … `<!-- /RULES -->` | Every SessionStart | See §2 | Imperative rules Claude always follows |
| **REFERENCE** | `<!-- REFERENCE -->` … `<!-- /REFERENCE -->` | On demand via `/playbook-browse` | ~35–50 lines | Full explanations, examples, rationale |

**Critical constraint:** RULES zone must be **self-contained**. Claude must be able to follow every rule without ever reading the REFERENCE zone. If understanding a rule requires background, either inline a one-line explanation (`— reason here`) or move the rule to REFERENCE and replace it with a stronger, self-sufficient rule.

---

## §2. RULES Zone Budget

| Preset type | Budget | Lines | When to use |
|-------------|--------|-------|-------------|
| **Standard** | ~100–120 tokens | 10–14 | Most presets |
| **Critical** | up to ~200 tokens | up to 20 | Daily-use presets covering a broad domain |

**When to use Critical budget:** If the preset is needed in almost every session (e.g., documentation workflow, git workflow), the cost of an additional ~80 tokens per session is lower than the cost of Claude missing important rules. Use judgment — not every preset deserves the larger budget.

---

## §3. Rule Patterns

### Pattern 1: Constraint

**Best for:** preventing errors, platform guardrails, forbidden actions.

```
Format: NEVER/ALWAYS <specific action> — <one-line reason or alternative>
```

**Good** (from `macos-zsh-quirks`):
```
- NEVER use `echo` for JSON strings — `echo` interprets `\n` in zsh; use `printf '%s'` instead
- NEVER use `/usr/bin/python3` — it is macOS system Python 3.9
```

**Bad:**
```
- Avoid using echo when possible — consider printf for safer output
- Be careful with system Python on macOS
```

Why it works: zero ambiguity. Claude sees the trigger (`echo` + JSON context) and knows the alternative immediately. No judgment call needed.

---

### Pattern 2: Trigger-Action

**Best for:** proactive behavior — Claude acts without being asked.

```
Format: When/After <observable event> → <specific action>
```

**Good** (from `github-workflow`):
```
- After committing on a PR branch → offer to update the PR description
- When creating PR without linked issue → ask user to create one first
```

**Bad:**
```
- Keep PR descriptions up to date
- PRs should have linked issues
```

Why it works: the trigger is an observable event (Claude just committed), not a vague state. Claude knows *when* to act, not just *what* to do in the abstract.

---

### Pattern 3: Diagnostic

**Best for:** error recovery — Claude self-corrects without investigating.

```
Format: <error symptom> → root cause is <X> — fix with <Y>
```

**Good** (from `macos-zsh-quirks`):
```
- Root cause of most "No such file" errors: CWD not set + relative path — fix with absolute paths
```

**Bad:**
```
- File path errors may occur due to various shell environment differences
```

Why it works: maps symptom → fix in one line. Claude pattern-matches the error without needing to investigate.

---

### Pattern 4: Checklist

**Use sparingly.** Checklists are the weakest pattern because each item requires a judgment call ("Did the architecture change?") that Claude must evaluate without clear criteria.

**When unavoidable, decompose into trigger-action pairs instead:**

**Weak:**
```
- Before EVERY commit → run the documentation checklist:
  1. Architecture changed? → update `docs/architecture.md`
  2. API changed? → update `docs/api/`
```

**Strong** (decomposed):
```
- After adding or removing a module → update `docs/architecture.md` component list
- After changing a public function signature → update its entry in `docs/api/`
- After introducing a new architectural pattern → add an ADR in `docs/adr/`
```

The decomposed version provides observable triggers (Claude can detect them mechanically) instead of abstract questions that require judgment.

---

## §4. Anti-Patterns

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| Vague verbs: "consider", "you may", "recommended" | Claude treats as optional, skips under context pressure | Use ALWAYS / NEVER / MUST |
| Abstract goals: "keep docs up to date" | No observable trigger, no specific action | Decompose into trigger-action pairs |
| Judgment without criteria: "if significant change" | Claude cannot evaluate "significant" consistently | Replace with observable conditions |
| `/playbook-browse` as the primary action | Claude rarely self-invokes skills | Make RULES self-contained; browse is a bonus |
| Overly broad triggers: "before every commit" | Becomes noise — most commits don't match | Narrow to specific change types |
| Rules outside Claude's scope: "update the team" | Claude cannot email or message | Scope to actions Claude can actually perform |

---

## §5. SKILL.md Authoring

### Required frontmatter

```yaml
---
name: skill-name          # kebab-case, unique across all plugins
description: >
  One or two sentences describing when and how Claude should use this skill.
---
```

### Description format for auto-invocable skills

Use the combined pattern for maximum effectiveness (~90 tokens):

```yaml
description: >
  Invoked automatically before [action] to [purpose].
  Covers [N] types: [type1], [type2], [type3].
  Do NOT [action] without consulting this [skill].
  Keywords: [phrase1], [phrase2], [phrase3].
```

Lead with "Invoked automatically" or "Use when" — not "Catalog of..." or "Guide for...". Claude uses descriptions as trigger signals.

### Hybrid design

Keep SKILL.md ≤100 lines. It should contain only routing logic, decision trees, and pointers to reference files:

```
skills/<name>/
├── SKILL.md              # ≤100 lines: routing logic, step descriptions
└── references/
    ├── catalog.md        # large lookup tables — read only when needed
    └── examples.md       # code templates
```

Inline a 200-line catalog in SKILL.md only if it is always needed. Otherwise, load files conditionally based on the user's request.

### Dedup rule

NEVER have the same `name:` frontmatter in both `commands/foo/SKILL.md` and `skills/foo/SKILL.md`. Claude Code does not deduplicate — both will appear in `/context`, causing confusion.

---

## §6. REFERENCE Zone Guidelines

**Put here:**
- Full explanations and rationale for RULES zone decisions
- Code examples with WRONG/CORRECT pairs
- Diagnostic tables (symptom → cause → fix)
- Background context that a RULES rule assumes

**Do NOT put here:**
- Rules Claude must follow proactively (those belong in RULES)
- Content that is needed to understand a RULES rule (make RULES self-contained instead)

**Structure:** use `##` headings that match the topics covered in RULES. A reader following from RULES to REFERENCE should find the relevant section immediately.

---

## §7. Quality Checklist

Before submitting a preset or SKILL.md, verify:

1. Every RULES bullet answers: "What exactly does Claude do, and when?"
2. Every trigger is an observable event, not a judgment call
3. Every action is concrete — Claude can execute it without further clarification
4. No RULES rule depends on reading the REFERENCE zone to be understood
5. No vague language: "consider", "may", "recommended", "try to", "when appropriate"
6. RULES zone is within budget (standard: ≤14 lines; critical: ≤20 lines)
7. The preset works correctly if `/playbook-browse` is never invoked

---

## §8. Preset File Template

```markdown
---
name: preset-name
description: "One-line summary of what this preset enforces"
tags: [tag1, tag2]
---

<!-- RULES -->
## Preset Title — Base Rules

MANDATORY: One-sentence scope declaration.

- ALWAYS/NEVER <specific action> — <reason or alternative>
- When/After <observable event> → <specific action>
- <error symptom> → root cause is <X> — fix with <Y>
- For full reference: invoke `/playbook-browse` and select "preset-name"
<!-- /RULES -->

<!-- REFERENCE -->
## Section Title

Full explanation, rationale, code examples.

```bash
# WRONG
...

# CORRECT
...
```

## Common Error Patterns

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| ... | ... | ... |
<!-- /REFERENCE -->
```
