#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-tf}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
export AWS_PROFILE
export AWS_SDK_LOAD_CONFIG=1

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found in PATH." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found in PATH." >&2
  exit 1
fi

aws sso login --profile "${AWS_PROFILE}" --use-device-code --no-browser

account_id="$(aws sts get-caller-identity --query Account --output text --profile "${AWS_PROFILE}")"
registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "${AWS_REGION}" --profile "${AWS_PROFILE}" \
  | docker login --username AWS --password-stdin "${registry}"

echo "Logged in to ${registry}"
