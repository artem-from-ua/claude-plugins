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
| Resume title vs self-report | Q1a current role | Resume most recent title | Title inflation/deflation — does resume overstate or understate? |
| Career stability vs sentiment | Q1b career direction | Resume tenure patterns | Says "Love it" but switches yearly? Says "Need change" but 10yr tenure? |
| Skills claimed vs verified | Q10 domain expertise | Resume skills + technology-explainer | Over/under-claiming — listed skills not backed by experience descriptions |
| Experience vs self-report | Q7 years experience | Resume career span computation | Inaccurate self-assessment of career stage |
| Resume vs reality | Q3b honest disclosure | Resume content | User's own identification of where resume doesn't match reality |
| Work substance | Q2b work description | project_areas, insights | Discrepancy between described work and actual AI usage |
| Satisfaction gap | Q1c satisfaction sources vs Q2b work description | project_areas, session diversity | Energy is outside day job → career misalignment signal |
| Satisfaction vs sentiment | Q1c satisfaction sources vs Q1b direction | satisfaction_distribution | Says "Love it" but energy comes only from pet projects? |
| AI monetization vision | Q19 ai_monetization_skills | technology-explainer, AI leverage score | Inflated opportunity or overlooked strengths |

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

## Career Trajectory Analysis
(conditional: only when PDF resume provided)

### Career Stability Score (1-5)

| Score | Label | Avg Tenure | Evidence Pattern |
|-------|-------|------------|------------------|
| 1 | Stable | >4 years | Long tenures, few transitions |
| 2 | Steady | 3-4 years | Regular but not frequent moves |
| 3 | Moderate | 2-3 years | Industry-normal transitions |
| 4 | Mobile | 1-2 years | Frequent moves, short stints |
| 5 | Volatile | ≤1 year | Very short tenures, pattern of exits |

### Adaptability Evidence Score (1-5)

| Score | Label | Evidence Pattern |
|-------|-------|------------------|
| 1 | Single-track | Same domain, same role type throughout career |
| 2 | Minor variation | Same domain, 1-2 role type changes |
| 3 | Moderate | 2-3 domain or role type changes |
| 4 | Versatile | Multiple domains, successful transitions |
| 5 | Radical adapter | Radical successful pivots across unrelated fields |

### How trajectory affects risk dimensions:
- **High domain diversity** → lowers Task Repeatability risk (proven ability to handle novel contexts)
- **Cross-domain experience** → increases Creative Synthesis score (cross-pollination potential)
- **Long single-domain tenure** → may increase Task Repeatability risk but lowers Regulation/Trust risk (deep expertise)

### How trajectory affects directions:
- **Long avg tenure** → predicts comfort with L1 (Optimize Current); L2/L3 may feel risky
- **History of lateral moves** → predicts L2 success; user has done this before
- **Past domain switches** → predicts L4 feasibility; demonstrated pivot capability
- **Short avg tenure** → may indicate difficulty with L1 long-term; consider L3-L5

### Skills Bridge Enhancement:
When resume is available, enhance the "Already Have" column in Skills Bridge tables:
- Add **years of experience** for each skill (computed from positions where it appeared)
- Flag **dormant skills** — listed in resume but not used in last 2 positions (mark with ⚠️)
- Distinguish **current skills** (last 2 positions) from **historical skills** (earlier only)

---

## Satisfaction Alignment Score (1-5)

Measures how well the user's energy/satisfaction sources (Q1c) align with their actual day job (Q2b).

| Score | Label | Evidence Pattern |
|-------|-------|------------------|
| 1 | **Misaligned** | Energy sources exclusively outside day job (only pet projects, hobbies, volunteering mentioned) |
| 2 | **Mostly outside** | 1 work activity mentioned but majority outside job |
| 3 | **Split** | Roughly equal energy from work and non-work activities |
| 4 | **Mostly work** | Most energy from day job, some side interests |
| 5 | **Fully aligned** | Energy sources are entirely within day job scope |

### Computation rules:
- Compare Q1c satisfaction sources against Q2b work description
- Count how many Q1c items relate to day job work (Q2b) vs outside activities
- If Q1c is empty or vague → default to 3 (Split)

### How it affects the report:
- **Displayed in Your Profile section:** `**Satisfaction Alignment: {X}/5** — {label}`
- **Score 1-2** → triggers Satisfaction Gap subsection in Blind Spots. L3-L5 directions should prioritize aligning with Q1c energy sources, not just Q1a/Q2b work skills.
- **Score 1-2 + Q1b "Love it"** → contrastive finding: "You say you love your career direction, but your energy is elsewhere"
- **Score 4-5** → reinforce L1 (Optimize Current) as strong baseline
- **Score 3** → note in Blind Spots as "worth monitoring" but not alarming

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
