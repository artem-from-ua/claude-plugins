---
name: plantuml-validate
description: >
  Validate PlantUML diagrams in markdown files: check that image URLs match
  their source blocks, and lint the sources for deprecated syntax and render
  errors. Reports missing or stale URLs and offers auto-fix.
compatibility: Requires Python 3.x
---

# PlantUML Validate

Validate that all PlantUML diagrams in markdown files are in sync with their source blocks and still render without complaints.

Two independent problems are detected:

- **Stale or missing URL** — the image URL no longer encodes the source block. Auto-fixable with `--sync`.
- **Deprecated syntax or render error** — the source renders with a warning box or fails to parse. Not auto-fixable: the source block has to be corrected by hand, then re-synced.

## Instructions

1. Find all `.md` files in the project that contain PlantUML code blocks:
   ```bash
   grep -rl '```plantuml' . --include='*.md'
   ```

2. Run the validation check on all found files:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/plantuml-encode.py" --check <files>
   ```
   `CLAUDE_PLUGIN_ROOT` is set automatically by Claude Code when running plugin commands.

   `--check` does both jobs: URL sync (offline) and render lint (asks the PlantUML server about each diagram). If the server is unreachable, the command prints a warning and reports only what it could verify — it does not fail. To check URL sync alone, put `--no-lint` before `--check`.

3. Report results to the user:
   - If everything passes: confirm success with the file count, and say whether the render lint actually ran (the command's own output states this).
   - If issues were found: list each one with file, line number, and type — stale URL, missing URL, or deprecated syntax / render error.
   - Offer to auto-fix the URL problems. Do **not** offer to auto-fix deprecated syntax — show the server's message and the suggested replacement, and let the user decide what the diagram should say.

4. If the user confirms auto-fix for URL problems, run:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/plantuml-encode.py" --sync <affected-files>
   ```

5. After a deprecated-syntax fix is applied to a source block, re-run `--check` on that file: the edited source needs a fresh URL, and the render lint confirms the warning is gone.

6. If a block shows bad syntax deliberately — a counter-example in documentation — it can be exempted from the lint with a `' plantuml-lint: ignore` comment inside the block. Suggest this only when the user confirms the syntax is intentional; never add it to silence a genuine problem.
