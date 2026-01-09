#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_ROOT="$ROOT_DIR/bench/results"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"
HEALTH_URL="http://localhost:8080/api/gateway/status"
LOAD_URL="http://localhost:8080/api/gateway/orders"
WARMUP=60
DURATION=120
CONCURRENCY=25

for cmd in docker curl git mvn; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "required command '$cmd' is missing" >&2
    exit 1
  fi
done

PYTHON_BIN="python"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "required command 'python' (or 'python3') is missing" >&2
  exit 1
fi
export PYTHON_BIN

JQ_BIN="jq"
if ! command -v "$JQ_BIN" >/dev/null 2>&1; then
  JQ_BIN=""
fi

COMPOSE_CMD=()
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "docker compose or docker-compose CLI not found" >&2
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "docker compose file missing: $COMPOSE_FILE" >&2
  exit 1
fi

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
matrix_dir="$RESULT_ROOT/$timestamp"
mkdir -p "$matrix_dir"

branches=(java11 java17)
if git show-ref --verify --quiet refs/heads/java21; then
  branches+=("java21")
fi
branches+=("main" "java25")

# Optional: ONLY_BRANCH=java21 bash bench/run-matrix.sh
if [[ -n "${ONLY_BRANCH:-}" ]]; then
  branches=("${ONLY_BRANCH}")
fi

initial_branch="$(git rev-parse --abbrev-ref HEAD)"

function ensure_compose_down() {
  if [[ "${KEEP_COMPOSE_UP:-0}" == "1" ]]; then
    return 0
  fi
  "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}

function cleanup() {
  ensure_compose_down
  git checkout "$initial_branch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

declare -a summary_rows=()
MATRIX_FAIL_FAST="${MATRIX_FAIL_FAST:-0}"
KEEP_COMPOSE_UP="${KEEP_COMPOSE_UP:-0}"

function branch_java_version() {
  case "$1" in
    java11) echo "11" ;;
    java17) echo "17" ;;
    java21) echo "21" ;;
    main) echo "21" ;;
    java25) echo "25" ;;
    *) echo "unknown" ;;
  esac
}

