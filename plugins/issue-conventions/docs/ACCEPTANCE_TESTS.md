# Acceptance Tests — issue-conventions

## 1. Purpose

Verifies that the plugin designs a taxonomy, applies it without losing data, and detects drift — and that it does not manufacture work on a repository whose taxonomy is already correct.

Two properties matter more than the rest and are tested explicitly: **the parser is the single implementation of the document contract** (so nothing else invents regexes over the document), and **the skill actually fires** (its trigger is a description plus a conditional hook, and the repo's own docs rate a passive description as the weakest mechanism available).

## 2. Test Execution Order

1. Static checks (automated)
2. Parser round-trip and negative tests (automated)
3. Script integration against a live repo (automated)
4. Skill invocation (manual, fresh sessions)
5. End-to-end on the polygons (manual, ordered)

## 3. Automation Status

- ✅ **Fully automated**: sections 4.1–4.3
- 🟡 **Partially automated**: section 4.4 — runs in-session but needs a repo with a taxonomy
- ⚠️ **Manual only**: sections 4.5–4.6 — require fresh sessions and real mutations

## 4. Test Categories

### 4.1 Static checks ✅

| # | Check | Command | Expected |
|---|---|---|---|
| 1.1 | `plugin.json` is valid JSON | `jq . plugins/issue-conventions/.claude-plugin/plugin.json` | parses |
| 1.2 | `hooks.json` is valid JSON | `jq . plugins/issue-conventions/hooks/hooks.json` | parses |
| 1.3 | Config template is valid JSON | `jq . plugins/issue-conventions/templates/issue-conventions.json` | parses |
| 1.4 | Shell scripts parse | `bash -n plugins/issue-conventions/scripts/*.sh` | silent |
| 1.5 | Parser compiles | `python3 -m py_compile plugins/issue-conventions/scripts/parse-taxonomy.py` | silent |
| 1.6 | `plugin.json` has both `commands` and `skills` | `jq -e '.commands and .skills' …` | true |
| 1.7 | Registered in marketplace | `jq -e '.plugins[] \| select(.name=="issue-conventions")' .claude-plugin/marketplace.json` | one entry |
| 1.8 | Every SKILL.md has frontmatter with `name` and `description` | grep | four files |
| 1.9 | Command SKILL.md ≤100 lines; dispatcher ≤60 | `wc -l` | within limits |
| 1.10 | Dispatcher carries no taxonomy values | `grep -oE '`(type\|priority)[a-z:_-]+`' skills/*/SKILL.md` | only placeholders |
| 1.11 | Scripts are executable | `test -x` | all six |
| 1.12 | Hook is deterministic | `grep -vE '^\s*#' scripts/inject-rules.sh \| grep -E 'date \|git log\|\$RANDOM\|curl\|wget'` | no matches |

**Failure modes:** 1.6 and 1.7 are the two checks every plugin in this marketplace must carry. 1.10 guards the architecture — the moment value dictionaries appear in the dispatcher, rules are leaking back into session context. 1.12 guards prompt-cache determinism: a `date` call in the hook invalidates the cache on every session start.

### 4.2 Parser round-trip and negative tests ✅

**Objective:** the generator and the parser agree, and the parser fails loudly and precisely where the contract is violated while tolerating human additions.

**Steps:** extract the skeleton from the ````markdown` block in `templates/document-schema.md`, parse it, and assert the model.

| # | Case | Expected |
|---|---|---|
| 2.1 | Skeleton parses | exit 0 |
| 2.2 | Axis count, prefixes, cardinality | 6 axes, prefixes match, vocabulary respected |
| 2.3 | Color inheritance | empty Color cell inherits the axis color; a per-value color overrides it |
| 2.4 | `priority:*` gradient | four distinct hex values |
| 2.5 | `<!-- source: … -->` | `kind=modules`, `path`, `ignore` list |
| 2.6 | Cross-axis rules | `at-least-one` parsed, `soft-limit` numeric |
| 2.7 | Legacy mapping | all five actions accepted |
| 2.8 | Footer | marker found, sync date read |

Negative — each must exit non-zero **with a line number**:

| # | Mutation | Expected |
|---|---|---|
| 2.9 | Remove `## Values` | missing required section |
| 2.10 | `Cardinality` set to an unknown word | vocabulary error |
| 2.11 | Empty Description cell | description required |
| 2.12 | Label prefix not matching its axis | prefix mismatch |
| 2.13 | Axis with no `###` section | missing values section |
| 2.14 | Non-hex color | color format error |
| 2.19 | Description over 100 bytes | rejected with a line number — GitHub returns 422 otherwise, half-applying the plan |
| 2.20 | 60 Cyrillic characters in a description | rejected: the limit is bytes of UTF-8, not characters |

Tolerant — each must exit **zero**:

| # | Mutation | Expected |
|---|---|---|
| 2.15 | Footer removed | passes, emits a warning |
| 2.16 | Extra column in the Axes table | ignored |
| 2.17 | Unknown `## Notes` section | ignored |
| 2.18 | Extra `###` section inside `## Values` | ignored |
| 2.21 | `## Rule exceptions` section | parsed; listed issues are exempt from the named cross-axis rule |

**Acceptance criteria:** all twenty-one behave as specified. 2.15–2.18 are as important as the negatives — a parser that rejects a human's added column turns the document back into a brittle config, which is the thing markdown-as-truth was chosen to avoid.

### 4.3 Script integration ✅

| # | Check | Expected |
|---|---|---|
| 3.0 | `drift-check.sh` on a repo with ~200+ issues | completes — the dump reaches jq via `--slurpfile`, not argv. `--argjson` dies with "Argument list too long" past the execve argument limit, which is exactly the corpus size this plugin is for |
| 3.1 | `fetch-issues.sh --count-only` on a repo with >60 issues | returns the true count, **not ~60** — the regression guard against `gh issue list --json` truncation |
| 3.2 | `fetch-issues.sh` filters PRs | no entry has a `pull_request` field |
| 3.3 | `label-plan.sh` against a synced document | empty create and update groups (idempotent) |
| 3.4 | `label-plan.sh` never schedules deletions | `unknown` group is reported, never applied |
| 3.5 | `gh label create --force` on an existing label | exits 0 |
| 3.6 | `backup.sh` | writes `labels.json`, `issues.json`, `ROLLBACK.md`; the rollback commands are syntactically valid |
| 3.7 | `inject-rules.sh` without a config | zero output, exit 0 |
| 3.8 | `inject-rules.sh` twice in a row with a config | byte-identical output (determinism) |
| 3.9 | `test-drift-jq.sh` | 12 tests pass — pins the semantics of the jq expressions in `drift-check.sh` |
| 3.10 | `test-adr-status.sh` | 6 tests pass — supersession decided by script from three signals, on fixtures copied from the reference project |
| 3.11 | `test-index-rows.sh` | 8 tests pass — supersession is read from the strikethrough (structure), the successor number from the Status cell (prose) |
| 3.12 | `test-scale.sh` | 5 tests pass — a synthetic 500-issue dump; asserts the old form still fails with the exact error, so a stale fixture announces itself |
| 3.13 | `test-adr-state.sh` | 3 tests pass — "no ADR configured" and "configured but the file is gone" are distinct states, so a broken config cannot read as a clean one |

**On 3.10.** Supersession detection lived in the subagent template until 0.2.4 — deterministic logic expressed as prose the model had to re-derive each run. The first polygon pointed out the consequence: the tests pinned a bash implementation that shipped nowhere, so rewording a paragraph would change behavior while every test stayed green. The three signals now live in `adr-status.sh`, which the drift check calls and the subagent reads. The template keeps the judgment (what a divergence *means*) and hands over the fact.

**On 3.9.** Two bugs shipped in 0.1.0 and were caught on the first polygon: `from_entries` fed `{key, count}` instead of `{key, value}` (so every declared value looked unused — 36 of 36, burying the five real ones), and a bare `.description` where `$l.description` was meant (so every label looked drifted, while `label-plan.sh` correctly reported zero updates on the same data). Both are the same shape: jq stayed silent and returned plausible output, so `bash -n` could not catch them. These tests pin behavior rather than syntax.

### 4.4 Drift detection 🟡

**Objective:** the drift check finds real divergences and stays quiet about healthy state.

Run against a repository with a known-good taxonomy. Expected: **zero divergences**, INFO findings allowed.

The check that most easily produces false positives is modules-without-an-axis. A module counts as covered when it matches a value name, **is mentioned in a value's description** (one value frequently covers several modules), or appears in `ignore=`. A run that flags infrastructure modules covered by a topical axis means one of those three mechanisms is broken — not that the taxonomy is wrong.

### 4.5 Skill invocation ⚠️ Manual

**Objective:** measure how often the dispatcher actually fires. The trigger is a description plus a conditional hook, and `docs/plugin-behavior.md` rates a passive description far below a SessionStart mandate — so this needs numbers, not assumptions.

**This cannot be tested in the session where the plugin was developed.** The skill loads from the plugin cache at session start, so it is absent until installed; and after installation that session gives a false positive, because the conversation itself is about the taxonomy and the model would invoke the skill from context rather than from the trigger.

**Procedure:**

1. Install the plugin; open a **fresh** session in a different repository that has a taxonomy configured.
2. Give an ordinary task where an issue arises naturally: "file an issue about X failing on Y". **Do not say "label", "taxonomy", or a prefix** — that tests the prompt, not the trigger.
3. Record the outcome by checking whether the created issue carries taxonomy labels. Per `docs/acceptance-tests.md`, verify the **result**, not the UI: the skill may fire without appearing in a visible invocation list.
4. Five attempts per combination: Sonnet and Opus, with the hook and with `hooks.json` temporarily renamed — 20 sessions.
5. Every attempt needs a fresh session; within one session an earlier invocation primes the next.

**Cleanup:** close the test issues with a closing reason, or run the test on issues that needed filing anyway.

**Expected result:** a table of model × hook. This is a one-time investment before the v0.1.0 release, not a regression test. It decides whether v0.2.0 needs a `PostToolUse` check that catches the fact (`gh issue create` already ran) rather than the intent.

### 4.6 End-to-end on the polygons ⚠️ Manual

Ordered deliberately: prove the plugin does not manufacture work before letting it mutate anything.

1. **A repository whose taxonomy is already correct** — dry run. Expected: zero rule violations, and only the drift findings known in advance. A finding beyond that list is a false positive to fix before proceeding.
2. **The same repository, migrated** — move the taxonomy out of `CLAUDE.md` into a document, cut the section (with permission), supersede the ADR rather than editing it.
3. **The largest backlog** — first live relabel. Exercises pagination, rate limiting, batch pacing, and all five legacy-mapping actions.
4. **This repository** — the built-in labels policy and the absorption case (a flat `plugin` label disappearing into `plugin:<name>`).

## 5. Manual Test Procedures

### Verifying the hook is conditional

```bash
cd /path/to/repo/without/taxonomy
bash plugins/issue-conventions/scripts/inject-rules.sh; echo "exit=$?"
```

Expected: no output, `exit=0`. A repository that never adopts the plugin must pay nothing for having it installed.

### Verifying rollback

After any run that deleted labels, open `ROLLBACK.md` in the backup directory and run its label-recreation block. Every label returns with its original color and description. This is the only safety net for `gh label delete`, which strips the label from every issue that carried it.

## 6. Regression Guide

| Symptom | Likely cause | Check |
|---|---|---|
| `relabel` fails on the first `gh issue edit` | a label exists in the document but not on GitHub | step 2 of relabel was skipped; run `label-plan.sh` |
| Only ~60 issues classified | `gh issue list --json` used instead of the REST paginate | 3.1 |
| Labels vanished from issues | `--label` used instead of `--add-label`/`--remove-label` | `apply-reconcile.md` |
| Foreign labels stripped | the delta was not intersected with taxonomy-owned labels | `apply-reconcile.md` |
| Drift report full of noise | unused values reported as divergences instead of INFO | `templates/drift-check.md` |
| Every label reported as drifted | bare `.description` instead of `$l.description` in the `metadataDrift` select | 3.9; cross-check against `label-plan.sh`, which is right when the two disagree |
| Every value reported as unused | `from_entries` fed `count:` instead of `value:` | 3.9 |

### A tool is tested on a repo smaller than the one it was written for

Two limits in this plugin sat exactly where it starts being useful, and a live run found both:

| Limit | Threshold | Found on |
|---|---|---|
| `gh issue list --json` truncates silently | ~60 issues | first polygon |
| `--argjson` exceeds `ARG_MAX` | ~200 issues with bodies | second polygon |

That is not bad luck. A plugin gets exercised on its author's repository during development, and that repository is always smaller than the backlog the plugin was written to handle — so every size-dependent failure waits for a real run to surface.

`test-scale.sh` is the answer: a synthetic 500-issue, ~2.4 MB dump, deliberately larger than any repo here.

**Name the polygon a finding came from, and name the right one.** Every lesson here is reproducible only against the repository that produced it: the first polygon has a Dependabot integration and a corpus of partially superseded ADRs, the second has neither but does have 210 issues and a flat Swift package. Attributing a finding to the wrong run sends the next reader looking for conditions that are not there — and a lesson nobody can reproduce is indistinguishable from one nobody checked. "One of the polygons" is better than a confident wrong name.

**A polygon that does not catch a bug is not evidence the fix was unnecessary.** The third repository has ~151 issues, so its dump sits comfortably under the argv limit and `--argjson` would not have failed there. Had the polygons run in a different order, the bug would have reached everyone who has a larger backlog than the author's. Order of testing decided whether it was found, not whether it existed — which is precisely why the synthetic fixture is larger than any repository here.

**It observes rather than calculates, and that distinction is the point.** The first version asserted the fixture exceeded `getconf ARG_MAX`. But `getconf` is an upper bound, not the limit `execve` enforces — the real ceiling also counts the environment and the argv pointer array, so it moves with however many variables the user exports. Measured on one machine: `getconf` reported 1 048 576 while `jq` actually failed at ~1 040 234, a gap of roughly the environment's own size.

A guard comparing against `getconf` can therefore claim the fixture is big enough when it no longer is. So the test runs the failing form and requires it to fail with the exact error. If it ever stops failing, the fixture has gone stale and says so — a signal rather than an estimate. The same shape applies to any guard: assert the bug reproduces, not that some proxy for it is large enough.

### Anchor on structure, not on a word that may appear in prose

Four bugs in this plugin have now shared one shape: something was located by guessing at a word instead of keying on structure.

| What was guessed | What it matched instead | Fix |
|---|---|---|
| `.description` after a `\|` in jq | the object being iterated, not `$l` | bind the value first |
| `index(.scope)` after a `\|` | the array, not the object | bind the value first |
| a table found by a column name containing "scope" | the section's *first* table, whose prose mentions scope | anchor on the bold marker line |
| an index row matched on "supersede" | the successor row (`supersedes`), not the superseded one | read the strikethrough, not the prose |

The first two are the same jq trap: after a pipe, the dot is the previous result, not where you started. The last two look like carelessness about structure, but the second polygon put the cause better, and the better statement is the useful one:

**A grep for a line *is* a structural check — until someone writes prose about that line.** `grep 'gh issue list'` was a perfectly good check the day it was written. It broke when `fetch-issues.sh` gained a comment explaining why that command is *not* used. The most conscientiously documented file defeats the simplest check, and it does so by being improved rather than by being broken.

So the practical rule is not "use structure" — it is: **a check that reads a file must be re-read whenever that file gains a substantive comment.** Refactors are not the risky moment; explanations are. Where the check can be made immune cheaply, do that instead — `^[^#]*` for a call rather than a mention, an anchored marker line rather than a column name, a bound variable rather than a bare dot.

**The fourth one had to be fixed twice**, which is the most instructive part. The first attempt narrowed the match from "supersede" to "superseded by" — correct on today's data, and it would have held for a while: 5 rows of 37 say `supersedes`, so the naive version returned 10 instead of 5, while the narrowed one returned exactly the right 5.

But the Status cell is prose, and prose has no contract. A successor row phrased "accepted (0029 superseded by this record)" reads perfectly naturally and defeats the narrowed match too. The strikethrough on the number and title does not have that failure mode: it says something about *the record*, not about a relationship, and it cannot be reworded into meaning the opposite.

So the split is: **structure answers whether, prose answers by whom.** Read the strikethrough to decide the record was replaced, then read the Status cell for the successor's number. Getting a right answer from the wrong kind of signal is the thing to notice — it works until someone writes a sentence nobody anticipated.
| Session context bloated after one issue | rules leaked into the dispatcher | 1.10 |
| Prompt cache missing every session | the hook emits a computed date | 1.12 |
