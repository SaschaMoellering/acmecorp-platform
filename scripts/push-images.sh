#!/bin/bash
set -e

echo "🚀 Building Container Images"
echo "============================="

# Build images
echo "Building images..."
cd infra/local
docker compose build

echo "✅ All images built successfully!"
echo "💡 Images available as: local-*-service:latest"