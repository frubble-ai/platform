#!/usr/bin/env bash
# Filter: redacts emails, UUIDs, 32-hex ids and 9+ digit numbers.
set -euo pipefail

# Lookarounds, not boundary characters: a pattern that consumes the character
# beside a match leaves the next id in a comma- or space-separated run
# unmatched, because global substitutions do not overlap.
perl -pe '
  s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/(redacted-email)/g;
  s/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/(redacted-id)/g;
  s/(?<![0-9a-fA-F])[0-9a-fA-F]{32}(?![0-9a-fA-F])/(redacted-id)/g;
  s/(?<![0-9])[0-9]{9,}(?![0-9])/(redacted-number)/g;
'
