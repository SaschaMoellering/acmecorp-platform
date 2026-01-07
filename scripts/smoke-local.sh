#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:8080}
SMOKE_TRIES=${SMOKE_TRIES:-30}
SMOKE_SLEEP=${SMOKE_SLEEP:-2}
CURL_CONNECT_TIMEOUT=${CURL_CONNECT_TIMEOUT:-2}
CURL_MAX_TIME=${CURL_MAX_TIME:-10}

echo "Smoke check against ${BASE_URL}"

check_url() {
  local name=$1
  local url=$2
  local dest=$3
  local retries=${4:-1}
  local attempt=1

  while true; do
    if curl -fsS --connect-timeout "${CURL_CONNECT_TIMEOUT}" --max-time "${CURL_MAX_TIME}" \
      "${url}" -o "${dest}"; then
      echo "${name}: ok"
      return 0
    fi

    if [ "${attempt}" -ge "${retries}" ]; then
      echo "${name}: failed after ${attempt} attempt(s)"
      echo "Response for ${url}:"
      # Print headers + body to help debug failing endpoints in CI.
      curl -sS --connect-timeout "${CURL_CONNECT_TIMEOUT}" --max-time "${CURL_MAX_TIME}" \
        -D- "${url}" || true
      return 1
    fi

    echo "${name}: retrying (${attempt}/${retries}) in ${SMOKE_SLEEP}s..."
    attempt=$((attempt + 1))
    sleep "${SMOKE_SLEEP}"
  done
}

check_url "System status" "${BASE_URL}/api/gateway/system/status" \
  /tmp/acmecorp_system_status.json 1

# Retry endpoints that may not be ready immediately in CI.
check_url "Analytics counters" "${BASE_URL}/api/gateway/analytics/counters" \
  /tmp/acmecorp_analytics_counters.json "${SMOKE_TRIES}"

check_url "Orders latest" "${BASE_URL}/api/gateway/orders/latest" \
  /tmp/acmecorp_orders.json "${SMOKE_TRIES}"

check_url "Catalog" "${BASE_URL}/api/gateway/catalog" \
  /tmp/acmecorp_catalog.json "${SMOKE_TRIES}"

echo "All smoke checks passed."
