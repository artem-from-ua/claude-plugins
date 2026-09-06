# Repo scan — mining candidates

The interview must never open with an empty prompt. This scan produces the candidates every question offers.

## 1. Structural candidates, and what to call the axis

The axis name comes from how the product is built, not from a fixed vocabulary. Detect the layout, then propose both a name and its dictionary:

| What the repo looks like | Proposed axis | Dictionary from |
|---|---|---|
| `plugins/*/`, `packages/*/`, `apps/*/` | `plugin:` / `package:` / `app:` | directory names |
| A pipeline of modules under `src/<pkg>/` | `stage:` | module names |
| `internal/`, `cmd/`, `pkg/` (Go) | `component:` | directory names |
| Layered app (`ui/`, `core/`, `infra/`) | `layer:` | directory names |
| Nothing structural stands out | ask, defaulting to a topical axis only | — |

Scan `src/<pkg>/*`, `plugins/*`, `packages/*`, `lib/`, `pkg/`, `cmd/`, `internal/`, `app/`. Exclude names starting with `_`, `__init__`, and anything test-shaped. Rank by file size plus git churn (`git log --format= --name-only | sort | uniq -c | sort -rn`). Cap at 15 candidates.

**Record what you filtered out** — it goes into the axis's `ignore=` so the drift check does not keep re-raising it.

## 2. Topical candidates

From the issue dump: tokenize titles and the first 400 characters of bodies, drop terms already claimed by the structural axis, and keep nouns recurring in three or more issues.

Present each with two real issue numbers as evidence — `llm — seen in #122, #78`. A candidate nobody can point at is a candidate nobody needs.

**Always offer a housekeeping value** (`repo`, `meta`, or similar) explicitly. Without one, repo-maintenance issues drift into the nearest product-facing value and quietly turn it into a catch-all — the single most common way these taxonomies rot.

## 3. Existing labels

`gh label list --limit 200 --json name,description,color` plus usage counts from the dump. This feeds the legacy mapping in step 5.

Flag the nine GitHub built-ins (`bug`, `enhancement`, `documentation`, `duplicate`, `invalid`, `wontfix`, `question`, `good first issue`, `help wanted`) separately from custom ones — they need a policy decision, not a per-label one.

## 4. Provenance sources

Look for automation that files issues, and propose a provenance value for each: `.github/dependabot.yml`, workflows under `.github/workflows/`, an existing `kb-grooming` label or `.claude-plugin/kb-grooming.json`.

## 5. Where the document should live

| Detected | Proposal |
|---|---|
| `docs/` and `docs/conventions.md` both exist | `docs/issue-labels.md`, plus a two-line pointer in `conventions.md` |
| `docs/` exists, no `conventions.md` | `docs/issue-labels.md` |
| No `docs/`, but `.github/` exists | `.github/ISSUE_LABELS.md` |
| Neither | `ISSUE_LABELS.md` at the repo root |

Always confirm with the detected proposal pre-selected, and offer a free-text path.
