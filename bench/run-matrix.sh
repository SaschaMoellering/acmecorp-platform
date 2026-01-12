#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_ROOT="$ROOT_DIR/bench/results"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"
HEALTH_URL="http://localhost:8080/api/gateway/status"
LOAD_URL="http://localhost:8080/api/gateway/orders"

WARMUP="${WARMUP:-60}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-25}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-120}"

LOAD_READY_URL="${LOAD_READY_URL:-$LOAD_URL}"
LOAD_READY_TIMEOUT_SECONDS="${LOAD_READY_TIMEOUT_SECONDS:-120}"
LOAD_READY_CODES="${LOAD_READY_CODES:-200}"

MATRIX_FAIL_FAST="${MATRIX_FAIL_FAST:-0}"
COMPOSE_QUIET="${COMPOSE_QUIET:-1}"
BUILD_MODE="${BUILD_MODE:-docker}"

SKIP_BUILD="${SKIP_BUILD:-0}"
MVN_THREADS="${MVN_THREADS:-}"

PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
  PYTHON_BIN="$(command -v python || true)"
fi

for cmd in docker curl git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "required command '$cmd' is missing" >&2
    exit 1
  fi
done
if [[ "$BUILD_MODE" == "hybrid" ]] && ! command -v mvn >/dev/null 2>&1; then
  echo "required command 'mvn' is missing (BUILD_MODE=hybrid)" >&2
  exit 1
fi
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

ensure_compose_down() {
  docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}

cleanup() {
  ensure_compose_down
  git checkout "$initial_branch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

declare -a summary_rows=()

branch_java_version() {
  case "$1" in
    java11) echo "11" ;;
    java17) echo "17" ;;
    java21) echo "21" ;;
    main) echo "21" ;;
    java25) echo "25" ;;
    *) echo "unknown" ;;
  esac
}

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

build_branch_hybrid() {
  local branch="$1"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Skipping host build for $branch (SKIP_BUILD=1)" >&2
    return 0
  fi

  if [[ -f "$ROOT_DIR/pom.xml" ]]; then
    echo "Packaging $branch (root aggregator)..." >&2
    (cd "$ROOT_DIR" && mvn -q ${MVN_THREADS} -DskipTests package)
    return 0
  fi

  echo "Packaging $branch (module builds)..." >&2
  for m in "${MAVEN_MODULES[@]}"; do
    local pom="$ROOT_DIR/$m/pom.xml"
    if [[ ! -f "$pom" ]]; then
      echo "ERROR: Missing pom.xml: $pom" >&2
      return 1
    fi
    echo "  - $m" >&2
    (cd "$ROOT_DIR/$m" && mvn -q ${MVN_THREADS} -DskipTests package)
  done
}

wait_for_health() {
  local url="$1"
  local timeout="$2"
  local start_ts
  start_ts="$(date +%s)"

  echo "Waiting for health endpoint ($url) up to ${timeout}s..." >&2
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

wait_for_http_codes() {
  local url="$1"
  local timeout="$2"
  local codes_csv="$3"
  local start_ts
  start_ts="$(date +%s)"

  local codes
  codes="$(echo "$codes_csv" | tr ',' ' ' | xargs)"

  echo "Waiting for endpoint readiness ($url) expecting HTTP [${codes}] up to ${timeout}s..." >&2
  while true; do
    local code
    code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || true)"
    if [[ -n "$code" ]]; then
      for ok in $codes; do
        if [[ "$code" == "$ok" ]]; then
          echo "$(date +%s)"
          return 0
        fi
      done
    fi

    if [[ "$(date +%s)" -ge $((start_ts + timeout)) ]]; then
      echo "Timeout waiting for $url (last http_code=${code:-na})" >&2
      return 1
    fi
    sleep 2
  done
}

compose_up_build() {
  if [[ "$COMPOSE_QUIET" == "1" ]]; then
    docker compose -f "$COMPOSE_FILE" up --build -d >/dev/null
  else
    docker compose -f "$COMPOSE_FILE" up --build -d
  fi
}

dump_load_debug() {
  local branch="$1"
  local out="$2"
  local err="$3"
  echo "loadtest output is not valid JSON for $branch" >&2
  echo "----- loadtest stdout (first 200 lines) -----" >&2
  sed -n '1,200p' "$out" >&2 || true
  echo "----- loadtest stderr (first 200 lines) -----" >&2
  sed -n '1,200p' "$err" >&2 || true
}

