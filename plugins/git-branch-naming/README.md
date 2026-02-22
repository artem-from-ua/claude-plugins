# git-branch-naming

A Claude Code plugin that enforces git branch naming conventions. Validates branch names before creation, warns when staged/pushed files don't match the branch type, and protects against direct pushes to main branches.

## What It Does

- **Validates branch names** at creation (`git checkout -b`, `git branch`, `git switch -c`)
- **Warns on content mismatch** before `git commit` (staged files) and `git push` (full branch diff)
- **Protects main branches** from direct pushes
- **Injects naming rules** into every Claude Code session (zero extra user prompts)
- **Configurable per project** via `.claude/git-branch-naming.json` — committed to git and shared team-wide

## Branch Name Format

```
<prefix>/<kebab-case-description>
```

Valid prefixes: `feature`, `bugfix`, `hotfix`, `release`, `docs`, `test`, `chore`, `refactor`

Examples:
- ✅ `feature/user-auth`
- ✅ `bugfix/fix-login-redirect`
- ✅ `docs/update-readme`
- ❌ `my-feature` — missing prefix
- ❌ `Feature/UserAuth` — wrong case
- ❌ `feature/user_auth` — underscore not allowed

## Installation

### 1. Add to `enabledPlugins`

In your project's `.claude/settings.json`:
```json
{
  "enabledPlugins": {
    "git-branch-naming@tribe-coding": true
  }
}
```

### 2. (Optional) Run setup wizard

In a Claude Code session:
```
/git-branch-naming:setup
```

This creates `.claude/git-branch-naming.json` with your project's conventions. Commit it to git to share with your team.

## Configuration

Configuration lives in `.claude/git-branch-naming.json` (committed to git, team-wide).

### Schema

```json
{
  "prefixes": ["feature", "bugfix", "hotfix", "release", "docs", "test", "chore", "refactor"],
  "ticketPattern": "",
  "maxLength": 60,
  "protectedBranches": ["main", "master", "develop"],
  "requireKebabCase": true,
  "warnOnContentMismatch": true,
  "enforcement": {
    "invalidName": "ask",
    "protectedBranch": "ask",
    "contentMismatch": "ask"
  }
}
```

### Fields

| Field | Default | Description |
|-------|---------|-------------|
| `prefixes` | 8 standard prefixes | Allowed branch prefixes |
| `ticketPattern` | `""` | Regex for required ticket number. Empty = not required. |
| `maxLength` | `60` | Max characters in branch name |
| `protectedBranches` | `["main","master","develop"]` | Branches requiring confirmation to push directly |
| `requireKebabCase` | `true` | Enforce lowercase and hyphens in description |
| `warnOnContentMismatch` | `true` | Check file types vs branch type on commit/push |
| `enforcement.invalidName` | `"ask"` | Action on invalid branch name: `"ask"` or `"deny"` |
| `enforcement.protectedBranch` | `"ask"` | Action on push to protected branch: `"ask"` or `"deny"` |
| `enforcement.contentMismatch` | `"ask"` | Action on content mismatch: `"ask"` or `"deny"` |

### Enforcement modes

- **`ask`** (default) — Claude warns and asks for confirmation. User can proceed.
- **`deny`** — Claude blocks the command. User must fix the issue to continue.

### Example: JIRA project with strict enforcement

```json
{
  "prefixes": ["feature", "bugfix", "hotfix", "release", "docs", "chore"],
  "ticketPattern": "[A-Z]+-\\d+",
  "maxLength": 72,
  "protectedBranches": ["main", "develop"],
  "requireKebabCase": true,
  "warnOnContentMismatch": true,
  "enforcement": {
    "invalidName": "deny",
    "protectedBranch": "deny",
    "contentMismatch": "ask"
  }
}
```

This requires ticket numbers: `feature/PROJ-123-add-login`

## Team Setup Workflow

1. **One developer** runs the setup wizard:
   ```
   /git-branch-naming:setup
   ```

2. **Commit both files:**
   ```bash
   git add .claude/settings.json .claude/git-branch-naming.json
   git commit -m "chore: add git branch naming conventions"
   git push
   ```

3. **All team members** clone the repo — conventions are automatically enforced in their Claude Code sessions.

## Content Mismatch Detection

The plugin checks that files you're committing/pushing match what the branch name implies.

### Two checkpoints

| Checkpoint | What's checked | Threshold | Default |
|------------|---------------|-----------|---------|
| `git commit` | Staged files vs branch prefix | >80% type mismatch | `ask` |
| `git push` | Full branch diff + commit messages | >50% mismatch | `ask` |

### Example warnings

> **`docs/` branch with code files:**
> "Branch 'docs/update-api' is a docs branch, but 90% of files are code files (9/10 files). Consider using a 'feature/' or 'refactor/' prefix instead."

> **`feature/` branch with only docs:**
> "Branch 'feature/add-login' usually contains code changes, but 85% of files are documentation. Is this intentional?"

### Prefix-to-content mapping

| Prefix | Expected | Warning condition |
|--------|----------|-------------------|
| `feature/`, `bugfix/`, `hotfix/` | Code + tests | Only docs, no code (>80%) |
| `docs/` | Markdown, rst, txt | Code files (>80%) |
| `test/` | Test files | No test files at all |
| `chore/` | Config, CI, deps | Application source code (>80%) |
| `refactor/` | Code | (checks only for `--branch` mode) |
| `release/` | Any | No check |

## Pre-push Git Hook

For enforcement outside of Claude Code (CI, terminal git), install the pre-push hook:

```bash
mkdir -p .githooks
cp /path/to/plugin/templates/pre-push .githooks/pre-push
chmod +x .githooks/pre-push
git config core.hooksPath .githooks
```

Or let the setup wizard install it: `/git-branch-naming:setup` → answer "Yes" to hook installation.

The hook reads the same `.claude/git-branch-naming.json` config file.

## Architecture

```
scripts/
├── inject-rules.sh           # SessionStart: outputs ~130 tokens of rules
├── validate-branch.sh        # PreToolUse: intercepts git commands, validates names
└── check-content-mismatch.sh # Helper: staged/branch file analysis

hooks/hooks.json              # PreToolUse(Bash) + SessionStart wiring
commands/git-branch-naming-setup/SKILL.md  # /git-branch-naming:setup wizard
skills/branch-naming-guide/SKILL.md        # On-demand naming reference
templates/
├── git-branch-naming.json    # Default config template
└── pre-push                  # Standalone git pre-push hook
```

## Token Budget

| Component | Tokens | When |
|-----------|--------|------|
| SessionStart rules | ~130 | Every session |
| Skill description | ~60 | Every session (skill list) |
| Command description | ~30 | Every session (command list) |
| **Total per-session** | **~220** | Fixed |
| Skill body (on-demand) | ~400 | When invoked |
| PreToolUse scripts | 0 | External process |

## Testing

See [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) for comprehensive test documentation including:
- Automated unit tests for all scripts
- Integration test procedures
- Manual SessionStart verification steps
- Cross-platform compatibility tests
- Team config sharing workflow

## Requirements

- **bash** 3.2+ (macOS compatible)
- **git** (any modern version)
- **jq** (for config loading — scripts fall back to defaults if jq is unavailable)
