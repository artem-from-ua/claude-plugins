# Resume Extraction Template

Extract career data from the user's PDF resume (LinkedIn export, Europass, or any structured format). Claude reads PDFs natively via the Read tool — no external parsing needed.

**Minimum required:** 2+ positions with dates.

---

## Raw Extraction Fields

### Contact & Identity
- Name, current title, location, email (if present)

### Skills
- Explicitly listed skills section
- Technologies/tools mentioned in position descriptions

### Experience Timeline
Array of positions, each with:
```
{
  "company": "Company Name",
  "title": "Job Title",
  "startDate": "YYYY-MM",
  "endDate": "YYYY-MM or Present",
  "duration": "N years M months",
  "location": "City, Country (or Remote)",
  "description": "Key responsibilities and achievements",
  "technologies": ["tech1", "tech2"]
}
```

### Education
```
{
  "institution": "University Name",
  "degree": "Degree Type",
  "field": "Field of Study",
  "dates": "YYYY-YYYY"
}
```

### Certifications
List of certifications with issuing body and date (if present).

---

## Computed Metrics

### Career Timeline
- **Total years:** from first position start date to now
- **Role count:** number of distinct positions
- **Average tenure:** total years / role count
- **Longest tenure:** company name + duration
- **Shortest tenure:** company name + duration

### Career Velocity Classification
Classify based on promotion/transition patterns:

| Classification | Pattern | Evidence |
|---------------|---------|----------|
| **Rocket** | 1-2 year promotions within same company | Multiple title changes at same employer |
| **Steady Climber** | 2-4 year tenure, progressive titles | Regular upward moves |
| **Deep Specialist** | Same level across different companies | Title stays similar, company changes |
| **Explorer** | Frequent domain switches | Different industries every 2-3 years |
| **Settled** | Long tenure at one company | 5+ years at current employer |

### Domain Analysis
- **Distinct industries:** count unique industries across positions
- **Domain switches:** number of times industry changed between consecutive positions
- **Diversification score:** industries / roles (0-1 scale; 1 = every role in different industry)
- **Primary domain:** industry with most total years

### Company Pattern
- **Trajectory:** startup → enterprise, enterprise → startup, mixed, consistent size
- **Geographic mobility:** same city, same country, international

### Technology Adoption Timeline
- Group technologies by era (which positions they appeared in)
- **Adoption speed:** early adopter (uses tech within 1-2 years of release) vs late adopter

### Skill Currency
- **Current** (used in last 2 positions): actively practiced skills
- **Dormant** (listed in skills but not in recent descriptions): may be rusty
- **Emerging** (appear only in most recent position): newly acquired

### Career Trajectory Direction
Classify the overall trajectory:
- **IC deepening** — progressively senior IC titles (Junior → Senior → Staff → Principal)
- **Management track** — IC → Lead → Manager → Director
- **IC recovery** — Management → back to IC roles
- **Lateral exploration** — similar seniority, different domains/functions
- **Entrepreneurial** — employee → founder/freelance
- **Stabilization** — long tenure in current role, no recent transitions

---

## Format-Agnostic Notes

This template works with any structured PDF resume:
- **LinkedIn exports:** Usually well-structured with clear sections
- **Europass:** Standardized EU format with dates and skills sections
- **Custom resumes:** Extract whatever career data is available

If the resume is minimal (freelance portfolio, academic CV, etc.), extract what's available and note gaps. The analysis adapts to available data — partial extraction is better than skipping.
