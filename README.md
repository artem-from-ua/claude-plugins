# Tribe Coding — Claude Code Plugins

A marketplace of reusable plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Quick Reference

| Plugin | Type | Name | Invocation | Description |
|--------|------|------|------------|-------------|
| **plantuml** | hook | PostToolUse | *automatic* | Auto-sync PlantUML image URLs on `.md` edits |
| | hook | SessionStart | *automatic* | Inject base formatting rules + install pre-commit hook |
| | command | [`plantuml-validate`](plugins/plantuml/commands/plantuml-validate/SKILL.md) | `/plantuml:plantuml-validate` | Check all diagram URLs are in sync |
| | skill | [`plantuml-diagram-guide`](plugins/plantuml/skills/plantuml-diagram-guide/SKILL.md) | *on-demand* | Full catalog of 16 diagram types with selection guide |
| **statusline** | hook | SessionStart | *automatic* | Install statusline script to `~/.claude/` |
| | command | [`statusline-setup`](plugins/statusline/commands/statusline-setup/SKILL.md) | `/statusline:statusline-setup` | Configure statusline in `~/.claude/settings.json` |
| **statusline-compact** | hook | SessionStart | *automatic* | Install compact statusline script to `~/.claude/` |
| | command | [`statusline-setup`](plugins/statusline-compact/commands/statusline-setup/SKILL.md) | `/statusline-compact:statusline-setup` | Configure compact statusline |

> - **hook** — runs automatically in response to events (e.g. after every file edit or on session start). No user action needed.
> - **command** — a `/slash-command` that the user invokes explicitly when needed.
> - **skill** — reference material that Claude loads on-demand when it decides the context is relevant.

## Installation

### Add the marketplace

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
```

### Install a plugin

```bash
/plugin install plantuml@tribe-coding
/plugin install statusline@tribe-coding
/plugin install statusline-compact@tribe-coding
```

### Enable auto-updates

After installing, enable automatic updates so plugins stay in sync with the latest fixes:

```bash
/plugin
```

Then select the installed plugin and enable **auto-update**. Updates are applied automatically on the next Claude Code restart.

## Available Plugins

### plantuml

PlantUML diagram automation for markdown documentation.

**Features:**

- Auto-sync PlantUML image URLs after every Write/Edit (PostToolUse hook)
- ASCII text diagrams in terminal via PlantUML text renderer API
- Git pre-commit hook blocks commits with stale diagram URLs
- Base formatting rules injected on session start (~200 tokens)
- Full diagram type catalog available on-demand via skill
- Validation command: `/plantuml:plantuml-validate`
- GitHub Actions CI workflow template

**What it does:**

- **In markdown files**: Every PlantUML diagram has two parts — a fenced code block with raw source and an image link pointing to plantuml.com. This plugin keeps them in sync automatically.
- **In terminal**: When you ask Claude to explain architecture or flows, it uses PlantUML's ASCII text renderer (`https://www.plantuml.com/plantuml/txt/<encoded>`) to show perfectly aligned ASCII diagrams instead of pasting raw PlantUML source or manually drawing ASCII art.

### statusline

Custom Claude Code statusline with real-time API usage info.

**Features:**

- Current directory and git branch (yellow when dirty)
- Model name, color-coded (Opus=red, Sonnet=green, Haiku=blue)
- Context window usage with thresholds (yellow >=60%, red >=80%)
- 5-hour and 7-day rate limit progress bars with time remaining
- Extra usage (monthly billing) progress bar with money spent
- Anthropic OAuth usage API integration (cached 60s)
- Setup command: `/statusline:statusline-setup`

**Progress bar resolution:**

- 5h: 15 min/block (20 blocks) - updates every 15 minutes
- 7d: 8 hours/block (21 blocks) - updates every 8 hours
- Extra: 1 day/block (28-31 blocks) - updates daily
- Cache: 60s refresh rate (all bars)

### statusline-compact

Compact single-line Claude Code statusline with brightness-coded API usage values.

**Example:**

```
5h 92% 50m !!   7d 22% ~5d   extra $4.79   Sonnet 4.5   context 30%   my-project/   main*
```

**Features:**

- Single-line layout - most space-efficient option
- 5-hour and 7-day rate limit tracking with time-to-reset
- Extra usage (monthly billing) with dollar amount
- Context window usage percentage
- Current directory and git branch (yellow when dirty)
- Model name with brightness = capability tier (Opus bright, Sonnet default, Haiku dim)
- Brightness-coded values: dim at low usage, brighter as they climb, yellow >90%, red at 100%
- Text indicators: `!!` warning, `XX` exhausted
- Anthropic OAuth usage API integration (cached 60s)
- Setup command: `/statusline-compact:statusline-setup`

## Plugin Structure

