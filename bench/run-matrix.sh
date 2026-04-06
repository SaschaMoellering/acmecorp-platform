#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_ROOT="$ROOT_DIR/bench/results"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"
HEALTH_URL="${HEALTH_URL:-http://localhost:8080/api/gateway/status}"
LOAD_URL="${LOAD_URL:-http://localhost:8080/api/gateway/orders}"
SCENARIO="${SCENARIO:-mixed}"

WARMUP="${WARMUP:-60}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-25}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-120}"
HEALTH_POLL_INTERVAL_SECONDS="${HEALTH_POLL_INTERVAL_SECONDS:-0.10}"

LOAD_READY_URL="${LOAD_READY_URL:-$LOAD_URL}"
LOAD_READY_TIMEOUT_SECONDS="${LOAD_READY_TIMEOUT_SECONDS:-120}"
LOAD_READY_CODES="${LOAD_READY_CODES:-200}"
ORDERS_STARTUP_URL="${ORDERS_STARTUP_URL:-http://localhost:8081/api/orders/startup}"

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
matrix_label="$timestamp"
if [[ "$SCENARIO" != "mixed" ]]; then
  matrix_label="${timestamp}--${SCENARIO}"
fi
matrix_dir="$RESULT_ROOT/$matrix_label"
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

if [[ "$SCENARIO" == "methodology-check" && -z "${ONLY_BRANCH:-}" ]]; then
  branches=("$initial_branch")
fi

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
  local start_ms
  start_ms="$(date +%s%3N)"
  local timeout_ms=$((timeout * 1000))

  echo "Waiting for health endpoint ($url) up to ${timeout}s..." >&2
  while true; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$(date +%s%3N)"
      return 0
    fi
    if [[ "$(date +%s%3N)" -ge $((start_ms + timeout_ms)) ]]; then
      return 1
    fi
    sleep "$HEALTH_POLL_INTERVAL_SECONDS"
  done
}

wait_for_http_codes() {
  local url="$1"
  local timeout="$2"
  local codes_csv="$3"
  local start_ms
  start_ms="$(date +%s%3N)"
  local timeout_ms=$((timeout * 1000))

  local codes
  codes="$(echo "$codes_csv" | tr ',' ' ' | xargs)"

  echo "Waiting for endpoint readiness ($url) expecting HTTP [${codes}] up to ${timeout}s..." >&2
  while true; do
    local code
    code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || true)"
    if [[ -n "$code" ]]; then
      for ok in $codes; do
        if [[ "$code" == "$ok" ]]; then
          echo "$(date +%s%3N)"
          return 0
        fi
      done
    fi

    if [[ "$(date +%s%3N)" -ge $((start_ms + timeout_ms)) ]]; then
      echo "Timeout waiting for $url (last http_code=${code:-na})" >&2
      return 1
    fi
    sleep "$HEALTH_POLL_INTERVAL_SECONDS"
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

capture_orders_startup_trace() {
  local output_file="$1"

  if curl -fsS "$ORDERS_STARTUP_URL" >"$output_file"; then
    return 0
  fi

  local container_ip
  container_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' local-orders-service-1 2>/dev/null || true)"
  if [[ -n "$container_ip" ]] && curl -fsS "http://${container_ip}:8080/api/orders/startup" >"$output_file"; then
    return 0
  fi

  echo "{\"error\":\"startup instrumentation unavailable\",\"url\":\"$ORDERS_STARTUP_URL\",\"container_ip\":\"${container_ip:-}\"}" >"$output_file"
  return 1
}

write_request_body() {
  local path="$1"
  cat >"$path" <<'EOF'
{
  "customerEmail": "bench@example.com",
  "items": [
    {"productId":"11111111-1111-1111-1111-111111111111","quantity":1}
  ]
}
EOF
}

write_headers_file() {
  local path="$1"
  shift || true
  : >"$path"
  for header in "$@"; do
    [[ -n "$header" ]] || continue
    printf '%s\n' "$header" >>"$path"
  done
}

