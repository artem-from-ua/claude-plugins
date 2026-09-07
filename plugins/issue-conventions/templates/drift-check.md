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
| `violations` | divergence | issues breaking cardinality, a cross-axis rule, or the soft limit — run `/issue-conventions-relabel` |
| `builtinsPresent` | divergence | GitHub re-created a built-in it was told to delete; delete again |
| `unusedValues` | **INFO** | a declared value nobody uses. **Not a defect** — zero use of a closing reason only means nothing was closed that way. Never report it as a divergence, or the report becomes noise people learn to skip |

## What you decide

**ADR vs document.** Read the ADR if there is one. Does it still describe the taxonomy in the document — same axes, same value counts, same rules? Prose counts ("seven values", "a dictionary of 13") are the most common drift: they are written once and never updated. Report a mismatch as a divergence whose fix is "update the ADR, or supersede it with a new one" — never "edit the document to match the ADR". If parsing a stated count is ambiguous, report it as INFO rather than guessing.

**The script has already decided whether the ADR was superseded** — read `forSubagent.adrStatus`, do not re-derive it:

```json
{ "number": "0029", "status": "accepted", "superseded": true, "partial": true,
  "supersededBy": ["0038"], "signals": ["index-strikethrough", "superseded_by"] }
```

`superseded` is the verdict, `partial` distinguishes a record replaced wholesale from one that gave up only part of itself, and `supersededBy` names the successor. What remains yours is the judgment: **if the record was superseded and its successor documents the same drift, the prescribed fix has already been carried out.** Report it as INFO, naming the successor — "ADR 0029 states 7 area values against 8 in the document; superseded in part by ADR 0038, which cites this drift as evidence."

If `adrStatus` is absent, no ADR is configured and there is nothing to compare against.

Demanding another fix would be wrong twice over: the work is done, and editing the numbers in place would violate the immutability convention the successor itself records. An ADR is a decision as it was made, not a mirror of current state.

**Why the script decides this and not you.** The three signals are deterministic — `status: superseded`, a non-empty `superseded_by`, or the number and title struck through in the index — so they live in `adr-status.sh`, where a test can pin them. Prose in this file cannot be regression-tested: reword a paragraph and the behavior changes while every test stays green.

The one thing worth knowing about that logic: **partial supersession is the common case here.** In the reference project only 3 of 9 superseded records carry `status: superseded`; the rest stay `accepted` because just part of them was replaced, and one names its successor solely through the index strikethrough. Those are the records that keep being read while their retired half drifts — exactly what this check exists to notice.

**Frontmatter disagreeing with the index is its own finding.** A record whose frontmatter says `superseded` while the index says `accepted (superseded by NNNN)` — or the reverse — means someone updated one and forgot the other. Report it as **INFO**, separately: it is not a taxonomy problem, but it is the kind of drift that makes every later check unreliable.

**Documented norm vs the corpus.** Compare `softLimit` against `labelCountDistribution`. A soft limit of 5 with a median of 4 is healthy. A limit of 5 where most issues carry 6 means the limit is fiction. State it as INFO with the actual median, and let the user choose between restating the limit and accepting the de-facto norm.

**Modules without an axis** (only when `moduleAxis` is set). Compare `modulesOnDisk` against the values of that axis. A module is covered when it matches a value's name, **is mentioned in a value's description** (one value often covers two or three modules), or appears in `modulesIgnored`. Only genuinely uncovered modules are a finding, and the fix is "add a value, or add it to `ignore=`". Read the descriptions before reporting — this is where false positives come from.

**Title scopes that name nothing** (`titleScopes`). The title-format regex accepts any word between the parentheses, so `feat(whatever): …` is well-formed while naming a scope that does not exist in any axis. The script lists these; you decide what each one means. There are three kinds, and only the first is a defect:

- **A scope that will never exist** — it names infrastructure the taxonomy deliberately excluded, something in the axis's `ignore=`, or a typo. Finding: propose the closest real value. (Seen in practice: `research(pipeline)` where `pipeline` was ignored as infrastructure.)
- **A scope that does not exist *yet*** — the issue is *proposing* the very thing it names, typically a new pipeline stage or component. `feat(followup): add a follow-up stage` reads better than forcing it onto an existing value, and the labels can carry a cross-cutting axis until the stage ships. **INFO, not a defect** — unless the project has decided otherwise in its disambiguation rules. Any pipeline-shaped project accumulates these.
- **A scope the document allows by rule** — check the disambiguation rules before reporting; a project may have settled this case already.

**Footer freshness.** `footer.lastSynced` against the document's last commit date (`git log -1 --format=%cI -- <document>`). Do not use file mtime: in a fresh clone every file looks modified. A document edited after the last sync means GitHub may not have caught up — INFO, with `/issue-conventions-drift` or `/issue-conventions-setup` as the fix.

## The report

Group by what the user must decide. Every finding names the two sources that disagree and one concrete fix.

```
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

Everything agreeing gets one line: `Drift check: the taxonomy document, GitHub labels, and the ADR agree.`
