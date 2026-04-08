#!/usr/bin/env bash
set -euo pipefail

# Generate a deployment-specific production values file for the canonical chart.
# Inputs:
# - Terraform outputs from infra/terraform (or TF_OUTPUT_JSON)
# - IMAGE_TAG env var or second positional argument
# Output:
# - rendered values file at the first positional argument or /tmp/acmecorp-values-prod.generated.yaml

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
BASE_VALUES="${BASE_VALUES:-$ROOT_DIR/helm/acmecorp-platform/values-prod.yaml}"
OUTPUT_PATH="${1:-${OUTPUT_PATH:-/tmp/acmecorp-values-prod.generated.yaml}}"
IMAGE_TAG="${IMAGE_TAG:-${2:-}}"
TF_OUTPUT_JSON="${TF_OUTPUT_JSON:-}"
ENV_AWS_REGION="${AWS_REGION:-${aws_region:-${AWS_REGION_OVERRIDE:-}}}"

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

normalize_host() {
  local value="$1"
  local normalized="$value"

  normalized="${normalized#*://}"
  normalized="${normalized%%/*}"
  normalized="${normalized%%:*}"

  printf '%s\n' "$normalized"
}

tf_output_value() {
  local key="$1"
  jq -er --arg key "$key" '.[$key].value' <<<"$TF_JSON"
}

tf_output_ecr() {
  local repo="$1"
  jq -er --arg repo "$repo" '.ecr_repository_urls.value[$repo]' <<<"$TF_JSON"
}

require_cmd jq

run_yq_inplace() {
  local expression="$1"
  local file_path="$2"

  if command -v yq >/dev/null 2>&1; then
    yq -i "$expression" "$file_path"
    return
  fi

  require_cmd docker

  docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e AWS_REGION \
    -e AURORA_ENDPOINT \
    -e MQ_ENDPOINT \
    -e MQ_HOST \
    -e GATEWAY_HOST \
    -e GRAFANA_HOST \
    -e UI_CUSTOM_URL \
    -e GATEWAY_CERT_ARN \
    -e GRAFANA_CERT_ARN \
    -e ECR_GATEWAY \
    -e ECR_ORDERS \
    -e ECR_CATALOG \
    -e ECR_BILLING \
    -e ECR_ANALYTICS \
    -e ECR_NOTIFICATION \
    -e IMAGE_TAG \
    -v "${file_path}:${file_path}" \
    mikefarah/yq:4 \
    -i "$expression" "$file_path"
}

if [[ -z "$IMAGE_TAG" ]]; then
  echo "ERROR: image tag is required. Pass it as IMAGE_TAG=<tag> or as the second argument." >&2
  exit 1
fi

if [[ ! -f "$BASE_VALUES" ]]; then
  echo "ERROR: base values file not found: $BASE_VALUES" >&2
  exit 1
fi

if [[ -n "$TF_OUTPUT_JSON" ]]; then
  if [[ ! -f "$TF_OUTPUT_JSON" ]]; then
    echo "ERROR: terraform output json file not found: $TF_OUTPUT_JSON" >&2
    exit 1
  fi
  TF_JSON="$(cat "$TF_OUTPUT_JSON")"
else
  TF_JSON="$(terraform -chdir="$TF_DIR" output -json)"
fi

AWS_REGION="$(tf_output_value aws_region 2>/dev/null || true)"
if [[ -z "$AWS_REGION" || "$AWS_REGION" == "null" ]]; then
  AWS_REGION="$ENV_AWS_REGION"
fi
if [[ -z "$AWS_REGION" || "$AWS_REGION" == "null" ]]; then
  AWS_REGION="$(terraform -chdir="$TF_DIR" console <<'EOF' | tr -d '\r'
var.aws_region
EOF
)"
  AWS_REGION="${AWS_REGION//\"/}"
fi

AURORA_ENDPOINT="$(tf_output_value aurora_endpoint)"
MQ_ENDPOINT="$(tf_output_value mq_broker_endpoint)"
MQ_HOST="$(normalize_host "$MQ_ENDPOINT")"
GATEWAY_HOST="$(tf_output_value gateway_ingress_host)"
GRAFANA_HOST="$(tf_output_value grafana_ingress_host)"
UI_CUSTOM_URL="$(tf_output_value ui_custom_url)"
GATEWAY_CERT_ARN="$(tf_output_value gateway_certificate_arn)"
GRAFANA_CERT_ARN="$(tf_output_value grafana_certificate_arn)"
ECR_GATEWAY="$(tf_output_ecr acmecorp/gateway-service)"
ECR_ORDERS="$(tf_output_ecr acmecorp/orders-service)"
ECR_CATALOG="$(tf_output_ecr acmecorp/catalog-service)"
ECR_BILLING="$(tf_output_ecr acmecorp/billing-service)"
ECR_ANALYTICS="$(tf_output_ecr acmecorp/analytics-service)"
ECR_NOTIFICATION="$(tf_output_ecr acmecorp/notification-service)"

