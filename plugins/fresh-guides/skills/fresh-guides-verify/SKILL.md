---
name: fresh-guides-verify
description: >
  Invoked automatically when discussing a technology on the fresh-guides watchlist.
  Provides verification procedure: detect version, fetch official docs for that version,
  compare with training data, cite sources. Do NOT give version-specific advice for
  watched technologies without consulting this skill first.
  Keywords: fresh-guides verify, check docs, fast-changing technology, outdated knowledge, version check.
---

# Fresh Guides — Verification Procedure

A technology on the user's fresh-guides watchlist was detected in the conversation. Follow this procedure BEFORE giving version-specific advice.

## Steps

### 1. Identify the matched technology

Find the matching entry in the watchlist (injected by SessionStart). Note:
- The technology `name` from the watchlist
- The configured `docs` URLs

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
2. When the official docs have versioned URLs (e.g., `/v1.6.x/`, `/latest/`), target the URL for the user's specific version — not "latest"
3. If the page is too large or doesn't contain the answer, use `WebSearch` with a targeted query:
   `"<technology> <version> <specific feature/API> official documentation"`
4. For release notes / changelogs, search for the specific version or recent changes

**Fallback chain:** configured docs URL → WebSearch official docs → WebSearch general → state "could not verify"

### 5. Compare with user's version and respond

After verification, explicitly compare the feature/behavior with the user's version:

- **Feature available in user's version:** State it clearly: "Supported in your version (vX.Y.Z, added in vA.B)."
- **Feature NOT available in user's version:** Warn explicitly: "Requires vA.B+. Your vX.Y.Z does not support it." Suggest a workaround if one exists for their version.
- **Behavior changed between versions:** Note what differs: "In your vX.Y.Z, the default is A. In vA.B+ it changed to B."

Based on what you found from docs:

**Docs confirm your knowledge:**
> Include the answer with inline citation.

**Docs contradict your knowledge:**
> **Note:** My training data may be outdated here. According to the official docs: [corrected information]. [Source: url]

**Could not verify:**
> **Note:** I could not verify this against official docs. My answer is based on training data. Please double-check at: [configured doc URLs]

### 6. Citation format

Always include inline citations when providing verified information:

```
[Source: domain.com/path/to/versioned/page]
```

Place the citation after the specific claim it supports, not at the end of the entire response. Use version-specific URLs when the documentation site supports them.

## Important

- NEVER silently use training data for version-specific advice on watched technologies
- NEVER skip verification because "I'm fairly confident" — the whole point is that confidence can be misplaced for fast-changing tech
- If WebFetch/WebSearch fails, say so explicitly — do not fall back to training data silently
- Keep verification efficient — fetch only what's needed, don't read entire documentation sites
