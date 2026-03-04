---
name: playbook-browse
description: >
  Browse and read playbook preset guidelines on demand.
  Invoked automatically when full reference is needed for documentation principles,
  GitHub workflow, git safety, debugging, or other configured guidelines.
  Do NOT skip this when RULES zone references it.
  Keywords: guidelines, documentation rules, commit checklist, ADR, PR workflow, playbook,
  debugging, git safety, planning, subagent verification, shell scripting, bash pitfalls,
  find path, strict mode.
---

# Playbook Browse

Display the full reference content of a playbook preset.

## Steps

### 1. Determine which preset to show

If the user or a RULES zone specified a preset name — use it directly.

Otherwise, list all available presets by reading `${CLAUDE_PLUGIN_ROOT}/presets/*.md` and extracting YAML frontmatter (`name`, `description`). Ask the user which one to view.

### 2. Read the preset file

Read `${CLAUDE_PLUGIN_ROOT}/presets/<name>.md`.

### 3. Extract and display REFERENCE zone

Extract the content between `<!-- REFERENCE -->` and `<!-- /REFERENCE -->` markers. Display it to the user as formatted markdown.

If the preset has no REFERENCE zone, display the entire file content (excluding YAML frontmatter and RULES zone).
