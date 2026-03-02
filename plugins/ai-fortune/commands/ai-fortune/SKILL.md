---
name: ai-fortune
description: >
  Career direction analysis: interview + AI usage pattern mining to identify
  roles AI won't replace. Collects data from 8 data sources, runs adaptive interview,
  performs web research, and generates a structured career risk report.
  Keywords: ai fortune, career analysis, career risk, ai displacement, career direction,
  job future, ai resistant, career pivot.
---

# /ai-fortune — Career Direction Analysis

Run all phases in order. Each step specifies the exact tools to use.

## Phase 0: Load Persistent State

### Step 0: Load State

1. Read `~/.claude/ai-fortune.json`
   - If exists → load `dataSources` (saved file paths), `answers` (interview answers with timestamps), `reportsDir` (saved report directory)
   - If not found → start with empty state: `dataSources = {}`, `answers = {}`, `reportsDir = null`
2. Set `sources_used = 0` counter to track how many of the 9 data sources produce data

---

## Phase 1: Data Collection (Steps 1-6)

Collect data from up to 8 sources. Each source is optional — if unavailable, note it and continue.

### Step 1: Memory Chat File

**Purpose:** Extract industry, tech stack, interests, domain context from the user's Claude web memory export.

1. Check if `dataSources.memoryFilePath` exists in loaded state
2. If saved path exists → `AskUserQuestion`: "Memory chat file path: use saved path `{path}`?"
   - Options: "Use saved path", "Enter different path", "Skip this source"
3. If no saved path → `AskUserQuestion`: "Where is your Claude memory chat export file? (Markdown file exported from claude.ai)"
   - Options: "Skip this source"
   - Free text for custom path
4. If not skipped → `Read` the file
5. Extract: industry, tech stack, interests, projects, domain expertise, personal context
6. Save chosen path to `dataSources.memoryFilePath`
7. Increment `sources_used`

### Step 1.5: PDF Resume

**Purpose:** Extract complete career history, tenure patterns, skill timeline, and education.

1. Check `dataSources.resumePath` in loaded state
2. If saved path exists and file readable → `AskUserQuestion`: "PDF resume: use saved `{path}`?"
   - Options: "Use saved path", "Enter different path", "Skip"
3. If no saved path → `AskUserQuestion`: "Do you have a PDF resume (LinkedIn export or any format)? Adds career history, tenure patterns, and skill verification to the analysis."
   - Options: "Skip this source"
   - Free text for path
4. If not skipped → `Read` the PDF (Claude reads PDFs natively)
5. Extract structured data per `${SKILL_DIR}/references/resume-extraction.md`
6. Save path to `dataSources.resumePath`
7. Increment `sources_used`

### Step 2: Insights Report

**Purpose:** Extract AI usage patterns, strengths, friction, session types from the CC Insights HTML report.

1. Check `dataSources.insightsReportPath` in state; default fallback: `~/.claude/usage-data/report.html`
2. `AskUserQuestion` with saved/default path, same pattern as Step 1
3. If not skipped → `Bash`: `python3 ${SKILL_DIR}/../../scripts/parse-insights.py "{path}"`
4. Parse JSON output — key fields: `project_areas`, `top_tools`, `languages`, `session_types`, `usage_narrative`, `whats_working`, `whats_hindering`, `friction_categories`, `impressive_things`, `horizon_cards`, `satisfaction_distribution`, `multi_clauding`, `stats`
5. Save path to `dataSources.insightsReportPath`
6. Increment `sources_used`

### Step 3: Session Metadata (7 days, all projects)

**Purpose:** Get recent work patterns — project diversity, tool usage, complexity indicators.

1. `Bash`: `python3 ${SKILL_DIR}/../../scripts/aggregate-sessions.py --days 7`
2. Parse JSON output — key fields: `sessions_total`, `projects`, `tool_distribution`, `language_distribution`, `complexity_indicators` (task_agent_pct, mcp_pct, web_search_pct), `averages`, `session_types`, `first_prompts`
3. If `sessions_total == 0` → note as unavailable, continue
4. Increment `sources_used`

### Step 4: Technology Explainer Config

**Purpose:** Get objective technology proficiency map (expert/intermediate/learning).

