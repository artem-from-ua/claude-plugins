---
name: kb-groom
description: >
  Analyze documentation health: run structural checks (broken links, orphans,
  duplicates, CLAUDE.md overflow, mandatory docs), then semantic analysis
  (README compliance, terminology, ADR completeness, content actuality).
  Create GitHub epic with linked issues for findings.
  Keywords: documentation audit, kb grooming, doc health, knowledge base.
---

# KB Grooming — Documentation Health Analysis

Run a full documentation health check on the current project.

## Steps

### 1. Load configuration

Resolve config using this priority (first found wins):
1. Project: `.claude-plugin/kb-grooming.json` in the project root
2. Legacy project: `.claude/kb-grooming.json` in the project root
3. Global: `~/.claude/kb-grooming.json`
4. Defaults: use built-in defaults from `${SKILL_DIR}/../../templates/kb-grooming.json`

If no config file exists anywhere, use `AskUserQuestion`:
- **Use defaults** — proceed with built-in configuration
- **Run setup first** — invoke `/kb-grooming-setup` and stop

Display which config was loaded (path or "built-in defaults").

### 2. Structural scan

Run the structural analysis script:

```bash
env CLAUDE_PROJECT_DIR="<project_root>" KB_CONFIG_FILE="<config_path>" bash "${SKILL_DIR}/../../scripts/kb-structural-scan.sh"
```

The script outputs a file path to a JSON report. Read that file to get structural findings.

Display a brief status: "Structural scan complete: X findings in Y files."

### 3. Load context for semantic analysis

Gather these inputs for the semantic subagent:

1. **Structural report** — the JSON from step 2
2. **Playbook presets** — if playbook plugin is configured, read active preset files from `~/.claude/plugins/cache/tribe-coding/playbook/*/presets/`. Extract only RULES zones (content between `<!-- RULES -->` markers). Skip if playbook is not installed.
3. **Project CLAUDE.md** — read `CLAUDE.md` from project root (if exists)
4. **Global CLAUDE.md** — read `~/.claude/CLAUDE.md` (if exists)
5. **Documentation files** — read all `.md` files in scope (per config `scope.include` / `scope.exclude`). For files longer than 500 lines: include first 100 lines + last 50 lines with a `[... truncated ...]` marker.

### 4. Semantic analysis

Check which semantic checks are enabled in config (`readmeCompliance`, `terminologyConsistency`, `adrCompleteness`, `contentActuality`).

If at least one semantic check is enabled, launch a subagent:

- **Model**: use `config.model` value — `"sonnet"` maps to model `sonnet`, `"haiku"` maps to model `haiku`, `"inherit"` means do not specify a model (use default)
- **Subagent type**: `general-purpose`
- **Prompt**: read `${SKILL_DIR}/references/semantic-prompt.md` as the system instructions. Include only the enabled checks. Append the gathered context (structural report, playbook rules, CLAUDE.md files, doc contents) as input data.

The subagent returns JSON with `semanticFindings[]` and `semanticSummary`.

If all semantic checks are disabled, skip this step.

### 5. Present results

Combine structural findings (from step 2) and semantic findings (from step 4) into a unified list.

**If zero findings** — display only:

> Analyzed N documents. No issues found.

Then stop (skip step 6).

**If findings exist** — display a status block:

1. **Document count**: "Analyzed N documents."
2. **Typical findings by type** — one line per check type that has findings, using human-readable names:
   - brokenLinks → "Broken links"
   - orphanDocs → "Orphan documents"
   - duplicateContent → "Duplicate content"
   - claudemdOverflow → "CLAUDE.md overflow"
   - mandatoryDocs → "Missing mandatory files"
   - readmeCompliance → "README compliance"
   - terminologyConsistency → "Terminology inconsistency"
   - adrCompleteness → "ADR completeness"
   - contentActuality → "Content actuality"

   Format: `- Broken links: 5` (count per type)

3. **Non-standard recommendations** — semantic findings that don't fit neatly into a check type category, or have unique `suggestedFix` values. List them as a brief bullet list (file + one-line summary). Skip if none.

If `config.output.reportFile` is true, write the full report to `/tmp/kb-grooming-report-{timestamp}.md` using the format from `${SKILL_DIR}/references/report-template.md` as a guide. Display the report file path.

### 6. GitHub issues

Skip this step if `config.output.githubIssues` is false or if there are no findings.

First verify: `gh auth status` — if not authenticated, skip with a message.

#### Epic issue

Create an epic issue that tracks the overall grooming session:
- **Title**: `[EPIC] KB grooming report YYYY-MM-DD`
- **Body**: the full status block from step 5 (document count, findings by type, non-standard recommendations) + a checklist of child issues to be created below
- **Labels**: from `config.github.labels` (default: `["documentation", "kb-grooming"]`)
- **Assignee**: from `config.github.assignee` (if non-empty)

#### Child issues

Group remaining findings into child issues:

1. **Typical findings** — one issue per check type. Title format: `Fix N broken documentation links`, `Remove 3 orphan documents`, etc. Body uses `${SKILL_DIR}/references/issue-template.md` as a guide.
2. **Non-standard recommendations** — one issue per unique recommendation. Title: short summary of the recommendation. Body: file, context, suggested action.

Ask the user with `AskUserQuestion`: "Create GitHub issues?" with options:
- **Yes** — create epic + child issues
- **No** — save report to file instead

If the user confirms, create all issues:
```bash
gh issue create --title "..." --body "..." --label "documentation" --label "kb-grooming"
```

After creating all child issues, update the epic body with actual issue numbers (checklist links). Then add a reference comment to each child:
```bash
gh issue comment <child_N> --body "Parent epic: #<epic_N>"
```

Display a summary list of created issues (number + title).

#### Fallback: report file

If the user declines, write a detailed report file instead:

- **Path**: `docs/audit/kb-grooming-report-YYYY-MM-DD.md` (create `docs/audit/` if it doesn't exist)
- **Content**: full report using `${SKILL_DIR}/references/report-template.md` as a guide — document count, all findings grouped by check type with file/line/message/severity, non-standard recommendations, and suggested actions
- Display: "Report saved to `docs/audit/kb-grooming-report-YYYY-MM-DD.md`"

This also applies when `gh auth status` fails (not authenticated) — write the report file instead of silently skipping.
