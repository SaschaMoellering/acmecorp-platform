#!/usr/bin/env bash
set -euo pipefail

# scripts/crac-demo.sh
#
# Commands:
#   - demo:   scripts/crac-demo.sh demo <service>
#   - matrix: scripts/crac-demo.sh matrix
#
# Env:
#   CRAC_CHECKPOINT_BASE=/opt/crac
#   CRAC_MATRIX_SERVICES=gateway-service,orders-service,...
#   CRAC_CHECKPOINT_POLL_MAX_SECONDS=180
#   CRAC_RESTORE_POLL_MAX_SECONDS=60
#   CRAC_POLL_MAX_SECONDS= (legacy fallback for both)
#   BASE_READY_MAX_SECONDS=180
#   RESTORE_POLL_INTERVAL_SECONDS=0.2
#   BASE_READY_URL=http://localhost:8080/actuator/health
#   CRAC_MATRIX_REPEATS=1
#   CRAC_SMOKE=0
#   CRAC_SMOKE_URLS="orders-service=/actuator/health;/actuator/info,billing-service=/actuator/health"
#   SMOKE_PROBE_IMAGE=curlimages/curl:8.5.0
#   PROBE_MODE=oneshot|loop
#   CRAC_EXPORT_DIR=/tmp/crac-results
#   CRAC_DEBUG=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CRAC_CHECKPOINT_BASE="${CRAC_CHECKPOINT_BASE:-/opt/crac}"
CRAC_POLL_MAX_SECONDS="${CRAC_POLL_MAX_SECONDS:-}"

CRAC_CHECKPOINT_POLL_MAX_SECONDS="${CRAC_CHECKPOINT_POLL_MAX_SECONDS:-${CRAC_POLL_MAX_SECONDS:-180}}"
CRAC_RESTORE_POLL_MAX_SECONDS="${CRAC_RESTORE_POLL_MAX_SECONDS:-${CRAC_POLL_MAX_SECONDS:-60}}"

BASE_READY_MAX_SECONDS="${BASE_READY_MAX_SECONDS:-180}"
RESTORE_POLL_INTERVAL_SECONDS="${RESTORE_POLL_INTERVAL_SECONDS:-0.2}"
BASE_READY_URL="${BASE_READY_URL:-http://localhost:8080/actuator/health}"
CRAC_MATRIX_REPEATS="${CRAC_MATRIX_REPEATS:-1}"
CRAC_SMOKE="${CRAC_SMOKE:-0}"
CRAC_SMOKE_URLS="${CRAC_SMOKE_URLS:-}"
SMOKE_PROBE_IMAGE="${SMOKE_PROBE_IMAGE:-curlimages/curl:8.5.0}"
PROBE_MODE="${PROBE_MODE:-oneshot}"
CRAC_EXPORT_DIR="${CRAC_EXPORT_DIR:-}"

CRAC_DEBUG="${CRAC_DEBUG:-0}"
CRAC_MATRIX_SERVICES="${CRAC_MATRIX_SERVICES:-gateway-service,orders-service,billing-service,notification-service,analytics-service}"
RUN_CONTEXT="${RUN_CONTEXT:-matrix}"

COMPOSE_BASE=(-f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml)
TEMP_FILES=()
CID_FILES=()
MATRIX_ROWS=()

cleanup_tmp_artifacts() {
  local f
  for f in "${CID_FILES[@]:-}"; do rm -f "$f" >/dev/null 2>&1 || true; done
  for f in "${TEMP_FILES[@]:-}"; do rm -f "$f" >/dev/null 2>&1 || true; done
}
trap cleanup_tmp_artifacts EXIT

ts_ms() {
  date +%s%3N 2>/dev/null || echo $(( $(date +%s) * 1000 ))
}

debug() { [[ "${CRAC_DEBUG}" == "1" ]] && echo "DEBUG: $*" >&2 || true; }
warn() { echo "WARN: $*" >&2; }

is_number() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

detect_engine() {
  local from_opts=""
  from_opts="$(printf '%s' "${CRAC_JVM_OPTS:-}" | sed -nE 's/.*-XX:CRaCEngine=([^[:space:]]+).*/\1/p' | tail -n1)"
  if [[ -n "${from_opts}" ]]; then
    echo "${from_opts}"
  elif [[ -n "${CRAC_ENGINE:-}" ]]; then
    echo "${CRAC_ENGINE}"
  else
    echo "warp"
  fi
}

cid_file_for() {
  local svc="$1" phase="$2"
  local prefix="crac-matrix"
  if [[ "${RUN_CONTEXT}" == "demo" ]]; then
    prefix="crac"
  fi
  echo "/tmp/${prefix}.${svc}.${phase}.cid"
}

mklog() {
  local f
  f="$(mktemp "/tmp/crac.${1}.${2}.XXXXXX")"
  TEMP_FILES+=("$f")
  echo "$f"
}

docker_compose() { (cd "${REPO_ROOT}" && docker compose "${COMPOSE_BASE[@]}" "$@"); }

