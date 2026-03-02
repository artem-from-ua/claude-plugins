# Interview Question Bank

Questions are organized by tier. Each question specifies:
- `key`: persistent storage key in `~/.claude/ai-fortune.json`
- `type`: `free_text` or `multiple_choice`
- `options`: for MC questions (used with AskUserQuestion)
- `skip_if_data`: data source fields that can answer this question automatically
- `tier`: determines whether the question is always asked or adaptive

---

## Tier 1: Role & Industry (always ask)

### Q1a: Current Role & Industry (factual)
- **key:** `current_role`
- **type:** `free_text`
- **prompt:** "What is your current job title and industry? (e.g., 'Software Engineer, FinTech')"
- **skip_if_data:** memory file may contain role/industry context

### Q1b: Career Direction Sentiment
- **key:** `career_direction_sentiment`
- **type:** `multiple_choice`
- **prompt:** "How do you feel about this career direction?"
- **options:**
  - "Love it — wouldn't change a thing"
  - "Open to change — happy but curious about alternatives"
  - "Want to pivot — actively exploring other paths"
  - "Need change — current path feels unsustainable"

### Q2: Typical Workday Breakdown
- **key:** `daily_tasks`
- **type:** `free_text`
- **prompt:** "How does your typical workday break down by activity? (e.g., '40% coding, 20% architecture, 20% meetings, 10% debugging, 10% docs')"
- **skip_if_data:** none (subjective)

### Q3: Core Value to Team
- **key:** `core_value`
- **type:** `free_text`
- **prompt:** "What is the single most important thing you bring to your team that would be hardest to replace? Be honest — there's no wrong answer. If your position is retained by circumstance rather than unique skill, say that."
- **skip_if_data:** none (subjective)
- **examples_for_priming:**
  - "I'm the only one who understands the legacy billing system" (legacy knowledge)
  - "No one else wants to maintain the CI/CD pipeline, so I do it" (only willing worker)
  - "I translate between the backend team and the product team" (cross-team coordination)

### Q3b: Resume vs Reality (conditional)
- **key:** `resume_vs_reality`
- **type:** `free_text`
- **prompt:** "Looking at your resume, it highlights {skills_from_resume}. Is there anything that doesn't fully reflect your current reality? (e.g., skills you listed but rarely use now, titles that over/understate your role, descriptions that are more aspirational than factual). Be honest — this helps us identify where the market sees you vs where you actually are."
- **skip_if_data:** skip if no resume provided
- **tier:** 1 (always ask when resume available)

---

## Tier 2: AI Context (always ask)

### Q4: AI Adoption at Organization
- **key:** `org_ai_adoption`
- **type:** `multiple_choice`
- **prompt:** "How widely is AI adopted in your organization?"
- **options:**
  - "Widely adopted — most teams use AI tools daily"
  - "Early adoption — several teams experimenting"
  - "Pilot stage — one or two teams testing"
  - "Not adopted — no formal AI initiatives"
  - "Actively resisted — organizational pushback"

### Q5a: AI Dependency — Work
- **key:** `ai_dependency_work`
- **type:** `multiple_choice`
- **prompt:** "How dependent is your WORK (day job) on AI tools?"
- **options:**
  - "Essential — can't imagine working without AI"
  - "Significant — AI handles 30%+ of my work"
  - "Occasional — use AI for specific tasks"
  - "Rarely — tried but not integrated"
  - "Never — don't use AI tools"

### Q5b: AI Dependency — Personal/Side Projects
- **key:** `ai_dependency_personal`
- **type:** `multiple_choice`
- **prompt:** "How dependent are your PERSONAL/side projects on AI tools?"
- **options:**
  - "Essential — AI is central to my side work"
  - "Significant — AI handles 30%+ of side project work"
  - "Occasional — use AI for specific personal tasks"
  - "Rarely — tried but not integrated"
  - "N/A — no side projects"

### Q6: AI Replacement Predictions
- **key:** `ai_replacement_2yr`
- **type:** `free_text`
- **prompt:** "Which specific tasks in YOUR role do you think AI will handle within 2 years?"
- **skip_if_data:** none (subjective prediction)

---

## Tier 3: Career Context (adaptive — skip if data available)

### Q7: Years of Experience
- **key:** `years_experience`
- **type:** `multiple_choice`
- **prompt:** "How many years of professional experience do you have?"
- **options:**
  - "0-2 years (early career)"
  - "3-5 years (mid-level)"
  - "6-10 years (senior)"
  - "11-20 years (staff/principal)"
  - "20+ years (veteran)"
- **skip_if_data:** memory file may mention experience level

### Q8: Management vs IC
- **key:** `management_vs_ic`
- **type:** `multiple_choice`
- **prompt:** "What best describes your current role?"
- **options:**
  - "Team lead (IC + some management)"
  - "Manager/Director (primarily people management)"
  - "Individual Contributor (no direct reports)"
  - "Mixed (varies by project)"

### Q9: Client-facing vs Back-office
- **key:** `client_facing`
- **type:** `multiple_choice`
- **prompt:** "How much of your work is client/customer-facing?"
- **options:**
  - "Primarily client-facing (sales, consulting, support)"
  - "Mixed (some client interaction)"
  - "Primarily back-office (internal tools, infrastructure)"
  - "Fully internal (no external stakeholders)"

