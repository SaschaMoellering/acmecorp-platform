#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
CHART_DIR="${CHART_DIR:-$ROOT_DIR/helm/acmecorp-platform}"
WEBAPP_DIR="${WEBAPP_DIR:-$ROOT_DIR/webapp}"
TF_VARS_FILE="${TF_VARS_FILE:-terraform.tfvars}"
PUBLIC_HOSTED_ZONE_NAME="${PUBLIC_HOSTED_ZONE_NAME:-acmecorp.autoscaling.io}"
GATEWAY_INGRESS_HOST="${GATEWAY_INGRESS_HOST:-api.${PUBLIC_HOSTED_ZONE_NAME}}"
GRAFANA_INGRESS_HOST="${GRAFANA_INGRESS_HOST:-grafana.${PUBLIC_HOSTED_ZONE_NAME}}"
UI_SUBDOMAIN="${UI_SUBDOMAIN:-app}"
AWS_PROFILE="${AWS_PROFILE:-tf}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
CLUSTER_NAME="${CLUSTER_NAME:-acmecorp-platform}"
HELM_RELEASE="${HELM_RELEASE:-acmecorp-platform}"
NAMESPACE_APP="${NAMESPACE_APP:-acmecorp}"
NAMESPACE_OBS="${NAMESPACE_OBS:-observability}"
NAMESPACE_DATA="${NAMESPACE_DATA:-data}"
NAMESPACE_EXTERNAL_SECRETS="${NAMESPACE_EXTERNAL_SECRETS:-external-secrets}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
SKIP_SSO_LOGIN="${SKIP_SSO_LOGIN:-false}"
SKIP_UI_DEPLOY="${SKIP_UI_DEPLOY:-false}"
SKIP_CLOUDFRONT_INVALIDATION="${SKIP_CLOUDFRONT_INVALIDATION:-false}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-600s}"
NODE_READY_TIMEOUT="${NODE_READY_TIMEOUT:-20m}"
INGRESS_TIMEOUT_SECONDS="${INGRESS_TIMEOUT_SECONDS:-900}"
PUBLIC_DNS_WAIT_TIMEOUT="${PUBLIC_DNS_WAIT_TIMEOUT:-300}"
HTTP_READY_TIMEOUT="${HTTP_READY_TIMEOUT:-180}"
PROD_VALUES_PATH="${PROD_VALUES_PATH:-/tmp/acmecorp-values-prod.generated.yaml}"
IMAGE_TAG="${IMAGE_TAG:-prod-$(date -u +%Y%m%d%H%M%S)}"

export AWS_PROFILE
export AWS_REGION
export TF_DIR
export TF_VARS_FILE
export RELEASE_NAME="$HELM_RELEASE"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

section() {
  printf '\n[%s] ==> %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

die() {
  log "ERROR: $*"
  exit 1
}

on_error() {
  local exit_code="$1"
  local line_no="$2"
  log "ERROR: setup-prod.sh failed at line ${line_no} with exit code ${exit_code}."
  exit "$exit_code"
}

trap 'on_error $? $LINENO' ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || die "required file not found: $path"
}

normalize_dns_name() {
  local value="${1:-}"
  value="${value%.}"
  printf '%s\n' "${value,,}"
}

