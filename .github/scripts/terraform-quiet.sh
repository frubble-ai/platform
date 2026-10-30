#!/usr/bin/env bash
# Runs terraform with its output in a file and prints a status line. On
# failure it prints the redacted error headlines; when the plan store is not
# configured (PLAN_STORE_BUCKET unset), the whole redacted error blocks
# instead, so the failure can still be diagnosed from the log.
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
if [ -n "${PLAN_STORE_BUCKET:-}" ]; then
  grep -E '^(│ )?Error: ' "$log" | sed 's/^│ //' | "$here/redact.sh" || true
else
  # Diagnostics are boxed between ╷ and ╵; keep the Error blocks only.
  awk '/^╷/ { block = ""; inb = 1; next }
       /^╵/ { if (block ~ /(^|\n)Error: /) printf "%s\n", block; inb = 0; next }
       inb  { sub(/^│ ?/, ""); block = block $0 "\n" }
       /^Error: / && !inb { print }' "$log" \
    | head -n 200 | "$here/redact.sh" || true
fi
exit 1
