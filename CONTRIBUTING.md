# Contributing to Claude Code Plugins Marketplace

Thank you for contributing to the Tribe Coding plugin marketplace! This guide will help you understand our contribution workflow.

## Quick Links

- [CLAUDE.md](CLAUDE.md) — Complete project guidelines (read this first!)
- [Plugin Structure Convention](CLAUDE.md#plugin-structure-convention)
- [Version Bump Requirements](docs/versioning.md) — **CRITICAL**
- [Acceptance Test Standard](docs/acceptance-tests.md)

## Plugin Concepts

- **hook** — runs automatically in response to events (`PostToolUse`, `PreToolUse`, `SessionStart`, `SessionEnd`). No user action needed.
- **command** — a `/slash-command` that the user invokes explicitly when needed.
- **skill** — reference material that Claude loads on-demand when it decides the context is relevant.

## Before You Start

1. Read [CLAUDE.md](CLAUDE.md) — contains all technical guidelines
2. Review existing plugins (`plugins/plantuml/`, `plugins/statusline/`)
3. Check open issues and PRs to avoid duplicates

## Contribution Workflow

### 1. Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b feature/<your-feature-name>
```

### 2. Make Your Changes

Follow conventions in [CLAUDE.md](CLAUDE.md):
- Plugin structure
- Skills standard (agentskills.io spec)
- Hook scripts convention (`${CLAUDE_PLUGIN_ROOT}`)
- Cross-platform compatibility (macOS + Linux)

### 3. Add Acceptance Tests

**REQUIRED** for new plugins or significant features:
- Create `plugins/<name>/docs/ACCEPTANCE_TESTS.md`
- See [Acceptance Test Standard](docs/acceptance-tests.md)
- Reference example: `plugins/plantuml/docs/ACCEPTANCE_TESTS.md`

### 4. Version Bump (CRITICAL!)

**Before creating PR or merging**, bump the plugin version:

```bash
# Edit plugins/<name>/.claude-plugin/plugin.json
# Change "version": "1.2.3" to "1.3.0"

git add plugins/<name>/.claude-plugin/plugin.json
git commit -m "Bump <plugin-name> version to 1.3.0

Version bump for PR #XX: <description>

Changes in 1.3.0:
- <list changes>

Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Version bump rules:**
- **MAJOR** (X.0.0): Breaking changes, user migration required
- **MINOR** (x.Y.0): New features, backwards-compatible
- **PATCH** (x.y.Z): Bug fixes, documentation corrections

See [Version Bump Requirements](docs/versioning.md) for detailed examples.

**Why this matters:** Without a version bump, users won't see your changes after restarting Claude Code.

### 5. Create Pull Request

Use the PR template to:
- Describe your changes
- Check affected plugins
- Confirm version bump
- List testing done

### 6. Address Review Feedback

Respond to review comments and make requested changes.

### 7. Merge

After approval:
- Squash merge to main (GitHub will handle this)
- Delete feature branch

### 8. Post-Merge

After merge:
```bash
# Sync your local main
git checkout main
git pull origin main
```

Then restart Claude Code to pick up changes.

## Common Tasks

### Adding a New Plugin

1. Create plugin structure:
   ```bash
   mkdir -p plugins/my-plugin/{.claude-plugin,hooks,scripts,commands,skills,templates,docs}
   ```

2. Add `plugin.json` manifest (version `0.1.0`)
3. Add `hooks/hooks.json` (if needed)
4. Add commands/skills with YAML frontmatter
5. **Create** `docs/ACCEPTANCE_TESTS.md`
6. Register in `.claude-plugin/marketplace.json`
7. Test locally
8. **Bump version if iterating** before final PR

### Modifying Existing Plugin

1. Make changes
2. Update acceptance tests if behavior changed
3. **Bump version** (MAJOR/MINOR/PATCH based on change type)
4. Create PR

### Fixing Bugs

1. Create fix in feature branch
2. **Bump PATCH version** (`1.2.3` → `1.2.4`)
3. Test fix
4. Create PR with "Fixes #issue-number"

### Adding Features

1. Create feature in feature branch
2. **Bump MINOR version** (`1.2.3` → `1.3.0`)
3. Update/create acceptance tests
4. Test feature
5. Create PR

## Code Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Use `${CLAUDE_PLUGIN_ROOT}` for plugin paths
- Provide fallback: `${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}`
- Support macOS and Linux (see [Cross-Platform Compatibility](docs/conventions.md#cross-platform-compatibility))
- Keep hooks fast (timeout ≤30s)
- Silent on success, informative on errors

### Skills (SKILL.md)

- **MUST** include YAML frontmatter ([agentskills.io spec](https://agentskills.io/specification))
- Required fields: `name`, `description`
- Keep under ~100 lines (use hybrid design for large catalogs)
- Write clear trigger signals in description

### Acceptance Tests

- Cover all components (scripts, hooks, commands, skills)
- Mark automation status (✅ automated, 🟡 partial, ⚠️ manual)
- Include step-by-step manual procedures
- Provide expected outputs and failure modes
- See `plugins/plantuml/docs/ACCEPTANCE_TESTS.md` as reference

## Testing

### Automated Testing

Most tests can be run by Claude Code itself:
```
# In Claude Code session
Run the acceptance tests from plugins/<name>/docs/ACCEPTANCE_TESTS.md
```

### Manual Testing

For SessionStart hooks and fresh session behavior:
1. Restart Claude Code (triggers cache refresh + SessionStart hooks)
2. Follow manual test procedures in ACCEPTANCE_TESTS.md

## Questions?

- Open an issue for questions
- Reference [CLAUDE.md](CLAUDE.md) for technical details
- Look at existing plugins for examples

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
