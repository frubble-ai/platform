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
# What "succeeded" means is the caller's: the whole run, or with JOBS the
# named jobs alone, so a job the caller does not depend on cannot hold it.
# A run that was cancelled was superseded by a newer push on the branch
# (concurrency replaces a queued run); a later run that succeeded and whose
# commit contains this one did the same work, and counts.
#
# PATHS mirrors WORKFLOW's trigger paths; change both.
#
# Env: GH_TOKEN, REPO (owner/name), SHA, BEFORE (may be empty or all zeros),
#      BRANCH, WORKFLOW (its file name), PATHS (an extended regex over
#      changed paths), JOBS (optional: job names that must succeed,
#      separated by |, as the run's job list prints them)
set -euo pipefail

: "${REPO:?}" "${SHA:?}" "${BRANCH:?}" "${WORKFLOW:?}" "${PATHS:?}"
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

# id, status, conclusion and url of the newest run for a commit.
run_for() {
  gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?head_sha=$1&per_page=1" \
    --jq '.workflow_runs[0] // empty | "\(.id) \(.status) \(.conclusion // "-") \(.html_url)"'
}

# Whether a completed run did what the caller needs: every job in JOBS
# succeeded, or, with no JOBS, the run as a whole did.
succeeded() {
  local id=$1 conclusion=$2
  if [ -z "${JOBS:-}" ]; then
    [ "$conclusion" = "success" ]
    return
  fi
  local jobs name
  jobs=$(gh api "repos/$REPO/actions/runs/$id/jobs?per_page=100" \
    --jq '.jobs[] | "\(.conclusion // "-")\t\(.name)"')
  IFS='|' read -ra names <<<"$JOBS"
  for name in "${names[@]}"; do
    if ! grep -qxF "success	$name" <<<"$jobs"; then
      echo "job '$name' did not succeed in run $id"
      return 1
    fi
  done
}

run=""
for _ in $(seq 1 30); do
  run=$(run_for "$SHA")
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
  read -r id status conclusion url <<<"$run"
  if [ "$status" = "completed" ]; then
    if succeeded "$id" "$conclusion"; then
      echo "$WORKFLOW succeeded: $url"
      exit 0
    fi
    [ "$conclusion" = "cancelled" ] && break
    echo "::error::$WORKFLOW did not succeed ($conclusion): $url. Re-run this workflow once it has."
    exit 1
  fi
  echo "$WORKFLOW is $status, waiting: $url"
  sleep 30
  run=$(run_for "$SHA")
done

# Superseded: a newer push replaced the queued run, and the newest run on
# the branch whose commit contains this one does the same work. Polled like
# the first: it may still be queued, it may fail, or it may be superseded in
# turn, in which case the next poll finds the run that replaced it.
echo "$WORKFLOW was cancelled for $SHA, superseded by a newer push: $url"

# Fetched on every poll: a replacement may run a commit the clone does not
# have yet.
replacement() {
  git fetch --quiet origin "$BRANCH"
  gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?branch=$BRANCH&per_page=20" \
    --jq '.workflow_runs[] | "\(.id) \(.status) \(.conclusion // "-") \(.head_sha) \(.html_url)"' \
    | while read -r id status conclusion head url; do
        # Newer than the last cancelled one: ids grow, so this never falls
        # back to a run already rejected.
        if [ "$id" -gt "${cancelled:-0}" ] && git merge-base --is-ancestor "$SHA" "$head"; then
          echo "$id $status $conclusion $head $url"
          break
        fi
      done
}

# A replacement that is not visible yet, or was cancelled in turn, gets the
# same five minutes the first run got to appear.
cancelled=""
missing=0
while :; do
  rep=$(replacement)
  if [ -z "$rep" ]; then
    missing=$((missing + 1))
    if [ "$missing" -gt 10 ]; then
      echo "::error::$WORKFLOW was superseded for $SHA and no later run contains it after five minutes. Re-run this workflow once one has succeeded."
      exit 1
    fi
    sleep 30
    continue
  fi
  missing=0
  read -r id status conclusion head url <<<"$rep"
  if [ "$status" = "completed" ]; then
    if [ "$conclusion" = "cancelled" ]; then
      echo "$WORKFLOW was cancelled for $head too: $url"
      cancelled=$id
      sleep 30
      continue
    fi
    if succeeded "$id" "$conclusion"; then
      echo "$WORKFLOW succeeded for $head, which contains $SHA: $url"
      exit 0
    fi
    echo "::error::$WORKFLOW did not succeed ($conclusion) for $head, which contains $SHA: $url. Re-run this workflow once it has."
    exit 1
  fi
  echo "$WORKFLOW is $status for $head, which contains $SHA, waiting: $url"
  sleep 30
done
