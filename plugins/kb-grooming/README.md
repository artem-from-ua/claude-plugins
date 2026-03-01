# kb-grooming

> [!TIP]
> ✨ ***Find doc rot before your users do.***

Documentation health analysis for Claude Code projects. Scans all markdown files for structural problems and semantic compliance, then creates a GitHub epic with linked issues for each finding group.

> [!NOTE]
> [⚙️ How it works](#how-it-works) · [⚡ Commands](#commands) · [📦 Installation](#installation) · [⚙️ Setup](#setup) · [📝 Config](#config) · [🔗 Dependencies](#dependencies)

## 🎬 Demo <a name="demo"></a>

```markdown
> /kb-groom

Loading config… built-in defaults.

Structural scan complete: 8 findings in 42 files.
Semantic analysis complete: 3 findings.

Analyzed 42 documents.
- Broken links: 5
- Orphan documents: 2
- README compliance: 1
- Content actuality: 2
- `docs/setup.md` — references deprecated v2 API, current is v4
- `CONTRIBUTING.md` — TODO marker in "Release process" section (line 87)
- `README.md` — missing Installation section

Create GitHub issues?

> yep

Created issues:
- #210 — [EPIC] KB grooming report 2026-02-28
- #211 — Fix 5 broken documentation links
- #212 — Review 2 orphan documents
- #213 — Update stale API reference in setup.md
- #214 — Resolve TODO in CONTRIBUTING.md
- #215 — Add missing Installation section to README
```

If you decline issue creation, the full report is saved to `docs/audit/kb-grooming-report-2026-02-28.md`.

## ⚙️ How it works <a name="how-it-works"></a>

```
/kb-groom
    │
    ├─ Phase 1: structural scan (bash)
    │   ├─ brokenLinks        — resolve relative paths, check existence
    │   ├─ orphanDocs          — reference graph, find zero-inbound files
    │   ├─ duplicateContent    — hash content lines, flag matches
    │   ├─ claudemdOverflow    — CLAUDE.md > 200 lines or > 10K chars
    │   └─ mandatoryDocs       — README.md + CLAUDE.md existence
    │
    ├─ Phase 2: semantic analysis (LLM subagent)
    │   ├─ readmeCompliance    — 5-second test, nav, required sections
    │   ├─ terminologyConsistency — inconsistent terms, capitalization
    │   ├─ adrCompleteness     — required ADR sections and status values
    │   └─ contentActuality    — old dates, stale versions, TODO/FIXME
    │
    └─ GitHub issues (interactive)
        ├─ Epic: "KB grooming report YYYY-MM-DD"
        ├─ Child issues grouped by check type
        ├─ Individual issues for non-standard recommendations
        └─ Fallback: docs/audit/ report file if declined
```

## ⚡ Commands <a name="commands"></a>

| Command | What it does |
|---------|-------------|
| `/kb-groom` | Run full documentation health analysis |
| `/kb-grooming-setup` | Interactive configuration wizard |

## 📦 Installation <a name="installation"></a>

```bash
/plugin install kb-grooming@tribe-coding
```

## ⚙️ Setup <a name="setup"></a>

```bash
/kb-grooming-setup
```

The wizard walks through:
- **Model** — sonnet (default), haiku, or inherit
- **Scope** — which files/directories to analyze
- **Checks** — enable/disable individual checks (9 available)
- **Output** — GitHub issues, report file
- **GitHub** — labels and assignee for created issues
- **Config level** — project (`.claude-plugin/kb-grooming.json`) or global (`~/.claude/kb-grooming.json`)

## 📝 Config <a name="config"></a>

```json
{
  "model": "sonnet",
  "scope": {
    "include": ["README.md", "CLAUDE.md", "docs/", "*.md"],
    "exclude": ["node_modules/", ".git/", "vendor/", "dist/", "build/"]
  },
  "checks": {
    "brokenLinks": true,
    "orphanDocs": true,
    "duplicateContent": true,
    "claudemdOverflow": true,
    "mandatoryDocs": true,
    "readmeCompliance": true,
    "terminologyConsistency": true,
    "adrCompleteness": true,
    "contentActuality": true
  },
  "output": {
    "githubIssues": true,
    "reportFile": true
  },
  "github": {
    "labels": ["documentation", "kb-grooming"],
    "assignee": ""
  }
}
```

## 🔗 Dependencies <a name="dependencies"></a>

- bash, python3 (structural scan)
- `gh` CLI (optional, for GitHub issue creation)
- playbook plugin (optional, for rule-based semantic checks)
