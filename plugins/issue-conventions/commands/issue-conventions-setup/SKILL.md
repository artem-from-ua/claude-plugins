---
name: issue-conventions-setup
description: >
  Interactive setup wizard for a GitHub issue label and title taxonomy. Scans the repo
  for module and topic candidates, interviews you on axes, dictionaries, colors, and
  mandatory rules, maps legacy labels, writes a taxonomy document to your repo, and
  creates the labels on GitHub.
  Keywords: issue conventions setup, label taxonomy, configure labels, github labels,
  issue titles, taxonomy design.
---

# Issue Conventions — Setup

Designs a taxonomy for this repository, writes it as a document, and creates the labels.

## Steps

### 1. Preflight

Run `gh auth status` — stop with instructions if it fails. Get the repo with `gh repo view --json nameWithOwner`.

Count issues: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fetch-issues.sh" --count-only`. If the count is below `thresholds.minIssues` (30 by default), use `AskUserQuestion`: **Continue anyway** (the taxonomy will lean on code structure, with weaker evidence for topical axes) or **Postpone**. This is a recommendation, never a block — with fewer issues there is not enough material to see what the maintainers actually work on.

If a config already exists, read it and its document, and pre-fill every answer from **the document**.

### 2. Scan the repo for candidates

Follow `${SKILL_DIR}/references/repo-scan.md`. It produces four lists: structural candidates with a proposed axis name, topical candidates each backed by two real issue numbers, title prefixes already in use, and the existing labels with their usage counts.

### 3. Interview

Run it per `${SKILL_DIR}/references/interview.md` — the full question order, option texts, and defaults live there. Every question offers the step-2 candidates; never an empty prompt.

**Anything shown as a candidate but not chosen goes into `ignore=`**, alongside what step 2 filtered out automatically. Without this the drift check keeps re-raising what the user already declined.

### 4. Look for gaps before confirming

Before showing the axis table, run one cheap pass: **which issues do not fit the dictionary just assembled?** Sample 20–30 across the corpus and ask, per issue, whether any value covers it.

The frequency scan in step 2 cannot find these by construction — it keeps terms recurring in three or more issues, so a surface with one or two loses out. On the second polygon four values had to be added mid-run this way, each covering 1–4 issues, and each addition meant returning to already-classified batches. Finding them here costs one pass; finding them later costs a re-run.

### 5. Draft and confirm

Print the axis table and ask for one confirmation; an edit answer loops back to that question. Alongside the table, **preview the palette on three real issues from this repo**, showing the full label set each would carry — adjacent shades blur only on real multi-label issues, and this is the moment to catch it.

### 6. Map legacy labels

Follow `${SKILL_DIR}/references/legacy-mapping.md`. Build the `old label (usage) → action` table, show the auto-proposals as a list, ask about contested ones individually, and record the result in the document's Legacy label mapping section.

### 7. Choose where the document lives

Propose a path based on what step 2 found (see `repo-scan.md` for the priority order) and confirm it. One document, never two: if `docs/conventions.md` exists it gets a two-line pointer, not a copy of the dictionaries.

Then ask what the classifier may read from the PRs that closed the issues, and write it to `prEvidence.mode`. Say what it buys, since the option names do not: a title records the reported symptom, the diff records the work that answered it, and for a whole class of issues those disagree.

- **`paths`** (default) — files changed, ranked by churn. ~300 characters per issue. For a directory-derived axis this is not evidence but the answer: a change under `plugins/retroscope/` *is* `plugin:retroscope`.
- **`full`** — adds the PR title, the head of its body, and the `Closes #N` / `Refs #N` line. ~900 characters, three times the cost, earned mainly on the type axis where the author's own words settle what the paths imply.
- **`off`** — title and body only. Right for a repo whose issues are rarely closed by PRs, or where two API calls per issue is not worth it — count the closed issues in the dump and say so if that is the case.

### 8. Write the document

Render it per `${CLAUDE_PLUGIN_ROOT}/templates/document-schema.md`, using real issues from this repo as the worked examples. Immediately re-read it with `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/parse-taxonomy.py"` and stop loudly if the round-trip does not reproduce the interview — that is where a generator/parser mismatch surfaces.

**Write every label description to fit 100 bytes of UTF-8** — GitHub's cap, and the text is created on the label verbatim. Count bytes as you write, not after: Cyrillic and emoji cost two to four bytes each, so a description that reads short can still be over. One clause naming what the value covers is the right size; a second clause listing what it also includes is what pushes it over, and that belongs in a disambiguation rule instead. Discovering the cap from a parse error means rewriting descriptions already reasoned about.

**Then read the dictionaries back and ask, of each pair: is there an artifact both descriptions would accept?** Not "do they look similar" — name a concrete thing and see whether two values claim it. `type:test` written as "tests, including acceptance test documentation" and `type:docs` as "README, docs/, SKILL.md prose" share no word, yet every `ACCEPTANCE_TESTS.md` edit satisfies both. That is why the check has to be a question about cases rather than a comparison of text, and why it cannot be a parser check: the parser sees two structurally valid rows with nothing in common.

Each collision found is either a description to narrow or a line for `## Disambiguation rules` — decided now, while the dictionary is being written, not later by a classifier that stalls on the case and has no authority to settle it.

If the project's `CLAUDE.md` has a label section, show it and ask permission to cut it. **Never write anything to CLAUDE.md automatically.**

### 9. Record the decision, if the project keeps ADRs

Only when `docs/adr/` already exists. Per `${SKILL_DIR}/references/adr-template.md`, the record says one thing: the taxonomy now lives at `<path>`, maintained by this plugin. **Not** the axes, dictionaries, colors, or rules — those are in the document, and an ADR that copies them starts drifting from it immediately.

If no `docs/adr/` exists, ask whether to start the practice; a project without ADRs is not missing anything the taxonomy needs.

### 10. Create the labels

Back up first: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup.sh"` — deletion is irreversible.

Then `bash "${CLAUDE_PLUGIN_ROOT}/scripts/label-plan.sh" <document> --summary`, show the itemized plan, and take **one** `AskUserQuestion` (Apply / Show details / Cancel). Apply with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/label-plan.sh" <document> --apply`. Labels reported as undeclared are never auto-deleted — report them and let the user decide.

**Create labels now; delete nothing until `/issue-conventions-relabel` has run.** That covers legacy labels **and the GitHub built-ins** — `bug`, `enhancement`, `documentation` are usually the most informative input the classifier gets, and they are built-ins rather than custom labels, so a rule mentioning only "legacy" would read as permission to remove them.

`gh label delete` strips the label from every issue that carried it, permanently, and `relabel` classifies *from* those labels. The `split` action depends on them entirely: without `enhancement` on an issue, the classifier has only the title, and the criterion in the Why column has nothing to apply to.

If the built-ins are unused — the second polygon's nine were all empty — deleting them early costs nothing. Check the usage counts from step 2 before deciding, rather than assuming either way.

So: create and update here, and say plainly that removing the old labels is the last step of the migration, not part of this one.

Write today's date into the document footer's sync row.

### 11. Drift check

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/drift-check.sh" <document>` and have the drift subagent report it. A fresh setup must show **zero divergences**; INFO findings are expected. Finish by pointing at `/issue-conventions-relabel`.
