# ADR draft

The plugin writes roughly 70% of an ADR. The remaining 30% is worth more than the 70%, and no interview can reach it — so the draft stops short and says where.

## Why a draft and not a finished record

Evidence from the reference project: in ADR 0029's first commit the blue gradient across the pipeline axis was **the decision** ("so label chips echo upstream/downstream"). Thirty minutes later it was a **rejected alternative** ("rejected after first use: multi-stage issues read as visual noise"). That sentence — the most useful one in the ADR — did not exist until the labels were on real issues in the GitHub UI.

An ADR is immutable by convention: a wrong one is not edited, it is superseded by a whole new record. Auto-emitting `status: accepted` from unvalidated interview answers manufactures permanent records. So the draft ships as `status: draft` with a named gate, and the human promotes it after looking at a labelled backlog.

## What the plugin fills

| Part | Source |
|---|---|
| Number, filename, frontmatter, index row | mechanical — and the part that actually drifts |
| Context | the label census from `gh` (how many labels exist, how many are used, how many issues are unlabelled) plus the operations that are broken today |
| Decision | the axis tables and disambiguation rules from the interview |
| Alternatives considered | every option rejected **during the interview**, with the reason given |
| Consequences | honest and provisional, with `TODO` markers |

## Skeleton

```markdown
---
status: draft
date: YYYY-MM-DD
gate: promote to accepted after the taxonomy has been applied to the existing backlog
---

# NNNN. Issue label and title taxonomy

## Context

<Label census: N labels exist, M ever used, K of L issues unlabelled. Which operations
this breaks — filtering by component, sorting a backlog by urgency, searching closed
issues. Project constraints: team size, who applies labels (humans, AI assistants, or
automation), one-time cost of relabelling.>

## Decision

<The axis table. The dictionaries. The prefix choice and why. The color scheme and why
one color per axis. The mandatory rules. The disambiguation rules that were settled
during the interview. What is explicitly out of scope and why.>

## Alternatives considered

<Every option rejected during the interview, each with its reason. An unnamed cost reads
as one nobody noticed.>

## Consequences

**Positive:** <what now works: one-command filtering, release-blocking backlog visible
at a glance, AI assistants have a single source of truth.>

**Negative:** <the honest costs. A mandatory priority forces a choice on every issue;
the cure — defaulting to medium — risks the axis losing meaning if everything lands there.>

TODO after applying to the backlog:
- Color legibility on real multi-label issues — which shades blurred, if any.
- Values that turned out to fit awkwardly, and the rules added because of them.
- Actual migration cost against the estimate.
```

## Index row and supersession

If `docs/adr/README.md` exists, add the row in its existing format. If an ADR about the label taxonomy is already there, do **not** write a second one: propose superseding it, set `superseded_by` on the old record, add a one-line postscript at its top pointing at the replacement, and strike through both the number and the title link in the index table — leaving the Status cell readable.

If the project has no `docs/adr/`, ask whether to start the practice rather than creating the directory unasked.

**Point the config at the successor, not the superseded record.** After writing a superseding ADR, update `adr` in `.claude-plugin/issue-conventions.json` to the new file. A config still naming the old one makes every tool that reads that field quote numbers the ADR itself has disowned — and the drift check will keep comparing the document against a record that was deliberately retired.

**Extend the postscript, do not edit the numbers.** Stale figures usually live in the superseded ADR's Decision tables, *above* wherever a postscript at the top would sit — so a reader arriving from search sees "7 values" with no indication it is historical. Say in the postscript which specific claims are now wrong and what replaced them. The numbers in the body stay untouched: an ADR records a decision as it was made, not current state.
