# Issue taxonomy

This repository is a marketplace of reusable Claude Code plugins, each living under `plugins/<name>/`. The taxonomy answers two questions about every issue: what kind of work it is, and which plugin it lands on.

## Axes

| Axis | Prefix | Mandatory | Cardinality | Color | Applies to |
|---|---|---|---|---|---|
| type | `type:` | yes | exactly one | `#cccccc` | all |
| plugin | `plugin:` | no | zero or more | `#0052cc` | all |
| preset | `preset:` | no | zero or more | `#52a373` | all |
| by | `by:` | no | zero or more | `#cccccc` | all |
| reason | `reason:` | no | zero or more | `#cccccc` | closed only |

**Scope:** issues only. PRs are not labeled.

## Cross-axis rules

- soft-limit: 5

Only `type:*` is required — an issue always has a kind, even when it touches no single plugin. Beyond five labels an issue is usually doing too much and is a candidate to split.

`preset:*` is meaningful only alongside `plugin:playbook`: presets are that plugin's content. It is a separate axis rather than a set of `plugin:` values because a preset is a unit inside playbook, not a peer of the thirteen plugins.

## Values

### `type:*`

| Label | Description | Color |
|---|---|---|
| `type:bug` | Something is broken or behaves incorrectly against documented expectations. | `#b60205` |
| `type:feature` | A new user-visible capability. | |
| `type:perf` | Speed, token, or context-budget improvement, with or without visible behavior change. | |
| `type:docs` | Changes only to README, docs/, SKILL.md prose, or in-code comments. | |
| `type:refactor` | Internal restructuring with no user-visible change and no perf claim. | |
| `type:test` | Adding, fixing, or restructuring tests, including acceptance test documentation. | |
| `type:chore` | Tooling, build, deps, repo hygiene, CI, marketplace manifest. | |
| `type:research` | Investigation with no guaranteed artifact; the outcome may be a conclusion, not a change. | |
| `type:epic` | An umbrella tracking work that is delivered through other issues. | |
| `type:idea` | An unripe proposal: worth recording, not yet decided. | |

### `plugin:*`

<!-- source: modules path=plugins ignore=repo,new,all -->

| Label | Description | Color |
|---|---|---|
| `plugin:ai-fortune` | `plugins/ai-fortune/` — career direction analysis. | |
| `plugin:context` | `plugins/context/` — session context inspection. | |
| `plugin:fresh-guides` | `plugins/fresh-guides/` — watchlist for fast-changing technologies. | |
| `plugin:git-branch-naming` | `plugins/git-branch-naming/` — branch naming enforcement. | |
| `plugin:issue-conventions` | `plugins/issue-conventions/` — issue label and title taxonomy. | |
| `plugin:kb-grooming` | `plugins/kb-grooming/` — documentation health analysis. | |
| `plugin:plantuml` | `plugins/plantuml/` — PlantUML diagram URL sync and ASCII rendering. | |
| `plugin:playbook` | `plugins/playbook/` — curated coding guideline presets. | |
| `plugin:retroscope` | `plugins/retroscope/` — retrospective session reports. | |
| `plugin:semver` | `plugins/semver/` — semantic versioning enforcement. | |
| `plugin:statusline` | `plugins/statusline/` — three-line statusline with rate limits. | |
| `plugin:statusline-compact` | `plugins/statusline-compact/` — minimal single-line statusline. | |
| `plugin:technology-explainer` | `plugins/technology-explainer/` — per-technology explanation depth. | |

### `preset:*`

<!-- source: modules path=plugins/playbook/presets -->

