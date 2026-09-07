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

**Check whether the ADR has been superseded — in whole or in part.** If it has, and its successor documents the same drift, the prescribed fix has *already been carried out*: the divergence is a historical record, not an outstanding defect. Report it as **INFO**, naming the successor — "ADR 0029 states 7 area values against 8 in the document; superseded in part by ADR 0038, which cites this drift as evidence."

Demanding another fix would be wrong twice over: the work is done, and editing the numbers in place would violate the immutability convention the successor itself records. An ADR is a decision as it was made, not a mirror of current state.

**Three signals, any one of which counts.** Checking only `status:` is not enough, and the miss is not an edge case — in the reference project just 3 of 9 superseded records carry that status:

1. `status: superseded` in the frontmatter — a record replaced wholesale.
2. A non-empty `superseded_by` — often present while `status` stays `accepted`.
3. The index row has the number and title **struck through** (`~~N~~`) — sometimes the only place the replacement is recorded, with no `superseded_by` field at all.

**Read the strikethrough for *whether*, the Status cell for *by whom*.** Real rows from the reference project:

```
| ~~24~~ | ~~[Defaults for the safe_speech stage](0024-…md)~~ | accepted (render display superseded by 0025) |
| 25     | [Silence events: unified pause/muted rendering](0025-…md) | accepted (supersedes 0024 render display) |
| ~~29~~ | ~~[Issue label taxonomy: 4 axes](0029-…md)~~ | accepted (storage mechanism superseded by 0038; axes still in force) |
```

The strikethrough is a **structural** marker on the record itself: this row is about a decision that has been replaced. It lives in the first two columns only — the Status cell is deliberately left readable, so that a reader can still scan which record superseded which. The Status cell is **prose**, written by hand in whatever wording fits.

So anchor on the structure and let the prose supply the detail. Verified across all 37 rows of the reference index, both signals agree exactly — but they are not equally safe:

- `supersedes` is not `superseded by`, and the successors are not rare. Five rows say `supersedes`; a naive substring search for "supersede" returns 10 of 37 rows instead of 5, marking every replacement as replaced.
- Even matching `superseded by` exactly depends on a phrasing nobody has promised. "accepted (0029 superseded by this record)" would read naturally on a *successor* row and would fool the phrase check. The strikethrough cannot be fooled that way, because it says something about the row rather than about a relationship.

Take the number from the Status cell once the strikethrough has established that the record was replaced — matching `superseded by NNNN` as a substring anywhere in the cell, since the phrase sits mid-cell inside parentheses and any prefix check would miss it.

**Partial supersession is the common case, and the one that matters most here.** When a record is replaced wholesale, `status` becomes `superseded` and people stop reading it. When only part of it is replaced, the status honestly stays `accepted` — the rest still governs the code — and *that* record keeps being read while its retired half quietly drifts from reality. Exactly the class of stale number this check exists to notice. Reporting it as a defect asks the maintainer to break the immutability convention.

**Parsing `superseded_by` is a trap.** One repo holds three shapes at once — all three are live in the reference project:

```yaml
superseded_by:                                    # YAML list of filenames
  - 0006-mlx-lm-over-lm-studio.md
superseded_by: ["0028-proofread-default-on"]      # JSON array of strings
superseded_by: [0038]                             # JSON array of bare numbers
```

Pull the leading four digits with a regex rather than parsing YAML strictly — strict parsing either throws or silently returns nothing, and silently returning nothing looks exactly like "not superseded".

The number is the identity; the filename is decoration. If you need the successor's file to read it, resolve by globbing `NNNN-*.md` rather than trusting the recorded name — the bare-number form has no name to trust, and a recorded name can be stale after a rename.

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