docker_logs_tail() {
  local cid="$1" tailn="${2:-500}"
  docker logs --tail="${tailn}" "${cid}" 2>&1 || true
}

container_log_path() {
  local svc="$1" phase="$2" repeat="${3:-}"
  local path="/tmp/crac.${svc}.${phase}"
  if [[ -n "${repeat}" ]]; then
    path="${path}.${repeat}"
  fi
  echo "${path}.container.log"
}

capture_container_logs() {
  local cid="$1" svc="$2" phase="$3" repeat="${4:-}"
  local log_path
  log_path="$(container_log_path "${svc}" "${phase}" "${repeat}")"

  # Wrapper logs capture script output; container logs capture JVM/app output.
  {
    echo "svc=${svc}"
    echo "phase=${phase}"
    if [[ -n "${repeat}" ]]; then
      echo "repeat=${repeat}"
    fi
    echo "captured_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "---- docker inspect ----"
    docker inspect -f 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "${cid}" 2>&1 || echo "inspect failed"
    echo "---- docker logs ----"
    docker logs "${cid}" 2>&1 || echo "docker logs failed"
  } >"${log_path}" 2>&1 || true
}

resolve_crac_data_volume_name() {
  local volume_name=""
  volume_name="$(docker_compose config 2>/dev/null | awk '
    $1=="volumes:" {in_volumes=1; next}
    in_volumes && $1=="services:" {in_volumes=0}
    in_volumes && $1=="crac-data:" {in_crac_data=1; next}
    in_volumes && in_crac_data && $1=="name:" {print $2; exit}
    in_volumes && in_crac_data && $1 ~ /^[A-Za-z0-9_.-]+:$/ && $1!="name:" {in_crac_data=0}
  ' | head -n1)"
  if [[ -n "${volume_name}" ]]; then
    echo "${volume_name}"
  else
    echo "acmecorp-local_crac-data"
  fi
}

checkpoint_subpath_for_service() {
  local svc="$1"
  local base="${CRAC_CHECKPOINT_BASE%/}"
  local rel="${base#/opt/crac}"
  rel="${rel#/}"
  if [[ -n "${rel}" ]]; then
    echo "${rel}/${svc}"
  else
    echo "${svc}"
  fi
}

checkpoint_artifacts_exist_in_volume() {
  local volume_name="$1" checkpoint_subpath="$2" engine="${3:-warp}"
  if [[ "${engine}" == "warp" ]]; then
    docker run --rm -v "${volume_name}:/mnt" alpine sh -lc \
      "[ -f \"/mnt/${checkpoint_subpath}/core.img\" ]" >/dev/null 2>&1
    return $?
  fi
  docker run --rm -v "${volume_name}:/mnt" alpine sh -lc \
    "d=\"/mnt/${checkpoint_subpath}\"; [ -d \"\$d\" ] && find \"\$d\" -maxdepth 1 -mindepth 1 ! -name core.img ! -name lost+found -print | grep -q ." \
    >/dev/null 2>&1
}

checkpoint_core_img_exists_in_volume() {
  local volume_name="$1" checkpoint_subpath="$2"
  docker run --rm -v "${volume_name}:/mnt" alpine sh -lc "[ -f \"/mnt/${checkpoint_subpath}/core.img\" ]" >/dev/null 2>&1
}

append_postmortem() {
  local cid="$1" log_path="$2"
  {
    echo ""
    echo "==== POSTMORTEM ===="
    docker inspect -f 'State.Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} OOMKilled={{.State.OOMKilled}}' "${cid}" 2>/dev/null || true
    echo "---- docker logs --tail=200 ----"
    docker logs --tail=200 "${cid}" 2>&1 || true
  } >> "${log_path}"
}

append_checkpoint_diagnostics() {
  local cid="$1" log_path="$2" volume_name="$3" checkpoint_subpath="$4"
  {
    echo ""
    echo "==== CHECKPOINT DIAGNOSTICS ===="
    docker inspect -f 'ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Error={{.State.Error}}' "${cid}" 2>/dev/null || true
    echo "---- docker logs --tail=120 ----"
    docker logs --tail=120 "${cid}" 2>&1 || true
    echo "---- volume listing: ${volume_name}/${checkpoint_subpath} ----"
    docker run --rm -v "${volume_name}:/mnt" alpine sh -lc \
      "ls -la \"/mnt/${checkpoint_subpath}\" 2>/dev/null || true; (du -sh \"/mnt/${checkpoint_subpath}\" 2>/dev/null || true)" 2>&1 || true
  } >> "${log_path}"
}

rm_container_quiet() { docker rm -f "$1" >/dev/null 2>&1 || true; }

is_container_running() {
  local cid="$1"
  [[ "$(docker inspect -f '{{.State.Status}}' "${cid}" 2>/dev/null || echo unknown)" == "running" ]]
}

container_exit_code() { docker inspect -f '{{.State.ExitCode}}' "$1" 2>/dev/null || echo ""; }

