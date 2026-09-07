# Legacy label mapping

Every label that exists before the taxonomy needs a decision. Build the table `old label (usage count) → action`, show the obvious ones as a list for a single confirmation, and ask about the contested ones individually.

## Five actions, not two

| Action | When | Example |
|---|---|---|
| `map` | one old label, one new value, no judgment needed | `documentation` → `type:docs` |
| `split` | the old label covers several new values; each issue needs deciding | `enhancement` → feature vs refactor vs chore, by whether a user can observe the change |
| `delete` | no replacement — the label carried no information worth keeping | `wip`, superseded by issue state |
| `keep` | the label is not ours: another tool created and maintains it | `dependencies`, `python:uv` from Dependabot |

**A `keep` row may name a color** in the New label column — `| \`dependencies\` | keep | \`#cccccc\` | ... |`. The label stays foreign: never renamed, never deleted, never stripped from an issue. Only its swatch changes.

Offer this whenever a foreign label sits close to an axis color. One-color-per-axis only works if the color tells you which axis a label belongs to, and a Dependabot blue next to a structural blue breaks exactly that — on an issue carrying several labels, the foreign one reads as one of yours. Neutral grey says "outside the taxonomy" the same way it does for the metadata axes.

The color is compared on every drift check; the name and description are not, since they belong to whoever created the label.
| `migrate` | the label expresses something GitHub has its own mechanism for | `phase-1` is a roadmap stage, i.e. a milestone |

A `split` row has no target value. It is passed to the classifier as a criterion, and `/issue-conventions-relabel` decides issue by issue — write the criterion in the row's Why column, because that is what the classifier reads.

**Absorption** is a `delete` in disguise: a flat `plugin` label disappears not because it maps to something, but because every issue gets a more specific `plugin:<name>`. Propose it as `delete` with that explanation, never as `map`.

## `migrate` is a question, not a recommendation

Before proposing a milestone migration, check whether the repo uses milestones at all: `gh api "repos/{owner}/{repo}/milestones?state=all" --jq 'length'`.

**Zero milestones — do not offer the migration at all.** Map the label to an axis (`phase:1`, `phase:2`) and say why in one line: the repo does not use milestones, so moving roadmap state there would introduce a mechanism nobody maintains. Offering an option the user will not take is noise, and noise in a question is worse than in a report — it costs a decision.

**Milestones in use** — then it is a real question. Three options with **"keep it as an axis" as the default**: keep as an axis / move to milestones / delete.

## GitHub built-ins: one policy question

Ask once, not nine times — and say in the question itself that **nothing is deleted now.** The built-ins stay on their issues throughout relabeling, where `bug`, `documentation` and `enhancement` are the classifier's strongest evidence for `type:*`; deleting them up front would throw away the signal the migration runs on. The question decides the end state, after relabeling finishes.

Without that framing the third polygon's maintainer answered "I don't understand the question", and answered immediately once it was said. The options read as a choice about right now, and a maintainer who thinks their labels are about to vanish is being asked something different from what is meant.

1. **Delete all nine** — the taxonomy replaces them.
2. **Delete the six that duplicate or clash** (`bug`, `enhancement`, `documentation`, `duplicate`, `invalid`, `wontfix`), keep `good first issue` and `help wanted` — they have real integration value in a project that takes contributions.
3. **Keep all.**

Warn that GitHub silently re-creates built-ins after some UI operations. The drift check watches for that, which is why the taxonomy document records the policy.

## Auto-proposals

- Exact name match to a new value → `map`.
- Zero usage → `delete`.
- Created by a known bot (`dependencies`, `python:*`, `github_actions`) → `keep`.
- Everything else → ask individually, with three options: map to X / keep as is / delete.
