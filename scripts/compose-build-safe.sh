#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/infra/local/docker-compose.yml}"

export COMPOSE_PARALLEL_LIMIT="${COMPOSE_PARALLEL_LIMIT:-1}"

cat <<'BANNER'
==> Docker Compose build (serial)
    COMPOSE_PARALLEL_LIMIT=1 keeps GraalVM native builds from freezing the host.
    Override by exporting COMPOSE_PARALLEL_LIMIT before running this script.
BANNER

docker compose -f "$COMPOSE_FILE" build --progress=plain "$@"
