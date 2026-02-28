---
name: technology-explainer-setup
description: >
  Interactive setup wizard for technology proficiency levels. Creates or updates
  ~/.claude/technology-explainer.json. Run this command to configure how Claude
  adapts explanation depth per technology.
  Keywords: technology explainer setup, configure proficiency, explanation depth.
---

# Technology Explainer Setup

Configure how Claude adapts explanation depth based on your proficiency with each technology.

## Steps

### 1. Educational intro

Explain the three proficiency levels to the user:

- **Expert** — You know this technology deeply. Claude gives brief, no-theory answers. Just the facts and commands.
- **Intermediate** — You use this technology regularly but in limited scope. Claude explains nuances, gotchas, and edge cases but skips the basics.
- **Learning** — You're actively studying this technology. Claude provides detailed theory, concrete examples, and step-by-step walkthroughs.

Explain that "technology" is broadly defined: operating systems (Linux, macOS), programming languages (Python, Java), tools (Docker, Git), platforms (AWS, GCP), workflows (CI/CD, Agile), and anything else the user works with.

### 2. Show existing config

Read `~/.claude/technology-explainer.json`. If it exists, display the current configuration as a formatted table showing technologies grouped by level, the default level, and any configured sources. If it doesn't exist, say "No proficiency config found — let's create one."

### 3. Ask expert technologies

Use `AskUserQuestion` with a free-text "Other" option. Remind the criteria: "Technologies you know deeply. Claude will give brief, no-theory answers."

Suggest common categories: operating systems, shells, languages, IDEs, version control.

### 4. Ask learning technologies

Use `AskUserQuestion` with a free-text "Other" option. Remind the criteria: "Technologies you're actively studying. Claude will provide detailed theory, examples, and step-by-step explanations."

### 5. Ask intermediate technologies

Use `AskUserQuestion` with a free-text "Other" option. Remind the criteria: "Technologies you use regularly but in limited scope. Claude will explain nuances and gotchas but skip basics."

### 6. Ask default level

Use `AskUserQuestion`:
- **Learning** (Recommended) — detailed explanations for anything not listed
- **Intermediate** — nuanced explanations for unlisted technologies
- **Expert** — brief answers for everything not listed

### 7. Ask about custom sources (optional)

Use `AskUserQuestion`: "Do you want to add preferred documentation or style guides for specific technologies?" (e.g., `terraform → HashiCorp docs`, `python → PEP 8`).

If yes, ask for technology name and URL/reference pairs. Collect as many as the user wants.

### 8. Write config and confirm

Write `~/.claude/technology-explainer.json` with the collected data. Display a summary table and remind: "Restart your session or run `/clear` for changes to take effect."
