#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_BASE="${COMPOSE_BASE:-$ROOT_DIR/infra/local/docker-compose.yml}"
COMPOSE_NATIVE="${COMPOSE_NATIVE:-$ROOT_DIR/infra/local/docker-compose.native.yml}"

export COMPOSE_PARALLEL_LIMIT="${COMPOSE_PARALLEL_LIMIT:-1}"
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
export BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS:-plain}"

DEFAULT_SERVICES=(
  orders-service
  billing-service
  notification-service
  analytics-service
  catalog-service
  gateway-service
)

if [[ -n "${SERVICES:-}" ]]; then
  read -r -a SERVICES_LIST <<<"$SERVICES"
else
  SERVICES_LIST=("${DEFAULT_SERVICES[@]}")
fi

cat <<'BANNER'
==> Docker Compose native build (serial)
    Builds one service at a time to limit RAM/IO spikes from native-image.
    Override services with SERVICES="orders-service catalog-service".
BANNER

for service in "${SERVICES_LIST[@]}"; do
  echo "==> building ${service}"
  docker compose -f "$COMPOSE_BASE" -f "$COMPOSE_NATIVE" build --progress=plain "$@" "$service"
done
