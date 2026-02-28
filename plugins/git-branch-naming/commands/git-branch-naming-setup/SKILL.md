---
name: git-branch-naming-setup
description: >
  Interactive setup wizard for git branch naming conventions.
  Creates or updates .claude-plugin/git-branch-naming.json with project-specific rules.
  Run this command to configure prefixes, ticket patterns, enforcement levels, and protected branches.
  Keywords: setup branch naming, configure conventions, branch config, git naming setup.
---

# Git Branch Naming Setup

Interactive wizard to create or update `.claude-plugin/git-branch-naming.json` for your project.

## What this command does

1. Shows current configuration (if exists)
2. Asks configuration questions via dialog
3. Creates/updates `.claude/git-branch-naming.json`
4. Optionally installs `.githooks/pre-push` hook

## Setup Steps

### Step 1: Check existing config

Read `.claude-plugin/git-branch-naming.json` if it exists (show current values as defaults).
Otherwise use defaults from `${SKILL_DIR}/../../templates/git-branch-naming.json`.

### Step 2: Ask configuration questions

Use `AskUserQuestion` to collect:

**Question 1 — Allowed prefixes** (multiSelect):
- feature, bugfix, hotfix, release, docs, test, chore, refactor ← all selected by default
- Allow "Other" to add custom prefixes

**Question 2 — Ticket number requirement**:
- No ticket required (default)
- JIRA format: `[A-Z]+-\d+` (e.g., `PROJ-123`)
- GitHub issue: `#\d+` (e.g., `#42`)
- Custom pattern (ask for regex)

**Question 3 — Max branch name length**:
- 60 characters (default)
- 80 characters
- 100 characters
- No limit

**Question 4 — Protected branches** (multiSelect):
- main, master, develop ← all selected by default

**Question 5 — Enforcement level** (applies to ALL rules):
- Ask (warn, let user decide) ← default
- Deny (block the command)
- Per-rule (ask for each of: invalid name, protected branch, content mismatch)

**Question 6 — Content mismatch detection**:
- Enable (warn when branch type doesn't match staged/pushed files) ← default
- Disable

**Question 7 — Open PR check** (what happens when branch has an open PR by another author):
- Ask (warn, let user decide) ← default
- Deny (block the command)
- Off (skip check entirely)

**Question 8 — Install pre-push git hook?**:
- Yes, install to `.githooks/pre-push` (requires `git config core.hooksPath .githooks`)
- No

### Step 3: Write config file

Create `.claude-plugin/` directory if needed, then write `.claude-plugin/git-branch-naming.json`:

```json
{
  "prefixes": ["feature", "bugfix", ...],
  "ticketPattern": "",
  "maxLength": 60,
  "protectedBranches": ["main", "master", "develop"],
  "requireKebabCase": true,
  "warnOnContentMismatch": true,
  "checkOpenPR": "ask",
  "enforcement": {
    "invalidName": "ask",
    "protectedBranch": "ask",
    "contentMismatch": "ask"
  }
}
```

### Step 4: Install pre-push hook (if requested)

Copy `${SKILL_DIR}/../../templates/pre-push` to `.githooks/pre-push`, then:
```bash
chmod +x .githooks/pre-push
git config core.hooksPath .githooks
```

### Step 5: Show next steps to user

```
✅ Configuration saved to .claude-plugin/git-branch-naming.json

Next steps:
1. Commit this file: git add .claude-plugin/git-branch-naming.json && git commit -m "chore: add branch naming config"
2. Add plugin to .claude/settings.json: { "enabledPlugins": { "git-branch-naming@tribe-coding": true } }
3. Push to share conventions with your team

Branch naming enforcement is now active in this Claude Code session.
```

## Config Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `prefixes` | string[] | 8 standard prefixes | Allowed branch prefixes |
| `ticketPattern` | string | `""` | Regex for required ticket (empty = not required) |
| `maxLength` | number | `60` | Max branch name length |
| `protectedBranches` | string[] | `["main","master","develop"]` | Branches requiring confirmation to push |
| `requireKebabCase` | boolean | `true` | Enforce kebab-case in description |
| `warnOnContentMismatch` | boolean | `true` | Check files vs branch type on commit/push |
| `checkOpenPR` | `"ask"\|"deny"\|"off"` | `"ask"` | What to do when branch has open PR by another author |
| `enforcement.invalidName` | `"ask"\|"deny"` | `"ask"` | What to do when branch name is invalid |
| `enforcement.protectedBranch` | `"ask"\|"deny"` | `"ask"` | What to do when pushing to protected branch |
| `enforcement.contentMismatch` | `"ask"\|"deny"` | `"ask"` | What to do when content doesn't match branch type |
