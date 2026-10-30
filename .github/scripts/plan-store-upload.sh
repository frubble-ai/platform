#!/usr/bin/env bash
# Copies a run's full Terraform output into the private plan store,
# gs://$PLAN_STORE_BUCKET/<kind>/<stack>/<ref>/<run id>-<attempt>/
# (layout and access: terraform/live/org/gcp/_setup/plan_store.tf).
#
# Uploads through the JSON API with ifGenerationMatch=0, so each request is a
# pure create: the writer holds objectCreator on its own prefix and nothing
# else, cannot overwrite, and needs no read or list to upload.
#
# Usage: plan-store-upload.sh <plan|apply> <stack> <file...>   (missing files are skipped)
# Env:   PLAN_STORE_BUCKET   bucket; unset means the store is not set up yet
#        PLAN_STORE_REF      pr-<number> or the branch name
#        PLAN_STORE_AS       service account to impersonate (optional; the
#                            GCP jobs authenticate as a hub and write as the spoke)
set -euo pipefail

kind=${1:?usage: plan-store-upload.sh <plan|apply> <stack> <file...>}
stack=${2:?usage: plan-store-upload.sh <plan|apply> <stack> <file...>}
shift 2

if [ -z "${PLAN_STORE_BUCKET:-}" ]; then
  echo "::warning::PLAN_STORE_BUCKET is not set, so the full ${kind} output for ${stack} was not kept."
  exit 0
fi

ref=$(printf '%s' "${PLAN_STORE_REF:?}" | tr -c 'A-Za-z0-9._-' '-')
prefix="${kind}/${stack}/${ref}/${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"

token_args=()
if [ -n "${PLAN_STORE_AS:-}" ]; then token_args=(--impersonate-service-account="$PLAN_STORE_AS"); fi
token=$(gcloud auth print-access-token "${token_args[@]}" 2> /dev/null)
echo "::add-mask::$token"

for file in "$@"; do
  [ -f "$file" ] || continue
  name=$(jq -rn --arg s "${prefix}/$(basename "$file")" '$s | @uri')
  curl -sS --fail-with-body -o /dev/null -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$file" \
    "https://storage.googleapis.com/upload/storage/v1/b/${PLAN_STORE_BUCKET}/o?uploadType=media&ifGenerationMatch=0&name=${name}"
done

echo "Full ${kind} output (organization members only): gs://${PLAN_STORE_BUCKET}/${prefix}/" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
