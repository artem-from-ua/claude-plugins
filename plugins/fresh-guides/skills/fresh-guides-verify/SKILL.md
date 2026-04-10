---
name: fresh-guides-verify
description: >
  Invoked automatically when discussing a technology on the fresh-guides watchlist.
  Provides verification procedure: fetch official docs, compare with training data,
  cite sources. Do NOT give version-specific advice for watched technologies
  without consulting this skill first.
  Keywords: fresh-guides verify, check docs, fast-changing technology, outdated knowledge, version check.
---

# Fresh Guides — Verification Procedure

A technology on the user's fresh-guides watchlist was detected in the conversation. Follow this procedure BEFORE giving version-specific advice.

## Steps

### 1. Identify the matched technology

Find the matching entry in the watchlist (injected by SessionStart). Note:
- The technology `name` from the watchlist
- The configured `docs` URLs
- The `version` constraint (usually "latest")

### 2. Determine the current version

Before giving any advice, establish which version of the technology is in use:

1. **Check the project** — look for version pins in lockfiles, config files, or dependency manifests (e.g., `terraform { required_version }`, `package.json`, `go.mod`, `.tool-versions`, Dockerfile `FROM` tags, provider version constraints).
2. **Check runtime** — if the tool is available locally, run its version command (e.g., `terraform version`, `kubectl version --client`, `aws --version`).
3. **If neither works** — ask the user: "Which version of **<technology>** are you using?" Do NOT assume "latest" — the user may be on an older version with different behavior.

All subsequent verification MUST target the specific version identified in this step.

### 3. Determine what needs verification

Identify the specific claim, API, behavior, config syntax, or default that could have changed since training cutoff. Not everything needs verification:

**Verify:** API signatures, default values, config syntax, deprecations, new features, pricing, limits, CLI flags, provider arguments, service quotas.

**Skip verification:** General concepts, design patterns, architectural principles, well-established fundamentals that don't change across versions.

### 4. Fetch official documentation

Use `WebFetch` on the configured doc URLs to find information about the specific topic:

1. Try the most specific doc URL first (e.g., API reference > general docs)
2. If the page is too large or doesn't contain the answer, use `WebSearch` with a targeted query:
   `"<technology> <specific feature/API> official documentation <current year>"`
3. For release notes / changelogs, search for the specific version or recent changes

**Fallback chain:** configured docs URL → WebSearch official docs → WebSearch general → state "could not verify"

### 5. Compare and respond

Based on what you found:

**Docs confirm your knowledge:**
> Verified against official docs ([source](url), fetched YYYY-MM-DD).

**Docs contradict your knowledge:**
> **Note:** My training data may be outdated here. According to the official docs as of YYYY-MM-DD: [corrected information]. Source: [url]

**Could not verify:**
> **Note:** I could not verify this against official docs. My answer is based on training data (cutoff: [date]). Please double-check at: [configured doc URLs]

### 6. Citation format

Always include inline citations when providing verified information:

```
[Source: domain.com/path, YYYY-MM-DD]
```

Place the citation after the specific claim it supports, not at the end of the entire response.

## Important

- NEVER silently use training data for version-specific advice on watched technologies
- NEVER skip verification because "I'm fairly confident" — the whole point is that confidence can be misplaced for fast-changing tech
- If WebFetch/WebSearch fails, say so explicitly — do not fall back to training data silently
- Keep verification efficient — fetch only what's needed, don't read entire documentation sites
