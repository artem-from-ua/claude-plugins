---
name: mermaid-uninstall
description: >
  Remove the Mermaid pre-commit validation hook from the current project.
  Removes only the mermaid marker-delimited section, preserving other hook content.
---

# Mermaid Uninstall

Remove the Mermaid pre-commit hook section from the current project's git hooks.

## Instructions

1. Run the uninstall script:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-hook.sh"
   ```
   `CLAUDE_PLUGIN_ROOT` is set automatically by Claude Code when running plugin commands.

2. Report the result to the user:
   - If the mermaid section was the only content, the hook file is deleted entirely.
   - If other hook sections exist, only the mermaid section is removed and the rest is preserved.
   - If no mermaid section was found, inform the user that nothing needed to be removed.
