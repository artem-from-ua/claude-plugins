# semver

> [!TIP]
> ✨ ***Never ship without a version bump — Claude enforces SemVer before every commit, push, and PR.***

Semantic versioning enforcement for Claude Code. Validates that a version bump is staged before `git commit`, `git push`, and PR creation. Injects SemVer rules into every session so Claude knows when and how to increment versions automatically.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [⚙️ Configuration](#configuration)

## 🎬 Demo

```
You: commit the auth service refactor

Claude: ⚠️  No version bump detected.

The staged changes include source file modifications in src/auth/.
According to SemVer, this refactor (backwards-compatible) requires a MINOR bump.

Current version in package.json: 2.3.1
Suggested: 2.4.0

Bump version now, or commit anyway?
```

## ⚙️ How it works <a name="how-it-works"></a>

| Trigger | What happens |
|---------|-------------|
| SessionStart | Injects SemVer rules — Claude evaluates each commit automatically |
| PreToolUse (`git commit`, `git push`, PR creation) | Validates a version bump is staged; warns if missing |

**Trigger strategies:**

| Strategy | Behaviour |
|----------|-----------|
| `auto` (default) | Evaluate each commit: feature → MINOR, fix → PATCH, breaking → MAJOR, docs/config only → skip |
| `always` | Every commit with source changes requires a bump — no exceptions |

**Excluded from bump checks by default:** `*.md`, `docs/**`, `LICENSE`, `.gitignore`, `.claude-plugin/**`

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install semver@tribe-coding
```

Then run the setup wizard to configure your version files and trigger strategy:

```bash
/semver:semver-setup
```

Select **semver** in `/plugin` → enable **auto-update**. Restart your session — done.

## ⚙️ Configuration <a name="configuration"></a>

Config lives at `.claude-plugin/semver.json` (project, committed to git) and `~/.claude/semver.json` (global fallback). Project config takes priority.

**Example `.claude-plugin/semver.json`:**

```json
{
  "versionFiles": [
    { "path": "package.json", "field": "version", "format": "json" }
  ],
  "triggerStrategy": "auto",
  "baseBranch": "main",
  "enforcement": { "missingBump": "ask" },
  "commitFormat": "chore: bump version to {version}",
  "excludePatterns": ["README.md", "docs/**", "*.md"]
}
```

**Supported version file formats:** `package.json`, `pyproject.toml`, `plugin.json`, or any JSON/TOML file with a version field. Multiple files supported.

**Enforcement levels:**

| `missingBump` | Behaviour |
|---------------|-----------|
| `ask` (default) | Prompt the user before proceeding |
| `warn` | Log a warning, continue anyway |
| `block` | Refuse to commit/push until version is bumped |

## Skills (on-demand)

`semver-guide` — loaded automatically when Claude needs to decide MAJOR/MINOR/PATCH. Covers SemVer 2.0.0 decision tree, conflict resolution when rebasing, and common mistakes.

## Reference

- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite
