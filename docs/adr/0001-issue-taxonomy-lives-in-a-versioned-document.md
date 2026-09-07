---
status: draft
date: 2026-09-07
gate: promote to accepted once the taxonomy has been applied to the backlog
---

# 0001. Issue taxonomy lives in a versioned document

## Context

The repository had 14 labels and 151 issues, and the labels answered almost nothing. Seven labels were ever applied; the other seven — six GitHub built-ins plus a `SPAM` label — carried zero issues. 44 issues had no label at all, and the two most-used labels (`enhancement` on 51 issues, `documentation` on 49) were broad enough to cover unrelated kinds of work: `enhancement` alone spanned new capabilities, internal refactors, investigations, and umbrella trackers.

Two questions could not be answered by filtering. "What is open on the plantuml plugin" — because no label named a plugin, only a flat `plugin` label marking issues *about plugins in general*. "What kind of work is this" — because `enhancement` did not distinguish a user-visible feature from a spike. With thirteen plugins in one repository, the first question is the one asked most often.

Labels here are applied by a mix of humans and automation: the `kb-grooming` plugin files issues on its own (27 of them, marked with a bespoke `kb-grooming-report` label that encoded provenance in the same namespace as everything else), and AI assistants working in this repository label issues as they create them. An informal convention is not enough for that mix — a convention nobody can read is one every participant reconstructs differently.

## Decision

The issue label and title taxonomy is defined in [`../issue-labels.md`](../issue-labels.md), maintained by the `issue-conventions` plugin.

That document is the single source of truth. When it and the GitHub labels disagree, the document wins; the plugin propagates the change to GitHub, never the reverse. Editing it by hand is a legitimate way to change the taxonomy — the commands exist to keep the labels in step, not to hold a monopoly on the rules.

## Alternatives considered

**A section in `docs/conventions.md`.** Rejected: that file documents how plugins are built, and the taxonomy is machine-read by the plugin's parser, which needs a fixed heading structure. Mixing a parsed contract into a prose document makes both harder to change. `conventions.md` gets a two-line pointer instead.

**Labels alone, no document.** Rejected: GitHub label descriptions are capped at 100 bytes and hold no cross-label rules — nothing to say when `type:idea` becomes `type:feature`, or that `preset:*` never stands without `plugin:playbook`. Those rules are most of the value, and they have nowhere to live on GitHub.

**A wiki page.** Rejected: not versioned with the code, invisible in review, and not readable by the plugin's parser.

**No taxonomy, enforce by review.** Rejected: the labels were already inconsistent after 151 issues, and much of the labeling is done by automation and AI assistants that do not attend review.

**A `priority:*` axis.** Offered and declined during the interview. Priority is real but changes far more often than a label edit is worth; the backlog is small enough to read.

**A `status:*` axis.** Not offered: open/closed state, assignees, and milestones already carry workflow state.

## Consequences

**Positive:** filtering by plugin becomes possible for the first time — `label:plugin:plantuml` answers "what is open here" completely, including documentation issues. The `type:*` axis aligns with the Conventional Commits prefixes already used in 64% of issue titles, so an issue title and the PR title that closes it read alike. Provenance moves to its own axis, so a kb-grooming-filed issue is classified on merit and still identifiable as automated. AI assistants read the rules from one place instead of inferring them.

**Negative:** the document is one more artifact to keep current, and every new plugin now needs a matching `plugin:*` label. A label created in the GitHub UI is drift until someone runs `/issue-conventions-drift`. Labeling an issue takes a decision that a free-for-all did not require.

TODO once applied to the backlog:
- Whether the palette stays legible on real multi-label issues.
- Values that fitted awkwardly and the rules added because of them.
- Whether `type:idea` and `type:research` earn their places or collapse into their neighbors.
