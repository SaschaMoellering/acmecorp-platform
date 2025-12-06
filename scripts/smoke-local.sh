#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:8080}

echo "Smoke check against ${BASE_URL}"

curl -sf "${BASE_URL}/api/gateway/system/status" >/tmp/acmecorp_system_status.json
echo "System status: ok"

curl -sf "${BASE_URL}/api/gateway/analytics/counters" >/tmp/acmecorp_analytics_counters.json
echo "Analytics counters: ok"

curl -sf "${BASE_URL}/api/gateway/orders/latest" >/tmp/acmecorp_orders.json
echo "Orders latest: ok"

curl -sf "${BASE_URL}/api/gateway/catalog" >/tmp/acmecorp_catalog.json
echo "Catalog: ok"

echo "All smoke checks passed."
