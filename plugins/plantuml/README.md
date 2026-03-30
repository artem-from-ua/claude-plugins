# PlantUML

> [!TIP]
> ✨ ***Add diagrams to your docs and conversations — Claude picks the type, format, and keeps them in sync.***

With this plugin, Claude proactively illustrates architecture, flows, and data structures using [Mermaid](https://mermaid.js.org/) or [PlantUML](https://plantuml.com): in markdown documentation and directly in the terminal during conversations. Mermaid is preferred when supported — it renders natively in GitHub, Obsidian, and Excalidraw without external services.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [🗑️ Uninstall](#uninstall)

## 🎬 Demo <a name="demo"></a>

A developer asks Claude to document the login flow. Claude picks Mermaid (native rendering), writes the diagram, and draws an ASCII version in conversation.

### Step 1 — Claude writes `docs/auth.md` with a Mermaid diagram

```markdown
> Document the login flow for the auth service.

✦ Using skill: plantuml-diagram-guide

I'll create docs/auth.md. The flow involves four actors — I'll use a Mermaid sequence diagram.

● Write(docs/auth.md)
  ┌───────────────────────────────────────────────────────────────────┐
  │ # Auth Service                                                    │
  │                                                                   │
  │ ## Login Request Flow                                             │
  │                                                                   │
  │ ```mermaid                                                        │
  │ sequenceDiagram                                                   │
  │     title Login Request Flow                                      │
  │     participant User                                              │
  │     participant Web as Web App                                    │
  │     participant API as Auth API                                   │
  │     participant DB as PostgreSQL                                  │
  │                                                                   │
  │     User->>Web: POST /login                                       │
  │     Web->>API: forward credentials                                │
  │     API->>DB: SELECT user WHERE email = ?                         │
  │     DB-->>API: user row                                           │
  │     API-->>Web: 200 OK + token                                    │
  │     Web-->>User: redirect + set cookie                            │
  │ ```                                                               │
  └───────────────────────────────────────────────────────────────────┘

⏺ Done — docs/auth.md created. The diagram renders natively in GitHub and Obsidian.
```

### Step 2 — Later in conversation, Claude draws ASCII (no API call)

```markdown
> Walk me through the login flow step by step.

Here's the full flow:

  User          Web App        Auth API      PostgreSQL
   │               │               │               │
   │ POST /login   │               │               │
   │──────────────>│               │               │
   │               │ forward creds │               │
   │               │──────────────>│               │
   │               │               │ SELECT user   │
   │               │               │──────────────>│
   │               │               │   user row    │
   │               │               │<──────────────│
   │               │  200 + token  │               │
   │               │<──────────────│               │
   │ redirect +    │               │               │
   │ set cookie    │               │               │
   │<──────────────│               │               │

The flow is straightforward: credentials go in, token comes back.
```

### PlantUML still works for types Mermaid doesn't support

```markdown
> Add a deployment diagram showing the infrastructure.

✦ Using skill: plantuml-diagram-guide

Deployment diagrams are PlantUML-only. I'll use PlantUML with an auto-synced image URL.

● Write(docs/deployment.md)
  ┌──────────────────────────────────────────────────────────────┐
  │ ```plantuml                                                   │
  │ @startuml                                                     │
  │ title Production Deployment                                   │
  │ node "AWS" {                                                  │
  │   node "ECS" { component "Auth API" }                         │
  │   database "RDS" { component "PostgreSQL" }                   │
  │ }                                                             │
  │ @enduml                                                       │
  │ ```                                                           │
  │                                                               │
  │ ![Production Deployment](https://www.plantuml.com/plantuml/…) │
  └──────────────────────────────────────────────────────────────┘
```

## ⚙️ How it works <a name="how-it-works"></a>

**Mermaid diagrams** need only a fenced `mermaid` code block — no image URL. Renderers (GitHub, Obsidian, Excalidraw) handle it natively. The PostToolUse hook validates Mermaid syntax on save.

**PlantUML diagrams** have two parts: a `plantuml` source block and an image URL below it. Claude writes both — you only edit the source. When you save, the URL updates automatically.

| Trigger | What happens |
|---------|-------------|
| SessionStart | Injects dual-format diagram rules (Mermaid preferred, PlantUML fallback) |
| PostToolUse (Write/Edit on `.md`) | Auto-syncs PlantUML image URLs; validates Mermaid syntax |
| PreToolUse | Auto-allows PlantUML encoding operations — no permission prompts |
| Before creating any diagram | `plantuml-diagram-guide` skill invoked — picks the right type and format from 26 options |

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install plantuml@tribe-coding
/plugin
```

Select **plantuml** → enable **auto-update**. Restart your session — done.

**Requirements:** Python 3.6+

## 🗑️ Uninstall <a name="uninstall"></a>

The plugin installs a pre-commit hook section that validates diagram syntax before each commit. To remove it from a project:

```
/plantuml-uninstall
```

This removes only the plantuml section from your pre-commit hook. If other hook sections exist (eslint, prettier, etc.), they are preserved. If the plantuml section was the only content, the hook file is deleted entirely.