dump_compose_debug() {
  echo "----- docker compose ps -----" >&2
  docker compose -f "$COMPOSE_FILE" ps >&2 || true
  echo "----- gateway-service logs (tail=200) -----" >&2
  docker compose -f "$COMPOSE_FILE" logs --tail=200 gateway-service >&2 || true
  echo "----- orders-service logs (tail=200) -----" >&2
  docker compose -f "$COMPOSE_FILE" logs --tail=200 orders-service >&2 || true
}

for branch in "${branches[@]}"; do
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "branch '$branch' missing, skipping" >&2
    continue
  fi

  echo "---------- Benchmarking branch: $branch ----------" >&2
  git checkout "$branch" >/dev/null 2>&1 || true

  branch_dir="$RESULT_ROOT/$branch/$timestamp"
  mkdir -p "$branch_dir"

  if [[ "$BUILD_MODE" == "hybrid" ]]; then
    if ! build_branch_hybrid "$branch"; then
      echo "host build failed for $branch" >&2
      if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
    fi
  else
    echo "BUILD_MODE=docker: skipping host Maven build for $branch" >&2
  fi

  ensure_compose_down
  compose_up_build

  start_ts="$(date +%s)"
  if ! ready_ts="$(wait_for_health "$HEALTH_URL" "$HEALTH_TIMEOUT_SECONDS")"; then
    echo "health endpoint did not become ready for $branch" >&2
    dump_compose_debug
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  if ! load_ready_ts="$(wait_for_http_codes "$LOAD_READY_URL" "$LOAD_READY_TIMEOUT_SECONDS" "$LOAD_READY_CODES")"; then
    echo "load endpoint did not become ready for $branch" >&2
    dump_compose_debug
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  startup_seconds=$((ready_ts - start_ts))

  echo "Running load test: warmup=${WARMUP}s duration=${DURATION}s concurrency=${CONCURRENCY}" >&2
  load_stdout="$branch_dir/load.stdout.txt"
  load_stderr="$branch_dir/load.stderr.txt"
  load_json="$branch_dir/load.json"

  # loadtest emits JSON to stdout; we decide based on JSON.ok
  bash "$ROOT_DIR/bench/loadtest.sh" "$LOAD_URL" "$DURATION" "$WARMUP" "$CONCURRENCY" >"$load_stdout" 2>"$load_stderr"

  if [[ ! -s "$load_stdout" ]]; then
    echo "loadtest produced empty stdout for $branch" >&2
    dump_load_debug "$branch" "$load_stdout" "$load_stderr"
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  # Validate JSON + canonicalize to load.json
  if ! "$PYTHON_BIN" -c 'import json,sys; raw=sys.stdin.read().strip();
if not raw: raise SystemExit("empty stdout from loadtest");
obj=json.loads(raw); print(json.dumps(obj))' <"$load_stdout" >"$load_json"; then
    dump_load_debug "$branch" "$load_stdout" "$load_stderr"
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  # Parse metrics (+ ok) from canonical JSON file
  mapfile -t metrics < <("$PYTHON_BIN" - <<PY
import json

data = json.load(open("$load_json"))

ok = bool(data.get("ok", True))
rps = data.get("requests_per_sec", 0)
p50 = data.get("p50", "na")
p95 = data.get("p95", "na")
p99 = data.get("p99", "na")

err = "na"
if not ok:
    err = data.get("error", "ok=false")
else:
    non2xx = data.get("http_non2xx", "na")
    sock = data.get("socket_errors", {})
    # only show if meaningful
    if non2xx != "na" or (isinstance(sock, dict) and any(int(v) != 0 for v in sock.values() if isinstance(v, int))):
        err = f"http_non2xx={non2xx} socket_errors={sock}"

print("1" if ok else "0")
print(rps)
print(p50)
print(p95)
print(p99)
print(err)
PY
)

  load_ok="${metrics[0]:-0}"
  requests_per_sec="${metrics[1]:-0}"
  p50="${metrics[2]:-na}"
  p95="${metrics[3]:-na}"
  p99="${metrics[4]:-na}"
  errors="${metrics[5]:-na}"

  if [[ "$load_ok" != "1" ]]; then
    echo "loadtest reported ok=false for $branch: ${errors}" >&2
    dump_load_debug "$branch" "$load_stdout" "$load_stderr"
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  sleep 5
  containers_file="$("$ROOT_DIR/bench/collect.sh" "$branch_dir")" || true
  ensure_compose_down

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
    IFS='|' read -r b startup requests p50 p95 p99 errors memory <<< "$row"
    version="$(branch_java_version "$b")"
    details="[link](../${b}/${timestamp}/summary.md)"
    echo "| ${b} | ${version} | ${startup} | ${requests} | ${p50} | ${p95} | ${p99} | ${errors} | ${memory} | ${details} |"
  done
} > "$matrix_file"

echo "Matrix results written to $matrix_file"