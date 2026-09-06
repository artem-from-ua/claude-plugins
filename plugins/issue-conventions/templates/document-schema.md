# Taxonomy document schema

The taxonomy document in the target repository is the **source of truth**. This file is the contract: the exact structure `parse-taxonomy.py` reads, the subagents apply, and the drift check verifies. It doubles as the skeleton `/issue-conventions-setup` renders.

When the document and the live GitHub labels disagree, **the document wins**. A hand edit is a legitimate way to change the taxonomy; the plugin's job is to propagate it to GitHub, never the reverse.

## Required structure

Headings are the parse anchors. Their level, wording, and order are fixed.

**Required sections:** `## Axes`, `## Cross-axis rules`, `## Values`, `## Disambiguation rules`, `## Worked examples`.

**Optional sections:** `## Title format`, `## Legacy label mapping`, `## GitHub built-in labels`.

## Skeleton

````markdown
# Issue taxonomy

<One or two sentences: what this project is and what the taxonomy is for.>

## Axes

| Axis | Prefix | Mandatory | Cardinality | Color | Applies to |
|---|---|---|---|---|---|
| type | `type:` | yes | exactly one | `#cccccc` | all |
| priority | `priority:` | yes | exactly one | gradient | all |
| plugin | `plugin:` | no | zero or more | `#0052cc` | all |
| topic | `topic:` | no | zero or more | `#52a373` | all |
| reason | `reason:` | no | zero or more | `#cccccc` | closed only |
| by | `by:` | no | zero or more | `#cccccc` | all |

**Scope:** issues only. PRs are not labeled.

## Cross-axis rules

- at-least-one: plugin, topic
- soft-limit: 5

Every issue needs at least one `plugin:*` or `topic:*`; beyond five labels an issue is usually doing too much and is a candidate to split.

## Values

### `type:*`

| Label | Description | Color |
|---|---|---|
| `type:bug` | Something is broken or behaves incorrectly against documented expectations. | `#b60205` |
| `type:feature` | A new user-visible capability. | |
| `type:perf` | Speed or memory improvement, with or without visible behavior change. | |
| `type:docs` | Changes only to README, docs/, or in-code comments. | |
| `type:refactor` | Internal restructuring with no user-visible change and no perf claim. | |
| `type:test` | Adding, fixing, or restructuring tests. | |
| `type:chore` | Tooling, build, deps, repo hygiene, CI. | |

### `priority:*`

| Label | Description | Color |
|---|---|---|
| `priority:critical` | Broken for users right now, or about to be. Fix before anything else. | `#b60205` |
| `priority:high` | Should land in the next release cycle. | `#e8814a` |
| `priority:medium` | Default for most work. Use this if unsure. | `#bfd62c` |
| `priority:low` | Nice to have. | `#cccccc` |

### `plugin:*`

<!-- source: modules path=plugins ignore=_internal,testdata -->

| Label | Description | Color |
|---|---|---|
| `plugin:playbook` | `plugins/playbook/` — coding guideline presets. | |

### `topic:*`

| Label | Description | Color |
|---|---|---|
| `topic:conventions` | Repo-wide conventions: authoring rules, structure, naming. | |

### `reason:*`

| Label | Description | Color |
|---|---|---|
| `reason:duplicate` | Closing reason: already tracked in another issue. | |
| `reason:invalid` | Closing reason: out of scope, misunderstanding, not a real issue. | |
| `reason:wontfix` | Closing reason: acknowledged but explicitly decided not to fix. | |

### `by:*`

| Label | Description | Color |
|---|---|---|
| `by:kb-grooming` | Filed by the kb-grooming automation. | |

## Disambiguation rules

- **`type:feature` vs `type:refactor`** — only `type:feature` when a user can observe the change. Renames and internal restructuring are `type:refactor`.
- **Catch-all guard** — repo housekeeping goes to its own topic value, never to the nearest product-facing one.

## Worked examples

| Issue | Labels | Why |
|---|---|---|
| #324 `feat(issue-conventions): plugin for label taxonomy` | `type:feature`, `priority:medium`, `plugin:issue-conventions` | New user-visible capability scoped to one plugin. |

