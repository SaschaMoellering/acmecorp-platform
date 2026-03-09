#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"
RESULT_BASE="$ROOT_DIR/bench/results"
HEALTH_URL="${HEALTH_URL:-http://localhost:8080/api/gateway/status}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-120}"
HEALTH_POLL_INTERVAL_SECONDS="${HEALTH_POLL_INTERVAL_SECONDS:-0.10}"
ORDERS_STARTUP_URL="${ORDERS_STARTUP_URL:-http://localhost:8081/api/orders/startup}"

for cmd in docker curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "required command '$cmd' is missing" >&2
    exit 1
  fi
done

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "docker-compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
RESULT_DIR="$RESULT_BASE/$timestamp"
mkdir -p "$RESULT_DIR"

function cleanup() {
  echo "Tearing down docker-compose stack..."
  docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting docker compose stack..."
docker compose -f "$COMPOSE_FILE" up --build -d

start_ts=$(date +%s%3N)
timeout_ms=$((start_ts + (HEALTH_TIMEOUT_SECONDS * 1000)))
ready_ts=""
echo "Waiting for gateway health at $HEALTH_URL ..."
while [[ $(date +%s%3N) -lt $timeout_ms ]]; do
  if curl -fsS "$HEALTH_URL" >/dev/null; then
    ready_ts=$(date +%s%3N)
    break
  fi
  sleep "$HEALTH_POLL_INTERVAL_SECONDS"
done

if [[ -z "$ready_ts" ]]; then
  echo "Gateway health check failed to become ready within timeout" >&2
  exit 1
fi

startup_ms=$((ready_ts - start_ts))
startup_seconds="$(awk "BEGIN { printf \"%.3f\", ${startup_ms}/1000 }")"
echo "Gateway ready after ${startup_seconds}s"

sleep 5
containers_file="$("$ROOT_DIR/bench/collect.sh" "$RESULT_DIR")"
containers_data="$(cat "$containers_file")"
startup_trace_file="$RESULT_DIR/orders-startup.json"
if ! curl -fsS "$ORDERS_STARTUP_URL" >"$startup_trace_file"; then
  echo "{\"error\":\"startup instrumentation unavailable\",\"url\":\"$ORDERS_STARTUP_URL\"}" >"$startup_trace_file"
fi
startup_trace_data="$(cat "$startup_trace_file")"

summary_json="$RESULT_DIR/summary.json"
cat <<EOF > "$summary_json"
{
  "timestamp": "${timestamp}",
  "startup_time_seconds": ${startup_seconds},
  "startup_time_millis": ${startup_ms},
  "health_endpoint": "${HEALTH_URL}",
  "orders_startup_trace": ${startup_trace_data},
  "containers": ${containers_data}
}
EOF

summary_md="$RESULT_DIR/summary.md"
cat <<EOF > "$summary_md"
# Benchmark summary: ${timestamp}

Startup time: ${startup_seconds}s
Startup raw: ${startup_ms} ms
Health endpoint: ${HEALTH_URL}
Orders startup trace: [orders-startup.json](orders-startup.json)

Containers:
${containers_data}
EOF

echo "Benchmark results written to $RESULT_DIR"
