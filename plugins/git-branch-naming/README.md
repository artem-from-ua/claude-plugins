# git-branch-naming

> [!TIP]
> ✨ ***Clean branch names, enforced automatically — before the mess even starts.***

A Claude Code plugin that enforces git branch naming conventions. Validates branch names before creation, warns when staged/pushed files don't match the branch type, and protects against direct pushes to main branches.

> [!NOTE]
> [💡 Why](#why-this-plugin-exists) · [🎬 Usage Examples](#usage-examples) · [📐 Format](#branch-name-format) · [📦 Installation](#installation) · [⚙️ Configuration](#configuration) · [👥 Team Setup](#team-setup-workflow) · [🔍 Mismatch](#content-mismatch) · [🪝 Pre-push](#pre-push-hook) · [🏗️ Architecture](#architecture) · [💰 Token Cost](#token-cost) · [🧪 Testing](#testing) · [📚 References](#references)

## ✅ What It Does <a name="what-it-does"></a>

- **Validates branch names** at creation (`git checkout -b`, `git branch`, `git switch -c`)
- **Warns on content mismatch** before `git commit` (staged files) and `git push` (full branch diff)
- **Protects main branches** from direct pushes
- **Injects naming rules** into every Claude Code session (zero extra user prompts)
- **Configurable per project** via `.claude-plugin/git-branch-naming.json` — committed to git and shared team-wide

## 💡 Why This Plugin Exists <a name="why-this-plugin-exists"></a>

Without this plugin, Claude happily runs whatever git command you ask — including problematic ones:

```markdown
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

```markdown
You: create a branch for the new payment feature

Claude: ⚠️  Branch name 'payment-feature' is missing a valid prefix.

Valid prefixes: feature, bugfix, hotfix, release, docs, test, chore, refactor

Suggested fix: git branch -m 'payment-feature' 'feature/payment-feature'

Branch name format: <prefix>/<kebab-case-description>

Proceed anyway, or rename to 'feature/payment-feature'?
```

### Scenario 2: Claude derives the branch name from task context

The plugin teaches Claude *how* naming works, so it picks the right prefix based on what you're actually doing — not just what you literally say:

```markdown
You: we need to fix the null pointer crash in the cart service, it's urgent

Claude: git checkout -b hotfix/fix-null-pointer-cart-service   ✅
```

```markdown
You: I want to reorganize the auth module, no behavior changes

Claude: git checkout -b refactor/reorganize-auth-module   ✅
```

```markdown
You: add unit tests for the payment processor

Claude: git checkout -b test/add-payment-processor-unit-tests   ✅
```

Without this plugin, Claude would likely create `fix-crash`, `refactor` or `new-branch` — whatever felt natural in the moment.

### Scenario 3: Ticket number required by team config

```markdown
You: start working on PROJ-789, the cart checkout bug

Claude: git checkout -b bugfix/PROJ-789-fix-cart-checkout   ✅
```

Without the plugin, Claude might have created `bugfix/fix-cart-checkout` — valid format, but no ticket link. With `"ticketPattern": "[A-Z]+-\\d+"` in config, the ticket is enforced automatically whenever Claude sees a ticket number in context.

### Scenario 4: Content mismatch before commit

```markdown
You: git commit -m "docs: update API reference"

Claude: ⚠️  Branch 'feature/add-payment' usually contains code changes, but 90%
of staged files are documentation (9/10 files). Is this intentional?

Staged files: README.md, docs/api.md, docs/auth.md, docs/errors.md ...

Proceed with commit, or would you like to review the staged files?
```

Catches the common mistake of committing to the wrong branch.

### Scenario 5: Direct push to main blocked

```markdown
You: git push origin main

Claude: ⚠️  You are about to push directly to protected branch 'main'.

This is usually done via a pull request instead of a direct push. Are you sure?
```

### Scenario 6: Team-wide conventions via committed config

Your team uses JIRA and wants strict enforcement. One dev runs `/git-branch-naming:setup`, commits `.claude-plugin/git-branch-naming.json`, and from that point every teammate's Claude Code session enforces the same rules — no onboarding docs required.

## 📐 Branch Name Format <a name="branch-name-format"></a>

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

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install git-branch-naming@tribe-coding
/plugin
```

Select **git-branch-naming** → enable **auto-update**.

Then run the setup wizard to configure your branch naming conventions:

```
/git-branch-naming:setup
```

This creates `.claude-plugin/git-branch-naming.json` with your project's conventions. Commit it to git to share with your team.

**Requirements:** bash 3.2+, git, jq (scripts fall back to defaults if jq is unavailable)

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

## 👥 Team Setup Workflow <a name="team-setup-workflow"></a>

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

## 🔍 Content Mismatch Detection <a name="content-mismatch"></a>

Warns when staged/pushed files don't match the branch prefix (e.g., only docs on a `feature/` branch). See [`docs/content-mismatch.md`](docs/content-mismatch.md) for thresholds, prefix-to-content mapping, and example warnings.

## 🪝 Pre-push Git Hook <a name="pre-push-hook"></a>

For enforcement outside Claude Code (CI, terminal git). See [`docs/pre-push-hook.md`](docs/pre-push-hook.md) for installation instructions.

## 🏗️ Architecture <a name="architecture"></a>

Hook scripts run as external processes — zero context cost. See [`docs/architecture.md`](docs/architecture.md) for the full file tree.

## 💰 Token Cost Analysis <a name="token-cost"></a>

~220 tokens fixed per session; all validation runs externally at zero context cost. See [`docs/token-cost.md`](docs/token-cost.md) for the full breakdown.

## 🧪 Testing <a name="testing"></a>

See [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) for comprehensive test documentation including:
- Automated unit tests for all scripts
- Integration test procedures
- Manual SessionStart verification steps
- Cross-platform compatibility tests
- Team config sharing workflow

## 📚 References <a name="references"></a>

Standards and best practices this plugin is based on:

- [A successful Git branching model](https://nvie.com/posts/a-successful-git-branching-model/) — Vincent Driessen's original 2010 Gitflow article that established `feature/`, `bugfix/`, `hotfix/`, `release/` as the canonical branch prefixes
- [Gitflow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) — Atlassian's documentation on Gitflow, widely used as a team reference for branch naming strategy
- [Conventional Branch](https://conventional-branch.github.io/) — a lightweight specification for standardized branch naming, analogous to Conventional Commits but at the branch level
- [Best practices for naming Git branches](https://graphite.com/guides/git-branch-naming-conventions) — practical guide covering kebab-case, prefix semantics, and team workflow integration