## Title format

**Pattern:** `[CRITICAL ]<type>(<scope>): <subject>`

| Element | Source | Rule |
|---|---|---|
| `<type>` | the `type:*` value without its prefix | `feat`, `fix`, `perf`, `docs`, `refactor`, `test`, `chore` |
| `<scope>` | a structural or topical axis value | where the effect lands for the user, not where the code lives; one per title |
| `<subject>` | — | what the user gets, not how it is implemented |
| `CRITICAL` | `priority:critical` | optional prefix modifier |

`epic` and `research` are title-only types: they have no `type:*` label, and the underlying work is still classified by its base type.

**Length:** 60–80 characters, soft. Self-containment beats brevity — if trimming a word makes the title ambiguous without reading the labels, keep the word.

**Exempt:** issues carrying a `by:*` label keep whatever title the automation produced.

## Legacy label mapping

| Old label | Action | New label | Why |
|---|---|---|---|
| `documentation` | map | `type:docs` | Direct equivalent. |
| `enhancement` | split | — | Feature vs refactor vs chore depends on user visibility. |
| `wip` | delete | | Superseded by issue state. |
| `dependencies` | keep | | Created by Dependabot; not ours to manage. |
| `phase-1` | migrate | | Roadmap stage — a milestone, not a label. |

## GitHub built-in labels

Policy: **delete**. Exceptions kept: none.

---

<!-- issue-conventions:managed -->
> **Do NOT edit this file by hand.** Run `/issue-conventions-setup` to change the taxonomy and `/issue-conventions-relabel` to apply it to existing issues. Hand edits are honored — this document is the source of truth — but the plugin cannot guarantee that GitHub labels and this file agree until you re-run those commands.

| | |
|---|---|
| Config | `.claude-plugin/issue-conventions.json` |
| Plugin | `issue-conventions` v0.1.2 |
| Last synced with GitHub | YYYY-MM-DD |
<!-- /issue-conventions:managed -->
````

## Parse rules

| Rule | Behavior |
|---|---|
| Anchors | The five required sections must be present. Optional sections may be absent. |
| Axis order | Row order in the `## Axes` table defines axis order; the `Axis` cell is the canonical name. |
| Mandatory vocabulary | `yes` / `no`. |
| Cardinality vocabulary | Exactly three strings: `exactly one`, `at least one`, `zero or more`. Anything else is a parse error. |
| Applies-to vocabulary | `all` / `closed only` / `open only`. |
| Color | Three valid forms: `#rrggbb` in backticks, the word `gradient` (only in the Axes table), **or an empty cell** — inherit the axis color. A per-value color overrides the axis color. |
| Label names | Backtick-quoted in the Values tables; the prefix must match its axis prefix, otherwise a parse error. |
| Description required | An empty Description cell is a parse error. Every label carries a description. |
| Values sections | Every row of the Axes table must have a matching `### ` section. Extra `### ` sections are ignored. |
| Cross-axis rules | Machine-readable, since axis names are project-specific: `- at-least-one: a, b`, `- soft-limit: N`, `- mutually-exclusive: a, b`. Lines not starting with a known key are prose and are ignored. |
| `<!-- source: ... -->` | Optional, under an axis `### ` heading. Key `source` is required, value `modules` or `manual`. For `modules`, `path=<repo-relative path>` is required (one path) and `ignore=<comma list>` is optional — modules deliberately left out of the axis; drift check skips them. An unknown `source` value is treated as `manual`, without error. |
| Tolerance | **Unknown columns and unknown sections are ignored, not errors.** Someone adding an `Owner` column or a `## Notes` section must still get a working document. Strictness applies only where it is unavoidable: cardinality vocabulary, prefix match, description presence. |
| Footer | The `<!-- issue-conventions:managed -->` marker is expected; its absence is a **warning, not an error** — a hand-written document should still work. |
| Failure mode | A parse error reports the line number and the expected shape. **Never guess**: stop and point at the line. |
