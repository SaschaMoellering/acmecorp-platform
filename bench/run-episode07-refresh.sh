#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNS_PER_BRANCH="${RUNS_PER_BRANCH:-5}"
WARMUP="${WARMUP:-60}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-25}"
DO_FETCH="${DO_FETCH:-1}"
BRANCHES="${BRANCHES:-java11 java17 java21 java25}"

START_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
export START_UTC RUNS_PER_BRANCH

STARTUP_DIAGRAM="$ROOT_DIR/docs/episodes/episode-07/assets/diagrams/E07-D01-startup-comparison.md"
MEMORY_DIAGRAM="$ROOT_DIR/docs/episodes/episode-07/assets/diagrams/E07-D02-memory-footprint-comparison.md"
TELEPROMPTER="$ROOT_DIR/docs/episodes/episode-07/Teleprompter-Script-Episode-7-Polished.md"
SUMMARY_DIR="$ROOT_DIR/bench/results"
WORKTREE_ROOT="${WORKTREE_ROOT:-/tmp/acmecorp-episode07-worktrees-$START_UTC}"

cd "$ROOT_DIR"

if [[ "$DO_FETCH" == "1" ]]; then
  git fetch origin
fi

for b in $BRANCHES; do
  if ! git show-ref --verify --quiet "refs/heads/$b"; then
    git branch --track "$b" "origin/$b"
  fi
done

mkdir -p "$SUMMARY_DIR" "$WORKTREE_ROOT"

cleanup() {
  for b in $BRANCHES; do
    wt="$WORKTREE_ROOT/$b"
    if [[ -d "$wt" ]]; then
      git worktree remove --force "$wt" >/dev/null 2>&1 || true
    fi
  done
}
trap cleanup EXIT

for b in $BRANCHES; do
  wt="$WORKTREE_ROOT/$b"
  if [[ -d "$wt" ]]; then
    git worktree remove --force "$wt" >/dev/null 2>&1 || true
  fi
  git worktree add --force --checkout "$wt" "$b" >/dev/null
  cp "$ROOT_DIR/bench/run-matrix.sh" "$wt/bench/run-matrix.sh"
  cp "$ROOT_DIR/bench/run-once.sh" "$wt/bench/run-once.sh"
  cp "$ROOT_DIR/bench/README.md" "$wt/bench/README.md"

  for run in $(seq 1 "$RUNS_PER_BRANCH"); do
    echo "Running benchmark: branch=$b run=$run/$RUNS_PER_BRANCH"
    (
      cd "$wt"
      ONLY_BRANCH="$b" WARMUP="$WARMUP" DURATION="$DURATION" CONCURRENCY="$CONCURRENCY" bash bench/run-matrix.sh
    )
  done

  mkdir -p "$SUMMARY_DIR/$b"
  if [[ -d "$wt/bench/results/$b" ]]; then
    cp -R "$wt/bench/results/$b/." "$SUMMARY_DIR/$b/"
  fi
  find "$wt/bench/results" -mindepth 1 -maxdepth 1 -type d ! -name "$b" -exec cp -R {} "$SUMMARY_DIR/" \;
done

python3 - <<'PY'
import json
import re
import statistics
from datetime import datetime, timezone
from pathlib import Path

root = Path(".").resolve()
summary_dir = root / "bench" / "results"
startup_diagram = root / "docs" / "episodes" / "episode-07" / "assets" / "diagrams" / "E07-D01-startup-comparison.md"
memory_diagram = root / "docs" / "episodes" / "episode-07" / "assets" / "diagrams" / "E07-D02-memory-footprint-comparison.md"
teleprompter = root / "docs" / "episodes" / "episode-07" / "Teleprompter-Script-Episode-7-Polished.md"

runnable_branches = __import__("os").environ.get("BRANCHES", "java11 java17 java21 java25").split()
branch_meta = [
    ("java11", "Java 11", "J11", "java11"),
    ("java17", "Java 17", "J17", "java17"),
    ("java21", "Java 21", "J21", "java21"),
    ("java25", "Java 25", "J25", "java25"),
]
branches = [meta for meta in branch_meta if meta[0] in runnable_branches]
if not branches:
    raise SystemExit("No supported branches selected for Episode 7 refresh.")
runs_per_branch = int(__import__("os").environ.get("RUNS_PER_BRANCH", "5"))
start_utc = __import__("os").environ["START_UTC"]
start_dt = datetime.strptime(start_utc, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)

def parse_mem_to_mib(mem: str):
    m = re.match(r"\s*([0-9]*\.?[0-9]+)\s*([KMG]i?)B\s*$", mem or "")
    if not m:
        return None
    val = float(m.group(1))
    unit = m.group(2).lower()
    if unit.startswith("k"):
        return val / 1024.0
    if unit.startswith("g"):
        return val * 1024.0
    return val

