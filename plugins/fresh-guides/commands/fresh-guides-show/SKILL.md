---
name: fresh-guides-show
description: >
  Display current fresh-guides watchlist configuration.
  Shows all watched technologies and their doc URLs.
  Keywords: show watchlist, fresh-guides config, current technologies.
---

# Fresh Guides Show

Display the current fast-changing technology watchlist.

## Steps

### 1. Read config

Read both `~/.claude/fresh-guides.json` (global) and `.claude-plugin/fresh-guides.json` (project).

If neither file exists, display: "No watchlist configured. Run `/fresh-guides-setup` to create one."

### 2. Display configuration

If both configs exist, show them separately with labels. Otherwise show the one that exists.

Format the output as a table:

**Scope: Global** (`~/.claude/fresh-guides.json`)

| Technology | Official Docs |
|------------|--------------|
| terraform | developer.hashicorp.com/terraform/docs, github.com/.../releases |

If project config also exists:

**Scope: Project** (`.claude-plugin/fresh-guides.json`)

| Technology | Official Docs |
|------------|--------------|
| aws terraform provider | registry.terraform.io/..., github.com/.../releases |

**Note:** Project entries override global entries with the same name.

### 3. Suggest next steps

Mention available commands:
- `/fresh-guides-update add <name> <url>` — add a technology with a doc URL
- `/fresh-guides-update remove <name>` — remove a technology from watchlist
- `/fresh-guides-update url <name> <url>` — add another URL to an existing technology
- `/fresh-guides-setup` — reconfigure from scratch
