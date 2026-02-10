---
name: statusline-setup
description: >
  Configure the Claude Code custom statusline showing API rate limits,
  context window usage, git branch, and model info.
compatibility: Requires jq and curl. macOS and Linux supported.
---

# Statusline Setup

Configure the Claude Code custom statusline with API rate limits, context window usage, git branch, and model info.

## Instructions

1. Check if `~/.claude/statusline.sh` exists. If not, copy it from the plugin:
   ```bash
   cp "$(dirname "$0")/../../scripts/statusline.sh" ~/.claude/statusline.sh
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
   - 📁 Current directory
   - 🌿 Git branch (yellow when dirty)
   - 🤖 Model name (color-coded: Opus=red, Sonnet=green, Haiku=blue)
   - 📚 Context window usage (yellow ≥60%, red ≥80%)
   - ⏳ 5-hour rate limit with progress bar
   - 📅 7-day rate limit with progress bar

6. Note: The statusline requires `jq` and `curl` to be installed. Check if they're available and warn if not.