def eligible_dirs(branch: str):
    bdir = summary_dir / branch
    if not bdir.exists():
        return []
    dirs = []
    for child in bdir.iterdir():
        if not child.is_dir():
            continue
        try:
            ts = datetime.strptime(child.name, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
        except ValueError:
            continue
        if ts >= start_dt:
            dirs.append(child)
    dirs.sort(key=lambda p: p.name, reverse=True)
    return list(reversed(dirs[:runs_per_branch]))

results = {}
for branch, _, _, _ in branches:
    dirs = eligible_dirs(branch)
    if len(dirs) < runs_per_branch:
        raise SystemExit(
            f"Expected at least {runs_per_branch} runs for {branch} since {start_utc}, found {len(dirs)}"
        )

    startup_values = []
    startup_trace_values = []
    rps_values = []
    mem_values = []
    for d in dirs:
        summary_md = (d / "summary.md").read_text(encoding="utf-8")
        m = re.search(r"Startup:\s+([0-9]+(?:\.[0-9]+)?)s", summary_md)
        if not m:
            raise SystemExit(f"Could not parse startup from {d / 'summary.md'}")
        startup_values.append(float(m.group(1)))

        startup_trace = json.loads((d / "orders-startup.json").read_text(encoding="utf-8"))
        trace_ready = startup_trace.get("applicationReadySinceJvmStartMillis")
        if not isinstance(trace_ready, (int, float)) or trace_ready < 0:
            raise SystemExit(f"Could not parse applicationReadySinceJvmStartMillis from {d / 'orders-startup.json'}")
        startup_trace_values.append(float(trace_ready))

        load_json = json.loads((d / "load.json").read_text(encoding="utf-8"))
        rps_values.append(float(load_json.get("requests_per_sec", 0)))

        containers = json.loads((d / "containers.json").read_text(encoding="utf-8"))
        orders = [c for c in containers if c.get("service") == "orders-service"]
        if not orders:
            raise SystemExit(f"No orders-service memory entry in {d / 'containers.json'}")
        mem_mib = parse_mem_to_mib(str(orders[0].get("mem", "")))
        if mem_mib is None:
            raise SystemExit(f"Could not parse orders-service mem '{orders[0].get('mem')}' in {d / 'containers.json'}")
        mem_values.append(mem_mib)

    results[branch] = {
        "runs": [d.name for d in dirs],
        "startup_median_s": statistics.median(startup_values),
        "orders_main_to_ready_median_ms": statistics.median(startup_trace_values),
        "rps_median": statistics.median(rps_values),
        "orders_mem_median_mib": statistics.median(mem_values),
    }

def fmt_startup(v):
    return f"{v:.2f}s"

def fmt_mem(v):
    return f"{v:.1f} MiB"

def fmt_rps(v):
    return f"{v:.1f} req/s"

def fmt_ms(v):
    return f"{int(round(v))} ms"

startup_text = startup_diagram.read_text(encoding="utf-8")
startup_text = re.sub(
    r'Method\["<b>Metrics?</b><br/>.*?Minimum: \d+ runs per Java version"\]:::metric',
    f'Method["<b>Metrics</b><br/>External readiness median via /api/gateway/status<br/>Orders-service main() to ApplicationReadyEvent median<br/>Minimum: {runs_per_branch} runs per Java version"]:::metric',
    startup_text,
    flags=re.S,
)
for branch, label, node_id, css_class in branches:
    startup_text = re.sub(
        rf'{node_id}\["<b>{re.escape(label)}</b><br/>.*?"\]:::{css_class}',
        f'{node_id}["<b>{label}</b><br/>Readiness: {fmt_startup(results[branch]["startup_median_s"])}<br/>Orders main→ready: {fmt_ms(results[branch]["orders_main_to_ready_median_ms"])}"]:::{css_class}',
        startup_text,
    )
startup_text = re.sub(
    r'Result\["<b>Status</b><br/>[^"]*"\]:::metric',
    f'Result["<b>Status</b><br/>Median of {runs_per_branch} cold starts per Java version"]:::metric',
    startup_text,
)
startup_diagram.write_text(startup_text, encoding="utf-8")

memory_text = memory_diagram.read_text(encoding="utf-8")
for branch, label, node_id, css_class in branches:
    memory_text = re.sub(
        rf'{node_id}\["<b>{re.escape(label)}</b><br/>Memory snapshot median: [^"]*"\]:::{css_class}',
        f'{node_id}["<b>{label}</b><br/>Memory snapshot median: {fmt_mem(results[branch]["orders_mem_median_mib"])}"]:::{css_class}',
        memory_text,
    )
memory_text = re.sub(
    r'Status\["<b>Status</b><br/>[^"]*"\]:::metric',
    f'Status["<b>Status</b><br/>Median of {runs_per_branch} cold starts per Java version"]:::metric',
    memory_text,
)
memory_diagram.write_text(memory_text, encoding="utf-8")

tp_text = teleprompter.read_text(encoding="utf-8")
summary_lines = [
    f"- {label}: readiness {fmt_startup(results[branch]['startup_median_s'])}, orders-service main to ready {fmt_ms(results[branch]['orders_main_to_ready_median_ms'])}, orders-service memory {fmt_mem(results[branch]['orders_mem_median_mib'])}, throughput {fmt_rps(results[branch]['rps_median'])}"
    for branch, label, _, _ in branches
]
summary_block = (
    f"Once those {runs_per_branch} runs are complete, we report medians only.\n\n"
    "Measured medians from the latest rerun set:\n"
    + "\n".join(summary_lines)
    + "\n\n"
    + "The important distinction is that readiness is measured externally at the gateway, while the orders-service main to ready value is measured inside the service from `main()` to `ApplicationReadyEvent`."
)
pattern = (
    r"Once those (?:five|\d+) runs are complete(?: for each branch)?, we report medians only\.\n"
    r"(?:\nMeasured medians from the latest rerun set:\n(?:- .*\n?){0,10})?"
)
tp_text, replaced = re.subn(pattern, summary_block, tp_text, count=1)
if replaced == 0:
    raise SystemExit("Could not find teleprompter benchmark summary anchor block to update.")
teleprompter.write_text(tp_text, encoding="utf-8")

stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
summary_out = summary_dir / f"episode07-median-summary-{stamp}.json"
summary_out.write_text(json.dumps(results, indent=2), encoding="utf-8")

print("Updated files:")
print(f"- {startup_diagram}")
print(f"- {memory_diagram}")
print(f"- {teleprompter}")
print(f"- {summary_out}")
PY

echo "Episode 7 benchmark refresh complete."
