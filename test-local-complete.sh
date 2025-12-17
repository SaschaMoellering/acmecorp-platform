#!/bin/bash
set -e

echo "🚀 Starting AcmeCorp Platform Local Test"

# Start services
echo "📦 Starting Docker Compose..."
cd infra/local
docker compose up -d --build

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 30

# Health checks
echo "🔍 Checking service health..."
curl -f http://localhost:8080/api/gateway/status || exit 1
curl -f http://localhost:8081/actuator/health || exit 1
curl -f http://localhost:8085/q/health || exit 1

# Seed data
echo "🌱 Seeding test data..."
curl -X POST http://localhost:8080/api/gateway/seed

# Test core functionality
echo "🧪 Testing core functionality..."
ORDER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "items": [{"productId": 1, "quantity": 2}]}')

echo "Order created: $ORDER_RESPONSE"

# Test Redis
echo "🔴 Testing Redis integration..."
cd ../..
if [ -f "./scripts/test-redis-local.sh" ]; then
  ./scripts/test-redis-local.sh
fi

echo "✅ All tests passed! Platform is running correctly."
echo "🌐 Access frontend at: http://localhost:5173 (after npm run dev in webapp/)"
echo "🔧 Cleanup with: cd infra/local && docker compose down --volumes"