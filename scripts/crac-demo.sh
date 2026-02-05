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
#   RESTORE_POLL_INTERVAL_SECONDS=0.05
#   BASE_READY_URL=http://localhost:8080/actuator/health
#   CRAC_MATRIX_REPEATS=1
#   CRAC_SMOKE=0
#   CRAC_SMOKE_URLS="orders-service=/actuator/health;/actuator/info,billing-service=/actuator/health"
#   SMOKE_PROBE_IMAGE=curlimages/curl:8.5.0
#   PROBE_MODE=oneshot|loop
#   RESTORE_DEBUG_HTTP=0
#   CRAC_CLEANUP=1
#   CRAC_EXPORT_DIR=/tmp/crac-results
#   CRAC_DEBUG=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CRAC_CHECKPOINT_BASE="${CRAC_CHECKPOINT_BASE:-/opt/crac}"
CRAC_POLL_MAX_SECONDS="${CRAC_POLL_MAX_SECONDS:-}"

CRAC_CHECKPOINT_POLL_MAX_SECONDS="${CRAC_CHECKPOINT_POLL_MAX_SECONDS:-${CRAC_POLL_MAX_SECONDS:-180}}"
CRAC_RESTORE_POLL_MAX_SECONDS="${CRAC_RESTORE_POLL_MAX_SECONDS:-${CRAC_POLL_MAX_SECONDS:-60}}"

BASE_READY_MAX_SECONDS="${BASE_READY_MAX_SECONDS:-180}"
RESTORE_POLL_INTERVAL_SECONDS="${RESTORE_POLL_INTERVAL_SECONDS:-0.05}"
BASE_READY_URL="${BASE_READY_URL:-http://localhost:8080/actuator/health}"
CRAC_MATRIX_REPEATS="${CRAC_MATRIX_REPEATS:-1}"
CRAC_SMOKE="${CRAC_SMOKE:-0}"
CRAC_SMOKE_URLS="${CRAC_SMOKE_URLS:-}"
SMOKE_PROBE_IMAGE="${SMOKE_PROBE_IMAGE:-curlimages/curl:8.5.0}"
PROBE_MODE="${PROBE_MODE:-oneshot}"
RESTORE_DEBUG_HTTP="${RESTORE_DEBUG_HTTP:-0}"
CRAC_CLEANUP="${CRAC_CLEANUP:-1}"
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
  for f in "${CID_FILES[@]:-}"; do
    # keep restore cid files if requested
    if [[ "${CRAC_CLEANUP}" == "0" && "${f}" == *".restore.cid" ]]; then
      continue
    fi
    rm -f "$f" >/dev/null 2>&1 || true
  done
  for f in "${TEMP_FILES[@]:-}"; do
    rm -f "$f" >/dev/null 2>&1 || true
  done
}
trap cleanup_tmp_artifacts EXIT

ts_ms() {
  date +%s%3N 2>/dev/null || echo $(( $(date +%s) * 1000 ))
}

debug() { [[ "${CRAC_DEBUG}" == "1" ]] && echo "DEBUG: $*" >&2 || true; }
warn() { echo "WARN: $*" >&2; }

is_number() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

docker_compose() { (cd "${REPO_ROOT}" && docker compose "${COMPOSE_BASE[@]}" "$@"); }

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

  {
    echo "svc=${svc}"
    echo "phase=${phase}"
    [[ -n "${repeat}" ]] && echo "repeat=${repeat}"
    echo "captured_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "---- docker inspect ----"
    docker inspect -f 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "${cid}" 2>&1 || echo "inspect failed"
    echo "---- docker logs ----"
    docker logs "${cid}" 2>&1 || echo "docker logs failed"
  } >"${log_path}" 2>&1 || true
}

rm_container_quiet() { docker rm -f "$1" >/dev/null 2>&1 || true; }

is_container_running() {
  local cid="$1"
  [[ "$(docker inspect -f '{{.State.Status}}' "${cid}" 2>/dev/null || echo unknown)" == "running" ]]
}

container_exit_code() { docker inspect -f '{{.State.ExitCode}}' "$1" 2>/dev/null || echo ""; }

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

