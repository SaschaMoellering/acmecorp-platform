#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TIMEOUT_SECONDS=180
DEFAULT_INTERVAL_SECONDS=2

TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-${1:-$DEFAULT_TIMEOUT_SECONDS}}
INTERVAL_SECONDS=${INTERVAL_SECONDS:-${2:-$DEFAULT_INTERVAL_SECONDS}}
BASE_URL=${BASE_URL:-http://localhost:8080}

# We assume BASE_URL points to gateway (8080). Other services are on fixed ports.
SERVICES=(
  "gateway-service|$BASE_URL/actuator/health|spring"
  "orders-service|http://localhost:8081/actuator/health|spring"
  "billing-service|http://localhost:8082/actuator/health|spring"
  "notification-service|http://localhost:8083/actuator/health|spring"
  "analytics-service|http://localhost:8084/actuator/health|spring"
  # Quarkus SmallRye Health (default)
  "catalog-service|http://localhost:8085/q/health|quarkus"
  # If you prefer readiness semantics:
  # "catalog-service|http://localhost:8085/q/health/ready|quarkus"
)

check_health() {
  local url="$1"
  local kind="${2:-auto}"

  local response
  if ! response="$(curl -fsS "$url" 2>/dev/null)"; then
    return 1
  fi

  printf '%s' "$response" | python3 - "$kind" <<'PY'
import json, sys

kind = sys.argv[1] if len(sys.argv) > 1 else "auto"

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)

def ok_spring(d):
    # Spring Boot actuator health: {"status":"UP", ...}
    return d.get("status") == "UP"

def ok_quarkus(d):
    # Quarkus SmallRye Health: {"status":"UP","checks":[...]}
    return d.get("status") == "UP"

if kind == "spring":
    sys.exit(0 if ok_spring(data) else 1)
elif kind == "quarkus":
    sys.exit(0 if ok_quarkus(data) else 1)
else:
    # auto: accept either shape as long as status == UP
    sys.exit(0 if data.get("status") == "UP" else 1)
PY
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
  name="${entry%%|*}"
  rest="${entry#*|}"
  url="${rest%%|*}"
  kind="${rest##*|}"

  echo "[wait] $name -> $url"
  start="$(date +%s)"

  while true; do
    if check_health "$url" "$kind"; then
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