#!/usr/bin/env bash
# Uploads files to gs://$PLAN_STORE_BUCKET/<kind>/<stack>/<ref>/<run id>-<attempt>/
# as create-only requests (ifGenerationMatch=0). No-op when the bucket is unset.
#
# Usage: plan-store-upload.sh <plan|apply> <stack> <file...>
# Env:   PLAN_STORE_BUCKET, PLAN_STORE_REF (pr-<n> or branch),
#        PLAN_STORE_AS (service account to impersonate, optional)
set -euo pipefail

kind=${1:?usage: plan-store-upload.sh <plan|apply> <stack> <file...>}
stack=${2:?usage: plan-store-upload.sh <plan|apply> <stack> <file...>}
shift 2

if [ -z "${PLAN_STORE_BUCKET:-}" ]; then exit 0; fi

ref=$(printf '%s' "${PLAN_STORE_REF:?}" | tr -c 'A-Za-z0-9._-' '-')
prefix="${kind}/${stack}/${ref}/${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"

token_args=()
if [ -n "${PLAN_STORE_AS:-}" ]; then token_args=(--impersonate-service-account="$PLAN_STORE_AS"); fi
token=$(timeout 60 gcloud auth print-access-token "${token_args[@]}" 2> /dev/null)
echo "::add-mask::$token"

for file in "$@"; do
  [ -f "$file" ] || continue
  name=$(jq -rn --arg s "${prefix}/$(basename "$file")" '$s | @uri')
  curl -sS --fail-with-body -o /dev/null -X POST \
    --connect-timeout 20 --max-time 120 \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$file" \
    "https://storage.googleapis.com/upload/storage/v1/b/${PLAN_STORE_BUCKET}/o?uploadType=media&ifGenerationMatch=0&name=${name}"
done