1. `Read` `~/.claude/technology-explainer.json`
2. If exists → extract `technologies` grouped by `level` (expert, intermediate, learning), `default_level`, `custom_sources`
3. If not found → note as unavailable
4. Increment `sources_used` if found

### Step 5: Installed Plugins

**Purpose:** Assess AI augmentation sophistication.

1. `Read` `~/.claude/settings.json` → extract `enabledPlugins` array
2. For each plugin path → `Read` the `plugin.json` inside its `.claude-plugin/` directory
3. Collect: plugin names, versions, descriptions, count of hooks/skills/commands
4. Increment `sources_used`

### Step 6: Stats Cache (optional)

**Purpose:** Longitudinal usage data — total sessions, daily patterns, model usage.

1. `Read` `~/.claude/stats-cache.json`
2. If exists → extract: total sessions, messages/day, model distribution, date range
3. If not found → note as unavailable, continue
4. Increment `sources_used` if found

---

## Phase 2: Interview (Steps 7-8)

### Step 7: Adaptive Interview

1. `Read` `${SKILL_DIR}/references/interview-questions.md`
2. For each question (Q1a, Q1b, Q2, Q3, Q4, Q5a, Q5b, Q6-Q12, Q14-Q18), apply re-ask logic:

   **Re-ask decision tree:**
   ```
   Has previous answer in state?
   ├── YES → How old is the answer?
   │   ├── < 6 months → SKIP: Display "Using your previous answer from {date}: {value}"
   │   └── >= 6 months → RE-ASK: Use AskUserQuestion with previous value as first option
   │                      (add "(previous answer)" suffix to the label)
   └── NO → Does a legacy key have a migratable answer? (see interview-questions.md § Legacy answer migration)
       ├── YES → PRE-FILL: Use migrated value as first option "(from previous session)", always confirm
       └── NO → Can data auto-answer this question?
           ├── YES → Pre-fill from data, confirm with user: "Based on your data, {value} — correct?"
           └── NO → ASK: Use AskUserQuestion with options from interview-questions.md
   ```

3. **Pacing rule**: Ask at most 2 questions per AskUserQuestion call. Tier 4 (Q10-Q12) MUST be asked one at a time — these require thoughtful answers.

4. **Q3 presentation**: When asking Q3 (core value), present the `examples_for_priming` from the question bank as context before the question. Expect free text answer — the examples normalize honest self-assessment, not constrain answers.

4b. **Q3b (conditional)**: If a PDF resume was provided in Step 1.5, ask Q3b immediately after Q3. Populate `{skills_from_resume}` with the top skills extracted from the resume. Skip Q3b entirely if no resume was provided.

5. **Auto-skip rules** (use data to pre-answer):
   - Q1a (role/industry): if memory file or resume contains clear role/industry info; resume pre-fills from most recent position title + company
   - Q5a (AI dependency, work): if session data shows >5 sessions/day → pre-fill "Essential"
   - Q5b (AI dependency, personal): if session data shows per-project diversity with personal projects → use as signal
   - Q7 (years experience): if memory file mentions experience level; resume computes total years from first position start date
   - Q8 (management vs IC): if resume has title patterns (Manager/Director → management; Engineer/Developer → IC)
   - Q10 (domain expertise): if technology-explainer has expert-level entries; resume extracts domain knowledge from experience descriptions
   - Q17 (languages): if memory file or resume mentions languages → pre-fill, confirm
   - Q18 (local market): if Q15 covers geography or memory/resume has location → pre-fill, confirm
   - Q18 should be asked before Q16 when both are unanswered (so currency placeholder adapts)
   - **Resume pre-fills always confirm** — never silently skip, since resumes can be outdated

6. **Tier 3 collapse**: If user gives 2+ consecutive minimal answers (picks first option without customizing), skip remaining Tier 3 questions

7. For `multiple_choice` questions → use `AskUserQuestion` with options from the question bank
8. For `free_text` questions → use `AskUserQuestion` with 2-3 example options + free text

### Step 8: Profile Synthesis

