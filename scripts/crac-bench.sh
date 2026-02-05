#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXPORT_BASE="${CRAC_EXPORT_DIR:-/tmp/crac-results}"
LOG_FILE="/tmp/crac-bench.$(date -u +%Y%m%dT%H%M%SZ).log"

cd "${REPO_ROOT}"

echo "== CRaC bench: cleaning local compose volumes =="
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml down -v --remove-orphans || true

echo "== CRaC bench: running matrix =="
CRAC_EXPORT_DIR="${EXPORT_BASE}" scripts/crac-demo.sh matrix | tee "${LOG_FILE}"

echo "Bench log: ${LOG_FILE}"
echo "Export base dir: ${EXPORT_BASE}"
