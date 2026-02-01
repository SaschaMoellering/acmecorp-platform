#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="${COMPOSE_DIR:-$ROOT_DIR/infra/local}"
COMPOSE_FILE="${COMPOSE_FILE:-$COMPOSE_DIR/docker-compose.yml}"
export COMPOSE_PARALLEL_LIMIT="${COMPOSE_PARALLEL_LIMIT:-1}"

# Let users override, but default to the internal DNS name + port from compose network
GATEWAY_URL="${GATEWAY_URL:-http://gateway-service:8080}"

# Timeouts / polling
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

# Curl image version pin (reproducible)
CURL_IMAGE="${CURL_IMAGE:-curlimages/curl:8.6.0}"

# Maven runner (pin + reproducible)
MAVEN_IMAGE="${MAVEN_IMAGE:-maven:3.9.9-eclipse-temurin-21}"

# Optional: reuse local Maven cache (saves lots of time)
M2_DIR="${M2_DIR:-$HOME/.m2}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose is required (plugin or standalone)" >&2
  exit 1
fi

usage() {
  cat <<EOF
Usage: $(basename "$0")

Runs infra/local docker compose and executes integration tests from inside the compose network.

Env overrides:
  COMPOSE_DIR        (default: $COMPOSE_DIR)
  COMPOSE_FILE       (default: $COMPOSE_FILE)
  GATEWAY_URL        (default: $GATEWAY_URL)
  TIMEOUT_SECONDS    (default: $TIMEOUT_SECONDS)
  SLEEP_SECONDS      (default: $SLEEP_SECONDS)
  CURL_IMAGE         (default: $CURL_IMAGE)
  MAVEN_IMAGE        (default: $MAVEN_IMAGE)
  M2_DIR             (default: $M2_DIR)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Best-effort teardown; never mask the test result.
TEST_RC=0
cleanup() {
  echo "[teardown] docker compose down (best-effort; may require docker socket access)"
  (cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE" down) || true
  exit "$TEST_RC"
}
trap cleanup EXIT

echo "[setup] docker compose up -d --build"
(cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE" up -d --build)

# Discover compose network name dynamically (avoid hardcoding *_default)
# Pick the first network from the project (usually "<project>_default")
echo "[setup] discovering compose network..."
NETWORK_NAME="$(
  cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE" ps -q \
    | head -n 1 \
    | xargs -r docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}' \
    | head -n 1
)"

if [[ -z "${NETWORK_NAME:-}" ]]; then
  echo "[error] could not determine compose network name" >&2
  echo "[debug] docker compose ps:" >&2
  (cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE" ps) || true
  exit 1
fi

echo "[setup] using network: $NETWORK_NAME"

# Helper: run curl inside network
curl_in_net() {
  local url="$1"
  docker run --rm --network "$NETWORK_NAME" "$CURL_IMAGE" -fsS "$url"
}

# Helper: wait until an endpoint returns expected content (or just 200 if no matcher)
wait_for() {
  local name="$1"
  local url="$2"
  local matcher="${3:-}" # optional grep -E pattern
  local start_ts
  start_ts="$(date +%s)"

  echo "[wait] $name: $url"
  while true; do
    if [[ -z "$matcher" ]]; then
      if curl_in_net "$url" >/dev/null 2>&1; then
        return 0
      fi
    else
      # fetch body and match semantics
      if curl_in_net "$url" 2>/dev/null | grep -Eq "$matcher"; then
        return 0
      fi
    fi

    if (( "$(date +%s)" - start_ts >= TIMEOUT_SECONDS )); then
      echo "[error] timeout waiting for $name ($url)" >&2
      echo "[debug] docker compose ps:" >&2
      (cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE" ps) || true
      echo "[debug] last logs (gateway-service):" >&2
      (cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE" logs --tail=200 gateway-service) || true
      return 1
    fi
    sleep "$SLEEP_SECONDS"
  done
}

# 1) Spring readiness endpoint should be UP
wait_for "readiness" "${GATEWAY_URL}/actuator/health/readiness" '"status"\s*:\s*"UP"'

# 2) System status endpoint should be READY or UP (accept both)
wait_for "system status" "${GATEWAY_URL}/api/gateway/system/status" '(READY|UP)'

echo "[test] integration tests (in-network)"
# Run Maven inside network; mount repo read-only, but allow Maven cache write if present
# If M2_DIR doesn't exist, skip cache mount.
M2_MOUNT_ARGS=()
if [[ -d "$M2_DIR" ]]; then
  M2_MOUNT_ARGS=(-v "$M2_DIR:/root/.m2")
fi

set +e
docker run --rm --network "$NETWORK_NAME" \
  -e ACMECORP_BASE_URL="$GATEWAY_URL" \
  -v "$ROOT_DIR:/repo:ro" \
  "${M2_MOUNT_ARGS[@]}" \
  -w /repo/integration-tests \
  "$MAVEN_IMAGE" \
  mvn -q test
TEST_RC=$?
set -e

# cleanup trap will exit with TEST_RC
