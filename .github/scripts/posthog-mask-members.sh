#!/usr/bin/env bash
# Registers every PostHog member's email and name as a GitHub Actions secret
# mask, so they print as *** if anything does reach the public job log.
#
# Defense in depth only: the PostHog jobs never print Terraform's raw output
# (see terraform-plan-summary.sh). Masks both sources a value can come from:
# the members map (TF_VAR_members), and the managed state, which still holds a
# member who was just removed from the map and is about to be planned away.
#
# Run in the root, after terraform init.
set -euo pipefail

{
  jq -r '.[].email' <<< "${TF_VAR_members:-"{}"}"
  terraform show -json 2>/dev/null | jq -r '
    [ .values.root_module.resources[]?
      | select(.type == "posthog_organization_member")
      | .values | .email, .first_name, .last_name ] | .[]
    | select(type == "string")'
} | while IFS= read -r value; do
  # Shorter values would mask unrelated text all over the log.
  if [ "${#value}" -ge 3 ]; then echo "::add-mask::$value"; fi
done
