#!/usr/bin/env bash
# Masks PostHog member emails and names (from TF_VAR_org_members_access and
# from state).
# Run in the root after tofu init.
set -euo pipefail

{
  jq -r '.[].email' <<< "${TF_VAR_org_members_access:-"{}"}"
  # Raw state, not `tofu show -json`: show loads every provider schema the
  # state names, and state Terraform wrote still names
  # registry.terraform.io/posthog/posthog, which OpenTofu doesn't install
  # (the next apply rewrites it). An empty or missing state prints nothing.
  tofu state pull | jq -r '
    [ .resources[]?
      | select(.mode == "managed" and .type == "posthog_organization_member")
      | .instances[]?.attributes | .email, .first_name, .last_name ] | .[]
    | select(type == "string")'
} | while IFS= read -r value; do
  # Shorter values would mask unrelated text all over the log.
  if [ "${#value}" -ge 3 ]; then echo "::add-mask::$value"; fi
done
