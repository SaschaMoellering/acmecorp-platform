#!/bin/bash
set -euo pipefail
ulimit -c 0 || true

: "${BASE_JVM_OPTS:=}"
: "${CRAC_MODE:=off}"
: "${CRAC_CHECKPOINT_DIR:=/opt/crac}"
: "${CRAC_CPU_FEATURES:=native}"
: "${CRAC_HEALTH_PORT:=8080}"
: "${CRAC_HEALTH_PATH:=/actuator/health}"
: "${CRAC_ENGINE:=warp}"
: "${CRAC_JVM_OPTS:=-XX:CRaCEngine=warp}"

CRAC_CPU_FEATURES="${CRAC_CPU_FEATURES:-native}"
CRAC_HEALTH_URL="${CRAC_HEALTH_URL:-http://localhost:${CRAC_HEALTH_PORT:-8080}${CRAC_HEALTH_PATH:-/actuator/health}}"

print_env_summary() {
  echo "CRAC_MODE=${CRAC_MODE:-}"
  echo "CRAC_CHECKPOINT_DIR=${CRAC_CHECKPOINT_DIR:-}"
  echo "CRAC_CPU_FEATURES=${CRAC_CPU_FEATURES:-}"
  echo "BASE_JVM_OPTS=${BASE_JVM_OPTS:-}"
  echo "CRAC_JVM_OPTS=${CRAC_JVM_OPTS:-}"
  echo "JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS:-}"
  echo "JDK_JAVA_OPTIONS=${JDK_JAVA_OPTIONS:-}"
}

print_cmd_array() {
  local label="$1"
  shift
  printf "%s " "$label"
  printf "%q " "$@"
  printf "\n"
}

is_warp() {
  case " $(detect_engine) " in
    *" warp "*) return 0 ;;
    *) return 1 ;;
  esac
}

detect_engine() {
  local opts=" ${CRAC_JVM_OPTS:-} "
  local from_opts=""
  from_opts="$(printf '%s' "$opts" | sed -nE 's/.*-XX:CRaCEngine=([^[:space:]]+).*/\1/p' | tail -n1)"
  if [ -n "${from_opts}" ]; then
    echo "${from_opts}"
  elif [ -n "${CRAC_ENGINE:-}" ]; then
    echo "${CRAC_ENGINE}"
  else
    echo "warp"
  fi
}

ensure_engine_in_opts() {
  local engine
  engine="$(detect_engine)"
  case " ${CRAC_JVM_OPTS:-} " in
    *" -XX:CRaCEngine="*) : ;;
    *) CRAC_JVM_OPTS="${CRAC_JVM_OPTS:-} -XX:CRaCEngine=${engine}" ;;
  esac
}

strip_not_restore_settable() {
  for v in BASE_JVM_OPTS CRAC_JVM_OPTS JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS _JAVA_OPTIONS JAVA_OPTS JAVA_OPTIONS; do
    eval "val=\${$v-}"
    val="$(printf '%s' "$val" \
      | sed -E 's/(^|[[:space:]])-XX:(MaxRAMPercentage|InitialRAMPercentage)=[^[:space:]]+//g' \
      | sed -E 's/(^|[[:space:]])-XX:\+(ExitOnOutOfMemoryError|HeapDumpOnOutOfMemoryError)([[:space:]]|$)/ /g' \
      | sed -E 's/(^|[[:space:]])-XX:HeapDumpPath=[^[:space:]]+//g' \
      | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
    eval "$v=\"\$val\""
    export "$v"
  done
}