post_json() {
  local url="$1"
  local body="${2:-}"
  local tmp
  tmp="$(mktemp)"
  local curl_args=(-fsS -X POST "$url")
  if [[ -n "$body" ]]; then
    curl_args+=(-H "Content-Type: application/json" --data "$body")
  fi
  if curl "${curl_args[@]}" >"$tmp"; then
    cat "$tmp"
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

prepare_seed_data() {
  wait_for_http_codes "http://localhost:8080/api/gateway/status" "$HEALTH_TIMEOUT_SECONDS" "200" >/dev/null
  post_json "http://localhost:8080/api/gateway/seed" "" >/dev/null
}

resolve_seed_order_id() {
  "$PYTHON_BIN" - <<'PY'
import json
import urllib.request

with urllib.request.urlopen("http://localhost:8080/api/gateway/orders/latest", timeout=10) as response:
    payload = json.load(response)

if not payload:
    raise SystemExit("No seeded orders returned by gateway latest endpoint")

first = payload[0]
order_id = first.get("id")
if order_id is None:
    raise SystemExit("Seeded order missing id field")

print(order_id)
PY
}

configure_scenario() {
  local branch="$1"
  local branch_dir="$2"

  SCENARIO_NAME="$SCENARIO"
  SCENARIO_CAPTURE_STARTUP=1
  SCENARIO_RUN_LOAD=1
  SCENARIO_BRANCH_MODE="branch-comparison"
  SCENARIO_HEALTH_URL="$HEALTH_URL"
  SCENARIO_LOAD_URL="$LOAD_URL"
  SCENARIO_LOAD_READY_URL="$LOAD_READY_URL"
  SCENARIO_LOAD_READY_CODES="$LOAD_READY_CODES"
  SCENARIO_LOAD_METHOD="GET"
  SCENARIO_LOAD_BODY_FILE=""
  SCENARIO_LOAD_HEADER_FILE=""
  SCENARIO_IDEMPOTENCY_ENABLED=0
  SCENARIO_INCLUDE_HISTORY=0
  SCENARIO_METADATA_NOTES=""
  SCENARIO_PREPARE="none"

  local body_file="$branch_dir/request.body.json"
  local header_file="$branch_dir/request.headers.txt"
  local idem_key=""

  case "$SCENARIO_NAME" in
    mixed)
      ;;
    orders-startup)
      SCENARIO_HEALTH_URL="http://localhost:8081/api/orders/status"
      SCENARIO_RUN_LOAD=0
      SCENARIO_METADATA_NOTES="startup-only"
      ;;
    orders-list)
      SCENARIO_HEALTH_URL="http://localhost:8081/api/orders/status"
      SCENARIO_LOAD_URL="http://localhost:8081/api/orders?page=0&size=20"
      SCENARIO_LOAD_READY_URL="$SCENARIO_LOAD_URL"
      SCENARIO_PREPARE="seed"
      ;;
    orders-create)
      SCENARIO_HEALTH_URL="http://localhost:8081/api/orders/status"
      SCENARIO_LOAD_URL="http://localhost:8081/api/orders"
      SCENARIO_LOAD_READY_URL="$SCENARIO_LOAD_URL"
      SCENARIO_LOAD_METHOD="POST"
      SCENARIO_PREPARE="seed"
      write_request_body "$body_file"
      write_headers_file "$header_file" "Content-Type: application/json"
      SCENARIO_LOAD_BODY_FILE="$body_file"
      SCENARIO_LOAD_HEADER_FILE="$header_file"
      ;;
    orders-create-idempotent)
      SCENARIO_HEALTH_URL="http://localhost:8081/api/orders/status"
      SCENARIO_LOAD_URL="http://localhost:8081/api/orders"
      SCENARIO_LOAD_READY_URL="$SCENARIO_LOAD_URL"
      SCENARIO_LOAD_METHOD="POST"
      SCENARIO_PREPARE="seed"
      SCENARIO_IDEMPOTENCY_ENABLED=1
      idem_key="bench-${branch}-${SCENARIO_NAME}-${timestamp}"
      write_request_body "$body_file"
      write_headers_file "$header_file" \
        "Content-Type: application/json" \
        "Idempotency-Key: ${idem_key}"
      SCENARIO_LOAD_BODY_FILE="$body_file"
      SCENARIO_LOAD_HEADER_FILE="$header_file"
      SCENARIO_METADATA_NOTES="idempotency-key=${idem_key}"
      ;;
    gateway-order-details)
      SCENARIO_LOAD_READY_URL="http://localhost:8080/api/gateway/orders/latest"
      SCENARIO_PREPARE="seed-order-id"
      ;;
    gateway-order-details-history)
      SCENARIO_LOAD_READY_URL="http://localhost:8080/api/gateway/orders/latest"
      SCENARIO_PREPARE="seed-order-id"
      SCENARIO_INCLUDE_HISTORY=1
      ;;
    methodology-check)
      SCENARIO_BRANCH_MODE="java25-only"
      SCENARIO_METADATA_NOTES="records external-ready and load-ready markers side-by-side"
      ;;
    *)
      echo "Unknown SCENARIO='$SCENARIO_NAME'" >&2
      exit 1
      ;;
  esac
}

