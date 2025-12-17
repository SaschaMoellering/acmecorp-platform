#!/bin/bash

echo "=== Redis Testing Guide ==="

echo "1. Test Analytics Service"
echo "Track events:"
echo "curl -X POST http://localhost:8084/api/analytics/track/orders.created"
echo "curl -X POST http://localhost:8084/api/analytics/track/billing.invoice.paid"
echo ""
echo "View counters:"
echo "curl http://localhost:8084/api/analytics/counters"
echo ""

echo "2. Test Gateway Rate Limiting"
echo "Make requests:"
echo "curl http://localhost:8080/api/gateway/status"
echo ""

echo "3. Test Catalog Service"
echo "Get products:"
echo "curl http://localhost:8085/catalog/products"
echo ""

echo "4. Check Redis Keys"
echo "docker compose exec redis redis-cli keys '*'"
echo ""

echo "5. Check specific Redis data"
echo "Analytics keys: docker compose exec redis redis-cli keys 'analytics:*'"
echo "Rate limit keys: docker compose exec redis redis-cli keys 'rate_limit:*'"
echo "Cache keys: docker compose exec redis redis-cli keys 'catalog:*'"