#!/bin/bash
# SessionStart hook: inject Mermaid formatting rules into Claude's context.
# The full diagram type catalog is available on-demand via the mermaid-diagram-guide skill.

cat <<'RULES'
## Mermaid Diagrams in Markdown — Base Rules

Mermaid diagrams render natively in GitHub, Obsidian, VS Code, and most modern markdown viewers. No image URL is needed — just a fenced `mermaid` code block.

Format:
- A fenced ```mermaid code block with the diagram source. Nothing else.
- Do NOT add an image link after the block (unlike PlantUML).

Proactive usage:
- When creating/updating `.md` docs, proactively add Mermaid diagrams for flowcharts, sequences, state machines, class relationships, ER schemas, and gantt timelines.
- Prefer Mermaid for: GitHub/Obsidian-bound docs, simple flowcharts, quick sequences, lightweight ERD. Default choice for most `.md` documentation.
- Prefer PlantUML (if installed) for: complex UML (timing, deployment, nwdiag, wireframes), component diagrams with nested packages, diagrams requiring specific styling control.
- Terminal rendering is NOT supported. For in-terminal diagrams, use the PlantUML plugin (ASCII rendering). With Mermaid, write to `.md` and direct the user to view in GitHub/Obsidian/IDE.

Diagram conventions:
- Every diagram MUST include a title where the type supports it: `title: ...` for sequence, class, state; `title ...` for gantt; first-line comment `%% Title: ...` otherwise. Self-documenting diagrams only.
- Every diagram MUST include `accTitle: ...` and `accDescr: ...` where supported (flowchart, sequence, class, state, ER) — screen readers rely on these.
- For flowcharts, use shapes *semantically* (cylinder = storage, hexagon = orchestrator, stadium = actor, rhombus = decision) and apply `linkStyle` colors for meaning (blue = data, orange = control, green = storage, purple = feedback). Define reusable `classDef` entries instead of styling nodes inline.
- Supported types in guide: flowchart, sequence, state, class, ER, gantt. For other Mermaid types (pie, journey, mindmap, timeline, architecture-beta), consult upstream docs at https://mermaid.js.org.
- **ALWAYS invoke the `mermaid-diagram-guide` skill BEFORE creating any Mermaid diagram** to choose the correct diagram type AND review the Styling & Semantics section. This is MANDATORY — do not skip this step even if you think you know which type to use.

Validation:
- The PostToolUse hook validates every `mermaid` block after Write/Edit on `.md` files by POSTing to Kroki (https://kroki.io). Syntax errors are surfaced to stderr (non-blocking).
- Set `MERMAID_KROKI_URL` to point at a self-hosted Kroki instance if public kroki.io is unavailable or rate-limited.
- On network failure, validation is skipped silently (fail-soft).
RULES
