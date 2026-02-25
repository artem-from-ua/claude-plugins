---
name: compact-statusline-setup
description: >
  Configure the compact Claude Code statusline showing API rate limits,
  context window usage, git branch, and model info on a single line.
compatibility: Requires jq and curl. macOS and Linux supported.
---

# Statusline setup (compact)

Configure the compact single-line Claude Code statusline with brightness-coded API usage values.

## Instructions

1. Check if `~/.claude/statusline.sh` exists. If not, copy it from the plugin:
   ```bash
   cp "${SKILL_DIR}/../../scripts/statusline.sh" ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Read the user's `~/.claude/settings.json` to check if `statusLine` is already configured.

3. If `statusLine` is already configured:
   - Show the current configuration
   - Ask if they want to update it

4. If `statusLine` is NOT configured (or user wants to update):
   - Add or update the `statusLine` field in `~/.claude/settings.json`:
     ```json
     {
       "statusLine": {
         "type": "command",
         "command": "~/.claude/statusline.sh"
       }
     }
     ```
   - Preserve all other existing settings in the file

5. Confirm the setup is complete and explain what the statusline shows:

   **Compact statusline:**
   - Single line: `5h 12% ~2h14m   7d 45% ~3d5h   extra $4.79   Sonnet 4.5   context 52%   claude-plugins/   main`
   - Dim labels, brightness-coded values (dim at low usage, brighter as they climb, yellow >90%, red 100%)
   - Branch shown yellow with `*` suffix when dirty
   - Text indicators: `!!` warning at >90%, `XX` exhausted at 100%

6. Note: The statusline requires `jq` and `curl` to be installed. Check if they're available and warn if not.
