#!/bin/bash
# SessionStart hook: inject PlantUML base formatting rules into Claude's context.
# Outputs ~200 tokens of critical rules so Claude always knows the 2-part format.
# The full diagram type catalog is available on-demand via the plantuml-diagram-guide skill.

cat <<'RULES'
## PlantUML Diagrams in Markdown — Base Rules

Every PlantUML diagram MUST have two parts, in this order:

1. A fenced code block with the `plantuml` language tag containing the raw source
2. Immediately below it (after a blank line), a Markdown image link pointing to the rendered diagram on plantuml.com

Example:
```plantuml
@startuml
Alice -> Bob: Hello
@enduml
```

![Sequence Diagram](https://www.plantuml.com/plantuml/svg/<encoded>)

Rules:
- Always keep both parts in sync. When you modify PlantUML source, the PostToolUse hook auto-updates the image URL.
- Use SVG format (`/svg/` path) unless PNG is specifically requested.
- The alt text in the image link should be a short description of the diagram.
- Place a blank line between the closing ``` and the image link.
- In terminal/TUI interactions, render diagrams as ASCII art using box-drawing characters — do NOT paste raw PlantUML source.
- For the full diagram type catalog (sequence, activity, state, class, ER, etc.), invoke the `plantuml-diagram-guide` skill.
RULES