---

## Tier 4: Differentiators (always ask)

### Q10: Domain Expertise
- **key:** `domain_expertise`
- **type:** `free_text`
- **prompt:** "What specialized domain knowledge or expertise do you have that would be hard for AI to replicate? (e.g., regulatory knowledge, industry relationships, proprietary systems)"
- **skip_if_data:** none

### Q11: Creative vs Operational
- **key:** `creative_vs_operational`
- **type:** `multiple_choice`
- **prompt:** "Where does most of your value come from?"
- **options:**
  - "Creative/strategic — designing solutions to novel problems"
  - "Balanced — mix of creative and operational"
  - "Operational — executing well-defined processes efficiently"
  - "Interpersonal — relationships, negotiation, persuasion"

### Q12: Physical Presence Requirements
- **key:** `physical_presence`
- **type:** `multiple_choice`
- **prompt:** "Does your role require physical presence?"
- **options:**
  - "Fully remote — everything is digital"
  - "Occasionally in-person (meetings, events)"
  - "Regularly in-person (lab, manufacturing, site visits)"
  - "Always in-person (hands-on work, equipment)"

---

## Tier 5: Aspirations & Context (always ask)

### Q14: Risk Tolerance
- **key:** `risk_tolerance`
- **type:** `multiple_choice`
- **prompt:** "What's your tolerance for career risk?"
- **options:**
  - "Conservative — prefer stability, incremental moves"
  - "Moderate — willing to take calculated risks"
  - "Aggressive — ready for bold moves if upside is clear"

### Q15: Constraints on Pivot
- **key:** `pivot_constraints`
- **type:** `free_text`
- **prompt:** "What constraints would limit a career pivot? (e.g., geographic, financial, family, language, visa, industry certifications)"
- **skip_if_data:** none

### Q16: Current Compensation
- **key:** `current_compensation`
- **type:** `multiple_choice`
- **prompt:** "What is your current annual compensation range? (in {currency})"
- **options:**
  - "Under {currency}30k"
  - "{currency}30k–60k"
  - "{currency}60k–100k"
  - "{currency}100k–150k"
  - "{currency}150k–250k"
  - "Over {currency}250k"
- **skip_if_data:** never auto-skip (sensitive, always confirm)
- **note:** `{currency}` placeholder is resolved from Q18 answer or defaults to `$`

### Q17: Working Languages
- **key:** `working_languages`
- **type:** `free_text`
- **prompt:** "What languages do you work in professionally? (e.g., 'English (native), Ukrainian (native), German (B2)')"
- **skip_if_data:** memory file may mention languages

### Q18: Local Market
- **key:** `local_market`
- **type:** `free_text`
- **prompt:** "Where are you based and what job market do you primarily target? (e.g., 'Kyiv, Ukraine — open to EU remote')"
- **skip_if_data:** Q15 may cover geography; memory file may mention location

---

## Adaptive Logic

### Auto-skip rules:
- If memory file reveals industry → mark Q1a as partially answered, confirm rather than ask fresh
- If session data shows heavy task-agent usage → Q5a can be pre-filled as "Essential/Significant"
- If session data shows per-project AI usage patterns → Q5b can use project diversity as signal
- If technology-explainer config exists → skip tech-related parts of Q10
- If memory file mentions languages → Q17 can be pre-filled, confirm
- If Q15 already covers geography or memory has location → Q18 can be pre-filled, confirm
- Q18 should be asked before Q16 when both are unanswered (so currency can adapt)

### Resume-based auto-skip rules:
When a PDF resume is provided, pre-fill the following questions from extracted data. **Always confirm with the user — never silently skip** (resumes can be outdated):
- Q1a (current role): pre-fill from most recent position title + company
- Q7 (years experience): compute total years from first position start date
- Q8 (management vs IC): infer from title patterns (Manager/Director → management; Engineer/Developer → IC)
- Q10 (domain expertise): extract domain knowledge from experience descriptions
- Q17 (languages): if resume mentions languages spoken
- Q18 (local market): pre-fill from resume header location

### Re-ask rules (persistent state):
- Answer < 6 months old → skip question, show "Using your previous answer from {date}: {value}"
- Answer >= 6 months old → re-ask with previous value as default option (first option + "(previous answer)" suffix)
- No previous answer → ask normally

### Legacy answer migration:
When a question is split, removed, or substantially reworded across versions, old answers in state can seed defaults for new questions:

| Old Key | Old Question | New Key(s) | Migration |
|---------|-------------|------------|-----------|
| `ai_dependency` | Q5 "How dependent is your daily work on AI tools?" | `ai_dependency_work` (Q5a) | Use old value as default for Q5a; ask Q5b fresh |
| `career_satisfaction` | Q13 "How do you feel about your current career trajectory?" | `career_direction_sentiment` (Q1b) | Use old value as default for Q1b (options map 1:1) |

Rules:
- If old key has a value and new key does not → pre-fill new question with old value as first option "(from previous session)" and ask for confirmation
- If both old and new keys have values → ignore old key, use new key
- Never auto-skip based on a migrated value — always confirm with the user
- Old keys are never deleted from state; they age out naturally after 6 months

### Tier 3 collapse:
- If user shows impatience (quick "skip" or "Other" answers) → collapse remaining Tier 3 questions
- Detect via: 2+ consecutive minimal answers
