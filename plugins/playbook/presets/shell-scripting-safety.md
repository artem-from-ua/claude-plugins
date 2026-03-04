---
name: shell-scripting-safety
description: "Shell script pitfalls: set -euo pipefail, find -path globs, grep/jq edge cases"
tags: [bash, shell, scripting, safety]
---

<!-- RULES -->
## Shell Scripting Safety — Base Rules

MANDATORY: Follow these rules when writing or editing `.sh` scripts.

- ALWAYS use `set -euo pipefail` at the top of scripts
- NEVER pass `**` globs to `find -path` — `fnmatch(3)` treats `**` as two `*`; convert `**/foo` → `*/foo` or `-name`
- ALWAYS anchor `find -path` to project dir — `"${DIR}/*/${pat}/*"` not `"*/${pat}/*"` (unanchored matches parent dirs)
- NEVER pipe `grep` into `while` under pipefail — grep returns 1 on no matches; use `|| true`
- NEVER use `jq` `// true` to default booleans — `false` passes through; use `if/then/else`
- Quote `#` in `case` patterns — `#*` is a comment; use `'#'*`
- Use `${ARR[@]+"${ARR[@]}"}` for empty arrays under `set -u`
- **ALWAYS invoke `playbook-browse shell-scripting-safety` BEFORE writing shell scripts** to load full reference.
<!-- /RULES -->

<!-- REFERENCE -->
## find -path Does Not Support `**` Recursive Globs

`find -path` uses POSIX `fnmatch(3)` pattern matching. `**` is NOT a recursive glob — it equals two `*` wildcards. This is a `.gitignore`/bash `globstar` convention, not POSIX.

```bash
# BROKEN — ** is not recursive in find; also unanchored, matches parent dirs
find "$DIR" -type f -not -path "*/${pattern}/*"

# FIX — strip **/ prefix, anchor to project dir
pattern="${pattern##\*\*/}"  # **/raw → raw
find "$DIR" -type f -not -path "${DIR}/*/${pattern}/*"

# ALT FIX — use -name for simple patterns
find "$DIR" -type f -not -name "${pattern}"
```

**Key gotcha:** unanchored `-not -path "*/${pattern}/*"` matches the pattern anywhere in the absolute path, including parent directories. If the project lives under `~/code/my-project` and the exclude pattern is `code`, every file gets excluded.

## grep | while Fails with pipefail

`grep` returns exit 1 on no matches → `pipefail` propagates → `set -e` kills the script.

```bash
# BROKEN
grep -noE 'pattern' "$file" | while IFS= read -r match; do
  ...
done

# FIX — redirect to tmpfile
grep -noE 'pattern' "$file" > "$tmpfile" || true
while IFS= read -r match; do ...  done < "$tmpfile"

# ALT FIX — process substitution
while IFS= read -r match; do ...  done < <(grep -noE 'pattern' "$file" || true)
```

Similarly, `grep -v` returns exit 1 when it filters out ALL lines:

```bash
# BROKEN
others=$(grep "^${hash}|" "$file" | grep -v "^${target}$" | head -3)

# FIX
others=$(grep "^${hash}|" "$file" | { grep -v "^${target}$" || true; } | head -3)
```

## jq `//` Does Not Catch `false`

`// true` is the "alternative" operator — triggers only for `null` or missing keys. `false` is a valid value and passes through.

```bash
# BROKEN — returns "true" even when value is false
CHECK=$(jq -r '.checks.foo // true' "$config")

# FIX — explicit conditional
CHECK=$(jq -r 'if .checks.foo == false then "false" else "true" end' "$config")
```

## `#*` in case Patterns Is a Comment

```bash
# BROKEN — #* starts a comment, syntax error
case "$var" in
  http://*|#*) continue ;;
esac

# FIX — quote the hash
case "$var" in
  http://*|'#'*) continue ;;
esac
```

## Empty Arrays with set -u

`${ARR[@]}` on an empty array is "unbound variable" under `set -u`.

```bash
# BROKEN
ITEMS=()
printf '%s\n' "${ITEMS[@]}"   # error: unbound variable

# FIX
printf '%s\n' "${ITEMS[@]+"${ITEMS[@]}"}"
```
<!-- /REFERENCE -->
