#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_ROOT="$ROOT_DIR/bench/results"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"
HEALTH_URL="http://localhost:8080/api/gateway/status"
LOAD_URL="http://localhost:8080/api/gateway/orders"

# Defaults (override via env if you like)
WARMUP="${WARMUP:-60}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-25}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-120}"

# Optional env vars:
#   ONLY_BRANCH=java25 bash bench/run-matrix.sh
#   MATRIX_FAIL_FAST=1 bash bench/run-matrix.sh
#   MAVEN_MODULES_CSV="services/gateway-service,services/orders-service" bash bench/run-matrix.sh
#   MVN_THREADS="-T1C" bash bench/run-matrix.sh
#   SKIP_BUILD=1 bash bench/run-matrix.sh
MATRIX_FAIL_FAST="${MATRIX_FAIL_FAST:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
MVN_THREADS="${MVN_THREADS:-}"  # e.g. "-T1C" for parallel builds

# Python detection (prefer python3)
PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
  PYTHON_BIN="$(command -v python || true)"
fi

for cmd in docker curl git mvn; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "required command '$cmd' is missing" >&2
    exit 1
  fi
done

if [[ -z "${PYTHON_BIN:-}" ]]; then
  echo "required command 'python3' (or 'python') is missing" >&2
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

#
# Build configuration
# - If $ROOT_DIR/pom.xml exists, we build the root aggregator.
# - Otherwise we build modules explicitly (paths must contain a pom.xml).
# Override module list via MAVEN_MODULES_CSV (comma-separated).
#
declare -a MAVEN_MODULES=(
  "services/quarkus/catalog-service"
  "services/spring-boot/gateway-service"
  "services/spring-boot/orders-service"
  "services/spring-boot/billing-service"
  "services/spring-boot/notification-service"
  "services/spring-boot/analytics-service"
)

if [[ -n "${MAVEN_MODULES_CSV:-}" ]]; then
  IFS=',' read -r -a MAVEN_MODULES <<< "${MAVEN_MODULES_CSV}"
fi

function build_branch() {
  local branch="$1"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Skipping build for $branch (SKIP_BUILD=1)"
    return 0
  fi

  # Case 1: Root aggregator
  if [[ -f "$ROOT_DIR/pom.xml" ]]; then
    echo "Packaging $branch (root aggregator)..."
    (cd "$ROOT_DIR" && mvn -q ${MVN_THREADS} -DskipTests package)
    return 0
  fi

  # Case 2: Module builds
  echo "Packaging $branch (module builds)..."
  for m in "${MAVEN_MODULES[@]}"; do
    local pom="$ROOT_DIR/$m/pom.xml"
    if [[ ! -f "$pom" ]]; then
      echo "ERROR: Missing pom.xml: $pom" >&2
      echo "Hint: adjust MAVEN_MODULES in bench/run-matrix.sh or set MAVEN_MODULES_CSV." >&2
      return 1
    fi
    echo "  - $m"
    (cd "$ROOT_DIR/$m" && mvn -q ${MVN_THREADS} -DskipTests package)
  done
}

function wait_for_health() {
  local url="$1"
  local timeout="$2"

  local start_ts
  start_ts="$(date +%s)"

  echo "Waiting for health endpoint ($url) up to ${timeout}s..."
  while true; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$(date +%s)"
      return 0
    fi
    if [[ "$(date +%s)" -ge $((start_ts + timeout)) ]]; then
      return 1
    fi
    sleep 2
  done
}

for branch in "${branches[@]}"; do
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "branch '$branch' missing, skipping" >&2
    continue
  fi

  echo "---------- Benchmarking branch: $branch ----------"
  git checkout "$branch" >/dev/null 2>&1 || true

  branch_dir="$RESULT_ROOT/$branch/$timestamp"
  mkdir -p "$branch_dir"

  if ! build_branch "$branch"; then
    echo "build failed for $branch" >&2
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    else
      continue
    fi
  fi

  ensure_compose_down
  docker compose -f "$COMPOSE_FILE" up --build -d >/dev/null

  start_ts="$(date +%s)"
  ready_ts=""
  if ready_ts="$(wait_for_health "$HEALTH_URL" "$HEALTH_TIMEOUT_SECONDS")"; then
    :
  else
    echo "health endpoint did not become ready for $branch" >&2
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    else
      continue
    fi
  fi

  startup_seconds=$((ready_ts - start_ts))

  load_result=""
  if ! load_result="$(bash "$ROOT_DIR/bench/loadtest.sh" "$LOAD_URL" "$DURATION" "$WARMUP" "$CONCURRENCY")"; then
    echo "loadtest failed for $branch" >&2
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then
      exit 1
    else
      continue
    fi
  fi

  printf '%s\n' "$load_result" > "$branch_dir/load.json"

  sleep 5
  containers_file="$("$ROOT_DIR/bench/collect.sh" "$branch_dir")" || true
  ensure_compose_down

  mapfile -t metrics < <("$PYTHON_BIN" - <<'PY'
import json, sys
raw = sys.stdin.read()
data = json.loads(raw)
print(data.get("requests_per_sec", 0))
print(data.get("p50", "na"))
print(data.get("p95", "na"))
print(data.get("p99", "na"))
print(data.get("errors", "na"))
PY
<<< "$load_result")

  requests_per_sec="${metrics[0]:-0}"
  p50="${metrics[1]:-na}"
  p95="${metrics[2]:-na}"
  p99="${metrics[3]:-na}"
  errors="${metrics[4]:-na}"

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
    echo "| ${branch} | ${version} | ${startup} | ${requests} | ${p50} | ${p95} | ${p95} | ${p99} | ${errors} | ${memory} | ${details} |" \
      | awk 'BEGIN{OFS="|"}{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12}' 2>/dev/null || \
    echo "| ${branch} | ${version} | ${startup} | ${requests} | ${p50} | ${p95} | ${p99} | ${errors} | ${memory} | ${details} |"
  done
} > "$matrix_file"

echo "Matrix results written to $matrix_file"
