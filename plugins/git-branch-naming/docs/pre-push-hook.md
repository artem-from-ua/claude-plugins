# Pre-push Git Hook

For enforcement outside of Claude Code (CI, terminal git), install the pre-push hook:

```bash
mkdir -p .githooks
cp /path/to/plugin/templates/pre-push .githooks/pre-push
chmod +x .githooks/pre-push
git config core.hooksPath .githooks
```

Or let the setup wizard install it: `/git-branch-naming:setup` → answer "Yes" to hook installation.

The hook reads `.claude-plugin/git-branch-naming.json` (falls back to `.claude/git-branch-naming.json` for backwards compatibility).
