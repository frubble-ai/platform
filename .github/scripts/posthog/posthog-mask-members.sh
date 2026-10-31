#!/usr/bin/env bash
# Masks PostHog member emails and names (from TF_VAR_members and from state).
# Run in the root after terraform init.
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
