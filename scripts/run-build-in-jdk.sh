#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <11|17|21|25>" >&2
  exit 2
fi

version="$1"
case "$version" in
  11|17|21|25) ;;
  *)
    echo "Unsupported JDK version: ${version}. Expected 11, 17, 21, or 25." >&2
    exit 2
    ;;
esac

image="maven:3.9.9-eclipse-temurin-${version}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cache_volume="acmecorp-m2-cache-${version}"

docker volume create "${cache_volume}" >/dev/null

echo "Running backend build in ${image}"
docker run --rm -t \
  -v "${repo_root}:/workspace" \
  -v "${cache_volume}:/workspace/.m2" \
  -w /workspace \
  -e MAVEN_OPTS="-Dmaven.repo.local=/workspace/.m2" \
  "${image}" \
  bash -lc "command -v make >/dev/null || (apt-get update && apt-get install -y make); make build-backend"