# ---- Probe via netns helper container (no dependency on curl inside app container) ----
probe_http_via_netns() {
  local cid="$1" url="$2"
  debug "[http] oneshot probe image=${SMOKE_PROBE_IMAGE} url=${url}"
  docker run --rm --network "container:${cid}" "${SMOKE_PROBE_IMAGE}" \
    curl -fsS --max-time 3 "${url}" >/dev/null 2>&1
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

wait_base_ready_netns() {
  local svc="$1" cid="$2" max_seconds="$3" url="$4" log_path="$5"
  local start end now
  start="$(date +%s)"; end=$((start + max_seconds))

  echo "base_ready url=${url} cid=${cid}" >>"${log_path}" 2>&1 || true

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
      [[ -z "${ec}" ]] && ec="1"
      echo "${ec}"
      return 0
    fi

    docker_logs_tail "${cid}" 800 > "${log_path}" 2>&1 || true
    sleep 1
  done
}

# ---- RESTORE polling (oneshot or loop) ----
poll_restore() {
  local svc="$1" cid="$2" log_path="$3" max_seconds="$4"
  local start end now
  start="$(date +%s)"; end=$((start + max_seconds))

  local probe_mode="${PROBE_MODE}"
  local probe_cid=""
  local probe_exit=""

  # Start loop probe container ONCE (NO --rm!) and observe it.
  if [[ "${probe_mode}" == "loop" ]]; then
    probe_cid="$(
      docker run -d --network "container:${cid}" "${SMOKE_PROBE_IMAGE}" \
        sh -lc '
          now_ms() { date +%s%3N 2>/dev/null || echo $(( $(date +%s) * 1000 )); }
          start=$(now_ms)
          end=$(( $(date +%s) + '"${max_seconds}"' ))
          first_200=""
          last_non=""

          while [ $(date +%s) -lt "$end" ]; do
            code=$(curl -sS --max-time 3 -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health 2>/dev/null || echo 000)
            now=$(now_ms); elapsed=$(( now - start ))
            if [ "$code" = "200" ]; then
              if [ -z "$first_200" ]; then first_200="$elapsed"; fi
              echo "probe_summary duration_ms=${elapsed} first_200_ms=${first_200} last_non200=${last_non:-none}"
              exit 0
            fi
            last_non="$code"
            sleep 0.2
          done

          dur=$(( $(now_ms) - start ))
          echo "probe_summary duration_ms=${dur} first_200_ms=${first_200:-none} last_non200=${last_non:-none}"
          exit 124
        ' 2>/dev/null | tail -n1 || true
    )"
    if [[ -z "${probe_cid}" ]]; then
      warn "[${svc}] loop probe container failed to start; falling back to oneshot"
      probe_mode="oneshot"
    fi
  fi

  append_probe_summary() {
    if [[ "${RESTORE_DEBUG_HTTP}" == "1" && -n "${probe_cid}" ]]; then
      {
        echo "---- probe summary ----"
        docker logs --tail=50 "${probe_cid}" 2>&1 || true
      } >> "${log_path}" 2>&1 || true
    fi
  }

  probe_cleanup() {
    if [[ -n "${probe_cid}" ]]; then
      rm_container_quiet "${probe_cid}"
    fi
  }

  while true; do
    now="$(date +%s)"
    if (( now >= end )); then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      append_postmortem "${cid}" "${log_path}"
      append_probe_summary
      probe_cleanup
      return 124
    fi

    if ! is_container_running "${cid}"; then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      append_postmortem "${cid}" "${log_path}"
      append_probe_summary
      probe_cleanup
      return 1
    fi

    # If loop probe exists, check if it finished.
    if [[ "${probe_mode}" == "loop" && -n "${probe_cid}" ]]; then
      local ps
      ps="$(docker inspect -f '{{.State.Status}}' "${probe_cid}" 2>/dev/null || echo missing)"
      if [[ "${ps}" == "exited" ]]; then
        probe_exit="$(docker inspect -f '{{.State.ExitCode}}' "${probe_cid}" 2>/dev/null || echo 1)"
        append_probe_summary
        probe_cleanup
        if [[ "${probe_exit}" == "0" ]]; then
          return 0
        elif [[ "${probe_exit}" == "124" ]]; then
          return 124
        else
          return 1
        fi
      elif [[ "${ps}" == "missing" ]]; then
        # Defensive: probe got removed externally; degrade to oneshot
        warn "[${svc}] loop probe container disappeared; degrading to oneshot"
        probe_cid=""
        probe_mode="oneshot"
      fi
    fi

    docker_logs_tail "${cid}" 1200 > "${log_path}" 2>&1 || true

    # If oneshot: try as soon as the JVM is plausibly up.
    if [[ "${probe_mode}" == "oneshot" ]]; then
      if grep -q 'Spring-managed lifecycle restart completed' "${log_path}" || grep -q 'warp: Restore successful!' "${log_path}"; then
        if probe_http_via_netns "${cid}" "http://localhost:8080/actuator/health"; then
          append_probe_summary
          probe_cleanup
          return 0
        fi
        if [[ "${RESTORE_DEBUG_HTTP}" == "1" ]]; then
          {
            echo "---- oneshot probe failed ----"
            docker run --rm --network "container:${cid}" "${SMOKE_PROBE_IMAGE}" \
              curl -sv --max-time 3 "http://localhost:8080/actuator/health" 2>&1 | tail -n 20
          } >> "${log_path}" 2>&1 || true
        fi
      fi
    fi

    sleep "${RESTORE_POLL_INTERVAL_SECONDS}"
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

# ---- Stats helpers ----
percentile_from_sorted_file() {
  local file="$1" pct="$2"
  local n rank
  n="$(wc -l <"${file}" | tr -d ' ')"
  (( n <= 0 )) && { echo ""; return 0; }
  rank=$(( (pct * n + 99) / 100 ))
  (( rank < 1 )) && rank=1
  (( rank > n )) && rank=n
  sed -n "${rank}p" "${file}"
}

median_from_sorted_file() {
  local file="$1"
  local n a b
  n="$(wc -l <"${file}" | tr -d ' ')"
  (( n <= 0 )) && { echo ""; return 0; }
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

  local ts run_dir matrix_md
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  run_dir="${CRAC_EXPORT_DIR%/}/${ts}"
  mkdir -p "${run_dir}"
  matrix_md="${run_dir}/matrix.md"

  {
    print_matrix_header
    for row in "${MATRIX_ROWS[@]:-}"; do
      echo "${row}"
    done
  } >"${matrix_md}"

  echo "Exported results to ${run_dir}"
}

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
    base_stop "${svc}"
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "TIMEOUT" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
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
  local ck_cid
  if ! ck_cid="$(run_detached "${svc}" "checkpoint" "${ck_dir}")"; then
    reason="CHECKPOINT_RUN_FAILED"
    warn "[${svc}] checkpoint run failed"
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "1" "${normal_ready_ms}" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
    return 0
  fi

  local poll_ec
  poll_ec="$(poll_checkpoint "${svc}" "${ck_cid}" "${ck_log}" "${CRAC_CHECKPOINT_POLL_MAX_SECONDS}")" || true
  checkpoint_exit="${poll_ec:-1}"
  capture_container_logs "${ck_cid}" "${svc}" "checkpoint"

  # If checkpoint exited non-zero, skip restore.
  if [[ "${checkpoint_exit}" != "0" ]]; then
    reason="CHECKPOINT_FAILED"
    warn "[${svc}] checkpoint failed (exit=${checkpoint_exit}); log: ${ck_log}"
    rm_container_quiet "${ck_cid}"
    rm -f "$(cid_file_for "${svc}" "checkpoint")" >/dev/null 2>&1 || true
    emit_matrix_row "${svc}" "${port}" "${crac_capable}" "NO" "${checkpoint_exit}" "${normal_ready_ms}" "N/A" "N/A" "N/A" "N/A" "${reason}"
    return 0
  fi

  snapshot_created="YES"
  reason="CHECKPOINT_OK"
  rm_container_quiet "${ck_cid}"
  rm -f "$(cid_file_for "${svc}" "checkpoint")" >/dev/null 2>&1 || true

  local repeats="${CRAC_MATRIX_REPEATS}"
  if ! is_number "${repeats}" || (( repeats < 1 )); then repeats=1; fi

  local stats_ready_tmp stats_jvm_tmp stats_post_tmp
  stats_ready_tmp="$(mklog "${svc}" "restore-ready-ms-agg")"
  stats_jvm_tmp="$(mklog "${svc}" "restore-jvm-ms-agg")"
  stats_post_tmp="$(mklog "${svc}" "restore-post-ms-agg")"

  local rs_fail="0"
  for (( i=1; i<=repeats; i++ )); do
    echo "-> [${svc}] restore (${i}/${repeats})"
    local rs_log; rs_log="$(mklog "${svc}" "restore.${i}")"
    local rs_ready_file="/tmp/crac.${svc}.restore-ms.${i}"
    local rs_jvm_file="/tmp/crac.${svc}.restore-jvm-ms.${i}"
    local rs_post_file="/tmp/crac.${svc}.restore-post-ms.${i}"
    rm -f "${rs_ready_file}" "${rs_jvm_file}" "${rs_post_file}" >/dev/null 2>&1 || true

    local t_restore0 t_restore1
    t_restore0="$(ts_ms)"

    local rs_cid
    if ! rs_cid="$(run_detached "${svc}" "restore" "${ck_dir}")"; then
      reason="RESTORE_RUN_FAILED"
      warn "[${svc}] restore run failed"
      rs_fail="1"
      break
    fi

    if poll_restore "${svc}" "${rs_cid}" "${rs_log}" "${CRAC_RESTORE_POLL_MAX_SECONDS}"; then
      capture_container_logs "${rs_cid}" "${svc}" "restore" "${i}"
      t_restore1="$(ts_ms)"
      local ready_ms jvm_ms post_ms jvm_log
      ready_ms=$(( t_restore1 - t_restore0 ))
      jvm_log="$(container_log_path "${svc}" "restore" "${i}")"
      jvm_ms="$(extract_restore_jvm_ms "${jvm_log}")"

      if is_number "${ready_ms}"; then
        echo "${ready_ms}" >"${rs_ready_file}"
        echo "${ready_ms}" >>"${stats_ready_tmp}"
      fi
      if is_number "${jvm_ms}"; then
        echo "${jvm_ms}" >"${rs_jvm_file}"
        echo "${jvm_ms}" >>"${stats_jvm_tmp}"
      fi
      if is_number "${ready_ms}" && is_number "${jvm_ms}"; then
        post_ms=$(( ready_ms - jvm_ms ))
        (( post_ms < 0 )) && post_ms=0
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
      if [[ "${CRAC_CLEANUP}" == "1" ]]; then
        rm_container_quiet "${rs_cid}"
        rm -f "$(cid_file_for "${svc}" "restore")" >/dev/null 2>&1 || true
      fi
      break
    fi

    if [[ "${CRAC_CLEANUP}" == "1" ]]; then
      rm_container_quiet "${rs_cid}"
      rm -f "$(cid_file_for "${svc}" "restore")" >/dev/null 2>&1 || true
    fi
  done

  if [[ "${rs_fail}" == "1" ]]; then
    restore_ready_ms="N/A"; restore_jvm_ms="N/A"; post_restore_ms="N/A"; restore_stats="N/A"
  else
    local ready_comp jvm_comp post_comp
    ready_comp="$(compute_restore_stats "${stats_ready_tmp}")"
    jvm_comp="$(compute_restore_stats "${stats_jvm_tmp}")"
    post_comp="$(compute_restore_stats "${stats_post_tmp}")"
    restore_ready_ms="${ready_comp%%|*}"
    restore_jvm_ms="${jvm_comp%%|*}"
    post_restore_ms="${post_comp%%|*}"
    restore_stats="ready(${ready_comp#*|}) jvm(${jvm_comp#*|}) post(${post_comp#*|})"
  fi

  emit_matrix_row "${svc}" "${port}" "${crac_capable}" "${snapshot_created}" "${checkpoint_exit}" "${normal_ready_ms}" "${restore_ready_ms}" "${restore_jvm_ms}" "${post_restore_ms}" "${restore_stats}" "${reason}"
}

run_matrix() {
  RUN_CONTEXT="${RUN_CONTEXT:-matrix}"
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
