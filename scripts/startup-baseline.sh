#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CRAC_MATRIX_SERVICES="${CRAC_MATRIX_SERVICES:-gateway-service,orders-service,billing-service,notification-service,analytics-service}"
BASE_READY_URL="${BASE_READY_URL:-http://localhost:8080/actuator/health}"
BASE_READY_MAX_SECONDS="${BASE_READY_MAX_SECONDS:-180}"
SMOKE_PROBE_IMAGE="${SMOKE_PROBE_IMAGE:-curlimages/curl:8.5.0}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-0.1}"
OUT_FILE="${OUT_FILE:-startup-baseline.md}"

COMPOSE_FILES=(
  -f "${REPO_ROOT}/infra/local/docker-compose.yml"
  -f "${REPO_ROOT}/infra/local/docker-compose.crac.yml"
)

docker_compose() { (cd "${REPO_ROOT}" && docker compose "${COMPOSE_FILES[@]}" "$@"); }

ts_ms() {
  local now
  now="$(date +%s%3N 2>/dev/null || true)"
  if [[ "${now}" =~ ^[0-9]+$ ]]; then
    echo "${now}"
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

probe_http_via_netns() {
  local cid="$1" url="$2"
  docker run --rm --network "container:${cid}" "${SMOKE_PROBE_IMAGE}" \
    curl -fsS --max-time 3 "${url}" >/dev/null 2>&1
}

wait_ready_ms() {
  local cid="$1" url="$2" max_seconds="$3"
  local start_ms end_ms now_ms
  start_ms="$(ts_ms)"
  end_ms=$(( start_ms + max_seconds * 1000 ))

  while true; do
    now_ms="$(ts_ms)"
    if (( now_ms >= end_ms )); then
      echo "TIMEOUT"
      return 124
    fi
    if probe_http_via_netns "${cid}" "${url}"; then
      echo $(( now_ms - start_ms ))
      return 0
    fi
    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

print_header() {
  echo "| service | normal_ready_ms | started_s |"
  echo "|---|---:|---:|"
}

print_header >"${OUT_FILE}"
print_header

IFS=',' read -r -a svcs <<< "${CRAC_MATRIX_SERVICES}"
for svc in "${svcs[@]}"; do
  svc="$(echo "${svc}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  [[ -n "${svc}" ]] || continue

  docker_compose up -d --no-deps --force-recreate "${svc}" >/dev/null 2>&1
  cid="$(docker_compose ps -q "${svc}" | head -n1)"
  if [[ -z "${cid}" ]]; then
    ready_ms="TIMEOUT"
    started_s="unknown"
  else
    ready_ms="$(wait_ready_ms "${cid}" "${BASE_READY_URL}" "${BASE_READY_MAX_SECONDS}")"
    started_line="$(docker logs "${cid}" 2>/dev/null | grep -E 'Started .* in [0-9]+(\.[0-9]+)? seconds' | tail -n1)"
    started_s="unknown"
    if [[ -n "${started_line}" ]]; then
      started_s="$(echo "${started_line}" | sed -nE 's/.* in ([0-9]+(\.[0-9]+)?) seconds.*/\1/p' | head -n1)"
    fi
  fi

  row="| ${svc} | ${ready_ms} | ${started_s} |"
  echo "${row}" | tee -a "${OUT_FILE}"
  docker_compose stop "${svc}" >/dev/null 2>&1 || true
  docker_compose rm -sf "${svc}" >/dev/null 2>&1 || true

done

echo "Wrote ${OUT_FILE}"
