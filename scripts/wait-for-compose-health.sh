#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TIMEOUT_SECONDS=180
DEFAULT_INTERVAL_SECONDS=2

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-${1:-$DEFAULT_TIMEOUT_SECONDS}}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-${2:-$DEFAULT_INTERVAL_SECONDS}}"
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# scheme://host[:port] (drop path) from BASE_URL
ORIGIN="$(
  python3 -c '
import os, urllib.parse
u = urllib.parse.urlparse(os.environ.get("BASE_URL","http://localhost:8080"))
scheme = u.scheme or "http"
host = u.hostname or "localhost"
port = u.port
if port:
    print(f"{scheme}://{host}:{port}")
else:
    print(f"{scheme}://{host}")
'
)"

SERVICES=(
  "gateway-service|${ORIGIN}/actuator/health|spring"
  "system-status|${ORIGIN}/api/gateway/system/status|system"
)

fetch() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  # prints:
  #   <http_code>\n<body>
  local code="000"
  code="$(curl -sS -m 2 -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null || true)"
  [[ -n "$code" ]] || code="000"
  printf '%s\n' "$code"
  cat "$tmp" 2>/dev/null || true
  rm -f "$tmp" || true
}

json_status_up() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if d.get("status") == "UP" else 1)
'
}

system_status_up() {
  python3 -c '
import json, sys
expected = {"orders", "billing", "notification", "analytics", "catalog"}
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(data, list):
    sys.exit(1)
seen = set()
for entry in data:
    if not isinstance(entry, dict):
        sys.exit(1)
    service = entry.get("service")
    status = entry.get("status")
    if service:
        seen.add(str(service))
    if not status or str(status).upper() not in ("UP", "READY"):
        sys.exit(1)
sys.exit(0 if expected.issubset(seen) else 1)
'
}

check_spring_health() {
  local health_url="$1"
  local readiness_url="${health_url%/actuator/health}/actuator/health/readiness"

  # Try readiness first (Spring Boot groups)
  local out code body
  out="$(fetch "$readiness_url")"
  code="$(printf '%s\n' "$out" | head -n1)"
  body="$(printf '%s\n' "$out" | tail -n +2)"

  if [[ "$code" == "200" ]] && json_status_up <<<"$body"; then
    return 0
  fi

  # Fallback to /actuator/health
  out="$(fetch "$health_url")"
  code="$(printf '%s\n' "$out" | head -n1)"
  body="$(printf '%s\n' "$out" | tail -n +2)"

  [[ "$code" == "200" ]] && json_status_up <<<"$body"
}

check_system_status() {
  local url="$1"
  local out code body
  out="$(fetch "$url")"
  code="$(printf '%s\n' "$out" | head -n1)"
  body="$(printf '%s\n' "$out" | tail -n +2)"
  [[ "$code" == "200" ]] && system_status_up <<<"$body"
}

print_diagnostics() {
  echo "[diagnostics] docker compose ps/logs" >&2
  if command -v docker >/dev/null 2>&1; then
    if [[ -f "${REPO_ROOT}/infra/local/docker-compose.yml" ]]; then
      (cd "${REPO_ROOT}/infra/local" && docker compose ps) || true
      (cd "${REPO_ROOT}/infra/local" && docker compose logs --tail 200) || true
    else
      echo "[diagnostics] ${REPO_ROOT}/infra/local/docker-compose.yml not found" >&2
    fi
  else
    echo "[diagnostics] docker not available" >&2
  fi
}

for entry in "${SERVICES[@]}"; do
  IFS='|' read -r name url kind <<<"$entry"

  echo "[wait] $name -> $url"
  start="$(date +%s)"

  while true; do
    if [[ "$kind" == "spring" ]]; then
      if check_spring_health "$url"; then
        echo "READY: $name"
        break
      fi
    elif [[ "$kind" == "system" ]]; then
      if check_system_status "$url"; then
        echo "READY: $name"
        break
      fi
    fi

    if (( "$(date +%s)" - start >= TIMEOUT_SECONDS )); then
      echo "[timeout] $name not healthy at $url after ${TIMEOUT_SECONDS}s" >&2
      echo "[timeout] last probe:" >&2
      probe="$(fetch "$url")"
      printf '%s\n' "$probe" | head -n1 >&2
      printf '%s\n' "$probe" | tail -n +2 | head -c 500 >&2
      echo >&2
      print_diagnostics
      exit 1
    fi

    sleep "$INTERVAL_SECONDS"
  done
done
