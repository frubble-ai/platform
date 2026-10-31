#!/usr/bin/env bash
# Refuses to apply a _setup root unless the GitHub environment the job runs
# in has a required-reviewer rule that bars self-review.
#
# The path to the bootstrap admin is pinned in code; the person who must
# approve is a repository setting the code never reads. Without the rule, a
# merge to dev would apply every _setup root as the pool's owner with nobody
# in the loop; without the self-review bar, the person who pushed to dev
# approves their own apply. So the job reads the setting rather than assumes.
#
# Env: GH_TOKEN, REPO (owner/name), ENVIRONMENT
set -euo pipefail

: "${REPO:?}" "${ENVIRONMENT:?}"
reviewers=$(gh api "repos/$REPO/environments/$ENVIRONMENT" \
  --jq '[.protection_rules[] | select(.type == "required_reviewers" and .prevent_self_review == true) | .reviewers[]] | length')
if [ "$reviewers" = "0" ]; then
  echo "::error::environment $ENVIRONMENT has no required-reviewer rule that bars self-review; refusing to apply a _setup root"
  exit 1
fi
echo "environment $ENVIRONMENT requires $reviewers reviewer(s), self-review barred"
