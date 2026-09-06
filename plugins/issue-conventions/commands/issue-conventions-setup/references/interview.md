# The interview

Every question goes through `AskUserQuestion` and offers candidates mined in step 2. Nothing here is imposed: the defaults below are strong recommendations, all of them overridable.

Ask in this order — later questions depend on earlier answers.

## 1. Which axes?

Multi-select. Pre-select `type` and `priority`; offer the structural and topical axes with the names proposed by the scan; offer `reason` (closing reasons) and `by` (provenance) as optional.

Warn against a `status:*` axis if the user asks for one: open/closed, assignees, and milestones already carry workflow state, and a fourth copy has to be hand-synced with all three.

## 2. Prefix separator

Colon (default) / slash / dash. Say why colon: a slash URL-escapes to `%2F` in GitHub filter URLs, so `type/bug` becomes unreadable in the very place labels are most used.

## 3. The `type:*` dictionary

Pre-filled with seven values aligned to Conventional Commits — `bug`, `feature`, `perf`, `docs`, `refactor`, `test`, `chore` — so an issue title and a PR title carry the same signal. Editable and removable.

## 4. The `priority:*` scale

`critical` / `high` / `medium` / `low` (default), or P0–P3, or high/medium/low. Note that a default of `medium` is what keeps the axis honest — an unset priority is worse than an approximate one.

## 5. Structural axis: the name

The scan proposes one (`plugin:`, `stage:`, `component:`, `layer:`). Confirm or rename. Skip the whole branch if the user did not take a structural axis in question 1.

## 6. Structural axis: the dictionary

Multi-select over the scan's candidates, plus a free-text option. Show what each candidate maps to on disk.

Record what is offered but not chosen — it goes into `ignore=`.

## 7. Topical axis: name and dictionary

Same shape. Each candidate carries two real issue numbers as evidence.

**Offer the housekeeping value explicitly** (`repo`, `meta`). Explain the failure it prevents: without it, issues about labels, CI, and dev tooling land on the closest product-facing value and hollow it out.

## 8. Mandatory rules

Which axes are mandatory, and whether "at least one of the structural or topical axis" applies. Default: `type` and `priority` mandatory, at-least-one across the other two.

## 9. Colors

Three options: **the recommended palette** (default), pick per axis, or all grey.

The recommended palette assigns one color per axis, because the prefix already carries identity and the color should carry the axis: `type:*` grey `#cccccc` with `type:bug` red `#b60205`; the structural axis blue `#0052cc`; the topical axis green `#52a373`; a third axis purple `#8250df`, a fourth teal `#00736b`; `by:*` and `reason:*` grey.

`priority:*` is the one exception — a red→orange→lime→grey gradient, because there the color carries urgency rather than membership. `priority:critical` shares the exact red of `type:bug` so the two loudest signals look alike.

Never use the red-orange range for a structural axis: it dilutes the urgency signal.

## 10. Soft limit

3 / 5 (default) / none. Frame it as a smell, not a rule: past five labels an issue is usually doing too much and wants splitting.

## 11. Provenance sources

Pre-filled from what the scan detected. Each becomes a `by:*` value. Skip if the user did not take the axis.

## 12. Title format

Two separate questions — they are different commitments:

- **Do title rules apply to new issues?** (`titleFormat.enabled`, default yes.) This is what the skill enforces going forward.
- **Rewrite existing titles during relabel?** (`titleFormat.rewriteExisting`, default **no**.) Renaming a whole backlog is the least reversible thing this plugin can do; `/issue-conventions-relabel` will offer it again with a count of how many titles actually differ.

## 13. Disambiguation pass — mandatory

Pick 5–10 genuinely ambiguous issues from the corpus: ones matching two topical values equally, or none. For each, show the title and ask where it belongs.

Every answer becomes a line in the document's Disambiguation rules.

**Do not skip this.** It is the cheapest thing in the whole setup and the one that most reduces review rounds later: in the reference project all three review rounds were about rules, not individual issues. A rule settled here is a round not spent.
