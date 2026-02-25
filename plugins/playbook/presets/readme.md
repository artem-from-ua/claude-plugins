---
name: readme
description: "README as a landing page: 5-second test, audience-aware writing, compact structure, cross-links to docs"
tags: [docs, readme]
---

<!-- RULES -->
## README — Base Rules

MANDATORY: README.md is the project's landing page. First 5 lines MUST answer "what is this?" and "why would I use it?".

- When creating/editing README.md → first 5 lines: project name, one-line description, problem it solves, target audience
- After header block → add a nav line as blockquote: `> **Scroll to: [⚙️ How it works](#how-it-works) · [📦 Installation](#installation)**` — exclude the first section, use ` · ` as separator
- Use emoji in headings (🚀 📦 ⚡ ⚙️) unless user explicitly forbids it
- For tools/CLIs/plugins → lead with a concrete demo (real input → real output), NOT a feature list
- Installation: official method only — no workarounds; merge Quick Start + Installation into one section
- Every install/usage instruction MUST include a copy-pasteable command block — no placeholder-only steps
- When a README section exceeds 20 lines → extract to `docs/<topic>.md` and replace with a one-line summary + link
- README.md MUST NOT exceed 300 lines — if approaching limit, extract detail sections to docs/
- After adding/removing a public API, CLI command, or major feature → remind: "README may need updating"
- When user asks to create/improve README → start with audience interview: who reads this? what's their level?
- NEVER leave outdated examples — if code changed, update or remove them
- **ALWAYS invoke the `playbook-browse readme` skill BEFORE creating or improving any README** to load full guidelines. This is MANDATORY — do not skip this step.
<!-- /RULES -->

<!-- REFERENCE -->
## Navigation Line

Add a nav line as a blockquote after the header block (tagline + intro paragraph). Exclude the first section (usually Demo) — it's already visible. Use ` · ` as separator. Prefix with `Scroll to:` for clarity:

```markdown
> **Scroll to: [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [License](#license)**
```

This gives regulars instant access to any section without scrolling. Keep it on one line — no bullets, no numbering.

## Emoji

Use emoji proactively in README headings and key elements to improve scannability:

```markdown
## 🎬 Demo
## 📦 Installation
## ⚡ Usage
## ⚙️ How it works
```

Emoji make sections visually distinct when scanning a long page. Use them **unless the user explicitly forbids emoji** in their instructions or project conventions.

Guidelines:
- One emoji per heading, placed before the text
- Use universally recognized emoji (🚀 🎬 📦 ⚡ ⚙️ 📝 🔧 📋) — avoid obscure or ambiguous ones
- Do NOT use emoji in body text or table cells — headings only

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

## Demo-First Structure

For tools, CLIs, and plugins: **a demo outperforms a feature list**. Show the tool working — not what it can do.

**Pattern:**
1. One paragraph: what problem this solves
2. A code block showing real interaction: user input → tool output
3. Installation
4. Anything else

**For CLI/TUI tools** — simulate a terminal session using the tool's actual UI markers (prompts, status indicators, tool call outputs). The reader should be able to imagine themselves using it.

**Coherent narrative:** reuse the same example across sections rather than introducing new context each time. If the demo uses a login flow, use the same login flow in the detailed docs, the diagram, and the terminal rendering example.

## Recommended Sections

Adapt to the project — not all sections are needed for every project:

1. **Header** — project name (H1), tagline/motto (blockquote), badges
2. **What & Why** — one paragraph: problem → solution → key benefit
3. **Demo** — for tools/CLIs: real interaction in a code block (see Demo-First Structure)
4. **Installation** — copy-pasteable commands; merge with Quick Start if they overlap
5. **Usage** — concrete examples beyond the demo, covering additional use cases
6. **Documentation** — links to `docs/` for deeper reference
7. **Contributing** — link to `CONTRIBUTING.md` or brief guidelines

Omit sections that don't apply. A 60-line focused README beats a 300-line comprehensive one.

## Platform-Aware Rendering

README renders on a specific platform — design for where it will actually be read.

**GitHub:**
- Use **PNG** for inline images (`/png/` path), not SVG — SVG rendering is inconsistent in some GitHub contexts
- Make item names in tables **clickable links** to their source file or docs: `[`name`](https://github.com/org/repo/blob/main/path/to/file.md)`
- Code blocks render as monospace — use them for terminal simulations, TUI output, and file content previews
- Test images, links, and table formatting by viewing the file on GitHub before merging

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

Also extract sections that are short but cover edge cases, advanced workflows, or non-primary use cases — even if under 20 lines. The trigger is not just length but relevance to the primary reader's goal.

**Requirements:** merge short requirements into the Installation section as a single inline line rather than a separate section:

```markdown
**Requirements:** Python 3.6+
```

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
- **Feature list without demo** — bullet points describing capabilities, no concrete example of use
- **Separate Quick Start + Installation** — redundant sections that duplicate each other; merge them
- **Internal install methods** — workarounds, dev scripts, or unofficial paths that may break for users
- **TODO items** — "TODO: add examples", "Coming soon" — either write it or omit it
- **Screenshots of text** — not searchable, not copyable; use code blocks
- **Entire API reference inline** — use `docs/api/` and link from README
- **Stale examples** — code that no longer works after a refactor
- **Placeholder commands** — `npm install <your-package>` without showing the actual package name
- **Unlinked table items** — listing plugins, modules, or presets by name without linking to their source
- **License section** — a one-line "MIT" section adds no value; readers who care will check the `LICENSE` file; omit it from README
<!-- /REFERENCE -->
