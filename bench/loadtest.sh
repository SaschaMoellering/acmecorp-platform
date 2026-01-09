#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

url="${1:?usage: $0 <url> [duration_s] [warmup_s] [concurrency] [threads]}"
duration="${2:-120}"
warmup="${3:-60}"
concurrency="${4:-25}"
threads="${5:-4}"

PYTHON_BIN="python"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "python (or python3) is required to run the load test" >&2
  exit 1
fi

if [[ "$duration" -lt 5 ]]; then
  echo "measurement duration must be at least 5 seconds" >&2
  exit 1
fi

tool=""
if command -v wrk >/dev/null 2>&1; then
  tool="wrk"
elif command -v hey >/dev/null 2>&1; then
  tool="hey"
elif command -v k6 >/dev/null 2>&1; then
  tool="k6"
else
  tool="curl"
fi

tmpfile="$(mktemp)"
tmpdir="$(mktemp -d)"
trap 'rm -f "$tmpfile"; rm -rf "$tmpdir"' EXIT

echo "Running ${tool} load test against ${url} (warmup=${warmup}s, duration=${duration}s, concurrency=${concurrency})..." >&2

if [[ "$tool" == "wrk" ]]; then
  if [[ "$warmup" -gt 0 ]]; then
    wrk -t"$threads" -c"$concurrency" -d"${warmup}s" "$url" >/dev/null
  fi
  wrk -t"$threads" -c"$concurrency" -d"${duration}s" --latency "$url" > "$tmpfile"
elif [[ "$tool" == "hey" ]]; then
  if [[ "$warmup" -gt 0 ]]; then
    hey -c "$concurrency" -z "${warmup}s" "$url" >/dev/null 2>&1
  fi
  hey -c "$concurrency" -z "${duration}s" "$url" > "$tmpfile"
elif [[ "$tool" == "k6" ]]; then
  echo "k6 is not yet supported by this script" >&2
  exit 1
else
  for idx in $(seq 1 "$concurrency"); do
    (
      if [[ "$warmup" -gt 0 ]]; then
        warmup_end=$((SECONDS + warmup))
        while ((SECONDS < warmup_end)); do
          curl -s -o /dev/null "$url" 2>/dev/null || true
        done
      fi

      end_ts=$((SECONDS + duration))
      count=0
      lat_file="$tmpdir/latency.$idx"
      while ((SECONDS < end_ts)); do
        if elapsed=$(curl -s -o /dev/null -w "%{time_total}" "$url" 2>/dev/null); then
          echo "$elapsed" >> "$lat_file"
          count=$((count + 1))
        fi
      done
      echo "$count" > "$tmpdir/count.$idx"
    ) &
  done
  wait
fi

if [[ "$tool" == "curl" ]]; then
  cat "$tmpdir"/latency.* 2>/dev/null > "$tmpfile" || true
  total=0
  for count_file in "$tmpdir"/count.*; do
    [[ -f "$count_file" ]] || continue
    total=$((total + $(cat "$count_file")))
  done

  "$PYTHON_BIN" - <<PY
import json
import math
import os

duration = int("${duration}")
total = int("${total}")
latencies = []
if os.path.exists("${tmpfile}"):
    with open("${tmpfile}") as fh:
        for line in fh:
            try:
                latencies.append(float(line.strip()))
            except ValueError:
                pass

def percentile(sorted_values, pct):
    if not sorted_values:
        return None
    k = (len(sorted_values) - 1) * (pct / 100.0)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return sorted_values[int(k)]
    d0 = sorted_values[int(f)] * (c - k)
    d1 = sorted_values[int(c)] * (k - f)
    return d0 + d1

latencies.sort()
p50 = percentile(latencies, 50)
p95 = percentile(latencies, 95)
p99 = percentile(latencies, 99)

def fmt_ms(value):
    if value is None:
        return "na"
    return f"{value * 1000:.2f}ms"

result = {
    "tool": "curl",
    "requests_per_sec": round(total / duration, 2) if duration > 0 else 0,
    "p50": fmt_ms(p50),
    "p95": fmt_ms(p95),
    "p99": fmt_ms(p99),
}
print(json.dumps(result))
PY
  exit 0
fi

"$PYTHON_BIN" - <<PY
import json
import os
import re
import sys

tool = "${tool}"
text = open("${tmpfile}").read()

def to_ms(value: str) -> float:
    value = value.strip()
    if value.endswith("ms"):
        return float(value[:-2])
    if value.endswith("s"):
        return float(value[:-1]) * 1000
    if value.endswith("us") or value.endswith("µs"):
        clean = value.replace("µ", "u")
        return float(clean[:-2]) / 1000
    raise ValueError(f"Unknown latency unit: {value}")

def fmt_ms(value: float) -> str:
    return f"{value:.2f}ms"

requests_match = re.search(r"Requests/sec:\s*([0-9.]+)", text)
if not requests_match:
    raise SystemExit("failed to parse requests/sec")
requests_per_sec = float(requests_match.group(1))

latencies = {}
if tool == "wrk":
    for match in re.finditer(r"(?m)^\\s*([0-9]+)%\\s+([0-9.]+(?:us|µs|ms|s))", text):
        latencies[int(match.group(1))] = match.group(2)
    available = {k: to_ms(v) for k, v in latencies.items()}
    p50_ms = available.get(50)
    p90_ms = available.get(90)
    p99_ms = available.get(99)
    if p50_ms is None or p90_ms is None or p99_ms is None:
        raise SystemExit("missing latency distribution data from wrk output")
    if 95 in available:
        p95_ms = available[95]
    else:
        p95_ms = (p90_ms + p99_ms) / 2
elif tool == "hey":
    for match in re.finditer(r"(?m)^\\s*([0-9]+)% in ([0-9.]+) secs", text):
        percent = int(match.group(1))
        value = float(match.group(2)) * 1000
        latencies[percent] = value
    p50_ms = latencies.get(50)
    p95_ms = latencies.get(95)
    p99_ms = latencies.get(99)
    if p50_ms is None or p95_ms is None or p99_ms is None:
        raise SystemExit("missing latency distribution data from hey output")
else:
    raise SystemExit("unsupported tool")

result = {
    "tool": tool,
    "requests_per_sec": round(requests_per_sec, 2),
    "p50": fmt_ms(p50_ms),
    "p95": fmt_ms(p95_ms),
    "p99": fmt_ms(p99_ms),
}
print(json.dumps(result))
PY
