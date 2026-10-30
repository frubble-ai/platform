#!/usr/bin/env bash
# Filter: replaces anything shaped like personal data or an account
# identifier with a placeholder. Defense in depth for text bound for a public
# log or comment; the text it filters is already meant to hold no values.
#
#   email addresses, UUIDs, 32-character hex ids (Cloudflare account, zone and
#   tunnel ids), and runs of 9 or more digits (GCP project numbers, billing
#   and other account numbers).
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
