#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:8080}

echo "Smoke check against ${BASE_URL}"

# Function to retry curl with backoff
retry_curl() {
    local url=$1
    local output=$2
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > "$output" 2>/dev/null; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying in 2 seconds..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "Failed after $max_attempts attempts: $url"
    return 1
}

retry_curl "${BASE_URL}/api/gateway/system/status" "/tmp/acmecorp_system_status.json"
echo "System status: ok"

retry_curl "${BASE_URL}/api/gateway/analytics/counters" "/tmp/acmecorp_analytics_counters.json"
echo "Analytics counters: ok"

retry_curl "${BASE_URL}/api/gateway/orders/latest" "/tmp/acmecorp_orders.json"
echo "Orders latest: ok"

retry_curl "${BASE_URL}/api/gateway/catalog" "/tmp/acmecorp_catalog.json"
echo "Catalog: ok"

echo "All smoke checks passed."
