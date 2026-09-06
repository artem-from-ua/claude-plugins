# Drift check — the judgment half

`scripts/drift-check.sh` has already run the mechanical checks (set operations over JSON, no model needed). You receive its output and finish the job: interpret what needs judgment, then write the report.

**The taxonomy document is the source of truth.** Every fix you propose pulls GitHub, the ADR, or the prose up to the document — never the reverse. A hand edit to the document is a legitimate way to change the taxonomy.

## Input

The JSON from `drift-check.sh`, with two parts: `mechanical` (findings already decided) and `forSubagent` (raw material for the checks below). You also get the taxonomy document path and, if the project has one, the ADR path.

## What the script already found

Report these as they are — no re-derivation:

| Field | Severity | Fix to state |
|---|---|---|
| `missingOnGitHub` | divergence | `gh label create --force` with the document's color and description |
| `undeclaredOnGitHub` | divergence | add to the document, add to the legacy mapping as `keep`, or delete from GitHub |
| `metadataDrift` | divergence | someone edited a label in the GitHub UI; `gh label create --force` restores the document's values |
| `violations` | divergence | issues breaking cardinality, a cross-axis rule, or the soft limit — run `/issue-conventions:relabel` |
| `builtinsPresent` | divergence | GitHub re-created a built-in it was told to delete; delete again |
| `unusedValues` | **INFO** | a declared value nobody uses. **Not a defect** — zero use of a closing reason only means nothing was closed that way. Never report it as a divergence, or the report becomes noise people learn to skip |

## What you decide

**ADR vs document.** Read the ADR if there is one. Does it still describe the taxonomy in the document — same axes, same value counts, same rules? Prose counts ("seven values", "a dictionary of 13") are the most common drift: they are written once and never updated. Report a mismatch as a divergence whose fix is "update the ADR, or supersede it with a new one" — never "edit the document to match the ADR". If parsing a stated count is ambiguous, report it as INFO rather than guessing.

**Documented norm vs the corpus.** Compare `softLimit` against `labelCountDistribution`. A soft limit of 5 with a median of 4 is healthy. A limit of 5 where most issues carry 6 means the limit is fiction. State it as INFO with the actual median, and let the user choose between restating the limit and accepting the de-facto norm.

**Modules without an axis** (only when `moduleAxis` is set). Compare `modulesOnDisk` against the values of that axis. A module is covered when it matches a value's name, **is mentioned in a value's description** (one value often covers two or three modules), or appears in `modulesIgnored`. Only genuinely uncovered modules are a finding, and the fix is "add a value, or add it to `ignore=`". Read the descriptions before reporting — this is where false positives come from.

**Footer freshness.** `footer.lastSynced` against the document's last commit date (`git log -1 --format=%cI -- <document>`). Do not use file mtime: in a fresh clone every file looks modified. A document edited after the last sync means GitHub may not have caught up — INFO, with `/issue-conventions:drift` or `/issue-conventions:setup` as the fix.

## The report

Group by what the user must decide. Every finding names the two sources that disagree and one concrete fix.

```
Drift check — 4 findings · source of truth: docs/issue-labels.md

DOCUMENT ↔ GITHUB
- `dependencies`, `python:uv` exist on GitHub but not in the document (Dependabot created them).
  Fix: add them under "Legacy label mapping" as `keep`, or delete them from GitHub.
- 3 issues have no priority label — #201, #244, #289. Fix: /issue-conventions:relabel

DOCUMENT ↔ ADR
- ADR 0029 states 7 values for the area axis; the document has 8 (`area:repo` came later).
  Fix: update the ADR table, or supersede it.

INFO
- Soft limit is 5; median labels per issue is 4. Healthy — no action.
- 5 declared values are unused (3 stages, 2 closing reasons). Expected, not a defect.
```

Everything agreeing gets one line: `Drift check: the taxonomy document, GitHub labels, and the ADR agree.`