resolve_tf_vars_path() {
  if [[ "$TF_VARS_FILE" = /* ]]; then
    printf '%s\n' "$TF_VARS_FILE"
    return
  fi

  printf '%s\n' "$TF_DIR/$TF_VARS_FILE"
}

tf_apply_args=()
if [[ "$AUTO_APPROVE" == "true" ]]; then
  tf_apply_args+=(-auto-approve)
fi

warn_namespace_override_limitations() {
  if [[ "$NAMESPACE_APP" != "acmecorp" || "$NAMESPACE_OBS" != "observability" || "$NAMESPACE_DATA" != "data" || "$NAMESPACE_EXTERNAL_SECRETS" != "external-secrets" ]]; then
    log "WARNING: this chart still hardcodes some namespaces. Non-default namespace overrides are not fully supported and this setup path assumes the repo defaults."
  fi
}

ensure_tooling() {
  section "Validate Local Tooling"
  require_cmd aws
  require_cmd curl
  require_cmd docker
  require_cmd dig
  require_cmd helm
  require_cmd jq
  require_cmd kubectl
  require_cmd terraform
  if [[ "$SKIP_UI_DEPLOY" != "true" ]]; then
    require_cmd npm
  fi
  require_file "$ROOT_DIR/scripts/restore-secrets-if-pending-deletion.sh"
  require_file "$ROOT_DIR/scripts/build-and-push-ecr.sh"
  require_file "$ROOT_DIR/scripts/render-prod-values.sh"
  require_file "$ROOT_DIR/scripts/validate-deploy.sh"
  require_file "$ROOT_DIR/scripts/bootstrap-first-cluster.sh"
  require_file "$ROOT_DIR/scripts/finalize-alb-dns.sh"
  require_file "$ROOT_DIR/scripts/deploy-ui.sh"
  require_file "$CHART_DIR/values.yaml"
  require_file "$CHART_DIR/values-prod.yaml"
  require_file "$WEBAPP_DIR/package.json"
  log "Tooling and required repo scripts are present."
}

ensure_aws_session() {
  section "Check AWS Credentials"
  if aws sts get-caller-identity >/dev/null 2>&1; then
    log "AWS session is active for profile ${AWS_PROFILE}."
    return
  fi

  if [[ "$SKIP_SSO_LOGIN" == "true" ]]; then
    die "AWS credentials are not active and SKIP_SSO_LOGIN=true."
  fi

  log "AWS session is not active. Running aws sso login for profile ${AWS_PROFILE}."
  aws sso login --profile "$AWS_PROFILE"
  aws sts get-caller-identity >/dev/null 2>&1 || die "AWS credentials are still unavailable after aws sso login."
}

upsert_tfvar() {
  local file_path="$1"
  local key="$2"
  local rendered_value="$3"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v key="$key" -v value="$rendered_value" '
    BEGIN { replaced = 0 }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      if (!replaced) {
        print key " = " value
        replaced = 1
      }
      next
    }
    { print }
    END {
      if (!replaced) {
        print key " = " value
      }
    }
  ' "$file_path" >"$tmp_file"
  mv "$tmp_file" "$file_path"
}

tfvar_key_present() {
  local file_path="$1"
  local key="$2"
  awk -v key="$key" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" { found = 1 } END { exit(found ? 0 : 1) }' "$file_path"
}

read_tfvar_string() {
  local file_path="$1"
  local key="$2"

  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      line = $0
      sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "", line)
      sub(/[[:space:]]*(#.*)?$/, "", line)
      if (line ~ /^".*"$/) {
        sub(/^"/, "", line)
        sub(/"$/, "", line)
      }
      print line
      exit
    }
  ' "$file_path"
}

ensure_tfvar_matches() {
  local file_path="$1"
  local key="$2"
  local expected="$3"
  local existing

  if ! tfvar_key_present "$file_path" "$key"; then
    upsert_tfvar "$file_path" "$key" "\"${expected}\""
    return
  fi

  existing="$(read_tfvar_string "$file_path" "$key")"
  if [[ -n "$existing" && "$existing" != "$expected" ]]; then
    die "existing ${key} in ${file_path} is '${existing}', but this run expects '${expected}'. Align TF_VARS_FILE or override the environment explicitly."
  fi
}

ensure_tfvars() {
  local tf_vars_path="$1"

  section "Prepare Terraform Variables"
  mkdir -p "$(dirname "$tf_vars_path")"

  if [[ ! -f "$tf_vars_path" ]]; then
    cat >"$tf_vars_path" <<EOF
# Generated by scripts/setup-prod.sh for delegated-subdomain production deploys.
aws_region = "${AWS_REGION}"
cluster_name = "${CLUSTER_NAME}"
public_hosted_zone_name = "${PUBLIC_HOSTED_ZONE_NAME}"
gateway_ingress_host = "${GATEWAY_INGRESS_HOST}"
grafana_ingress_host = "${GRAFANA_INGRESS_HOST}"
ui_subdomain = "${UI_SUBDOMAIN}"
enable_grafana_dns = true
EOF
    log "Created Terraform vars file: $tf_vars_path"
    return
  fi

  ensure_tfvar_matches "$tf_vars_path" "aws_region" "$AWS_REGION"
  ensure_tfvar_matches "$tf_vars_path" "cluster_name" "$CLUSTER_NAME"
  upsert_tfvar "$tf_vars_path" "public_hosted_zone_name" "\"${PUBLIC_HOSTED_ZONE_NAME}\""
  upsert_tfvar "$tf_vars_path" "gateway_ingress_host" "\"${GATEWAY_INGRESS_HOST}\""
  upsert_tfvar "$tf_vars_path" "grafana_ingress_host" "\"${GRAFANA_INGRESS_HOST}\""
  upsert_tfvar "$tf_vars_path" "ui_subdomain" "\"${UI_SUBDOMAIN}\""
  upsert_tfvar "$tf_vars_path" "enable_grafana_dns" "true"
  log "Ensured delegated-zone settings are present in $tf_vars_path without rewriting unrelated Terraform settings."
}

run_terraform_apply() {
  local tf_vars_path="$1"

  section "Terraform Init And Apply"
  terraform -chdir="$TF_DIR" init
  terraform -chdir="$TF_DIR" apply -input=false "${tf_apply_args[@]}" -var-file="$tf_vars_path"
}

update_kubeconfig() {
  section "Update Kubeconfig"
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
  log "Updated kubeconfig for cluster ${CLUSTER_NAME}."
}

wait_for_cluster() {
  section "Wait For EKS Cluster"
  aws eks wait cluster-active --region "$AWS_REGION" --name "$CLUSTER_NAME"

  local attempt
  for attempt in {1..60}; do
    if kubectl cluster-info >/dev/null 2>&1; then
      break
    fi
    sleep 10
  done

  kubectl cluster-info >/dev/null 2>&1 || die "kubectl could not reach the EKS cluster."
  kubectl wait --for=condition=Ready node --all --timeout="$NODE_READY_TIMEOUT"
  log "Cluster is reachable and all nodes are Ready."
}

bootstrap_cluster() {
  section "Bootstrap First Cluster"
  ROLLOUT_TIMEOUT="$ROLLOUT_TIMEOUT" RELEASE_NAME="$HELM_RELEASE" "$ROOT_DIR/scripts/bootstrap-first-cluster.sh"
}

build_and_push_images() {
  section "Build And Push Backend Images"
  IMAGE_TAG="$IMAGE_TAG" AWS_REGION="$AWS_REGION" "$ROOT_DIR/scripts/build-and-push-ecr.sh" "$IMAGE_TAG"
}

render_prod_values() {
  section "Render Production Helm Values"
  IMAGE_TAG="$IMAGE_TAG" AWS_REGION="$AWS_REGION" "$ROOT_DIR/scripts/render-prod-values.sh" "$PROD_VALUES_PATH" "$IMAGE_TAG"
  [[ -f "$PROD_VALUES_PATH" ]] || die "rendered production values file was not created: $PROD_VALUES_PATH"
  log "Rendered values file: $PROD_VALUES_PATH"
}

validate_deploy_inputs() {
  section "Validate Deployment Inputs"
  PROD_VALUES="$PROD_VALUES_PATH" IMAGE_TAG="$IMAGE_TAG" RELEASE_NAME="$HELM_RELEASE" RELEASE_NAMESPACE="$NAMESPACE_APP" TF_VARS_FILE="$TF_VARS_FILE" "$ROOT_DIR/scripts/validate-deploy.sh"
}

install_or_upgrade_release() {
  section "Install Or Upgrade Helm Release"
  helm dependency update "$CHART_DIR"
  helm upgrade --install "$HELM_RELEASE" "$CHART_DIR" \
    --namespace "$NAMESPACE_APP" \
    --create-namespace \
    -f "$CHART_DIR/values.yaml" \
    -f "$PROD_VALUES_PATH"
}

wait_for_rollout() {
  local kind="$1"
  local name="$2"
  local namespace="$3"
  kubectl rollout status "${kind}/${name}" -n "$namespace" --timeout="$ROLLOUT_TIMEOUT"
}

wait_for_workloads() {
  section "Wait For Workloads"
  wait_for_rollout deployment external-secrets "$NAMESPACE_EXTERNAL_SECRETS"
  wait_for_rollout deployment "${HELM_RELEASE}-gateway-service" "$NAMESPACE_APP"
  wait_for_rollout deployment "${HELM_RELEASE}-orders-service" "$NAMESPACE_APP"
  wait_for_rollout deployment "${HELM_RELEASE}-billing-service" "$NAMESPACE_APP"
  wait_for_rollout deployment "${HELM_RELEASE}-notification-service" "$NAMESPACE_APP"
  wait_for_rollout deployment "${HELM_RELEASE}-analytics-service" "$NAMESPACE_APP"
  wait_for_rollout deployment "${HELM_RELEASE}-catalog-service" "$NAMESPACE_APP"
  wait_for_rollout deployment grafana "$NAMESPACE_OBS"
  wait_for_rollout statefulset prometheus "$NAMESPACE_OBS"
  wait_for_rollout statefulset redis "$NAMESPACE_DATA"
  log "Core platform workloads are healthy."
}

wait_for_ingress_hostname() {
  local ingress_name="$1"
  local namespace="$2"
  local timeout_seconds="$3"
  local elapsed=0
  local hostname=""

  while (( elapsed < timeout_seconds )); do
    hostname="$(kubectl get ingress "$ingress_name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    if [[ -n "$hostname" ]]; then
      printf '%s\n' "$hostname"
      return
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done

  die "ingress ${namespace}/${ingress_name} did not receive an ALB hostname within ${timeout_seconds}s."
}

detect_route53_drift_and_finalize() {
  section "Finalize ALB Route53 Aliases"
  local gateway_ingress_name="${HELM_RELEASE}-gateway-service-ingress"
  local grafana_ingress_name="grafana"
  local gateway_alb
  local grafana_alb
  local zone_id
  local gateway_host
  local grafana_host
  local current_gateway_target
  local current_grafana_target
  local gateway_match=false
  local grafana_match=false

  gateway_alb="$(wait_for_ingress_hostname "$gateway_ingress_name" "$NAMESPACE_APP" "$INGRESS_TIMEOUT_SECONDS")"
  grafana_alb="$(wait_for_ingress_hostname "$grafana_ingress_name" "$NAMESPACE_OBS" "$INGRESS_TIMEOUT_SECONDS")"
  IFS='|' read -r zone_id gateway_host grafana_host <<<"$(get_dns_context "$(get_tf_output_json)")"

  current_gateway_target="$(lookup_alias_target "$zone_id" "$gateway_host")"
  current_grafana_target="$(lookup_alias_target "$zone_id" "$grafana_host")"

  log "Gateway ALB hostname: $gateway_alb"
  log "Grafana ALB hostname: $grafana_alb"

  if [[ "$(normalize_dns_name "$current_gateway_target")" == "$(normalize_dns_name "$gateway_alb")" ]]; then
    gateway_match=true
  else
    log "Route53 alias for ${gateway_host} points to ${current_gateway_target}, will update to ${gateway_alb}."
  fi

  if [[ "$(normalize_dns_name "$current_grafana_target")" == "$(normalize_dns_name "$grafana_alb")" ]]; then
    grafana_match=true
  else
    log "Route53 alias for ${grafana_host} points to ${current_grafana_target}, will update to ${grafana_alb}."
  fi

  if [[ "$gateway_match" == "true" && "$grafana_match" == "true" ]]; then
    log "Route53 aliases already match the current ALBs. Skipping the second Terraform apply."
  else
    AUTO_APPROVE="$AUTO_APPROVE" \
    AWS_REGION="$AWS_REGION" \
    RELEASE_NAME="$HELM_RELEASE" \
    TF_VARS_FILE="$TF_VARS_FILE" \
    GATEWAY_NAMESPACE="$NAMESPACE_APP" \
    GRAFANA_NAMESPACE="$NAMESPACE_OBS" \
    "$ROOT_DIR/scripts/finalize-alb-dns.sh"
  fi

  verify_dns_aliases "$gateway_alb" "$grafana_alb"
}

lookup_alias_target() {
  local zone_id="$1"
  local record_name="$2"

  aws route53 list-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --query "ResourceRecordSets[?Type=='A' && Name=='${record_name}.'].AliasTarget.DNSName | [0]" \
    --output text
}

get_tf_output_json() {
  terraform -chdir="$TF_DIR" output -json
}

get_dns_context() {
  local tf_output_json="$1"
  local zone_id
  local gateway_host
  local grafana_host

  zone_id="$(jq -r '.route53_zone_id.value // empty' <<<"$tf_output_json")"
  gateway_host="$(jq -r '.gateway_ingress_host.value // empty' <<<"$tf_output_json")"
  grafana_host="$(jq -r '.grafana_ingress_host.value // empty' <<<"$tf_output_json")"

  [[ -n "$zone_id" ]] || die "terraform output route53_zone_id is required for Route53 alias verification."
  [[ -n "$gateway_host" ]] || die "terraform output gateway_ingress_host is required for Route53 alias verification."
  [[ -n "$grafana_host" ]] || die "terraform output grafana_ingress_host is required for Route53 alias verification."

  printf '%s|%s|%s\n' "$zone_id" "$gateway_host" "$grafana_host"
}

get_ip_set_via_dig() {
  local resolver="$1"
  local record_name="$2"
  local record_type="$3"

  dig @"$resolver" +short "$record_name" "$record_type" | awk 'NF { print $1 }' | sort -u
}

get_ip_set_via_local_resolver() {
  local record_name="$1"
  local record_type="$2"

  dig +short "$record_name" "$record_type" | awk 'NF { print $1 }' | sort -u
}

public_dns_matches() {
  local resolver="$1"
  local alias_host="$2"
  local alb_host="$3"
  local alias_a
  local alb_a

  alias_a="$(get_ip_set_via_dig "$resolver" "$alias_host" A)"
  alb_a="$(get_ip_set_via_dig "$resolver" "$alb_host" A)"

  [[ -n "$alias_a" && "$alias_a" == "$alb_a" ]]
}

wait_for_public_dns_match() {
  local resolver="$1"
  local alias_host="$2"
  local alb_host="$3"
  local timeout_seconds="$4"
  local elapsed=0

  while (( elapsed < timeout_seconds )); do
    if public_dns_matches "$resolver" "$alias_host" "$alb_host"; then
      return 0
    fi

    sleep 10
    elapsed=$((elapsed + 10))
  done

  return 1
}

check_local_dns_cache_mismatch() {
  local host="$1"
  local local_dns
  local public_dns

  local_dns="$(get_ip_set_via_local_resolver "$host" A)"
  public_dns="$(get_ip_set_via_dig "1.1.1.1" "$host" A)"

  if [[ -n "$local_dns" && -n "$public_dns" && "$local_dns" != "$public_dns" ]]; then
    log "Local DNS resolver differs from public DNS for ${host}."
    log "Local resolver A records: ${local_dns}"
    log "Public resolver A records: ${public_dns}"
    log "This is likely a router cache (e.g. FritzBox). Use resolvectl or override DNS for testing."
  fi
}

get_first_public_ip() {
  local host="$1"
  local ip

  ip="$(get_ip_set_via_dig "1.1.1.1" "$host" A | head -n 1)"
  if [[ -n "$ip" ]]; then
    printf '%s\n' "$ip"
    return
  fi

  ip="$(get_ip_set_via_dig "8.8.8.8" "$host" A | head -n 1)"
  if [[ -n "$ip" ]]; then
    printf '%s\n' "$ip"
    return
  fi

  return 1
}

verify_dns_aliases() {
  section "Verify Route53 Aliases"
  local gateway_alb="$1"
  local grafana_alb="$2"
  local zone_id
  local gateway_host
  local grafana_host
  local gateway_target
  local grafana_target
  local normalized_gateway_alb
  local normalized_grafana_alb
  local gateway_cf_ok=false
  local gateway_google_ok=false
  local grafana_cf_ok=false
  local grafana_google_ok=false
  local public_ok_count

  IFS='|' read -r zone_id gateway_host grafana_host <<<"$(get_dns_context "$(get_tf_output_json)")"

  gateway_target="$(lookup_alias_target "$zone_id" "$gateway_host")"
  grafana_target="$(lookup_alias_target "$zone_id" "$grafana_host")"
  normalized_gateway_alb="$(normalize_dns_name "$gateway_alb")"
  normalized_grafana_alb="$(normalize_dns_name "$grafana_alb")"

  if [[ "$(normalize_dns_name "$gateway_target")" != "$normalized_gateway_alb" ]]; then
    die "Route53 alias for ${gateway_host} still points to ${gateway_target}, expected ${gateway_alb}."
  fi
  if [[ "$(normalize_dns_name "$grafana_target")" != "$normalized_grafana_alb" ]]; then
    die "Route53 alias for ${grafana_host} still points to ${grafana_target}, expected ${grafana_alb}."
  fi

  log "Authoritative Route53 aliases match the current ALBs."
  log "Public DNS propagation can lag behind Route53 state, so the next check uses 1.1.1.1 and 8.8.8.8 instead of trusting the local resolver cache."

  check_local_dns_cache_mismatch "$gateway_host"
  check_local_dns_cache_mismatch "$grafana_host"

  wait_for_public_dns_match "1.1.1.1" "$gateway_host" "$gateway_alb" "$PUBLIC_DNS_WAIT_TIMEOUT" && gateway_cf_ok=true
  wait_for_public_dns_match "8.8.8.8" "$gateway_host" "$gateway_alb" "$PUBLIC_DNS_WAIT_TIMEOUT" && gateway_google_ok=true
  public_ok_count=0
  [[ "$gateway_cf_ok" == "true" ]] && public_ok_count=$((public_ok_count + 1))
  [[ "$gateway_google_ok" == "true" ]] && public_ok_count=$((public_ok_count + 1))
  if (( public_ok_count == 0 )); then
    die "public DNS for ${gateway_host} does not match the current ALB via 1.1.1.1 or 8.8.8.8."
  elif (( public_ok_count == 1 )); then
    log "WARNING: public DNS for ${gateway_host} matches only one public resolver, so propagation is still ongoing."
  else
    log "Public DNS for ${gateway_host} matches the current ALB via both 1.1.1.1 and 8.8.8.8."
  fi

  wait_for_public_dns_match "1.1.1.1" "$grafana_host" "$grafana_alb" "$PUBLIC_DNS_WAIT_TIMEOUT" && grafana_cf_ok=true
  wait_for_public_dns_match "8.8.8.8" "$grafana_host" "$grafana_alb" "$PUBLIC_DNS_WAIT_TIMEOUT" && grafana_google_ok=true
  public_ok_count=0
  [[ "$grafana_cf_ok" == "true" ]] && public_ok_count=$((public_ok_count + 1))
  [[ "$grafana_google_ok" == "true" ]] && public_ok_count=$((public_ok_count + 1))
  if (( public_ok_count == 0 )); then
    die "public DNS for ${grafana_host} does not match the current ALB via 1.1.1.1 or 8.8.8.8."
  elif (( public_ok_count == 1 )); then
    log "WARNING: public DNS for ${grafana_host} matches only one public resolver, so propagation is still ongoing."
  else
    log "Public DNS for ${grafana_host} matches the current ALB via both 1.1.1.1 and 8.8.8.8."
  fi
}

http_probe() {
  local url="$1"
  local timeout_seconds="$2"
  local description="$3"
  local elapsed=0

  while (( elapsed < timeout_seconds )); do
    if curl -fsS --max-time 10 -o /dev/null "$url" >/dev/null 2>&1; then
      log "${description}: OK (${url})"
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done

  log "WARNING: ${description} did not respond successfully within ${timeout_seconds}s: ${url}"
  return 1
}

curl_with_public_dns() {
  local host="$1"
  shift
  local ip

  ip="$(get_first_public_ip "$host")" || die "could not resolve ${host} via public resolvers 1.1.1.1 or 8.8.8.8."
  curl --resolve "${host}:443:${ip}" "$@"
}

wait_for_https_ready() {
  local host="$1"
  local timeout_seconds="$2"
  local elapsed=0

  while (( elapsed < timeout_seconds )); do
    if curl_with_public_dns "$host" -k -sS -I --max-time 10 "https://${host}" >/dev/null 2>&1; then
      log "HTTPS endpoint is reachable via public DNS: https://${host}"
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done

  die "HTTPS endpoint did not become reachable within ${timeout_seconds}s via public DNS: https://${host}"
}

validate_ui_api_base_url() {
  local expected_api_base="$1"
  local env_file="$WEBAPP_DIR/.env.production"

  [[ -f "$env_file" ]] || die "missing UI production env file: $env_file"

  if ! grep -Fxq "VITE_API_BASE_URL=${expected_api_base}" "$env_file"; then
    die "UI production config does not match expected API base URL. Expected VITE_API_BASE_URL=${expected_api_base} in ${env_file}."
  fi

  if ! grep -R -Fq "${expected_api_base}" "$WEBAPP_DIR/dist/assets"; then
    die "built UI bundle does not embed the expected API base URL ${expected_api_base}."
  fi

  log "UI build config uses the expected API base URL: ${expected_api_base}"
}

validate_gateway_functional_endpoint() {
  local gateway_host="$1"
  local status_body

  status_body="$(curl_with_public_dns "$gateway_host" -fsS --max-time 15 "https://${gateway_host}/api/gateway/system/status")" || die "gateway functional endpoint failed: https://${gateway_host}/api/gateway/system/status"
  [[ -n "$status_body" ]] || die "gateway functional endpoint returned an empty response: https://${gateway_host}/api/gateway/system/status"
  jq -e '
    type == "array" and
    length > 0 and
    (map(.service) | index("orders-service")) != null and
    (map(.service) | index("catalog-service")) != null and
    (map(.service) | index("billing-service")) != null and
    (map(.service) | index("notification-service")) != null and
    (map(.service) | index("analytics-service")) != null and
    all(.[]; .status == "OK")
  ' <<<"$status_body" >/dev/null || die "gateway system status did not report all expected downstream services as OK: https://${gateway_host}/api/gateway/system/status"
  log "Gateway functional endpoint returned expected downstream services with OK status."
}

validate_gateway_cors_for_ui() {
  local gateway_host="$1"
  local ui_url="$2"
  local response_headers
  local status_code
  local allow_origin

  response_headers="$(curl_with_public_dns "$gateway_host" -sS -D - -o /dev/null -X OPTIONS "https://${gateway_host}/api/gateway/tools/seed" \
    -H "Origin: ${ui_url}" \
    -H "Access-Control-Request-Method: POST")" || die "gateway CORS preflight failed to execute against https://${gateway_host}/api/gateway/tools/seed"

  status_code="$(awk 'toupper($1) ~ /^HTTP\// { code=$2 } END { print code }' <<<"$response_headers")"
  allow_origin="$(awk -F': ' 'tolower($1) == "access-control-allow-origin" { gsub(/\r/, "", $2); print $2; exit }' <<<"$response_headers")"

  [[ "$status_code" == "200" ]] || die "gateway CORS preflight returned HTTP ${status_code}, expected 200."
  [[ -n "$allow_origin" ]] || die "gateway CORS preflight did not return Access-Control-Allow-Origin."
  [[ "$allow_origin" == "$ui_url" ]] || die "gateway CORS preflight returned Access-Control-Allow-Origin=${allow_origin}, expected ${ui_url}."
  log "Gateway CORS preflight accepts the canonical UI origin."
}

post_deploy_validation() {
  section "Post-Deploy Validation"
  local tf_output_json
  local gateway_host
  local ui_url
  local ui_cloudfront_url
  local expected_api_base

  tf_output_json="$(get_tf_output_json)"
  gateway_host="$(jq -r '.gateway_ingress_host.value // empty' <<<"$tf_output_json")"
  ui_url="$(jq -r '.ui_custom_url.value // empty' <<<"$tf_output_json")"
  ui_cloudfront_url="$(jq -r '.ui_cloudfront_url.value // empty' <<<"$tf_output_json")"

  [[ -n "$gateway_host" ]] || die "terraform output gateway_ingress_host is required for post-deploy validation."
  [[ -n "$ui_url" ]] || die "terraform output ui_custom_url is required for post-deploy validation."

  wait_for_https_ready "$gateway_host" "$HTTP_READY_TIMEOUT"
  wait_for_https_ready "${ui_url#https://}" "$HTTP_READY_TIMEOUT"

  expected_api_base="https://${gateway_host}"
  validate_gateway_functional_endpoint "$gateway_host"
  validate_gateway_cors_for_ui "$gateway_host" "$ui_url"

  if [[ "$SKIP_UI_DEPLOY" != "true" ]]; then
    validate_ui_api_base_url "$expected_api_base"
  fi

  log "Canonical UI URL: ${ui_url}"
  if [[ -n "$ui_cloudfront_url" ]]; then
    log "Raw CloudFront URL (debug only): ${ui_cloudfront_url}"
    log "Do NOT use CloudFront domain for production access due to CORS."
  fi
}

deploy_ui() {
  if [[ "$SKIP_UI_DEPLOY" == "true" ]]; then
    section "Skip UI Deployment"
    log "Skipping UI build and deploy because SKIP_UI_DEPLOY=true."
    return
  fi

  section "Build And Deploy UI"
  TF_DIR="$TF_DIR" \
  WEBAPP_DIR="$WEBAPP_DIR" \
  SKIP_CLOUDFRONT_INVALIDATION="$SKIP_CLOUDFRONT_INVALIDATION" \
  "$ROOT_DIR/scripts/deploy-ui.sh"
}

print_summary() {
  section "Deployment Summary"
  local tf_output_json
  local gateway_host
  local grafana_host
  local ui_url
  local ui_bucket
  local ui_cloudfront_url

  tf_output_json="$(get_tf_output_json)"
  gateway_host="$(jq -r '.gateway_ingress_host.value // empty' <<<"$tf_output_json")"
  grafana_host="$(jq -r '.grafana_ingress_host.value // empty' <<<"$tf_output_json")"
  ui_url="$(jq -r '.ui_custom_url.value // empty' <<<"$tf_output_json")"
  ui_bucket="$(jq -r '.ui_bucket_name.value // empty' <<<"$tf_output_json")"
  ui_cloudfront_url="$(jq -r '.ui_cloudfront_url.value // empty' <<<"$tf_output_json")"

  log "Image tag deployed: $IMAGE_TAG"
  [[ -n "$gateway_host" ]] && log "Gateway URL: https://${gateway_host}"
  [[ -n "$grafana_host" ]] && log "Grafana URL: https://${grafana_host}"
  [[ -n "$ui_url" ]] && log "UI URL: $ui_url"
  [[ -n "$ui_bucket" ]] && log "UI bucket: s3://${ui_bucket}"
  [[ -n "$ui_cloudfront_url" ]] && log "CloudFront URL (debug only): ${ui_cloudfront_url}"
  if [[ -n "$ui_url" ]]; then
    log "Use the UI alias domain above for production testing. Do not treat the raw CloudFront hostname as the canonical UI origin."
  fi

  printf '\nUseful follow-up checks:\n'
  printf '  kubectl get pods -A\n'
  printf '  kubectl get ingress -A\n'
  printf '  terraform -chdir=%q output\n' "$TF_DIR"
  if [[ -n "$gateway_host" ]]; then
    printf '  curl -i https://%s/actuator/health\n' "$gateway_host"
    printf '  curl -i https://%s/api/gateway/system/status\n' "$gateway_host"
    printf '  curl -i -X OPTIONS https://%s/api/gateway/tools/seed -H %q -H %q\n' "$gateway_host" "Origin: ${ui_url}" "Access-Control-Request-Method: POST"
  fi
  if [[ -n "$ui_url" ]]; then
    printf '  curl -I %s\n' "$ui_url"
  fi
}

main() {
  local tf_vars_path
  tf_vars_path="$(resolve_tf_vars_path)"

  warn_namespace_override_limitations
  ensure_tooling
  ensure_aws_session

  section "Restore Pending-Deletion Secrets"
  "$ROOT_DIR/scripts/restore-secrets-if-pending-deletion.sh"

  ensure_tfvars "$tf_vars_path"
  run_terraform_apply "$tf_vars_path"
  update_kubeconfig
  wait_for_cluster
  bootstrap_cluster
  build_and_push_images
  render_prod_values
  validate_deploy_inputs
  install_or_upgrade_release
  wait_for_workloads
  detect_route53_drift_and_finalize
  deploy_ui
  post_deploy_validation
  print_summary
}

main "$@"
