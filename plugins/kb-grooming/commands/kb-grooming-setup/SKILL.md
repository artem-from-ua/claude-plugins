---
name: kb-grooming-setup
description: >
  Interactive setup wizard for kb-grooming plugin. Creates or updates
  configuration for documentation health checks: model, scope, checks,
  output options, and GitHub integration.
  Keywords: kb-grooming setup, configure doc checks, documentation audit config.
---

# KB Grooming Setup

Configure documentation health analysis for your project.

## Steps

### 1. Show current configuration

Check both config locations and display current state:
- Project (`.claude-plugin/kb-grooming.json` in repo root): show enabled checks and scope
- Global (`~/.claude/kb-grooming.json`): show enabled checks and scope
- If neither exists, say "No configuration found. Let's create one."

### 2. Model selection

Use `AskUserQuestion`:
- **Sonnet (Recommended)** — Best balance of quality and speed for documentation analysis
- **Haiku** — Faster and cheaper, good for large codebases
- **Inherit** — Use the same model as the parent session

### 3. Scope — include patterns

Use `AskUserQuestion` with `multiSelect: true`:
- **README.md** — Root README file
- **CLAUDE.md** — Claude Code instructions
- **docs/** — Documentation directory
- **\*.md** — All markdown files in project

Question: "Which documentation areas should be analyzed?"

All options selected by default (or pre-selected from existing config).

### 4. Scope — exclude patterns

Use `AskUserQuestion` with `multiSelect: true`:
- **node_modules/** — Node.js dependencies
- **vendor/** — Vendored dependencies
- **dist/** — Build output
- **build/** — Build output

Question: "Which directories should be excluded from analysis?"

Pre-select from existing config or default all.

### 5. Checks to enable

Use `AskUserQuestion` with `multiSelect: true`. List all 9 checks with descriptions:
- **brokenLinks** — Find broken internal documentation links
- **orphanDocs** — Find markdown files with no incoming references
- **duplicateContent** — Detect similar content across files
- **claudemdOverflow** — Warn if CLAUDE.md exceeds recommended size
- **mandatoryDocs** — Check for required files (README.md, CLAUDE.md)
- **readmeCompliance** — Validate README structure and content quality
- **terminologyConsistency** — Find inconsistent naming across docs
- **adrCompleteness** — Validate ADR document structure
- **contentActuality** — Find outdated dates, versions, and TODO markers

Question: "Which documentation checks should be enabled?"

Header: "Checks"

### 6. Output options

Use `AskUserQuestion` with `multiSelect: true`:
- **GitHub issues** — Create GitHub epic with linked issues for findings
- **Report file** — Save full report to docs/audit/

Question: "Which output options should be enabled?"

### 7. GitHub integration (conditional)

Only ask if "GitHub issues" was enabled in step 6.

Detect current user: `gh api user -q .login` (skip if `gh` not available).

Use `AskUserQuestion`:
- **Default labels** (`documentation, kb-grooming`) — Use standard labels
- **Custom labels** — Specify custom label set

If custom: ask for comma-separated label list.

Ask about assignee:
- **Auto-assign to me** (`<detected_login>`) — Assign issues to current user
- **No assignee** — Leave unassigned

### 8. Config level

Use `AskUserQuestion`:
- **Project** (`.claude-plugin/kb-grooming.json`) — Committed to git, applies to this project only
- **Global** (`~/.claude/kb-grooming.json`) — Applies to all projects by default

### 9. Write config

Assemble the JSON config from all selections and write to the chosen location.

Display:
- Config file path written
- Summary of enabled checks (count)
- Model selected
- Reminder: "Run `/kb-groom` to analyze your documentation."
