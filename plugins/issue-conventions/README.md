# issue-conventions

> [!TIP]
> ✨ ***Issue labels rot quietly. So do the docs that describe them.***

Your issue tracker has labels nobody agrees on: the ones in heavy use narrow nothing, and the rest nobody ever applied. This designs a taxonomy from what you actually work on, writes it down, and applies it to every issue you already have.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [📦 Installation](#installation) · [⚡ Commands](#commands) · [⚙️ Setup](#setup) · [📝 Config](#config) · [📚 Reference](#reference) · [🔗 Dependencies](#dependencies)

## 🎬 Demo <a name="demo"></a>

**Designing the taxonomy** — reads the issues, proposes the axes, asks you to settle the rest:

```markdown
> /issue-conventions-setup

Scanned 157 issues (84 closed, 73 open) and 16 labels.

[a short interview: which axes describe your work — the parts of the product,
 the kinds of change, the urgency — offered as candidates mined from the scan,
 plus the ambiguous issues it wants you to settle once so it stops asking]

Wrote issue taxonomy proposal to docs/issue-labels.md · created 38 labels · deleted 9 GitHub built-ins
```

**Applying it to the backlog** — proposes, you review, then it applies:

```markdown
> /issue-conventions-relabel

Classified 157 issues in 9 batches. Review at /tmp/relabel-review.md.

⚠️ Needs your decision (4)
  #100  root cause is upstream, but the fix landed in plugins/retroscope/
        → plugin:retroscope   → no plugin value

Batch 1 of 9                                     current → proposed
  #285  Fix 2 broken documentation links      documentation → type:bug
        └ PR #292 changed kb-structural-scan.sh (+61/-5) — a scanner fix
  #293  Fix root README nav line              documentation → type:feature
        └ PR #298 changed presets/readme.md — executable preset content

Apply batch 1? [y/n/edit]
```

Note the two `type:docs` proposals that are not `type:docs`: the title records the symptom, the pull request records the work.

## ⚙️ How it works <a name="how-it-works"></a>

**Two workflows, in order.**

The first reads every issue in the repository — open and closed alike — and proposes a label taxonomy from what it finds. It mines the recurring subjects, the parts of the product that get filed against, and the existing labels that stopped narrowing anything, then interviews you about the calls it cannot make alone and writes the result as a document in your repo ([example](../../docs/issue-labels.md)). The GitHub labels are created from that document.

This wants dozens of issues at minimum, and reads best at a hundred or more. Below thirty the plugin says so and lets you continue anyway — with that little history a taxonomy is guessed from the code layout rather than derived from what the maintainers actually do.

The second applies the taxonomy to the issues you already have. It classifies all of them, proposes labels and — if you ask for it — retitled subjects, and hands you a review document in batches rather than a fait accompli. When you rewrite a proposal it asks whether that was a one-off or a rule; a rule goes into the document and is re-applied to everything already classified, so each correction is paid for once. Nothing reaches GitHub until you approve it, and the backup written beforehand contains the commands to undo it.

### Where the truth lives

The taxonomy lives as a **schema-constrained markdown document in your repository** — not in a JSON config, and not in `CLAUDE.md`. That choice drives everything else:

- **A taxonomy is a set of decisions people read and argue about.** JSON is unreadable, and generating a human-facing document from it creates a second source that drifts from the first — the exact failure this plugin exists to catch.
- **When the document and GitHub disagree, the document wins.** Editing it by hand is a legitimate way to change the taxonomy; the plugin propagates the change to GitHub, never the reverse.
- **Rules do not sit in your `CLAUDE.md`.** A label section there loads into every session, including the majority that never touch issues.

The skill is a **dispatcher**: about fifty lines of routing that decide which subagent handles what. The rules and the issue bodies stay in the subagent, so neither reaches your session context. A conditional `SessionStart` hook adds a short block — where the taxonomy lives, when to invoke the skill, how to check for drift — and only in repositories that have one configured, costing nothing everywhere else. Its text is fixed rather than computed, so it does not invalidate the prompt cache on every session start.

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

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add artem-from-ua/claude-plugins
/plugin install issue-conventions@artem-from-ua
```

## ⚡ Commands <a name="commands"></a>

| Command | What it does |
|---|---|
| `/issue-conventions-setup` | Interviews you, writes the taxonomy document, creates the labels |
| `/issue-conventions-relabel` | Classifies the existing backlog, reviews it in batches, applies with reconciliation |
| `/issue-conventions-drift` | Read-only: reports what disagrees between the document and GitHub |

The `issue-conventions-guide` skill runs on its own before any `gh issue create`, `gh issue edit`, `gh issue close`, or label change.

### What `relabel` does differently

Classifying a backlog is not the expensive part — reviewing it is. So when you rewrite a proposed classification, the command asks whether it was a one-off or a rule. A rule gets written into the document's disambiguation section and **re-applied to the already-classified issues immediately**, without re-running classification. Rules accumulated this way make the next run cheaper and bind the skill for every new issue.

It also reads the pull request that closed each issue, not just the title and body. A title records the symptom someone reported; the diff records the work that answered it, and those disagree more often than they look like they would — "Fix 2 broken documentation links" turned out to be a fix to a scanner that was emitting false positives, which makes it a bug, not documentation. For an axis derived from directories the paths settle the label outright: a change under `plugins/retroscope/` *is* `plugin:retroscope`.

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
  "titleFormat": { "enabled": true, "rewriteExisting": false },
  "prEvidence": { "mode": "paths" },
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

`prEvidence.mode` decides how much of a closed issue's pull request the classifier sees, and setup asks for it rather than assuming. `paths` (the default) passes the changed files ranked by size — about 300 characters per issue, and for an axis derived from directories it is not evidence but the answer. `full` adds the PR's title, the head of its description, and its `Closes #N` line: three times the size, worth it mainly on the type axis, where the author's own words settle what the paths only imply. `off` classifies from the title and body alone, which is the right call for a backlog whose issues are rarely closed by PRs.

Resolution order: `.claude-plugin/issue-conventions.json` → `.claude/issue-conventions.json` → `~/.claude/issue-conventions.json` → the plugin's `templates/issue-conventions.json`.

### The document may run ahead of the plugin

Unknown sections and unknown columns are ignored rather than rejected, so a document can use syntax the installed version does not know yet. Verified on a real document: a `## Rule exceptions` section added before upgrading parsed cleanly under the older parser — no warning, no error, all axes and labels intact — and started taking effect once the plugin caught up.

This is worth knowing because the intuition runs the other way. There is no ordering requirement between updating the plugin and updating the document: add the section whenever it is convenient.

## 📚 Reference <a name="reference"></a>

- [`docs/ACCEPTANCE_TESTS.md`](docs/ACCEPTANCE_TESTS.md) — test suite, plus what three live migrations taught: which checks earned their place, which one was written and abandoned after measuring it, and the traps that produce a confident wrong answer instead of an error.

Three test scripts run without network or credentials, on synthetic fixtures: `test-drift-jq.sh` pins the semantics of the drift expressions, `test-pr-evidence.sh` pins which pull request counts as evidence, and `test-scale.sh` guards the batch size against a dump large enough to break it.

## 🔗 Dependencies <a name="dependencies"></a>

`gh` (authenticated), `jq`, `python3`, `git`.

The `python3` dependency is the taxonomy document parser — one implementation of the contract, shared by the commands and the drift check, so nothing invents its own regexes. It fails with the offending line number rather than guessing, and it is tolerant by default: unknown columns and unknown sections are ignored, so adding prose or a column of your own does not break the document.
