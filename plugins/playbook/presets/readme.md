---
name: readme
description: "README as a landing page: 5-second test, audience-aware writing, compact structure, cross-links to docs"
tags: [docs, readme]
---

<!-- RULES -->
## README — Base Rules

MANDATORY: README.md is the project's landing page. First 5 lines MUST answer "what is this?" and "why would I use it?".

- When creating/editing README.md → first 5 lines: project name, one-line description, problem it solves, target audience
- After header block (motto + intro paragraph) → add a nav line as `> [!NOTE]` GitHub Alert. **NEVER include the first H2 section** — it is always visible above the fold. This is a hard rule: do not add it "for completeness", do not add it when there are few sections, do not add it for any reason. Also **exclude GitHub community files** (GitHub surfaces these automatically — see Navigation Line reference section). Include all other H2 sections. Use ` · ` as separator. No "Scroll to:" prefix. Add explicit `<a name="...">` anchor to each emoji heading: `## ⚙️ How it works <a name="how-it-works"></a>`. Then nav links use the explicit anchor: `[⚙️ How it works](#how-it-works)`
- Use emoji in headings (🚀 📦 ⚡ ⚙️) unless user explicitly forbids it
- For tools/CLIs/plugins → lead with a concrete demo (real input → real output), NOT a feature list
- Installation: official method only — no workarounds; merge Quick Start + Installation into one section
- Every install/usage instruction MUST include a copy-pasteable command block — no placeholder-only steps
- When a README section exceeds 20 lines → extract to `docs/<topic>.md` and replace with a one-line summary + link
- README.md MUST NOT exceed 300 lines — if approaching limit, extract detail sections to docs/
- After adding, removing, or renaming a plugin, preset, command, or other component that a README enumerates → update that README's table/list immediately; do NOT leave it out of sync
- When user asks to create/improve README → start with audience interview: who reads this? what's their level?
- When creating a Demo section for a new README → NEVER invent output; ask the user for real demo material first: propose 1–3 concrete actions they could perform (e.g. "run the command", "trigger the hook", "use the slash command") and request a screenshot, terminal output paste, or copy-paste of a real agent dialogue
- NEVER leave outdated examples — if code changed, update or remove them
- **ALWAYS invoke the `playbook-browse readme` skill BEFORE writing, modifying, reviewing, or improving any README** (including when the user refers to it as "readme", "рідмі", "the landing page", or similar). This is MANDATORY — do not skip even when executing a plan or implementing a task that produces a README.
- When shortening a README (removing sections, detail, or full component descriptions) → BEFORE deleting, verify each removed block has a destination (per-component README, `docs/`, `CONTRIBUTING.md`). If no destination exists — create it first, then remove from README. After completing the rewrite, produce a "what went where" summary for the user.
- Do NOT add a standalone License section — a one-line "MIT — see LICENSE" adds no value; readers who care check the `LICENSE` file directly
<!-- /RULES -->

<!-- REFERENCE -->
## Navigation Line

Add a nav line after the header block (tagline + intro paragraph) using a `[!NOTE]` GitHub Alert. **NEVER include the first H2 section** — no exceptions, regardless of how few sections the README has. Also exclude GitHub community files (see table below). Include all other H2 sections. Use ` · ` as separator:

```markdown
> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📋 Sources](#sources) · [⚡ Commands](#commands) · [📦 Installation](#installation)
```

This gives regulars instant access to any section without scrolling. Keep it on one line — no bullets, no numbering, no "Scroll to:" prefix.

**Do NOT include links to GitHub community files** — GitHub surfaces these automatically in the repository sidebar, tab, or right panel, making README links redundant:

| File | Where GitHub shows it |
|------|-----------------------|
| `CONTRIBUTING.md` | Sidebar link + Contributing tab |
| `LICENSE` / `LICENSE.md` | Right panel (license type) |
| `CODE_OF_CONDUCT.md` | Community Standards panel |
| `SECURITY.md` | Security tab |
| `SUPPORT.md` | Community Standards panel |
| `GOVERNANCE.md` | Community Standards panel |

