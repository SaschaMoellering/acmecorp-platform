#!/usr/bin/env bash
set -euo pipefail

# Full pre-deployment validation workflow for the AWS deploy path.
# Assumes execution from repo root and a generated prod values file.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
TF_VARS_FILE="${TF_VARS_FILE:-terraform.tfvars}"
CHART_DIR="${CHART_DIR:-$ROOT_DIR/helm/acmecorp-platform}"
BASE_VALUES="${BASE_VALUES:-$CHART_DIR/values.yaml}"
PROD_VALUES="${PROD_VALUES:-/tmp/acmecorp-values-prod.generated.yaml}"
RELEASE_NAME="${RELEASE_NAME:-acmecorp-platform}"
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-acmecorp}"
RENDERED_OUTPUT="${RENDERED_OUTPUT:-/tmp/acmecorp-rendered.yaml}"
TF_PLAN_OUT="${TF_PLAN_OUT:-/tmp/acmecorp-tfplan}"
IMAGE_TAG="${IMAGE_TAG:-}"

section() {
  printf '\n==> %s\n' "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

require_file() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    echo "ERROR: required file not found: $file_path" >&2
    exit 1
  fi
}

resolve_tf_vars_file() {
  local requested_path="$1"

  if [[ "$requested_path" = /* ]]; then
    printf '%s\n' "$requested_path"
    return
  fi

  printf '%s\n' "$TF_DIR/$requested_path"
}

require_cmd terraform
require_cmd helm
require_cmd aws
require_cmd kubectl

run_kubeconform() {
  echo "Validating built-in Kubernetes resources strictly with kubeconform."
  echo "CRD-backed resources remain rendered and Helm-validated; missing CRD schemas are ignored unless schemas are provided explicitly."

  if command -v kubeconform >/dev/null 2>&1; then
    kubeconform -strict -summary -ignore-missing-schemas "$RENDERED_OUTPUT"
    return
  fi

  require_cmd docker

  docker run --rm \
    -v "${RENDERED_OUTPUT}:${RENDERED_OUTPUT}:ro" \
    ghcr.io/yannh/kubeconform:latest \
    -strict -summary -ignore-missing-schemas "$RENDERED_OUTPUT"
}

cluster_has_crd() {
  local crd_name="$1"
  kubectl get crd "$crd_name" >/dev/null 2>&1
}

require_file "$BASE_VALUES"

TF_VAR_ARGS=()
TF_VARS_PATH="$(resolve_tf_vars_file "$TF_VARS_FILE")"
if [[ -f "$TF_VARS_PATH" ]]; then
  TF_VAR_ARGS=(-var-file="$TF_VARS_PATH")
elif [[ -n "${TF_VARS_FILE:-}" && "$TF_VARS_FILE" != "terraform.tfvars" ]]; then
  echo "ERROR: requested TF_VARS_FILE not found: $TF_VARS_PATH" >&2
  exit 1
fi

if [[ ! -f "$PROD_VALUES" ]]; then
  if [[ -n "$IMAGE_TAG" ]] && terraform -chdir="$TF_DIR" output -json | jq -e 'length > 0' >/dev/null 2>&1; then
    section "Generate Production Values"
    IMAGE_TAG="$IMAGE_TAG" "$ROOT_DIR/scripts/render-prod-values.sh" "$PROD_VALUES"
  else
    section "Prepare Validation Values"
    cp "$CHART_DIR/values-prod.yaml" "$PROD_VALUES"
    echo "Using checked-in values-prod.yaml for validation because Terraform outputs are not available."
  fi
fi

section "Terraform Validation"
terraform -chdir="$TF_DIR" fmt -recursive
terraform -chdir="$TF_DIR" init
terraform -chdir="$TF_DIR" validate

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS credentials are required for terraform plan and are not available in the current environment." >&2
  exit 1
fi

terraform -chdir="$TF_DIR" plan -input=false "${TF_VAR_ARGS[@]}" -out="$TF_PLAN_OUT"

section "Helm Chart Validation"
helm lint "$CHART_DIR" -f "$BASE_VALUES" -f "$PROD_VALUES"

section "Helm Template Rendering"
helm template "$RELEASE_NAME" "$CHART_DIR" --namespace "$RELEASE_NAMESPACE" -f "$BASE_VALUES" -f "$PROD_VALUES" > "$RENDERED_OUTPUT"
echo "Rendered manifest written to $RENDERED_OUTPUT"

section "Kubernetes Manifest Validation"
run_kubeconform

section "Helm Cluster Dry-Run"
if cluster_has_crd externalsecrets.external-secrets.io && cluster_has_crd clustersecretstores.external-secrets.io; then
  helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" -n "$RELEASE_NAMESPACE" --create-namespace -f "$BASE_VALUES" -f "$PROD_VALUES" --dry-run
else
  echo "External Secrets CRDs are not registered in the target cluster yet."
  echo "On a first deployment, a server dry-run cannot validate CRD-backed resources before those CRDs exist."
  echo "Helm client dry-run is also skipped here because Helm still performs cluster capability discovery in this path."
  echo "Render validation and kubeconform already passed; rerun this script after the first install for a full cluster dry-run."
fi

section "Validation Complete"
echo "Terraform, Helm, manifest, and dry-run validation succeeded."
