# Troubleshooting

This page covers the most common local and AWS deployment problems.

## Local UI Cannot Reach The Gateway

Symptoms:
- browser CORS errors
- failed fetches from `webapp`
- `ERR_CONNECTION_REFUSED` to `localhost:8080`

Checks:

```bash
curl http://localhost:8080/api/gateway/status
cat webapp/.env.development
```

Expected:
- gateway responds on `http://localhost:8080`
- `VITE_API_BASE_URL=http://localhost:8080`

## CORS Is Blocking Requests

Check the gateway preflight behavior:

```bash
curl -i -X OPTIONS http://localhost:8080/api/gateway/orders \
  -H 'Origin: http://localhost:5173' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: Content-Type,Idempotency-Key'
```

The origin must match one of the configured allowed origins in `gateway-service`.

## UI Build Uses The Wrong API Domain

Check the production build input:

```bash
terraform -chdir=infra/terraform output gateway_ingress_host
```

Manual production build:

```bash
VITE_API_BASE_URL="https://$(terraform -chdir=infra/terraform output -raw gateway_ingress_host)" \
  npm --prefix webapp run build
```

## Terraform Cannot Plan Or Apply

Common causes:
- missing AWS credentials
- Secrets Manager secrets pending deletion
- backend S3 state access problems

Checks:

```bash
aws sts get-caller-identity
scripts/restore-secrets-if-pending-deletion.sh
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform plan
```

## Helm Release Fails

Validate before deploy:

```bash
PROD_VALUES=/tmp/acmecorp-values-prod.generated.yaml scripts/validate-deploy.sh
```

Inspect workloads:

```bash
kubectl get pods -n acmecorp
kubectl describe pod -n acmecorp <pod-name>
kubectl logs -n acmecorp deploy/acmecorp-platform-gateway-service --tail=200
```

## UI Deploy Succeeds But Browser Still Shows Old Assets

Invalidate CloudFront:

```bash
aws cloudfront create-invalidation \
  --distribution-id "$(terraform -chdir=infra/terraform output -raw ui_cloudfront_distribution_id)" \
  --paths "/*"
```

Also verify that `index.html` was uploaded with no-cache headers.

## Analytics Cannot Reach Redis On EKS

Check the secret in the app namespace:

```bash
kubectl get secret analytics-redis-credentials -n acmecorp
kubectl get externalsecret analytics-redis-credentials -n acmecorp -o yaml
kubectl get deploy acmecorp-platform-analytics-service -n acmecorp -o yaml
```
