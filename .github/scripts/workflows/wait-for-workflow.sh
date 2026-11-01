#!/usr/bin/env bash
# Waits for another workflow's run on this commit before an apply proceeds.
#
# A push that touches PATHS starts WORKFLOW beside the caller, and the caller
# applies something that reads what that run produces: a workload root reads
# the _setup outputs setup-cd writes, the Mailgun setup root keys the domain
# stg-cd registers. Decided from the push where it can be: the other run may
# register after this job starts, and silence must not read as "not
# triggered". When the previous commit is not in the clone, as after a
# force-push, or there is none, as on a dispatch, the answer comes from the
# poll instead. Exits 0 when there is nothing to wait for or the run
# succeeded, 1 otherwise.
#
# PATHS mirrors WORKFLOW's trigger paths; change both.
#
# Env: GH_TOKEN, REPO (owner/name), SHA, BEFORE (may be empty or all zeros),
#      WORKFLOW (its file name), PATHS (an extended regex over changed paths)
set -euo pipefail

: "${REPO:?}" "${SHA:?}" "${WORKFLOW:?}" "${PATHS:?}"
paths="$PATHS"

expected=unknown
if [ -n "${BEFORE:-}" ] && git cat-file -e "$BEFORE^{commit}" 2>/dev/null; then
  # Captured first: in a pipeline, grep -q stopping at its first match can
  # hand git diff a SIGPIPE, which would read as no match.
  changed=$(git diff --name-only "$BEFORE" "$SHA")
  if grep -qE "$paths" <<<"$changed"; then
    expected=yes
    echo "this push touched a path $WORKFLOW triggers on; it must run for $SHA"
  else
    echo "this push touched no path $WORKFLOW triggers on; nothing to wait for"
    exit 0
  fi
else
  echo "no previous commit to diff against; checking for a $WORKFLOW run"
fi

latest() {
  gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?head_sha=$SHA&per_page=1" \
    --jq '.workflow_runs[0] // empty | "\(.status) \(.conclusion // "-") \(.html_url)"'
}

run=""
for _ in $(seq 1 30); do
  run=$(latest)
  [ -n "$run" ] && break
  sleep 10
done
if [ -z "$run" ]; then
  if [ "$expected" = yes ]; then
    echo "::error::a path $WORKFLOW triggers on changed but no run of it exists for $SHA after five minutes"
    exit 1
  fi
  echo "no $WORKFLOW run for $SHA; nothing to wait for"
  exit 0
fi

while :; do
  read -r status conclusion url <<<"$run"
  if [ "$status" = "completed" ]; then
    if [ "$conclusion" = "success" ]; then
      echo "$WORKFLOW succeeded: $url"
      exit 0
    fi
    echo "::error::$WORKFLOW did not succeed ($conclusion): $url. Re-run this workflow once it has."
    exit 1
  fi
  echo "$WORKFLOW is $status, waiting: $url"
  sleep 30
  run=$(latest)
done