Each plugin follows the Claude Code plugin spec:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/                 # User-invocable /commands
│   └── <command>/
│       └── SKILL.md
├── skills/                   # On-demand skills (context-efficient)
│   └── <skill>/
│       └── SKILL.md
├── hooks/
│   └── hooks.json            # PostToolUse / SessionStart hooks
├── scripts/                  # Hook and utility scripts
└── templates/                # Project templates (pre-commit, CI)
```

> **Note:** `plugin.json` **must** include both `"commands"` and `"skills"` fields for Claude Code to expose SKILL.md files to the skill system. If your plugin only has `commands/`, point both fields at the same directory:
> ```json
> { "commands": ["./commands/"], "skills": ["./commands/"] }
> ```

## Requirements

### plantuml

- Python 3.x (for the encoder script)
- Git (for pre-commit hook)

### statusline / statusline-compact

- `jq` — JSON processing
- `curl` — API requests
- `python3` — OAuth token parsing (macOS)
- macOS Keychain or `~/.claude/.credentials.json` (for Anthropic OAuth token)

## Plugin Cache Sync

### The problem

Claude Code has a bug where auto-updating a marketplace does not invalidate the plugin cache. `CLAUDE_PLUGIN_ROOT` continues to point at stale cached files, so updated scripts, skills, and commands are not picked up.

**Upstream issues:**

- [anthropics/claude-code#14061](https://github.com/anthropics/claude-code/issues/14061) — `/plugin update` doesn't invalidate cache
- [anthropics/claude-code#15621](https://github.com/anthropics/claude-code/issues/15621) — old versions not removed, their hooks still run
- [anthropics/claude-code#15642](https://github.com/anthropics/claude-code/issues/15642) — `CLAUDE_PLUGIN_ROOT` points to stale version

### The fix: `claude-marketplace-sync`

A standalone script that runs *before* Claude Code starts. It pulls marketplace repos with `autoUpdate: true` and rsyncs their plugin directories into the cache.

**Install:**

```bash
# From the marketplace repo
./scripts/install-sync.sh
```

This creates a symlink from `~/.local/bin/claude-marketplace-sync` to the script in the repo, adds it to `PATH`, and configures a shell alias so that `claude` automatically syncs before starting. Because it's a symlink, changes to the script in the repo are picked up immediately — no reinstall needed.

**Usage:**

```bash
claude-marketplace-sync              # Sync (skips if ran in last 5 min)
claude-marketplace-sync --force      # Ignore freshness window; also re-runs SessionStart hooks
claude-marketplace-sync --all        # Sync all marketplaces, not just autoUpdate ones
claude-marketplace-sync --verbose    # Print detailed progress
```

**Output:**

By default, `claude-marketplace-sync` shows:

- Sync status (`🔄 Syncing...` or `⏭️ Skipping...`)
- Plugin version updates (`✅ Updated: plugin@marketplace version X.Y.Z`)
- Sync errors (`❌ Failed to sync...`)

With `--verbose`, also shows git pull and rsync operations.

For silent operation: `claude-marketplace-sync 2>/dev/null`

### Troubleshooting

Both `claude-marketplace-sync` and plugin SessionStart hooks log detailed operations to a shared log file:

```bash
cat /tmp/claude-plugin-sync.log
```

The log records: sync decisions (version/SHA comparison), rsync operations, SessionStart hook execution (expanded commands, exit codes, output), and `setup-statusline.sh` operations (`CLAUDE_PLUGIN_ROOT` value, source/target file states, diff results).

To diagnose a stale plugin after sync:
1. Restart Claude Code (triggers `claude-marketplace-sync` + SessionStart hooks)
2. Check the log: `cat /tmp/claude-plugin-sync.log`
3. Look for `[setup-statusline]` entries showing `CLAUDE_PLUGIN_ROOT` path — if it points to an old version directory, Claude Code hasn't picked up the new cache entry

The workaround will be removed once the upstream bugs are fixed.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

**Quick links:**

- [CONTRIBUTING.md](CONTRIBUTING.md) — Full contribution workflow
- [CLAUDE.md](CLAUDE.md) — Complete technical guidelines
- [Version Bump Requirements](CLAUDE.md#version-bump-requirements) — **CRITICAL**: Required before merge
- [Acceptance Test Standard](CLAUDE.md#acceptance-test-documentation-standard)
- [PR Template](.github/pull_request_template.md) — Use this when creating PRs

**Quick start:**

1. Create `plugins/<name>/` with the standard structure (see [CLAUDE.md](CLAUDE.md))
2. Add `.claude-plugin/plugin.json` manifest (version `0.1.0`)
3. All SKILL.md files must include YAML frontmatter ([agentskills.io spec](https://agentskills.io/specification))
4. Create `docs/ACCEPTANCE_TESTS.md` with comprehensive tests
5. Register in `.claude-plugin/marketplace.json`
6. **Bump version before merge** (see [Version Bump Requirements](CLAUDE.md#version-bump-requirements))
7. Submit PR using the [template](.github/pull_request_template.md)

**Important:** Version bumps are **required** before merging any PR that changes plugin code. Without version bumps, `claude-marketplace-sync` won't pick up your changes. See [CLAUDE.md](CLAUDE.md#version-bump-requirements) for semantic versioning rules.

## License

MIT — see [LICENSE](LICENSE).
