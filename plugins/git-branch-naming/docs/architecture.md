# Architecture

```
scripts/
├── inject-rules.sh           # SessionStart: outputs ~130 tokens of rules
├── validate-branch.sh        # PreToolUse: intercepts git commands, validates names
└── check-content-mismatch.sh # Helper: staged/branch file analysis

hooks/hooks.json              # PreToolUse(Bash) + SessionStart wiring
commands/git-branch-naming-setup/SKILL.md  # /git-branch-naming:setup wizard
skills/branch-naming-guide/SKILL.md        # On-demand naming reference
templates/
├── git-branch-naming.json    # Default config template
└── pre-push                  # Standalone git pre-push hook
```
