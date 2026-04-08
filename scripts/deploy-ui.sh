#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
WEBAPP_DIR="${WEBAPP_DIR:-$ROOT_DIR/webapp}"
UI_BUILD_DIR="${UI_BUILD_DIR:-$WEBAPP_DIR/dist}"
SKIP_CLOUDFRONT_INVALIDATION="${SKIP_CLOUDFRONT_INVALIDATION:-false}"

section() {
  printf '\n==> %s\n' "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

require_cmd aws
require_cmd jq
require_cmd npm
require_cmd terraform

section "Build Frontend"
pushd "$WEBAPP_DIR" >/dev/null
npm ci
npm run build
popd >/dev/null

section "Read Terraform Outputs"
TF_OUTPUT_JSON="$(terraform -chdir="$TF_DIR" output -json)"
UI_BUCKET="$(jq -er '.ui_bucket_name.value' <<<"$TF_OUTPUT_JSON")"
UI_DISTRIBUTION_ID="$(jq -er '.ui_cloudfront_distribution_id.value // empty' <<<"$TF_OUTPUT_JSON" || true)"

if [[ -z "$UI_BUCKET" || "$UI_BUCKET" == "null" ]]; then
  echo "ERROR: terraform output ui_bucket_name is required for UI deployment." >&2
  exit 1
fi

section "Upload UI Assets"
aws s3 sync "$UI_BUILD_DIR/" "s3://${UI_BUCKET}" --delete

if [[ "$SKIP_CLOUDFRONT_INVALIDATION" == "true" ]]; then
  echo "Skipping CloudFront invalidation because SKIP_CLOUDFRONT_INVALIDATION=true."
elif [[ -n "$UI_DISTRIBUTION_ID" && "$UI_DISTRIBUTION_ID" != "null" ]]; then
  section "Invalidate CloudFront"
  aws cloudfront create-invalidation \
    --distribution-id "$UI_DISTRIBUTION_ID" \
    --paths "/*" >/dev/null
  echo "Created invalidation for distribution $UI_DISTRIBUTION_ID."
else
  echo "No CloudFront distribution output found. Skipping invalidation."
fi

section "UI Deployment Complete"
echo "UI assets uploaded to s3://${UI_BUCKET}"
