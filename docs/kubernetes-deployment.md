# Kubernetes Deployment Guide

This guide covers deploying the AcmeCorp platform to Kubernetes environments.

## Production Deployment

### Helm Chart Deployment

```bash
# Create namespace
kubectl create namespace acmecorp

# Build and tag images for your registry
./scripts/push-images.sh
# Tag images for your registry (example with DockerHub)
docker tag local-gateway-service:latest your-registry/gateway-service:latest
docker push your-registry/gateway-service:latest
# ... repeat for all services

# Install with production values
helm upgrade --install acmecorp helm/acmecorp-platform \
  -n acmecorp \
  -f helm/acmecorp-platform/values-prod.yaml
```

### Security Features

The platform includes production-ready security components:

- **Network Policies**: Micro-segmentation between services
- **Resource Quotas**: CPU/memory limits and pod counts
- **Pod Disruption Budgets**: High availability during updates
- **Sealed Secrets**: Encrypted secret management

### Validation

```bash
# Validate manifests
./scripts/validate-k8s.sh

# Check deployment status
kubectl get pods,svc,networkpolicy -n acmecorp

# Test endpoints
kubectl port-forward svc/gateway-service 8080:80 -n acmecorp
curl http://localhost:8080/api/gateway/status
```

## Troubleshooting

### Common Issues

1. **Image Pull Errors**: Ensure images are pushed to accessible registry
2. **Network Policies**: Check if policies are blocking communication
3. **Resource Limits**: Verify pods have sufficient CPU/memory

### Debug Commands

```bash
# Check pod logs
kubectl logs -l app=gateway-service -n acmecorp

# Describe failing pods
kubectl describe pod <pod-name> -n acmecorp

# Check service endpoints
kubectl get endpoints -n acmecorp
```

## Configuration

### Environment Variables

Services support these key environment variables:

- `SPRING_PROFILES_ACTIVE`: Set to `kubernetes` for K8s deployment
- `DB_HOST`, `DB_PORT`: Database connection
- `REDIS_HOST`, `REDIS_PORT`: Redis connection
- `RABBITMQ_HOST`, `RABBITMQ_PORT`: Message queue connection

### Secrets

Required secrets:
- `acmecorp-credentials`: Database and RabbitMQ credentials
- `acmecorp-postgres`: Database password
- `acmecorp-rabbitmq`: RabbitMQ password

```bash
kubectl create secret generic acmecorp-credentials \
  --from-literal=POSTGRES_DB=acmecorp \
  --from-literal=POSTGRES_USER=acmecorp \
  --from-literal=POSTGRES_PASSWORD=<password> \
  --from-literal=RABBITMQ_DEFAULT_USER=guest \
  --from-literal=RABBITMQ_DEFAULT_PASS=<password> \
  -n acmecorp
```