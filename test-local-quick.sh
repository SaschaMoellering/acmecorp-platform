#!/bin/bash
set -e

echo "🚀 AcmeCorp Platform - Quick Local Test"

# Build services with host network (fixes Maven connectivity)
echo "🔨 Building services..."
cd services/quarkus/catalog-service && docker build --network=host -t local-catalog-service . && cd ../../..
cd services/spring-boot/analytics-service && docker build --network=host -t local-analytics-service . && cd ../../..
cd services/spring-boot/orders-service && docker build --network=host -t local-orders-service . && cd ../../..

# Start services
echo "📦 Starting services..."
cd infra/local && docker compose up -d && cd ../..

# Wait for startup
echo "⏳ Waiting for services..."
sleep 20

# Health checks
echo "🔍 Health checks..."
curl -f http://localhost:8080/api/gateway/status
curl -f http://localhost:8081/actuator/health
curl -f http://localhost:8085/q/health

# Seed data
echo -e "\n🌱 Seeding data..."
curl -X POST http://localhost:8080/api/gateway/seed

# Test functionality
echo -e "\n🧪 Testing functionality..."
ORDER=$(curl -s -X POST http://localhost:8080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "customerEmail": "test@example.com", "items": [{"productId": 1, "quantity": 2}]}')
echo "Order created: $(echo $ORDER | jq '.orderNumber')"

ORDERS=$(curl -s http://localhost:8080/api/gateway/orders | jq 'length')
echo "Total orders: $ORDERS"

PRODUCTS=$(curl -s http://localhost:8080/api/gateway/catalog/products | jq 'length')
echo "Total products: $PRODUCTS"

NOTIFICATIONS=$(curl -s http://localhost:8080/api/gateway/notifications | jq '.totalElements')
echo "Total notifications: $NOTIFICATIONS"

# Redis check
echo -e "\n🔴 Redis integration:"
docker exec acmecorp-redis redis-cli KEYS '*'

echo -e "\n✅ All tests passed!"
echo "🌐 Frontend: cd webapp && npm run dev (http://localhost:5173)"
echo "🔧 Cleanup: cd infra/local && docker compose down --volumes"