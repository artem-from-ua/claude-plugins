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

Tolerant — each must exit **zero**:

| # | Mutation | Expected |
|---|---|---|
| 2.15 | Footer removed | passes, emits a warning |
| 2.16 | Extra column in the Axes table | ignored |
| 2.17 | Unknown `## Notes` section | ignored |
| 2.18 | Extra `###` section inside `## Values` | ignored |

**Acceptance criteria:** all eighteen behave as specified. 2.15–2.18 are as important as the negatives — a parser that rejects a human's added column turns the document back into a brittle config, which is the thing markdown-as-truth was chosen to avoid.

### 4.3 Script integration ✅

| # | Check | Expected |
|---|---|---|
| 3.1 | `fetch-issues.sh --count-only` on a repo with >60 issues | returns the true count, **not ~60** — the regression guard against `gh issue list --json` truncation |
| 3.2 | `fetch-issues.sh` filters PRs | no entry has a `pull_request` field |
| 3.3 | `label-plan.sh` against a synced document | empty create and update groups (idempotent) |
| 3.4 | `label-plan.sh` never schedules deletions | `unknown` group is reported, never applied |
| 3.5 | `gh label create --force` on an existing label | exits 0 |
| 3.6 | `backup.sh` | writes `labels.json`, `issues.json`, `ROLLBACK.md`; the rollback commands are syntactically valid |
| 3.7 | `inject-rules.sh` without a config | zero output, exit 0 |
| 3.8 | `inject-rules.sh` twice in a row with a config | byte-identical output (determinism) |
| 3.9 | `test-drift-jq.sh` | 8 tests pass — pins the semantics of the jq expressions in `drift-check.sh` |

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
| Session context bloated after one issue | rules leaked into the dispatcher | 1.10 |
| Prompt cache missing every session | the hook emits a computed date | 1.12 |
