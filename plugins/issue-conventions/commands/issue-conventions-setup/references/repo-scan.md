# Repo scan — mining candidates

The interview must never open with an empty prompt. This scan produces the candidates every question offers.

**Get the dump first.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fetch-issues.sh"` writes every issue to a file and **prints that file's path, not its contents** — it is a full corpus and belongs on disk, not in the session. Capture the path and read the file; piping the script's own output into a parser gets you one line containing a filename. Sections 2, 3 and 4 below all read this file.

## 1. Structural candidates, and what to call the axis

The axis name comes from how the product is built, not from a fixed vocabulary. Detect the layout, then propose both a name and its dictionary:

| What the repo looks like | Proposed axis | Dictionary from |
|---|---|---|
| `plugins/*/`, `packages/*/`, `apps/*/` | `plugin:` / `package:` / `app:` | directory names |
| A pipeline of modules under `src/<pkg>/` | `stage:` | module names |
| `internal/`, `cmd/`, `pkg/` (Go) | `component:` | directory names |
| Layered app (`ui/`, `core/`, `infra/`) | `layer:` | directory names |
| One flat package — dozens of files, no subdirectories | **no structural axis** | — |
| Nothing structural stands out | ask, defaulting to a topical axis only | — |

**A flat package has no structure to mine, and that is a finding, not a failure.** The second polygon had 90 Swift files directly under `Sources/<Package>/` — no pipeline, no layers, no sub-packages. File names there describe implementation, not the surfaces users file issues about, so an axis built from them would be a worse index than no axis at all. Say so, and go to a topical axis mined from the issues instead. Do not fall back to `stage:` because the reference project used it.

Scan `src/<pkg>/*`, `plugins/*`, `packages/*`, `lib/`, `pkg/`, `cmd/`, `internal/`, `app/`. Exclude names starting with `_`, `__init__`, and anything test-shaped. Rank by file size plus git churn (`git log --format= --name-only | sort | uniq -c | sort -rn`). Cap at 15 candidates.

**Record what you filtered out** — it goes into the axis's `ignore=` so the drift check does not keep re-raising it.

## 2. Topical candidates

From the issue dump: tokenize titles and the first 400 characters of bodies, drop terms already claimed by the structural axis, and keep nouns recurring in three or more issues.

Present each with two real issue numbers as evidence — `llm — seen in #122, #78`. A candidate nobody can point at is a candidate nobody needs.

**Always offer a housekeeping value** (`repo`, `meta`, or similar) explicitly. Without one, repo-maintenance issues drift into the nearest product-facing value and quietly turn it into a catch-all — the single most common way these taxonomies rot.

## 3. Title prefixes already in use

Extract the leading `word:` or `word(scope):` from every title in the dump and count them. A prefix a maintainer has been typing by hand is a distinction they already make, and nobody types one by accident — this is evidence of the same weight as an existing label, arguably better, since a label can be applied once and forgotten while a prefix has to be retyped every time.

Offer any prefix seen three or more times as a candidate `type:*` value beyond the seven Conventional Commits defaults. The third polygon's backlog carried `spike:`, `epic:`, `research:` and `idea:`; all four were real kinds of work the default dictionary had no home for, and they surfaced only in the gap check after the dictionary was already drafted.

Prefixes matching the seven defaults are confirmation, not candidates — note the counts and move on.

## 4. Existing labels

`gh label list --limit 200 --json name,description,color` plus usage counts from the dump. This feeds the legacy mapping in step 5.

Flag the nine GitHub built-ins (`bug`, `enhancement`, `documentation`, `duplicate`, `invalid`, `wontfix`, `question`, `good first issue`, `help wanted`) separately from custom ones — they need a policy decision, not a per-label one.

## 5. Provenance sources

Look for automation that files issues, and propose a provenance value for each: `.github/dependabot.yml`, workflows under `.github/workflows/`, an existing `kb-grooming` label or `.claude-plugin/kb-grooming.json`.

## 6. Where the document should live

| Detected | Proposal |
|---|---|
| `docs/` and `docs/conventions.md` both exist | `docs/issue-labels.md`, plus a two-line pointer in `conventions.md` |
| `docs/` exists, no `conventions.md` | `docs/issue-labels.md` |
| No `docs/`, but `.github/` exists | `.github/ISSUE_LABELS.md` |
| Neither | `ISSUE_LABELS.md` at the repo root |

Always confirm with the detected proposal pre-selected, and offer a free-text path.