require_value "aws_region" "$AWS_REGION"
require_value "aurora_endpoint" "$AURORA_ENDPOINT"
require_value "mq_broker_endpoint" "$MQ_ENDPOINT"
require_value "mq_host" "$MQ_HOST"
require_value "gateway_ingress_host" "$GATEWAY_HOST"
require_value "grafana_ingress_host" "$GRAFANA_HOST"
require_value "ui_custom_url" "$UI_CUSTOM_URL"
require_value "gateway_certificate_arn" "$GATEWAY_CERT_ARN"
require_value "grafana_certificate_arn" "$GRAFANA_CERT_ARN"
require_value "ecr_repository_urls[acmecorp/gateway-service]" "$ECR_GATEWAY"
require_value "ecr_repository_urls[acmecorp/orders-service]" "$ECR_ORDERS"
require_value "ecr_repository_urls[acmecorp/catalog-service]" "$ECR_CATALOG"
require_value "ecr_repository_urls[acmecorp/billing-service]" "$ECR_BILLING"
require_value "ecr_repository_urls[acmecorp/analytics-service]" "$ECR_ANALYTICS"
require_value "ecr_repository_urls[acmecorp/notification-service]" "$ECR_NOTIFICATION"

export AWS_REGION
export AURORA_ENDPOINT
export MQ_ENDPOINT
export MQ_HOST
export GATEWAY_HOST
export GRAFANA_HOST
export UI_CUSTOM_URL
export GATEWAY_CERT_ARN
export GRAFANA_CERT_ARN
export ECR_GATEWAY
export ECR_ORDERS
export ECR_CATALOG
export ECR_BILLING
export ECR_ANALYTICS
export ECR_NOTIFICATION
export IMAGE_TAG

cp "$BASE_VALUES" "$OUTPUT_PATH"

run_yq_inplace '
  .global.awsRegion = env(AWS_REGION) |
  .global.aurora.host = env(AURORA_ENDPOINT) |
  .global.mq.host = env(MQ_HOST) |
  .["gateway-service"].image.repository = env(ECR_GATEWAY) |
  .["gateway-service"].image.tag = env(IMAGE_TAG) |
  .["gateway-service"].image.pullPolicy = "Always" |
  .["gateway-service"].config.gatewayCorsOriginUi = env(UI_CUSTOM_URL) |
  .["gateway-service"].ingress.host = env(GATEWAY_HOST) |
  .["gateway-service"].ingress.tls.enabled = true |
  .["gateway-service"].ingress.tls.certificateArn = env(GATEWAY_CERT_ARN) |
  .["orders-service"].image.repository = env(ECR_ORDERS) |
  .["orders-service"].image.tag = env(IMAGE_TAG) |
  .["orders-service"].image.pullPolicy = "Always" |
  .["catalog-service"].image.repository = env(ECR_CATALOG) |
  .["catalog-service"].image.tag = env(IMAGE_TAG) |
  .["catalog-service"].image.pullPolicy = "Always" |
  .["billing-service"].image.repository = env(ECR_BILLING) |
  .["billing-service"].image.tag = env(IMAGE_TAG) |
  .["billing-service"].image.pullPolicy = "Always" |
  .["analytics-service"].image.repository = env(ECR_ANALYTICS) |
  .["analytics-service"].image.tag = env(IMAGE_TAG) |
  .["analytics-service"].image.pullPolicy = "Always" |
  .["notification-service"].image.repository = env(ECR_NOTIFICATION) |
  .["notification-service"].image.tag = env(IMAGE_TAG) |
  .["notification-service"].image.pullPolicy = "Always" |
  .grafana.ingress.host = env(GRAFANA_HOST) |
  .grafana.ingress.annotations."alb.ingress.kubernetes.io/certificate-arn" = env(GRAFANA_CERT_ARN)
' "$OUTPUT_PATH"

if grep -nE '<[^>]+>' "$OUTPUT_PATH" >/dev/null; then
  echo "ERROR: unresolved placeholder values remain in rendered output: $OUTPUT_PATH" >&2
  grep -nE '<[^>]+>' "$OUTPUT_PATH" >&2
  exit 1
fi

echo "Generated production values: $OUTPUT_PATH"
