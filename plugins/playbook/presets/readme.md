---
name: readme
description: "README as a landing page: 5-second test, audience-aware writing, compact structure, cross-links to docs"
tags: [docs, readme]
---

<!-- RULES -->
## README — Base Rules

MANDATORY: README.md is the project's landing page. First 5 lines MUST answer "what is this?" and "why would I use it?".

- When creating/editing README.md → first 5 lines: project name, one-line description, problem it solves, target audience
- Every install/usage instruction MUST include a copy-pasteable command block — no placeholder-only steps
- When a README section exceeds 20 lines → extract to `docs/<topic>.md` and replace with a one-line summary + link
- README.md MUST NOT exceed 300 lines — if approaching limit, extract detail sections to docs/
- After adding/removing a public API, CLI command, or major feature → remind: "README may need updating"
- When user asks to create/improve README → start with audience interview: who reads this? what's their level?
- NEVER leave outdated examples in README — if code changed, update the example or remove it
- For full reference: invoke `/playbook-browse` and select "readme"
<!-- /RULES -->

<!-- REFERENCE -->
## The 5-Second Test

A visitor landing on your README has 5 seconds to decide: stay or leave. The first screen (without scrolling) must answer:

1. **What is this?** — project name + one-line description
2. **Why would I use it?** — the problem it solves, the value it delivers
3. **Who is it for?** — target audience or use case

If these aren't visible before the fold, the README fails the 5-second test.

## Two Reader Types

Design for two distinct audiences:

| Reader | Goal | What they need |
|--------|------|---------------|
| **Newcomer** | Discovery — "should I use this?" | What, why, quick example, install |
| **Regular** | Navigation — "where's the X reference?" | Fast scanning, clear headings, links to docs |

Structure the README to serve both. Newcomers read top-to-bottom; regulars scan headings.

## Recommended Sections

Adapt to the project — not all sections are needed for every project:

1. **Header** — project name (H1), tagline/motto (blockquote), badges
2. **What & Why** — one paragraph: problem → solution → key benefit
3. **Quick Start** — minimal steps to get something working (copy-pasteable commands)
4. **Installation** — full install instructions if Quick Start is too brief
5. **Usage** — concrete examples covering the most common use cases
6. **Documentation** — links to `docs/` for deeper reference
7. **Contributing** — link to `CONTRIBUTING.md` or brief guidelines
8. **License** — one line

Omit sections that don't apply. A 60-line focused README beats a 300-line comprehensive one.

## Motto / Tagline

A memorable one-liner under the H1 (as a blockquote) helps readers instantly grasp the project's identity:

```markdown
# my-tool

> Turn raw data into live dashboards in one command.
```

When creating a README from scratch, propose a tagline to the user and let them decide. Keep it: short (≤10 words), concrete (not generic "powerful/flexible"), action-oriented.

## Badges

Place immediately after the header. Useful badges: CI status, version, license, platform. Avoid badge overload (>5 badges adds noise).

```markdown
![CI](https://github.com/org/repo/actions/workflows/ci.yml/badge.svg)
![Version](https://img.shields.io/github/v/release/org/repo)
![License](https://img.shields.io/github/license/org/repo)
```

## Diagrams

Add architecture or flow diagrams when:
- The project has multiple components interacting
- The data flow is non-obvious
- Onboarding without a diagram requires reading 3+ files

Use PlantUML (integrate with the plantuml plugin if available).

## Size Guidelines

| Lines | Assessment |
|-------|-----------|
| 60–150 | Ideal for most projects |
| 150–300 | Acceptable for complex tools |
| 300+ | Red flag — extract sections to `docs/` |

A README is a landing page, not a manual. Long sections belong in `docs/`.

## CLAUDE.md ↔ README Relationship

These files serve different readers:

- **README.md** — human readers (developers, users, evaluators)
- **CLAUDE.md** — Claude Code agent instructions (build commands, tooling, doc links)

Both should cross-link each other. README should link to CLAUDE.md only if contributors need to know about agent-specific setup. CLAUDE.md should always link to README.md for project context.

## Audience Interview

When creating a README from scratch, ask:

1. Who is the primary reader? (developer, end-user, ops, both)
2. What's their technical level? (beginner, intermediate, expert)
3. What's the #1 thing they need to do after reading? (install, evaluate, contribute)
4. Is there existing documentation to link to?
5. What's the project's elevator pitch? (one sentence)

Use answers to decide: section order, technical depth, and how much to explain vs. link.

## Anti-Patterns

- **Wall of text** — no headings, no structure, paragraph after paragraph
- **TODO items** — "TODO: add examples", "Coming soon" — either write it or omit it
- **Screenshots of text** — not searchable, not copyable; use code blocks
- **Entire API reference inline** — use `docs/api/` and link from README
- **Stale examples** — code that no longer works after a refactor
- **Placeholder commands** — `npm install <your-package>` without showing the actual package name
<!-- /REFERENCE -->
