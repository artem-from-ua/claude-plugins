---
name: issue-conventions-guide
description: >
  Invoked automatically before every `gh issue create`, `gh issue edit`,
  `gh issue close`, or `gh label` call, before choosing or changing any issue
  label, and before writing or rewriting any issue title. Also invoked when
  reclassifying an issue, changing its priority or scope, closing it with a
  reason, or triaging a backlog. Do NOT create, label, retitle, reclassify,
  or close a GitHub issue without consulting this guide.
  Keywords: issue label, gh issue create, gh issue edit, gh label, label taxonomy,
  triage, relabel, reclassify issue, issue title format, backlog audit.
---

# Issue Conventions — Dispatcher

This skill routes work to a subagent. It carries **no taxonomy rules of its own** — rules and issue bodies stay in the subagent so they never enter the session context.

## Step 1: Resolve the config

Read the first that exists: `.claude-plugin/issue-conventions.json` → `.claude/issue-conventions.json` → `~/.claude/issue-conventions.json`.

A hit without a `taxonomyDocument` field counts as no taxonomy.

**No config, or the document is missing or unparseable:** do NOT invent a taxonomy and do NOT block the operation. Apply whatever labels already exist in the repo, say once per session — "This repo has no issue taxonomy; `/issue-conventions-setup` can design one" (or name the broken path) — then carry on.

## Step 2: Route

Pick the row that matches what is about to happen. Launch the subagent with the instruction file as its system prompt, and pass it the `taxonomyDocument` path plus the issue data. Use `models.<key>` and `efforts.<key>` from the config.

| Situation | Instructions | Model key |
|---|---|---|
| A new issue is being created | `${SKILL_DIR}/references/classify-new.md` | `classifyNew` |
| An existing issue changes scope, priority, severity, or classification; or is closed with a reason | `${SKILL_DIR}/references/reclassify.md` | `reclassify` |
| Several issues at once (splitting an epic, a small cleanup) | `${CLAUDE_PLUGIN_ROOT}/templates/batch-classify.md` | `batchClassify` |
| The whole backlog | stop — tell the user to run `/issue-conventions-relabel` | — |
| "Is everything still consistent?" | stop — tell the user to run `/issue-conventions-drift` | — |

The subagent cannot see this conversation. Pass it a 2–3 sentence summary of what the issue is about, alongside the issue number or the draft title and body.

## Step 3: Act on what comes back

Every classification subagent returns the same shape:

```json
{ "labels": ["type:x", "priority:y"], "title": "...", "confidence": "high|low",
  "question": null }
```

- **`question` is null** — apply it. Labels go in one call: `gh issue create --label "a,b,c"`. For an edit use `--add-label` / `--remove-label`, never `--label` (it overwrites).
- **`question` is set** — it holds `text` and `options`. Raise it with `AskUserQuestion` in this session (the subagent has no such tool), then apply the answer. If the answer reads like a general rule rather than a one-off, offer to add it to the document's disambiguation section.

Never invent a label that is not in the taxonomy. If one is missing, that is what `question` is for.
