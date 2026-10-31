#!/usr/bin/env bash
# Prints a saved plan as resource addresses and actions, then the counts line
# ("Plan: N to add, N to change, N to destroy." or "No changes.", which
# live-plan.yml parses). No attribute values. for_each keys must be handles.
#
# Usage: terraform-plan-summary.sh <saved plan file>   (run in the root)
set -euo pipefail

plan_file=${1:?usage: terraform-plan-summary.sh <saved plan file>}
here=$(dirname "$0")

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
  | [ $rc[] | {address, verb: verb, import: (.change.importing != null), from: .previous_address}
      | select(.verb != null or .import or .from != null) ] as $shown
  | ($rc | map(.change.actions) ) as $acts
  | {
      add:     ($acts | map(select(. == ["create"] or (sort == ["create", "delete"]))) | length),
      change:  ($acts | map(select(. == ["update"])) | length),
      destroy: ($acts | map(select(. == ["delete"] or (sort == ["create", "delete"]))) | length),
      forget:  ($acts | map(select(. == ["forget"])) | length),
      import:  ($rc | map(select(.change.importing != null)) | length),
      move:    ($rc | map(select(.previous_address != null)) | length),
      outputs: ([ .output_changes // {} | to_entries[] | select(.value.actions != ["no-op"]) ] | length)
    } as $n
  | ( $shown[]
      | "\(.address): \([.verb, (if .import then "import" else null end),
          (if .from != null then "moved from \(.from)" else null end)] | map(select(. != null)) | join(", "))" ),
    ( if ($shown | length) > 0 then "" else empty end ),
    ( if ($n.import + $n.move + $n.forget + $n.outputs) > 0
      then ([ (if $n.import > 0 then "\($n.import) to import" else empty end),
              (if $n.move > 0 then "\($n.move) to move" else empty end),
              (if $n.forget > 0 then "\($n.forget) to forget" else empty end),
              (if $n.outputs > 0 then "\($n.outputs) output(s) changed" else empty end) ] | join(", "))
      else empty end ),
    ( if ($shown | length) == 0 and $n.outputs == 0
      then "No changes."
      else "Plan: \($n.add) to add, \($n.change) to change, \($n.destroy) to destroy."
      end )
' | "$here/redact.sh"
