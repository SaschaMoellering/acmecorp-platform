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
#   CRAC_DEBUG=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CRAC_CHECKPOINT_BASE="${CRAC_CHECKPOINT_BASE:-/opt/crac}"
CRAC_POLL_MAX_SECONDS="${CRAC_POLL_MAX_SECONDS:-}"

CRAC_CHECKPOINT_POLL_MAX_SECONDS="${CRAC_CHECKPOINT_POLL_MAX_SECONDS:-${CRAC_POLL_MAX_SECONDS:-180}}"
CRAC_RESTORE_POLL_MAX_SECONDS="${CRAC_RESTORE_POLL_MAX_SECONDS:-${CRAC_POLL_MAX_SECONDS:-60}}"

BASE_READY_MAX_SECONDS="${BASE_READY_MAX_SECONDS:-180}"

CRAC_DEBUG="${CRAC_DEBUG:-0}"
CRAC_MATRIX_SERVICES="${CRAC_MATRIX_SERVICES:-gateway-service,orders-service,billing-service,notification-service,analytics-service}"
RUN_CONTEXT="${RUN_CONTEXT:-matrix}"

COMPOSE_BASE=(-f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml)
TEMP_FILES=()
CID_FILES=()

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

# ---- HTTP probe that works even if wget is missing ----
probe_http_cmd() {
  local url="$1"
  cat <<EOF
if command -v curl >/dev/null 2>&1; then
  curl -fsS '${url}' >/dev/null 2>&1
elif command -v wget >/dev/null 2>&1; then
  wget -qO- '${url}' >/dev/null 2>&1
elif command -v busybox >/dev/null 2>&1; then
  busybox wget -qO- '${url}' >/dev/null 2>&1
else
  exit 127
fi
EOF
}

probe_http_compose_exec() {
  local svc="$1" url="$2"
  docker_compose exec -T "${svc}" sh -lc "$(probe_http_cmd "${url}")" >/dev/null 2>&1
}

probe_http_docker_exec() {
  local cid="$1" url="$2"
  docker exec -T "${cid}" sh -lc "$(probe_http_cmd "${url}")" >/dev/null 2>&1
}

# ---- Base up/down ----
base_up() {
  local svc="$1" log_path="$2"
  docker_compose up -d "${svc}" >"${log_path}" 2>&1
}

base_stop() {
  local svc="$1"
  docker_compose stop "${svc}" >/dev/null 2>&1 || true
}

