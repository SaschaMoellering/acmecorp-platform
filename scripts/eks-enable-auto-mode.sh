#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-tf}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
ENVIRONMENT="${ENVIRONMENT:-}"
CLUSTER_PREFIX="${CLUSTER_PREFIX:-acmecorp}"
CLUSTER_NAME="${CLUSTER_NAME:-}"

export AWS_PROFILE
export AWS_SDK_LOAD_CONFIG=1

if [[ -z "${CLUSTER_NAME}" ]]; then
  if [[ -z "${ENVIRONMENT}" ]]; then
    echo "Set CLUSTER_NAME or ENVIRONMENT to derive it." >&2
    echo "Example: ENVIRONMENT=dev ./scripts/eks-enable-auto-mode.sh" >&2
    exit 1
  fi
  CLUSTER_NAME="${CLUSTER_PREFIX}-${ENVIRONMENT}"
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found in PATH." >&2
  exit 1
fi

aws eks put-cluster-config \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --compute-config enabled=true

echo "Requested EKS Auto Mode enablement for ${CLUSTER_NAME} in ${AWS_REGION}"
