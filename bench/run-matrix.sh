#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_ROOT="$ROOT_DIR/bench/results"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"

HEALTH_URL="http://localhost:8080/api/gateway/status"
LOAD_URL="http://localhost:8080/api/gateway/orders"

# Defaults (override via env)
WARMUP="${WARMUP:-60}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-25}"

STARTUP_TIMEOUT_SECONDS="${STARTUP_TIMEOUT_SECONDS:-180}"
CURL_TIMEOUT_SECONDS="${CURL_TIMEOUT_SECONDS:-2}"

# Optional env vars:
#   ONLY_BRANCH=java25 bash bench/run-matrix.sh
#   MATRIX_FAIL_FAST=1 bash bench/run-matrix.sh
#   MAVEN_MODULES_CSV="services/spring-boot/gateway-service,services/spring-boot/orders-service" bash bench/run-matrix.sh
#   COMPOSE_QUIET=1 bash bench/run-matrix.sh
MATRIX_FAIL_FAST="${MATRIX_FAIL_FAST:-1}"
COMPOSE_QUIET="${COMPOSE_QUIET:-1}"

for cmd in docker curl git mvn; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "required command '$cmd' is missing" >&2
    exit 1
  fi
done

# Python detection (prefer python3)
PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
  PYTHON_BIN="$(command -v python || true)"
fi
if [[ -z "${PYTHON_BIN:-}" ]]; then
  echo "required command 'python3' (or 'python') is missing" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "required command 'jq' is missing" >&2
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

if [[ -n "${ONLY_BRANCH:-}" ]]; then
  branches=("${ONLY_BRANCH}")
fi

initial_branch="$(git rev-parse --abbrev-ref HEAD)"

function ensure_compose_down() {
  docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}

function cleanup() {
  ensure_compose_down
  git checkout "$initial_branch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

declare -a summary_rows=()

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
  done < <(
    find "$sdkdir" -maxdepth 1 -mindepth 1 -type d \
      \( -name "${version}.*" -o -name "${version}-*" \) \
      -print0 2>/dev/null || true
  )

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
  echo "Using JAVA_HOME=$JAVA_HOME" >&2
  java -version >&2
  mvn -v >&2
}

# Override module list via MAVEN_MODULES_CSV (comma-separated).
declare -a MAVEN_MODULES=(
  "services/spring-boot/gateway-service"
  "services/spring-boot/orders-service"
  "services/spring-boot/billing-service"
  "services/spring-boot/notification-service"
  "services/spring-boot/analytics-service"
  "services/quarkus/catalog-service"
)

if [[ -n "${MAVEN_MODULES_CSV:-}" ]]; then
  IFS=',' read -r -a MAVEN_MODULES <<< "${MAVEN_MODULES_CSV}"
fi

