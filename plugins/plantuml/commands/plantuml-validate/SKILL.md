---
name: plantuml-validate
description: >
  Validate that all PlantUML diagram URLs and Mermaid syntax in markdown files
  are correct. Reports missing/stale PlantUML URLs and invalid Mermaid blocks,
  then offers auto-fix for PlantUML issues.
compatibility: Requires Python 3.x
---

# Diagram Validate

Validate that all PlantUML diagram URLs are in sync with their source blocks, and that all Mermaid blocks have valid syntax.

## Instructions

1. Find all `.md` files in the project that contain diagram code blocks:
   ```bash
   grep -rlE '```(plantuml|mermaid)' . --include='*.md'
   ```

2. Run the validation check on all found files:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/plantuml-encode.py" --check <files>
   ```
   `CLAUDE_PLUGIN_ROOT` is set automatically by Claude Code when running plugin commands.

3. Report results to the user:
   - If all diagrams are valid: confirm success with file count
   - If issues found: list each issue with file, line number, and type:
     - PlantUML: missing URL or stale URL
     - Mermaid: unrecognized diagram type or empty block
   - Offer to auto-fix PlantUML issues by running `--sync` on affected files
   - Mermaid issues require manual correction (fix the diagram type keyword)

4. If the user confirms auto-fix for PlantUML, run:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/plantuml-encode.py" --sync <affected-files>
   ```
