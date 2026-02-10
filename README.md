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
- Git pre-commit hook blocks commits with stale diagram URLs
- Base formatting rules injected on session start (~200 tokens)
- Full diagram type catalog available on-demand via skill
- Validation command: `/plantuml:plantuml-validate`
- GitHub Actions CI workflow template

**What it does:** Every PlantUML diagram in markdown has two parts — a fenced code block with raw source and an image link pointing to plantuml.com. This plugin keeps them in sync automatically.

### statusline

Custom Claude Code statusline with real-time API usage info.

**Features:**
- Current directory and git branch (yellow when dirty)
- Model name, color-coded (Opus=red, Sonnet=green, Haiku=blue)
- Context window usage with thresholds (yellow ≥60%, red ≥80%)
- 5-hour and 7-day rate limit progress bars with time remaining
- Anthropic OAuth usage API integration (cached 60s)
- Setup command: `/statusline:statusline-setup`

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

## Requirements

### plantuml
- Python 3.x (for the encoder script)
- Git (for pre-commit hook)

### statusline
- `jq` — JSON processing
- `curl` — API requests
- macOS Keychain access (for Anthropic OAuth token)

## Plugin Cache Sync

### The problem

Claude Code has a bug where auto-updating a marketplace does not invalidate the plugin cache. `CLAUDE_PLUGIN_ROOT` continues to point at stale cached files, so updated scripts, skills, and commands are not picked up.

**Upstream issues:**
- [anthropics/claude-code#14061](https://github.com/anthropics/claude-code/issues/14061) — `/plugin update` doesn't invalidate cache
- [anthropics/claude-code#15621](https://github.com/anthropics/claude-code/issues/15621) — old versions not removed, their hooks still run
- [anthropics/claude-code#15642](https://github.com/anthropics/claude-code/issues/15642) — `CLAUDE_PLUGIN_ROOT` points to stale version

### The fix: `claude-sync`

A standalone script that runs _before_ Claude Code starts. It pulls marketplace repos with `autoUpdate: true` and rsyncs their plugin directories into the cache.

**Install:**

```bash
# From the marketplace repo
./scripts/install-sync.sh
```

This copies `claude-sync` to `~/.local/bin/`, adds it to `PATH`, and configures a shell alias so that `claude` automatically syncs before starting.

**Usage:**

```bash
claude-sync              # Sync (skips if ran in last 5 min)
claude-sync --force      # Ignore freshness window
claude-sync --all        # Sync all marketplaces, not just autoUpdate ones
claude-sync --verbose    # Print detailed progress
```

The workaround will be removed once the upstream bugs are fixed.

## Contributing

To add a new plugin:

1. Create `plugins/<name>/` with the standard structure
2. Add a `.claude-plugin/plugin.json` manifest
3. All SKILL.md files must include YAML frontmatter per the [agentskills.io spec](https://agentskills.io/specification)
4. Register it in `.claude-plugin/marketplace.json`
5. Submit a PR

## License

MIT — see [LICENSE](LICENSE).
