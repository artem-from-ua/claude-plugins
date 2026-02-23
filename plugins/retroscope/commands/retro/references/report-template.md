# Retroscope Report Template

Use this template when generating retrospective reports. Fill in all sections based on the session data provided. Replace placeholders in `{braces}` with actual content.

---

```markdown
# 📋 Retroscope: {Project} — {Date}

## 📊 Overview

| Metric | Value |
|--------|-------|
| ⏱️ Duration | {time range, e.g. "10:15–13:42 (3h 27m)"} |
| 💬 Sessions | {count} |
| 🤖 Model | {model name} |
| 🌿 Branch(es) | {comma-separated branches} |

## 🎯 Performance Assessment

{2–3 sentences on productivity, focus, and efficiency based on the session flow.}

**Activity breakdown:** {list primary activity types — e.g. coding 60%, debugging 25%, docs 15%}

## 📝 Tasks & Outcomes

| Status | Task | Links |
|--------|------|-------|
| ✅ Done | {completed task} | 📌 PR #N · 🔀 `branch` |
| 🚧 In progress | {ongoing work} | 🔀 `feature/foo` |
| ❓ Open | {unresolved question} | 🐛 Issue #N |
| 🔬 Research | {topic investigated} | 💬 `uuid-short` |
| ✔️ Decision | {what was decided} | 📋 `plan-file.md` |
| ❌ Abandoned | {abandoned task and reason} | — |
| 💡 Idea | {idea for future} | — |
| ⚠️ Blocked | {what is blocked and why} | 🐛 Issue #N |

_(Include only rows that apply. Remove unused status rows.)_

**Link icons:** 📌 PR · 🔀 Branch · 💬 Session · 📋 Plan · 🐛 Issue/Discussion
Use `·` (middle dot) to separate multiple links in one cell.

## 📄 Documentation Changes

| Change | File(s) |
|--------|---------|
| {short description of substantial change} | `{file path}` |

_(Include only significant documentation changes: new docs, structural updates, important clarifications. Skip trivial edits like typo fixes.)_

## 💬 Communication Insights

### User side
- {Suggestions for more effective prompting, task descriptions, or context provision}

### Claude Code config
- {Suggested CLAUDE.md improvements, plugin adjustments, or settings tweaks based on patterns observed}

## 📈 Productivity Metrics

- **Estimated cost:** ${estimated_cost_usd} (with cache discounts) / ${naive_cost_usd} (without cache discounts, as shown in Claude Code UI)
- **Token usage:** {input / output / cache totals}
- **Tool breakdown:** {top tools — e.g. "Read: 42, Bash: 18, Edit: 15, Write: 7"}
- **Session pacing:** {average time between exchanges or notable patterns}

## 🔮 Next Steps

- {Actionable follow-up item 1}
- {Open question to address next session}
- {Reminder or deferred work}
```
