#!/bin/bash
# SessionStart hook: inject diagram formatting rules into Claude's context.
# Outputs compact base rules for both PlantUML and Mermaid formats.
# The full diagram type catalog is available on-demand via the plantuml-diagram-guide skill.

# Resolve plugin root path (works both as hook and standalone)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cat <<RULES
## Diagrams in Markdown — Base Rules

**Format preference:** Use Mermaid when the diagram type supports it (renders natively in GitHub, Obsidian, Excalidraw). Use PlantUML for types Mermaid doesn't support or when you need PlantUML-specific features (advanced styling, deployment, timing, etc.).

### Mermaid format
Mermaid diagrams need only ONE part: a fenced \`mermaid\` code block. No image URL needed — renderers handle it natively.
- In markdown files: write only the \`\`\`mermaid block. Nothing else.
- In terminal/conversation: draw a hand-drawn ASCII approximation directly from the mermaid source. Do NOT call any external API. Do NOT show the raw mermaid source block before the ASCII — show ONLY the ASCII diagram, then a brief note of what it represents.

### PlantUML format
Every PlantUML diagram MUST have two parts, in this order:
1. A fenced \`plantuml\` code block with raw source
2. A blank line, then a Markdown image link to \`https://www.plantuml.com/plantuml/svg/<encoded>\`

- **Encode**: \`encoded=\$(echo "\$source" | python3 ${PLUGIN_ROOT}/scripts/plantuml-encode.py --encode-only)\`
- In terminal: for ASCII-friendly types, fetch via WebFetch from \`https://www.plantuml.com/plantuml/txt/<encoded>\`. For other types, show source + SVG link.
- The PostToolUse hook auto-syncs PlantUML image URLs when you edit .md files.
- Use SVG format (\`/svg/\` path) unless PNG is specifically requested.
- Every sequence diagram MUST include \`skinparam sequenceArrowThickness 1.5\` and \`skinparam LifeLineBorderColor #C0C0C0\` after \`@startuml\`.
- For sequence diagrams: consult \`references/sequence.md\` (via plantuml-diagram-guide skill) for ACK suppression rules and arrow style conventions.

### Shared rules
- **ALWAYS invoke the \`plantuml-diagram-guide\` skill BEFORE creating any diagram** to choose the correct type and format. This is MANDATORY — do not skip this step.
- When creating/updating \`.md\` docs, proactively add diagrams for architecture, sequences, state machines, data flow, and component relationships.
RULES
