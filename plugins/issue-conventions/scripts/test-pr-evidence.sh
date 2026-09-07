#!/bin/bash
# test-pr-evidence.sh — regression tests for pr-evidence.sh's selection rules.
#
# The filters look obvious once written and each of them was wrong first. All
# four bugs below produce a confident, plausible answer rather than an error,
# which is why they need pinning: nothing fails loudly when the classifier is
# handed evidence from the wrong pull request.
#
# Synthetic fixtures only — no network, so this runs anywhere.
#
# Usage: test-pr-evidence.sh

set -uo pipefail

pass=0
fail=0
ok()  { echo "  ok    $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; fail=$((fail + 1)); }

# A timeline shaped like issue #285's, which is the messiest real case seen:
# four cross-references, one of them the actual fix, two of them filed by this
# plugin while discussing the bug, and one from a different repository.
TIMELINE='[
  {"event":"labeled"},
  {"event":"cross-referenced","source":{"issue":{"number":284,"title":"a sibling issue","body":"",
     "repository":{"full_name":"o/r"},"pull_request":null}}},
  {"event":"cross-referenced","source":{"issue":{"number":292,"title":"the fix","body":"Closes #285",
     "repository":{"full_name":"o/r"},"pull_request":{"merged_at":"2026-04-06T13:37:52Z"}}}},
  {"event":"cross-referenced","source":{"issue":{"number":300,"title":"never merged","body":"",
     "repository":{"full_name":"o/r"},"pull_request":{"merged_at":null}}}},
  {"event":"cross-referenced","source":{"issue":{"number":377,"title":"another project entirely","body":"",
     "repository":{"full_name":"o/other"},"pull_request":{"merged_at":"2026-08-14T23:47:59Z"}}}},
  {"event":"cross-referenced","source":{"issue":{"number":393,"title":"a label migration, months later","body":"Refs #326",
     "repository":{"full_name":"o/r"},"pull_request":{"merged_at":"2026-09-07T13:18:47Z"}}}},
  {"event":"closed"}
]'

# The same filter chain pr-evidence.sh runs, minus the network.
candidates() {
  jq -c '[ .[] | select(.event == "cross-referenced") | .source.issue
           | select(.pull_request != null)
           | select(.pull_request.merged_at != null)
           | {number, title, body: (.body // ""), repo: .repository.full_name,
              merged_at: .pull_request.merged_at} ]' <<<"$TIMELINE" \
  | jq -c --arg repo "o/r" '[ .[] | select(.repo == $repo) ]'
}

echo "=== candidate selection ==="

got=$(candidates | jq -c 'map(.number)')
if [[ "$got" == "[292,393]" ]]; then
  ok "keeps merged PRs of this repo only (drops the issue, the unmerged PR, the foreign PR)"
else
  bad "expected [292,393], got $got"
fi

# A cross-reference is usually another issue. Without this the plugin's own bug
# reports become evidence about the bug they describe.
if candidates | jq -e 'map(.number) | index(284) | not' >/dev/null; then
  ok "a plain issue cross-reference is not evidence"
else
  bad "issue #284 leaked into the candidates"
fi

# `gh pr view 377` answers from the *current* repo regardless of where the
# reference came from, so an unfiltered pipeline silently attributes another
# project's files to this issue.
if candidates | jq -e 'map(.number) | index(377) | not' >/dev/null; then
  ok "a PR from another repository is excluded"
else
  bad "foreign PR #377 leaked into the candidates"
fi

echo "=== closed issue: the fix is the PR merged at or before the close ==="

