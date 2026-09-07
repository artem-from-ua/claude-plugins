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

The distinction matters most where the two are entangled in one paragraph. "Colors are `#b60205` for `type:bug` and a red→orange→lime gradient for priority" is checkable and goes. "One color per axis, because the prefix already carries identity — except priority, where color carries urgency instead" is not checkable from the document: it will show you *that* the colors are what they are, never that this was a decision rather than an accident. Split the paragraph; keep the half that survives the test.

**Why this is stated as a test rather than a prohibition.** An earlier version of this template asked for the axis table inside the Decision section, and it was filled in faithfully — the duplication is invisible while writing, because a table under "Decision" reads exactly like what was decided. It only becomes visible when both documents exist and someone opens them side by side. A template that asks you to fill in a structure is stronger than a rule that asks you not to, so the guidance here is something you can apply to a single line without holding both files in your head.

## Skeleton

```markdown
---
status: draft
date: YYYY-MM-DD
gate: promote to accepted once the taxonomy has been applied to the backlog
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

TODO once applied to the backlog:
- Whether the palette stays legible on real multi-label issues.
- Values that fitted awkwardly and the rules added because of them.
```

## Editing before the record is accepted

While it says `status: draft`, the record is still being written and can be revised freely. Once it is `accepted`, the convention makes it immutable: a wrong decision gets a superseding record, not an edit.

That fixes the order of two things people usually think of as independent. **Any tidying — trimming what belongs in the document, fixing a stale count — happens before promotion, or not at all.** Promote first and the same edit means rewriting an immutable record; the only clean alternative left is a new ADR that supersedes the old one over a copy-paste mistake.

So when the gate is met and the record also needs cleaning, do both in one commit.

## Index row and supersession

If `docs/adr/README.md` exists, add a row in its existing format.

If an ADR about the taxonomy is already there, do **not** write a second one. Propose superseding it: set `superseded_by` on the old record, add a one-line postscript at its top pointing at the replacement, and strike through both the number and the title link in the index — leaving the Status cell readable.

Point `adr` in `.claude-plugin/issue-conventions.json` at the **current** record. A config still naming a superseded one makes every tool that reads that field quote a retired decision.

If the project has no `docs/adr/`, ask whether to start the practice rather than creating the directory unasked. A project without ADRs is not missing anything the taxonomy needs — the document works alone.
