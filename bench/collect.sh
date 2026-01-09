#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"

RESULT_DIR="${1:?}"
if [[ ! -d "$RESULT_DIR" ]]; then
  mkdir -p "$RESULT_DIR"
fi

services=("gateway-service" "orders-service" "catalog-service")
containers_file="$RESULT_DIR/containers.json"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "compose file missing: $COMPOSE_FILE" >&2
  exit 1
fi

docker_compose=("docker" "compose" "-f" "$COMPOSE_FILE")

printf '[' > "$containers_file"
first=true
for svc in "${services[@]}"; do
  ids=$("${docker_compose[@]}" ps -q "$svc")
  for id in $ids; do
    [[ -z "$id" ]] && continue
    stats=$(docker stats --no-stream --no-trunc --format '{{.Name}}|{{.MemUsage}}' "$id")
    name="${stats%%|*}"
    mem_usage_full="${stats#*|}"
    mem="${mem_usage_full%% / *}"
    if [[ "$first" == true ]]; then
      first=false
    else
      printf ',' >> "$containers_file"
    fi
    printf '\n  {"service":"%s","container":"%s","mem":"%s"}' "$svc" "$name" "$mem" >> "$containers_file"
  done
done
printf '\n]\n' >> "$containers_file"

echo "$containers_file"
