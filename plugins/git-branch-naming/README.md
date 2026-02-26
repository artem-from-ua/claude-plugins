# git-branch-naming

> Clean branch names, enforced automatically — before the mess even starts.

A Claude Code plugin that enforces git branch naming conventions. Validates branch names before creation, warns when staged/pushed files don't match the branch type, and protects against direct pushes to main branches.

> **Scroll to: [🎬 Usage Examples](#usage-examples) · [📦 Installation](#installation) · [⚙️ Configuration](#configuration)**

## What It Does

- **Validates branch names** at creation (`git checkout -b`, `git branch`, `git switch -c`)
- **Warns on content mismatch** before `git commit` (staged files) and `git push` (full branch diff)
- **Protects main branches** from direct pushes
- **Injects naming rules** into every Claude Code session (zero extra user prompts)
- **Configurable per project** via `.claude-plugin/git-branch-naming.json` — committed to git and shared team-wide

## Why This Plugin Exists

Without this plugin, Claude happily runs whatever git command you ask — including problematic ones:

```
You: create a branch for the login feature
Claude: git checkout -b LoginFeature   ✅ done
```

Three months later, your repo looks like this:

```
LoginFeature
fix-bug
update
johns-branch
temp2
JIRA-456
refactor-stuff-v2-FINAL
```

Nobody knows what's in these branches, `git branch -a` is unreadable, and automated tooling (release scripts, changelogs, CI rules) breaks because it can't parse branch names.

This plugin catches the problem at the source — before the branch is created.

## 🎬 Usage Examples <a name="usage-examples"></a>

### Scenario 1: Claude creates a branch with a bad name

```
You: create a branch for the new payment feature

Claude: ⚠️  Branch name 'payment-feature' is missing a valid prefix.

Valid prefixes: feature, bugfix, hotfix, release, docs, test, chore, refactor

Suggested fix: git branch -m 'payment-feature' 'feature/payment-feature'

Branch name format: <prefix>/<kebab-case-description>

Proceed anyway, or rename to 'feature/payment-feature'?
```

### Scenario 2: Claude derives the branch name from task context

The plugin teaches Claude *how* naming works, so it picks the right prefix based on what you're actually doing — not just what you literally say:

```
You: we need to fix the null pointer crash in the cart service, it's urgent

Claude: git checkout -b hotfix/fix-null-pointer-cart-service   ✅
```

```
You: I want to reorganize the auth module, no behavior changes

Claude: git checkout -b refactor/reorganize-auth-module   ✅
```

```
You: add unit tests for the payment processor

Claude: git checkout -b test/add-payment-processor-unit-tests   ✅
```

Without this plugin, Claude would likely create `fix-crash`, `refactor` or `new-branch` — whatever felt natural in the moment.

### Scenario 3: Ticket number required by team config

```
You: start working on PROJ-789, the cart checkout bug

Claude: git checkout -b bugfix/PROJ-789-fix-cart-checkout   ✅
```

Without the plugin, Claude might have created `bugfix/fix-cart-checkout` — valid format, but no ticket link. With `"ticketPattern": "[A-Z]+-\\d+"` in config, the ticket is enforced automatically whenever Claude sees a ticket number in context.

### Scenario 4: Content mismatch before commit

```
You: git commit -m "docs: update API reference"

Claude: ⚠️  Branch 'feature/add-payment' usually contains code changes, but 90%
of staged files are documentation (9/10 files). Is this intentional?

Staged files: README.md, docs/api.md, docs/auth.md, docs/errors.md ...

Proceed with commit, or would you like to review the staged files?
```

Catches the common mistake of committing to the wrong branch.

### Scenario 5: Direct push to main blocked

```
You: git push origin main

Claude: ⚠️  You are about to push directly to protected branch 'main'.

This is usually done via a pull request instead of a direct push. Are you sure?
```

### Scenario 6: Team-wide conventions via committed config

Your team uses JIRA and wants strict enforcement. One dev runs `/git-branch-naming:setup`, commits `.claude-plugin/git-branch-naming.json`, and from that point every teammate's Claude Code session enforces the same rules — no onboarding docs required.

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

## 📦 Installation <a name="installation"></a>

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

This creates `.claude-plugin/git-branch-naming.json` with your project's conventions. Commit it to git to share with your team.

## ⚙️ Configuration <a name="configuration"></a>

Configuration lives in `.claude-plugin/git-branch-naming.json` (committed to git, team-wide).

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
   git add .claude/settings.json .claude-plugin/git-branch-naming.json
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

The hook reads `.claude-plugin/git-branch-naming.json` (falls back to `.claude/git-branch-naming.json` for backwards compatibility).

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

## Token Cost Analysis

### Fixed cost per session (~220 tokens)

Every Claude Code session pays this cost regardless of whether you use git at all:

| Component | Tokens | Source |
|-----------|--------|--------|
| SessionStart rules (`inject-rules.sh`) | ~130 | Injected into system prompt |
| Skill description (`branch-naming-guide`) | ~60 | Skill list loaded at startup |
| Command description (`git-branch-naming-setup`) | ~30 | Command list loaded at startup |
| **Total fixed** | **~220** | — |

At Sonnet 4.6 pricing ($3.00 / 1M input tokens), 220 tokens cost **$0.00066 per session** — less than a tenth of a cent.

### Variable cost (only when triggered)

| Event | Tokens | Frequency |
|-------|--------|-----------|
| `branch-naming-guide` skill body | ~400 | When Claude consults naming guide |
| `git-branch-naming-setup` command body | ~500 | When `/git-branch-naming:setup` is run |
| Warning message in conversation | ~50–100 | When validation fires |

### Zero-cost operations

The PreToolUse hook (`validate-branch.sh`, `check-content-mismatch.sh`) runs as an **external process** — it never adds tokens to the context window. This means:
- Every `git checkout`, `git commit`, `git push` validation costs **0 tokens**
- Validation runs even on the largest codebase with no context overhead
- Mismatch analysis (file classification, diff inspection) is entirely outside Claude

### Comparison with naive approaches

| Approach | Cost per session | Notes |
|----------|-----------------|-------|
| This plugin | ~220 tokens | Fixed; validation is external |
| Inline rules in CLAUDE.md | ~220 tokens | Same, but no enforcement mechanism |
| Asking Claude to validate each time | ~300–500 tokens | Per-validation cost, no automation |
| No plugin (ad-hoc reminders) | 0 tokens | But conventions drift and Claude forgets |

### Design principle

The plugin is designed so that **enforcement has zero context cost**. All three validation scripts (`validate-branch.sh`, `check-content-mismatch.sh`, `inject-rules.sh`) run outside the LLM — they read stdin JSON and write `permissionDecision` JSON without consuming any context window tokens. The ~220 token fixed cost covers only the rules Claude needs to *understand* conventions, not to *enforce* them.

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

## References

Standards and best practices this plugin is based on:

- [A successful Git branching model](https://nvie.com/posts/a-successful-git-branching-model/) — Vincent Driessen's original 2010 Gitflow article that established `feature/`, `bugfix/`, `hotfix/`, `release/` as the canonical branch prefixes
- [Gitflow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) — Atlassian's documentation on Gitflow, widely used as a team reference for branch naming strategy
- [Conventional Branch](https://conventional-branch.github.io/) — a lightweight specification for standardized branch naming, analogous to Conventional Commits but at the branch level
- [Best practices for naming Git branches](https://graphite.com/guides/git-branch-naming-conventions) — practical guide covering kebab-case, prefix semantics, and team workflow integration
