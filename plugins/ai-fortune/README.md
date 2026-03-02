# AI Fortune

> [!TIP]
> ✨ ***Know your career blind spots before AI finds them for you.***

A Claude Code plugin that analyzes your AI usage patterns, runs an adaptive career interview, performs real-time industry research, and generates a personalized career direction report — not generic advice, but data-backed recommendations anchored in how you actually work.

> [!NOTE]
> [📦 Installation](#installation) · [🚀 How it works](#how-it-works) · [📊 Data Sources](#data-sources) · [🎯 Report Sections](#report-sections) · [💾 Persistent State](#persistent-state) · [⚙️ Configuration](#configuration) · [🔧 Troubleshooting](#troubleshooting)

## ✅ What it does <a name="what-it-does"></a>

- **`/ai-fortune`** — Run a full career direction analysis: data collection → adaptive interview → web research → structured report

One command that:
1. Mines 7 data sources (insights report, session metadata, plugins, tech proficiency, stats)
2. Runs an adaptive 18-question interview with sub-questions (skips what it already knows)
3. Researches your industry's AI landscape via 5-8 targeted web searches
4. Generates a 5-level amplitude spectrum of career directions — from optimize-in-place to radical change
5. Detects burnout risk from session patterns and flags sustainability warnings
6. Prevents echo chamber bias with diversity validation across domains and industries
7. Anchors salary comparisons against your current compensation bracket

## 📦 Installation <a name="installation"></a>

```bash
/plugin marketplace add Tribe-Coding/claude-plugins
/plugin install ai-fortune@tribe-coding
```

Select **ai-fortune** in `/plugin` → enable **auto-update**.

## 🚀 How it works <a name="how-it-works"></a>

```markdown
You: /ai-fortune

Claude: 📂 Loading persistent state...
        ✅ Found previous answers from 2026-02-15 (14 days ago)

        📊 Phase 1: Collecting data from 7 sources...
        ✅ Memory chat file — extracted industry: Tech, role context
        ✅ Insights report — 182 sessions, 5 project areas, plan-driven power user
        ✅ Session metadata (7d) — 23 sessions, 4 projects
        ✅ Technology explainer — 8 expert, 5 intermediate, 3 learning
        ✅ Installed plugins — 10 plugins (sophisticated AI augmentation)
        ✅ Stats cache — 299 total sessions over 39 days
        Sources: 6/7 used

        🎤 Phase 2: Adaptive interview...
        Using your previous answer from Feb 15: "Software Engineer, Tech"
        Using your previous answer from Feb 15: "40% code, 20% architecture..."

Claude: ❓ What is the single most important thing you bring to your team?
        (Be honest — there's no wrong answer. Examples:
         "I'm the only one who understands the legacy billing system"
         "No one else wants to maintain the CI/CD pipeline"
         "I translate between backend and product teams")

You: I bridge the gap between infrastructure and product — no one else speaks both languages.

        ... (12-18 adaptive questions, max 2 per prompt) ...

        🔍 Phase 3: Web research & report generation...
        Searching: "AI automation software engineering 2026 trends"
        Searching: "Software Engineer AI replacement risk 2026"
        Searching: "AI-resistant careers technology"
        Searching: "Software Engineer salary Kyiv 2026"
        Searching: "DevRel job market Europe remote 2026"

        📋 Generating Career Direction Report...

# Career Direction Report

Generated: 2026-03-01 | Sources: 7/8 used

## Your Profile
**Role:** Software Engineer | **Industry:** Tech | **Experience:** 6-10 years
**AI Adoption at org:** Widely adopted | **Personal AI dependency:** Essential

## AI Leverage Profile
**AI Leverage Score: 9/10** — Architect-level AI orchestration
**Delegation Maturity: Level 5 — Architect**

## Risk Assessment: Your Current Path
**Overall AI displacement risk: MODERATE**

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Task Repeatability | ⭐⭐⭐ | 40% coding (partially automatable) |
| Human Judgment | ⭐⭐⭐⭐ | Architecture decisions, stakeholder nav |
| Physical Presence | ⭐ | Fully remote |
| Regulatory/Trust | ⭐⭐ | No licensing requirements |
| Creative Synthesis | ⭐⭐⭐⭐ | Plugin ecosystem design, cross-domain |

## Recommended Directions (5-Level Amplitude Spectrum)

### L1 — Optimize Current: Senior AI Platform Engineer
### L2 — Lateral Move: Developer Relations Lead
### L3 — New Company: Staff Engineer at AI-Adopting Enterprise
### L4 — Career Pivot: Technical Product Manager
### L5 — Radical Change: Independent AI Tooling Consultant

| Level | Direction | Risk | Salary Delta | Timeline |
|-------|-----------|------|-------------|----------|
| L1 | Sr AI Platform Engineer | Low | +15% | 3-6mo |
| L2 | DevRel Lead | Low | +5% | 6-12mo |
| L3 | Staff Eng (Enterprise) | Med | +25% | 3-6mo |
| L4 | Technical PM | Med | +10% | 12-18mo |
| L5 | Independent Consultant | High | +40%/-20% | 18-24mo |

        ... (full report with action plan, blind spots, burnout check) ...

        💾 State saved to ~/.claude/ai-fortune.json
        📄 Report saved to /tmp/ai-fortune-reports/2026-03-01_14-30-45.md
        Run /ai-fortune again anytime — it remembers your answers.
```

## 📊 Data Sources <a name="data-sources"></a>

| # | Source | What it reveals | Required? |
|---|--------|----------------|-----------|
| 1 | Memory chat file | Industry, interests, domain context | Optional |
| 2 | CC Insights report | Usage patterns, strengths, friction | Optional |
| 3 | Session metadata (7d) | Recent work diversity, tool usage | Optional |
| 4 | Technology explainer | Skill proficiency map | Optional |
| 5 | Installed plugins | AI augmentation sophistication | Optional |
| 6 | Stats cache | Longitudinal usage trends | Optional |
| 7 | Web research | Industry AI landscape, salary data | Optional |
| 8 | Interview | Self-assessment, aspirations | **Required** |

The report can be generated with just the interview, but quality improves dramatically with more data sources. The plugin gracefully handles missing sources.

## 🎯 Report Sections <a name="report-sections"></a>

- **Your Profile** — role, industry, location, languages, compensation, tech proficiency map
- **AI Leverage Profile** — AI Leverage Score (0-10) and Delegation Maturity Model (Level 1-5), measuring how effectively you use AI as a force multiplier
- **Risk Assessment** — 5-dimension risk matrix with evidence-backed scores
- **Industry AI Landscape** — real-time web research on AI in your industry
- **Recommended Directions** — 5-level amplitude spectrum (Optimize Current → Lateral Move → New Company → Career Pivot → Radical Change) with target business types (named companies), salary ranges with delta vs current, and a comparison table
- **AI Orchestrator Advantage** — (for advanced users) why your AI orchestration skill is a competitive moat
- **Action Plan** — concrete 30-day, 6-month, and 1-2 year milestones
- **Blind Spots** — honest assessment of tech gaps, friction patterns, over-reliance risks, burnout risk detection (session-pattern-based), and financial risk assessment (salary anchoring vs current bracket)

## 💾 Persistent State <a name="persistent-state"></a>

Interview answers are saved to `~/.claude/ai-fortune.json` with timestamps. On re-runs:

- **Recent answers (< 6 months):** Skipped, shown as "Using your previous answer from {date}"
- **Stale answers (>= 6 months):** Re-asked with previous value as default option
- **File paths:** Saved so you don't re-enter them each time

Reports are automatically saved to a user-chosen directory (default: `/tmp/ai-fortune-reports/`) with timestamped filenames (e.g., `2026-03-01_14-30-45.md`). The chosen directory is remembered for future runs. Browse past reports to track how recommendations evolve over time.

## ⚙️ Configuration <a name="configuration"></a>

No setup wizard needed — just run `/ai-fortune`. The plugin discovers data sources automatically and asks about any it can't find.

State file: `~/.claude/ai-fortune.json`

## 🔧 Troubleshooting <a name="troubleshooting"></a>

**Scripts fail to run:**
```bash
python3 -m py_compile plugins/ai-fortune/scripts/parse-insights.py
python3 -m py_compile plugins/ai-fortune/scripts/aggregate-sessions.py
```

**No insights report:**
Generate one at [claude.ai/insights](https://claude.ai/insights) and download the HTML file to `~/.claude/usage-data/report.html`.

**Missing session metadata:**
Session metadata is collected automatically by Claude Code. If `~/.claude/usage-data/session-meta/` is empty, you may need to update Claude Code.

**Want to reset saved answers:**
Delete `~/.claude/ai-fortune.json` and re-run `/ai-fortune`.