1. Combine all collected data + interview answers into a unified profile
2. Run contrastive analysis — compare self-reported vs data-observed:
   - AI dependency at work (Q5a) vs actual session frequency
   - AI dependency personal (Q5b) vs project diversity in session data
   - Work vs personal AI gap (Q5a vs Q5b) — split personality detection
   - Daily task breakdown (Q2) vs project_areas from insights
   - Claimed strengths (Q3, Q10) vs impressive_things from insights
   - Compensation (Q16) vs market rates for role (will compare in Step 9)
   - Session timestamps vs Q2 — detect night/weekend work patterns
   - (if resume provided) Resume title vs self-reported role (Q1a) → title inflation/deflation
   - (if resume provided) Resume tenure patterns vs career sentiment (Q1b) → says "Love it" but switches yearly?
   - (if resume provided) Resume skills vs technology-explainer proficiency → over/under-claiming
   - (if resume provided) Resume career span vs self-reported experience (Q7) → inaccurate self-assessment
   - (if Q3b answered) Resume vs reality — user's honest disclosure about resume embellishments
3. Note any discrepancies for the Blind Spots section
4. Compute preliminary risk scores for each of the 5 dimensions
5. **Burnout risk screening**: Count burnout indicators from analysis-framework.md (night work >30%, no rest days 7/7, dual workload, session marathon >3h, escalating volume >50% WoW). Record flag count for report generation.

---

## Phase 3: Research & Report (Steps 9-11)

### Step 9: Web Research

Perform 5-8 targeted `WebSearch` queries based on the user's profile:

1. `WebSearch`: "AI automation {user's industry} 2026 trends"
2. `WebSearch`: "{user's role title} AI replacement risk 2026"
3. `WebSearch`: "AI-resistant careers {user's domain}"
4. `WebSearch`: "{user's top technology} AI automation capabilities 2026" (if relevant)
5. `WebSearch`: "{user's role} salary range {Q18 city/market} 2026" (use Q18 answer for geography-specific searches)
6. `WebSearch`: "{recommended L3 direction} job market {Q18 city}" (target business discovery)
7. `WebSearch`: "{recommended L5 direction} freelance market demand 2026" (radical change validation)
8. `WebSearch`: "{recommended direction} salary range {user's geography}" (after directions are drafted, for remaining levels)

For each search → extract key findings, specific companies/products, salary data.
Increment `sources_used`.

### Step 10: Generate Report

1. `Read` `${SKILL_DIR}/references/analysis-framework.md`
2. `Read` `${SKILL_DIR}/references/report-template.md`
3. If resume was provided → `Read` `${SKILL_DIR}/references/resume-extraction.md` for metric computation reference
4. Compute final scores:
   - **Risk Matrix**: score each of 5 dimensions (1-5) with evidence
   - **AI Leverage Score**: compute from plugin count, session complexity, multi-clauding %, task-agent %, delegation maturity
   - **Delegation Maturity Level**: determine from session types, tool distribution, multi-clauding stats
   - (if resume provided) **Career Stability Score** and **Adaptability Evidence Score**: compute per analysis-framework.md § Career Trajectory Analysis
5. Generate 5 recommended career directions (one per amplitude level):
   - L1 (Optimize Current): always detailed — baseline reference
   - L2 (Lateral Move): always included — low-friction alternative
   - L3 (New Company): detailed if Q1b ≠ "Love it" OR risk ≥ MODERATE
   - L4 (Career Pivot): detailed if Q1b ∈ {"Want to pivot", "Need change"} OR Q14 ≠ "Conservative"
   - L5 (Radical Change): always included — stretch option
   - Each direction must reference specific AI-resistant properties
   - Each must include target business types (real companies, mixed local + remote, diverse industries)
   - L3-L5 must include a skills bridge table with concrete resources; when resume available, use enhanced 4-column format with "Years" column and dormant flags (⚠️) per report-template.md
   - Each must cite web research findings and salary ranges
6. **Anti-echo-chamber validation**: Run the 5-point checklist from analysis-framework.md. If any check fails → revise directions before finalizing:
   - Not all 5 in same industry
   - Not all 5 require same primary skill
   - At least one direction NOT about building/selling AI
   - At least one leverages an unconsidered skill
   - L5 is genuinely radical
