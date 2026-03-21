#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a fresh EKS cluster so the canonical umbrella release can install cleanly.
# This prepares kubeconfig, namespaces, and External Secrets CRDs/operator ahead of
# the main app Helm release.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
CHART_DIR="${CHART_DIR:-$ROOT_DIR/helm/acmecorp-platform}"
EXTERNAL_SECRETS_CHART_DIR="${EXTERNAL_SECRETS_CHART_DIR:-$CHART_DIR/charts/external-secrets}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"

section() {
  printf '\n==> %s\n' "$1"
}

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
require_cmd helm
require_cmd kubectl
require_cmd terraform

section "Resolve Cluster Settings"
CLUSTER_NAME="$(terraform -chdir="$TF_DIR" output -raw cluster_name)"
AWS_REGION="$(terraform -chdir="$TF_DIR" console <<'EOF' | tr -d '\r'
var.aws_region
EOF
)"
AWS_REGION="${AWS_REGION//\"/}"

require_value "cluster_name" "$CLUSTER_NAME"
require_value "aws_region" "$AWS_REGION"

echo "Cluster: $CLUSTER_NAME"
echo "Region:  $AWS_REGION"

section "Update Kubeconfig"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

section "Update Helm Dependencies"
helm dependency update "$CHART_DIR"

section "Create Required Namespaces"
helm template acmecorp-platform "$CHART_DIR" \
  --show-only templates/namespaces/namespaces.yaml \
  | kubectl apply -f -

section "Create Auto Mode StorageClass"
helm template acmecorp-platform "$CHART_DIR" \
  --show-only templates/storage-class.yaml \
  | kubectl apply -f -

section "Install External Secrets Operator"
helm upgrade --install external-secrets "$EXTERNAL_SECRETS_CHART_DIR" \
  -n external-secrets \
  --create-namespace \
  --set "global.awsRegion=${AWS_REGION}"

section "Wait For External Secrets Rollout"
kubectl rollout status deploy/external-secrets -n external-secrets --timeout="$ROLLOUT_TIMEOUT"

section "Verify External Secrets CRDs"
for crd_name in \
  externalsecrets.external-secrets.io \
  secretstores.external-secrets.io \
  clustersecretstores.external-secrets.io
do
  kubectl get crd "$crd_name" >/dev/null
  echo "Verified CRD: $crd_name"
done

section "Bootstrap Complete"
echo "Fresh-cluster bootstrap completed successfully."
