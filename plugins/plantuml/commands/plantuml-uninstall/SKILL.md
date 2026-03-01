---
name: plantuml-uninstall
description: >
  Remove the PlantUML pre-commit hook from the current project.
  Removes only the plantuml marker-delimited section, preserving other hook content.
---

# PlantUML Uninstall

Remove the PlantUML pre-commit hook section from the current project's git hooks.

## Instructions

1. Run the uninstall script:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-hook.sh"
   ```
   `CLAUDE_PLUGIN_ROOT` is set automatically by Claude Code when running plugin commands.

2. Report the result to the user:
   - If the plantuml section was the only content, the hook file is deleted entirely
   - If other hook sections exist, only the plantuml section is removed and the rest is preserved
   - If no plantuml section was found, inform the user that nothing needed to be removed
