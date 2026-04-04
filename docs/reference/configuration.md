# Configuration Reference

This page lists the main domains, environment variables, and outputs used across the platform.

## Public Domains

| Purpose | Domain |
| --- | --- |
| UI | `app.acmecorp.autoscaling.io` |
| API gateway | `api.acmecorp.autoscaling.io` |
| Grafana | `grafana.acmecorp.autoscaling.io` |

## Frontend Configuration

| Variable | Purpose | Default |
| --- | --- | --- |
| `VITE_API_BASE_URL` | Browser-facing gateway base URL used by the UI build | `http://localhost:8080` in development, `https://api.acmecorp.autoscaling.io` in production |

Config files:
- `webapp/.env.development`
- `webapp/.env.production`
- `webapp/src/config/api.ts`

## Gateway Configuration

Key environment-backed properties in `gateway-service`:

| Property / Env | Purpose |
| --- | --- |
| `ORDERS_BASE_URL` | downstream orders service base URL |
| `CATALOG_BASE_URL` | downstream catalog service base URL |
| `BILLING_BASE_URL` | downstream billing service base URL |
| `NOTIFICATION_BASE_URL` | downstream notification service base URL |
| `ANALYTICS_BASE_URL` | downstream analytics service base URL |
| `GATEWAY_CORS_ORIGIN_LOCAL` | local Vite origin |
| `GATEWAY_CORS_ORIGIN_LOCAL_ALT` | alternate local loopback origin |
| `GATEWAY_CORS_ORIGIN_PREVIEW` | preview / E2E Vite origin |
| `GATEWAY_CORS_ORIGIN_PREVIEW_ALT` | alternate preview origin |
| `GATEWAY_CORS_ORIGIN_UI` | deployed UI origin |

## Terraform Inputs

| Variable | Purpose |
| --- | --- |
| `eks_secrets_kms_key_arn` | optional existing KMS key ARN for EKS secrets envelope encryption |
| `route53_zone_name` | public Route53 hosted zone |
| `gateway_ingress_host` | API hostname |
| `grafana_ingress_host` | Grafana hostname |
| `ui_subdomain` | UI hostname label |
| `ui_bucket_name_override` | optional explicit S3 bucket name |
| `ui_build_assets_path` | local build path used by deploy workflows |

## Terraform Outputs

| Output | Purpose |
| --- | --- |
| `cluster_name` | EKS cluster name |
| `cluster_secrets_kms_key_arn` | retained customer-managed KMS key ARN for EKS secrets encryption |
| `eks_cluster_security_group_id` | EKS-managed cluster security group used by the Auto Mode networking model |
| `aurora_endpoint` | Aurora writer endpoint |
| `mq_broker_endpoint` | Amazon MQ endpoint |
| `gateway_ingress_host` | public gateway hostname |
| `ui_bucket_name` | UI asset bucket |
| `ui_cloudfront_domain_name` | raw CloudFront domain |
| `ui_cloudfront_url` | full CloudFront URL |
| `ui_cloudfront_distribution_id` | distribution ID for invalidation |
| `ui_custom_domain` | UI custom hostname |
| `ui_custom_url` | UI custom URL |

Inspect them:

```bash
terraform -chdir=infra/terraform output
```
