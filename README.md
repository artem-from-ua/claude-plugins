# Claude Code plugin marketplace by @artem-from-ua

> [!TIP]
> ✨ ***Good habits, better output.***

A curated collection of plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that automate the routines good developers follow anyway — consistent diagrams, clean branches, version discipline, session awareness.

> [!NOTE]
> [📦 Installation](#installation) · [🤝 Contributing](#contributing)

## 🧩 Plugins <a name="plugins"></a>

| Plugin | What it does |
|--------|-------------|
| [**ai-fortune**](plugins/ai-fortune/README.md) | Analyze your AI usage patterns, run a career interview, and get a personalized career direction report |
| [**context**](plugins/context/README.md) | Show everything loaded into your session — CLAUDE.md files, memory, hooks — with a per-source token breakdown |
| [**fresh-guides**](plugins/fresh-guides/README.md) | Watchlist for fast-changing technologies — verify advice against official docs before responding |
| [**git-branch-naming**](plugins/git-branch-naming/README.md) | Enforce branch naming conventions automatically; warns before push if the name or staged content doesn't match |
| [**kb-grooming**](plugins/kb-grooming/README.md) | Audit documentation health — broken links, orphan files, README compliance — then create a GitHub epic with linked issues |
| [**plantuml**](plugins/plantuml/README.md) | Proactively add rendered diagrams to docs (image URLs auto-synced); draw ASCII diagrams inline during terminal conversations |
| [**playbook**](plugins/playbook/README.md) | Inject team coding conventions into every session — git workflow, documentation standards, platform quirks |
| [**retroscope**](plugins/retroscope/README.md) | Capture what happened each session and generate structured daily retrospective reports |
| [**semver**](plugins/semver/README.md) | Validate that a version bump is staged before every commit, push, and PR — with configurable enforcement |
| [**statusline**](plugins/statusline/README.md) | Three-line statusline showing API rate limits, context window usage, git branch, and model |
| [**technology-explainer**](plugins/technology-explainer/README.md) | Adapt explanation depth per technology — brief for experts, detailed for learners |

## 📦 Installation <a name="installation"></a>

### 1. Add the marketplace

```bash
/plugin marketplace add artem-from-ua/claude-plugins
```

### 2. Install a plugin

```bash
/plugin install plantuml@artem-from-ua
```

Repeat for each plugin you want.

### 3. Enable auto-updates

Open `/plugin`, select each installed plugin, and enable **auto-update**.

## 🤝 Contributing <a name="contributing"></a>

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow, plugin structure, and code standards.
