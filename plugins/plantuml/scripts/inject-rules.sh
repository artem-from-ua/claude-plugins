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
- **NEVER print a bare PlantUML URL in conversation.** Every diagram link shown to the user MUST be a Markdown link with short text — \`[diagram 1](https://www.plantuml.com/plantuml/svg/<encoded>)\`, or a name that says what it shows (\`[before](...)\` / \`[after](...)\`). Encoded diagrams routinely run past 500 characters; pasted bare they wrap across lines, are painful to click, and invite copy damage. A Markdown link keeps the encoding on one unbroken line.
- **NEVER retype, reconstruct, or hand-assemble an encoded string.** Copy the encoder's stdout verbatim into the link. Do not rebuild a URL from an earlier message, do not merge a remembered prefix with a fresh tail, and re-run \`--encode-only\` rather than reusing an encoding you are not certain of. A single wrong character silently decodes to a different diagram or to nothing: PlantUML answers with a HUFFMAN/\`~1\` complaint or the wrong diagram type, which reads as a plugin bug and is not one. If a link is reported broken, re-encode the source and diff the two strings character by character before theorizing about the cause.
- **Verify before showing.** Run \`python3 ${PLUGIN_ROOT}/scripts/plantuml-encode.py --verify-url "<url>"\` on every link before putting it in a reply. It decodes the URL locally — no network — and prints the diagram's own title, so a link that decodes to the wrong diagram is caught too. Exit 1 means do not show it.
- The above applies everywhere a diagram is shown — comparisons, samples, one-off illustrations — not only the two render flows above.
- **ALWAYS invoke the \`plantuml-diagram-guide\` skill BEFORE creating any PlantUML diagram** to choose the correct diagram type. This is MANDATORY — do not skip this step even if you think you know which type to use.

Rules:
- Always keep both parts in sync. When you modify PlantUML source, the PostToolUse hook auto-updates the image URL.
- Use SVG format (\`/svg/\` path) unless PNG is specifically requested.
- The alt text in the image link should be a short description of the diagram.
- Place a blank line between the closing \`\`\` and the image link.
- Every diagram MUST set a non-default arrow thickness after \`@startuml\`: \`skinparam sequenceArrowThickness 1.5\` for sequence diagrams, \`skinparam ArrowThickness 1.5\` for activity, state, class, component, object, use case, deployment and ER. Sequence diagrams MUST also include \`skinparam LifeLineBorderColor #C0C0C0\`.
- For sequence diagrams: consult \`references/sequence.md\` (via plantuml-diagram-guide skill) for ACK suppression rules and arrow style conventions.
RULES
