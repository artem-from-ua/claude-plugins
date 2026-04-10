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
> 1. Alert you that this tech is on the watchlist
> 2. Fetch the latest official docs to verify its answer
> 3. Cite sources with URLs and dates

Give examples: AWS services (new features every week), Terraform providers (breaking changes between versions), Kubernetes (deprecation cycles), CI/CD tools (frequent major releases).

### 2. Show existing config

Read `~/.claude/fresh-guides.json` and `.claude-plugin/fresh-guides.json` (if in a project). If either exists, display the current watchlist as a table:

| Technology | Official Docs | Version |
|------------|--------------|---------|
| terraform | developer.hashicorp.com/terraform/docs | latest |
| aws-lambda | docs.aws.amazon.com/lambda/ | latest |

If neither exists, say "No watchlist configured yet — let's create one."

### 3. Ask for technologies

Use `AskUserQuestion` with a free-text option. Ask:

> "Which technologies should be on your watchlist? These are tools/services where you want Claude to always check official docs before answering."

Suggest categories: cloud providers (AWS, GCP, Azure), IaC tools (Terraform, Pulumi), container orchestration (Kubernetes, ECS), CI/CD platforms, rapidly-evolving frameworks.

### 4. For each technology, ask for doc URLs

For each technology the user listed, use `AskUserQuestion` to collect official documentation URLs. Suggest sensible defaults based on the technology name:

- terraform → `https://developer.hashicorp.com/terraform/docs`, `https://github.com/hashicorp/terraform/releases`
- aws-* → `https://docs.aws.amazon.com/<service>/`
- kubernetes → `https://kubernetes.io/docs/`, `https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/`

Accept multiple URLs per technology (docs, release notes, changelog).

### 5. Ask for check mode

Use `AskUserQuestion`:
- **alert-and-verify** (Recommended) — Claude alerts AND fetches official docs to verify
- **alert-only** — Claude alerts but does not automatically fetch docs

### 6. Ask for config scope

Use `AskUserQuestion`:
- **Global** (`~/.claude/fresh-guides.json`) — applies to all projects
- **Project** (`.claude-plugin/fresh-guides.json`) — applies only to this project

If the user chooses project scope, check that `.claude-plugin/` directory exists (create if needed).

### 7. Write config and confirm

Write the config file with the collected data. Display a summary:

```
Watchlist saved to ~/.claude/fresh-guides.json

| Technology | Docs | Version |
|------------|------|---------|
| terraform  | developer.hashicorp.com/..., github.com/... | latest |

Check mode: alert-and-verify

Restart your session or run /clear for changes to take effect.
```
