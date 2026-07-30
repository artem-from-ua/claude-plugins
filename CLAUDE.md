# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## PR Merge

`allow_auto_merge` is **disabled** in this repo — `gh pr merge --auto` will fail. Branch protection requires `--admin` for immediate merge. Always use:
```bash
gh pr merge <N> --squash --admin
```

## ⚠️ CRITICAL: Version Bump Requirement

**MANDATORY: Claude Code MUST automatically bump version when plugin files change**

### Workflow (NO EXCEPTIONS)

When ANY files under `plugins/<name>/` are modified:

1. **Make code/doc changes**
2. **Check current version in main**: `git show main:plugins/<name>/.claude-plugin/plugin.json | jq -r '.version'`
3. **Automatically bump version** in `plugins/<name>/.claude-plugin/plugin.json`:
   - PATCH: bug fixes, docs, UI improvements
   - MINOR: new features, backwards-compatible
   - MAJOR: breaking changes
4. **Commit version bump** (separate commit with changelog message)
5. **Then create PR**

See [`docs/versioning.md`](docs/versioning.md) for full semver rules, conflict resolution, and examples.

**This is NOT a reminder. This is NOT optional. This is MANDATORY automated behavior.**

## What This Is

A marketplace of reusable Claude Code plugins. Each plugin lives under `plugins/<name>/` and follows the Claude Code plugin spec. The marketplace manifest is `.claude-plugin/marketplace.json`.

## Plugins

- **ai-fortune** — Career direction analysis: interview + AI usage pattern mining
- **context** — Inspects full session context in load order
- **fresh-guides** — Watchlist for fast-changing technologies: verifies advice against official docs
- **git-branch-naming** — Enforces branch naming conventions (prefix/kebab-case)
- **kb-grooming** — Documentation health analysis: structural checks, semantic compliance, GitHub issues
- **plantuml** — Keeps PlantUML diagram URLs in sync; provides ASCII rendering in terminal
- **playbook** — Injects curated coding guideline presets into sessions
- **retroscope** — Generates retrospective reports summarizing sessions
- **semver** — Enforces semantic versioning on commit/push/PR
- **statusline** — Three-line statusline: rate limits, context/branch, extra usage
- **statusline-compact** — Minimal single-line statusline: repo/worktree/branch, model/effort/context/cost (jq + git only)
- **technology-explainer** — Adapts explanation depth based on user proficiency per technology

See [`docs/plugin-behavior.md`](docs/plugin-behavior.md) for how plugins use hooks, skills, and PostToolUse to work proactively.

## Plugin Structure Convention

```
plugins/<name>/
├── .claude-plugin/plugin.json    # manifest (name, version, commands, skills, hooks)
├── hooks/hooks.json              # hook definitions (PostToolUse, SessionStart)
├── scripts/                      # shell/python scripts called by hooks
├── commands/<cmd>/SKILL.md       # user-invocable slash commands
├── skills/<skill>/SKILL.md       # on-demand context-efficient skills
├── templates/                    # project templates (pre-commit, CI, default config)
└── docs/
    └── ACCEPTANCE_TESTS.md       # comprehensive test documentation (REQUIRED)
```

See [`docs/conventions.md`](docs/conventions.md) for plugin config, hook scripts, and cross-platform patterns.

## Skills & Presets

All SKILL.md files must follow the [agentskills.io specification](https://agentskills.io/specification):
- YAML frontmatter with `name` and `description` is required
- Optional: `compatibility`, `license`, `metadata`
- When creating or editing SKILL.md files, always include valid frontmatter

For full authoring guidelines — SKILL.md hybrid design, preset RULES/REFERENCE zones, rule patterns, anti-patterns, and quality checklist — see **[`docs/AUTHORING.md`](docs/AUTHORING.md)**.

## Adding a New Plugin

1. Create `plugins/<name>/` with the structure above
2. Add `.claude-plugin/plugin.json` manifest with version `0.1.0`
3. All SKILL.md files must include YAML frontmatter per the [agentskills.io spec](https://agentskills.io/specification)
4. In hooks.json, use `${CLAUDE_PLUGIN_ROOT}` for script paths (see [`docs/conventions.md`](docs/conventions.md))
5. Register in `.claude-plugin/marketplace.json`
6. **Create acceptance test documentation** in `plugins/<name>/docs/ACCEPTANCE_TESTS.md` (see [`docs/acceptance-tests.md`](docs/acceptance-tests.md))
7. **If plugin needs project-level config:**
   - Store default config template in `templates/<name>.json`
   - Setup wizard writes to `{project}/.claude-plugin/<name>.json`
   - Scripts read from `.claude-plugin/<name>.json` first, fall back to `.claude/<name>.json`
   - README must document the setup command and config location (see `readme` playbook preset → Setup Section for Plugins)
8. **If plugin installs git hooks** (pre-commit, pre-push, etc.) → use marker-based injection and provide an uninstall command (see [`docs/conventions.md`](docs/conventions.md) — Git Hook Installation)
9. **Update root `README.md`** — add row to the Plugins table (alphabetical order)
10. **Update the Plugins list above** — add bullet to the Plugins section in this file (alphabetical order)
11. **README navbar** — nav line goes after the header block (motto + intro paragraph), lists ALL sections except the first one (usually Demo); see `readme` playbook preset for full rules

## Adding a New Playbook Preset

1. Create `plugins/playbook/presets/<name>.md` (see [`docs/AUTHORING.md`](docs/AUTHORING.md) for format)
2. Update `plugins/playbook/README.md` preset table (alphabetical order)
3. Bump playbook version (MINOR for new preset)
4. If replacing a rule from `~/.claude/CLAUDE.md` or `memory/` → remove the source after merge
5. Update `playbook-browse` SKILL.md description keywords if needed

## README Demo Sections

Claude Code console interaction examples (blocks showing `You: … Claude: …` dialogues, tool call output, or slash command output) in plugin README files MUST use `` ```markdown `` fenced code blocks — not bare `` ``` ``. This enables syntax highlighting on GitHub (tables, emoji, bold) and ensures consistent appearance across all plugins. Do NOT apply `` ```markdown `` to non-interaction blocks (plain text lists, file trees, format templates) — those stay as bare `` ``` ``.

## Dependencies

- plantuml: Python 3.x, git
- statusline: jq, curl, python3; macOS Keychain or ~/.claude/.credentials.json on Linux (for Anthropic OAuth token)
- statusline-compact: jq, git (no python3; the render makes no network calls). Optional `gh` for the
  `[CPM]` block's M (PR-not-merged) letter, invoked only as a detached background refresh — without
  `gh` the M letter is simply omitted and everything else works
