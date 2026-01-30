#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

spring_services=(
  "services/spring-boot/orders-service"
  "services/spring-boot/billing-service"
  "services/spring-boot/notification-service"
  "services/spring-boot/analytics-service"
  "services/spring-boot/gateway-service"
)

for service in "${spring_services[@]}"; do
  echo "==> Building AppCDS image for ${service}"
  (cd "${repo_root}/${service}" && mvn clean spring-boot:build-image -Pappcds -Dspring-boot.build-image.network=host)
done

echo "==> Building AppCDS Docker image for Quarkus catalog-service"
(cd "${repo_root}/services/quarkus/catalog-service" && docker build --network=host -t local-catalog-service -f Dockerfile .)
