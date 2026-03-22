# UI Hosting On S3 And CloudFront

The React UI is deployed separately from the EKS workloads.

- Terraform provisions the S3 bucket, CloudFront distribution, ACM certificate in `us-east-1`, and Route53 alias records.
- GitHub Actions builds the UI, syncs `webapp/dist` to the S3 bucket, and invalidates CloudFront.
- The S3 bucket is private. CloudFront reaches it through Origin Access Control.

## Manual Deploy

Build the UI:

```bash
cd webapp
npm ci
npm run build
```

Read the Terraform outputs:

```bash
terraform -chdir=infra/terraform output ui_bucket_name
terraform -chdir=infra/terraform output ui_cloudfront_domain_name
terraform -chdir=infra/terraform output ui_custom_domain
```

Upload the built assets:

```bash
aws s3 sync webapp/dist/ "s3://$(terraform -chdir=infra/terraform output -raw ui_bucket_name)" \
  --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "index.html"

aws s3 cp webapp/dist/index.html \
  "s3://$(terraform -chdir=infra/terraform output -raw ui_bucket_name)/index.html" \
  --cache-control "no-cache,no-store,must-revalidate" \
  --content-type "text/html"
```

Invalidate CloudFront:

```bash
aws cloudfront create-invalidation \
  --distribution-id "$(terraform -chdir=infra/terraform output -raw ui_cloudfront_distribution_id)" \
  --paths "/*"
```