prepare_scenario_runtime() {
  case "$SCENARIO_PREPARE" in
    none)
      ;;
    seed)
      prepare_seed_data
      ;;
    seed-order-id)
      prepare_seed_data
      local order_id
      order_id="$(resolve_seed_order_id)"
      if [[ "$SCENARIO_INCLUDE_HISTORY" == "1" ]]; then
        SCENARIO_LOAD_URL="http://localhost:8080/api/gateway/orders/${order_id}?includeHistory=true"
      else
        SCENARIO_LOAD_URL="http://localhost:8080/api/gateway/orders/${order_id}?includeHistory=false"
      fi
      SCENARIO_LOAD_READY_URL="$SCENARIO_LOAD_URL"
      SCENARIO_METADATA_NOTES="orderId=${order_id}"
      ;;
    *)
      echo "Unknown scenario prepare step '$SCENARIO_PREPARE'" >&2
      exit 1
      ;;
  esac
}

write_scenario_metadata() {
  local output_file="$1"
  local notes_json="null"
  if [[ -n "$SCENARIO_METADATA_NOTES" ]]; then
    notes_json="$(printf '%s' "$SCENARIO_METADATA_NOTES" | "$PYTHON_BIN" -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  fi
  cat >"$output_file" <<EOF
{
  "timestamp": "${timestamp}",
  "branch": "${branch}",
  "java_version": "$(branch_java_version "$branch")",
  "scenario": "${SCENARIO_NAME}",
  "branch_mode": "${SCENARIO_BRANCH_MODE}",
  "capture_startup": ${SCENARIO_CAPTURE_STARTUP},
  "run_load": ${SCENARIO_RUN_LOAD},
  "health_url": "${SCENARIO_HEALTH_URL}",
  "load_url": "${SCENARIO_LOAD_URL}",
  "load_ready_url": "${SCENARIO_LOAD_READY_URL}",
  "load_method": "${SCENARIO_LOAD_METHOD}",
  "load_body_file": "${SCENARIO_LOAD_BODY_FILE}",
  "load_header_file": "${SCENARIO_LOAD_HEADER_FILE}",
  "idempotency_enabled": ${SCENARIO_IDEMPOTENCY_ENABLED},
  "include_history": ${SCENARIO_INCLUDE_HISTORY},
  "notes": ${notes_json}
}
EOF
}

