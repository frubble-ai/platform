#!/usr/bin/env bash
# Runs terraform with its output in a file; prints a status line, and the
# redacted error headlines on failure.
#
# Usage: terraform-quiet.sh <log file> <terraform arguments...>
set -euo pipefail

log=${1:?usage: terraform-quiet.sh <log file> <terraform arguments...>}
shift
here=$(dirname "$0")

if terraform "$@" > "$log" 2>&1; then
  echo "terraform $1: ok"
  exit 0
fi

echo "::error::terraform $1 failed"
grep -E '^(│ )?Error: ' "$log" | sed 's/^│ //' | "$here/redact.sh" || true
exit 1
