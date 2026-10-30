#!/usr/bin/env bash
# Runs terraform with all of its output going to a file, never to the job
# log. This repository's Actions logs are public, and Terraform prints values
# from inside resources that providers do not always mark sensitive.
#
# Prints one status line. On failure it also prints Terraform's "Error:"
# headlines, redacted, so the log still says what broke; the full output is in
# the private plan store (plan-store-upload.sh).
#
# Usage: terraform-quiet.sh <log file> <terraform arguments...>
set -euo pipefail

log=${1:?usage: terraform-quiet.sh <log file> <terraform arguments...>}
shift
here=$(dirname "$0")

if terraform "$@" > "$log" 2>&1; then
  echo "terraform $1: ok (output withheld from this public log)"
  exit 0
fi

echo "::error::terraform $1 failed. Output withheld from this public log; the full log is in the private plan store."
grep -E '^(│ )?Error: ' "$log" | sed 's/^│ //' | "$here/redact.sh" || true
exit 1