**GitHub anchor rules for emoji headings:** GitHub's anchor generation for emoji headings is unreliable — the resulting anchor depends on the specific emoji and may include leading dashes or other artifacts. The only reliable approach is explicit `<a name>` anchors:

```markdown
## ⚙️ How it works <a name="how-it-works"></a>
## 📋 Sources <a name="sources"></a>
## 📦 Installation <a name="installation"></a>
```

Then nav links reference the explicit anchor name directly:

```markdown
> **Scroll to: [⚙️ How it works](#how-it-works) · [📦 Installation](#installation)**
```

Never rely on GitHub's auto-generated anchors for emoji headings — they differ per emoji and break silently.

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

## Getting Real Demo Material

NEVER invent demo output — fabricated output erodes trust when readers try to reproduce it. Before writing the Demo section, ask the user for real material.

**How to ask:**

1. Propose 1–3 concrete actions that would produce good demo output. Tailor to the tool type:
   - CLI/command: "Run `/<command>` in a fresh session and paste the terminal output"
   - Hook/automation: "Trigger the hook (e.g. edit a file it watches) and share what appeared in the terminal"
   - Agent dialogue: "Copy-paste a real exchange where the plugin did something useful"

2. Specify what format you need:
   - **Screenshot** — best for showing UI, colors, layout (attach as image)
   - **Terminal paste** — best for text output, tables, command sequences (paste as text)
   - **Agent dialogue copy-paste** — best for showing Claude's reasoning + tool calls + result

3. If the user can't provide material right now (tool not yet built, no session recorded), say explicitly: "I'll write a placeholder demo — update it with real output before publishing."

**Example ask:**

> To write the Demo section, I need real output — invented examples erode trust. Could you:
> - Run `/ctx-show` in a fresh Claude Code session, and
> - Paste the summary table that appears in the terminal?
>
> Alternatively, share a screenshot of the output.

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

A memorable one-liner under the H1 helps readers instantly grasp the project's identity. Use a GitHub Alert (`[!TIP]`) with ✨ emoji prefix and bold+italic (`***...***`) for visual emphasis — this renders as a styled callout box on GitHub:

```markdown
# my-tool

> [!TIP]
> ✨ ***Turn raw data into live dashboards in one command.***
```

When creating a README from scratch, propose a tagline to the user and let them decide. Keep it: short (≤10 words), concrete (not generic "powerful/flexible"), action-oriented.

## GitHub Alerts

GitHub renders special blockquote prefixes as styled callout boxes. Use them for high-signal information:

```markdown
> [!NOTE]
> Highlights information that users should take into account.

> [!TIP]
> Optional information to help a user be more successful.

> [!IMPORTANT]
> Crucial information necessary for users to succeed.

> [!WARNING]
> Critical content demanding immediate user attention due to potential risks.

> [!CAUTION]
> Negative potential consequences of an action.
```

Guidelines:
- Use `[!TIP]` for the project motto/tagline (see above)
- Use `[!IMPORTANT]` for critical prerequisites or breaking behavior
- Use `[!WARNING]` for destructive actions or data loss risks
- Do NOT overuse — one or two alerts per README maximum; alert fatigue cancels the effect
- GitHub-only: alerts do not render on npm, PyPI, or plain markdown viewers

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

## Multi-Component README

For projects containing multiple independent components (plugin marketplace, monorepo, library collection):

- Lead with an **index table**: Name (linked to component README) · Short outcome-oriented description
- Do NOT duplicate component detail in the root README — link to per-component READMEs instead
- Demo section is optional for the root README; each component should have its own demo in its own README
- Descriptions in the index table should answer "what does this do for me", not "what hooks does this use"
- Installation: show ONE example command, then "Repeat for each component you want"
- The root README scales to any number of components without growing — detail lives per-component

**Anti-pattern:** listing every hook, command, and skill for every component in a single root table — this creates a reference document, not a landing page.

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
- **Stale enumeration** — README table or list that no longer matches the actual set of components; always update when adding/removing items
- **License section** — a one-line "MIT" section adds no value; readers who care will check the `LICENSE` file; omit it from README
- **Removing without relocating** — deleting content from README without verifying a destination exists (per-component docs, CONTRIBUTING.md, etc.) — content is lost silently
<!-- /REFERENCE -->
