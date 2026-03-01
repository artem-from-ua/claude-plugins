---
name: ai-fortune
description: >
  Career direction analysis: interview + AI usage pattern mining to identify
  roles AI won't replace. Collects data from 7 sources, runs adaptive interview,
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
2. Set `sources_used = 0` counter to track how many of the 8 data sources produce data

---

## Phase 1: Data Collection (Steps 1-6)

Collect data from up to 7 sources. Each source is optional — if unavailable, note it and continue.

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
2. For each question (Q1-Q15), apply re-ask logic:

   **Re-ask decision tree:**
   ```
   Has previous answer in state?
   ├── YES → How old is the answer?
   │   ├── < 6 months → SKIP: Display "Using your previous answer from {date}: {value}"
   │   └── >= 6 months → RE-ASK: Use AskUserQuestion with previous value as first option
   │                      (add "(previous answer)" suffix to the label)
   └── NO → Can data auto-answer this question?
       ├── YES → Pre-fill from data, confirm with user: "Based on your data, {value} — correct?"
       └── NO → ASK: Use AskUserQuestion with options from interview-questions.md
   ```

3. **Auto-skip rules** (use data to pre-answer):
   - Q1 (role/industry): if memory file contains clear role/industry info
   - Q5 (AI dependency): if session data shows >5 sessions/day → pre-fill "Essential"
   - Q7 (years experience): if memory file mentions experience level
   - Q10 (domain expertise): if technology-explainer has expert-level entries

4. **Tier 3 collapse**: If user gives 2+ consecutive minimal answers (picks first option without customizing), skip remaining Tier 3 questions

5. For `multiple_choice` questions → use `AskUserQuestion` with options from the question bank
6. For `free_text` questions → use `AskUserQuestion` with 2-3 example options + free text

### Step 8: Profile Synthesis

1. Combine all collected data + interview answers into a unified profile
2. Run contrastive analysis — compare self-reported vs data-observed:
   - AI dependency (interview Q5) vs actual session frequency
   - Daily task breakdown (Q2) vs project_areas from insights
   - Claimed strengths (Q3, Q10) vs impressive_things from insights
3. Note any discrepancies for the Blind Spots section
4. Compute preliminary risk scores for each of the 5 dimensions

---

## Phase 3: Research & Report (Steps 9-11)

### Step 9: Web Research

Perform 3-5 targeted `WebSearch` queries based on the user's profile:

1. `WebSearch`: "AI automation {user's industry} 2026 trends"
2. `WebSearch`: "{user's role title} AI replacement risk 2026"
3. `WebSearch`: "AI-resistant careers {user's domain}"
4. `WebSearch`: "{user's top technology} AI automation capabilities 2026" (if relevant)
5. `WebSearch`: "{recommended direction} salary range {user's geography}" (after directions are drafted)

For each search → extract key findings, specific companies/products, salary data.
Increment `sources_used`.

### Step 10: Generate Report

1. `Read` `${SKILL_DIR}/references/analysis-framework.md`
2. `Read` `${SKILL_DIR}/references/report-template.md`
3. Compute final scores:
   - **Risk Matrix**: score each of 5 dimensions (1-5) with evidence
   - **AI Leverage Score**: compute from plugin count, session complexity, multi-clauding %, task-agent %, delegation maturity
   - **Delegation Maturity Level**: determine from session types, tool distribution, multi-clauding stats
4. Generate 3-4 recommended career directions:
   - Each direction must reference specific AI-resistant properties
   - Each must include a skills bridge table with concrete resources
   - Each must cite web research findings
5. Generate the complete report following `report-template.md` structure
6. **Display the report** in the terminal
7. **Save the report to disk:**
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
- **Privacy**: No data leaves the local machine except WebSearch queries (which use general terms, not personal data)
- **Re-runnability**: Running `/ai-fortune` again will skip recent answers and use saved file paths
- **Time estimate**: Full run with all sources takes ~5-10 minutes depending on interview length
