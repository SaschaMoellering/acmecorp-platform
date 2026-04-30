#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

warn() {
  echo "WARN: $*" >&2
}

run_step() {
  local label="$1"
  shift
  echo "==> $label"
  "$@"
}

echo "Repository validation started"

mapfile -t shell_scripts < <(find scripts -type f -name '*.sh' | sort)
if (( ${#shell_scripts[@]} > 0 )); then
  run_step "bash syntax: scripts" bash -n "${shell_scripts[@]}"
fi

if command -v terraform >/dev/null 2>&1; then
  run_step "terraform fmt check" terraform -chdir=infra/terraform fmt -check -recursive
else
  warn "terraform not found; skipping terraform fmt check"
fi

if command -v helm >/dev/null 2>&1; then
  echo "==> helm template"
  helm template acmecorp-platform helm/acmecorp-platform --namespace acmecorp -f helm/acmecorp-platform/values.yaml >/dev/null
else
  warn "helm not found; skipping helm template"
fi

if [[ -x scripts/validate-boundary-contract.sh ]]; then
  if [[ -f /tmp/acmecorp-values-prod.generated.yaml ]]; then
    run_step "boundary contract validation" scripts/validate-boundary-contract.sh /tmp/acmecorp-values-prod.generated.yaml
  else
    warn "rendered values file not found at /tmp/acmecorp-values-prod.generated.yaml; skipping boundary contract validation"
  fi
else
  warn "scripts/validate-boundary-contract.sh is not executable; skipping boundary contract validation"
fi

echo "Repository validation completed"
