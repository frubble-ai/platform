#!/usr/bin/env bash
# Waits for the setup-cd run on this commit before a workload apply proceeds.
#
# A push that touches a _setup root starts setup-cd beside the caller, and
# setup-cd then waits in the `setup` environment for a reviewer. The workload
# apply reads _setup outputs through remote state, so applying against the
# old _setup state would miss a new output or use a stale one. Decided from
# the push where it can be: the other run may register after this job starts,
# and silence must not read as "not triggered". When the previous commit is
# not in the clone, as after a force-push, or there is none, as on a dispatch,
# the answer comes from the poll instead. Exits 0 when there is nothing to
# wait for or setup-cd succeeded, 1 otherwise.
#
# The path list mirrors setup-cd.yml's triggers; change both. This script is
# not among them: it gates the workload applies, which setup-cd never runs.
#
# Env: GH_TOKEN, REPO (owner/name), SHA, BEFORE (may be empty or all zeros)
set -euo pipefail

: "${REPO:?}" "${SHA:?}"
paths='^(terraform/live/[^/]+/gcp/_setup/|terraform/modules/gcp/(developer-access|plan-store|project|project-pin|state-bucket|wif-hub|wif-spoke)/|\.github/workflows/(_setup-apply|setup-cd)\.yml$|\.github/scripts/terraform/)'

expected=unknown
if [ -n "${BEFORE:-}" ] && git cat-file -e "$BEFORE^{commit}" 2>/dev/null; then
  # Captured first: in a pipeline, grep -q stopping at its first match can
  # hand git diff a SIGPIPE, which would read as no match.
  changed=$(git diff --name-only "$BEFORE" "$SHA")
  if grep -qE "$paths" <<<"$changed"; then
    expected=yes
    echo "this push touched a _setup path; setup-cd must run for $SHA"
  else
    echo "this push touched no _setup path; nothing to wait for"
    exit 0
  fi
else
  echo "no previous commit to diff against; checking for a setup-cd run"
fi

latest() {
  gh api "repos/$REPO/actions/workflows/setup-cd.yml/runs?head_sha=$SHA&per_page=1" \
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
    echo "::error::a _setup path changed but no setup-cd run exists for $SHA after five minutes"
    exit 1
  fi
  echo "no setup-cd run for $SHA; nothing to wait for"
  exit 0
fi

while :; do
  read -r status conclusion url <<<"$run"
  if [ "$status" = "completed" ]; then
    if [ "$conclusion" = "success" ]; then
      echo "setup-cd succeeded: $url"
      exit 0
    fi
    echo "::error::setup-cd did not succeed ($conclusion): $url. Re-run this workflow once it has."
    exit 1
  fi
  echo "setup-cd is $status, waiting: $url"
  sleep 30
  run=$(latest)
done
