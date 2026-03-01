# Analysis Framework

## Risk Matrix (5 Dimensions)

Rate each dimension 1-5 based on the user's profile data + interview answers.

| Dimension | 1 (Low Risk) | 5 (High Risk) |
|-----------|-------------|----------------|
| **Task Repeatability** | Novel problems, unique context every time | Templated, pattern-based work |
| **Human Judgment** | Ambiguous decisions, stakeholder politics | Clear right/wrong answers |
| **Physical Presence** | Requires being physically there | Fully digital, remote-capable |
| **Regulation/Trust** | Licensed, legal liability, fiduciary duty | No licenses, low-stakes output |
| **Creative Synthesis** | Cross-domain innovation, taste-driven | Single-domain execution |

### Scoring:
- **LOW risk** (avg 1.0-2.0): Well-positioned, focus on amplifying with AI
- **MODERATE risk** (avg 2.1-3.0): Some exposure, strategic upskilling needed
- **HIGH risk** (avg 3.1-4.0): Significant exposure, consider pivot planning
- **CRITICAL risk** (avg 4.1-5.0): Urgent action needed, many tasks automatable

---

## 7 AI-Resistant Career Properties

Use these to evaluate recommended directions. A strong career direction should have 3+ of these properties.

1. **Accountability bearing** — Someone must be legally/professionally responsible for outcomes. AI can advise but can't sign off. (Doctors, lawyers, auditors, licensed engineers)

2. **Relationship-dependent** — Trust built over years that can't be transferred to an algorithm. (Sales to enterprise clients, therapists, executive coaches, account managers)

3. **Intense context-switching** — Navigating multi-stakeholder environments where political/social dynamics matter as much as technical correctness. (Product managers, CTOs, diplomatic roles)

4. **Physical embodiment** — Physical presence, manual dexterity, or sensory judgment required. (Surgeons, electricians, chefs, field engineers)

5. **Regulatory barriers** — Licenses, certifications, security clearances that legally restrict who can do the work. (CPAs, medical professionals, classified-environment engineers)

6. **Taste/judgment** — Success depends on subjective quality assessment that resists quantification. (Design directors, creative directors, editors, curators)

7. **Novel problem space** — Working on frontier problems where training data doesn't yet exist. (Cutting-edge research, emerging market strategy, novel technology integration)

---

## AI Leverage Score (0-10)

Measures how effectively the user **amplifies** their capabilities using AI, not how much they fear it.

### Input signals:

| Signal | Source | Weight |
|--------|--------|--------|
| Installed plugins count | settings.json | 1x |
| Plugin sophistication (hooks, skills, presets) | plugin configs | 1x |
| Session complexity (tool diversity per session) | session-meta | 2x |
| Multi-clauding % | insights report | 1x |
| Task agent usage % | session-meta | 2x |
| Tool error recovery (errors vs successful outcomes) | session-meta + facets | 1x |
| Delegation maturity level | computed below | 2x |

### Scoring formula:
```
raw = sum(normalized_signal * weight) / total_weight
score = round(raw * 10)
```

### Interpretation:
- **1-3**: Beginner — using AI as enhanced search/autocomplete
- **4-5**: Practitioner — AI handles defined tasks, user drives flow
- **6-7**: Power User — multi-step delegation, custom workflows
- **8-9**: Orchestrator — parallel sessions, meta-learning, plugin ecosystem
- **10**: Architect — AI operates as autonomous extension of user's intent

---

## Delegation Maturity Model

Based on insights report data patterns:

| Level | Name | Session Indicators |
|-------|------|-------------------|
| 1 | **Q&A** | Quick Question sessions dominate, few tool calls, short sessions |
| 2 | **Copilot** | Single Task sessions, code + debug, moderate tool usage |
| 3 | **Executor** | Multi Task sessions, plan-driven, PR lifecycle management |
| 4 | **Orchestrator** | Parallel sessions (multi-clauding), task agents, batch PR operations |
| 5 | **Architect** | Custom presets/plugins, self-healing loops, meta-learning feedback |

### Detection rules:
- Level 1: >50% Quick Question sessions, avg <3 tool calls/session
- Level 2: >40% Single Task, tool diversity <5 types
- Level 3: >30% Multi Task OR Iterative Refinement, uses TaskCreate
- Level 4: Multi-clauding >10%, uses_task_agent >20%, >3 projects/week
- Level 5: Custom plugins installed, >5 tool types avg, meta-learning patterns in insights

### Evidence gathering:
- Session types from insights → base level
- Tool distribution from session-meta → complexity indicator
- Multi-clauding stats from insights → parallel capability
- Plugin list from settings → customization depth
- Friction patterns → learning/adaptation behavior

---

## Contrastive Analysis

Compare self-reported data (interview) vs observed data (sessions/insights):

| Aspect | Self-Reported Source | Observed Source | Look For |
|--------|---------------------|----------------|----------|
| AI dependency | Q5 interview | session frequency, tool calls | Under/over-estimation |
| Role focus | Q2 daily tasks | project_areas, what_you_wanted | Discrepancy in time allocation |
| Strengths | Q3, Q10 interview | whats_working, impressive_things | Blind spots or unrecognized strengths |
| Weaknesses | Q6 predictions | friction_categories, tool_errors | Denial or over-worry |
| Career direction | Q13 satisfaction | session diversity, new tool adoption | Stagnation vs active exploration |

### How to present:
- If data confirms self-report → reinforce with evidence
- If data contradicts → present gently: "Your sessions suggest X, though you described Y — this gap is worth exploring"
- If data reveals unmentioned strength → highlight as "hidden advantage"