for branch in "${branches[@]}"; do
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "branch '$branch' missing, skipping" >&2
    continue
  fi

  echo "---------- Benchmarking branch: $branch ----------" >&2
  if ! git checkout "$branch" >/dev/null 2>&1; then
    echo "failed to checkout branch '$branch'" >&2
    echo "current branch remains: $(git rev-parse --abbrev-ref HEAD)" >&2
    echo "benchmark matrix requires a clean worktree or a separate git worktree per branch" >&2
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$current_branch" != "$branch" ]]; then
    echo "expected branch '$branch' but current branch is '$current_branch'" >&2
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  run_label="$timestamp"
  if [[ "$SCENARIO" != "mixed" ]]; then
    run_label="${timestamp}--${SCENARIO}"
  fi
  branch_dir="$RESULT_ROOT/$branch/$run_label"
  mkdir -p "$branch_dir"
  configure_scenario "$branch" "$branch_dir"

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

  start_ts="$(date +%s%3N)"
  if ! ready_ts="$(wait_for_health "$SCENARIO_HEALTH_URL" "$HEALTH_TIMEOUT_SECONDS")"; then
    echo "health endpoint did not become ready for $branch" >&2
    dump_compose_debug
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  prepare_scenario_runtime
  scenario_metadata_file="$branch_dir/scenario.json"
  write_scenario_metadata "$scenario_metadata_file"

  if [[ "$SCENARIO_RUN_LOAD" == "1" ]] && ! load_ready_ts="$(wait_for_http_codes "$SCENARIO_LOAD_READY_URL" "$LOAD_READY_TIMEOUT_SECONDS" "$SCENARIO_LOAD_READY_CODES")"; then
    echo "load endpoint did not become ready for $branch" >&2
    dump_compose_debug
    ensure_compose_down
    if [[ "$MATRIX_FAIL_FAST" == "1" ]]; then exit 1; else continue; fi
  fi

  startup_ms=$((ready_ts - start_ts))
  startup_seconds="$(awk "BEGIN { printf \"%.3f\", ${startup_ms}/1000 }")"
  load_ready_delay_ms="na"
  startup_to_load_ready_ms="na"
  if [[ "${load_ready_ts:-}" =~ ^[0-9]+$ ]]; then
    load_ready_delay_ms=$((load_ready_ts - ready_ts))
    startup_to_load_ready_ms=$((load_ready_ts - start_ts))
  fi
  startup_trace_file="$branch_dir/orders-startup.json"
  load_stdout="$branch_dir/load.stdout.txt"
  load_stderr="$branch_dir/load.stderr.txt"
  load_json="$branch_dir/load.json"
  capture_orders_startup_trace "$startup_trace_file" || true

  requests_per_sec="na"
  p50="na"
  p95="na"
  p99="na"
  errors="na"

  if [[ "$SCENARIO_RUN_LOAD" == "1" ]]; then
    echo "Running load test: scenario=${SCENARIO_NAME} method=${SCENARIO_LOAD_METHOD} warmup=${WARMUP}s duration=${DURATION}s concurrency=${CONCURRENCY}" >&2
    # loadtest emits JSON to stdout; we decide based on JSON.ok
    LOAD_METHOD="$SCENARIO_LOAD_METHOD" \
    LOAD_BODY_FILE="$SCENARIO_LOAD_BODY_FILE" \
    LOAD_HEADER_FILE="$SCENARIO_LOAD_HEADER_FILE" \
    bash "$ROOT_DIR/bench/loadtest.sh" "$SCENARIO_LOAD_URL" "$DURATION" "$WARMUP" "$CONCURRENCY" >"$load_stdout" 2>"$load_stderr"

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
  else
    echo '{"ok":true,"skipped":true,"reason":"startup-only scenario"}' >"$load_json"
    : >"$load_stdout"
    : >"$load_stderr"
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

- Scenario: ${SCENARIO_NAME}
- Branch mode: ${SCENARIO_BRANCH_MODE}
- Startup: ${startup_seconds}s
- Startup raw: ${startup_ms} ms
- Load ready delay after health: ${load_ready_delay_ms} ms
- Startup to load-ready: ${startup_to_load_ready_ms} ms
- Health endpoint: ${SCENARIO_HEALTH_URL}
- Load target: ${SCENARIO_LOAD_METHOD} ${SCENARIO_LOAD_URL}
- Scenario metadata: [scenario.json](scenario.json)
- Orders startup trace: [orders-startup.json](orders-startup.json)
- Load: ${requests_per_sec} req/s (p50=${p50}, p95=${p95}, p99=${p99}, errors=${errors})
- Memory snapshot: ${mem_summary}
- Load metrics: [load.json](load.json)
- Load stdout: [load.stdout.txt](load.stdout.txt)
- Load stderr: [load.stderr.txt](load.stderr.txt)
- Containers: [containers.json](containers.json)
- DB query count: not collected by the current harness
EOF

  summary_rows+=("$branch|$SCENARIO_NAME|$startup_seconds|$requests_per_sec|$p50|$p95|$p99|$errors|$mem_summary")
done

matrix_file="$matrix_dir/matrix-summary.md"
{
  echo "# Java benchmark matrix (${timestamp})"
  echo
  echo "| Branch | Scenario | Java | Startup (s) | Req/s | P50 | P95 | P99 | Errors | Memory | Details |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
  for row in "${summary_rows[@]}"; do
    IFS='|' read -r b scenario startup requests p50 p95 p99 errors memory <<< "$row"
    version="$(branch_java_version "$b")"
    details="[link](../${b}/${run_label}/summary.md)"
    echo "| ${b} | ${scenario} | ${version} | ${startup} | ${requests} | ${p50} | ${p95} | ${p99} | ${errors} | ${memory} | ${details} |"
  done
} > "$matrix_file"

echo "Matrix results written to $matrix_file"
