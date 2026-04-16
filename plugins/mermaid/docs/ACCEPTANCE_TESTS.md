# Mermaid Plugin — Acceptance Tests

Each test describes setup, expected behavior, and how to verify.

## 1. Manifest validity

**Setup:** fresh checkout.
**Run:**
```bash
cat plugins/mermaid/.claude-plugin/plugin.json | jq .
```
**Expect:** valid JSON with `name`, `version`, `commands`, `skills` fields.

## 2. Marketplace registration

**Run:**
```bash
jq '.plugins[] | select(.name == "mermaid")' .claude-plugin/marketplace.json
```
**Expect:** non-empty object.

## 3. SessionStart rules injection

**Run:**
```bash
bash plugins/mermaid/scripts/inject-rules.sh
```
**Expect:** stdout contains "Mermaid Diagrams in Markdown — Base Rules" and "ALWAYS invoke the `mermaid-diagram-guide` skill".

## 4. Validator — valid block

**Setup:** `/tmp/ok.md` containing:
```
\`\`\`mermaid
flowchart TD
    A --> B
\`\`\`
```
**Run:**
```bash
python3 plugins/mermaid/scripts/validate-mermaid.py /tmp/ok.md
```
**Expect:** exit 0, no stderr.

## 5. Validator — invalid block

**Setup:** `/tmp/bad.md` containing a mermaid block with `A --->>>> B`.
**Run:** same command, path `/tmp/bad.md`.
**Expect:** exit 1, stderr contains `mermaid block #1 invalid:` with a Kroki error message.

## 6. Validator — no blocks

**Setup:** `/tmp/plain.md` with plain text, no mermaid fences.
**Expect:** exit 0, no stderr.

## 7. Validator — non-markdown file

**Run:**
```bash
echo '{"tool_input":{"file_path":"/tmp/foo.py"}}' | bash plugins/mermaid/scripts/validate-on-edit.sh
```
**Expect:** no Kroki call, silent exit 0.

## 8. Validator — network offline (fail-soft)

**Setup:** `MERMAID_KROKI_URL=http://127.0.0.1:1` and a file containing a mermaid block.
**Expect:** exit 0, stderr warns "Kroki unreachable".

## 9. Pre-commit install/uninstall

**Setup:** a scratch git repo.
**Run:** `bash plugins/mermaid/scripts/setup-project.sh`
**Expect:** `.githooks/pre-commit` exists with `# >>> tribe-coding/mermaid >>>` markers; `core.hooksPath = .githooks`.
**Run:** `bash plugins/mermaid/scripts/uninstall-hook.sh`
**Expect:** markers removed, other hook content preserved (or file deleted if it was the only content).

## 10. Pre-commit blocks invalid commits

**Setup:** scratch repo with plugin's pre-commit installed; stage a `.md` with an invalid mermaid block.
**Run:** `git commit -m test`
**Expect:** commit rejected with "Commit blocked: Mermaid diagrams have syntax errors".

## 11. Live plugin — rules in session

**Setup:** install plugin locally via `/plugin marketplace add` + `/plugin install mermaid@tribe-coding`.
**Run:** in a new session, `/context:ctx-show`.
**Expect:** base rules visible; `mermaid-diagram-guide` skill listed.

## 12. Live plugin — proactive diagram

**Setup:** installed plugin, new session.
**Prompt:** "Document the login flow in `docs/auth.md`".
**Expect:** Claude invokes `mermaid-diagram-guide`, writes a `mermaid` block (no image URL), and PostToolUse validation reports no errors.