7. **Salary anchoring** (if Q16 answered):
   - For each direction, compute delta vs current bracket from Q16
   - Populate "vs current" and "Minimum viable?" fields
   - Generate the Comparison Table with salary deltas
   - Add Financial Risk Assessment to Blind Spots section
8. **Burnout integration** (if 3+ burnout flags from Step 8):
   - Add Sustainability Warning subsection to Blind Spots
   - Extend all direction timelines by 3-6 months (or 6-12 months if 5/5 flags)
   - Recommend L1 as primary path if 5/5 flags
9. (if resume provided) **Career Trajectory section**: Generate per report-template.md — career timeline table, velocity classification, tenure stats, domain analysis, skill currency, and Resume vs Reality subsection (if Q3b answered)
10. (if resume provided) **Career Pattern Blind Spots**: Add to Blind Spots section — skill atrophy, stagnation indicators, education-career misalignment, resume embellishment patterns, predicted next transition window
11. Generate the complete report following `report-template.md` structure
9. **Display the report** in the terminal
10. **Save the report to disk:**
    - If `reportsDir` exists in loaded state → use it as default option
    - `AskUserQuestion`: "Where to save the report?"
      - Options: saved `reportsDir` or `/tmp/ai-fortune-reports/` (default, ephemeral), `~/.claude/ai-fortune/reports/` (persistent)
      - If saved `reportsDir` matches one of the options, show it as first option with "(previous choice)" suffix
    - `Bash`: `mkdir -p {chosen_dir}`
    - Filename: `YYYY-MM-DD_HH-MM-SS.md` (current timestamp, e.g. `2026-03-01_14-30-45.md`)
    - `Write` the complete report markdown to `{chosen_dir}/{filename}`
    - Confirm: "Report saved to {chosen_dir}/{filename}"

### Step 11: Save State

1. Build state object:
   ```json
   {
     "lastRun": "{ISO 8601 timestamp}",
     "lastReportPath": "{full path to saved report from Step 10}",
     "reportsDir": "{chosen directory from Step 10}",
     "dataSources": {
       "memoryFilePath": "{path from Step 1}",
       "resumePath": "{path from Step 1.5}",
       "insightsReportPath": "{path from Step 2}"
     },
     "answers": {
       "{question_key}": {
         "value": "{answer text}",
         "answeredAt": "{ISO 8601 timestamp}"
       }
     }
   }
   ```
   New answer keys: `career_direction_sentiment` (Q1b), `resume_vs_reality` (Q3b), `ai_dependency_work` (Q5a), `ai_dependency_personal` (Q5b), `current_compensation` (Q16), `working_languages` (Q17), `local_market` (Q18).
   Old keys `ai_dependency` and `career_satisfaction` are preserved in state but no longer actively read. They serve as migration sources: on first run after upgrade, their values seed defaults for the new split questions (Q5a/Q1b). See interview-questions.md § Legacy answer migration for the mapping table. Old keys age out naturally after 6 months.
2. `Write` to `~/.claude/ai-fortune.json`
3. Confirm: "State saved. Run `/ai-fortune` again anytime — it will remember your answers and skip recent ones."

---

## Error Handling

- **Missing data source**: Note as "❌ {source}" in the Data Sources table, continue with remaining sources
- **Script failure**: If parse-insights.py or aggregate-sessions.py fails, show stderr output, continue without that source
- **Minimum viable report**: The report can be generated with just interview answers + web research (0 automated data sources). Quality improves with more sources.
- **Web search failure**: If WebSearch is unavailable, note in the Industry AI Landscape section and provide analysis based on general knowledge

---

## Important Notes

- **Auto-save**: The report is displayed in the terminal and saved to a user-chosen directory (default: `/tmp/ai-fortune-reports/`). The chosen directory is remembered for future runs.
- **Privacy**: No data leaves the local machine except WebSearch queries (which use general terms, not personal data). Resume data stays local. Only aggregate career metrics (years, industry) inform WebSearch queries — never personal details (name, email, company names).
- **Re-runnability**: Running `/ai-fortune` again will skip recent answers and use saved file paths
- **Time estimate**: Full run with all sources takes ~5-10 minutes depending on interview length
