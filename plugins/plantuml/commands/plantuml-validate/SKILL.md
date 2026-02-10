---
name: plantuml-validate
description: >
  Validate that all PlantUML diagram URLs in markdown files match their
  source blocks. Reports missing or stale URLs and offers auto-fix.
compatibility: Requires Python 3.x
---

# PlantUML Validate

Validate that all PlantUML diagram URLs in markdown files are in sync with their source blocks.

## Instructions

1. Find all `.md` files in the project that contain PlantUML code blocks:
   ```bash
   grep -rl '```plantuml' . --include='*.md'
   ```

2. Run the validation check on all found files:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/plantuml-encode.py" --check <files>
   ```
   `CLAUDE_PLUGIN_ROOT` is set automatically by Claude Code when running plugin commands.

3. Report results to the user:
   - If all diagrams are in sync: confirm success with file count
   - If mismatches found: list each issue with file, line number, and type (missing URL vs stale URL)
   - Offer to auto-fix by running `--sync` on affected files

4. If the user confirms auto-fix, run:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/plantuml-encode.py" --sync <affected-files>
   ```