# ---- Base readiness (inside container) ----
wait_base_ready_inside_service() {
  local svc="$1" max_seconds="$2" url="$3" log_path="$4"
  local start end now
  start="$(date +%s)"; end=$((start + max_seconds))

  while true; do
    now="$(date +%s)"
    if (( now >= end )); then
      warn "[${svc}] base readiness timeout; log: ${log_path}"
      return 124
    fi

    # 1) primary: /actuator/health reachable
    if probe_http_compose_exec "${svc}" "${url}"; then
      return 0
    fi

    # 2) fallback: if tools missing (exit 127) OR still not ready:
    # check logs for typical Spring "Started ... in X seconds" (base start)
    # (won't appear on CRaC restore, but base run has it)
    if docker_compose logs --no-color --tail=200 "${svc}" 2>/dev/null | grep -qE 'Started .* in [0-9]+\.[0-9]+ seconds'; then
      return 0
    fi

    sleep 1
  done
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

  while true; do
    now="$(date +%s)"
    if (( now >= end )); then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      append_postmortem "${cid}" "${log_path}"
      echo ""
      return 124
    fi

    if ! is_container_running "${cid}"; then
      docker_logs_tail "${cid}" 2000 > "${log_path}" 2>&1 || true
      append_postmortem "${cid}" "${log_path}"
      echo ""
      return 1
    fi

    docker_logs_tail "${cid}" 1200 > "${log_path}" 2>&1 || true

    grep -q 'warp: Restore successful!' "${log_path}" && warp_ok=1 || true

    # ✅ Spring CRaC restore marker
    if grep -q 'Spring-managed lifecycle restart completed' "${log_path}"; then
      local ms
      ms="$(sed -nE 's/.*restored JVM running for ([0-9]+) ms.*/\1/p' "${log_path}" | tail -n1 || true)"
      echo "${ms}"
      return 0
    fi

    # Fallbacks
    if grep -q 'Netty started on port' "${log_path}" && [[ "${warp_ok}" == "1" ]]; then
      echo ""
      return 0
    fi
    if probe_http_docker_exec "${cid}" "http://localhost:8080/actuator/health"; then
      echo ""
      return 0
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

print_matrix_header() {
  echo "| service | host_port | crac_capable | snapshot_created | checkpoint_exit | normal_ready_ms | restore_ready_ms | reason |"
  echo "|---|---:|:---:|:---:|---:|---:|---:|---|"
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
  local reason=""
  local checkpoint_state="CHECKPOINT_EMPTY"
  local engine
  engine="$(detect_engine)"

  echo "-> [${svc}] base up"
  local base_log; base_log="$(mklog "${svc}" "base")"
  if ! base_up "${svc}" "${base_log}"; then
    reason="BASE_UP_FAILED"
    warn "[${svc}] base up failed; see ${base_log}"
    echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | TIMEOUT | ${restore_ready_ms} | ${reason} |"
    return 0
  fi

  echo "-> [${svc}] wait normal readiness (inside container)"
  local t0 t1
  t0="$(ts_ms)"
  if ! wait_base_ready_inside_service "${svc}" "${BASE_READY_MAX_SECONDS}" "http://localhost:8080/actuator/health" "${base_log}"; then
    reason="BASE_READY_TIMEOUT"
    warn "[${svc}] base readiness failed/timeout; see ${base_log}"
    base_stop "${svc}"
    echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | TIMEOUT | ${restore_ready_ms} | ${reason} |"
    return 0
  fi
  t1="$(ts_ms)"
  normal_ready_ms="$((t1 - t0))"

  echo "-> [${svc}] base stop"
  base_stop "${svc}"

  if [[ "${crac_capable}" != "YES" ]]; then
    reason="NOT_CRAC_CAPABLE"
    echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | ${normal_ready_ms} | ${restore_ready_ms} | ${reason} |"
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
    echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | 1 | ${normal_ready_ms} | ${restore_ready_ms} | ${reason} |"
    return 0
  fi

  local poll_ec=""
  if ! poll_ec="$(poll_checkpoint "${svc}" "${ck_cid}" "${ck_log}" "${CRAC_CHECKPOINT_POLL_MAX_SECONDS}")"; then
    checkpoint_exit="124"
    reason="CHECKPOINT_FAILED"
    checkpoint_state="CHECKPOINT_FAILED"
    warn "[${svc}] checkpoint timeout; log: ${ck_log}"
    append_checkpoint_diagnostics "${ck_cid}" "${ck_log}" "${crac_volume}" "${checkpoint_subpath}"
    rm_container_quiet "${ck_cid}"
    rm -f "$(cid_file_for "${svc}" "checkpoint")" >/dev/null 2>&1 || true
    echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | ${normal_ready_ms} | ${restore_ready_ms} | ${reason} |"
    return 0
  fi
  checkpoint_exit="${poll_ec:-1}"

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
  debug "[${svc}] checkpoint status=${checkpoint_state} (rc=${checkpoint_exit}, artifacts=${snapshot_created}, core_img=${has_core_img})"

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
    echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | ${normal_ready_ms} | ${restore_ready_ms} | ${reason} |"
    return 0
  fi
  if [[ "${checkpoint_state}" == "CHECKPOINT_WARP_OK" ]]; then
    snapshot_created="YES"
    debug "[${svc}] warp checkpoint validated via core.img"
  fi
  rm_container_quiet "${ck_cid}"
  rm -f "$(cid_file_for "${svc}" "checkpoint")" >/dev/null 2>&1 || true

  echo "-> [${svc}] restore"
  local rs_log; rs_log="$(mklog "${svc}" "restore")"
  local rs_cid
  if ! rs_cid="$(run_detached "${svc}" "restore" "${ck_dir}")"; then
    reason="RESTORE_RUN_FAILED"
    warn "[${svc}] restore run failed"
    echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | ${normal_ready_ms} | ${restore_ready_ms} | ${reason} |"
    return 0
  fi

  local rs_ms=""
  if rs_ms="$(poll_restore "${svc}" "${rs_cid}" "${rs_log}" "${CRAC_RESTORE_POLL_MAX_SECONDS}")"; then
    restore_ready_ms="${rs_ms:-N/A}"
    # keep a meaningful success reason
    if [[ "${checkpoint_state}" == "CHECKPOINT_WARP_OK" ]]; then
      reason="CHECKPOINT_WARP_OK"
    elif [[ "${checkpoint_state}" == "CHECKPOINT_OK" ]]; then
      reason="CHECKPOINT_OK"
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
  fi

  rm_container_quiet "${rs_cid}"
  rm -f "$(cid_file_for "${svc}" "restore")" >/dev/null 2>&1 || true

  echo "| ${svc} | ${port} | ${crac_capable} | ${snapshot_created} | ${checkpoint_exit} | ${normal_ready_ms} | ${restore_ready_ms} | ${reason} |"
}

run_matrix() {
  RUN_CONTEXT="${RUN_CONTEXT:-matrix}"
  CRAC_DATA_VOLUME_NAME="$(resolve_crac_data_volume_name)"
  debug "Resolved crac-data volume: ${CRAC_DATA_VOLUME_NAME}"
  print_matrix_header
  IFS=',' read -r -a svcs <<< "${CRAC_MATRIX_SERVICES}"
  for svc in "${svcs[@]}"; do
    matrix_one_service "${svc}"
  done
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
