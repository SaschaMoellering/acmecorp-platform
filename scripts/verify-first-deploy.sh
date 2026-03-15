#!/usr/bin/env bash
set -euo pipefail

# Verify the first AWS deployment end to end.
# Inputs:
# - working kubeconfig for the target EKS cluster
# - reachable public ingress hosts after DNS alias creation
# Output:
# - concise PASS/FAIL summary and non-zero exit on any failed check

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
AWS_REGION="${AWS_REGION:-}"
TIMEOUT="${TIMEOUT:-300s}"

PASS_COUNT=0
FAIL_COUNT=0

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $1"
}

check_cmd() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

require_cmd kubectl
require_cmd curl
require_cmd jq

if [[ -z "$AWS_REGION" ]]; then
  require_cmd terraform
  AWS_REGION="$(terraform -chdir="$TF_DIR" console <<'EOF' | tr -d '\r'
var.aws_region
EOF
)"
  AWS_REGION="${AWS_REGION//\"/}"
fi

check_cmd "namespace acmecorp exists" kubectl get ns acmecorp
check_cmd "namespace observability exists" kubectl get ns observability
check_cmd "namespace data exists" kubectl get ns data
check_cmd "namespace external-secrets exists" kubectl get ns external-secrets

rollout_by_label() {
  local namespace="$1"
  local app_name="$2"
  local deploy_name
  deploy_name="$(kubectl get deploy -n "$namespace" -l "app.kubernetes.io/name=${app_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -n "$deploy_name" ]] || return 1
  kubectl rollout status "deploy/${deploy_name}" -n "$namespace" --timeout="$TIMEOUT"
}

check_cmd "external-secrets deployment rolled out" rollout_by_label external-secrets external-secrets
check_cmd "gateway-service deployment rolled out" rollout_by_label acmecorp gateway-service
check_cmd "orders-service deployment rolled out" rollout_by_label acmecorp orders-service
check_cmd "billing-service deployment rolled out" rollout_by_label acmecorp billing-service
check_cmd "notification-service deployment rolled out" rollout_by_label acmecorp notification-service
check_cmd "analytics-service deployment rolled out" rollout_by_label acmecorp analytics-service
check_cmd "catalog-service deployment rolled out" rollout_by_label acmecorp catalog-service
check_cmd "grafana deployment rolled out" rollout_by_label observability grafana
check_cmd "prometheus deployment rolled out" rollout_by_label observability prometheus
check_cmd "redis stateful workload exists" kubectl get statefulset -n data redis

check_cmd "gateway-service service account exists" kubectl get sa gateway-service -n acmecorp
check_cmd "orders-service service account exists" kubectl get sa orders-service -n acmecorp
check_cmd "catalog-service service account exists" kubectl get sa catalog-service -n acmecorp
check_cmd "billing-service service account exists" kubectl get sa billing-service -n acmecorp
check_cmd "analytics-service service account exists" kubectl get sa analytics-service -n acmecorp
check_cmd "notification-service service account exists" kubectl get sa notification-service -n acmecorp
check_cmd "grafana service account exists" kubectl get sa grafana -n observability
check_cmd "external-secrets service account exists" kubectl get sa external-secrets -n external-secrets

check_cmd "ClusterSecretStore aws-secrets-manager exists" kubectl get clustersecretstore aws-secrets-manager
check_cmd "ExternalSecret aurora-credentials exists" kubectl get externalsecret aurora-credentials -n acmecorp
check_cmd "ExternalSecret mq-credentials exists" kubectl get externalsecret mq-credentials -n acmecorp
check_cmd "ExternalSecret redis-credentials exists" kubectl get externalsecret redis-credentials -n data
check_cmd "ExternalSecret grafana-credentials exists" kubectl get externalsecret grafana-credentials -n observability
check_cmd "Secret aurora-credentials exists" kubectl get secret aurora-credentials -n acmecorp
check_cmd "Secret mq-credentials exists" kubectl get secret mq-credentials -n acmecorp
check_cmd "Secret redis-credentials exists" kubectl get secret redis-credentials -n data
check_cmd "Secret grafana-credentials exists" kubectl get secret grafana-credentials -n observability

GATEWAY_HOST="$(kubectl get ingress -n acmecorp -o jsonpath='{.items[?(@.metadata.name=="acmecorp-platform-gateway-service-ingress")].spec.rules[0].host}' 2>/dev/null || true)"
GRAFANA_HOST="$(kubectl get ingress grafana -n observability -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"

if [[ -n "$GATEWAY_HOST" ]]; then
  if curl -fsSI "https://${GATEWAY_HOST}" >/dev/null 2>&1; then
    pass "gateway ingress responds over HTTPS"
  else
    fail "gateway ingress responds over HTTPS"
  fi
else
  fail "gateway ingress host resolved from Kubernetes"
fi

if [[ -n "$GRAFANA_HOST" ]]; then
  if curl -fsSI "https://${GRAFANA_HOST}/login" >/dev/null 2>&1; then
    pass "grafana ingress responds over HTTPS"
  else
    fail "grafana ingress responds over HTTPS"
  fi
else
  fail "grafana ingress host resolved from Kubernetes"
fi

PROM_PORT_FORWARD_LOG="$(mktemp)"
kubectl port-forward -n observability svc/prometheus 19090:9090 >"$PROM_PORT_FORWARD_LOG" 2>&1 &
PORT_FORWARD_PID=$!
cleanup() {
  kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
  rm -f "$PROM_PORT_FORWARD_LOG"
}
trap cleanup EXIT
sleep 3

if curl -fsS "http://127.0.0.1:19090/api/v1/targets" >/tmp/acmecorp-prom-targets.json 2>/dev/null; then
  if jq -e '.data.activeTargets | length > 0' /tmp/acmecorp-prom-targets.json >/dev/null 2>&1; then
    pass "Prometheus has active scrape targets"
  else
    fail "Prometheus has active scrape targets"
  fi
else
  fail "Prometheus API reachable via port-forward"
fi

echo
echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
  exit 1
fi