# ---- HTTP probe that works even if tools are missing in the app container ----
# Uses a helper container that joins the target container's network namespace.
probe_http_via_netns() {
  local cid="$1" url="$2"
  local out rc
  debug "[http] probe image=${SMOKE_PROBE_IMAGE} url=${url}"

  # Prefer direct curl (no shell dependency in the probe image)
  out="$(docker run --rm --network "container:${cid}" "${SMOKE_PROBE_IMAGE}" \
    curl -fsS --max-time 3 "${url}" >/dev/null 2>&1)"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    return 0
  fi

  # Optional fallback for environments where the primary probe image is unavailable.
  if echo "${out}" | grep -qiE 'Unable to find image|pull access denied|manifest unknown|repository does not exist|i/o timeout|TLS handshake timeout|no such host'; then
    debug "[http] primary probe image unavailable, trying alpine:3 fallback"
    out="$(docker run --rm --network "container:${cid}" alpine:3 \
      sh -lc "wget -q -T 3 -O /dev/null '${url}'" 2>&1)"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      return 0
    fi
    if echo "${out}" | grep -qiE 'Unable to find image|pull access denied|manifest unknown|repository does not exist'; then
      warn "Smoke probe image unavailable; set SMOKE_PROBE_IMAGE to an image you have locally."
    fi
  fi

  debug "[http] probe failed rc=${rc} url=${url}"
  return 1
}

probe_http_via_netns_loop() {
  local cid="$1" url="$2" max_seconds="$3"
  local out rc
  debug "[http] loop probe image=${SMOKE_PROBE_IMAGE} url=${url} max_seconds=${max_seconds}"

  out="$(docker run --rm --network "container:${cid}" "${SMOKE_PROBE_IMAGE}" \
    sh -lc "end=\$((\$(date +%s)+${max_seconds})); while [ \$(date +%s) -lt \$end ]; do curl -fsS --max-time 3 \"${url}\" >/dev/null 2>&1 && exit 0; sleep 0.2; done; exit 124" 2>&1)"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    return 0
  fi
  debug "[http] loop probe failed rc=${rc} url=${url} out=${out}"
  return "${rc}"
}

# ---- Base readiness (inside container) still uses compose exec; keep old fallback for base run ----
probe_http_cmd() {
  local url="$1"
  cat <<HTTP
if command -v curl >/dev/null 2>&1; then
  curl -fsS '${url}' >/dev/null 2>&1
elif command -v wget >/dev/null 2>&1; then
  wget -qO- '${url}' >/dev/null 2>&1
elif command -v busybox >/dev/null 2>&1; then
  busybox wget -qO- '${url}' >/dev/null 2>&1
else
  exit 127
fi
HTTP
}

probe_http_compose_exec() {
  local svc="$1" url="$2"
  docker_compose exec -T "${svc}" sh -lc "$(probe_http_cmd "${url}")" >/dev/null 2>&1
}

probe_http_docker_exec() {
  local cid="$1" url="$2"
  docker exec -T "${cid}" sh -lc "$(probe_http_cmd "${url}")" >/dev/null 2>&1
}

# ---- Smoke checks ----
smoke_paths_for_service() {
  local svc="$1"
  local default_paths="/actuator/health"
  local raw="${CRAC_SMOKE_URLS:-}"
  if [[ -z "${raw}" ]]; then
    echo "${default_paths}"
    return 0
  fi

  local token trimmed key val fallback=""
  IFS=',' read -r -a tokens <<<"${raw}"
  for token in "${tokens[@]}"; do
    trimmed="$(echo "${token}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -n "${trimmed}" ]] || continue
    if [[ "${trimmed}" == *=* ]]; then
      key="${trimmed%%=*}"
      val="${trimmed#*=}"
      key="$(echo "${key}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
      if [[ "${key}" == "${svc}" ]]; then
        echo "${val}"
        return 0
      fi
    else
      fallback="${trimmed}"
    fi
  done

  if [[ -n "${fallback}" ]]; then
    echo "${fallback}"
  else
    echo "${default_paths}"
  fi
}

