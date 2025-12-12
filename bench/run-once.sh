#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"
RESULT_BASE="$ROOT_DIR/bench/results"

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

start_ts=$(date +%s)
health_url="http://localhost:8080/api/gateway/status"
timeout=$((start_ts + 120))
ready_ts=""
echo "Waiting for gateway health at $health_url ..."
while [[ $(date +%s) -lt $timeout ]]; do
  if curl -fsS "$health_url" >/dev/null; then
    ready_ts=$(date +%s)
    break
  fi
  sleep 2
done

if [[ -z "$ready_ts" ]]; then
  echo "Gateway health check failed to become ready within timeout" >&2
  exit 1
fi

startup_seconds=$((ready_ts - start_ts))
echo "Gateway ready after ${startup_seconds}s"

sleep 5
containers_file="$("$ROOT_DIR/bench/collect.sh" "$RESULT_DIR")"
containers_data="$(cat "$containers_file")"

summary_json="$RESULT_DIR/summary.json"
cat <<EOF > "$summary_json"
{
  "timestamp": "${timestamp}",
  "startup_time_seconds": ${startup_seconds},
  "health_endpoint": "${health_url}",
  "containers": ${containers_data}
}
EOF

summary_md="$RESULT_DIR/summary.md"
cat <<EOF > "$summary_md"
# Benchmark summary: ${timestamp}

Startup time: ${startup_seconds}s
Health endpoint: ${health_url}

Containers:
${containers_data}
EOF

echo "Benchmark results written to $RESULT_DIR"
