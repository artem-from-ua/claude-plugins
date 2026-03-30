# Changelog

All notable changes to the PlantUML plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-03-29

### Added
- **Mermaid diagram support** across the entire plugin
- Mermaid syntax validation in `plantuml-encode.py` (`--check` now validates both formats, `--check-mermaid-only` for mermaid-only)
- 9 Mermaid-only diagram types in diagram guide: flowchart, pie, gitgraph, timeline, sankey, XY chart, quadrant, requirement, block, journey
- `references/mermaid-syntax.md` — syntax examples for all Mermaid diagram types
- PostToolUse hook validates Mermaid syntax on `.md` file edits (non-blocking warnings)
- Pre-commit template validates both PlantUML URLs and Mermaid syntax

### Changed
- **BREAKING:** SessionStart rules restructured for dual-format (Mermaid + PlantUML)
- **BREAKING:** `--check` flag now validates both PlantUML URLs AND Mermaid syntax (previously PlantUML only)
- Diagram guide SKILL.md expanded from 17 to 26 diagram types with Format column and recommendations
- Default format preference: Mermaid when both formats support a type
- Terminal rendering for Mermaid: hand-drawn ASCII approximation (no API call, no raw source shown)
- Pre-commit error messages updated for both formats
- Validation command covers both PlantUML and Mermaid

## [1.8.0] - 2026-03-07

### Added
- ACK suppression rules for sequence diagrams (`skills/plantuml-diagram-guide/references/sequence.md`)
- Arrow style conventions: sync `->` / `-->`, async `->>` / `-->>`
- Decision table with 6 concrete ACK suppression scenarios
- `group` fragment guidance for clustering request-response pairs
- Visual styling defaults: thicker arrows (`sequenceArrowThickness 1.5`), gray lifelines (`LifeLineBorderColor #C0C0C0`)
- Legend format template for suppressed ACK diagrams
- 4 new acceptance test scenarios (Test 12: ACK Suppression)

### Changed
- Sequence row in SKILL.md now documents `->>` syntax
- `inject-rules.sh` SessionStart output includes visual styling skinparam rules and sequence reference note

## [1.7.2] - 2026-03-03

### Changed
- Renamed `inject-base-rules.sh` → `inject-rules.sh` to follow SessionStart script naming convention
- Updated all documentation references (ACCEPTANCE_TESTS.md, plugin-behavior.md, INITIAL_PLAN.md, context/README.md)
- Added SessionStart Script Naming convention to `docs/conventions.md`

## [1.5.9] - 2026-02-14

### Removed
- **BREAKING:** Removed deprecated `scripts/render-ascii.sh` wrapper (unused since v1.5.6)
- Removed obsolete permission prompt workaround documentation from ACCEPTANCE_TESTS.md

### Changed
- PreToolUse hook: Removed `render-ascii.sh` pattern (no longer needed)
- Updated hook comment to reflect current operations (encoding, temp files)

### Fixed
- Cleaned up outdated test sections referencing removed wrapper script

### Technical Details
- `render-ascii.sh` was wrapper for v1.4.1-1.5.5 to reduce command length
- v1.5.6+ uses WebFetch approach which doesn't need wrapper
- PreToolUse hooks (v1.5.0+) eliminate permission prompts entirely
- No functionality lost — all operations work via direct `plantuml-encode.py` calls

## [1.5.8] - 2026-02-14

### Fixed
- Relaxed PreToolUse hook patterns to allow any `/tmp/*.puml` files (not just files with "diagram"/"plantuml" keywords in name)
- Eliminates permission prompts for temp file operations with any naming convention

### Changed
- PreToolUse patterns now match:
  - `cat > /tmp/*.puml` (any .puml file creation via Bash)
  - `rm /tmp/*.puml` (any .puml file deletion)
  - Write tool for `/tmp/*.puml` (any .puml file via Write tool)

## [1.5.7] - 2026-02-14

### Fixed
- PreToolUse hook now auto-allows `plantuml-encode.py` without `--render-ascii` flag
- Eliminates permission prompts for encoding step in WebFetch workflow

## [1.5.6] - 2026-02-14

### Fixed
- **CRITICAL:** Reverted to WebFetch approach for ASCII rendering (fixes UI collapse regression)
- ASCII diagrams now display fully without "… +60 lines (ctrl+o to expand)" collapse

### Changed
- ASCII rendering workflow: encode → WebFetch from `plantuml.com/txt/{encoded}` → display
- Reverts breaking change from v1.4.0-1.5.5 which used Bash commands

### Technical Details
- Claude Code UI automatically collapses ALL Bash tool results >40-50 lines
- WebFetch results are NOT collapsed by UI
- Pre-1.4.0 used WebFetch (worked), 1.4.0-1.5.5 used Bash (broke), 1.5.6+ reverted to WebFetch

## [1.5.5] - 2026-02-14

### Fixed (unsuccessful)
- Attempted file-based output with Read tool to avoid UI collapse
- Did not resolve issue — Bash tool results still collapsed

## [1.5.4] - 2026-02-14

### Changed (unsuccessful)
- Attempted switch back to direct `python3 plantuml-encode.py --render-ascii` call
- Wrapper removed from SessionStart instructions
- Did not resolve UI collapse issue

## [1.5.3] - 2026-02-14

### Added
- PreToolUse hook pattern for auto-allowing `rm /tmp/(diagram|plantuml)*.puml` cleanup commands

### Fixed
- Eliminates permission prompts for temp file cleanup step

## [1.5.2] - 2026-02-14

### Fixed
- **CRITICAL:** SessionStart hook now dynamically resolves plugin path at runtime
- Fixed `${CLAUDE_PLUGIN_ROOT}` variable not resolving in SessionStart heredoc output
- Prevents fallback to wrong plugin versions

### Changed
- `inject-base-rules.sh` now uses `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"`
- Outputs absolute paths like `/Users/.../cache/tribe-coding/plantuml/1.5.2/scripts/plantuml-encode.py`
- Heredoc changed from `<<'RULES'` to `<<RULES` to enable variable substitution
- Escaped all backticks and `$` symbols in heredoc to prevent command execution

### Technical Details
- `${CLAUDE_PLUGIN_ROOT}` only works in hooks.json `command` fields, NOT in text output
- SessionStart hooks output text that becomes part of system prompt
- Variables must be resolved at script execution time, not by Claude Code

## [1.5.1] - 2026-02-13

### Added
- PreToolUse hook for Write tool to auto-allow PlantUML diagram files in `/tmp`
- Pattern: `/tmp/.*diagram.*\.puml`

### Fixed
- Eliminates permission prompts when using Write tool for temp PlantUML files

## [1.5.0] - 2026-02-13

### Added
- PreToolUse hook for Bash tool to auto-allow PlantUML rendering commands
- `scripts/allow-rendering.sh` — hook script with patterns for:
  - `render-ascii.sh` wrapper commands
  - `plantuml-encode.py --render-ascii` commands
  - `cat > .*(diagram|plantuml).*\.puml` temp file creation

### Changed
- All PlantUML rendering operations now execute without permission prompts
- Hook timeout: 5 seconds

### Technical Details
- PreToolUse hooks intercept tool calls before execution
- Return `permissionDecision: "allow"` for matching patterns
- Passthrough (exit 0) for non-matching commands to maintain security

## Earlier Versions

See git history for versions 1.0.0 - 1.4.2.
