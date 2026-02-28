---
name: technology-explainer-update
description: >
  Quick-update a single technology's proficiency level, the default level,
  or add a custom source. Usage: /technology-explainer-update <tech> <level>,
  /technology-explainer-update default <level>,
  /technology-explainer-update source <tech> <url>.
  Keywords: update proficiency, change level, add source.
---

# Technology Explainer Update

Quickly update a single aspect of the technology proficiency config.

## Supported Operations

### Update technology level

**Usage:** `/technology-explainer-update <technology> <level>`

Where `<level>` is one of: `expert`, `intermediate`, `learning`.

**Steps:**
1. Read `~/.claude/technology-explainer.json`. If it doesn't exist, create it from the template (empty arrays, `defaultLevel: "learning"`).
2. Remove `<technology>` from all level arrays (expert, intermediate, learning).
3. Add `<technology>` to the specified level array.
4. Write the updated config.
5. Confirm: "Updated **<technology>** → **<level>**. Restart session for changes to take effect."

### Update default level

**Usage:** `/technology-explainer-update default <level>`

**Steps:**
1. Read config (or create from template).
2. Set `defaultLevel` to `<level>`.
3. Write the updated config.
4. Confirm: "Default level set to **<level>**."

### Add custom source

**Usage:** `/technology-explainer-update source <technology> <url-or-reference>`

**Steps:**
1. Read config (or create from template).
2. Append `<url-or-reference>` to `sources.<technology>` array (create if needed).
3. Write the updated config.
4. Confirm: "Added source for **<technology>**: <url-or-reference>."

## Error Handling

- Invalid level → show valid options: `expert`, `intermediate`, `learning`
- No arguments → show usage examples
- Config file missing → create from template, then apply update
