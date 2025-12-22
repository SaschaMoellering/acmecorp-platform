#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-${ROOT_DIR}/infra/terraform}"
BACKEND_FILE="${BACKEND_FILE:-${TF_DIR}/backend.hcl}"

AWS_PROFILE="${AWS_PROFILE:-tf}"
export AWS_PROFILE
export AWS_SDK_LOAD_CONFIG=1
AWS_REGION="${AWS_REGION:-eu-west-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
export AWS_REGION
export AWS_DEFAULT_REGION

TERRAFORM_BIN="${TERRAFORM_BIN:-}"
if [[ -z "${TERRAFORM_BIN}" ]]; then
  if command -v terraform >/dev/null 2>&1; then
    TERRAFORM_BIN="$(command -v terraform)"
  else
    echo "terraform not found in PATH." >&2
    echo "PATH=${PATH}" >&2
    echo "" >&2
    echo "Install Terraform on Ubuntu (HashiCorp apt repo):" >&2
    echo "  sudo apt-get update" >&2
    echo "  sudo apt-get install -y gnupg software-properties-common curl" >&2
    echo "  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg" >&2
    echo "  echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list" >&2
    echo "  sudo apt-get update && sudo apt-get install -y terraform" >&2
    echo "" >&2
    echo "If you use tfenv:" >&2
    echo "  tfenv install <version> && tfenv use <version>" >&2
    echo "" >&2
    echo "If Terraform is installed but not on PATH, set TERRAFORM_BIN or fix PATH." >&2
    echo "Example: TERRAFORM_BIN=/usr/local/bin/terraform ./scripts/tf.sh init" >&2
    exit 127
  fi
fi

if [[ ! -x "${TERRAFORM_BIN}" ]]; then
  echo "Terraform binary not executable: ${TERRAFORM_BIN}" >&2
  exit 127
fi

if ! "${TERRAFORM_BIN}" version >/dev/null 2>&1; then
  echo "Terraform found but failed to execute: ${TERRAFORM_BIN}" >&2
  echo "PATH=${PATH}" >&2
  echo "If PATH differs in this shell, try: TERRAFORM_BIN=\"$(command -v terraform)\" ./scripts/tf.sh init" >&2
  exit 127
fi

cmd="${1:-}"
if [[ -z "${cmd}" ]]; then
  echo "Usage: scripts/tf.sh <init|plan|apply|destroy> [extra terraform args]" >&2
  exit 1
fi
shift || true

case "${cmd}" in
  init)
    aws sso login --profile "${AWS_PROFILE}" --use-device-code --no-browser
    "${TERRAFORM_BIN}" -chdir="${TF_DIR}" init -reconfigure -upgrade -backend-config="${BACKEND_FILE}" "$@"
    ;;
  plan)
    "${TERRAFORM_BIN}" -chdir="${TF_DIR}" plan "$@"
    ;;
  apply)
    "${TERRAFORM_BIN}" -chdir="${TF_DIR}" apply "$@"
    ;;
  destroy)
    "${TERRAFORM_BIN}" -chdir="${TF_DIR}" destroy "$@"
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    exit 1
    ;;
esac
