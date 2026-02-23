#!/bin/bash
# SessionStart hook: inject retroscope base rules into Claude's context.
# Outputs ~60 tokens reminding Claude about /retro command availability.

cat <<RULES
## Retroscope — Session Retrospective Reports

The \`/retro\` command is available to generate retrospective summaries:
- \`/retro session\` — summarize the current session (uses current context, display only)
- \`/retro today\` — aggregate report for all today's sessions (saved to storage repo)
- \`/retro yesterday\` — aggregate report for yesterday's sessions (saved to storage repo)

Run \`/retroscope:setup\` to configure storage directory and options on first use.
RULES
