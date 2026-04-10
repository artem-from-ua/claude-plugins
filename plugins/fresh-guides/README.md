# Fresh Guides

> [!TIP]
> ✨ ***Don't trust the weights — check the docs.***

Configure a watchlist of fast-changing technologies and Claude automatically verifies advice against official documentation before responding.

Pair with [`technology-explainer`](../technology-explainer/README.md) plugin for full coverage: `fresh-guides` controls *how reliably* Claude answers (checking official docs), `technology-explainer` controls *how much* it explains (depth based on your proficiency).

> [!NOTE]
> [📦 Installation](#installation) · [⚙️ How it works](#how-it-works) · [🎮 Commands](#commands) · [📝 Config](#config)

## 🎬 Demo <a name="demo"></a>

Configure your watchlist:

```markdown
> /fresh-guides-setup

Welcome! **Fresh Guides** keeps a watchlist of technologies that change
frequently — where model training data may be outdated.

? Which technologies should be on your watchlist?
  terraform, aws terraform provider

? Official doc URLs for **terraform**?
  [*] https://developer.hashicorp.com/terraform/docs
  [*] https://github.com/hashicorp/terraform/releases
  [ ] Other (enter URL)

? Official doc URLs for **aws terraform provider**?
  [*] https://registry.terraform.io/providers/hashicorp/aws/latest/docs
  [*] https://github.com/hashicorp/terraform-provider-aws/releases
  [ ] Other (enter URL)

? Check mode?
  ❯ alert-and-verify (Recommended)
    alert-only

? Config scope?
    Global (~/.claude/fresh-guides.json)
  ❯ Project (.claude-plugin/fresh-guides.json)

Restart your session or run /clear for changes to take effect.
```

Claude verifies before answering:

```markdown
> What's the syntax for terraform import block?

✦ Using skill: fresh-guides-verify

● Bash(terraform version)
  Terraform v1.6.6

The `import` block is supported in your version (v1.6.6, added in v1.5).
[Source: developer.hashicorp.com/terraform/language/v1.6.x/import]

Syntax:

    import {
      to = aws_instance.example
      id = "i-abcd1234"
    }

**Note:** `for_each` inside import blocks requires v1.7+. Your v1.6.6
does not support it — you'll need to write a separate `import` block
per resource. [Source: developer.hashicorp.com/terraform/language/v1.7.x/import]
```

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install fresh-guides@tribe-coding
/plugin
```

Select **fresh-guides** → enable **auto-update**. Then run the setup wizard:

```
/fresh-guides-setup
```

Restart your session for changes to take effect.

## ⚙️ How it works <a name="how-it-works"></a>

| Trigger | What happens |
|---------|-------------|
| SessionStart | Injects compact watchlist into context |
| Watched tech detected | `fresh-guides-verify` skill invoked |
| Version detection | Checks project files and runtime for current version |
| Doc verification | Fetches version-specific official docs via WebFetch/WebSearch |
| Version mismatch | Warns about features unavailable in user's version |
| Verification fails | States "could not verify" with links for manual check |

**Scope:** Verification triggers only for version-specific advice (API signatures, config syntax, defaults, deprecations). General concepts and design patterns are answered normally.


## 🎮 Commands <a name="commands"></a>

| Command | Description |
|---------|-------------|
| `/fresh-guides-setup` | Interactive wizard — configure watchlist and doc URLs |
| `/fresh-guides-show` | Display current watchlist configuration |
| `/fresh-guides-update add <name> <url>` | Add a technology with a doc URL |
| `/fresh-guides-update remove <name>` | Remove a technology from watchlist |
| `/fresh-guides-update url <name> <url>` | Add another URL to an existing technology |

## 📝 Config <a name="config"></a>

Global config: `~/.claude/fresh-guides.json`
Project config: `.claude-plugin/fresh-guides.json` (overrides global)

```json
{
  "watchlist": [
    {
      "name": "terraform",
      "docs": [
        "https://developer.hashicorp.com/terraform/docs",
        "https://github.com/hashicorp/terraform/releases"
      ]
    },
    {
      "name": "aws terraform provider",
      "docs": [
        "https://registry.terraform.io/providers/hashicorp/aws/latest/docs",
        "https://github.com/hashicorp/terraform-provider-aws/releases"
      ]
    }
  ]
}
```

| Field | Description | Default |
|-------|-------------|---------|
| `watchlist[].name` | Technology identifier (matched case-insensitive) | — |
| `watchlist[].docs` | Official doc / changelog / release note URLs | — |
