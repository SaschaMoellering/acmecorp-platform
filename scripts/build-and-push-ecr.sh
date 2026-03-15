#!/usr/bin/env bash
set -euo pipefail

# Build and push all six platform service images to Terraform-managed ECR repositories.
# Inputs:
# - required image tag argument
# - Terraform outputs from infra/terraform, or TF_OUTPUT_JSON, or ECR_ENV_FILE
# Output:
# - six pushed images in ECR tagged with the requested image tag

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
TF_OUTPUT_JSON="${TF_OUTPUT_JSON:-}"
ECR_ENV_FILE="${ECR_ENV_FILE:-}"
IMAGE_TAG="${1:-${IMAGE_TAG:-}}"
AWS_REGION="${AWS_REGION:-}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "ERROR: required value missing: $name" >&2
    exit 1
  fi
}

require_cmd aws
require_cmd docker
require_cmd jq
require_cmd terraform

if [[ -z "$IMAGE_TAG" ]]; then
  echo "ERROR: image tag is required. Usage: scripts/build-and-push-ecr.sh <image-tag>" >&2
  exit 1
fi

if [[ -n "$ECR_ENV_FILE" ]]; then
  if [[ ! -f "$ECR_ENV_FILE" ]]; then
    echo "ERROR: ECR env file not found: $ECR_ENV_FILE" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$ECR_ENV_FILE"
fi

if [[ -n "$TF_OUTPUT_JSON" ]]; then
  if [[ ! -f "$TF_OUTPUT_JSON" ]]; then
    echo "ERROR: terraform output json file not found: $TF_OUTPUT_JSON" >&2
    exit 1
  fi
  TF_JSON="$(cat "$TF_OUTPUT_JSON")"
elif [[ -z "${ECR_GATEWAY:-}" ]]; then
  TF_JSON="$(terraform -chdir="$TF_DIR" output -json)"
fi

if [[ -z "$AWS_REGION" ]]; then
  AWS_REGION="$(terraform -chdir="$TF_DIR" console <<'EOF' | tr -d '\r'
var.aws_region
EOF
)"
  AWS_REGION="${AWS_REGION//\"/}"
fi

tf_output_ecr() {
  local repo="$1"
  jq -er --arg repo "$repo" '.ecr_repository_urls.value[$repo]' <<<"$TF_JSON"
}

ECR_GATEWAY="${ECR_GATEWAY:-$(tf_output_ecr acmecorp/gateway-service)}"
ECR_ORDERS="${ECR_ORDERS:-$(tf_output_ecr acmecorp/orders-service)}"
ECR_CATALOG="${ECR_CATALOG:-$(tf_output_ecr acmecorp/catalog-service)}"
ECR_BILLING="${ECR_BILLING:-$(tf_output_ecr acmecorp/billing-service)}"
ECR_ANALYTICS="${ECR_ANALYTICS:-$(tf_output_ecr acmecorp/analytics-service)}"
ECR_NOTIFICATION="${ECR_NOTIFICATION:-$(tf_output_ecr acmecorp/notification-service)}"

require_value "aws_region" "$AWS_REGION"
require_value "acmecorp/gateway-service repository url" "$ECR_GATEWAY"
require_value "acmecorp/orders-service repository url" "$ECR_ORDERS"
require_value "acmecorp/catalog-service repository url" "$ECR_CATALOG"
require_value "acmecorp/billing-service repository url" "$ECR_BILLING"
require_value "acmecorp/analytics-service repository url" "$ECR_ANALYTICS"
require_value "acmecorp/notification-service repository url" "$ECR_NOTIFICATION"

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY_HOST="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$REGISTRY_HOST"

build_and_push() {
  local service_dir="$1"
  local image_ref="$2"

  echo "==> Building $image_ref from $service_dir"
  docker build -t "$image_ref" "$service_dir"

  echo "==> Pushing $image_ref"
  docker push "$image_ref"
}

build_and_push "$ROOT_DIR/services/spring-boot/gateway-service" "${ECR_GATEWAY}:${IMAGE_TAG}"
build_and_push "$ROOT_DIR/services/spring-boot/orders-service" "${ECR_ORDERS}:${IMAGE_TAG}"
build_and_push "$ROOT_DIR/services/quarkus/catalog-service" "${ECR_CATALOG}:${IMAGE_TAG}"
build_and_push "$ROOT_DIR/services/spring-boot/billing-service" "${ECR_BILLING}:${IMAGE_TAG}"
build_and_push "$ROOT_DIR/services/spring-boot/analytics-service" "${ECR_ANALYTICS}:${IMAGE_TAG}"
build_and_push "$ROOT_DIR/services/spring-boot/notification-service" "${ECR_NOTIFICATION}:${IMAGE_TAG}"

echo "Build and push complete for image tag: $IMAGE_TAG"
