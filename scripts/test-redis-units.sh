#!/bin/bash
# Run Redis-specific unit tests

set -e

echo "🧪 Running Redis Unit Tests"
echo "=========================="

# Test Orders Service Cache
echo "1. Testing Orders Service Cache..."
cd services/spring-boot/orders-service
mvn test -Dtest=CacheIntegrationTest
echo "✅ Orders cache tests passed"

# Test Analytics Service Redis
echo "2. Testing Analytics Service Redis..."
cd ../analytics-service
mvn test -Dtest=RedisAnalyticsTest
echo "✅ Analytics Redis tests passed"

# Test Gateway Service Rate Limiting
echo "3. Testing Gateway Service Rate Limiting..."
cd ../gateway-service
mvn test -Dtest=RateLimitFilterTest
echo "✅ Gateway rate limiting tests passed"

cd ../../..
echo ""
echo "✅ All Redis unit tests passed!"