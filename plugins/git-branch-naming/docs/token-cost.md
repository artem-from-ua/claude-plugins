# Token Cost Analysis

## Fixed cost per session (~220 tokens)

Every Claude Code session pays this cost regardless of whether you use git at all:

| Component | Tokens | Source |
|-----------|--------|--------|
| SessionStart rules (`inject-rules.sh`) | ~130 | Injected into system prompt |
| Skill description (`branch-naming-guide`) | ~60 | Skill list loaded at startup |
| Command description (`git-branch-naming-setup`) | ~30 | Command list loaded at startup |
| **Total fixed** | **~220** | — |

At Sonnet 4.6 pricing ($3.00 / 1M input tokens), 220 tokens cost **$0.00066 per session** — less than a tenth of a cent.

## Variable cost (only when triggered)

| Event | Tokens | Frequency |
|-------|--------|-----------|
| `branch-naming-guide` skill body | ~400 | When Claude consults naming guide |
| `git-branch-naming-setup` command body | ~500 | When `/git-branch-naming:setup` is run |
| Warning message in conversation | ~50–100 | When validation fires |

## Zero-cost operations

The PreToolUse hook (`validate-branch.sh`, `check-content-mismatch.sh`) runs as an **external process** — it never adds tokens to the context window. This means:
- Every `git checkout`, `git commit`, `git push` validation costs **0 tokens**
- Validation runs even on the largest codebase with no context overhead
- Mismatch analysis (file classification, diff inspection) is entirely outside Claude

## Comparison with naive approaches

| Approach | Cost per session | Notes |
|----------|-----------------|-------|
| This plugin | ~220 tokens | Fixed; validation is external |
| Inline rules in CLAUDE.md | ~220 tokens | Same, but no enforcement mechanism |
| Asking Claude to validate each time | ~300–500 tokens | Per-validation cost, no automation |
| No plugin (ad-hoc reminders) | 0 tokens | But conventions drift and Claude forgets |

## Design principle

The plugin is designed so that **enforcement has zero context cost**. All three validation scripts (`validate-branch.sh`, `check-content-mismatch.sh`, `inject-rules.sh`) run outside the LLM — they read stdin JSON and write `permissionDecision` JSON without consuming any context window tokens. The ~220 token fixed cost covers only the rules Claude needs to *understand* conventions, not to *enforce* them.
