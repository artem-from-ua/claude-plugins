---
name: semver-setup
description: >
  Interactive setup wizard for semantic versioning enforcement.
  Creates or updates .claude-plugin/semver.json with version files, trigger strategy, and enforcement rules.
  Run this command to configure SemVer for your project.
  Keywords: setup semver, configure versioning, version config, semver setup, version bump config.
---

# Semver Setup

Configure semantic versioning enforcement for this project.

## Steps

### 1. Detect existing config and version files

Check for existing configuration:
- Read `.claude-plugin/semver.json` if present (use as defaults for all questions)
- Auto-detect common version files in the project root: `package.json`, `pyproject.toml`, `Cargo.toml`, `.claude-plugin/plugin.json`, `version.txt`
- For monorepos: also scan one level deep (e.g., `packages/*/package.json`)

Show the user what was found.

### 2. Ask: which version files to track

Use `AskUserQuestion` with `multiSelect: true`. List detected files with descriptions:
- `package.json` — npm/Node.js projects
- `pyproject.toml` — Python projects (field: `project.version` or `tool.poetry.version`)
- `Cargo.toml` — Rust projects (field: `package.version`)
- `.claude-plugin/plugin.json` — Claude Code plugins (field: `version`)
- Other: ask user to enter path manually

For each selected file, ask:
- **Field path** (dot notation for nested) — default by file type: `version` for JSON, `project.version` for pyproject.toml, `package.version` for Cargo.toml
- **Format** — `json` / `toml` / `yaml` / `text` (auto-detected from extension if possible)

### 3. Ask: trigger strategy

Use `AskUserQuestion` (single select):

- **`auto`** — Claude evaluates each change and decides. New feature → MINOR, bug fix → PATCH, breaking change → MAJOR, docs/config only → skip. *(Recommended)*
- **`always`** — Every commit with source file changes must include a version bump. No exceptions. Good for strict release workflows.

### 4. Ask: enforcement level

Use `AskUserQuestion` (single select):

- **`ask`** — Warn and ask for confirmation before proceeding without a bump. *(Default)*
- **`deny`** — Block commit/push/PR until a version bump is staged.
- **`allow`** — No enforcement. Only session rules, no hook blocking.

### 5. Ask: base branch

Use `AskUserQuestion` (single select):

- `main` *(Default)*
- `master`
- `develop`
- Other (user enters custom name)

### 6. Ask: exclude patterns

Show default patterns and let user customize:

Default exclusions (files that never require a version bump):
```
README.md, CHANGELOG.md, LICENSE, .gitignore, *.md, docs/**, .claude/**, .claude-plugin/**
```

Use `AskUserQuestion` — ask if user wants to add or remove any patterns.

### 7. Write config

Write `.claude-plugin/semver.json` with all chosen settings:

```json
{
  "versionFiles": [
    { "path": "package.json", "field": "version", "format": "json" }
  ],
  "triggerStrategy": "auto",
  "baseBranch": "main",
  "enforcement": {
    "missingBump": "ask"
  },
  "commitFormat": "chore: bump version to {version}",
  "excludePatterns": ["README.md", "CHANGELOG.md", "LICENSE", ".gitignore", "*.md", "docs/**", ".claude/**", ".claude-plugin/**"]
}
```

Create `.claude-plugin/` directory if it doesn't exist.

### 8. Show confirmation

Display:
- Path written: `.claude-plugin/semver.json`
- Summary of settings (version files, strategy, enforcement, base branch)
- Next steps:

```
Next steps:
1. git add .claude-plugin/semver.json && git commit -m "chore: add semver config"
2. Push to share enforcement rules with your team
3. Run /semver:guide for the full SemVer 2.0.0 reference
```
