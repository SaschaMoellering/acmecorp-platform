#!/usr/bin/env bash
set -euo pipefail

# Run tests in a containerized workspace copied to /tmp so host repo stays clean.
# If a local JDK is available (e.g. SDKMAN), set USE_LOCAL_JAVA=1 to use it.

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
copy_reports="${COPY_TEST_REPORTS:-}"
artifacts_root="${repo_root}/artifacts/test-reports/jdk${version}"

use_local="${USE_LOCAL_JAVA:-}"
sdkman_home="${SDKMAN_DIR:-$HOME/.sdkman}"
sdkman_java="${sdkman_home}/candidates/java/${version}.0.0-tem"
if [[ -z "${use_local}" ]]; then
  if [[ -n "${JAVA_HOME:-}" ]]; then
    use_local="1"
  elif [[ -d "${sdkman_java}" ]]; then
    use_local="1"
  elif [[ -d "/usr/lib/jvm/java-${version}-openjdk-amd64" ]]; then
    use_local="1"
  fi
fi

if [[ "${use_local}" == "1" ]]; then
  if [[ -d "${sdkman_java}" ]]; then
    export JAVA_HOME="${sdkman_java}"
  elif [[ -d "/usr/lib/jvm/java-${version}-openjdk-amd64" ]]; then
    export JAVA_HOME="/usr/lib/jvm/java-${version}-openjdk-amd64"
  fi
  if [[ -n "${JAVA_HOME:-}" ]]; then
    export PATH="${JAVA_HOME}/bin:${PATH}"
  fi
  echo "Using local Java at ${JAVA_HOME:-<auto>}"
  java -version
  (cd "${repo_root}" && make test-backend)
  exit 0
fi

docker volume create "${cache_volume}" >/dev/null

docker_args=(--rm -t)
docker_args+=(-v "${repo_root}:/repo:ro")
docker_args+=(-v "${cache_volume}:/m2")
docker_args+=(-e MAVEN_OPTS="-Dmaven.repo.local=/m2")
if [[ -n "${copy_reports}" && -d "${repo_root}/artifacts" ]]; then
  docker_args+=(-v "${repo_root}/artifacts:/artifacts")
fi

echo "Running backend build + tests in ${image}"
docker run "${docker_args[@]}" \
  "${image}" \
  bash -lc "command -v make >/dev/null || (apt-get update && apt-get install -y make); \
    rm -rf '${workspace_dir}'; mkdir -p '${workspace_dir}'; \
    tar --exclude=.git -C /repo -cf - . | tar -xf - -C '${workspace_dir}'; \
    cd '${workspace_dir}'; \
    make build-backend && make test-backend; \
    if [[ -n '${copy_reports}' && -d /artifacts ]]; then \
      mkdir -p /artifacts/test-reports/jdk${version}; \
      find services -type d \\( -name surefire-reports -o -name failsafe-reports -o -name quarkus-test-reports \\) \
        -exec sh -lc 'dest=/artifacts/test-reports/jdk${version}/\$1; mkdir -p \"\${dest}\"; cp -a \"\$1\"/* \"\${dest}\" 2>/dev/null || true' _ {} \\;; \
    fi"
