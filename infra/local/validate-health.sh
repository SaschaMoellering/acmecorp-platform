#!/usr/bin/env bash
set -euo pipefail

# Validate local health endpoints without relying on host port access.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}"

compose_cmd=(docker compose)

wait_for() {
  local svc="$1"
  local url="$2"
  local attempts=30

  for _ in $(seq 1 "${attempts}"); do
    if "${compose_cmd[@]}" exec -T "${svc}" curl -fsS "${url}" >/dev/null; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for ${svc} health at ${url}" >&2
  return 1
}

assert_status_up() {
  local name="$1"
  local json="$2"
  if ! echo "${json}" | grep -q "\"status\":\"UP\""; then
    echo "${name} health not UP: ${json}" >&2
    return 1
  fi
}

wait_for gateway-service http://localhost:8080/actuator/health
wait_for analytics-service http://localhost:8084/actuator/health

gateway_health="$("${compose_cmd[@]}" exec -T gateway-service curl -fsS http://localhost:8080/actuator/health)"
gateway_readiness="$("${compose_cmd[@]}" exec -T gateway-service curl -fsS http://localhost:8080/actuator/health/readiness)"
assert_status_up "gateway-service /actuator/health" "${gateway_health}"
assert_status_up "gateway-service /actuator/health/readiness" "${gateway_readiness}"

analytics_health="$("${compose_cmd[@]}" exec -T analytics-service curl -fsS http://localhost:8084/actuator/health)"
analytics_readiness="$("${compose_cmd[@]}" exec -T analytics-service curl -fsS http://localhost:8084/actuator/health/readiness)"
assert_status_up "analytics-service /actuator/health" "${analytics_health}"
assert_status_up "analytics-service /actuator/health/readiness" "${analytics_readiness}"

if ! echo "${analytics_health}" | grep -q "\"redis\".*\"status\":\"UP\""; then
  echo "analytics-service redis health not UP: ${analytics_health}" >&2
  exit 1
fi

if ! echo "${analytics_health}" | grep -q "\"db\".*\"status\":\"UP\""; then
  echo "analytics-service db health not UP: ${analytics_health}" >&2
  exit 1
fi

echo "Local health checks passed."
