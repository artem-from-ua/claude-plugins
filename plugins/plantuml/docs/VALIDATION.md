# PlantUML Validation

Every diagram has two parts: a `plantuml` source block and an image URL below it. Validation detects diagrams whose image URL no longer matches the source block (stale URL) or is missing entirely.

## Manual validation

Run `/plantuml:plantuml-validate` in any Claude Code session to check all `.md` files in the project. Claude will list any mismatches and offer to auto-fix them.

## Git pre-commit hook

Installed automatically on session start. Blocks commits when any diagram URL is stale — run `/plantuml:plantuml-validate` to fix before committing.

## GitHub Actions CI

A workflow template is included at `templates/plantuml.yml`. Copy it to `.github/workflows/` to run validation on every PR.
