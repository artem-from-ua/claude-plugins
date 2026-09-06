---
name: issue-conventions-relabel
description: >
  Relabel existing GitHub issues against the project's taxonomy document. Fetches every
  issue, classifies them with a subagent, produces a reviewable markdown table of current
  versus proposed labels in batches, learns rules from your edits, then applies the
  approved changes with reconciliation against live GitHub state.
  Keywords: relabel issues, mass relabel, apply labels, issue taxonomy migration,
  retag issues, backlog cleanup.
---

# Issue Conventions — Relabel

Classifies the existing backlog against the taxonomy and applies the result in reviewed batches.

## Steps

### 1. Load the taxonomy

Resolve the config (`.claude-plugin/` → `.claude/` → `~/.claude/`), take `taxonomyDocument`, and parse it: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/parse-taxonomy.py" <document>`.

No config → point at `/issue-conventions-setup` and stop. This command never invents a taxonomy. A document that fails to parse → stop and show the reported line; there is no JSON fallback to fall back to.

### 2. Reconcile labels before touching issues

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/label-plan.sh" <document> --summary`. If anything is missing on GitHub, the document was edited by hand and GitHub has not caught up — offer to create the missing labels in one confirmation.

**Skipping this means `gh issue edit --add-label` fails on the first issue** with a label that exists only in the document. Hand edits are legitimate by design, so this is an expected path, not an edge case.

### 3. Fetch the issues

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/fetch-issues.sh"` writes the dump and prints its path. Comments are fetched lazily — only for issues the classifier flags with `needsComments`, via `gh api repos/{owner}/{repo}/issues/N/comments`, because `--json comments` returns empty for some issues.

### 4. Back up, and settle the title question

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup.sh"` — prints the backup directory with a ready `ROLLBACK.md`.

If `titleFormat.enabled` is on but `rewriteExisting` is off, count how many existing titles do not match the documented pattern and ask: rewrite them in this pass / show the list unchanged / leave titles alone. Ask **here**, before classification — the classifier already decides whether to propose a title, so asking later would mean re-running every batch.

### 5. Classify

Launch the subagent with `${CLAUDE_PLUGIN_ROOT}/templates/batch-classify.md` as its instructions, `models.batchClassify` and `efforts.batchClassify` from the config, in batches of `batchSize` (18 by default).

Pass it the document path and the batch — it reads the taxonomy itself. Issue bodies never enter this session; only the returned JSON does.

Validate every returned object against the parsed taxonomy — unknown label, cardinality violation, closed-only value on an open issue — and force `disputed: true` on anything that fails.

### 6. Write the review document

Ask where it goes (`review.location`): a session temp file, or a path in the repo for a review that spans days. Format per `${SKILL_DIR}/references/review-loop.md`.

### 7. Review, and learn from the edits

Full mechanism in `${SKILL_DIR}/references/review-loop.md`. Apply the first two batches one at a time with a pause, then faster.

The core: when the user rewrites a proposal, ask **one-off or rule?** A rule gets written into the document's disambiguation section and **applied to the already-classified issues on the spot**, without re-running classification. This is where the time goes — in the reference project all three review rounds were about rules, and each one meant restarting everything by hand.

### 8. Apply with reconciliation

Algorithm in `${SKILL_DIR}/references/apply-reconcile.md`. Three rules that must not be lost: re-read **live** labels via `gh api` and never trust the review document's "Current" column; never strip a label the taxonomy does not own; use `--add-label`/`--remove-label`, never `--label`.

### 9. Verify and check drift

Re-fetch and assert with `jq` that every issue satisfies the parsed cardinality rules and the soft limit; print violations, expecting none. Update the document footer's sync date. Then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/drift-check.sh" <document>` and report through the drift subagent.