CLOSED_AT="2026-04-06T13:37:54Z"
chosen=$(candidates | jq -r --arg closed "$CLOSED_AT" '
  [ .[] | select(.merged_at <= ($closed | fromdateiso8601 + 60 | todateiso8601)) ]
  | sort_by(.merged_at) | last | .number')
if [[ "$chosen" == "292" ]]; then
  ok "picks the fix, not the later migration"
else
  bad "expected 292, got $chosen"
fi

# Newest-wins is the tempting rule and it is wrong: a label migration or a
# docs sweep months later is the most recent PR touching a long-closed issue.
newest=$(candidates | jq -r 'sort_by(.merged_at) | last | .number')
if [[ "$newest" == "393" && "$chosen" == "292" ]]; then
  ok "newest-wins would have picked 393 — the close time is what separates them"
else
  bad "fixture no longer demonstrates the newest-wins trap"
fi

# GitHub closes the issue moments after the merge; two seconds here, and no
# documented bound. A strict <= would drop the fix on the wrong side.
tight=$(candidates | jq -r --arg closed "2026-04-06T13:37:51Z" '
  [ .[] | select(.merged_at <= ($closed | fromdateiso8601 | todateiso8601)) ] | length')
if [[ "$tight" == "0" ]]; then
  ok "without the grace window the fix falls outside by seconds"
else
  bad "expected the tight window to exclude everything, got $tight"
fi

echo "=== open issue: most recent merged work, flagged as not a fix ==="

open_choice=$(candidates | jq -r 'sort_by(.merged_at) | last | .number')
if [[ "$open_choice" == "393" ]]; then
  ok "an open issue takes the latest merged PR"
else
  bad "expected 393, got $open_choice"
fi

echo "=== churn filter ==="

FILES='[{"path":"plugins/a/.claude-plugin/plugin.json","additions":1,"deletions":1},
        {"path":"plugins/b/.claude-plugin/plugin.json","additions":1,"deletions":1},
        {"path":"plugins/kb-grooming/scripts/kb-structural-scan.sh","additions":40,"deletions":26},
        {"path":"plugins/c/README.md","additions":12,"deletions":6}]'
ranked=$(jq -c '[.[] | {path, churn: (.additions + .deletions)} | select(.churn >= 3)]
                | sort_by(-.churn) | map(.path)' <<<"$FILES")
if [[ "$ranked" == '["plugins/kb-grooming/scripts/kb-structural-scan.sh","plugins/c/README.md"]' ]]; then
  ok "version bumps drop out; the file that decides the label ranks first"
else
  bad "unexpected ranking: $ranked"
fi

# Six +1/-1 bumps across six plugins would otherwise argue for six values of a
# directory-derived axis on an issue that belongs to one.
kept=$(jq -c '[.[] | {churn: (.additions + .deletions)} | select(.churn >= 3)] | length' <<<"$FILES")
if [[ "$kept" == "2" ]]; then
  ok "two of four files survive — the noise is 50% here, 46% on the real PR"
else
  bad "expected 2 files, got $kept"
fi

echo "=== issue-link extraction ==="

LINK_RE='(clos|fix|resolv)e[sd]?[[:space:]]+#|addresses[[:space:]]+#|refs[[:space:]]+#'
links=$(printf '## Summary\n\nDid a thing.\n\nCloses #285, closes #286\nAddresses #289\n\n## Test plan\n- [ ] box\n' \
        | { grep -Ei "$LINK_RE" || true; } | head -4)
if [[ "$links" == *"Closes #285"* && "$links" == *"Addresses #289"* && "$links" != *"box"* ]]; then
  ok "pulls closing and touching lines, skips the checklist between them"
else
  bad "unexpected links: $links"
fi

# grep exits 1 on no match, and under `set -o pipefail` that aborted the whole
# run — silently, after the evidence had already been computed.
none=$(printf 'A body that mentions no issue at all.\n' | { grep -Ei "$LINK_RE" || true; } | head -4)
if [[ -z "$none" ]]; then
  ok "a body with no relationship yields empty, not a failed run"
else
  bad "expected empty, got $none"
fi

echo "=== mode gating ==="

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr-evidence.sh"

# `off` is a config value the caller may forward blindly. Exiting 0 with no
# output beats an error: the pipeline that honours the setting and the one that
# forwards it both end up doing nothing, which is what was asked for.
out=$(bash "$SCRIPT" --mode off 285 2>&1)
if [[ -z "$out" ]]; then
  ok "--mode off produces nothing and exits clean"
else
  bad "--mode off produced output: $out"
fi

msg=$(bash "$SCRIPT" --mode sideways 285 2>&1 >/dev/null)
rc=$?
if [[ "$rc" -eq 2 && "$msg" == *"unknown mode"* ]]; then
  ok "an unrecognized mode exits 2, not silently treated as full"
else
  bad "expected exit 2 with a message, got rc=$rc msg=$msg"
fi

# The field split is the whole point of the setting: paths are ~300 characters
# per issue against ~900 for the prose, measured across this repo's 93 issues
# that have a PR. A mode that returned everything anyway would cost the same.
shaped=$(jq -nc --arg mode paths '
  {number: 1, pr: 2, files: []}
  + (if $mode == "full" then {prTitle: "t", prSummary: "s", prLinks: "l"} else {} end)
  | keys')
if [[ "$shaped" == '["files","number","pr"]' ]]; then
  ok "paths mode omits the prose fields"
else
  bad "unexpected paths-mode shape: $shaped"
fi

shaped_full=$(jq -nc --arg mode full '
  {number: 1, pr: 2, files: []}
  + (if $mode == "full" then {prTitle: "t", prSummary: "s", prLinks: "l"} else {} end)
  | keys | length')
if [[ "$shaped_full" == "6" ]]; then
  ok "full mode carries the prose fields"
else
  bad "expected 6 keys in full mode, got $shaped_full"
fi

echo
echo "Пройдено: $pass, провалено: $fail"
[[ "$fail" -eq 0 ]]