run_smoke_checks() {
  local svc="$1" cid="$2"
  [[ "${CRAC_SMOKE}" == "1" ]] || return 0

  local spec path url
  spec="$(smoke_paths_for_service "${svc}")"
  debug "[${svc}] smoke paths=${spec}"

  IFS=';' read -r -a paths <<<"${spec}"
  for path in "${paths[@]}"; do
    path="$(echo "${path}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -n "${path}" ]] || continue
    if [[ "${path}" =~ ^https?:// ]]; then
      url="${path}"
    else
      if [[ "${path}" =~ ^/ ]]; then
        url="http://localhost:8080${path}"
      else
        url="http://localhost:8080/${path}"
      fi
    fi

    if ! probe_http_via_netns "${cid}" "${url}"; then
      warn "[${svc}] smoke failed for ${url}"
      return 1
    fi
  done
  return 0
}

# ---- Base up/down ----
base_up() {
  local svc="$1" log_path="$2"
  {
    echo "base_up ${svc} at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    docker_compose up -d "${svc}"
  } >"${log_path}" 2>&1
}

base_stop() {
  local svc="$1"
  docker_compose stop "${svc}" >/dev/null 2>&1 || true
}

service_container_id() {
  local svc="$1"
  docker_compose ps -q "${svc}" 2>/dev/null | head -n1
}

# ---- Base readiness (via netns probe) ----
wait_base_ready_netns() {
  local svc="$1" cid="$2" max_seconds="$3" url="$4" log_path="$5"
  local start end now
  start="$(date +%s)"; end=$((start + max_seconds))

  {
    echo "base_ready url=${url} cid=${cid}"
  } >>"${log_path}" 2>&1 || true

  while true; do
    now="$(date +%s)"
    if (( now >= end )); then
      warn "[${svc}] base readiness timeout; log: ${log_path}"
      return 124
    fi

    if probe_http_via_netns "${cid}" "${url}"; then
      return 0
    fi

    sleep "${RESTORE_POLL_INTERVAL_SECONDS}"
  done
}

extract_restore_jvm_ms() {
  local log_path="$1"
  sed -nE 's/.*restored JVM running for ([0-9]+) ms.*/\1/p' "${log_path}" | tail -n1
}

# ---- Detached run for checkpoint/restore ----
run_detached() {
  local svc="$1" phase="$2" checkpoint_dir="$3"
  local cid_file; cid_file="$(cid_file_for "${svc}" "${phase}")"
  rm -f "${cid_file}" >/dev/null 2>&1 || true

  local cmd=(run -d -T -e "CRAC_MODE=${phase}" -e "CRAC_CHECKPOINT_DIR=${checkpoint_dir}" "${svc}")
  debug "docker compose ${COMPOSE_BASE[*]} ${cmd[*]}"
  local cid
  cid="$(docker_compose "${cmd[@]}" 2>/dev/null | tail -n1 || true)"
  [[ -n "${cid}" ]] || return 1
  echo "${cid}" > "${cid_file}"
  CID_FILES+=("${cid_file}")
  debug "[${svc}][${phase}] cid=${cid} (file: ${cid_file})"
  echo "${cid}"
}

poll_checkpoint() {
  local svc="$1" cid="$2" log_path="$3" max_seconds="$4"
  local start end now
  start="$(date +%s)"; end=$((start + max_seconds))

  while true; do
    now="$(date +%s)"
    if (( now >= end )); then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      append_postmortem "${cid}" "${log_path}"
      return 124
    fi

    if ! is_container_running "${cid}"; then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      local ec; ec="$(container_exit_code "${cid}")"
      if [[ -n "${ec}" && "${ec}" != "0" ]]; then
        append_postmortem "${cid}" "${log_path}"
      fi
      echo "${ec:-1}"
      return 0
    fi

    docker_logs_tail "${cid}" 800 > "${log_path}" 2>&1 || true
    sleep 1
  done
}

poll_restore() {
  local svc="$1" cid="$2" log_path="$3" max_seconds="$4"
  local start end now
  start="$(date +%s)"; end=$((start + max_seconds))

  local warp_ok=0
  local probe_cid=""
  local probe_mode="${PROBE_MODE}"
  local probe_seconds="${max_seconds}"
  if (( probe_seconds < 1 )); then
    probe_seconds=1
  fi

  if [[ "${probe_mode}" == "loop" ]]; then
    probe_cid="$(docker run -d --rm --network "container:${cid}" "${SMOKE_PROBE_IMAGE}" \
      sh -lc "end=\$((\$(date +%s)+${probe_seconds})); while [ \$(date +%s) -lt \$end ]; do curl -fsS --max-time 3 \"http://localhost:8080/actuator/health\" >/dev/null 2>&1 && exit 0; sleep 0.2; done; exit 124" 2>/dev/null | tail -n1 || true)"
    if [[ -z "${probe_cid}" ]]; then
      debug "[${svc}] probe loop container failed to start; falling back to log-only checks"
      probe_mode="disabled"
    fi
  fi

  local probe_status=""
  local probe_exit=""
  probe_cleanup() {
    if [[ -n "${probe_cid}" ]]; then
      docker rm -f "${probe_cid}" >/dev/null 2>&1 || true
    fi
  }

  while true; do
    now="$(date +%s)"
    if (( now >= end )); then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      append_postmortem "${cid}" "${log_path}"
      probe_cleanup
      return 124
    fi

    if ! is_container_running "${cid}"; then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      append_postmortem "${cid}" "${log_path}"
      probe_cleanup
      return 1
    fi

    if [[ "${probe_mode}" == "loop" && -n "${probe_cid}" ]]; then
      probe_status="$(docker inspect -f '{{.State.Status}}' "${probe_cid}" 2>/dev/null || true)"
      if [[ "${probe_status}" == "exited" ]]; then
        probe_exit="$(docker inspect -f '{{.State.ExitCode}}' "${probe_cid}" 2>/dev/null || echo 1)"
        probe_cleanup
        if [[ "${probe_exit}" == "0" ]]; then
          return 0
        fi
        if [[ "${probe_exit}" == "124" ]]; then
          return 124
        fi
        return 1
      fi
    fi

    docker_logs_tail "${cid}" 1200 > "${log_path}" 2>&1 || true
    grep -q 'warp: Restore successful!' "${log_path}" && warp_ok=1 || true

    # Spring CRaC restore marker (timing parsed after poll)
    if grep -q 'Spring-managed lifecycle restart completed' "${log_path}"; then
      if [[ "${probe_mode}" == "oneshot" ]]; then
        if probe_http_via_netns "${cid}" "http://localhost:8080/actuator/health"; then
          probe_cleanup
          return 0
        fi
      fi
    fi

    # Fallbacks
    if grep -q 'Netty started on port' "${log_path}" && [[ "${warp_ok}" == "1" ]]; then
      probe_cleanup
      return 0
    fi
    # Use netns probe so we don't depend on curl in the app container
    if [[ "${probe_mode}" == "oneshot" ]]; then
      if probe_http_via_netns "${cid}" "http://localhost:8080/actuator/health"; then
        probe_cleanup
        return 0
      fi
    fi

    sleep 1
  done
}

