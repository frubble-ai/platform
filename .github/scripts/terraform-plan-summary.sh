#!/usr/bin/env bash
# Prints a saved Terraform plan as resource addresses, actions and counts,
# and nothing else: no attribute values, before or after.
#
# For roots whose plan carries personal data the provider does not mark
# sensitive (PostHog's organization_member returns email, first_name and
# last_name as plain computed attributes). This repository is public, and so
# are its Actions logs and plan comments, so redacting known fields one by one
# would leak the next field the provider adds. A summary built from
# `terraform show -json` has no values to leak.
#
# The last line keeps Terraform's own "Plan: N to add, N to change, N to
# destroy." or "No changes." wording, which live-plan.yml reads for the counts.
#
# Usage: terraform-plan-summary.sh <saved plan file>   (run in the root)
set -euo pipefail

plan_file=${1:?usage: terraform-plan-summary.sh <saved plan file>}

terraform show -json "$plan_file" | jq -r '
  def verb:
    .change.actions as $a
    | if   $a == ["create"] then "create"
      elif $a == ["update"] then "update"
      elif $a == ["delete"] then "destroy"
      elif $a == ["forget"] then "forget (removed from state, left in place)"
      elif ($a | sort) == ["create", "delete"] then "replace"
      elif $a == ["no-op"] then null
      else ($a | join("+"))
      end;

  [ .resource_changes[]? | select(.mode == "managed") ] as $rc
  | [ $rc[] | {address, verb: verb, import: (.change.importing != null)}
      | select(.verb != null or .import) ] as $shown
  | ($rc | map(.change.actions) ) as $acts
  | {
      add:     ($acts | map(select(. == ["create"] or (sort == ["create", "delete"]))) | length),
      change:  ($acts | map(select(. == ["update"])) | length),
      destroy: ($acts | map(select(. == ["delete"] or (sort == ["create", "delete"]))) | length),
      forget:  ($acts | map(select(. == ["forget"])) | length),
      import:  ($rc | map(select(.change.importing != null)) | length),
      outputs: ([ .output_changes // {} | to_entries[] | select(.value.actions != ["no-op"]) ] | length)
    } as $n
  | "Sanitized plan: addresses and actions only. Attribute values are withheld",
    "because this repository and its Actions logs are public.",
    "",
    ( $shown[] | "  # \(.address): \([.verb, (if .import then "import" else null end)] | map(select(. != null)) | join(", "))" ),
    ( if ($shown | length) > 0 then "" else empty end ),
    ( if ($n.import + $n.forget + $n.outputs) > 0
      then "Also: \($n.import) to import, \($n.forget) to forget, \($n.outputs) output(s) changed."
      else empty end ),
    ( if ($shown | length) == 0 and $n.outputs == 0
      then "No changes. Your infrastructure matches the configuration."
      else "Plan: \($n.add) to add, \($n.change) to change, \($n.destroy) to destroy."
      end )
'
