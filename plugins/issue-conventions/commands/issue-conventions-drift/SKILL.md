---
name: issue-conventions-drift
description: >
  Check that the issue taxonomy document and the GitHub labels still agree.
  Read-only — reports divergences and the fix for each, mutates nothing. Run it when the
  taxonomy document was edited by hand, when labels were changed in the GitHub UI, or
  periodically to catch silent drift.
  Keywords: issue conventions drift, taxonomy drift, check labels, validate taxonomy,
  label audit, labels out of sync.
---

# Issue Conventions — Drift Check

Read-only. Reports what disagrees and how to fix it; changes nothing, so it is safe to run any time.

## Steps

### 1. Load the taxonomy

Resolve the config (`.claude-plugin/` → `.claude/` → `~/.claude/`) and take `taxonomyDocument`.

No config → say this repo has no taxonomy and point at `/issue-conventions-setup`. A document that fails to parse **is itself the finding**: report the line the parser names, since a document nothing can read is the worst drift there is.

### 2. Run the mechanical half

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/drift-check.sh" <document>
```

Set operations over JSON — labels declared but missing on GitHub, labels on GitHub nobody declared, color and description drift, issues breaking the rules, unused values, resurrected built-ins. No model needed for any of it.

### 3. Finish with the subagent

Launch it with `${CLAUDE_PLUGIN_ROOT}/templates/drift-check.md` as instructions and the script's JSON as input, using `models.driftCheck` and `efforts.driftCheck` (haiku/low by default — half the work is already done, what remains is interpretation).

It decides the parts that need judgment: whether a documented norm survives contact with the actual corpus, whether modules on disk are genuinely uncovered, and whether the footer's sync date is stale. Then it writes the report.

### 4. Report

Show the subagent's report as it comes. Do not soften it and do not act on it — this command reports, the user decides.

Two things it must get right, and both are in the subagent's instructions: **the document is the source of truth**, so every fix pulls GitHub up to it, never the reverse. And **unused values are INFO, not divergences** — a closing reason nobody used means nothing was closed that way, and reporting it as a problem trains people to skip the report.

When everything agrees, that is one line, not a table.

## Fixing what it finds

- Labels missing on GitHub, or color and description drift → `/issue-conventions-relabel` reconciles them in its second step, or `gh label create --force` directly.
- Issues breaking the rules → `/issue-conventions-relabel`.
- Undeclared labels on GitHub → a decision: add to the document, record as `keep` in the legacy mapping, or delete from GitHub.
