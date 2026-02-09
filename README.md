# Tribe Coding — Claude Code Plugins

A marketplace of reusable plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Available Plugins

### plantuml-sync

PlantUML diagram automation for markdown documentation.

**Features:**
- Auto-sync PlantUML image URLs after every Write/Edit (PostToolUse hook)
- Git pre-commit hook blocks commits with stale diagram URLs
- Base formatting rules injected on session start (~200 tokens)
- Full diagram type catalog available on-demand via skill
- Validation command: `/plantuml-sync:plantuml-validate`
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

## Installation

### Add the marketplace

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
```

### Install a plugin

```bash
/plugin install plantuml-sync@tribe-coding
/plugin install statusline@tribe-coding
```

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

### plantuml-sync
- Python 3.x (for the encoder script)
- Git (for pre-commit hook)

### statusline
- `jq` — JSON processing
- `curl` — API requests
- macOS Keychain access (for Anthropic OAuth token)

## Contributing

To add a new plugin:

1. Create `plugins/<name>/` with the standard structure
2. Add a `.claude-plugin/plugin.json` manifest
3. All SKILL.md files must include YAML frontmatter per the [agentskills.io spec](https://agentskills.io/specification)
4. Register it in `.claude-plugin/marketplace.json`
5. Submit a PR

## License

MIT — see [LICENSE](LICENSE).