host_port_for() {
  case "$1" in
    gateway-service|orders-service|billing-service|notification-service|analytics-service) echo "8080" ;;
    *) echo "8080" ;;
  esac
}

is_crac_capable() {
  case "$1" in
    gateway-service|orders-service|billing-service|notification-service|analytics-service) echo "YES" ;;
    *) echo "NO" ;;
  esac
}

# ---- Stats (FIXED): sort numeric samples before min/max/percentiles ----
percentile_from_sorted_file() {
  local file="$1" pct="$2"
  local n rank
  n="$(wc -l <"${file}" | tr -d ' ')"
  if (( n <= 0 )); then
    echo ""
    return 0
  fi
  # Nearest-rank percentile: rank = ceil(pct/100 * n)
  rank=$(( (pct * n + 99) / 100 ))
  (( rank < 1 )) && rank=1
  (( rank > n )) && rank=n
  sed -n "${rank}p" "${file}"
}

median_from_sorted_file() {
  local file="$1"
  local n a b
  n="$(wc -l <"${file}" | tr -d ' ')"
  if (( n <= 0 )); then
    echo ""
    return 0
  fi

  if (( n % 2 == 1 )); then
    sed -n "$(( (n + 1) / 2 ))p" "${file}"
  else
    a="$(sed -n "$(( n / 2 ))p" "${file}")"
    b="$(sed -n "$(( n / 2 + 1 ))p" "${file}")"
    awk -v a="${a}" -v b="${b}" 'BEGIN{printf("%d\n", (a+b+1)/2)}'
  fi
}

compute_restore_stats() {
  local stats_file="$1"
  local sorted_file n min med p95 max

  sorted_file="$(mklog "crac" "restore-sorted")"
  awk '/^[0-9]+$/' "${stats_file}" | sort -n > "${sorted_file}" || true

  n="$(wc -l <"${sorted_file}" | tr -d ' ')"
  if (( n <= 0 )); then
    echo "N/A|N/A"
    return 0
  fi

  min="$(head -n1 "${sorted_file}")"
  med="$(median_from_sorted_file "${sorted_file}")"
  p95="$(percentile_from_sorted_file "${sorted_file}" 95)"
  max="$(tail -n1 "${sorted_file}")"

  echo "${med}|min=${min} med=${med} p95=${p95} max=${max} n=${n}"
}

print_matrix_header() {
  echo "| service | host_port | crac_capable | snapshot_created | checkpoint_exit | normal_ready_ms | restore_ready_ms | restore_jvm_ms | post_restore_ms | restore_stats | reason |"
  echo "|---|---:|:---:|:---:|---:|---:|---:|---:|---:|---|---|"
}

emit_matrix_row() {
  local svc="$1" port="$2" crac_capable="$3" snapshot_created="$4" checkpoint_exit="$5" normal_ready_ms="$6" restore_ready_ms="$7" restore_jvm_ms="$8" post_restore_ms="$9" restore_stats="${10}" reason="${11}"
  local row="| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | ${normal_ready_ms} | ${restore_ready_ms} | ${restore_jvm_ms} | ${post_restore_ms} | ${restore_stats} | ${reason} |"
  echo "${row}"
  MATRIX_ROWS+=("${row}")
}

