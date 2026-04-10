---
name: fresh-guides-setup
description: >
  Interactive setup wizard for fast-changing technology watchlist. Creates or updates
  ~/.claude/fresh-guides.json or .claude-plugin/fresh-guides.json. Run this command
  to configure which technologies require doc verification.
  Keywords: fresh-guides setup, configure watchlist, fast-changing technology, doc verification.
---

# Fresh Guides Setup

Configure which technologies Claude should verify against official docs before giving advice.

## Steps

### 1. Educational intro

Explain to the user:

> **Fresh Guides** keeps a watchlist of technologies that change frequently — where model training data may be outdated. When you ask about a watched technology, Claude will:
> 1. Detect which version you're running
> 2. Fetch the official docs for that version to verify its answer
> 3. Cite sources and warn about version-specific limitations

Give examples: AWS services (new features every week), Terraform providers (breaking changes between versions), Kubernetes (deprecation cycles), CI/CD tools (frequent major releases).

### 2. Show existing config

Read `~/.claude/fresh-guides.json` and `.claude-plugin/fresh-guides.json` (if in a project). If either exists, display the current watchlist as a table:

| Technology | Official Docs |
|------------|--------------|
| terraform | developer.hashicorp.com/terraform/docs |

If neither exists, say "No watchlist configured yet — let's create one."

### 3. Ask for technologies

Use `AskUserQuestion` with a free-text option. Ask:

> "Which technologies should be on your watchlist? These are tools/services where you want Claude to always check official docs before answering."

Suggest categories: cloud providers (AWS, GCP, Azure), IaC tools (Terraform, Pulumi), container orchestration (Kubernetes, ECS), CI/CD platforms, rapidly-evolving frameworks.

### 4. For each technology, discover and propose doc URLs

For each technology the user listed:

1. **Generate candidate URLs** based on the technology name. Use well-known patterns:
   - terraform → `https://developer.hashicorp.com/terraform/docs`, `https://github.com/hashicorp/terraform/releases`
   - aws terraform provider → `https://registry.terraform.io/providers/hashicorp/aws/latest/docs`, `https://github.com/hashicorp/terraform-provider-aws/releases`
   - kubernetes → `https://kubernetes.io/docs/`, `https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/`
   - For other technologies, construct likely official doc URLs

2. **Probe each candidate** with `WebFetch` to verify it resolves successfully. Only include URLs that actually work.

3. **Present as checkboxes** via `AskUserQuestion`: list the working URLs as `[*]` pre-selected options, plus an `[ ] Other (enter URL)` option for the user to add custom URLs.

4. If no candidate URLs resolve, ask the user to provide URLs manually.

### 5. Ask for config scope

Use `AskUserQuestion`:
- **Global** (`~/.claude/fresh-guides.json`) — applies to all projects
- **Project** (`.claude-plugin/fresh-guides.json`) — applies only to this project

If the user chooses project scope, check that `.claude-plugin/` directory exists (create if needed).

### 6. Write config and confirm

Write the config file with the collected data. Display a summary table with all configured technologies and their doc URLs:

| Technology | Official Docs |
|------------|--------------|
| terraform | developer.hashicorp.com/terraform/docs, github.com/.../releases |
| aws terraform provider | registry.terraform.io/..., github.com/.../releases |

Then confirm:

```
Restart your session or run /clear for changes to take effect.
```
