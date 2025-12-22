#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_PROFILE="${AWS_PROFILE:-tf}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
ECR_REPO_NAME="${ECR_REPO_NAME:-acmecorp-platform}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-}"

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

account_id="$(aws sts get-caller-identity --query Account --output text --profile "${AWS_PROFILE}")"
registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

if ! repo_uri="$(aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" --profile "${AWS_PROFILE}" --query 'repositories[0].repositoryUri' --output text 2>/dev/null)"; then
  echo "ECR repository ${ECR_REPO_NAME} not found in ${AWS_REGION}." >&2
  echo "Create it via Terraform or run: aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION} --profile ${AWS_PROFILE}" >&2
  exit 1
fi

docker_config="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
if [[ ! -f "${docker_config}" ]] || ! grep -q "${registry}" "${docker_config}"; then
  echo "Not logged in to ${registry}. Run scripts/ecr-login.sh first." >&2
  exit 1
fi

build_dir=""
if [[ -n "${DOCKERFILE_DIR}" ]]; then
  if [[ -f "${ROOT_DIR}/${DOCKERFILE_DIR}/Dockerfile" ]]; then
    build_dir="${ROOT_DIR}/${DOCKERFILE_DIR}"
  else
    echo "Dockerfile not found in DOCKERFILE_DIR=${DOCKERFILE_DIR}" >&2
    exit 1
  fi
else
  mapfile -t dockerfiles < <(find "${ROOT_DIR}" -maxdepth 4 -name Dockerfile -print)
  if [[ "${#dockerfiles[@]}" -eq 0 ]]; then
    build_dir="${ROOT_DIR}"
  elif [[ "${#dockerfiles[@]}" -eq 1 ]]; then
    build_dir="$(dirname "${dockerfiles[0]}")"
  else
    echo "Multiple Dockerfiles found. Set DOCKERFILE_DIR to the one you want to build." >&2
    printf '%s\n' "${dockerfiles[@]}" >&2
    exit 1
  fi
fi

git_sha="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo "manual")"

docker build -t "${repo_uri}:${git_sha}" -t "${repo_uri}:latest" "${build_dir}"
docker push "${repo_uri}:${git_sha}"
docker push "${repo_uri}:latest"

echo "Pushed ${repo_uri}:${git_sha} and ${repo_uri}:latest"
