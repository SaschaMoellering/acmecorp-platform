#!/usr/bin/env bash
set -euo pipefail

echo "Building frontend..."
pushd webapp >/dev/null
npm ci
npm run build
popd >/dev/null

echo "Reading Terraform outputs..."
UI_BUCKET=$(terraform -chdir=infra/terraform output -raw ui_bucket_name)
UI_DISTRIBUTION_ID=$(terraform -chdir=infra/terraform output -raw ui_cloudfront_distribution_id)

echo "Uploading to S3..."
aws s3 sync webapp/dist/ "s3://${UI_BUCKET}" --delete

echo "Invalidating CloudFront..."
aws cloudfront create-invalidation \
  --distribution-id "${UI_DISTRIBUTION_ID}" \
  --paths "/*"

echo "Done."
