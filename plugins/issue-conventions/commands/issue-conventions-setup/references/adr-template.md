# ADR draft

The ADR records **one decision: where the taxonomy lives and who maintains it.** Not what is in it.

## Why so little

An ADR that reproduces the axis tables has copied the document. Two copies of the same dictionary drift the moment either changes — and then the plugin has to detect that drift, decide which copy wins, and tell a stale number apart from a wrong one. All of that work exists only because the copy was made.

The document is the source of truth. The ADR is the record of *choosing* it as such. So it names the file and stops.

What belongs in the ADR:

- The problem: labels were ad hoc, or inconsistent, or absent — with the counts that made it a problem.
- The decision: a taxonomy now exists, it lives at `<path>`, and it is applied by this plugin.
- Alternatives rejected during the interview, with reasons — including any that were about *placement* (a section in CONTRIBUTING, a wiki page, labels alone with no document).
- Consequences: what this enables, what it costs, what has to be maintained.

What does not: axis names, value dictionaries, colors, cardinality rules, disambiguation rules, the title pattern. Every one of those is in the document, one link away, and always current there.

**The test, applied line by line: could a reader learn this by opening the document?** If yes, it belongs there and not here. If no — if it is *why* the choice was made rather than what the choice is — it belongs here and nowhere else.

The distinction matters most where fact and reason are entangled in one paragraph. "Colors are `#b60205` for `type:bug` and a red-to-lime gradient for priority" is checkable and goes. "One color per axis, because the prefix already carries identity — except priority, where color carries urgency instead" is not checkable from the document: it will show you *that* the colors are what they are, never that this was a decision rather than an accident. Split the paragraph; keep the half that survives the test.

**A number that measures is not a number that defines.** The test rejects "seven `area:*` values" — that is the dictionary, restated, and it is wrong the moment an eighth is added. It keeps "150 of 210 issues landed on `priority:medium`, and 9 needed a human decision": the document does not know those figures and never will, because they describe the backlog on the day it was labeled, not the taxonomy. Measurements are dated observations and belong in Consequences; definitions belong in the document. Do not strip the first while removing the second.

## Skeleton

```markdown
---
<frontmatter in whatever shape this project's ADRs use>
---

# NNNN. Issue taxonomy lives in a versioned document

## Context

<What was wrong: N labels, M ever used, K of L issues unlabelled; which operations
that broke — filtering by component, sorting by urgency, searching closed issues.
Who applies labels: humans, AI assistants, automation. Why an informal convention
was not enough.>

## Decision

The issue label and title taxonomy is defined in [`<path>`](<path>), maintained by
the `issue-conventions` plugin.

That document is the single source of truth. When it and the GitHub labels
disagree, the document wins; the plugin propagates the change to GitHub, never the
reverse. Editing it by hand is a legitimate way to change the taxonomy — the
commands exist to keep the labels in step, not to hold a monopoly on the rules.

## Alternatives considered

<Options rejected during the interview, each with its reason. Placement choices
belong here: a section in an existing conventions file, a wiki page, GitHub label
descriptions alone. So do process choices: no taxonomy, or one enforced only by
review.>

## Consequences

**Positive:** <one command filters the backlog by component; release-blocking work
is visible at a glance; AI assistants read the rules from one place.>

**Negative:** <the document is one more artifact to keep current; a label created
in the GitHub UI is drift until someone runs the check.>
```

## Fitting into a practice that already exists

If `docs/adr/README.md` exists, add a row in its existing format.

If an ADR about the taxonomy is already there, do **not** write a second one alongside it. Say so, and let the maintainer decide what to do with the old record — whether an accepted ADR may be edited, and how a replacement is linked to what it replaces, is that project's convention. This plugin has no opinion on it and should not offer one.

If the project has no `docs/adr/`, ask whether to start the practice rather than creating the directory unasked. A project without ADRs is not missing anything the taxonomy needs — the document works alone.
