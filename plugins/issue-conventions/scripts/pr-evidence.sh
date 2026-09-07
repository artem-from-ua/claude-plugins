#!/bin/bash
# pr-evidence.sh — the paths a merged PR touched, as classification evidence.
#
# A title describes the symptom, a diff describes the work. "Fix 2 broken
# documentation links" reads as type:docs until you see the PR changed
# kb-structural-scan.sh — the scanner was emitting false positives, so the issue
# was a bug. On the third polygon five labels were wrong this way, and four were
# invisible from the title and body.
#
# Usage:
#   pr-evidence.sh 285 286 293        # explicit numbers
#   pr-evidence.sh --from-dump FILE   # every issue in a fetch-issues dump
#
# Emits one JSON object per line:
#   {"number":285,"issueState":"closed","pr":292,"prTitle":"…","prSummary":"…",
#    "prLinks":"Closes #285, closes #286…","prMergedAt":"…","isFix":true,
#    "files":[{"path":"plugins/kb-grooming/scripts/kb-structural-scan.sh","churn":66}]}
#
# `isFix` is the honest part. True means the PR merged at or before the issue
# closed: it is the accepted answer, and its paths carry the same weight as the
# body. False means work landed against an issue that is still open — real
# evidence, but of what has been done so far, not of what the issue is.
#
# An issue with no qualifying PR is emitted with "pr": null, so a caller can
# tell "asked, nothing there" from "never asked".

set -euo pipefail

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 1; }
done

# Files whose diff is this small are version bumps and lockfile churn. The
# threshold does the work a hardcoded path list would do badly: on PR #292 it
# drops six plugin.json bumps at +1/-1 each and keeps kb-structural-scan.sh at
# 66 lines, which is the file that decides the label. Tune per repo if needed.
MIN_CHURN=${PR_EVIDENCE_MIN_CHURN:-3}

# How much of the PR body to carry, from each end.
#
# The head is where an author says what the change does: PR #292 opens with
# "Improve kb-grooming structural scan: skip links in code blocks…", stating
# the work outright where the file paths only imply it.
#
# Everything below the head is test plans and checklists, which say nothing
# about the kind of work — with one exception worth extracting on its own: the
# lines that state the issue relationship. Those distinguish what nothing else
# does. PR #292 says "Closes #285, closes #286 … Addresses #289" — three issues
# fixed, three merely touched — and PR #393 says "Refs #326", which is not a fix
# at all.
#
# They are pulled by pattern rather than by a tail window because their position
# is not stable: line 11 of #292, line 74 of #393. A fixed tail catches one and
# misses the other.
BODY_HEAD=${PR_EVIDENCE_BODY_HEAD:-800}
LINK_RE='(clos|fix|resolv)e[sd]?[[:space:]]+#|addresses[[:space:]]+#|refs[[:space:]]+#'

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

numbers=()
if [[ "${1:-}" == "--from-dump" ]]; then
  DUMP="${2:-}"
  [[ -f "$DUMP" ]] || { echo "usage: pr-evidence.sh --from-dump FILE" >&2; exit 2; }
  while IFS= read -r n; do numbers+=("$n"); done < <(jq -r '.[].number' "$DUMP")
else
  numbers=("$@")
fi

[[ ${#numbers[@]} -gt 0 ]] || { echo "usage: pr-evidence.sh <issue-number>... | --from-dump FILE" >&2; exit 2; }

for n in "${numbers[@]}"; do
  meta=$(gh api "repos/$REPO/issues/$n" --jq '{state, closed_at}' 2>/dev/null || true)
  [[ -n "$meta" ]] || continue
  issue_state=$(jq -r '.state' <<<"$meta")
  closed_at=$(jq -r '.closed_at // empty' <<<"$meta")

  # Every merged PR that references this issue. Three filters, each earning its
  # place on live data from issue #285 and #100:
  #
  #   pull_request != null  — most cross-references are other issues. #285 has
  #                           four, and two were filed by this plugin while
  #                           discussing the very bug being fixed here.
  #   merged_at != null     — a proposed fix nobody merged is not evidence.
  #   same repository       — a cross-reference can arrive from another repo.
  #                           Issue #368 collects one from tokenpace#377, and
  #                           `gh pr view 377` would have quietly answered with
  #                           *this* repo's #377: a different PR, different
  #                           files, evidence belonging to another project.
  #   ordering by merged_at — #100 carries #101 (its actual fix) and #393 (a
  #                           label migration seven months later). Newest-wins
  #                           would pick the migration.
  # `gh api --jq` takes no --arg, so the repo is filtered downstream in jq
  # proper rather than interpolated into the filter string.
  candidates=$(gh api "repos/$REPO/issues/$n/timeline" --paginate --jq '
      [ .[] | select(.event == "cross-referenced") | .source.issue
        | select(.pull_request != null)
        | select(.pull_request.merged_at != null)
        | {number, title, body: (.body // ""), repo: .repository.full_name,
           merged_at: .pull_request.merged_at} ]' 2>/dev/null \
    | jq -c --arg repo "$REPO" '[ .[] | select(.repo == $repo) ]' 2>/dev/null || echo '[]')

  if [[ "$closed_at" != "" ]]; then
    # Closed: the fix is the last PR merged at or before the close. GitHub
    # closes the issue moments after the merge — observed at one and two
    # seconds on this repo — so allow a minute of slack rather than trusting
    # an ordering that is nowhere guaranteed.
    chosen=$(jq -c --arg closed "$closed_at" '
        [ .[] | select(.merged_at <= ($closed | fromdateiso8601 + 60 | todateiso8601)) ]
        | sort_by(.merged_at) | last // empty' <<<"$candidates")
    is_fix=true
  else
    # Open with merged work against it: take the most recent, and say plainly
    # that it is not a fix. Seven of twenty open issues in this repo are in
    # this state — treating "closed" as the precondition would discard all of
    # them, including #368 and #364, where the work is done and only the close
    # is missing.
    chosen=$(jq -c 'sort_by(.merged_at) | last // empty' <<<"$candidates")
    is_fix=false
  fi

  if [[ -z "$chosen" || "$chosen" == "null" ]]; then
    jq -nc --argjson number "$n" --arg st "$issue_state" \
       '{number: $number, issueState: $st, pr: null, files: []}'
    continue
  fi

  pr=$(jq -r '.number' <<<"$chosen")
  # `|| true` is load-bearing: grep exits 1 when a PR body states no issue
  # relationship, and under `set -o pipefail` that kills the whole run. PR #377
  # is exactly that case — it mentions #368 in prose without a closing keyword.
  links=$(jq -r '.body // ""' <<<"$chosen" | { grep -Ei "$LINK_RE" || true; } | head -4 | jq -Rsc 'rtrimstr("\n")')
  files=$(gh pr view "$pr" --repo "$REPO" --json files --jq \
          "[.files[] | {path, churn: (.additions + .deletions)}
            | select(.churn >= $MIN_CHURN)] | sort_by(-.churn)" 2>/dev/null || echo '[]')

  jq -nc --argjson number "$n" --arg st "$issue_state" --argjson chosen "$chosen" \
         --argjson files "$files" --argjson isFix "$is_fix" \
         --argjson head "$BODY_HEAD" --argjson links "${links:-\"\"}" \
     '{number: $number, issueState: $st, pr: $chosen.number, prTitle: $chosen.title,
       prSummary: ($chosen.body // "" | .[0:$head]),
       prLinks: $links,
       prMergedAt: $chosen.merged_at, isFix: $isFix, files: $files}'
  sleep 0.2
done
