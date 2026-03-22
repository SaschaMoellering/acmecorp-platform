#!/usr/bin/env bash
set -euo pipefail

SECRET_NAMES=(
  "acmecorp-platform-prod/aurora"
  "acmecorp-platform-prod/mq"
  "acmecorp-platform-prod/redis"
  "acmecorp-platform-prod/grafana"
)

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

restore_if_pending_deletion() {
  local secret_name="$1"
  local deleted_date

  echo "Checking secret: $secret_name"

  if ! deleted_date="$(aws secretsmanager describe-secret \
    --secret-id "$secret_name" \
    --query 'DeletedDate' \
    --output text 2>&1)"; then
    if [[ "$deleted_date" == *"ResourceNotFoundException"* ]]; then
      echo "  Not found. Nothing to restore."
      return
    fi

    echo "ERROR: failed to inspect secret $secret_name" >&2
    echo "$deleted_date" >&2
    exit 1
  fi

  if [[ "$deleted_date" == "None" ]]; then
    echo "  Present and active. Nothing to do."
    return
  fi

  echo "  Pending deletion since $deleted_date. Restoring."
  aws secretsmanager restore-secret --secret-id "$secret_name" >/dev/null
  echo "  Restored."
}

require_cmd aws

for secret_name in "${SECRET_NAMES[@]}"; do
  restore_if_pending_deletion "$secret_name"
done
