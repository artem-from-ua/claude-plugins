---
name: debugging-discipline
description: "Safe debugging workflow: gather evidence, diagnose, confirm, fix — never destroy state"
tags: [debugging, troubleshooting, safety]
---

<!-- RULES -->
## Debugging Discipline — Base Rules

MANDATORY: Follow this workflow when troubleshooting issues.

**Workflow:** gather → diagnose → confirm → fix

1. **Gather**: Read live state (logs, config, running processes). NEVER modify during this phase.
2. **Diagnose**: Identify root cause from evidence. State your hypothesis explicitly.
3. **Confirm**: Verify hypothesis with a non-destructive test before changing anything.
4. **Fix**: Make the minimal change that addresses the root cause.

**Never destroy evidence during debugging:**
- NEVER overwrite, delete, or reset live state to "try something"
- NEVER restart services/processes unless that IS the fix (not just a diagnostic step)
- If the issue is intermittent, capture state first (logs, screenshots, output) before touching anything

**For plugin/tool debugging specifically:**
- NEVER modify files in live caches or tool directories (e.g., `~/.claude/`, plugin caches)
- All fixes go to the working directory — user applies changes by restarting or resyncing
- Rationale: modifying live state destroys the evidence needed to diagnose the root cause
<!-- /RULES -->

<!-- REFERENCE -->
## The Gather Phase

Before touching anything, capture the full current state:

```bash
# Read logs
tail -50 /tmp/some-tool.log

# Check what's actually running/loaded
cat ~/.some-tool/config.json   # read only!

# Capture process state
ps aux | grep tool-name
```

Rule: if you're not sure whether an action is "read" or "modify", it's modify. Don't do it during gather.

## The Diagnose Phase

State your hypothesis explicitly before acting:
- "I think the issue is X because Y"
- "The evidence suggests Z is happening"

This forces clear reasoning and makes it easy to course-correct if the hypothesis is wrong.

## The Confirm Phase

Test the hypothesis non-destructively:
- Look for additional evidence that supports or refutes it
- Check if the observed symptoms are consistent with the hypothesis
- If you can't confirm without modifying state, document the hypothesis and ask the user to confirm before proceeding

## Live State Is Read-Only During Debugging

For plugin debugging (e.g., Claude Code plugins):
- `~/.claude/` and plugin caches → read only
- Working directory (`plugins/<name>/`) → where fixes go
- User applies changes by restarting Claude Code or running sync scripts manually

This separation ensures:
1. Evidence is preserved if the first fix attempt is wrong
2. The user retains control over when state changes
3. Debugging can be repeated with clean state
<!-- /REFERENCE -->
