---
name: issue-conventions-setup
description: >
  Interactive setup wizard for a GitHub issue label and title taxonomy. Scans the repo
  for module and topic candidates, interviews you on axes, dictionaries, colors, and
  mandatory rules, maps legacy labels, writes a taxonomy document to your repo, drafts
  an ADR, and creates the labels on GitHub.
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

Follow `${SKILL_DIR}/references/repo-scan.md`. It produces three lists: structural candidates with a proposed axis name, topical candidates each backed by two real issue numbers, and the existing labels with their usage counts.

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

### 8. Write the document

Render it per `${CLAUDE_PLUGIN_ROOT}/templates/document-schema.md`, using real issues from this repo as the worked examples. Immediately re-read it with `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/parse-taxonomy.py"` and stop loudly if the round-trip does not reproduce the interview — that is where a generator/parser mismatch surfaces.

If the project's `CLAUDE.md` has a label section, show it and ask permission to cut it. **Never write anything to CLAUDE.md automatically.**

### 9. Draft the ADR

Per `${SKILL_DIR}/references/adr-template.md`: `status: draft`, a named gate, filled Context and Decision, alternatives seeded from the interview, and `TODO` markers where post-application experience belongs. If an ADR about the taxonomy already exists, propose superseding it rather than adding a second. If there is no `docs/adr/`, ask whether to start the practice. Promoting draft → accepted is the user's call, after seeing the labels on a real backlog.

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