| Label | Description | Color |
|---|---|---|
| `preset:action-over-planning` | Bias toward acting over producing plans. | |
| `preset:debugging-discipline` | The gather → diagnose → confirm → fix workflow. | |
| `preset:documentation-principles` | Docs as part of the codebase; ADRs, ripple analysis. | |
| `preset:git-safety` | Guardrails around destructive git operations. | |
| `preset:github-workflow` | Branch, commit, PR, and merge conventions. | |
| `preset:macos-python` | Python pitfalls specific to macOS. | |
| `preset:macos-zsh-quirks` | zsh behaviors that break scripts written for bash. | |
| `preset:readme` | README structure and section conventions. | |
| `preset:shell-scripting-safety` | Strict mode, quoting, and safe shell patterns. | |
| `preset:verify-before-relay` | Verify a claim before reporting it as fact. | |

### `by:*`

| Label | Description | Color |
|---|---|---|
| `by:kb-grooming` | Filed by the kb-grooming automation, not by a person. | |

### `reason:*`

| Label | Description | Color |
|---|---|---|
| `reason:duplicate` | Closing reason: already tracked in another issue. | |
| `reason:wontfix` | Closing reason: acknowledged but explicitly decided not to fix. | |
| `reason:superseded` | Closing reason: a later issue or PR replaced this approach entirely. | |
| `reason:obsolete` | Closing reason: the surrounding code or product changed and the issue no longer applies. | |

An ordinary close through a merged PR needs no `reason:*` — the linked PR already says what happened. The axis exists for the closes that are not ordinary.

## Disambiguation rules

- **A plugin's Markdown is mostly executable, not documentation** — `SKILL.md`, `presets/*.md`, and hook prompts are what the agent reads and acts on, so editing them changes behavior: that is `type:feature` for a rule that did not exist, or `type:bug` when the agent already did the wrong thing against documented expectations. `type:docs` is for the text that *describes* a plugin to a person — README, `docs/`, code comments. Judge by what the edit changes, not by the file extension: most `.md` edits in this repo are functional.
- **`type:feature` vs `type:refactor`** — only `type:feature` when a plugin's user can observe the change. Renames and internal restructuring are `type:refactor`.
- **`type:idea` vs `type:feature`** — `type:idea` while the shape is still open ("preset or plugin?", "should this exist?"). Once the form is decided it becomes `type:feature`.
- **`type:research` vs `type:perf`** — an investigation is `type:research` even when its subject is performance; `type:perf` is for the change that follows.
- **A proposal gets no label for the thing it proposes** — `plugin:*` and `preset:*` name what exists on disk, so an issue asking for a *new* plugin or preset carries neither, however clearly it describes one. It still gets the address of whatever existing plugin would host it: #332 and #366 propose new playbook presets and carry `type:idea` + `plugin:playbook`, with no `preset:*`. Once the name is settled, add its value to the dictionary and label the originating issue with it — the block lasts only while the name does not exist.
- **A plugin's README still carries `plugin:*`** — #304 (heading case in the git-branch-naming README) is genuinely `type:docs`, and it keeps `plugin:git-branch-naming` so that "everything open on this plugin" stays a complete answer.
- **Provenance is not a type** — an issue filed by automation gets its own `type:*` on merit. A kb-grooming report umbrella is `type:epic` + `by:kb-grooming`; each derived issue is usually `type:docs` + `by:kb-grooming`.
- **Repo-level work has no `plugin:*`** — issues about `CLAUDE.md`, `CONTRIBUTING.md`, the root README, `docs/`, or the PR template belong to no single plugin and stay without the axis.
- **`preset:*` implies playbook** — a `preset:*` label always accompanies `plugin:playbook`, never stands alone.

## Worked examples

