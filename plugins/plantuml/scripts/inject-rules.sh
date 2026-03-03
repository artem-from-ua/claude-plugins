#!/bin/bash
# SessionStart hook: inject PlantUML formatting rules into Claude's context.
# Outputs ~200 tokens of critical rules so Claude always knows the 2-part format.
# The full diagram type catalog is available on-demand via the plantuml-diagram-guide skill.

# Resolve plugin root path (works both as hook and standalone)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cat <<RULES
## PlantUML Diagrams in Markdown — Base Rules

Every PlantUML diagram MUST have two parts, in this order:

1. A fenced code block with the \`plantuml\` language tag containing the raw source
2. Immediately below it (after a blank line), a Markdown image link pointing to the rendered diagram on plantuml.com

Example:
\`\`\`plantuml
@startuml
hide footbox
title Greeting Sequence
skinparam participantBackgroundColor #E8F4FD
skinparam participantBorderColor #7FB3D8
Alice -[#5B9BD5]> Bob: Hello
Bob -[#70AD47]-> Alice: Hi there!
@enduml
\`\`\`

![Sequence Diagram](https://www.plantuml.com/plantuml/svg/<encoded>)

Proactive usage:
- When creating or updating \`.md\` documentation files, proactively add PlantUML diagrams to illustrate architecture, sequences, state machines, data flow, and component relationships.
- When explaining architecture or flows in the terminal, determine diagram type first, then use one of two rendering paths:

  **ASCII-friendly types** (sequence, activity, state, class, component, object, usecase):
  1. Create the PlantUML source code
  2. Encode it: \`encoded=\$(echo "\$source" | python3 ${PLUGIN_ROOT}/scripts/plantuml-encode.py --encode-only)\`
  3. Fetch ASCII output via WebFetch from: \`https://www.plantuml.com/plantuml/txt/<encoded>\`
  4. Display the rendered ASCII diagram
  5. After the ASCII diagram, show a clickable SVG link: \`[View SVG diagram](https://www.plantuml.com/plantuml/svg/<encoded>)\`
  6. If WebFetch fails: retry once with simpler diagram
  7. If both attempts fail: inform user PlantUML API unavailable, then generate ASCII diagram yourself using box-drawing characters (as fallback only)

  **Link-only types** (timing, gantt, mindmap, WBS, wireframe, network, JSON, YAML, ER, deployment):
  1. Create the PlantUML source code
  2. Show source in a fenced \`plantuml\` code block
  3. Encode it: \`encoded=\$(echo "\$source" | python3 ${PLUGIN_ROOT}/scripts/plantuml-encode.py --encode-only)\`
  4. Show a clickable SVG link: \`[View SVG diagram](https://www.plantuml.com/plantuml/svg/<encoded>)\`

  Do NOT paste raw PlantUML source without a code block. Do NOT manually draw ASCII if PlantUML API is available.
- **ALWAYS invoke the \`plantuml-diagram-guide\` skill BEFORE creating any PlantUML diagram** to choose the correct diagram type. This is MANDATORY — do not skip this step even if you think you know which type to use.

Rules:
- Every PlantUML diagram MUST include a \`title\` directive after the opening tag (@startuml, @startjson, etc.). The title should be a short, descriptive name of the diagram.
- When appropriate, use color coding in diagrams (skinparam, colored arrows, group backgrounds) with a muted pastel palette on white background (default). Do NOT change backgroundColor unless the user requests it. Add a \`legend\` block when colors encode specific meaning (e.g., blue = external service, red = error path). Does NOT apply to JSON, YAML, or Wireframe (Salt) diagrams.
- Always keep both parts in sync. When you modify PlantUML source, the PostToolUse hook auto-updates the image URL.
- Use SVG format (\`/svg/\` path) unless PNG is specifically requested.
- The alt text in the image link should be a short description of the diagram.
- Place a blank line between the closing \`\`\` and the image link.
- For sequence diagrams with ≤ 10 arrows (fits on screen without scrolling), add \`hide footbox\` immediately after \`@startuml\` to suppress the repeated participant row at the bottom. For longer diagrams (> 10 arrows), omit \`hide footbox\` — the footer aids navigation.
RULES
