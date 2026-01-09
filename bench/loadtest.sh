#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

url="${1:?usage: $0 <url> [duration_s] [warmup_s] [concurrency] [threads]}"
duration="${2:-120}"
warmup="${3:-60}"
concurrency="${4:-25}"
threads="${5:-4}"

# If set, behave like a strict benchmark tool (fail hard).
STRICT="${LOADTEST_STRICT:-}"

# Prefer python, fall back to python3
PYTHON_BIN="python"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi

emit_json_error() {
  local tool="${1:-unknown}"
  local message="${2:-unknown error}"
  # Always emit valid JSON on stdout
  printf '{"tool":"%s","requests_per_sec":0,"p50":"na","p95":"na","p99":"na","errors":1,"error":"%s"}\n' \
    "$tool" "$(echo "$message" | tr -d '\n' | sed 's/"/\\"/g')"
}

fail_or_json() {
  local tool="${1:-unknown}"
  local msg="${2:-error}"
  if [[ -n "$STRICT" ]]; then
    echo "$msg" >&2
    exit 1
  fi
  emit_json_error "$tool" "$msg"
  exit 0
}

if [[ "$duration" -lt 5 ]]; then
  fail_or_json "unknown" "measurement duration must be at least 5 seconds"
fi

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  fail_or_json "unknown" "python missing (python or python3 required)"
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

run_wrk_or_hey_and_parse() {
  local tool="$1"

  # Run tool and capture output
  if [[ "$tool" == "wrk" ]]; then
    if [[ "$warmup" -gt 0 ]]; then
      wrk -t"$threads" -c"$concurrency" -d"${warmup}s" "$url" >/dev/null 2>&1 || return 1
    fi
    wrk -t"$threads" -c"$concurrency" -d"${duration}s" --latency "$url" > "$tmpfile" 2>/dev/null || return 1
  elif [[ "$tool" == "hey" ]]; then
    if [[ "$warmup" -gt 0 ]]; then
      hey -c "$concurrency" -z "${warmup}s" "$url" >/dev/null 2>&1 || return 1
    fi
    hey -c "$concurrency" -z "${duration}s" "$url" > "$tmpfile" 2>/dev/null || return 1
  else
    return 1
  fi

  # Parse into JSON; if parsing fails, return non-zero so caller can fall back.
  "$PYTHON_BIN" - <<PY
import json
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

m = re.search(r"Requests/sec:\\s*([0-9.]+)", text)
if not m:
    raise SystemExit(2)
rps = float(m.group(1))

if tool == "wrk":
    lat = {}
    for match in re.finditer(r"(?m)^\\s*([0-9]+)%\\s+([0-9.]+(?:us|µs|ms|s))", text):
        lat[int(match.group(1))] = match.group(2)
    available = {k: to_ms(v) for k, v in lat.items()}
    p50 = available.get(50)
    p90 = available.get(90)
    p99 = available.get(99)
    if p50 is None or p90 is None or p99 is None:
        raise SystemExit(3)
    p95 = available.get(95, (p90 + p99) / 2)
elif tool == "hey":
    lat = {}
    for match in re.finditer(r"(?m)^\\s*([0-9]+)% in ([0-9.]+) secs", text):
        pct = int(match.group(1))
        lat[pct] = float(match.group(2)) * 1000
    p50 = lat.get(50)
    p95 = lat.get(95)
    p99 = lat.get(99)
    if p50 is None or p95 is None or p99 is None:
        raise SystemExit(3)
else:
    raise SystemExit(4)

print(json.dumps({
    "tool": tool,
    "requests_per_sec": round(rps, 2),
    "p50": fmt_ms(p50),
    "p95": fmt_ms(p95),
    "p99": fmt_ms(p99),
    "errors": 0
}))
PY
}

run_curl_fallback() {
  # Concurrency via background loops; captures latency and counts.
  for idx in $(seq 1 "$concurrency"); do
    (
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
  errs=0
  for f in "$tmpdir"/count.*; do
    [[ -f "$f" ]] || continue
    total=$((total + $(cat "$f")))
  done
  for f in "$tmpdir"/error.*; do
    [[ -f "$f" ]] || continue
    errs=$((errs + $(cat "$f")))
  done

  "$PYTHON_BIN" - <<PY
import json, math, os

duration = int("${duration}")
total = int("${total}")
errors = int("${errs}")

latencies=[]
if os.path.exists("${tmpfile}"):
    with open("${tmpfile}") as fh:
        for line in fh:
            try:
                latencies.append(float(line.strip()))
            except ValueError:
                pass

def percentile(vals, pct):
    if not vals:
        return None
    vals.sort()
    k = (len(vals) - 1) * (pct / 100.0)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return vals[int(k)]
    d0 = vals[int(f)] * (c - k)
    d1 = vals[int(c)] * (k - f)
    return d0 + d1

p50 = percentile(latencies, 50)
p95 = percentile(latencies, 95)
p99 = percentile(latencies, 99)

def fmt_ms(v):
    return "na" if v is None else f"{v*1000:.2f}ms"

out = {
  "tool": "curl",
  "requests_per_sec": round(total / duration, 2) if duration > 0 else 0,
  "p50": fmt_ms(p50),
  "p95": fmt_ms(p95),
  "p99": fmt_ms(p99),
  "errors": errors,
}
if total == 0:
  out["error"] = "all requests failed"
print(json.dumps(out))
PY
}

case "$tool" in
  wrk|hey)
    if ! run_wrk_or_hey_and_parse "$tool"; then
      echo "WARN: ${tool} failed or could not be parsed; falling back to curl." >&2
      run_curl_fallback
    fi
    ;;
  k6)
    # k6 present but unsupported: fall back instead of failing
    echo "WARN: k6 detected but not supported; falling back to curl." >&2
    run_curl_fallback
    ;;
  curl)
    run_curl_fallback
    ;;
  *)
    fail_or_json "unknown" "no supported tool found"
    ;;
esac