# Changelog

All notable changes to the PlantUML plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-09-08

### Changed
- **Diagram source is now collapsed into a `<details>` block.** A reader opening a document sees the rendered diagram and one `Diagram source` line instead of the text that produced it; a long diagram no longer pushes its own image off the first screen. The PostToolUse hook applies the wrapper on save, so existing documents convert as they are edited. This is the breaking change: markdown files are restructured, not merely given a corrected URL
- The wrapper goes around the ordinary ```` ```plantuml ```` fence rather than replacing it. Fence content is code text, so a literal `-->` or `</details>` inside a diagram label is escaped by the renderer instead of acted on — and `grep -rl '```plantuml'`, which is how `/plantuml-validate` finds files, keeps working unchanged
- The three near-duplicate block patterns are replaced by one extractor that reports each diagram's form and one emitter that renders it, so `--check`, `--sync` and `--lint` can no longer disagree about what a diagram is
- The sync hook no longer touches every `.md` it is handed. It skips vendored and generated trees (`node_modules`, `vendor`, `dist`, `build`, `.venv`, `site-packages`), anything under `.git`, files outside a git repository, and files git is ignoring. Adding a missing URL was small enough to go unnoticed anywhere; restructuring a document is not
- `/plantuml-validate` reports a third class of problem: a diagram the tool cannot maintain, meaning a half-written `<details>` wrapper or a fence indented in a list or inside a blockquote. These are reported and left untouched rather than rewritten, because rewriting them would guess at what the author meant

### Added
- `<!-- plantuml-source: visible -->` on its own line keeps a whole document's sources visible; the same comment before a single fence, or `visible` in the fence info string, keeps one diagram. Every form of opt-out lives outside the diagram source, so choosing one re-encodes no URLs. The four documents in this repository whose purpose is to show PlantUML source — the validation guide, both syntax references, and the acceptance tests whose fixtures are fed back to the tool — carry the file-level marker and kept every URL they had
- `--dry-run`, used with `--sync`, prints a unified diff of what would change and writes nothing, exiting 1 if any file would change. It makes a repository-wide conversion reviewable before it lands, and doubles as a CI check that a tree is already in the expected form
- The generated wrapper carries a `<!-- plantuml-generated -->` marker, so a `<details>` written by hand is recognized as someone else's and left as it stands — its `<summary>` text is never overwritten

### Fixed
- A diagram whose `note` contains triple backticks was truncated at the backticks, and `--sync` spliced the image link into the middle of the source. The closing fence is now anchored to its own line
- A fence indented inside a list item, or inside a blockquote, had its indentation or `>` prefix encoded into the diagram — the blockquote case rendered a blank image — and gained a second image link at the wrong nesting level, while `--check` reported everything in sync. Such blocks are now reported instead of silently corrupted
- A ```` ```plantuml ```` fence quoted inside another fenced block or a shell heredoc was treated as a real diagram, so documentation examples and acceptance-test fixtures were rewritten in place. Quoted regions are now recognized and skipped

### Upgrading
- Run `python3 plantuml-encode.py --dry-run --sync <files>` first: it shows exactly what will change, file by file, without touching anything
- Documents that exist to show their diagram sources need a `<!-- plantuml-source: visible -->` line before the first sync, or their examples will be collapsed
- `--check` is stricter than it was, so a commit that passed yesterday can now be blocked — a diagram indented inside a list is the common case. The fix is to move the diagram to the top level of the document; the check is reporting corruption that was previously silent

