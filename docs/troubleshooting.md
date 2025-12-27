# Troubleshooting

## Docker Compose issues

**Error:** `docker compose: command not found`  
Fix:
```bash
docker --version
docker compose version
```
Install Docker Desktop or the Docker Compose v2 plugin, then retry:
```bash
cd infra/local
docker compose up -d --build
```

**Error:** `Cannot connect to the Docker daemon`  
Fix: start Docker, then retry:
```bash
docker info
```

## Port conflicts

**Error:** `Bind for 0.0.0.0:8080 failed: port is already allocated`  
Fix: stop the conflicting service or change the port mapping in `infra/local/docker-compose.yml`.
```bash
lsof -i :8080
```

## Terraform not found

**Error:** `terraform: command not found`  
Fix: install Terraform and re-run the wrapper:
```bash
./scripts/tf.sh init
```
`scripts/tf.sh` prints platform-specific install steps if Terraform is missing.

## AWS SSO expired or invalid credentials

**Error:** `The SSO session associated with this profile has expired or is otherwise invalid`  
Fix:
```bash
aws sso login --profile tf
```
Then retry:
```bash
./scripts/tf.sh plan
```

## Terraform init fails (S3 backend, permissions)

**Error:** `AccessDenied` or `NoSuchBucket` during `init`  
Fix:
- Confirm you are using the correct profile and region:
  ```bash
  export AWS_PROFILE=tf
  export AWS_SDK_LOAD_CONFIG=1
  export AWS_REGION=eu-west-1
  ```
- Re-run init:
  ```bash
  ./scripts/tf.sh init
  ```
- If the backend bucket is missing or permissions are wrong, check the backend configuration in `infra/terraform/backend.hcl` and your AWS IAM access.

## Services not reachable locally

**Symptom:** `curl: (7) Failed to connect to localhost port 8080`  
Fix:
```bash
cd infra/local
docker compose ps
docker compose logs -f gateway-service
```
If services are still starting, wait a few seconds and retry:
```bash
curl http://localhost:8080/api/gateway/status
```
