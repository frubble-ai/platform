#!/usr/bin/env bash
# Runs tofu with its output in a file and prints a status line. On
# failure it prints the redacted error headlines; when the plan store is not
# configured (PLAN_STORE_BUCKET unset), the whole redacted error blocks
# instead, so the failure can still be diagnosed from the log.
#
# Usage: tofu-quiet.sh <log file> <tofu arguments...>
set -euo pipefail

log=${1:?usage: tofu-quiet.sh <log file> <tofu arguments...>}
shift
here=$(dirname "$0")

if tofu "$@" > "$log" 2>&1; then
  echo "tofu $1: ok"
  exit 0
fi

echo "::error::tofu $1 failed"
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
