# Architecture Decision Records

Each ADR records one decision: the context that forced it, what was decided, what was rejected, and what it costs. Records are immutable — a decision that no longer holds is superseded by a new record, never rewritten.

A superseded record keeps its file and gets `status: superseded` plus `superseded_by:` in its frontmatter; in the table below, its number and title link are struck through while the Status cell stays readable.

Add a record when a choice would otherwise have to be re-derived from the code: picking between two viable approaches, deviating from a convention, or committing to a structure other work will depend on.

| # | Title | Status | Date |
|---|---|---|---|
| 0001 | [Issue taxonomy lives in a versioned document](0001-issue-taxonomy-lives-in-a-versioned-document.md) | draft | 2026-09-07 |
