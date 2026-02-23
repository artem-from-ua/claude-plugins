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
| ✅ Done | {completed task} | {PR #N, issue #N, or —} |
| 🚧 In progress | {ongoing work} | {branch feature/foo} |
| ❓ Open | {unresolved question} | {issue #N or —} |
| 🔬 Research | {topic investigated} | {session {uuid-short}} |
| ✔️ Decision | {what was decided} | {discussion #N or —} |
| ❌ Abandoned | {abandoned task and reason} | — |
| 💡 Idea | {idea for future} | — |
| ⚠️ Blocked | {what is blocked and why} | {issue #N} |

_(Include only rows that apply. Remove unused status rows.)_

## 🔗 References

- **PRs:** {PR URLs from conversation, or "none"}
- **Issues/Discussions:** {GitHub/JIRA references, or "none"}
- **Branches:** {git branches touched}
- **Sessions:** {session UUIDs with slugs, e.g. "03e14812 (wild-dancing-wigderson)"}

## 💬 Communication Insights

### User side
- {Suggestions for more effective prompting, task descriptions, or context provision}

### Claude Code config
- {Suggested CLAUDE.md improvements, plugin adjustments, or settings tweaks based on patterns observed}

## 📈 Productivity Metrics

- **Token usage:** {input / output / cache totals} (est. cost: ${estimated_cost})
- **Tool breakdown:** {top tools — e.g. "Read: 42, Bash: 18, Edit: 15, Write: 7"}
- **Session pacing:** {average time between exchanges or notable patterns}

## 🔮 Next Steps

- {Actionable follow-up item 1}
- {Open question to address next session}
- {Reminder or deferred work}
```
