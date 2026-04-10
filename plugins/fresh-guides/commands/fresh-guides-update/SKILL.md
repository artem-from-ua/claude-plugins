---
name: fresh-guides-update
description: >
  Quick-update the fresh-guides watchlist. Usage:
  /fresh-guides-update add <name> <url> — add a technology,
  /fresh-guides-update remove <name> — remove a technology,
  /fresh-guides-update url <name> <url> — add URL to existing technology.
  Keywords: update watchlist, add technology, remove technology.
---

# Fresh Guides Update

Quickly update a single aspect of the fresh-guides watchlist.

## Config Resolution

Determine which config file to update:
- If `.claude-plugin/fresh-guides.json` exists → update project config
- Else if `~/.claude/fresh-guides.json` exists → update global config
- Else → create global config from template, then apply update

## Supported Operations

### Add technology

**Usage:** `/fresh-guides-update add <name> <url>`

**Steps:**
1. Read config file.
2. Check if `<name>` already exists in watchlist (case-insensitive). If so, add the URL to its `docs` array instead.
3. If new, append `{ "name": "<name>", "docs": ["<url>"] }` to watchlist.
4. Write the updated config.
5. Confirm: "Added **<name>** to watchlist with doc URL: <url>. Restart session for changes to take effect."

### Remove technology

**Usage:** `/fresh-guides-update remove <name>`

**Steps:**
1. Read config file.
2. Remove the entry matching `<name>` (case-insensitive) from watchlist.
3. Write the updated config.
4. Confirm: "Removed **<name>** from watchlist."
5. If not found: "**<name>** is not on the watchlist."

### Add URL to existing technology

**Usage:** `/fresh-guides-update url <name> <url>`

**Steps:**
1. Read config file.
2. Find the entry matching `<name>` (case-insensitive).
3. Append `<url>` to its `docs` array (skip if already present).
4. Write the updated config.
5. Confirm: "Added doc URL for **<name>**: <url>."
6. If not found: "**<name>** is not on the watchlist. Use `/fresh-guides-update add <name> <url>` to add it."

## Error Handling

- No arguments → show usage examples for all operations
- Config file missing → create from template, then apply update
