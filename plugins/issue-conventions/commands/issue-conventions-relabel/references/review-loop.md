# The review loop

Two things live here: the format of the review document, and the mechanism that turns an edit into a rule. The second is what makes this command worth running.

## Document format

One section per batch of 15–20 issues. Disputed items are hoisted to the **top of their batch** so the user scans only those.

````markdown
# Relabel review — owner/repo

Batch 1 of 6 · 18 issues · taxonomy: docs/issue-labels.md

## ⚠️ Needs your decision

### #118 — Add structured logging to the transcode step

| | Current | Proposed |
|---|---|---|
| **Labels** | `enhancement` | `type:feature`, `priority:medium`, **?** |

Fits `topic:observability` and `stage:transcode` about equally — is this the logging
subsystem, or that stage's behavior?

Options: `topic:observability` · `stage:transcode` · both

---

## Confident

### #122 — perf(llm): reuse mlx-lm prompt cache

| | Current | Proposed |
|---|---|---|
| **Labels** | `enhancement` | `type:perf`, `priority:high`, `stage:proofread` |
| **Title** | perf(llm): reuse mlx-lm prompt cache | perf(proofread): 3x speedup via prompt cache reuse |

**Why:** speedup landing on one stage → `type:perf` + the stage, per the type-vs-topic rule.
````

The Title row appears only when title rewriting was enabled in step 4.

After writing the file, print its path and say: edit the Proposed cells directly, then say "apply batch 1" or "apply all".

## Learning from edits

Re-read the file after the user edits it. For every proposal that changed, compare it against what the classifier returned and ask:

> #118: you moved it from `topic:observability` to `stage:transcode`. One-off, or a rule?

**One-off** — apply it to that issue and move on.

**Rule** — ask for it in one sentence, offering a phrasing derived from the edit itself ("issues about a stage's own logging go to that stage, not to the observability topic"). Then:

1. Append it to the document's `## Disambiguation rules`.
2. **Re-apply just that rule to the already-classified issues.** It is narrow — it concerns two named values — so scan only the issues carrying either one, rather than re-running classification. Seconds, against minutes for a full re-run of 200 issues.
3. Show what changed as a result, and carry on with the next batch.

Rules accumulated this way are what make the next run cheaper: they stay in the document and bind the skill for every new issue, not just this pass.

## Changing the taxonomy mid-pass is normal

Adding an axis or a value halfway through is expected, not an error — say so rather than treating it as a mistake. Handle it: update the document, re-parse, create any new labels on GitHub, re-classify only the **remaining** batches, and offer a fix-up pass over the batches already applied.

## Batch pacing

The first two batches apply one at a time with a pause, so mistakes surface while they are cheap. From the third onward, offer to apply the rest in one go — by then the accumulated rules have usually taken the classifier's error rate down to the tail.
