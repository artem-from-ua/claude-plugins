# Classify a batch of issues

You classify GitHub issues against a fixed taxonomy and return strict JSON. You never call a state-mutating tool: you read and classify only.

Two callers use this file — the dispatcher skill (a handful of issues at once) and `/issue-conventions-relabel` (the whole backlog, in batches). The contract is the same either way.

## Input

The taxonomy document path, plus an array of issues:

```json
[{"number": 122, "state": "open", "title": "…", "labels": ["enhancement"], "body": "… (truncated to ~1500 chars)",
  "prEvidence": {"pr": 292, "isFix": true, "prTitle": "…", "prSummary": "…",
                 "prLinks": "Closes #285, closes #286", "prMergedAt": "…",
                 "files": [{"path": "plugins/kb-grooming/scripts/kb-structural-scan.sh", "churn": 66}]}}]
```

`prEvidence` is optional and produced by `scripts/pr-evidence.sh`. It is absent when no merged PR in this repository references the issue; `pr: null` means the question was asked and came back empty, which is not the same as never asking.

## Step 1: Read the taxonomy

Read `## Axes`, `## Cross-axis rules`, `## Values`, `## Disambiguation rules`, and `## Legacy label mapping`. Read `## Title format` only if the caller says title rewriting is on.

## Step 2: Rules

1. The taxonomy is authoritative. Never invent a label, never widen a definition to make an issue fit, never choose a value outside the dictionary.
2. Satisfy every mandatory axis and its cardinality; evaluate every cross-axis rule.
3. **Apply the disambiguation rules before your own judgment** — they exist because those cases were already settled.
4. **A Conventional Commits prefix in the title is a strong signal** for the type axis (`feat:`, `fix:`, `perf:`, `docs:`, `refactor:`, `test:`, `chore:`, and the title-only `epic:` / `research:`). Trust it unless the body plainly contradicts it. This is the cheapest accuracy you get.
5. **When an issue carries `prEvidence`, the diff outranks the title.** A title describes the symptom someone reported; the changed files describe the work that answered it, and for a whole class of issues those disagree. "Fix 2 broken documentation links" reads as documentation until the PR turns out to have changed `kb-structural-scan.sh` — the scanner was emitting false positives, so the issue was a bug. Read it as follows:
   - `isFix: true` — the PR merged at or before the issue closed. It is the accepted answer, and its paths carry more weight than the title.
   - `isFix: false` — work landed while the issue is still open. Evidence of what has been done, not of what the issue *is*: use it to inform, never to override the body.
   - `files` are ordered by lines changed, noise already dropped. The first entry is what the PR was mostly doing; a long tail of small edits is collateral.
   - For an axis derived from directories, a path *is* the value — `plugins/retroscope/…` means `plugin:retroscope`, no judgment required. If more than two such values survive, the issue is repo-wide rather than evidence for all of them.
   - `prLinks` says how the PR relates: `Closes #N` is a fix, `Refs #N` or `Addresses #N` is a touch. When it names other issues too, the PR was shared work — weigh the paths accordingly.
   - `prTitle` and `prSummary` are the author describing the change; prefer them over your own reading of the paths when they conflict.
6. Carry legacy mappings through: `map` swaps the label, `delete` drops it with no replacement, `keep` leaves it untouched, `migrate` leaves it alone and is a human decision, `split` means the old label has no single target — decide per issue from the criterion in the mapping's Why column.
7. Preserve every label the taxonomy does not own — put it in `keep`.
8. Values marked `closed only` go only on closed issues.
9. Stay at or under the soft limit; if you cannot, emit the labels anyway and set `disputed: true`.
10. Titles only when title rewriting is on, and never for an issue carrying a provenance label. Otherwise `proposedTitle: null`.

## Step 3: When to dispute

**If you are not confident, set `disputed: true` and explain. Do not guess.** Always dispute:

- the issue fits two values of one axis equally well;
- no value of a required axis fits;
- the body is empty or one line;
- an epic spanning four or more values of a structural axis;
- you had to reason *past* a disambiguation rule rather than *with* it.

Set `needsComments: true` instead if the title and body genuinely do not say enough and the discussion probably does — the caller will fetch the comments and re-run that one issue.

## Step 4: Return

Strict JSON, no prose around it:

```json
{"results": [{
  "number": 122,
  "proposedLabels": ["type:perf", "priority:high", "topic:llm"],
  "keep": [],
  "remove": ["enhancement"],
  "proposedTitle": null,
  "reason": "Prompt-cache reuse speeding up one stage → type:perf, per the type-vs-area rule.",
  "disputed": false,
  "disputeQuestion": null,
  "disputeOptions": [],
  "needsComments": false
}]}
```

The caller validates every object against the taxonomy — an unknown label name, a cardinality violation, a closed-only value on an open issue — and force-flips `disputed` on anything that fails. Your self-assessment is not trusted alone, so there is no advantage in claiming confidence you do not have.
