#!/usr/bin/env bash
set -euo pipefail

# Run builds in a containerized workspace copied to /tmp so host repo stays clean.

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
workspace_dir="/tmp/workspace"

docker volume create "${cache_volume}" >/dev/null

docker_args=(--rm -t)
docker_args+=(-v "${repo_root}:/repo:ro")
docker_args+=(-v "${cache_volume}:/m2")
docker_args+=(-e MAVEN_OPTS="-Dmaven.repo.local=/m2")

echo "Running backend build in ${image}"
docker run "${docker_args[@]}" \
  "${image}" \
  bash -lc "command -v make >/dev/null || (apt-get update && apt-get install -y make); \
    rm -rf '${workspace_dir}'; mkdir -p '${workspace_dir}'; \
    tar --exclude=.git -C /repo -cf - . | tar -xf - -C '${workspace_dir}'; \
    cd '${workspace_dir}'; \
    make build-backend"
