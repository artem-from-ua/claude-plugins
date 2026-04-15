# Changelog

## 0.2.0 — 2026-04-15

- Skill guide now teaches semantic styling: shape vocabulary (cylinder = storage, hexagon = orchestrator, stadium = actor, etc.), `linkStyle` color palette (blue = data, orange = control, green = storage, purple = feedback), and a default `classDef` set (storage, external, critical, deprecated).
- Added recommended `%%{init}%%` layout block for flowcharts over ~8 nodes (curve, nodeSpacing, rankSpacing, htmlLabels).
- Accessibility: `accTitle` and `accDescr` directives are now required for every supported diagram type.
- Added `click` handler example for linking nodes to source files / external docs.
- Flowchart example rewritten to demonstrate the full styling pattern; minimal example retained for quick READMEs.

## 0.1.0 — 2026-04-15

- Initial release.
- SessionStart hook injects Mermaid base rules.
- PostToolUse hook validates Mermaid blocks in `.md` files via Kroki after Write/Edit.
- Pre-commit hook installed in projects to block commits with invalid Mermaid syntax (marker-delimited, non-destructive).
- `mermaid-diagram-guide` skill covering 6 common types: flowchart, sequence, state, class, ER, gantt.
- `/mermaid-validate` command for on-demand repo-wide validation.
- `/mermaid-uninstall` command to remove the pre-commit section.
- Self-hosted Kroki supported via `MERMAID_KROKI_URL` env var.
