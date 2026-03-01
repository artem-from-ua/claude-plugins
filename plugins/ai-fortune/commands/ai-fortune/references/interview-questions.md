# Interview Question Bank

Questions are organized by tier. Each question specifies:
- `key`: persistent storage key in `~/.claude/ai-fortune.json`
- `type`: `free_text` or `multiple_choice`
- `options`: for MC questions (used with AskUserQuestion)
- `skip_if_data`: data source fields that can answer this question automatically
- `tier`: determines whether the question is always asked or adaptive

---

## Tier 1: Role & Industry (always ask)

### Q1: Current Role & Industry
- **key:** `current_role`
- **type:** `free_text`
- **prompt:** "What is your current job title and industry? (e.g., 'Software Engineer, FinTech')"
- **skip_if_data:** memory file may contain role/industry context

### Q2: Typical Workday Breakdown
- **key:** `daily_tasks`
- **type:** `free_text`
- **prompt:** "How does your typical workday break down by activity? (e.g., '40% coding, 20% architecture, 20% meetings, 10% debugging, 10% docs')"
- **skip_if_data:** none (subjective)

### Q3: Core Value to Team
- **key:** `core_value`
- **type:** `free_text`
- **prompt:** "What is the single most important thing you bring to your team that would be hardest to replace?"
- **skip_if_data:** none (subjective)

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

### Q5: Personal AI Dependency
- **key:** `ai_dependency`
- **type:** `multiple_choice`
- **prompt:** "How dependent is your daily work on AI tools?"
- **options:**
  - "Essential — can't imagine working without AI"
  - "Significant — AI handles 30%+ of my work"
  - "Occasional — use AI for specific tasks"
  - "Rarely — tried but not integrated"
  - "Never — don't use AI tools"

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

## Tier 5: Aspirations (always ask)

### Q13: Career Satisfaction & Direction
- **key:** `career_satisfaction`
- **type:** `multiple_choice`
- **prompt:** "How do you feel about your current career trajectory?"
- **options:**
  - "Want to deepen — love what I do, want to go deeper"
  - "Open to change — happy but curious about alternatives"
  - "Considering pivot — actively exploring other paths"
  - "Need change — current path feels unsustainable"

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

---

## Adaptive Logic

### Auto-skip rules:
- If memory file reveals industry → mark Q1 as partially answered, confirm rather than ask fresh
- If session data shows heavy task-agent usage → Q5 can be pre-filled as "Essential/Significant"
- If technology-explainer config exists → skip tech-related parts of Q10

### Re-ask rules (persistent state):
- Answer < 6 months old → skip question, show "Using your previous answer from {date}: {value}"
- Answer >= 6 months old → re-ask with previous value as default option (first option + "(previous answer)" suffix)
- No previous answer → ask normally

### Tier 3 collapse:
- If user shows impatience (quick "skip" or "Other" answers) → collapse remaining Tier 3 questions
- Detect via: 2+ consecutive minimal answers
