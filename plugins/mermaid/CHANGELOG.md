# Changelog

## 0.1.0 — 2026-04-15

- Initial release.
- SessionStart hook injects Mermaid base rules.
- PostToolUse hook validates Mermaid blocks in `.md` files via Kroki after Write/Edit.
- Pre-commit hook installed in projects to block commits with invalid Mermaid syntax (marker-delimited, non-destructive).
- `mermaid-diagram-guide` skill covering 6 common types: flowchart, sequence, state, class, ER, gantt.
- `/mermaid-validate` command for on-demand repo-wide validation.
- `/mermaid-uninstall` command to remove the pre-commit section.
- Self-hosted Kroki supported via `MERMAID_KROKI_URL` env var.
