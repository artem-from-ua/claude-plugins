---
name: playbook-setup
description: >
  Interactive setup wizard for playbook presets. Creates or updates
  ~/.claude/playbook.json (global) or .claude/playbook.json (project).
  Run this command to choose which coding guideline presets to enable.
  Keywords: playbook setup, configure guidelines, enable presets.
---

# Playbook Setup

Configure which coding guideline presets are active for your sessions.

## Steps

### 1. Scan available presets

Read all `.md` files in `${SKILL_DIR}/../../presets/`. For each file, extract the YAML frontmatter fields `name`, `description`, and `tags`.

### 2. Show current configuration

Check both config files and display current state:
- Global (`~/.claude/playbook.json`): list enabled presets
- Project (`.claude/playbook.json` in repo root): list enabled presets and excludes
- If neither exists, say "No presets configured yet."

### 3. Ask which presets to enable

Use `AskUserQuestion` with `multiSelect: true`. List all available presets with their descriptions. Pre-select any currently enabled presets.

### 4. Ask config level

Use `AskUserQuestion`:
- **Global** (`~/.claude/playbook.json`) — applies to all projects by default
- **Project** (`.claude/playbook.json`) — applies only to this project, committed to git

### 5. Handle excludes (project level only)

If configuring at project level AND global config exists:
- Ask if any global presets should be excluded in this project
- Use `AskUserQuestion` with `multiSelect: true`, listing only the globally enabled presets

### 6. Write config

Write the JSON config file to the chosen location:

```json
{
  "presets": ["preset-name-1", "preset-name-2"],
  "exclude": []
}
```

Omit the `"exclude"` field for global configs or when empty.

### 7. Confirm

Display:
- Config file path written
- List of enabled presets (after merge logic)
- Reminder: "Restart your session or run `/clear` for changes to take effect."
