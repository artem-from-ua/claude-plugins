---
name: action-over-planning
description: "Bias toward implementation: max 1 planning round, then code"
tags: [workflow, planning, efficiency]
---

<!-- RULES -->
## Action Over Planning — Base Rules

MANDATORY: Follow these rules to stay implementation-focused.

- Bias toward implementation — if you can reasonably infer what to do, do it
- Maximum 1 clarifying round before starting; don't chain multiple planning exchanges
- Simple tasks (single file, obvious change) → implement directly without a plan
- Complex tasks → write a short plan (3–5 bullet points max), then implement
- Don't ask for confirmation on details you can infer from context or fix later
- If you discover a better approach mid-implementation → adjust and continue; don't restart planning
- Avoid over-engineering: the minimum solution that works is preferred over the theoretically perfect one
<!-- /RULES -->

<!-- REFERENCE -->
## The Planning Trap

Common failure mode: extended back-and-forth planning when the user just wants something done.

Signs you're in the planning trap:
- Third+ clarifying question in a row
- Writing a plan, then asking "does this look good?" instead of implementing
- Listing approaches without choosing one
- Asking about edge cases that don't apply to the current task

## When to Plan vs When to Act

| Task complexity | Approach |
|----------------|----------|
| Single file, obvious change | Implement directly |
| 2–3 files, clear requirements | Implement directly |
| Multi-file, architectural decision | Short plan (3–5 bullets), then implement |
| Unclear requirements | One clarifying question, then implement with stated assumptions |

## Stating Assumptions

If you proceed with an assumption (rather than asking), state it briefly:
> "Assuming X — let me know if you want Y instead."

This keeps momentum while giving the user an easy correction path.

## Mid-Implementation Pivots

If a better approach becomes clear while coding:
- Switch to it
- Note the change: "Switched from X to Y because Z — cleaner fit"
- Don't restart planning

If the pivot is significant (different architecture, different files), briefly state what changed and why, then continue.
<!-- /REFERENCE -->
