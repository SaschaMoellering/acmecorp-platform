# UI Hosting With S3 And CloudFront

The UI is deployed separately from the Kubernetes workloads.

## Architecture

- Terraform provisions the S3 bucket, CloudFront distribution, ACM certificate in `us-east-1`, and Route53 alias records
- The S3 bucket is private
- CloudFront reads from S3 through Origin Access Control
- The UI is published at `https://app.acmecorp.autoscaling.io`
- The built UI calls the gateway at `https://api.acmecorp.autoscaling.io`

## Terraform Resources

Provisioned by `infra/terraform/modules/ui`:
- `aws_s3_bucket`
- `aws_s3_bucket_public_access_block`
- `aws_s3_bucket_policy`
- `aws_cloudfront_origin_access_control`
- `aws_cloudfront_distribution`
- `aws_acm_certificate`
- `aws_route53_record`
- `aws_acm_certificate_validation`

## Build-Time API Configuration

The UI uses `VITE_API_BASE_URL`.

Defaults:
- local dev: `webapp/.env.development` -> `http://localhost:8080`
- production build: `webapp/.env.production` -> `https://api.acmecorp.autoscaling.io`

The deploy workflow overrides the production value from Terraform output:

```bash
https://$(terraform -chdir=infra/terraform output -raw gateway_ingress_host)
```

That keeps the production UI build aligned with the current gateway hostname.

## CI/CD Flow

GitHub Actions workflow: `.github/workflows/ui-deploy.yml`

Sequence:
1. Checkout code
2. Install UI dependencies
3. Configure AWS credentials through OIDC
4. `terraform init` against the remote state backend
5. Read `ui_bucket_name`, `ui_cloudfront_distribution_id`, `ui_cloudfront_url`, `ui_custom_url`, and `gateway_ingress_host`
6. Build the UI with `VITE_API_BASE_URL` set from Terraform output
7. `aws s3 sync` the static assets
8. upload `index.html` with no-cache headers
9. invalidate CloudFront

## Manual Commands

Build for production:

```bash
VITE_API_BASE_URL="https://$(terraform -chdir=infra/terraform output -raw gateway_ingress_host)" \
  npm --prefix webapp ci
VITE_API_BASE_URL="https://$(terraform -chdir=infra/terraform output -raw gateway_ingress_host)" \
  npm --prefix webapp run build
```

Sync assets:

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

Inspect outputs:

```bash
terraform -chdir=infra/terraform output ui_bucket_name
terraform -chdir=infra/terraform output ui_cloudfront_domain_name
terraform -chdir=infra/terraform output ui_cloudfront_url
terraform -chdir=infra/terraform output ui_custom_domain
terraform -chdir=infra/terraform output ui_custom_url
```

## Verification

```bash
curl -I "$(terraform -chdir=infra/terraform output -raw ui_cloudfront_url)"
curl -I "$(terraform -chdir=infra/terraform output -raw ui_custom_url)"
curl -I "$(terraform -chdir=infra/terraform output -raw ui_custom_url)/orders/123"
```

Expected result:
- `200` for the root UI
- SPA routes served through `/index.html` on refresh
