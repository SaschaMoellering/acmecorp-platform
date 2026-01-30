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

build_spring_service() {
  local service="$1"
  echo "==> Building AppCDS image for ${service}"
  (cd "${repo_root}/${service}" && mvn clean spring-boot:build-image -Pappcds -Dspring-boot.build-image.network=host)
}

export -f build_spring_service
export repo_root

parallel="${PARALLEL:-1}"
if [ "${parallel}" -gt 1 ] && command -v xargs >/dev/null 2>&1; then
  printf '%s\n' "${spring_services[@]}" \
    | xargs -P "${parallel}" -I {} bash -lc 'build_spring_service "$@"' _ {}
else
  for service in "${spring_services[@]}"; do
    build_spring_service "${service}"
  done
fi

echo "==> Building AppCDS Docker image for Quarkus catalog-service"
(cd "${repo_root}/services/quarkus/catalog-service" && docker build --network=host -t local-catalog-service -f Dockerfile .)
