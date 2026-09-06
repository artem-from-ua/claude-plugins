# Apply with reconciliation

Applying the approved review is where data gets lost if the details are wrong. Three of these rules come from mistakes already made by hand.

## Never trust the review document's "Current" column

The document was written before the batch was reviewed, and review takes time. Labels may have changed since — by another session, by automation, by the user in the UI.

For every issue, re-read live state first:

```bash
gh api "repos/$REPO/issues/$N" --jq '[.labels[].name]'
```

Compute the delta against **that**, not against the document. A diff taken from stale state silently reverts whatever happened in between.

## Compute the delta narrowly

```
toAdd    = proposed − live
toRemove = (live − proposed) ∩ (labels the taxonomy owns ∪ labels in the legacy mapping)
```

The intersection is the important half. A label that is neither declared in the document nor named in the legacy mapping belongs to someone else — Dependabot's `dependencies`, a workflow's own marker — and stripping it is not this command's business.

## Apply additively

```bash
gh issue edit "$N" --add-label "a,b" --remove-label "c"
```

Never `--label`: it **replaces** the whole set, wiping anything not in the list. Both flags in one call keeps cardinality intact — a separate remove-then-add leaves the issue briefly with two values of a single-value axis, and a failure between the two calls leaves it that way for good.

Titles only when title rewriting was enabled and the issue carries no provenance label:

```bash
gh issue edit "$N" --title "$NEW_TITLE"
```

## Pace the calls

`sleep 0.5` between issues. Two hundred issues at one or two calls each sits inside the 5000/hour limit, but a CI run competing for the same token does not care about that arithmetic. Check headroom before a large batch:

```bash
gh api rate_limit --jq '.resources.core | "\(.remaining)/\(.limit)"'
```

## Verify after each batch

Re-fetch the batch and assert the mandatory rules — exactly one value for each single-value axis, at least one where a cross-axis rule requires it, no more than the soft limit. Print offending issue numbers; the expected result is an empty list.

Spot-check three random issues from the first two batches in the GitHub UI before speeding up. Colors and label crowding read differently there than in a terminal table, and this is the last cheap moment to notice.

## If something goes wrong

`backup.sh` wrote `ROLLBACK.md` in the backup directory: label recreation commands with original colors and descriptions, and per-issue label restoration. Point at it rather than improvising a fix.
