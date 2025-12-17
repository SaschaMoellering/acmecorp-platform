#!/bin/bash
# Test Redis functionality locally

set -e

echo "🔧 Testing Redis Integration Locally"
echo "=================================="

# Start services
echo "1. Starting Docker Compose services..."
cd infra/local
docker compose up -d redis postgres
sleep 5

# Test Redis connectivity
echo "2. Testing Redis connectivity..."
docker compose exec redis redis-cli ping
if [ $? -eq 0 ]; then
    echo "✅ Redis is running"
else
    echo "❌ Redis connection failed"
    exit 1
fi

# Test rate limiting (Gateway Service)
echo "3. Testing rate limiting..."
cd ../../
docker compose -f infra/local/docker-compose.yml up -d gateway-service
sleep 10

echo "Making 5 requests to test rate limiting..."
for i in {1..5}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/gateway/status)
    echo "Request $i: HTTP $response"
done

# Test analytics counters
echo "4. Testing analytics counters..."
docker compose -f infra/local/docker-compose.yml up -d analytics-service
sleep 10

echo "Tracking test events..."
curl -X POST http://localhost:8084/analytics/track/orders.created
curl -X POST http://localhost:8084/analytics/track/billing.invoice.paid

echo "Getting counters..."
curl -s http://localhost:8084/analytics/counters | jq .

# Test catalog caching
echo "5. Testing catalog caching..."
docker compose -f infra/local/docker-compose.yml up -d catalog-service
sleep 10

echo "First request (cache miss):"
time curl -s http://localhost:8085/catalog/products > /dev/null

echo "Second request (cache hit):"
time curl -s http://localhost:8085/catalog/products > /dev/null

# Check Redis keys
echo "6. Checking Redis keys..."
echo "Current Redis keys:"
docker compose -f infra/local/docker-compose.yml exec redis redis-cli keys "*"

echo ""
echo "✅ Redis testing completed!"
echo "Check the output above for any issues."