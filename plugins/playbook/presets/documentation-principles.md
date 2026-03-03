---
name: documentation-principles
description: "Documentation hierarchy, commit checklist, ADR policy, ripple analysis, automation reflection, diagram guidelines"
tags: [docs, commits]
---

<!-- RULES -->
## Documentation — Base Rules

MANDATORY: Documentation is part of the codebase. A change is not complete until docs reflect it.

- After adding, removing, or renaming a module/component → update `docs/architecture.md`
- After changing a public function/method signature or API endpoint → update its entry in `docs/api/`
- After choosing between two viable approaches or deviating from a convention → create `docs/adr/NNNN-title.md` (Context → Decision → Consequences)
- After adding a linter rule, formatter config, naming convention, or toolchain dependency → update `docs/conventions.md`
- After adding or updating any doc → verify all cross-links to/from it are valid
- After modifying any doc → analyze all docs that link to/from it plus project-wide docs (CLAUDE.md, README.md) for required cascading updates — including merging, splitting, or extracting sections
- ALWAYS keep `CLAUDE.md` minimal — build/test commands + links to docs only; details live in `docs/`; user-facing project overview belongs in `README.md`
- When asked to review, audit, or improve documentation → evaluate existing docs against ALL rules in this section before proposing changes
- After fixing a documentation issue → analyze whether the root cause is preventable by adding a rule or automation (preset rule, project `.claude-plugin/` hook, or global `~/.claude/` config)
- NEVER leave `TODO: document this` in code — write the doc now or create a tracked issue
- NEVER duplicate info across docs — single source of truth, link instead
- NEVER use inline comments as a substitute for documentation
- **ALWAYS invoke the `playbook-browse documentation-principles` skill BEFORE writing, restructuring, or reviewing any documentation file** to load full guidelines. This is MANDATORY — do not skip this step even when auditing or planning changes.
<!-- /RULES -->

<!-- REFERENCE -->
## Philosophy

Documentation is not a deliverable — it is part of the codebase. A change is not complete until the docs reflect it.

Project-level `CLAUDE.md` should be **minimal**: build/test commands, project-specific tooling, and links to documentation. Everything else lives in the doc hierarchy and is reachable via those links. This keeps context overhead low while keeping knowledge accessible.

## Hierarchy

Documentation follows a hierarchy rooted at the project `CLAUDE.md`. Every document should be reachable by following links upward from any entry point. The exact structure may vary by project type, stack, and scale — the levels below are a common baseline, not a rigid prescription:

- `CLAUDE.md` (project root) — agent instructions, build/test commands, links to docs below
- `docs/architecture.md` — system-wide structure, component boundaries, data flows
- `docs/conventions.md` — coding standards, naming, patterns, tooling choices
- `docs/adr/NNNN-title.md` — Architecture Decision Records for significant choices
- `docs/api/` — per-module/service API contracts and interfaces
- `docs/<component>/` — component-specific documentation

Adapt the hierarchy to the project. Infrastructure-heavy projects may need `docs/infrastructure/`. Multi-service projects may have per-service subtrees. The principle stays the same: **one coherent tree, navigable from the top**.

## Cross-linking

Cross-links between documents are mandatory. If doc A references a concept explained in doc B — link it explicitly. No dead ends. A reader following links from `CLAUDE.md` should be able to reach any relevant piece of documentation without guessing.

## Ripple analysis

Cross-link verification checks **structural integrity** — do links point to valid targets? Ripple analysis checks **semantic coherence** — does the content across linked documents still tell a consistent story after a change?

When you modify any document, scan all documents that link to or from it (plus project-wide docs like `CLAUDE.md` and `README.md`) for cascading impacts:

| Signal | Action |
|--------|--------|
| Two docs now overlap significantly | Merge into one, redirect the other |
| A section grew beyond the doc's scope | Extract into a dedicated doc, link back |
| A doc shrank to near-empty after changes | Fold remaining content into parent doc |
| A new concept appears with no home | Create a new doc in the appropriate hierarchy level |