function pick_java_home_sdkman() {
  local version="$1"
  local sdkdir="${HOME}/.sdkman/candidates/java"
  [[ -d "$sdkdir" ]] || return 1

  local matches=()
  while IFS= read -r -d '' path; do
    [[ -x "$path/bin/java" ]] && matches+=("$path")
  done < <(find "$sdkdir" -maxdepth 1 -mindepth 1 -type d \( -name "${version}.*" -o -name "${version}-*" \) -print0 2>/dev/null || true)

  [[ ${#matches[@]} -gt 0 ]] || return 1
  printf '%s\n' "${matches[@]}" | sort -V | tail -n 1
}

function pick_java_home_system() {
  local version="$1"
  local candidates=(
    "/usr/lib/jvm/java-${version}-openjdk-amd64"
    "/usr/lib/jvm/java-${version}-openjdk"
    "/usr/lib/jvm/temurin-${version}-jdk-amd64"
    "/usr/lib/jvm/temurin-${version}-jdk"
    "/usr/lib/jvm/java-${version}-temurin"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

function use_branch_java() {
  local version="$1"
  local java_home=""

  if java_home="$(pick_java_home_sdkman "$version")"; then
    :
  elif java_home="$(pick_java_home_system "$version")"; then
    :
  else
    echo "No JDK found for Java ${version}. Install a JDK under ~/.sdkman/candidates/java or /usr/lib/jvm and retry." >&2
    exit 1
  fi

  export JAVA_HOME="$java_home"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "Using JAVA_HOME=$JAVA_HOME"
  java -version
  mvn -v
}

function package_modules() {
  local branch="$1"

  echo "Packaging $branch (module builds)..."

  for svc in "$ROOT_DIR"/services/spring-boot/*-service; do
    [[ -f "$svc/pom.xml" ]] || continue
    echo "  - $(basename "$svc")"
    mvn -q -f "$svc/pom.xml" -DskipTests package
  done

  if [[ -f "$ROOT_DIR/integration-tests/pom.xml" ]]; then
    echo "  - integration-tests"
    mvn -q -f "$ROOT_DIR/integration-tests/pom.xml" -DskipTests package
  fi

  if [[ -d "$ROOT_DIR/services/quarkus" ]] && [[ "$branch" != "java11" ]]; then
    for qsvc in "$ROOT_DIR"/services/quarkus/*; do
      [[ -f "$qsvc/pom.xml" ]] || continue
      echo "  - $(basename "$qsvc") (quarkus)"
      mvn -q -f "$qsvc/pom.xml" -DskipTests package
    done
  fi
}

function extract_json_from_stdout() {
  local stdout="$1"

  [[ -n "${stdout//[[:space:]]/}" ]] || return 1

  local candidate=""
  candidate="$(printf '%s\n' "$stdout" | awk '/^[[:space:]]*[{[]/ {line=$0} END {print line}')"
  [[ -n "${candidate//[[:space:]]/}" ]] || return 1

  if [[ -n "$JQ_BIN" ]]; then
    if ! printf '%s' "$candidate" | "$JQ_BIN" -e . >/dev/null 2>&1; then
      return 1
    fi
  else
    if ! printf '%s' "$candidate" | "$PYTHON_BIN" - <<'PY'
import json
import sys

data = sys.stdin.read()
if not data.strip():
    raise SystemExit(1)
json.loads(data)
PY
    then
      return 1
    fi
  fi

  printf '%s' "$candidate"
}

function http_status() {
  local url="$1"
  curl -sS -o /dev/null -w '%{http_code}' --max-time 2 "$url" 2>/dev/null || echo "000"
}

function wait_for_url_ok() {
  local url="$1"
  local timeout_seconds="$2"
  local start_ts
  local status

  start_ts="$(date +%s)"
  status="000"
  until [[ "$(date +%s)" -ge $((start_ts + timeout_seconds)) ]]; do
    status="$(http_status "$url")"
    if [[ "$status" =~ ^[23][0-9][0-9]$ ]]; then
      echo "$status"
      return 0
    fi
    sleep 2
  done

  echo "$status"
  return 1
}

function write_branch_summary() {
  local branch="$1"
  local startup_seconds="$2"
  local requests_per_sec="$3"
  local p50="$4"
  local p95="$5"
  local p99="$6"
  local errors="$7"
  local mem_summary="$8"
  local branch_dir="$9"

  cat <<EOF > "$branch_dir/summary.md"
# Benchmark results for $branch

- Startup: ${startup_seconds}s
- Load: ${requests_per_sec} req/s (p50=${p50}, p95=${p95}, p99=${p99}, errors=${errors})
- Memory snapshot: ${mem_summary}
- Load metrics: [load.json](load.json)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
EOF

  if [[ -f "$branch_dir/load.parse-error.json" ]]; then
    cat <<EOF >> "$branch_dir/summary.md"

## Load parsing error

- Parse error file: [load.parse-error.json](load.parse-error.json)
EOF
  fi
}

function mark_branch_failure() {
  local branch="$1"
  local startup_seconds="$2"
  local reason="$3"
  local branch_dir="$4"
  local containers_file="$5"

  local requests_per_sec="0"
  local p50="na"
  local p95="na"
  local p99="na"
  local errors="$reason"
  local mem_summary="na"

  if [[ -n "$containers_file" ]] && [[ -s "$containers_file" ]]; then
    if mem_summary="$("$PYTHON_BIN" - <<PY
import json
import sys

path = "$containers_file"
try:
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    if not text.strip():
        raise ValueError("containers.json is empty")
    data = json.loads(text)
except Exception as exc:
    print(f"containers.json invalid: {path} ({exc})", file=sys.stderr)
    print("na")
    raise SystemExit(0)

groups = {}
for item in data:
    svc = item.get("service", "unknown")
    groups.setdefault(svc, []).append(item.get("mem", "na"))
parts = []
for svc in sorted(groups):
    parts.append(f"{svc}:{'/'.join(groups[svc])}")
print(', '.join(parts) if parts else "na")
PY
    )"; then
      :
    else
      mem_summary="na"
    fi
  fi

  # IMPORTANT: do NOT overwrite load.json (it should contain the real loadtest output if available)
  printf '{"error":"%s"}\n' "$reason" > "$branch_dir/load.parse-error.json"

  write_branch_summary "$branch" "$startup_seconds" "$requests_per_sec" "$p50" "$p95" "$p99" "$errors" "$mem_summary" "$branch_dir"
  summary_rows+=("$branch|$startup_seconds|$requests_per_sec|$p50|$p95|$p99|$errors|$mem_summary")
}

for branch in "${branches[@]}"; do
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "branch '$branch' missing, skipping" >&2
    continue
  fi

  echo "---------- Benchmarking branch: $branch ----------"
  git checkout "$branch" >/dev/null

  java_ver="$(branch_java_version "$branch")"
  if [[ "$java_ver" != "unknown" ]]; then
    use_branch_java "$java_ver"
  fi

  branch_dir="$RESULT_ROOT/$branch/$timestamp"
  mkdir -p "$branch_dir"

  # clean previous parse error marker for this run/branch_dir (defensive)
  rm -f "$branch_dir/load.parse-error.json" >/dev/null 2>&1 || true

  package_modules "$branch"

  ensure_compose_down
  ("${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" up --build -d) >/dev/null

  start_ts="$(date +%s)"
  ready_ts=""
  echo "Waiting for health endpoint ($HEALTH_URL)..."
  until [[ "$(date +%s)" -ge $((start_ts + 180)) ]]; do
    if curl -fsS --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
      ready_ts="$(date +%s)"
      break
    fi
    sleep 2
  done

  if [[ -z "$ready_ts" ]]; then
    echo "health endpoint did not become ready for $branch" >&2
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 gateway-service || true
    ensure_compose_down
    exit 1
  fi

  startup_seconds=$((ready_ts - start_ts))
  load_status="000"
  if ! load_status="$(wait_for_url_ok "$LOAD_URL" 180)"; then
    echo "LOAD_URL not ready (HTTP $load_status) for $branch" >&2
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 gateway-service || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 orders-service || true
    containers_file=""
    if containers_file="$(bash "$ROOT_DIR/bench/collect.sh" "$branch_dir" 2>/dev/null)"; then
      :
    else
      containers_file="$branch_dir/containers.json"
      printf '[]\n' > "$containers_file"
      echo "containers.json missing or invalid for $branch; wrote empty file: $containers_file" >&2
    fi
    ensure_compose_down
    mark_branch_failure "$branch" "$startup_seconds" "load_url_not_ready" "$branch_dir" "$containers_file"
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    fi
    continue
  fi

  load_stderr_file="$branch_dir/load.stderr.txt"
  load_stdout_file="$branch_dir/load.raw.stdout.txt"
  load_exit=0
  if bash "$ROOT_DIR/bench/loadtest.sh" "$LOAD_URL" "$DURATION" "$WARMUP" "$CONCURRENCY" \
      > "$load_stdout_file" 2> "$load_stderr_file"; then
    load_exit=0
  else
    load_exit=$?
  fi

  load_stdout="$(cat "$load_stdout_file")"

  if ! load_result="$(extract_json_from_stdout "$(cat "$load_stdout_file")")"; then
    echo "loadtest output did not contain valid JSON for $branch (exit=$load_exit, stdout file: $load_stdout_file)" >&2
    echo "----- loadtest sizes (bytes) -----" >&2
    wc -c "$load_stdout_file" "$load_stderr_file" >&2 || true
    echo "----- loadtest stderr (first 50 lines) -----" >&2
    sed -n '1,50p' "$load_stderr_file" >&2 || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 gateway-service || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 orders-service || true
    containers_file=""
    if containers_file="$(bash "$ROOT_DIR/bench/collect.sh" "$branch_dir" 2>/dev/null)"; then
      :
    else
      containers_file="$branch_dir/containers.json"
      printf '[]\n' > "$containers_file"
      echo "containers.json missing or invalid for $branch; wrote empty file: $containers_file" >&2
    fi
    ensure_compose_down
    mark_branch_failure "$branch" "$startup_seconds" "loadtest_no_json" "$branch_dir" "$containers_file"
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    fi
    continue
  fi

  if [[ -z "${load_result//[[:space:]]/}" ]]; then
    echo "loadtest JSON was empty for $branch (stdout file: $load_stdout_file)" >&2
    echo "----- loadtest sizes (bytes) -----" >&2
    wc -c "$load_stdout_file" "$load_stderr_file" >&2 || true
    echo "----- loadtest stderr (first 50 lines) -----" >&2
    sed -n '1,50p' "$load_stderr_file" >&2 || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 gateway-service || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 orders-service || true
    containers_file=""
    if containers_file="$(bash "$ROOT_DIR/bench/collect.sh" "$branch_dir" 2>/dev/null)"; then
      :
    else
      containers_file="$branch_dir/containers.json"
      printf '[]\n' > "$containers_file"
      echo "containers.json missing or invalid for $branch; wrote empty file: $containers_file" >&2
    fi
    ensure_compose_down
    mark_branch_failure "$branch" "$startup_seconds" "loadtest_empty_json" "$branch_dir" "$containers_file"
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    fi
    continue
  fi

  printf '%s\n' "$load_result" > "$branch_dir/load.json"
  if [[ ! -s "$branch_dir/load.json" ]]; then
    echo "load.json empty after write for $branch (file: $branch_dir/load.json)" >&2
    echo "----- loadtest sizes (bytes) -----" >&2
    wc -c "$load_stdout_file" "$load_stderr_file" >&2 || true
    echo "----- loadtest stderr (first 50 lines) -----" >&2
    sed -n '1,50p' "$load_stderr_file" >&2 || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 gateway-service || true
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" logs --tail=200 orders-service || true
    containers_file=""
    if containers_file="$(bash "$ROOT_DIR/bench/collect.sh" "$branch_dir" 2>/dev/null)"; then
      :
    else
      containers_file="$branch_dir/containers.json"
      printf '[]\n' > "$containers_file"
      echo "containers.json missing or invalid for $branch; wrote empty file: $containers_file" >&2
    fi
    ensure_compose_down
    mark_branch_failure "$branch" "$startup_seconds" "load_json_empty" "$branch_dir" "$containers_file"
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    fi
    continue
  fi

  sleep 5

  containers_file="$(bash "$ROOT_DIR/bench/collect.sh" "$branch_dir")"
  ensure_compose_down

  # IMPORTANT FIX:
  # Do NOT do `printf ... | python - <<PY` because python reads the program from stdin.
  # Read metrics from the written load.json file instead.
  metrics_output=""
  if ! metrics_output="$("$PYTHON_BIN" - "$branch_dir/load.json" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()
except Exception as exc:
    print(f"cannot read load.json while computing metrics ({exc})", file=sys.stderr)
    raise SystemExit(1)

if not raw.strip():
    print("load.json empty while computing metrics", file=sys.stderr)
    raise SystemExit(1)

try:
    data = json.loads(raw)
except Exception as exc:
    print(f"load.json invalid while computing metrics ({exc})", file=sys.stderr)
    raise SystemExit(1)

print(data.get("requests_per_sec", 0))
print(data.get("p50", "na"))
print(data.get("p95", "na"))
print(data.get("p99", "na"))
print(data.get("errors", "na"))
PY
  )"; then
    echo "failed to compute metrics from load.json for $branch (file: $branch_dir/load.json)" >&2
    "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps || true
    ensure_compose_down
    mark_branch_failure "$branch" "$startup_seconds" "loadtest_metrics_invalid" "$branch_dir" "$containers_file"
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    fi
    continue
  fi

  mapfile -t metrics <<< "$metrics_output"

  requests_per_sec="${metrics[0]:-0}"
  p50="${metrics[1]:-na}"
  p95="${metrics[2]:-na}"
  p99="${metrics[3]:-na}"
  errors="${metrics[4]:-na}"

  mem_summary="na"
  if [[ -n "$containers_file" ]] && [[ -s "$containers_file" ]]; then
    mem_summary="$("$PYTHON_BIN" - <<PY
import json
import sys

path = "$containers_file"
try:
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    if not text.strip():
        raise ValueError("containers.json is empty")
    data = json.loads(text)
except Exception as exc:
    print(f"containers.json invalid: {path} ({exc})", file=sys.stderr)
    print("na")
    raise SystemExit(0)

groups = {}
for item in data:
    svc = item.get("service", "unknown")
    groups.setdefault(svc, []).append(item.get("mem", "na"))
parts = []
for svc in sorted(groups):
    parts.append(f"{svc}:{'/'.join(groups[svc])}")
print(', '.join(parts) if parts else "na")
PY
    )"
  else
    if [[ -n "$containers_file" ]]; then
      echo "containers.json empty or missing: $containers_file" >&2
    else
      echo "containers.json path missing from collect.sh output for $branch" >&2
    fi
  fi

  write_branch_summary "$branch" "$startup_seconds" "$requests_per_sec" "$p50" "$p95" "$p99" "$errors" "$mem_summary" "$branch_dir"
  summary_rows+=("$branch|$startup_seconds|$requests_per_sec|$p50|$p95|$p99|$errors|$mem_summary")
done

matrix_file="$matrix_dir/matrix-summary.md"
{
  echo "# Java benchmark matrix (${timestamp})"
  echo
  echo "| Branch | Java | Startup (s) | Req/s | P50 | P95 | P99 | Errors | Memory | Details |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
  for row in "${summary_rows[@]}"; do
    IFS='|' read -r branch startup requests p50 p95 p99 errors memory <<< "$row"
    version="$(branch_java_version "$branch")"
    details="[link](../${branch}/${timestamp}/summary.md)"
    echo "| ${branch} | ${version} | ${startup} | ${requests} | ${p50} | ${p95} | ${p99} | ${errors} | ${memory} | ${details} |"
  done
} > "$matrix_file"

echo "Matrix results written to $matrix_file"
