#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/infra/local/docker-compose.yml}"
NETWORK_NAME="${NETWORK_NAME:-acmecorp-local_default}"
GATEWAY_URL="${GATEWAY_URL:-http://gateway-service:8080}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

cleanup() {
  echo "[teardown] docker compose down (may require docker socket access)"
  (cd "$ROOT_DIR/infra/local" && docker compose down) || true
}
trap cleanup EXIT

echo "[setup] docker compose up --build"
(cd "$ROOT_DIR/infra/local" && docker compose up -d --build)

echo "[wait] readiness from inside network: ${GATEWAY_URL}/actuator/health/readiness"
start_ts="$(date +%s)"
while true; do
  if docker run --rm --network "$NETWORK_NAME" curlimages/curl:8.6.0 \
    -fsS "${GATEWAY_URL}/actuator/health/readiness" >/dev/null 2>&1; then
    break
  fi
  if (( $(date +%s) - start_ts >= TIMEOUT_SECONDS )); then
    echo "timeout waiting for readiness via ${GATEWAY_URL}" >&2
    exit 1
  fi
  sleep 2
done

echo "[wait] system status from inside network: ${GATEWAY_URL}/api/gateway/system/status"
start_ts="$(date +%s)"
while true; do
  if docker run --rm --network "$NETWORK_NAME" curlimages/curl:8.6.0 \
    -fsS "${GATEWAY_URL}/api/gateway/system/status" >/dev/null 2>&1; then
    break
  fi
  if (( $(date +%s) - start_ts >= TIMEOUT_SECONDS )); then
    echo "timeout waiting for system status via ${GATEWAY_URL}" >&2
    exit 1
  fi
  sleep 2
done

echo "[test] integration tests in network"
docker run --rm --network "$NETWORK_NAME" \
  -e ACMECORP_BASE_URL="${GATEWAY_URL}" \
  -v "$ROOT_DIR:/repo:ro" \
  -w /repo/integration-tests \
  maven:3.9.9-eclipse-temurin-21 \
  mvn -q test
