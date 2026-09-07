# issue-conventions

> [!TIP]
> ✨ ***Design the taxonomy once. Keep it honest forever.***

Designs an issue label and title taxonomy for your repository, writes it as a document in your repo, applies it to the existing backlog, and detects when the document, the GitHub labels, and the ADR drift apart. Recommended once a project has around 30 issues — before that there is not enough material to see what the maintainers actually work on.

> [!NOTE]
> [📦 Installation](#installation) · [⚙️ How it works](#how-it-works) · [⚡ Commands](#commands) · [⚙️ Setup](#setup) · [📝 Config](#config) · [🔗 Dependencies](#dependencies)

## 🎬 Demo <a name="demo"></a>

```markdown
> /issue-conventions-drift

Drift check — 4 findings · source of truth: docs/issue-labels.md

DOCUMENT ↔ GITHUB
- `dependencies`, `python:uv` exist on GitHub but not in the document (Dependabot created them).
  Fix: add them under "Legacy label mapping" as `keep`, or delete them from GitHub.
- 3 issues have no priority label — #201, #244, #289. Fix: /issue-conventions-relabel

DOCUMENT ↔ ADR
- ADR 0029 states 7 values for the area axis; the document has 8 (`area:repo` came later).
  Fix: update the ADR table, or supersede it.

INFO
- Soft limit is 5; median labels per issue is 4. Healthy — no action.
- 5 declared values are unused (3 stages, 2 closing reasons). Expected, not a defect.
```

## ⚙️ How it works <a name="how-it-works"></a>

The taxonomy lives as a **schema-constrained markdown document in your repository** — not in a JSON config, and not in `CLAUDE.md`. That choice drives everything else:

- **A taxonomy is a set of decisions people read and argue about.** JSON is unreadable, and generating a human-facing document from it creates a second source that drifts from the first — the exact failure this plugin exists to catch.
- **When the document and GitHub disagree, the document wins.** Editing it by hand is a legitimate way to change the taxonomy; the plugin propagates the change to GitHub, never the reverse.
- **Rules do not sit in your `CLAUDE.md`.** A label section there loads into every session, including the majority that never touch issues.

The skill is a **dispatcher**: about fifty lines of routing that decide which subagent handles what. The rules and the issue bodies stay in the subagent, so neither reaches your session context. A conditional `SessionStart` hook prints three lines — and only in repositories that have a taxonomy configured, costing nothing everywhere else.

```
docs/issue-labels.md          ← source of truth (markdown, in git, read by people and machines)
        ↑ read by
   subagent (instructions in references/ and templates/)
        ↑ launched by
skills/issue-conventions-guide/   ← dispatcher: routing only, no rules
        ↑ path from
.claude-plugin/issue-conventions.json   ← thin config: operational settings
        ↓
GitHub labels                 ← derived state, synced to the document
```

## ⚡ Commands <a name="commands"></a>

| Command | What it does |
|---|---|
| `/issue-conventions-setup` | Interviews you, writes the taxonomy document, drafts an ADR, creates the labels |
| `/issue-conventions-relabel` | Classifies the existing backlog, reviews it in batches, applies with reconciliation |
| `/issue-conventions-drift` | Read-only: reports what disagrees between the document, GitHub, and the ADR |

The `issue-conventions-guide` skill runs on its own before any `gh issue create`, `gh issue edit`, `gh issue close`, or label change.

### What `relabel` does differently

Classifying a backlog is not the expensive part — reviewing it is. So when you rewrite a proposed classification, the command asks whether it was a one-off or a rule. A rule gets written into the document's disambiguation section and **re-applied to the already-classified issues immediately**, without re-running classification. Rules accumulated this way make the next run cheaper and bind the skill for every new issue.

## ⚙️ Setup <a name="setup"></a>

```bash
/issue-conventions-setup
```

The wizard scans your repo for candidates — directory structure for a structural axis, recurring topics across issue titles for a topical one — and offers them in every question. Nothing is imposed: axis names, dictionaries, colors, and mandatory rules are all yours to set. Only `type:*` and `priority:*` come pre-filled, and the palette assigns one color per axis so the prefix carries identity while the color carries the axis.

The disambiguation pass near the end is the highest-value step. It picks genuinely ambiguous issues and asks where they belong; each answer becomes a rule. Rules settled here are review rounds not spent later.

## 📝 Config <a name="config"></a>

`.claude-plugin/issue-conventions.json` — thin by design; it holds no dictionaries.

```json
{
  "version": 1,
  "taxonomyDocument": "docs/issue-labels.md",
  "adr": "docs/adr/0038-taxonomy-storage.md",
  "titleFormat": { "enabled": true, "rewriteExisting": false },
  "thresholds": { "minIssues": 30 },
  "models": { "classifyNew": "sonnet", "reclassify": "sonnet",
              "batchClassify": "sonnet", "driftCheck": "haiku" },
  "efforts": { "classifyNew": "medium", "reclassify": "medium",
               "batchClassify": "medium", "driftCheck": "low" },
  "batchSize": 18,
  "review": { "location": "ask" }
}
```

`titleFormat` splits deliberately: `enabled` makes title rules apply to new issues, while `rewriteExisting` controls mass renaming of the existing backlog — the least reversible thing this plugin can do, so it stays off until you turn it on.

`adr` accepts a single path or an array. Point it at the **current** record, not the one that started the chain: ADRs supersede each other, and a config still naming a superseded record makes every tool that reads it quote outdated numbers. With an array, the first entry is the current one and the rest are history.

Resolution order: `.claude-plugin/issue-conventions.json` → `.claude/issue-conventions.json` → `~/.claude/issue-conventions.json` → the plugin's `templates/issue-conventions.json`.

### The document may run ahead of the plugin

Unknown sections and unknown columns are ignored rather than rejected, so a document can use syntax the installed version does not know yet. Verified on a real document: a `## Rule exceptions` section added before upgrading parsed cleanly under the older parser — no warning, no error, all axes and labels intact — and started taking effect once the plugin caught up.

This is worth knowing because the intuition runs the other way. There is no ordering requirement between updating the plugin and updating the document: add the section whenever it is convenient.

## 🔗 Dependencies <a name="dependencies"></a>

`gh` (authenticated), `jq`, `python3`, `git`.

The `python3` dependency is the taxonomy document parser — one implementation of the contract, shared by the commands and the drift check, so nothing invents its own regexes. It fails with the offending line number rather than guessing, and it is tolerant by default: unknown columns and unknown sections are ignored, so adding prose or a column of your own does not break the document.
