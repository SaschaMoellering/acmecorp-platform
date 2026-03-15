#!/usr/bin/env bash
set -euo pipefail

# Finalize Route53 alias records after the first Helm deployment has created ALB-backed ingresses.
# Inputs:
# - working kubeconfig for the target EKS cluster
# - terraform.tfvars in infra/terraform
# Output:
# - second terraform apply with gateway/grafana ALB DNS names and hosted zone IDs

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
TF_VARS_FILE="${TF_VARS_FILE:-terraform.tfvars}"
AWS_REGION="${AWS_REGION:-}"
RELEASE_NAME="${RELEASE_NAME:-acmecorp-platform}"
GATEWAY_NAMESPACE="${GATEWAY_NAMESPACE:-acmecorp}"
GRAFANA_NAMESPACE="${GRAFANA_NAMESPACE:-observability}"
GATEWAY_INGRESS_NAME="${GATEWAY_INGRESS_NAME:-${RELEASE_NAME}-gateway-service-ingress}"
GRAFANA_INGRESS_NAME="${GRAFANA_INGRESS_NAME:-grafana}"

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
require_cmd kubectl
require_cmd terraform

if [[ -z "$AWS_REGION" ]]; then
  AWS_REGION="$(terraform -chdir="$TF_DIR" console <<'EOF' | tr -d '\r'
var.aws_region
EOF
)"
  AWS_REGION="${AWS_REGION//\"/}"
fi

require_value "aws_region" "$AWS_REGION"

GATEWAY_ALB_DNS="$(kubectl get ingress "$GATEWAY_INGRESS_NAME" -n "$GATEWAY_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
GRAFANA_ALB_DNS="$(kubectl get ingress "$GRAFANA_INGRESS_NAME" -n "$GRAFANA_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

require_value "gateway ingress ALB hostname" "$GATEWAY_ALB_DNS"
require_value "grafana ingress ALB hostname" "$GRAFANA_ALB_DNS"

lookup_zone_id() {
  local dns_name="$1"
  aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --query "LoadBalancers[?DNSName=='${dns_name}'].CanonicalHostedZoneId | [0]" \
    --output text
}

GATEWAY_ALB_ZONE_ID="$(lookup_zone_id "$GATEWAY_ALB_DNS")"
GRAFANA_ALB_ZONE_ID="$(lookup_zone_id "$GRAFANA_ALB_DNS")"

require_value "gateway ALB hosted zone ID" "$GATEWAY_ALB_ZONE_ID"
require_value "grafana ALB hosted zone ID" "$GRAFANA_ALB_ZONE_ID"

terraform -chdir="$TF_DIR" apply -var-file="$TF_VARS_FILE" \
  -var="gateway_alb_dns_name=${GATEWAY_ALB_DNS}" \
  -var="gateway_alb_zone_id=${GATEWAY_ALB_ZONE_ID}" \
  -var="grafana_alb_dns_name=${GRAFANA_ALB_DNS}" \
  -var="grafana_alb_zone_id=${GRAFANA_ALB_ZONE_ID}"
