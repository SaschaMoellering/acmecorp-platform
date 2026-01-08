#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TIMEOUT_SECONDS=180
DEFAULT_INTERVAL_SECONDS=2

TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-${1:-$DEFAULT_TIMEOUT_SECONDS}}
INTERVAL_SECONDS=${INTERVAL_SECONDS:-${2:-$DEFAULT_INTERVAL_SECONDS}}
BASE_URL=${BASE_URL:-http://localhost:8080}

SERVICES=(
  "gateway-service|$BASE_URL/actuator/health"
  "orders-service|${BASE_URL/8080/8081}/actuator/health"
  "billing-service|${BASE_URL/8080/8082}/actuator/health"
  "notification-service|${BASE_URL/8080/8083}/actuator/health"
  "analytics-service|${BASE_URL/8080/8084}/actuator/health"
  "catalog-service|${BASE_URL/8080/8085}/actuator/health"
)

check_health() {
  local url=$1
  if response=$(curl -fsS "$url" 2>/dev/null); then
    printf '%s' "$response" | python3 - <<'PY'
import json
import sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)
if data.get("status") != "UP":
    sys.exit(1)
PY
    return 0
  fi
  return 1
}

print_diagnostics() {
  echo "[diagnostics] docker compose status" >&2
  if command -v docker >/dev/null 2>&1; then
    if [ -f infra/local/docker-compose.yml ]; then
      (cd infra/local && docker compose ps) || true
      (cd infra/local && docker compose logs --tail 200) || true
    else
      echo "[diagnostics] infra/local/docker-compose.yml not found" >&2
    fi
  else
    echo "[diagnostics] docker not available" >&2
  fi
}

for entry in "${SERVICES[@]}"; do
  name=${entry%%|*}
  url=${entry##*|}
  echo "[wait] $name -> $url"
  start=$(date +%s)

  while true; do
    if check_health "$url"; then
      echo "READY: $name"
      break
    fi

    if (( $(date +%s) - start >= TIMEOUT_SECONDS )); then
      echo "[timeout] $name not healthy at $url after ${TIMEOUT_SECONDS}s" >&2
      print_diagnostics
      exit 1
    fi

    sleep "$INTERVAL_SECONDS"
  done
done