case "${CRAC_MODE}" in
  "checkpoint")
    echo "Starting in checkpoint mode..."
    echo "Checkpoint directory: ${CRAC_CHECKPOINT_DIR}"
    ensure_engine_in_opts
    echo "CRAC_ENGINE=$(detect_engine)"
    CRAC_JVM_OPTS="${CRAC_JVM_OPTS:-} -XX:CPUFeatures=${CRAC_CPU_FEATURES}"
    strip_not_restore_settable
    export JAVA_TOOL_OPTIONS=""
    export JDK_JAVA_OPTIONS=""
    export _JAVA_OPTIONS=""
    export JAVA_OPTS=""
    export JAVA_OPTIONS=""
    print_env_summary

    CMD=(java)
    if [ -n "${CRAC_JVM_OPTS:-}" ]; then
      read -r -a CRAC_OPTS_ARR <<< "${CRAC_JVM_OPTS}"
      CMD+=("${CRAC_OPTS_ARR[@]}")
    fi
    CMD+=("-XX:CRaCCheckpointTo=${CRAC_CHECKPOINT_DIR}" org.springframework.boot.loader.launch.JarLauncher)
    print_cmd_array "Checkpoint command:" "${CMD[@]}"
    "${CMD[@]}" &
    APP_PID=$!

    echo "Waiting for application to be ready..."
    for i in {1..60}; do
      if curl -sf "${CRAC_HEALTH_URL}" >/dev/null 2>&1; then
        echo "Application is ready after ${i} seconds"
        break
      fi
      sleep 1
    done

    if [ -n "${CRAC_WARMUP_URLS:-}" ]; then
      echo "Executing warmup requests..."
      IFS=',' read -ra URLS <<< "$CRAC_WARMUP_URLS"
      for url in "${URLS[@]}"; do
        echo "Warming up: $url"
        curl -sf "$url" >/dev/null 2>&1 || echo "Warmup failed for $url"
      done
    fi

    sleep 5

    echo "Creating checkpoint..."
    jcmd "$APP_PID" JDK.checkpoint

    set +e
    wait "$APP_PID"
    rc=$?
    set -e

    if is_warp; then
      if [ -f "${CRAC_CHECKPOINT_DIR}/core.img" ]; then
        echo "Warp checkpoint detected (core.img). Accepting checkpoint as valid (rc=${rc})."
        echo "Checkpoint created successfully"
        exit 0
      fi
      echo "ERROR: Warp checkpoint expected core.img in ${CRAC_CHECKPOINT_DIR} (rc=${rc})"
      ls -la "${CRAC_CHECKPOINT_DIR}" || true
      exit 1
    fi

    non_core_count="$(find "${CRAC_CHECKPOINT_DIR}" -maxdepth 1 -type f ! -name 'core.img' 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${rc}" -ne 0 ] || [ "${non_core_count}" -eq 0 ]; then
      echo "ERROR: checkpoint invalid (rc=${rc}) or no checkpoint artifacts in ${CRAC_CHECKPOINT_DIR}"
      ls -la "${CRAC_CHECKPOINT_DIR}" || true
      exit 1
    fi

    echo "Checkpoint created successfully"
    ;;

  "restore")
    echo "Starting in restore mode..."
    echo "Checkpoint directory: ${CRAC_CHECKPOINT_DIR}"
    ensure_engine_in_opts
    echo "CRAC_ENGINE=$(detect_engine)"

    if is_warp; then
      if [ ! -f "${CRAC_CHECKPOINT_DIR}/core.img" ]; then
        echo "ERROR: No Warp checkpoint found in ${CRAC_CHECKPOINT_DIR} (missing core.img)"
        exit 1
      fi
    else
      non_core_count="$(find "${CRAC_CHECKPOINT_DIR}" -maxdepth 1 -type f ! -name 'core.img' 2>/dev/null | wc -l | tr -d ' ')"
      if [ ! -d "${CRAC_CHECKPOINT_DIR}" ] || [ "${non_core_count}" -eq 0 ]; then
        echo "ERROR: No checkpoint found in ${CRAC_CHECKPOINT_DIR}"
        exit 1
      fi
    fi

    strip_not_restore_settable
    export JAVA_TOOL_OPTIONS=""
    export JDK_JAVA_OPTIONS=""
    export _JAVA_OPTIONS=""
    export JAVA_OPTS=""
    export JAVA_OPTIONS=""
    print_env_summary

    CMD=(java)
    if [ -n "${BASE_JVM_OPTS:-}" ]; then
      read -r -a BASE_OPTS_ARR <<< "${BASE_JVM_OPTS}"
      CMD+=("${BASE_OPTS_ARR[@]}")
    fi
    if [ -n "${CRAC_JVM_OPTS:-}" ]; then
      read -r -a CRAC_OPTS_ARR <<< "${CRAC_JVM_OPTS}"
      CMD+=("${CRAC_OPTS_ARR[@]}")
    fi
    CMD+=("-XX:CRaCRestoreFrom=${CRAC_CHECKPOINT_DIR}")
    print_cmd_array "Restore command:" "${CMD[@]}"
    exec "${CMD[@]}"
    ;;

  *)
    echo "Starting in normal mode (no CRaC)..."
    CMD=(java)
    if [ -n "${BASE_JVM_OPTS}" ]; then
      read -r -a BASE_OPTS_ARR <<< "${BASE_JVM_OPTS}"
      CMD+=("${BASE_OPTS_ARR[@]}")
    fi
    CMD+=(org.springframework.boot.loader.launch.JarLauncher)
    exec "${CMD[@]}"
    ;;
esac
