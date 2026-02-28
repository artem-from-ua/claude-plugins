# Technology Explainer

> [!TIP]
> ✨ ***Claude adapts how it explains things — brief for what you know, detailed for what you're learning.***

Configure your proficiency level per technology and Claude automatically adjusts its explanation depth: expert gets terse answers, learning gets theory and examples.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [🎮 Commands](#commands) · [📝 Config](#config)

## 🎬 Demo

```
> /technology-explainer-update git expert

Updated **git** → **expert**.

> /technology-explainer-update terraform learning

Updated **terraform** → **learning**.
```

After restarting:

```
> How does git stash work?

✦ Using skill: proficiency-guide-expert

`git stash` / `git stash pop`. List: `git stash list`. Keep stash after apply: `git stash apply`.

> How do Terraform modules work?

✦ Using skill: proficiency-guide-learning

**Terraform modules** are reusable containers for related resources. Think of them
like functions in programming — they take inputs (variables), create resources, and
return outputs.

A module is simply a directory with `.tf` files. You call it using a `module` block:

    module "vpc" {
      source  = "./modules/vpc"
      cidr    = "10.0.0.0/16"
    }

`source` tells Terraform where to find the module — a local path, Git URL, or
Terraform Registry address. Variables go in `variables.tf`, outputs in `outputs.tf`.

**Common mistake:** forgetting to run `terraform init` after adding a new module —
Terraform needs to download the module source before it can plan.

See: HashiCorp docs on modules → https://developer.hashicorp.com/terraform/docs
```

## ⚙️ How it works <a name="how-it-works"></a>

Three proficiency levels control Claude's explanation depth:

| Level | Behavior | Example |
|-------|----------|---------|
| **Expert** | Brief, no-theory answers | Just the command or fact |
| **Intermediate** | Nuances and gotchas, skip basics | Why this approach, common pitfalls |
| **Learning** | Detailed theory, examples, step-by-step | Full explanations with context |

| Trigger | What happens |
|---------|-------------|
| SessionStart | Injects compact tech lists (~60-80 tokens) + pointers to level-specific skills |
| Explaining expert tech | `proficiency-guide-expert` skill invoked — brief response rules |
| Explaining intermediate tech | `proficiency-guide-intermediate` skill invoked — nuance-focused rules |
| Explaining learning tech | `proficiency-guide-learning` skill invoked — detailed teaching rules |

**Scope:** Rules apply ONLY to conversational explanations in the terminal. Code comments, docstrings, and project documentation follow project conventions.

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install technology-explainer@tribe-coding
/plugin
```

Select **technology-explainer** → enable **auto-update**. Then run the setup wizard:

```
/technology-explainer-setup
```

Restart your session for changes to take effect.

## 🎮 Commands <a name="commands"></a>

| Command | Description |
|---------|-------------|
| `/technology-explainer-setup` | Interactive wizard — configure all levels, default, and sources |
| `/technology-explainer-show` | Display current proficiency configuration |
| `/technology-explainer-update <tech> <level>` | Change a technology's level |
| `/technology-explainer-update default <level>` | Change the default level for unlisted technologies |
| `/technology-explainer-update source <tech> <url>` | Add a custom documentation source |

## 📝 Config <a name="config"></a>

Global config: `~/.claude/technology-explainer.json`

```json
{
  "technologies": {
    "expert": ["linux", "mac", "git", "shell scripting"],
    "intermediate": ["docker", "k8s", "jira"],
    "learning": ["terraform", "aws", "python"]
  },
  "defaultLevel": "learning",
  "sources": {
    "terraform": ["https://developer.hashicorp.com/terraform/docs"],
    "python": ["PEP 8 style guide", "Google Python style guide"]
  }
}
```

| Field | Description | Default |
|-------|-------------|---------|
| `technologies.expert` | Brief, no-theory answers | `[]` |
| `technologies.intermediate` | Nuances and gotchas | `[]` |
| `technologies.learning` | Detailed theory + examples | `[]` |
| `defaultLevel` | Level for unlisted technologies | `"learning"` |
| `sources` | Preferred docs/style guides per technology | `{}` |