export_results() {
  [[ -n "${CRAC_EXPORT_DIR}" ]] || return 0

  local ts run_dir matrix_md csv_out summary_md branch commit engine
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  run_dir="${CRAC_EXPORT_DIR%/}/${ts}"
  mkdir -p "${run_dir}"

  matrix_md="${run_dir}/matrix.md"
  csv_out="${run_dir}/matrix.csv"
  summary_md="${run_dir}/summary.md"

  {
    print_matrix_header
    for row in "${MATRIX_ROWS[@]:-}"; do
      echo "${row}"
    done
  } >"${matrix_md}"

  branch="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  commit="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  engine="$(detect_engine)"

  if python3 "${REPO_ROOT}/scripts/crac-export.py" \
      --matrix-md "${matrix_md}" \
      --csv-out "${csv_out}" \
      --summary-out "${summary_md}" \
      --timestamp "${ts}" \
      --branch "${branch}" \
      --commit "${commit}" \
      --engine "${engine}" \
      --services "${CRAC_MATRIX_SERVICES}" \
      --repeats "${CRAC_MATRIX_REPEATS}" \
      --smoke "${CRAC_SMOKE}" \
      --smoke-urls "${CRAC_SMOKE_URLS}" \
      --checkpoint-poll "${CRAC_CHECKPOINT_POLL_MAX_SECONDS}" \
      --restore-poll "${CRAC_RESTORE_POLL_MAX_SECONDS}"; then
    echo "Exported results to ${run_dir}"
  else
    warn "Export helper failed; matrix.md still available at ${matrix_md}"
  fi

  local raw_dir
  raw_dir="${run_dir}/raw"
  mkdir -p "${raw_dir}"
  local -a raw_files=()
  shopt -s nullglob
  raw_files=(/tmp/crac.*.checkpoint.* /tmp/crac.*.restore.* /tmp/crac.*.container.log /tmp/crac.*.restore-ms.* /tmp/crac.*.restore-jvm-ms.* /tmp/crac.*.restore-post-ms.* /tmp/crac.*.checkpoint-ms.*)
  shopt -u nullglob
  if (( ${#raw_files[@]} > 0 )); then
    cp -f "${raw_files[@]}" "${raw_dir}/" 2>/dev/null || true
  fi
}

CRAC_DATA_VOLUME_NAME=""

matrix_one_service() {
  local svc="$1"
  local port crac_capable
  port="$(host_port_for "${svc}")"
  crac_capable="$(is_crac_capable "${svc}")"

  local snapshot_created="NO"
  local checkpoint_exit="N/A"
  local normal_ready_ms="N/A"
  local restore_ready_ms="N/A"
  local restore_jvm_ms="N/A"
  local post_restore_ms="N/A"
  local restore_stats="N/A"
  local reason=""
  local checkpoint_state="CHECKPOINT_EMPTY"
  local engine
  engine="$(detect_engine)"

  echo "-> [${svc}] base up"
  local base_log; base_log="$(mklog "${svc}" "base")"
  if ! base_up "${svc}" "${base_log}"; then
    reason="BASE_UP_FAILED"
    warn "[${svc}] base up failed; see ${base_log}"
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "TIMEOUT" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    return 0
  fi

  echo "-> [${svc}] wait normal readiness (inside container)"
  local t0 t1
  t0="$(ts_ms)"
  local base_cid
  base_cid="$(service_container_id "${svc}")"
  if [[ -z "${base_cid}" ]]; then
    reason="BASE_READY_TIMEOUT"
    warn "[${svc}] base container id not found; see ${base_log}"
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "TIMEOUT" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    base_stop "${svc}"
    return 0
  fi
  if ! wait_base_ready_netns "${svc}" "${base_cid}" "${BASE_READY_MAX_SECONDS}" "${BASE_READY_URL}" "${base_log}"; then
    reason="BASE_READY_TIMEOUT"
    warn "[${svc}] base readiness failed/timeout; see ${base_log}"
    capture_container_logs "${base_cid}" "${svc}" "base"
    base_stop "${svc}"
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "TIMEOUT" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    return 0
  fi
  t1="$(ts_ms)"
  normal_ready_ms="$((t1 - t0))"

  echo "-> [${svc}] base stop"
  base_stop "${svc}"

  if [[ "${crac_capable}" != "YES" ]]; then
    reason="NOT_CRAC_CAPABLE"
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "${normal_ready_ms}" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    return 0
  fi

  echo "-> [${svc}] checkpoint"
  local ck_dir="${CRAC_CHECKPOINT_BASE}/${svc}"
  local ck_log; ck_log="$(mklog "${svc}" "checkpoint")"
  local checkpoint_subpath
  checkpoint_subpath="$(checkpoint_subpath_for_service "${svc}")"
  local crac_volume="${CRAC_DATA_VOLUME_NAME:-$(resolve_crac_data_volume_name)}"
  local ck_cid
  if ! ck_cid="$(run_detached "${svc}" "checkpoint" "${ck_dir}")"; then
    reason="CHECKPOINT_RUN_FAILED"
    warn "[${svc}] checkpoint run failed"
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "1" "${normal_ready_ms}" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    return 0
  fi

  local poll_ec=""
  if ! poll_ec="$(poll_checkpoint "${svc}" "${ck_cid}" "${ck_log}" "${CRAC_CHECKPOINT_POLL_MAX_SECONDS}")"; then
    checkpoint_exit="124"
    reason="CHECKPOINT_FAILED"
    checkpoint_state="CHECKPOINT_FAILED"
    warn "[${svc}] checkpoint timeout; log: ${ck_log}"
    append_checkpoint_diagnostics "${ck_cid}" "${ck_log}" "${crac_volume}" "${checkpoint_subpath}"
    capture_container_logs "${ck_cid}" "${svc}" "checkpoint"
    rm_container_quiet "${ck_cid}"
    rm -f "$(cid_file_for "${svc}" "checkpoint")" >/dev/null 2>&1 || true
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "${normal_ready_ms}" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    return 0
  fi
  checkpoint_exit="${poll_ec:-1}"
  capture_container_logs "${ck_cid}" "${svc}" "checkpoint"

  local has_artifacts="NO"
  local has_core_img="NO"
  if checkpoint_artifacts_exist_in_volume "${crac_volume}" "${checkpoint_subpath}" "${engine}"; then has_artifacts="YES"; fi
  if checkpoint_core_img_exists_in_volume "${crac_volume}" "${checkpoint_subpath}"; then has_core_img="YES"; fi
  snapshot_created="${has_artifacts}"

  if [[ "${engine}" == "warp" && "${has_core_img}" == "YES" ]]; then
    checkpoint_state="CHECKPOINT_WARP_OK"
  elif [[ "${snapshot_created}" == "YES" ]]; then
    checkpoint_state="CHECKPOINT_OK"
  elif [[ "${checkpoint_exit}" != "0" && "${checkpoint_exit}" != "N/A" ]]; then
    checkpoint_state="CHECKPOINT_CRASH"
  elif [[ "${has_core_img}" == "YES" ]]; then
    checkpoint_state="CHECKPOINT_CORE_ONLY"
  else
    checkpoint_state="CHECKPOINT_EMPTY"
  fi
  debug "[${svc}] engine=${engine} checkpoint status=${checkpoint_state} (rc=${checkpoint_exit}, artifacts=${snapshot_created}, core_img=${has_core_img})"

  if [[ "${checkpoint_state}" != "CHECKPOINT_OK" && "${checkpoint_state}" != "CHECKPOINT_WARP_OK" ]]; then
    case "${checkpoint_state}" in
      CHECKPOINT_CRASH) reason="CHECKPOINT_CRASH" ;;
      CHECKPOINT_CORE_ONLY) reason="CHECKPOINT_CORE_ONLY" ;;
      CHECKPOINT_EMPTY) reason="CHECKPOINT_EMPTY" ;;
      *) reason="CHECKPOINT_FAILED" ;;
    esac
    if [[ "${checkpoint_state}" == "CHECKPOINT_CRASH" || "${checkpoint_state}" == "CHECKPOINT_CORE_ONLY" ]]; then
      append_checkpoint_diagnostics "${ck_cid}" "${ck_log}" "${crac_volume}" "${checkpoint_subpath}"
    fi
    warn "[${svc}] checkpoint status=${checkpoint_state} (rc=${checkpoint_exit}, artifacts=${snapshot_created}, core_img=${has_core_img}, volume_path=${crac_volume}/${checkpoint_subpath}); log: ${ck_log}"
    warn "[${svc}] skipping restore because checkpoint is not restoreable"
    rm_container_quiet "${ck_cid}"
    rm -f "$(cid_file_for "${svc}" "checkpoint")" >/dev/null 2>&1 || true
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "${normal_ready_ms}" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    return 0
  fi

  snapshot_created="YES"
  reason="${checkpoint_state}"
  rm_container_quiet "${ck_cid}"
  rm -f "$(cid_file_for "${svc}" "checkpoint")" >/dev/null 2>&1 || true

  local repeats="${CRAC_MATRIX_REPEATS}"
  if ! is_number "${repeats}" || (( repeats < 1 )); then
    repeats=1
  fi

  local stats_ready_tmp stats_jvm_tmp stats_post_tmp rs_cid rs_log rs_fail="0" i
  stats_ready_tmp="$(mklog "${svc}" "restore-ready-ms-agg")"
  stats_jvm_tmp="$(mklog "${svc}" "restore-jvm-ms-agg")"
  stats_post_tmp="$(mklog "${svc}" "restore-post-ms-agg")"

  for (( i=1; i<=repeats; i++ )); do
    echo "-> [${svc}] restore (${i}/${repeats})"
    rs_log="$(mklog "${svc}" "restore.${i}")"
    local rs_ready_file rs_jvm_file rs_post_file
    rs_ready_file="/tmp/crac.${svc}.restore-ms.${i}"
    rs_jvm_file="/tmp/crac.${svc}.restore-jvm-ms.${i}"
    rs_post_file="/tmp/crac.${svc}.restore-post-ms.${i}"
    rm -f "${rs_ready_file}" "${rs_jvm_file}" "${rs_post_file}" >/dev/null 2>&1 || true
    local t_restore0
    t_restore0="$(ts_ms)"

    if ! rs_cid="$(run_detached "${svc}" "restore" "${ck_dir}")"; then
      reason="RESTORE_RUN_FAILED"
      warn "[${svc}] restore run failed"
      rs_fail="1"
      break
    fi

    if poll_restore "${svc}" "${rs_cid}" "${rs_log}" "${CRAC_RESTORE_POLL_MAX_SECONDS}"; then
      capture_container_logs "${rs_cid}" "${svc}" "restore" "${i}"
      if [[ "${CRAC_SMOKE}" == "1" ]]; then
        if ! run_smoke_checks "${svc}" "${rs_cid}"; then
          reason="SMOKE_FAILED"
          rs_fail="1"
          rm_container_quiet "${rs_cid}"
          rm -f "$(cid_file_for "${svc}" "restore")" >/dev/null 2>&1 || true
          break
        fi
      fi
      local t_restore1 ready_ms jvm_ms post_ms
      t_restore1="$(ts_ms)"
      ready_ms=$(( t_restore1 - t_restore0 ))
      jvm_ms="$(extract_restore_jvm_ms "${rs_log}")"

      if is_number "${ready_ms}"; then
        echo "${ready_ms}" >"${rs_ready_file}"
        echo "${ready_ms}" >>"${stats_ready_tmp}"
      else
        warn "[${svc}] restore ready timing not numeric; skipping sample for repeat ${i}"
      fi

      if is_number "${jvm_ms}"; then
        echo "${jvm_ms}" >"${rs_jvm_file}"
        echo "${jvm_ms}" >>"${stats_jvm_tmp}"
      fi

      if is_number "${ready_ms}" && is_number "${jvm_ms}"; then
        post_ms=$(( ready_ms - jvm_ms ))
        if (( post_ms < 0 )); then
          post_ms=0
        fi
        echo "${post_ms}" >"${rs_post_file}"
        echo "${post_ms}" >>"${stats_post_tmp}"
      fi
    else
      local rc=$?
      if [[ $rc -eq 124 ]]; then
        reason="RESTORE_TIMEOUT"
        warn "[${svc}] restore timeout; log: ${rs_log}"
      else
        reason="RESTORE_FAILED"
        warn "[${svc}] restore failed; log: ${rs_log}"
      fi
      capture_container_logs "${rs_cid}" "${svc}" "restore" "${i}"
      rs_fail="1"
      rm_container_quiet "${rs_cid}"
      rm -f "$(cid_file_for "${svc}" "restore")" >/dev/null 2>&1 || true
      break
    fi

    rm_container_quiet "${rs_cid}"
    rm -f "$(cid_file_for "${svc}" "restore")" >/dev/null 2>&1 || true
  done

  if [[ "${CRAC_DEBUG}" == "1" ]]; then
    debug "[${svc}] restore samples ready(ms): $(tr '\n' ' ' < "${stats_ready_tmp}" 2>/dev/null || true)"
    debug "[${svc}] restore samples jvm(ms): $(tr '\n' ' ' < "${stats_jvm_tmp}" 2>/dev/null || true)"
    debug "[${svc}] restore samples post(ms): $(tr '\n' ' ' < "${stats_post_tmp}" 2>/dev/null || true)"
  fi

  if [[ "${rs_fail}" == "1" ]]; then
    restore_ready_ms="N/A"
    restore_jvm_ms="N/A"
    post_restore_ms="N/A"
    restore_stats="N/A"
  else
    local ready_comp jvm_comp post_comp ready_stats jvm_stats post_stats
    ready_comp="$(compute_restore_stats "${stats_ready_tmp}")"
    jvm_comp="$(compute_restore_stats "${stats_jvm_tmp}")"
    post_comp="$(compute_restore_stats "${stats_post_tmp}")"
    restore_ready_ms="${ready_comp%%|*}"
    restore_jvm_ms="${jvm_comp%%|*}"
    post_restore_ms="${post_comp%%|*}"
    ready_stats="${ready_comp#*|}"
    jvm_stats="${jvm_comp#*|}"
    post_stats="${post_comp#*|}"
    restore_stats="ready(${ready_stats}) jvm(${jvm_stats}) post(${post_stats})"
    reason="${checkpoint_state}"
  fi

  emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "${normal_ready_ms}" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
}

run_matrix() {
  RUN_CONTEXT="${RUN_CONTEXT:-matrix}"
  CRAC_DATA_VOLUME_NAME="$(resolve_crac_data_volume_name)"
  debug "Resolved crac-data volume: ${CRAC_DATA_VOLUME_NAME}"

  print_matrix_header
  IFS=',' read -r -a svcs <<< "${CRAC_MATRIX_SERVICES}"
  for svc in "${svcs[@]}"; do
    svc="$(echo "${svc}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -n "${svc}" ]] || continue
    matrix_one_service "${svc}"
  done

  export_results
}

run_demo() {
  local svc="${1:-}"
  [[ -n "${svc}" ]] || { echo "Usage: $0 demo <service>" >&2; exit 2; }
  RUN_CONTEXT="demo"
  CRAC_MATRIX_SERVICES="${svc}"
  run_matrix
}

main() {
  case "${1:-}" in
    matrix) run_matrix ;;
    demo) shift; run_demo "${1:-}" ;;
    *) echo "Usage: $0 {matrix|demo <service>}" >&2; exit 2 ;;
  esac
}

main "$@"
