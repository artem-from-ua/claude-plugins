# Tribe Coding — Claude Code Plugins

> Good habits, better output.

A curated collection of plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that automate the routines good developers follow anyway — consistent diagrams, clean branches, version discipline, session awareness.

> **Scroll to: [📦 Installation](#installation) · [🤝 Contributing](#contributing)**

## 🧩 Plugins

| Plugin | What it does |
|--------|-------------|
| [**context**](plugins/context/README.md) | Show everything loaded into your session — CLAUDE.md files, memory, hooks — with a per-source token breakdown |
| [**git-branch-naming**](plugins/git-branch-naming/README.md) | Enforce branch naming conventions automatically; warns before push if the name or staged content doesn't match |
| [**plantuml**](plugins/plantuml/README.md) | Proactively add rendered diagrams to docs (image URLs auto-synced); draw ASCII diagrams inline during terminal conversations |
| [**playbook**](plugins/playbook/README.md) | Inject team coding conventions into every session — git workflow, documentation standards, platform quirks |
| [**retroscope**](plugins/retroscope/README.md) | Capture what happened each session and generate structured daily retrospective reports |
| [**semver**](plugins/semver/README.md) | Validate that a version bump is staged before every commit, push, and PR — with configurable enforcement |
| [**statusline**](plugins/statusline/README.md) | Two-line statusline showing API rate limits, context window usage, git branch, and model |
| [**statusline-compact**](plugins/statusline-compact/README.md) | Single-line statusline with brightness-coded values — the minimal-footprint option |

## 📦 Installation

### 1. Add the marketplace

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
```

### 2. Install a plugin

```bash
/plugin install plantuml@tribe-coding
```

Repeat for each plugin you want.

### 3. Enable auto-updates

Open `/plugin`, select each installed plugin, and enable **auto-update**.

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow, plugin structure, and code standards.
