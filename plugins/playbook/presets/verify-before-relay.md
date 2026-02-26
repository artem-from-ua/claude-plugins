---
name: verify-before-relay
description: "Verify subagent outputs (URLs, links) before relaying to user"
tags: [subagents, urls, verification]
---

<!-- RULES -->
## Verify Before Relay — Base Rules

MANDATORY: Follow these rules when working with subagent outputs.

- Subagents (especially `claude-code-guide`) can hallucinate URLs — GitHub issue links, documentation pages, API references, etc.
- NEVER relay a URL from a subagent to the user without verifying it first (`gh issue view <N>`, `WebFetch`, or `curl`)
- If a subagent returns multiple URLs, verify ALL of them before citing
- If verification fails (404, wrong content, redirect to unrelated page) → do NOT cite the URL; state it could not be confirmed
<!-- /RULES -->

<!-- REFERENCE -->
## Why URL Verification Matters

Subagent hallucinations are subtle: the URL format looks plausible (correct domain, realistic path), but the resource doesn't exist or points to unrelated content. This is especially common for:
- GitHub issue/PR numbers that look real but aren't
- Documentation pages for specific versions or features
- Internal links between issues or PRs in a repo

## How to Verify

**GitHub issues and PRs:**
```bash
gh issue view <N> --repo OWNER/REPO
gh pr view <N> --repo OWNER/REPO
```

**Documentation URLs:**
Use WebFetch with a prompt to confirm the page exists and contains the expected content.

**Multiple URLs from one subagent:**
Verify each independently — a hallucinated URL doesn't invalidate others, but each needs its own check.

## When Verification Fails

If a URL can't be confirmed:
- Do NOT cite it (even as "might be useful")
- Say: "The subagent suggested [description], but I couldn't verify the link — skipping."
- Offer to search for the correct reference manually
<!-- /REFERENCE -->
