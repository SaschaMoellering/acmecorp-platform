#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SERVICE="${SERVICE:-gateway-service}"
HEALTH_URL="${HEALTH_URL:-http://localhost:8080/actuator/health}"
MAX_SECONDS="${MAX_SECONDS:-60}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-0.1}"
PROBE_IMAGE="${PROBE_IMAGE:-${SMOKE_PROBE_IMAGE:-curlimages/curl:8.5.0}}"
LOG_TAIL="${LOG_TAIL:-500}"
CLEANUP="${CLEANUP:-1}"
EXPORT_DIR="${EXPORT_DIR:-}"
BENCH_STARTUP="${BENCH_STARTUP:-}"

if [[ -z "${COMPOSE_BAKE+x}" ]]; then
  export COMPOSE_BAKE=false
fi

COMPOSE_FILES=(
  -f "${REPO_ROOT}/infra/local/docker-compose.yml"
  -f "${REPO_ROOT}/infra/local/docker-compose.crac.yml"
)

docker_compose() { (cd "${REPO_ROOT}" && docker compose "${COMPOSE_FILES[@]}" "$@"); }

ts_ms() {
  local now
  now="$(date +%s%3N 2>/dev/null || true)"
  if [[ "${now}" =~ ^[0-9]+$ ]]; then
    echo "${now}"
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

log() { echo "$*" | tee -a "${WRAPPER_LOG}"; }
warn() { echo "WARN: $*" | tee -a "${WRAPPER_LOG}" >&2; }

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
WRAPPER_LOG="/tmp/bench-startup.${SERVICE}.${timestamp}.log"
CONTAINER_LOG="/tmp/bench-startup.${SERVICE}.${timestamp}.container.log"

{
  echo "timestamp_utc=${timestamp}"
  echo "service=${SERVICE}"
  echo "health_url=${HEALTH_URL}"
  echo "poll_interval_seconds=${POLL_INTERVAL_SECONDS}"
  echo "max_seconds=${MAX_SECONDS}"
  echo "compose_bake=${COMPOSE_BAKE:-}"
} >"${WRAPPER_LOG}"

if [[ "${BENCH_STARTUP}" != "true" ]]; then
  log "bench_startup_disabled service=${SERVICE} (set -Dbench.startup=true to run)"
  exit 0
fi

log "==> Build ${SERVICE} image (COMPOSE_BAKE=${COMPOSE_BAKE:-})"
docker_compose build --no-cache "${SERVICE}" >>"${WRAPPER_LOG}" 2>&1

log "==> Recreate ${SERVICE} container"
docker_compose up -d --no-deps --force-recreate "${SERVICE}" >>"${WRAPPER_LOG}" 2>&1

cid="$(docker_compose ps -q "${SERVICE}" | head -n1)"
if [[ -z "${cid}" ]]; then
  warn "Container id not found for ${SERVICE}"
  docker_compose ps | tee -a "${WRAPPER_LOG}" >&2 || true
  exit 1
fi

start_ms="$(ts_ms)"
end_ms=$(( start_ms + MAX_SECONDS * 1000 ))
health_ms=""
port_started_ms=""
started_seconds="unknown"

while true; do
  now_ms="$(ts_ms)"
  if (( now_ms >= end_ms )); then
    warn "Health did not reach 200 within ${MAX_SECONDS}s"
    {
      echo "svc=${SERVICE}"
      echo "phase=base"
      echo "captured_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "---- docker inspect ----"
      docker inspect -f 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "${cid}" 2>&1 || echo "inspect failed"
      echo "---- docker logs ----"
      if [[ "${LOG_TAIL}" == "all" ]]; then
        docker logs "${cid}" 2>&1 || echo "docker logs failed"
      else
        docker logs --tail="${LOG_TAIL}" "${cid}" 2>&1 || echo "docker logs failed"
      fi
    } >"${CONTAINER_LOG}" 2>&1 || true
    warn "wrapper_log=${WRAPPER_LOG}"
    warn "container_log=${CONTAINER_LOG}"
    exit 1
  fi

  if [[ -z "${port_started_ms}" ]]; then
    if docker logs --tail=200 "${cid}" 2>/dev/null | grep -qE 'Netty started on port 8080|Tomcat started on port 8080'; then
      port_started_ms=$(( now_ms - start_ms ))
    fi
  fi

  if [[ -z "${started_seconds}" || "${started_seconds}" == "unknown" ]]; then
    started_line="$(docker logs "${cid}" 2>/dev/null | grep -E 'Started .* in [0-9]+(\.[0-9]+)? seconds' | tail -n1)"
    if [[ -n "${started_line}" ]]; then
      started_seconds="$(echo "${started_line}" | sed -nE 's/.* in ([0-9]+(\.[0-9]+)?) seconds.*/\1/p' | head -n1)"
    fi
  fi

  if docker run --rm --network "container:${cid}" "${PROBE_IMAGE}" curl -fsS --max-time 3 "${HEALTH_URL}" >/dev/null 2>&1; then
    now_ms="$(ts_ms)"
    health_ms=$(( now_ms - start_ms ))
    break
  fi

  sleep "${POLL_INTERVAL_SECONDS}"
done

{
  echo "svc=${SERVICE}"
  echo "phase=base"
  echo "captured_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "---- docker inspect ----"
  docker inspect -f 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "${cid}" 2>&1 || echo "inspect failed"
  echo "---- docker logs ----"
  if [[ "${LOG_TAIL}" == "all" ]]; then
    docker logs "${cid}" 2>&1 || echo "docker logs failed"
  else
    docker logs --tail="${LOG_TAIL}" "${cid}" 2>&1 || echo "docker logs failed"
  fi
} >"${CONTAINER_LOG}" 2>&1 || true

if [[ -z "${health_ms}" ]]; then
  health_ms="unknown"
fi
if [[ -z "${port_started_ms}" ]]; then
  port_started_ms="unknown"
fi
if [[ -z "${started_seconds}" ]]; then
  started_seconds="unknown"
fi

log "startup_summary service=${SERVICE} started_s=${started_seconds} health_200_ms=${health_ms} port_started_ms=${port_started_ms}"
log "wrapper_log=${WRAPPER_LOG}"
log "container_log=${CONTAINER_LOG}"

if [[ -n "${EXPORT_DIR}" ]]; then
  export_run_dir="${EXPORT_DIR%/}/${timestamp}/raw"
  mkdir -p "${export_run_dir}"
  cp -f "${WRAPPER_LOG}" "${CONTAINER_LOG}" "${export_run_dir}/" 2>/dev/null || true
  echo "startup_summary service=${SERVICE} started_s=${started_seconds} health_200_ms=${health_ms} port_started_ms=${port_started_ms}" >"${export_run_dir}/startup_summary.txt"
  log "export_dir=${export_run_dir}"
fi

if [[ "${CLEANUP}" == "1" ]]; then
  docker_compose rm -sf "${SERVICE}" >/dev/null 2>&1 || true
fi
