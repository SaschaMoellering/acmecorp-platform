#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNS_PER_BRANCH="${RUNS_PER_BRANCH:-5}"
WARMUP="${WARMUP:-60}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-25}"
DO_FETCH="${DO_FETCH:-1}"
BRANCHES=(java21 java25)

START_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
WORKTREE_ROOT="${WORKTREE_ROOT:-/tmp/acmecorp-java21-vs-java25-$START_UTC}"
SUMMARY_DIR="$ROOT_DIR/bench/results"
CAMPAIGN_DIR="$SUMMARY_DIR/$START_UTC--java21-vs-java25"
COMPOSE_FILE_REL="infra/local/docker-compose.yml"

for cmd in git docker python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "required command '$cmd' is missing" >&2
    exit 1
  fi
done

if ! [[ "$RUNS_PER_BRANCH" =~ ^[1-9][0-9]*$ ]]; then
  echo "RUNS_PER_BRANCH must be a positive integer" >&2
  exit 1
fi

cd "$ROOT_DIR"

if [[ "$DO_FETCH" == "1" ]]; then
  git fetch origin
fi

for branch in "${BRANCHES[@]}"; do
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    git branch --track "$branch" "origin/$branch"
  fi
done

mkdir -p "$SUMMARY_DIR" "$WORKTREE_ROOT" "$CAMPAIGN_DIR"

cleanup() {
  rm -f "$run_manifest"
  docker compose -f "$ROOT_DIR/$COMPOSE_FILE_REL" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

declare -a branch_run_dirs=()
run_manifest="$(mktemp)"

ensure_worktree() {
  local branch="$1"
  local wt="$WORKTREE_ROOT/$branch"

  if [[ -d "$wt/.git" || -f "$wt/.git" ]]; then
    return 0
  fi

  if [[ -d "$wt" ]]; then
    rm -rf "$wt"
  fi

  git worktree add --force --checkout "$wt" "$branch" >/dev/null
}

for branch in "${BRANCHES[@]}"; do
  ensure_worktree "$branch"
  wt="$WORKTREE_ROOT/$branch"

  for run in $(seq 1 "$RUNS_PER_BRANCH"); do
    echo "Running java21-vs-java25 benchmark: branch=$branch run=$run/$RUNS_PER_BRANCH"

    docker compose -f "$ROOT_DIR/$COMPOSE_FILE_REL" down -v --remove-orphans >/dev/null 2>&1 || true

    (
      cd "$wt"
      ONLY_BRANCH="$branch" \
      WARMUP="$WARMUP" \
      DURATION="$DURATION" \
      CONCURRENCY="$CONCURRENCY" \
      bash bench/run-matrix.sh
    )

    latest_run_dir="$(find "$wt/bench/results/$branch" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
    if [[ -z "$latest_run_dir" ]]; then
      echo "could not locate latest result directory for $branch run $run" >&2
      exit 1
    fi

    mkdir -p "$SUMMARY_DIR/$branch"
    cp -R "$latest_run_dir" "$SUMMARY_DIR/$branch/"
    copied_run_dir="$SUMMARY_DIR/$branch/$(basename "$latest_run_dir")"
    branch_run_dirs+=("$branch|$copied_run_dir")
    printf '%s|%s\n' "$branch" "$copied_run_dir" >> "$run_manifest"
  done
done

comparison_file="$CAMPAIGN_DIR/comparison-summary.md"

python3 - <<PY > "$comparison_file"
import pathlib
import re

entries = []
for raw in pathlib.Path(${run_manifest@Q}).read_text(encoding="utf-8").splitlines():
    if raw.strip():
        entries.append(tuple(raw.split("|", 1)))

def parse_summary(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    startup = re.search(r"^- Startup: ([0-9]+(?:\\.[0-9]+)?)s$", text, re.M)
    load = re.search(r"^- Load: (.+)$", text, re.M)
    memory = re.search(r"^- Memory snapshot: (.+)$", text, re.M)
    return {
        "startup": startup.group(1) + "s" if startup else "na",
        "load": load.group(1) if load else "na",
        "memory": memory.group(1) if memory else "na",
    }

lines = [
    f"# Java 21 vs Java 25 benchmark campaign ({pathlib.Path(${START_UTC@Q}).name})",
    "",
    f"- Runs per branch: ${RUNS_PER_BRANCH}",
    f"- Warmup: ${WARMUP}s",
    f"- Duration: ${DURATION}s",
    f"- Concurrency: ${CONCURRENCY}",
    f"- Branches: java21, java25",
    "",
    "| Branch | Run Dir | Startup | Load | Memory |",
    "| --- | --- | --- | --- | --- |",
]

for branch, run_dir_str in entries:
    run_dir = pathlib.Path(run_dir_str)
    summary = parse_summary(run_dir / "summary.md")
    lines.append(
        f"| {branch} | `{run_dir.relative_to(pathlib.Path(${ROOT_DIR@Q}))}` | "
        f"{summary['startup']} | {summary['load']} | {summary['memory']} |"
    )

print("\\n".join(lines))
PY

echo "Comparison summary written to $comparison_file"
