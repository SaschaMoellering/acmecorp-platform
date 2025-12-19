# Testing Guide

This guide covers testing the AcmeCorp platform across different environments.

## Local Testing with Docker Compose

### Quick Start

```bash
cd infra/local
docker compose up -d --build

# Wait for services to start
sleep 30

# Run smoke tests
../../scripts/smoke-local.sh
```

### Manual Testing

```bash
# Check gateway health
curl http://localhost:8080/api/gateway/status

# View system status (all services)
curl http://localhost:8080/api/gateway/system/status

# Check analytics counters
curl http://localhost:8080/api/gateway/analytics/counters

# Browse catalog products
curl http://localhost:8085/api/catalog/products

# Create test order
curl -X POST http://localhost:8080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "customerEmail": "test@example.com", "items": [{"productId": 1, "quantity": 2}]}'

# Verify analytics updated
curl http://localhost:8080/api/gateway/analytics/counters
```

## Kubernetes Testing

### Validation Tests

```bash
# Validate Kubernetes manifests
./scripts/validate-k8s.sh

# Check pod health
kubectl get pods -n acmecorp
kubectl wait --for=condition=ready pod -l app=gateway-service -n acmecorp

# Test service connectivity
kubectl exec -it deployment/gateway-service -n acmecorp -- curl http://orders-service:8081/actuator/health
```

## Integration Tests

### Backend Services

```bash
# Run integration tests
cd integration-tests
mvn test

# Run specific test
mvn test -Dtest=SystemStatusIntegrationTest
```

### Performance Tests

```bash
# Run Hibernate N+1 optimization test
cd services/spring-boot/orders-service
mvn test -Dtest=OrderServiceQueryCountTest
```

## Frontend Tests

### Unit Tests

```bash
cd webapp
npm test
```

### E2E Tests (if available)

```bash
cd webapp
npm run test:e2e
```

## Service-Specific Testing

### Orders Service

```bash
# Test order creation
curl -X POST http://localhost:8081/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "items": [{"productId": 1, "quantity": 2}]}'

# Test N+1 query demo
curl http://localhost:8081/api/orders/demo/nplus1
```

### Catalog Service (Quarkus)

```bash
# Health check
curl http://localhost:8085/q/health

# List products
curl http://localhost:8085/api/catalog/products

# Get specific product
curl http://localhost:8085/api/catalog/products/1
```

### Analytics Service

```bash
# Get counters
curl http://localhost:8084/api/analytics/counters

# Health check
curl http://localhost:8084/actuator/health
```

## Monitoring and Observability

### Health Checks

All services expose Spring Boot Actuator endpoints:

```bash
# Gateway
curl http://localhost:8080/actuator/health

# Orders
curl http://localhost:8081/actuator/health

# Billing
curl http://localhost:8082/actuator/health

# Notification
curl http://localhost:8083/actuator/health

# Analytics
curl http://localhost:8084/actuator/health
```

### Metrics

```bash
# Prometheus metrics (if enabled)
curl http://localhost:8080/actuator/prometheus
```

### Logs

```bash
# Docker Compose logs
docker compose logs -f gateway-service

# Kubernetes logs
kubectl logs -f deployment/gateway-service -n acmecorp
```

## Test Data

### Sample Products

The catalog service includes these test products:
- Acme Streamer Pro ($49.00)
- Alerting Add-on ($19.00)
- Secure Storage 1TB ($29.00)
- AI Insights ($59.00)

### Sample Orders

Create test orders with various scenarios:

```bash
# Single item order
curl -X POST http://localhost:8080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "customerEmail": "test@example.com", "items": [{"productId": 1, "quantity": 1}]}'

# Multiple items order
curl -X POST http://localhost:8080/api/gateway/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 2, "customerEmail": "user@example.com", "items": [{"productId": 1, "quantity": 2}, {"productId": 2, "quantity": 1}]}'
```

## Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker Compose logs
2. **Connection refused**: Ensure services are fully started (wait 30s)
3. **Database errors**: Verify PostgreSQL is healthy
4. **Message queue issues**: Check RabbitMQ status

### Debug Commands

```bash
# Check service status
docker compose ps

# View service logs
docker compose logs <service-name>

# Check database connectivity
docker exec -it acmecorp-postgres psql -U acmecorp -d acmecorp -c "SELECT 1;"

# Check Redis connectivity
docker exec -it acmecorp-redis redis-cli ping
```