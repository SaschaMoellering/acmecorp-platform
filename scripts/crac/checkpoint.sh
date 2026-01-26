#!/bin/bash

# CRaC Checkpoint Script for AcmeCorp Platform Spring Boot Services
# Usage: ./scripts/crac/checkpoint.sh <service-name>

set -euo pipefail

SERVICE_NAME=${1:-}
TIMEOUT=${2:-120}

if [[ -z "$SERVICE_NAME" ]]; then
    echo "Usage: $0 <service-name> [timeout]"
    echo "Available services: gateway-service, orders-service, billing-service, notification-service, analytics-service"
    exit 1
fi

# Validate service name (Spring Boot only)
case "$SERVICE_NAME" in
    gateway-service|orders-service|billing-service|notification-service|analytics-service)
        ;;
    *)
        echo "Error: '$SERVICE_NAME' is not a supported Spring Boot service"
        echo "CRaC is only supported for Spring Boot services, not Quarkus services"
        exit 1
        ;;
esac

echo "=== CRaC Checkpoint Creation ==="
echo "Service: $SERVICE_NAME"
echo "Timeout: ${TIMEOUT}s"
echo "Date: $(date)"
echo

# Check if service directory exists
SERVICE_DIR="services/spring-boot/$SERVICE_NAME"
if [[ ! -d "$SERVICE_DIR" ]]; then
    echo "Error: Service directory '$SERVICE_DIR' not found"
    exit 1
fi

# Build the CRaC-enabled image
echo "Building CRaC-enabled image..."
cd "$SERVICE_DIR"
docker build -t "$SERVICE_NAME:crac" .
cd - > /dev/null

# Create Docker volume for checkpoint storage
VOLUME_NAME="crac-$SERVICE_NAME"
echo "Creating checkpoint volume: $VOLUME_NAME"
docker volume create "$VOLUME_NAME" > /dev/null

# Clean up any existing checkpoint container
docker stop "$SERVICE_NAME-checkpoint" 2>/dev/null || true
docker rm "$SERVICE_NAME-checkpoint" 2>/dev/null || true

echo "Starting checkpoint creation..."

# Start container in checkpoint mode
docker run -d \\\n    --name "$SERVICE_NAME-checkpoint" \\\n    --privileged \\\n    -e CRAC_MODE=checkpoint \\\n    -e CRAC_CHECKPOINT_DIR=/opt/crac \\\n    -e SPRING_DATASOURCE_URL=\"jdbc:postgresql://host.docker.internal:5432/acmecorp\" \\\n    -e SPRING_DATASOURCE_USERNAME=\"acmecorp\" \\\n    -e SPRING_DATASOURCE_PASSWORD=\"acmecorp123\" \\\n    -e SPRING_RABBITMQ_HOST=\"host.docker.internal\" \\\n    -e SPRING_REDIS_HOST=\"host.docker.internal\" \\\n    -v \"$VOLUME_NAME:/opt/crac\" \\\n    \"$SERVICE_NAME:crac\"\n\necho \"Waiting for checkpoint creation (timeout: ${TIMEOUT}s)...\"\n\n# Wait for container to complete checkpoint and exit\nif timeout \"$TIMEOUT\" docker wait \"$SERVICE_NAME-checkpoint\" > /dev/null; then\n    EXIT_CODE=$(docker inspect \"$SERVICE_NAME-checkpoint\" --format='{{.State.ExitCode}}')\n    \n    if [[ \"$EXIT_CODE\" == \"0\" ]]; then\n        echo \"✅ Checkpoint created successfully!\"\n        \n        # Show checkpoint info\n        echo \"Checkpoint volume: $VOLUME_NAME\"\n        docker run --rm -v \"$VOLUME_NAME:/opt/crac\" alpine sh -c \"du -sh /opt/crac/* 2>/dev/null || echo 'Checkpoint files created'\"\n        \n        echo\n        echo \"To restore from this checkpoint, run:\"\n        echo \"  ./scripts/crac/restore.sh $SERVICE_NAME\"\n    else\n        echo \"❌ Checkpoint creation failed with exit code: $EXIT_CODE\"\n        echo \"Container logs:\"\n        docker logs \"$SERVICE_NAME-checkpoint\"\n        exit 1\n    fi\nelse\n    echo \"❌ Checkpoint creation timed out after ${TIMEOUT}s\"\n    echo \"Container logs:\"\n    docker logs \"$SERVICE_NAME-checkpoint\"\n    docker stop \"$SERVICE_NAME-checkpoint\" 2>/dev/null || true\n    exit 1\nfi\n\n# Cleanup\ndocker rm \"$SERVICE_NAME-checkpoint\" > /dev/null\n\necho \"Checkpoint creation complete!\"