**Example:** You add a "Caching" section to `docs/architecture.md`. Ripple analysis reveals `docs/conventions.md` already has caching rules, and `docs/api/users.md` references cache headers. Actions: (1) move caching rules from conventions to the new architecture section, leaving a link; (2) update `docs/api/users.md` to link to the architecture caching section instead of explaining cache behavior inline.

## Automation reflection

After fixing a documentation issue, ask three questions:

1. **Is this a recurring pattern?** Could this same mistake happen again in another doc or project?
2. **Can a rule prevent it?** Would a new bullet in a preset's RULES zone catch this class of issue at authoring time?
3. **Can automation catch it?** Would a hook, linter, or script detect this issue before it reaches a commit?

Match the fix scope to the problem scope:

| Scope | Mechanism | Example |
|-------|-----------|---------|
| Cross-project (universal) | Preset rule in `presets/*.md` | "NEVER duplicate info across docs" |
| Single project | Hook in `.claude-plugin/hooks.json` | Script that checks `docs/` cross-links on commit |
| Personal workflow | Config in `~/.claude/` | Auto-memory reminder for a personal documentation habit |

**When NOT to add automation:**
- The issue was a one-off mistake unlikely to recur
- The rule would be too specific to generalize (applies to exactly one doc)
- The cost of maintaining the automation exceeds the cost of occasional manual fixes

**Example:** You find that three docs reference a renamed API endpoint by its old name. Fix: update all three. Reflection: this is a recurring pattern (renames break references). A project-level pre-commit hook that greps for known renamed identifiers would catch future occurrences → create an issue or implement the hook.

## On every commit

Before finalizing any commit, go through this checklist:

1. Does this change affect system architecture or component boundaries? → update `docs/architecture.md`
2. Does this change introduce, modify or remove a public API, interface, or contract? → update `docs/api/<relevant>.md`
3. Does this change reflect a significant decision (technology choice, pattern adoption, tradeoff made)? → create or update `docs/adr/`
4. Does this change affect how future contributors should write code in this area? → update `docs/conventions.md`
5. Are all cross-links between docs still valid and accurate?

If none of the above apply — explicitly state why in the commit message (`docs: no update needed — isolated internal refactor`).

## ADR policy

Create an ADR when:
- choosing between two or more viable approaches
- deviating from an established convention
- making a decision that would confuse a future contributor without context

ADR format: **Context → Decision → Consequences**. Keep it short. Link to relevant code.

## Diagrams

Visual diagrams help readers understand architecture, data flows, and component relationships at a glance — faster than prose alone.

**When to add diagrams:**
- Architecture docs — system structure, component boundaries, service topology
- API and data flow docs — request lifecycle, event sequences, transformation pipelines
- State machines — lifecycle of resources (e.g., order states, job statuses)
- Decision trees — complex branching logic that is hard to follow as prose
- Component boundaries — what owns what, dependency directions

**When NOT to add diagrams:**
- Trivial docs (changelogs, simple lists, one-sentence explanations)
- When the diagram would just repeat what the adjacent text already says clearly
- When you cannot keep the diagram up to date — a stale diagram misleads more than no diagram

**Tool guidance:**
- If the PlantUML plugin is active in the session, use it (sequence, activity, component, state, class, ER, and more)
- This guideline is tool-agnostic — any diagramming tool that produces a maintained artifact is acceptable

**Placement and maintenance rules:**
- Place the diagram immediately next to the text it illustrates, not in a separate "diagrams" folder
- Treat diagrams as first-class code artifacts — update them in the same commit that changes the thing they depict
- A stale diagram is worse than no diagram: it actively misleads readers

## Forbidden patterns

- Inline comments as a substitute for documentation
- Duplicating information across multiple docs (single source of truth — link instead)
- Leaving `TODO: document this` in code
<!-- /REFERENCE -->
