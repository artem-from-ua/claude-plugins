#!/bin/bash
# SessionStart hook: inject PlantUML base formatting rules into Claude's context.
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
Alice -> Bob: Hello
@enduml
\`\`\`

![Sequence Diagram](https://www.plantuml.com/plantuml/svg/<encoded>)

Proactive usage:
- When creating or updating \`.md\` documentation files, proactively add PlantUML diagrams to illustrate architecture, sequences, state machines, data flow, and component relationships.
- When explaining architecture or flows in the terminal, use PlantUML's ASCII text renderer. For SMALL diagrams (<10 lines):
  \`\`\`bash
  echo "\$plantuml_source" | bash ${PLUGIN_ROOT}/scripts/render-ascii.sh
  \`\`\`
  For LARGE diagrams (≥10 lines), use Write tool to avoid permission prompts:
  1. Write PlantUML source to /tmp/diagram-\$\$.puml
  2. Run: bash ${PLUGIN_ROOT}/scripts/render-ascii.sh < /tmp/diagram-\$\$.puml
  3. Clean up: rm /tmp/diagram-\$\$.puml (optional, /tmp auto-clears)
  If rendering fails (exit code 1): retry once with simpler diagram. If both attempts fail: inform user PlantUML API unavailable, then generate ASCII diagram yourself using box-drawing characters (as fallback only).
  Do NOT paste raw PlantUML source. Do NOT manually draw ASCII if PlantUML API is available.
- **ALWAYS invoke the \`plantuml-diagram-guide\` skill BEFORE creating any PlantUML diagram** to choose the correct diagram type. This is MANDATORY — do not skip this step even if you think you know which type to use.

Rules:
- Always keep both parts in sync. When you modify PlantUML source, the PostToolUse hook auto-updates the image URL.
- Use SVG format (\`/svg/\` path) unless PNG is specifically requested.
- The alt text in the image link should be a short description of the diagram.
- Place a blank line between the closing \`\`\` and the image link.
RULES
