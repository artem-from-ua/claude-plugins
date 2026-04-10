# Fresh Guides

> [!TIP]
> ✨ ***Don't trust the weights — check the docs.***

Configure a watchlist of fast-changing technologies and Claude automatically verifies advice against official documentation before responding.

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
  ❯ **Project** (.claude-plugin/fresh-guides.json)

Restart your session or run /clear for changes to take effect.
```

Claude verifies before answering:

```markdown
> What's the syntax for terraform import block?

fresh-guides: **terraform** is on your fast-changing tech watchlist.

✦ Using skill: fresh-guides-verify

The `import` block was introduced in Terraform v1.5. Syntax:

    import {
      to = aws_instance.example
      id = "i-abcd1234"
    }

As of v1.7+, you can also use `for_each` inside import blocks for
bulk imports. [Source: developer.hashicorp.com/terraform/docs, 2026-04-10]
```

View your watchlist:

```markdown
> /fresh-guides-show

| Technology | Official Docs | Version |
|------------|--------------|---------|
| terraform | developer.hashicorp.com/..., github.com/.../releases | latest |
| aws terraform provider | registry.terraform.io/..., github.com/.../releases | latest |

**Check mode:** alert-and-verify
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

Two check modes control Claude's behavior:

| Mode | Behavior |
|------|----------|
| **alert-and-verify** | Alert + fetch official docs + cite sources |
| **alert-only** | Alert the user, skip automatic verification |

| Trigger | What happens |
|---------|-------------|
| SessionStart | Injects compact watchlist + rules into context |
| Watched tech detected | `fresh-guides-verify` skill invoked — fetches docs, compares, cites |
| Docs confirm knowledge | Response includes "Verified against official docs" with citation |
| Docs contradict knowledge | Explicit callout: "My training data may be outdated here" |
| Verification fails | States "could not verify" with links for manual check |

**Scope:** Verification triggers only for version-specific advice (API signatures, config syntax, defaults, deprecations). General concepts and design patterns are answered normally.

**Complements [technology-explainer](../technology-explainer/README.md):** Technology-explainer controls explanation *depth* (brief vs detailed). Fresh-guides controls *accuracy verification* (check docs vs trust weights). A technology can be in both configs.

## 🎮 Commands <a name="commands"></a>

| Command | Description |
|---------|-------------|
| `/fresh-guides-setup` | Interactive wizard — configure watchlist, doc URLs, check mode |
| `/fresh-guides-show` | Display current watchlist configuration |
| `/fresh-guides-update add <name> <url>` | Add a technology with a doc URL |
| `/fresh-guides-update remove <name>` | Remove a technology from watchlist |
| `/fresh-guides-update url <name> <url>` | Add another URL to an existing technology |
| `/fresh-guides-update mode <mode>` | Change check mode (alert-and-verify / alert-only) |

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
      ],
      "version": "latest"
    },
    {
      "name": "aws terraform provider",
      "docs": [
        "https://registry.terraform.io/providers/hashicorp/aws/latest/docs",
        "https://github.com/hashicorp/terraform-provider-aws/releases"
      ],
      "version": "latest"
    }
  ],
  "checkMode": "alert-and-verify"
}
```

| Field | Description | Default |
|-------|-------------|---------|
| `watchlist[].name` | Technology identifier (matched case-insensitively) | — |
| `watchlist[].docs` | Official doc / changelog / release note URLs | — |
| `watchlist[].version` | Version constraint (`"latest"` for now) | `"latest"` |
| `checkMode` | `"alert-and-verify"` or `"alert-only"` | `"alert-and-verify"` |
