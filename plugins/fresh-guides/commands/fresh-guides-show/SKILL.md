---
name: fresh-guides-show
description: >
  Display current fresh-guides watchlist configuration.
  Shows all watched technologies, their doc URLs, versions, and check mode.
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

| Technology | Official Docs | Version |
|------------|--------------|---------|
| terraform | developer.hashicorp.com/terraform/docs, github.com/.../releases | latest |
| aws-lambda | docs.aws.amazon.com/lambda/ | latest |

**Check mode:** alert-and-verify

If project config also exists:

**Scope: Project** (`.claude-plugin/fresh-guides.json`)

| Technology | Official Docs | Version |
|------------|--------------|---------|
| aws-cdk | docs.aws.amazon.com/cdk/ | latest |

**Note:** Project entries override global entries with the same name.

### 3. Suggest next steps

Mention available commands:
- `/fresh-guides-update add <name> <url>` — add a technology with a doc URL
- `/fresh-guides-update remove <name>` — remove a technology from watchlist
- `/fresh-guides-update url <name> <url>` — add another URL to an existing technology
- `/fresh-guides-update mode <alert-and-verify|alert-only>` — change check mode
- `/fresh-guides-setup` — reconfigure from scratch