| Issue | Labels | Why |
|---|---|---|
| #338 `git-branch-naming: commit/push branch detection reads main-checkout HEAD in a worktree` | `type:bug`, `plugin:git-branch-naming` | Documented behavior (block commits to protected branches) misfires in a worktree. One plugin. |
| #304 `docs: normalize heading case in git-branch-naming README` | `type:docs`, `plugin:git-branch-naming`, `by:kb-grooming` | Documentation-only change, filed by the automation, still addressed to its plugin. |
| #365 `playbook/shell-scripting-safety: write scratch files with the Write tool` | `type:bug`, `plugin:playbook`, `preset:shell-scripting-safety` | A heredoc the sandbox refuses is a real failure the preset should have prevented — editing preset prose is the fix, not the kind of work. |
| #345 `research: audit plugins/docs against Anthropic's Context Engineering rules` | `type:research` | Investigation with no guaranteed artifact. Touches every plugin, so no single `plugin:*` applies. |
| #332 `feat: worktree-discipline preset/plugin` | `type:idea`, `plugin:playbook` | Form undecided (preset or plugin), likeliest home known. |
| #227 `epic: subagent delegation for plugins` | `type:epic` | Umbrella delivered through #221–#225; spans three plugins, so none is labeled. |
| #300 `docs: fix merge instructions contradiction in CONTRIBUTING.md` | `type:docs` | Repo-level document — no plugin owns it. |

## Title format

**Pattern:** `<type>(<scope>): <subject>`

| Element | Source | Rule |
|---|---|---|
| `<type>` | the `type:*` value without its prefix | `feat`, `fix`, `perf`, `docs`, `refactor`, `test`, `chore`, `research`, `epic`, `idea` |
| `<scope>` | a `plugin:*` or `preset:*` value | where the effect lands for the user; optional when the work is repo-wide; one per title |
| `<subject>` | — | what the user gets, not how it is implemented |

`fix` maps to `type:bug` and `feat` to `type:feature` — the title uses the Conventional Commits spelling so an issue title and the PR title that closes it read alike.

**Length:** 60–80 characters, soft. Self-containment beats brevity — if trimming a word makes the title ambiguous without reading the labels, keep the word.

**Exempt:** issues carrying a `by:*` label keep whatever title the automation produced.

## Legacy label mapping

| Old label | Action | New label | Why |
|---|---|---|---|
| `documentation` | map | `type:docs` | Direct equivalent. |
| `bug` | map | `type:bug` | Direct equivalent. |
| `performance` | map | `type:perf` | Direct equivalent. |
| `enhancement` | split | — | Feature vs refactor vs research vs epic depends on user visibility: a change a plugin's user can observe is `type:feature`; internal restructuring is `type:refactor`; an investigation is `type:research`; an umbrella delivered through other issues is `type:epic`. |
| `kb-grooming-report` | map | `by:kb-grooming` | The label always meant provenance, never a kind of work. |
| `plugin` | delete | | Absorbed: issues about an existing plugin get a specific `plugin:<name>`, and proposals for plugins that do not exist yet stay without the axis. |
| `preset` | delete | | Absorbed: each issue gets a specific `preset:<name>`. |
| `SPAM` | delete | | Zero usage. |

## GitHub built-in labels

Policy: **delete**. Exceptions kept: none.

Six of the nine (`duplicate`, `invalid`, `wontfix`, `question`, `good first issue`, `help wanted`) carry zero issues and can go at any time. The other three (`bug`, `documentation`, `enhancement`) are the classifier's main input during migration and **must survive until `/issue-conventions-relabel` has run** — `gh label delete` strips a label from every issue that carried it, and the `split` row above has nothing to apply to once `enhancement` is gone.

GitHub silently re-creates built-ins after some UI operations; the drift check watches for that, which is why the policy is recorded here.

---

<!-- issue-conventions:managed -->
> **Do NOT edit this file by hand.** Run `/issue-conventions-setup` to change the taxonomy and `/issue-conventions-relabel` to apply it to existing issues. Hand edits are honored — this document is the source of truth — but the plugin cannot guarantee that GitHub labels and this file agree until you re-run those commands.

| | |
|---|---|
| Config | `.claude-plugin/issue-conventions.json` |
| Plugin | `issue-conventions` v0.4.1 |
| Last synced with GitHub | 2026-09-07 |
<!-- /issue-conventions:managed -->
