#!/usr/bin/env bash
set -euo pipefail

# Validate the Terraform-to-Helm boundary contract in read-only mode.
# If you change this contract, update docs/codebase-overview.md.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
RENDERED_VALUES="${1:-${RENDERED_VALUES:-/tmp/acmecorp-values-prod.generated.yaml}}"
TF_OUTPUT_JSON="${TF_OUTPUT_JSON:-}"

warn() {
  echo "WARN: $*" >&2
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

run_yq() {
  local expression="$1"
  local file_path="$2"

  if command -v yq >/dev/null 2>&1; then
    yq "$expression" "$file_path"
    return
  fi

  require_cmd docker
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "${file_path}:${file_path}:ro" \
    mikefarah/yq:4 \
    "$expression" "$file_path"
}

read_rendered_value() {
  local path="$1"
  local file_path="$2"
  local value

  value="$(run_yq "$path" "$file_path" 2>/dev/null || true)"
  value="${value//$'\r'/}"
  value="${value//$'\n'/}"
  printf '%s\n' "$value"
}

is_placeholder_or_example() {
  local value="$1"
  [[ "$value" == *"example.com"* ]] && return 0
  [[ "$value" == *"PLACEHOLDER"* ]] && return 0
  [[ "$value" == *"<REPLACE"* ]] && return 0
  [[ "$value" == *"REPLACE_ME"* ]] && return 0
  case "$value" in
    \<*\>) return 0 ;;
  esac
  return 1
}

require_rendered_value() {
  local path="$1"
  local file_path="$2"
  local check_name="$3"
  local value

  value="$(read_rendered_value "$path" "$file_path")"
  if [[ -z "$value" || "$value" == "null" ]]; then
    fail "rendered values check failed: ${check_name} is empty at ${path}"
  fi
  if is_placeholder_or_example "$value"; then
    fail "rendered values check failed: ${check_name} contains a placeholder/example value at ${path}: ${value}"
  fi
}

require_equal() {
  local check_name="$1"
  local left="$2"
  local right="$3"
  if [[ "$left" != "$right" ]]; then
    fail "${check_name} mismatch: expected '${right}' but got '${left}'"
  fi
}

require_cmd jq

TF_JSON=""
if [[ -n "$TF_OUTPUT_JSON" ]]; then
  [[ -f "$TF_OUTPUT_JSON" ]] || fail "terraform output json file not found: $TF_OUTPUT_JSON"
  TF_JSON="$(cat "$TF_OUTPUT_JSON")"
elif command -v terraform >/dev/null 2>&1 && [[ -d "$TF_DIR" ]]; then
  if TF_JSON="$(terraform -chdir="$TF_DIR" output -json 2>/dev/null)"; then
    :
  else
    warn "terraform output -json is unavailable from $TF_DIR; skipping live Terraform output checks"
    TF_JSON=""
  fi
else
  warn "terraform not available; skipping live Terraform output checks"
fi

if [[ -n "$TF_JSON" ]]; then
  for key in \
    aws_region \
    name_prefix \
    app_namespace \
    observability_namespace \
    external_secrets_namespace \
    gateway_ingress_host \
    grafana_ingress_host \
    gateway_certificate_arn \
    grafana_certificate_arn \
    aurora_endpoint \
    mq_broker_endpoint \
    ecr_repository_urls
  do
    jq -er --arg key "$key" '.[$key].value' <<<"$TF_JSON" >/dev/null \
      || fail "terraform output missing required boundary key: $key"
  done
fi

[[ -f "$RENDERED_VALUES" ]] || fail "rendered values file not found: $RENDERED_VALUES"

require_rendered_value '.global.awsRegion' "$RENDERED_VALUES" 'global.awsRegion'
require_rendered_value '.global.secretsNamePrefix' "$RENDERED_VALUES" 'global.secretsNamePrefix'
require_rendered_value '.global.namespaces.app' "$RENDERED_VALUES" 'global.namespaces.app'
require_rendered_value '.global.namespaces.observability' "$RENDERED_VALUES" 'global.namespaces.observability'
require_rendered_value '.global.namespaces.externalSecrets' "$RENDERED_VALUES" 'global.namespaces.externalSecrets'
require_rendered_value '."gateway-service".ingress.host' "$RENDERED_VALUES" 'gateway ingress host'
require_rendered_value '.grafana.ingress.host' "$RENDERED_VALUES" 'grafana ingress host'
require_rendered_value '."gateway-service".ingress.tls.certificateArn' "$RENDERED_VALUES" 'gateway certificate ARN'
require_rendered_value '.grafana.ingress.annotations."alb.ingress.kubernetes.io/certificate-arn"' "$RENDERED_VALUES" 'grafana certificate ARN'
require_rendered_value '.global.aurora.host' "$RENDERED_VALUES" 'Aurora host'
require_rendered_value '.global.mq.host' "$RENDERED_VALUES" 'MQ host'

if [[ -n "$TF_JSON" ]]; then
  TF_AWS_REGION="$(jq -er '.aws_region.value' <<<"$TF_JSON")"
  TF_NAME_PREFIX="$(jq -er '.name_prefix.value' <<<"$TF_JSON")"
  TF_APP_NAMESPACE="$(jq -er '.app_namespace.value' <<<"$TF_JSON")"
  TF_OBSERVABILITY_NAMESPACE="$(jq -er '.observability_namespace.value' <<<"$TF_JSON")"
  TF_EXTERNAL_SECRETS_NAMESPACE="$(jq -er '.external_secrets_namespace.value' <<<"$TF_JSON")"
  TF_GATEWAY_HOST="$(jq -er '.gateway_ingress_host.value' <<<"$TF_JSON")"
  TF_GRAFANA_HOST="$(jq -er '.grafana_ingress_host.value' <<<"$TF_JSON")"

  require_equal "aws region alignment" "$(read_rendered_value '.global.awsRegion' "$RENDERED_VALUES")" "$TF_AWS_REGION"
  require_equal "secret prefix alignment" "$(read_rendered_value '.global.secretsNamePrefix' "$RENDERED_VALUES")" "$TF_NAME_PREFIX"
  require_equal "app namespace alignment" "$(read_rendered_value '.global.namespaces.app' "$RENDERED_VALUES")" "$TF_APP_NAMESPACE"
  require_equal "observability namespace alignment" "$(read_rendered_value '.global.namespaces.observability' "$RENDERED_VALUES")" "$TF_OBSERVABILITY_NAMESPACE"
  require_equal "external-secrets namespace alignment" "$(read_rendered_value '.global.namespaces.externalSecrets' "$RENDERED_VALUES")" "$TF_EXTERNAL_SECRETS_NAMESPACE"
  require_equal "gateway host alignment" "$(read_rendered_value '."gateway-service".ingress.host' "$RENDERED_VALUES")" "$TF_GATEWAY_HOST"
  require_equal "grafana host alignment" "$(read_rendered_value '.grafana.ingress.host' "$RENDERED_VALUES")" "$TF_GRAFANA_HOST"
fi

echo "Boundary contract validation passed: $RENDERED_VALUES"
