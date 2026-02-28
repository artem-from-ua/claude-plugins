---
name: technology-explainer-show
description: >
  Display current technology proficiency configuration.
  Shows all technologies grouped by level, default level, and custom sources.
  Keywords: show proficiency, technology levels, current config.
---

# Technology Explainer Show

Display the current technology proficiency configuration.

## Steps

### 1. Read config

Read `~/.claude/technology-explainer.json`.

If the file doesn't exist, display: "No proficiency config found. Run `/technology-explainer-setup` to create one."

### 2. Display configuration

Format the output as a table:

| Level | Technologies |
|-------|-------------|
| Expert (brief) | linux, mac, ios, shell scripting |
| Intermediate (nuances) | git, docker, k8s |
| Learning (detailed) | terraform, aws, python |

**Default for unlisted:** learning

**Sources:**
- terraform → HashiCorp docs
- python → PEP 8, Google style guide

### 3. Suggest next steps

Mention available commands:
- `/technology-explainer-update <tech> <level>` — change a single technology's level
- `/technology-explainer-update default <level>` — change the default level
- `/technology-explainer-update source <tech> <url>` — add a custom source
- `/technology-explainer-setup` — reconfigure from scratch
