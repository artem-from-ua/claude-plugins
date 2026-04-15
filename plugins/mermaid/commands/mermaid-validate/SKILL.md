---
name: mermaid-validate
description: >
  Validate the syntax of all Mermaid diagrams in markdown files across the project
  by submitting each block to Kroki. Reports syntax errors with file and line.
compatibility: Requires Python 3.x and network access to Kroki (https://kroki.io by default).
---

# Mermaid Validate

Validate syntax of all Mermaid diagram blocks in markdown files.

## Instructions

1. Find all `.md` files in the project that contain Mermaid code blocks:
   ```bash
   grep -rl '```mermaid' . --include='*.md'
   ```

2. Run the validator on all found files:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validate-mermaid.py" <files>
   ```
   `CLAUDE_PLUGIN_ROOT` is set automatically by Claude Code when running plugin commands.

3. Report results to the user:
   - If all diagrams are valid: confirm success with file and block count.
   - If syntax errors found: list each issue with file, line, and error message from Kroki.
   - If network was unreachable: mention validation was skipped (fail-soft).

4. If the user wants offline or faster validation, suggest setting `MERMAID_KROKI_URL` to a self-hosted Kroki instance (`docker run -d -p 8000:8000 yuzutech/kroki`).
