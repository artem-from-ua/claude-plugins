---
name: semver-guide
description: >
  Invoked automatically when deciding version bumps to determine correct MAJOR/MINOR/PATCH increment.
  Covers SemVer 2.0.0: version format, decision tree, conflict resolution, common mistakes.
  Do NOT bump versions without consulting this guide for non-obvious cases.
  Keywords: semver, version bump, major minor patch, breaking change, version conflict, semantic versioning.
---

# SemVer 2.0.0 Quick Reference

## Version Format

`MAJOR.MINOR.PATCH` — e.g., `2.1.0`

When to reset: incrementing MINOR resets PATCH to 0; incrementing MAJOR resets both.

## When to Increment

### PATCH (x.y.**Z**)
Backwards-compatible bug fixes. No new API surface.

- Fixed crash on empty input
- Corrected typo in error message
- Performance optimization (same behavior)
- Fixed race condition

### MINOR (x.**Y**.0)
New features, backwards-compatible. Reset PATCH to 0.

- Added new API endpoint / function / command
- Added optional parameter with default value
- New configuration option (with sensible default)
- Deprecated old API (still works)

### MAJOR (**X**.0.0)
Breaking changes. Reset MINOR and PATCH to 0.

- Removed public API / function / command
- Changed function signature (added required params)
- Renamed public interface
- Changed default behavior incompatibly
- Dropped platform or dependency support

## Decision Tree

```
Changed files → excluded (docs, LICENSE, .gitignore)? → YES → No bump needed
                                                       → NO ↓
Did you remove / rename / break existing API?  → YES → MAJOR
Did you add new public API or feature?         → YES → MINOR (at minimum)
Did you fix a bug?                             → YES → PATCH
Refactoring, internal restructure only?        → PATCH (or skip if truly zero user impact)
```

## Initial Development (0.x.y)

`0.x.y` signals the API is not yet stable — anything may change.
- Start at `0.1.0`
- Use `0.x.y` freely during development
- Declare `1.0.0` for the first stable public release

## Pre-release Versions

Format: `1.0.0-alpha`, `1.0.0-alpha.1`, `1.0.0-beta.2`, `1.0.0-rc.1`

Precedence: `alpha < alpha.1 < beta < rc.1 < release`

Use for unstable or pre-release testing builds.

## Conflict Resolution (Rebase / Merge)

When you rebase and find a version conflict:

1. Check base branch version:
   ```bash
   git show <baseBranch>:<versionFile> | jq -r '.version'
   ```
2. Compare with your bumped version:
   - Base is **higher** → increment from base (not your original)
   - Base is **same** → increment again (concurrent PR)
   - Base is **lower** → keep yours (already correct)

Example: You bumped `1.1.0 → 1.1.1`. Base is now `1.2.0` → yours becomes `1.2.1`.

## Common Mistakes

| Mistake | Correct approach |
|---------|-----------------|
| MAJOR for every change | MAJOR only for breaking changes |
| No bump for bug fixes | PATCH for every bug fix |
| Bumping for docs-only changes | Usually skip (unless docs are your product) |
| Skipping versions (1.0.0 → 1.0.5) | Increment by 1 per release |
| Adding MAJOR bump for new optional feature | Optional feature with default = MINOR |