### Rejected
- Wrapping the source in an HTML comment, as [#414](https://github.com/artem-from-ua/claude-plugins/issues/414) proposed. HTML has no escaping mechanism inside a comment, so the first `-->` ends it — and `-->` is ordinary PlantUML arrow syntax, present in five of this plugin's own seventeen fences. Rendered on GitHub, such a diagram spills the tail of its source onto the page, producing more clutter than the visible fence it replaced. It would also hide the fence from `grep`-based discovery. See [ADR 0002](../../docs/adr/0002-plantuml-source-collapses-into-details-not-html-comments.md)

## [1.13.0] - 2026-09-08

### Changed
- **Default palette replaced.** Every color now carries three tones instead of two — fill, border, and a third for arrows and text: blue `#CADBFC`/`#6287CD`/`#5A79C4`, green `#BBEECA`/`#4DA64B`/`#479F47`, red `#F6C8C7`/`#C3403C`/`#DE3E31`, yellow `#FDF6BD`/`#99A02C`/`#B88C2E`, purple `#EEDAFC`/`#B56FE7`/`#C673DE`, gray `#E7E7E7`/`#909090`/`#737373`. Fills are lighter and less muted than the previous set, and gray is now neutral rather than cyan-cast
- Legend background lightened from `#EEEEEE` to `#F4F4F4`. The previous value was chosen to keep the old gray fill (`#D4D9D9`) from dissolving into the panel; the new gray fill sits lighter still, and it is that row's `#909090` border that keeps the swatch legible. The documented ceiling moves accordingly — `#F8F8F8` and up, where the panel stops separating from the white canvas
- Acceptance test 14.4 no longer asserts luma bands from the old palette, and drops the teal-from-cyan-cast check that only applied to the old gray

### Added
- Third palette tone as the color for arrows leaving a colored element (`up -[#5A79C4]-> tr`), so a connector between two colored blocks reads as belonging to its source rather than to neither
- Same tone as the color for text on the white canvas — arrow labels, notes, inline `<color:…>` spans — with line and label sharing one hex (`bl -[#5A79C4]-> gn : <color:#5A79C4>fetch`)
- Measured WCAG contrast for colored text on white, with the limits stated rather than implied: only gray `#737373` (4.74:1) clears the AA 4.5:1 threshold for normal-size text; blue (4.23:1) and red (4.34:1) fall just short, and green (3.32:1), yellow (3.08:1) and purple (3.04:1) clear only the 3:1 large-text bar. Colored text is documented as suitable for short labels carrying redundant meaning, never as the sole carrier of information
- Explicit note that the three tones are not a strict light-to-dark ramp — the arrow tone is darker than the border only for gray and blue, and the third column is defined by its role, not by being the darkest value in its row
- Worked example rendering all six colors with matching arrows and labels
- Acceptance test 14.5 for arrow and text tone; the former 14.5 (padding) becomes 14.6

## [1.12.0] - 2026-09-07

### Added
- Legend styling rule — three skinparams on every legend: `LegendFontColor #404040` (PlantUML's default black outweighs the borders and arrow labels the legend annotates, making a footnote the highest-contrast object on the canvas), `legendBorderColor transparent` (drops the black frame, the heaviest stroke on most diagrams), and `legendBackgroundColor #EEEEEE` (keeps the panel distinct once the frame is gone, lighter than the default `#DDD`)
- Guidance on pairing legend text with `<back:#XXXXXX>   </back>` swatches when the legend maps colors to categories, plus a worked component-diagram example
- Legend padding recipe: four-space indentation plus `<size:6> </size>` bracket lines, with the two traps documented — global `skinparam Padding` inflates every element on the diagram, and `&nbsp;` renders literally as text
- Legend line spacing: ending each entry with an oversized blank (`…storage<size:17> </size>`) stretches that line's box while leaving the text at its normal size, taking the step from 16px to 20px. The size scales the gap smoothly — a measured table of `17`/`20`/`26` against the resulting step and legend height is included. A standalone spacer line is documented as the wrong tool for this: it adds a whole line box, jumping straight to 33px with nothing in between, and its size number has no effect at all
- Acceptance tests for legend styling (section 14), covering color-coded legends, the sequence ACK legend, legends on limited-color diagram types, and padding side effects
- `--verify-url URL...` decodes a PlantUML URL back to its source locally and reports whether it is intact, printing the decoded diagram's title so a link pointing at the wrong diagram is caught too. A damaged encoding never fails loudly — the server decodes whatever prefix parses and answers with a "looks like HUFFMAN encoding, add a `~1` header" message or silently renders the wrong diagram type, both of which read as an encoder bug when the encoder is fine. Documentation fragments without `@start` pass; the `~1` prefix and non-PlantUML URLs are reported
- Rule that diagram links shown in conversation must be Markdown links (`[diagram 1](...)`) rather than bare URLs, that encoded strings are never retyped or hand-assembled, and that every link is checked with `--verify-url` before being shown
- `--md-link [TEXT]` reads source from stdin and prints a ready-to-paste, self-verified `[TEXT](url)` line, removing the hand-composition step that verification alone cannot protect: a link assembled by hand in a reply looks plausible and is dead
- `--verify-file FILE...` verifies every PlantUML URL found in each file, reading them from disk so nothing is retyped
- Acceptance tests for `--verify-url` (section 2.5), including the padding-truncation case that is legitimately harmless, and for `--md-link` / `--verify-file` (section 2.6)

### Changed
- Palette fills darkened: each is now its border color blended 18% toward the pastel, keeping both halves of a pair in the same hue family. The previous fills (luma 236–248) were too close to white and to the `#EEEEEE` legend background to read as distinct blocks
- Palette borders derived from their own fill: each border is the fill's hue taken down to roughly one third lightness, replacing the previous unrelated accent colors. A block now reads as one object instead of a pastel patch inside a foreign outline. Soft gray's border is desaturated back to `#4D5656`, since its fill's faint cyan cast would otherwise drive the derived border to teal
- Soft gray's fill darkened a further step to `#D4D9D9` — as the one neutral in the palette it shares a hue with the `#EEEEEE` legend panel and previously dissolved into it
- Rule that a diagram using more than one palette color sets fill and border together per element (`[X] #FDEDC4;line:7E6525`) rather than through `skinparam ComponentBorderColor`, which applies one border color to every element of that kind and silently breaks the fill/border pairing. The component example carried exactly that bug: four different fills, all outlined dark blue
- `references/styling.md` — legend guidance moved out of the Color Coding section into a `## Legend` section of its own, since it now covers more than color legends
- Both legend examples in `references/sequence.md` updated to the skinparam form; the Mixed Sync/Async example's participant fill moved to the darkened palette

## [1.11.0] - 2026-09-07

### Added
- Arrow thickness rule for every diagram type: `skinparam ArrowThickness 1.5` for activity, state, class, component, object, use case, deployment and ER, alongside the existing `sequenceArrowThickness 1.5` for sequence diagrams. At the default `1` arrows weigh the same as element borders and stop reading as the primary layer
- `references/styling.md` — one reference for all visual styling, holding the arrow thickness table, a worked non-sequence example, and the color palette
- Acceptance tests for arrow thickness (section 13), covering activity and class diagrams, unsupported types, and the injected SessionStart rule

### Changed
- SessionStart rule generalized from sequence-only arrow thickness to every supported diagram type
- `references/colors.md` merged into `references/styling.md`; the diagram guide now points at the latter

## [1.10.0] - 2026-09-07

### Added
- Render lint: `--check` now also verifies that each diagram source still renders without deprecation warnings or syntax errors, closing the gap where an in-sync URL implied a correct diagram
- `--lint FILE...` to run the render lint on its own
- `--no-lint` to restrict `--check` to URL sync (fully offline)
- `--offline` to lint against local deprecated-syntax patterns without contacting the PlantUML server
- Local pattern for the deprecated activity color form `#COLOR:label;`, reported with its line number and the `:label; <<#COLOR>>` replacement
- `' plantuml-lint: ignore` block comment to exempt deliberate counter-examples in documentation from the lint
- `PLANTUML_SKIP_LINT=1` escape hatch for the pre-commit hook
- Acceptance tests for the render lint (section 2.4), including offline and server-unreachable behavior

### Changed
- Pre-commit hook and CI template now block on deprecated syntax as well as stale URLs
- Success messages distinguish a verified clean render from a skipped or incomplete lint, instead of claiming diagrams "render cleanly" when the lint never ran
- Error banner renamed from "PLANTUML SYNC ERRORS" to "PLANTUML ERRORS", since findings are no longer only about sync

### Fixed
- `docs/VALIDATION.md` referenced a non-existent `templates/plantuml.yml`; the workflow template is `templates/plantuml-sync.yml`

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
- Outputs absolute paths like `/Users/.../cache/artem-from-ua/plantuml/1.5.2/scripts/plantuml-encode.py`
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
