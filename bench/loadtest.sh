#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

url="${1:?usage: $0 <url> [duration_s] [warmup_s] [concurrency] [threads]}"
duration="${2:-120}"
warmup="${3:-60}"
concurrency="${4:-25}"
threads="${5:-4}"

# Prefer python, fall back to python3
PYTHON_BIN="python"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi

emit_error_json() {
  local tool="${1:-unknown}"
  local message="${2:-unknown error}"
  # Always emit valid JSON on stdout
  printf '{"tool":"%s","requests_per_sec":0,"p50":"na","p95":"na","p99":"na","errors":1,"error":"%s"}\n' \
    "$tool" "$(echo "$message" | tr -d '\n' | sed 's/"/\\"/g')"
}

if [[ "$duration" -lt 5 ]]; then
  emit_error_json "unknown" "measurement duration must be at least 5 seconds"
  exit 0
fi

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  emit_error_json "unknown" "python missing (python or python3 required)"
  exit 0
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
    if ! wrk -t"$threads" -c"$concurrency" -d"${warmup}s" "$url" >/dev/null 2>&1; then
      emit_error_json "wrk" "warmup failed"
      exit 0
    fi
  fi
  if ! wrk -t"$threads" -c"$concurrency" -d"${duration}s" --latency "$url" > "$tmpfile" 2>/dev/null; then
    emit_error_json "wrk" "load test failed"
    exit 0
  fi

  "$PYTHON_BIN" - <<PY
import json
import math
import re
import sys

tool = "wrk"
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

def fail(msg: str):
    print(json.dumps({
        "tool": tool,
        "requests_per_sec": 0,
        "p50": "na",
        "p95": "na",
        "p99": "na",
        "errors": 1,
        "error": msg,
    }))
    sys.exit(0)

requests_match = re.search(r"Requests/sec:\\s*([0-9.]+)", text)
if not requests_match:
    fail("failed to parse requests/sec")
requests_per_sec = float(requests_match.group(1))

latencies = {}
for match in re.finditer(r"(?m)^\\s*([0-9]+)%\\s+([0-9.]+(?:us|µs|ms|s))", text):
    latencies[int(match.group(1))] = match.group(2)

available = {k: to_ms(v) for k, v in latencies.items()}
p50_ms = available.get(50)
p90_ms = available.get(90)
p99_ms = available.get(99)

if p50_ms is None or p90_ms is None or p99_ms is None:
    fail("missing latency distribution data from wrk output")

p95_ms = available.get(95, (p90_ms + p99_ms) / 2)

print(json.dumps({
    "tool": tool,
    "requests_per_sec": round(requests_per_sec, 2),
    "p50": fmt_ms(p50_ms),
    "p95": fmt_ms(p95_ms),
    "p99": fmt_ms(p99_ms),
    "errors": 0
}))
PY
  exit 0
fi

if [[ "$tool" == "hey" ]]; then
  if [[ "$warmup" -gt 0 ]]; then
    if ! hey -c "$concurrency" -z "${warmup}s" "$url" >/dev/null 2>&1; then
      emit_error_json "hey" "warmup failed"
      exit 0
    fi
  fi
  if ! hey -c "$concurrency" -z "${duration}s" "$url" > "$tmpfile" 2>/dev/null; then
    emit_error_json "hey" "load test failed"
    exit 0
  fi

  "$PYTHON_BIN" - <<PY
import json
import re
import sys

tool = "hey"
text = open("${tmpfile}").read()

def fmt_ms(value: float) -> str:
    return f"{value:.2f}ms"

def fail(msg: str):
    print(json.dumps({
        "tool": tool,
        "requests_per_sec": 0,
        "p50": "na",
        "p95": "na",
        "p99": "na",
        "errors": 1,
        "error": msg,
    }))
    sys.exit(0)

requests_match = re.search(r"Requests/sec:\\s*([0-9.]+)", text)
if not requests_match:
    fail("failed to parse requests/sec")
requests_per_sec = float(requests_match.group(1))

latencies = {}
for match in re.finditer(r"(?m)^\\s*([0-9]+)% in ([0-9.]+) secs", text):
    percent = int(match.group(1))
    value_ms = float(match.group(2)) * 1000
    latencies[percent] = value_ms

p50_ms = latencies.get(50)
p95_ms = latencies.get(95)
p99_ms = latencies.get(99)
if p50_ms is None or p95_ms is None or p99_ms is None:
    fail("missing latency distribution data from hey output")

print(json.dumps({
    "tool": tool,
    "requests_per_sec": round(requests_per_sec, 2),
    "p50": fmt_ms(p50_ms),
    "p95": fmt_ms(p95_ms),
    "p99": fmt_ms(p99_ms),
    "errors": 0
}))
PY
  exit 0
fi

if [[ "$tool" == "k6" ]]; then
  emit_error_json "k6" "k6 not supported by this script (use wrk/hey or curl fallback)"
  exit 0
fi

# --------------------
# curl fallback: concurrency via background loops; captures latency and counts.
# --------------------
for idx in $(seq 1 "$concurrency"); do
  (
    # Warmup loop (best-effort)
    if [[ "$warmup" -gt 0 ]]; then
      warmup_end=$((SECONDS + warmup))
      while ((SECONDS < warmup_end)); do
        curl -s -o /dev/null "$url" >/dev/null 2>&1 || true
      done
    fi

    end_ts=$((SECONDS + duration))
    count=0
    errors=0
    lat_file="$tmpdir/latency.$idx"

    while ((SECONDS < end_ts)); do
      # curl prints time_total on stdout; suppress body
      if elapsed=$(curl -s -o /dev/null -w "%{time_total}" "$url" 2>/dev/null); then
        echo "$elapsed" >> "$lat_file"
        count=$((count + 1))
      else
        errors=$((errors + 1))
      fi
    done

    echo "$count" > "$tmpdir/count.$idx"
    echo "$errors" > "$tmpdir/error.$idx"
  ) &
done
wait

cat "$tmpdir"/latency.* 2>/dev/null > "$tmpfile" || true

total=0
errors=0
for count_file in "$tmpdir"/count.*; do
  [[ -f "$count_file" ]] || continue
  total=$((total + $(cat "$count_file")))
done
for error_file in "$tmpdir"/error.*; do
  [[ -f "$error_file" ]] || continue
  errors=$((errors + $(cat "$error_file")))
done

"$PYTHON_BIN" - <<PY
import json
import math
import os

duration = int("${duration}")
total = int("${total}")
errors = int("${errors}")

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
    "errors": errors,
}
if total == 0:
    result["error"] = "all requests failed"
print(json.dumps(result))
PY
exit 0