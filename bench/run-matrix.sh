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
trap 'git checkout "$initial_branch" >/dev/null 2>&1 || true' EXIT

function ensure_compose_down() {
  "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}
trap 'ensure_compose_down' EXIT

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

  # Prefer jq if present: validate JSON strictly
  if [[ -n "$JQ_BIN" ]]; then
    if printf '%s' "$stdout" | jq -e . >/dev/null 2>&1; then
      printf '%s' "$stdout"
      return 0
    fi
  fi

  # Fallback: last line that looks like JSON object/array
  local line
  line="$(printf '%s\n' "$stdout" | awk '$0 ~ /^[[:space:]]*[{[]/ {json=$0} END{print json}')"
  if [[ -z "$line" ]]; then
    return 1
  fi
  # Validate via python
  "$PYTHON_BIN" - <<PY >/dev/null 2>&1
import json, sys
json.loads(sys.argv[1])
PY "$line" || return 1
  printf '%s' "$line"
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

  # ---- IMPORTANT FIX: keep stdout (JSON) clean; store stderr separately ----
  load_stderr_file="$branch_dir/load.stderr.txt"
  load_stdout="$(
    bash "$ROOT_DIR/bench/loadtest.sh" "$LOAD_URL" "$DURATION" "$WARMUP" "$CONCURRENCY" \
      2> "$load_stderr_file" || true
  )"

  printf '%s\n' "$load_stdout" > "$branch_dir/load.raw.stdout.txt"
  # stderr already stored in $load_stderr_file

  if ! load_result="$(extract_json_from_stdout "$load_stdout")"; then
    echo "loadtest output is not valid JSON for $branch" >&2
    echo "----- stdout -----" >&2
    printf '%s\n' "$load_stdout" >&2
    echo "----- stderr -----" >&2
    sed -n '1,200p' "$load_stderr_file" >&2 || true
    ensure_compose_down
    exit 1
  fi

  printf '%s\n' "$load_result" > "$branch_dir/load.json"

  sleep 5

  # collect.sh expects PYTHON_BIN in env
  containers_file="$(bash "$ROOT_DIR/bench/collect.sh" "$branch_dir")"
  ensure_compose_down

  mapfile -t metrics < <("$PYTHON_BIN" - <<'PY'
import json, sys
data=json.loads(sys.stdin.read())
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

  mem_summary="$("$PYTHON_BIN" - <<PY
import json
data=json.load(open("$containers_file"))
groups={}
for item in data:
    svc=item["service"]
    groups.setdefault(svc, []).append(item["mem"])
parts=[]
for svc in sorted(groups):
    parts.append(f"{svc}:{'/'.join(groups[svc])}")
print(', '.join(parts))
PY
)"

  cat <<EOF > "$branch_dir/summary.md"
# Benchmark results for $branch

- Startup: ${startup_seconds}s
- Load: ${requests_per_sec} req/s (p50=${p50}, p95=${p95}, p99=${p99}, errors=${errors})
- Memory snapshot: ${mem_summary}
- Load metrics: [load.json](load.json)
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

echo "Matrix results written to $matrix_file"
