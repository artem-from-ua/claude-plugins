#!/bin/bash
# SessionStart hook: inject PlantUML formatting rules into Claude's context.
# Outputs compact base rules so Claude always knows the 2-part format.
# The full diagram type catalog is available on-demand via the plantuml-diagram-guide skill.

# Resolve plugin root path (works both as hook and standalone)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cat <<RULES
## PlantUML Diagrams in Markdown — Base Rules

Every PlantUML diagram MUST have two parts, in this order:
1. A fenced \`plantuml\` code block with raw source
2. A blank line, then a Markdown image link to \`https://www.plantuml.com/plantuml/svg/<encoded>\`

Proactive usage:
- When creating/updating \`.md\` docs, proactively add PlantUML diagrams for architecture, sequences, state machines, data flow, and component relationships.
- When explaining in terminal, determine diagram type, then render:
  - **Encode**: \`encoded=\$(echo "\$source" | python3 ${PLUGIN_ROOT}/scripts/plantuml-encode.py --encode-only)\`
  - **ASCII-friendly types** (sequence, activity, state, class, component, object, usecase): fetch ASCII via WebFetch from \`https://www.plantuml.com/plantuml/txt/<encoded>\`, display it, then show \`[View SVG](https://www.plantuml.com/plantuml/svg/<encoded>)\`. On failure: retry once simpler, then fall back to box-drawing ASCII.
  - **Link-only types** (timing, gantt, mindmap, WBS, wireframe, network, JSON, YAML, ER, deployment): show source in fenced \`plantuml\` block + SVG link.
  - Do NOT paste raw source without a code block. Do NOT manually draw ASCII if API is available.
- **ALWAYS invoke the \`plantuml-diagram-guide\` skill BEFORE creating any PlantUML diagram** to choose the correct diagram type. This is MANDATORY — do not skip this step even if you think you know which type to use.

Rules:
- Always keep both parts in sync. When you modify PlantUML source, the PostToolUse hook auto-updates the image URL.
- Use SVG format (\`/svg/\` path) unless PNG is specifically requested.
- The alt text in the image link should be a short description of the diagram.
- Place a blank line between the closing \`\`\` and the image link.
RULES
