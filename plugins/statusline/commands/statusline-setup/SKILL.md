---
name: statusline-setup
description: >
  Configure the Claude Code custom statusline showing API rate limits,
  context window usage, git branch, and model info. Supports three presets:
  classic (progress bars), text (ASCII labels), compact (single-line).
compatibility: Requires jq and curl. macOS and Linux supported.
---

# Statusline setup

Configure the Claude Code custom statusline with API rate limits, context window usage, git branch, and model info.

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

5. Ask the user which preset they'd like using AskUserQuestion:
   - **Classic** (default): Emoji icons + progress bars + percentage + time-to-reset (3 lines)
   - **Text**: Text labels + percentage + time-to-reset only, no emoji, no progress bars (3 lines)
   - **Compact**: Single-line, text-only, color-coded. Dim labels (5H, 7D, MO, ctx) with bright values, no emoji, no progress bars. Most space-efficient option.

6. Write the selected preset to `~/.claude/statusline.json`:
   - If the file doesn't exist, create it:
     ```bash
     echo '{"preset": "classic"}' | jq . > ~/.claude/statusline.json
     ```
   - If the file already exists, merge the preset into it:
     ```bash
     jq '.preset = "text"' ~/.claude/statusline.json > /tmp/sl-cfg-${UID}.json && mv /tmp/sl-cfg-${UID}.json ~/.claude/statusline.json
     ```

7. Confirm the setup is complete and explain what the statusline shows:

   **Classic preset:**
   - Line 1: 5h rate limit (progress bar + percentage + time-to-reset), model, context%
   - Line 2: 7d rate limit (progress bar + percentage + time-to-reset), directory
   - Line 3: Monthly extra usage (progress bar + money spent), git branch

   **Text preset:**
   - Line 1: `5h: 73% resets 2h14m`, model, context%
   - Line 2: `7d: 45% resets 3d5h`, directory
   - Line 3: `1M: money spent`, git branch

   **Compact preset:**
   - Single line: `5h 12% ~2h14m   7d 45% ~3d5h   extra $4.79   Sonnet 4.5   context 52%   claude-plugins/   main`
   - Dim labels, brightness-coded values (dim at low usage, brighter as they climb, yellow >90%, red 100%)
   - Branch shown yellow with `*` suffix when dirty

8. Mention that users can further customize by editing `~/.claude/statusline.json`:
   - `"emojis": true/false` - override emoji display independently
   - `"progress_bars": true/false` - override progress bar display independently
   - Example: `{"preset": "text", "emojis": true}` gives emoji icons but no progress bars

9. Note: The statusline requires `jq` and `curl` to be installed. Check if they're available and warn if not.
