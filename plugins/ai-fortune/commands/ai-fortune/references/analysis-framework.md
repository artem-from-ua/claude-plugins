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

## Amplitude Classification

Classify each recommended direction into one of 5 amplitude levels. The report MUST include exactly one direction per level.

| Level | Name | Description | When to Generate |
|-------|------|-------------|-----------------|
| L1 | **Optimize Current** | Stay in current role, deepen specialization, leverage AI harder | Always — baseline reference point |
| L2 | **Lateral Move** | Same industry, adjacent role (e.g., dev → DevRel, PM → TPM) | Always — low-friction alternative |
| L3 | **New Company** | Same role/skills, different company type or industry | If Q1b ≠ "Love it" OR risk score ≥ MODERATE |
| L4 | **Career Pivot** | New role requiring significant reskilling (e.g., dev → product, ops → consulting) | If Q1b ∈ {"Want to pivot", "Need change"} OR Q14 ≠ "Conservative" |
| L5 | **Radical Change** | Entrepreneurship, freelance, completely new field, geographic move | Always — stretch option, even for conservative users |

### Generation rules:
- Q1b "Love it" → L1 gets the most detail, L4/L5 are brief "for future reference"
- Q1b "Need change" → L3-L5 get the most detail, L1 is brief "if you must stay"
- Q14 "Conservative" → L4/L5 include extra risk mitigation steps
- Q14 "Aggressive" → L4/L5 include faster timelines

### Content requirements per level:
- **All levels**: direction title, one-liner, "What to do" (concrete actions), target business types, "Why AI won't replace this" (AI-resistant properties), salary range + delta vs current, timeline
- **L3-L5 only**: skills bridge table (Already Have → Need to Acquire → How to Get)

---

## Business Type Classification

When recommending target businesses, classify them into these types and ensure diversity across directions:

| Type | Description | Examples |
|------|-------------|---------|
| **AI-native** | Built around AI from day one | AI labs, AI-first SaaS, AI infrastructure |
| **AI-adopting** | Traditional companies investing heavily in AI | Banks with ML teams, retailers with recommendation engines |
| **AI-consulting** | Helping others adopt AI | Consultancies, system integrators, AI training firms |
| **Non-AI** | Industries where AI is peripheral or absent | Construction, artisan crafts, regulated professions |

### Rules:
- Name real companies (not hypothetical), mixing well-known and emerging
- Mix local companies (from Q18 market) with remote-friendly options
- Diversify industries across the 5 directions
- Specify company size: startup (<50), scale-up (50-500), enterprise (500+)
- For each target business, note: company name, type, size, why it fits

---

## Contrastive Analysis

Compare self-reported data (interview) vs observed data (sessions/insights):

| Aspect | Self-Reported Source | Observed Source | Look For |
|--------|---------------------|----------------|----------|
| AI dependency (work) | Q5a interview | session frequency, tool calls | Under/over-estimation |
| AI dependency (personal) | Q5b interview | project diversity, side-project sessions | Work vs personal gap |
| Work vs personal AI gap | Q5a vs Q5b | session patterns by project | Split personality — power user at home, basic at work (or vice versa) |
| Role focus | Q2 daily tasks | project_areas, what_you_wanted | Discrepancy in time allocation |
| Strengths | Q3, Q10 interview | whats_working, impressive_things | Blind spots or unrecognized strengths |
| Weaknesses | Q6 predictions | friction_categories, tool_errors | Denial or over-worry |
| Career direction | Q1b sentiment | session diversity, new tool adoption | Stagnation vs active exploration |
| Compensation vs market | Q16 bracket | web search salary data for Q18 market | Under/over-compensated for role |
| Work/life balance | Q2 daily tasks | time_distribution, session timestamps | Night/weekend work patterns |
| Transition capacity | Q14 risk tolerance | burnout indicators, session intensity | Stated risk tolerance vs actual bandwidth |

### How to present:
- If data confirms self-report → reinforce with evidence
- If data contradicts → present gently: "Your sessions suggest X, though you described Y — this gap is worth exploring"
- If data reveals unmentioned strength → highlight as "hidden advantage"

---

## Burnout Risk Indicators

Screen for burnout risk using session metadata and interview answers. These indicators are warning signs, not diagnoses.

| # | Indicator | Threshold | Data Source |
|---|-----------|-----------|-------------|
| 1 | **Night work** | >30% of sessions start between 22:00-06:00 | session-meta timestamps |
| 2 | **No rest days** | 7/7 days with sessions in the past 2 weeks | session-meta dates |
| 3 | **Dual workload** | Q5a and Q5b both "Essential" or "Significant" | interview answers |
| 4 | **Session marathon** | Average session duration >3 hours | session-meta duration |
| 5 | **Escalating volume** | >50% week-over-week increase in session count | session-meta weekly counts |

### Scoring:
- **0-2 flags**: Normal — no burnout mention in report
- **3-4 flags**: **Sustainability Warning** — dedicated subsection in Blind Spots; extend all direction timelines by 3-6 months to account for recovery
- **5 flags**: **URGENT** — prominent warning at top of Blind Spots; strongly recommend L1 (Optimize Current) as primary path; extend all timelines by 6-12 months

---

## Direction Diversity Requirements

The 5 recommended directions MUST meet these diversity minimums to prevent echo chamber bias:

| Dimension | Minimum | How to Count |
|-----------|---------|-------------|
| Skill domains | 3 distinct | e.g., engineering, management, design, sales, research |
| Industries | 2 distinct | e.g., tech, finance, healthcare, education, manufacturing |
| Work formats | 2 distinct | e.g., full-time employment, freelance/consulting, entrepreneurship, part-time |
| Non-AI directions | 1 minimum | At least one direction where AI expertise is NOT the primary value proposition |

### Anti-echo-chamber checklist (all must pass):
1. ☐ Not all 5 directions are in the same industry
2. ☐ Not all 5 directions require the same primary skill
3. ☐ At least one direction does NOT involve building/selling AI tools
4. ☐ At least one direction leverages a skill the user may not have considered (from Q3 examples_for_priming or contrastive analysis hidden advantages)
5. ☐ L5 (Radical Change) is genuinely radical — not just "the same job at a startup"

If any check fails → revise directions before finalizing the report.
