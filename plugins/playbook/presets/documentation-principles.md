---
name: documentation-principles
description: "Documentation hierarchy, commit checklist, ADR policy, forbidden patterns"
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
- ALWAYS keep `CLAUDE.md` minimal — build/test commands + links to docs only; details live in `docs/`; user-facing project overview belongs in `README.md`
- When asked to review, audit, or improve documentation → evaluate existing docs against ALL rules in this section before proposing changes
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

## Forbidden patterns

- Inline comments as a substitute for documentation
- Duplicating information across multiple docs (single source of truth — link instead)
- Leaving `TODO: document this` in code
<!-- /REFERENCE -->
