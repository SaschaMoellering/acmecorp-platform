# Redis Testing Guide

## Quick Start

```bash
# Run all Redis tests
./scripts/test-redis-local.sh

# Run unit tests only
./scripts/test-redis-units.sh
```

## Manual Testing Steps

### 1. Start Local Environment

```bash
cd infra/local
docker compose up -d
```

### 2. Test Rate Limiting (Gateway)

```bash
# Test normal requests
for i in {1..10}; do
  curl -w "Request $i: %{http_code}\n" -o /dev/null -s http://localhost:8080/api/gateway/status
done

# Test rate limiting (run quickly)
for i in {1..1005}; do
  curl -w "%{http_code} " -o /dev/null -s http://localhost:8080/api/gateway/status
done
# Should see 429 (Too Many Requests) after 1000 requests
```

### 3. Test Analytics Counters

```bash
# Track events
curl -X POST http://localhost:8084/analytics/track/orders.created
curl -X POST http://localhost:8084/analytics/track/billing.invoice.paid

# View counters
curl http://localhost:8084/analytics/counters | jq
```

### 4. Test Catalog Caching

```bash
# First request (cache miss)
time curl -s http://localhost:8085/catalog/products

# Second request (cache hit - should be faster)
time curl -s http://localhost:8085/catalog/products
```

### 5. Inspect Redis Data

```bash
# Connect to Redis CLI
docker compose exec redis redis-cli

# View all keys
KEYS *

# Check rate limiting keys
KEYS rate_limit:*

# Check analytics keys
KEYS analytics:*

# Check cache keys
KEYS catalog:*
```

## Expected Results

### Rate Limiting
- First 1000 requests: HTTP 200
- Requests 1001+: HTTP 429

### Analytics
- Counters increment with each tracked event
- Data persists in Redis with keys like `analytics:event:orders.created`

### Caching
- Second request should be significantly faster
- Cache keys visible in Redis with TTL

### Session Management
- Session data stored in Redis with namespace `acmecorp:sessions`
- Sessions persist across gateway restarts

## Troubleshooting

### Redis Connection Issues
```bash
# Check Redis is running
docker compose ps redis

# Check Redis logs
docker compose logs redis

# Test Redis connectivity
docker compose exec redis redis-cli ping
```

### Cache Not Working
```bash
# Check cache configuration
docker compose exec catalog-service env | grep REDIS

# Verify cache keys exist
docker compose exec redis redis-cli keys "catalog:*"
```

### Rate Limiting Not Working
```bash
# Check rate limit keys
docker compose exec redis redis-cli keys "rate_limit:*"

# Check TTL on rate limit keys
docker compose exec redis redis-cli ttl rate_limit:127.0.0.1
```

## Performance Testing

### Load Test Rate Limiting
```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test rate limiting under load
ab -n 2000 -c 10 http://localhost:8080/api/gateway/status
```

### Cache Performance Test
```bash
# Measure cache hit ratio
for i in {1..100}; do
  time curl -s http://localhost:8085/catalog/products > /dev/null
done
```