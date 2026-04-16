# Mermaid

> [!TIP]
> ✨ ***Native markdown diagrams, validated on save — Claude picks the type, draws, and catches syntax errors.***

With this plugin, Claude proactively adds [Mermaid](https://mermaid.js.org) diagrams to your markdown docs. They render natively in GitHub, Obsidian, VS Code, and most modern viewers — no image URL, no round-trip. Every edit is validated against Kroki so syntax errors surface immediately.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [🗑️ Uninstall](#uninstall) · [📚 Reference](#reference)

## 🎬 Demo <a name="demo"></a>

A developer asks Claude to document the login flow. Claude picks a sequence diagram, writes it inline, and the validator confirms the block parses.

```markdown
> Document the login flow for the auth service.

✦ Using skill: mermaid-diagram-guide

I'll create docs/auth.md. Four actors and a request/response pattern — sequence diagram.

● Write(docs/auth.md)
  ┌────────────────────────────────────────────────────────┐
  │ # Auth Service                                         │
  │                                                        │
  │ ## Login Request Flow                                  │
  │                                                        │
  │ ```mermaid                                             │
  │ sequenceDiagram                                        │
  │     title: Login Request Flow                          │
  │     actor User                                         │
  │     participant Web                                    │
  │     participant API                                    │
  │     participant DB                                     │
  │     User->>Web: POST /login                            │
  │     Web->>API: forward credentials                     │
  │     API->>DB: SELECT user WHERE email = ?              │
  │     DB-->>API: user row                                │
  │     API-->>Web: 200 + token                            │
  │     Web-->>User: redirect + cookie                     │
  │ ```                                                    │
  └────────────────────────────────────────────────────────┘

⏺ Done — docs/auth.md created. Block validated by Kroki. GitHub/Obsidian will render it inline.
```

## ⚙️ How it works <a name="how-it-works"></a>

A Mermaid diagram is a single fenced ` ```mermaid ` block. Unlike PlantUML, there is no separate image URL — the target viewer renders the source directly.

| Trigger | What happens |
|---------|-------------|
| SessionStart | Injects diagram formatting rules and the mermaid-vs-plantuml decision guide |
| PostToolUse (Write/Edit on `.md`) | Validates every `mermaid` block by POSTing to Kroki; reports syntax errors to stderr |
| SessionStart (in a git repo) | Installs a pre-commit hook section that blocks commits with invalid mermaid syntax |
| Before creating any diagram | `mermaid-diagram-guide` skill invoked automatically — picks the right type from 6 common options |

### When to pick Mermaid vs PlantUML

- **Mermaid**: GitHub/Obsidian-bound docs, simple flowcharts, quick sequences, lightweight ERD, project gantts. Default for most `.md` documentation.
- **PlantUML**: complex UML (timing, deployment, nwdiag, Salt wireframes), nested components, fine styling, in-terminal ASCII rendering.

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install mermaid@tribe-coding
/plugin
```

Select **mermaid** → enable **auto-update**. Restart your session — done.

**Requirements:** Python 3.x (stdlib only) and network access to `https://kroki.io`. To run offline or avoid rate limits, set `MERMAID_KROKI_URL` to a self-hosted instance:

```bash
docker run -d -p 8000:8000 yuzutech/kroki
export MERMAID_KROKI_URL=http://localhost:8000
```

## 🗑️ Uninstall <a name="uninstall"></a>

The plugin installs a pre-commit hook section that validates Mermaid syntax before each commit. To remove it from a project:

```
/mermaid-uninstall
```

This removes only the mermaid section from your pre-commit hook. Other hook sections (eslint, prettier, plantuml, etc.) are preserved. If the mermaid section was the only content, the hook file is deleted entirely.

## 📚 Reference <a name="reference"></a>

- [`CHANGELOG.md`](CHANGELOG.md) — version history
- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite
- [Mermaid syntax reference](https://mermaid.js.org) — upstream docs
- [Kroki](https://kroki.io) — the validation backend