function package_modules() {
  local branch="$1"
  echo "Packaging $branch (module builds)..." >&2

  for m in "${MAVEN_MODULES[@]}"; do
    # Skip Quarkus on java11
    if [[ "$branch" == "java11" ]] && [[ "$m" == services/quarkus/* ]]; then
      continue
    fi

    local pom="$ROOT_DIR/$m/pom.xml"
    if [[ ! -f "$pom" ]]; then
      echo "ERROR: Missing pom.xml: $pom" >&2
      echo "Hint: adjust MAVEN_MODULES or set MAVEN_MODULES_CSV." >&2
      return 1
    fi

    echo "  - $m" >&2
    mvn -q -f "$pom" -DskipTests package
  done

  # Optional integration tests module
  if [[ -f "$ROOT_DIR/integration-tests/pom.xml" ]]; then
    echo "  - integration-tests" >&2
    mvn -q -f "$ROOT_DIR/integration-tests/pom.xml" -DskipTests package
  fi
}

function wait_for_http_200() {
  local url="$1"
  local deadline_ts="$2"

  while [[ "$(date +%s)" -lt "$deadline_ts" ]]; do
    if curl -fsS --max-time "$CURL_TIMEOUT_SECONDS" "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

function wait_for_gateway_ready() {
  local start_ts="$1"
  local deadline_ts="$2"

  echo "Waiting for health endpoint ($HEALTH_URL)..." >&2
  if ! wait_for_http_200 "$HEALTH_URL" "$deadline_ts"; then
    echo "health endpoint did not become ready within ${STARTUP_TIMEOUT_SECONDS}s" >&2
    return 1
  fi

  echo "Waiting for orders endpoint to answer once ($LOAD_URL)..." >&2
  if ! wait_for_http_200 "$LOAD_URL" "$deadline_ts"; then
    echo "orders endpoint did not become ready within ${STARTUP_TIMEOUT_SECONDS}s" >&2
    return 1
  fi

  local ready_ts
  ready_ts="$(date +%s)"
  echo "$((ready_ts - start_ts))"
}

function compose_up() {
  if [[ "$COMPOSE_QUIET" == "1" ]]; then
    docker compose -f "$COMPOSE_FILE" up --build -d >/dev/null
  else
    docker compose -f "$COMPOSE_FILE" up --build -d
  fi
}

for branch in "${branches[@]}"; do
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "branch '$branch' missing, skipping" >&2
    continue
  fi

  echo "---------- Benchmarking branch: $branch ----------" >&2
  git checkout "$branch" >/dev/null

  java_ver="$(branch_java_version "$branch")"
  if [[ "$java_ver" != "unknown" ]]; then
    use_branch_java "$java_ver"
  fi

  branch_dir="$RESULT_ROOT/$branch/$timestamp"
  mkdir -p "$branch_dir"

  if ! package_modules "$branch"; then
    echo "packaging failed for $branch" >&2
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    else
      continue
    fi
  fi

  ensure_compose_down
  compose_up

  start_ts="$(date +%s)"
  deadline_ts="$((start_ts + STARTUP_TIMEOUT_SECONDS))"

  startup_seconds=""
  if ! startup_seconds="$(wait_for_gateway_ready "$start_ts" "$deadline_ts")"; then
    docker compose -f "$COMPOSE_FILE" ps || true
    docker compose -f "$COMPOSE_FILE" logs --tail=200 gateway-service || true
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    else
      continue
    fi
  fi

  echo "Running load test: warmup=${WARMUP}s duration=${DURATION}s concurrency=${CONCURRENCY}" >&2
  load_stderr="$branch_dir/load.stderr.txt"
  load_json="$branch_dir/load.json"
  load_raw_stdout="$branch_dir/load.stdout.txt"

  if ! bash "$ROOT_DIR/bench/loadtest.sh" "$LOAD_URL" "$DURATION" "$WARMUP" "$CONCURRENCY" >"$load_raw_stdout" 2>"$load_stderr"; then
    true
  fi

  if ! jq -e . "$load_raw_stdout" >"$load_json" 2>/dev/null; then
    echo "loadtest output is not valid JSON for $branch" >&2
    echo "----- stdout -----" >&2
    sed -n '1,200p' "$load_raw_stdout" >&2 || true
    echo "----- stderr -----" >&2
    sed -n '1,200p' "$load_stderr" >&2 || true
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    else
      continue
    fi
  fi

  sleep 5

  containers_file="$(bash "$ROOT_DIR/bench/collect.sh" "$branch_dir")" || true
  ensure_compose_down

  requests_per_sec="$(jq -r '.requests_per_sec // 0' "$load_json")"
  p50="$(jq -r '.p50 // "na"' "$load_json")"
  p95="$(jq -r '.p95 // "na"' "$load_json")"
  p99="$(jq -r '.p99 // "na"' "$load_json")"
  errors="$(jq -r '.errors // "na"' "$load_json")"

  mem_summary="na"
  if [[ -n "${containers_file:-}" ]] && [[ -s "${containers_file:-}" ]]; then
    mem_summary="$("$PYTHON_BIN" - <<PY
import json
data=json.load(open("$containers_file"))
groups={}
for item in data:
    svc=item.get("service","unknown")
    groups.setdefault(svc, []).append(item.get("mem","na"))
parts=[]
for svc in sorted(groups):
    parts.append(f"{svc}:{'/'.join(groups[svc])}")
print(', '.join(parts) if parts else "na")
PY
)"
  fi

  cat <<EOF > "$branch_dir/summary.md"
# Benchmark results for $branch

- Startup: ${startup_seconds}s
- Load: ${requests_per_sec} req/s (p50=${p50}, p95=${p95}, p99=${p99}, errors=${errors})
- Memory snapshot: ${mem_summary}
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
EOF

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

echo "Matrix results written to $matrix_file" >&2
echo "Matrix results written to $matrix_file"