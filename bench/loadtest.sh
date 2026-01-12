#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

url="${1:?usage: $0 <url> [duration_s] [warmup_s] [concurrency] [threads]}"
duration="${2:-120}"
warmup="${3:-60}"
concurrency="${4:-25}"
threads="${5:-4}"

if [[ "$duration" -lt 5 ]]; then
  echo "measurement duration must be at least 5 seconds" >&2
  exit 1
fi

# Python detection (prefer python3)
PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
  PYTHON_BIN="$(command -v python || true)"
fi
if [[ -z "$PYTHON_BIN" ]]; then
  echo "Install python3 (or python) before running loadtest" >&2
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
  echo "Install wrk, hey, or k6 before running loadtest" >&2
  exit 1
fi

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

echo "Running ${tool} load test against ${url} (warmup=${warmup}s, duration=${duration}s, concurrency=${concurrency})..." >&2

run_ok=1
run_err=""

if [[ "$tool" == "wrk" ]]; then
  # Warmup (do not fail the whole script if warmup fails)
  if [[ "$warmup" -gt 0 ]]; then
    set +e
    wrk -t"$threads" -c"$concurrency" -d"${warmup}s" "$url" >/dev/null 2>&1
    warmup_rc=$?
    set -e
    if [[ $warmup_rc -ne 0 ]]; then
      echo "WARN: wrk warmup failed (exit=$warmup_rc) - continuing to measurement" >&2
    fi
  fi

  # Measurement (capture output; if it fails, still parse what we got)
  set +e
  wrk -t"$threads" -c"$concurrency" -d"${duration}s" --latency "$url" >"$tmpfile" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    run_ok=0
    run_err="wrk failed (exit=${rc})"
  fi

elif [[ "$tool" == "hey" ]]; then
  if [[ "$warmup" -gt 0 ]]; then
    set +e
    hey -c "$concurrency" -z "${warmup}s" "$url" >/dev/null 2>&1
    warmup_rc=$?
    set -e
    if [[ $warmup_rc -ne 0 ]]; then
      echo "WARN: hey warmup failed (exit=$warmup_rc) - continuing to measurement" >&2
    fi
  fi

  set +e
  hey -c "$concurrency" -z "${duration}s" "$url" >"$tmpfile" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    run_ok=0
    run_err="hey failed (exit=${rc})"
  fi

else
  echo "k6 is not yet supported by this script" >&2
  exit 1
fi

# Always emit JSON to stdout (ok=true/false). Never rely on exit codes.
set +e
"$PYTHON_BIN" - <<PY
import json
import re

tool = "${tool}"
url = "${url}"
duration = int("${duration}")
warmup = int("${warmup}")
concurrency = int("${concurrency}")
threads = int("${threads}")
run_ok = int("${run_ok}")
run_err = "${run_err}"

with open("${tmpfile}", "r", encoding="utf-8", errors="replace") as f:
    text = f.read()

def to_ms(value: str) -> float:
    value = value.strip()
    if value.endswith("ms"):
        return float(value[:-2])
    if value.endswith("s"):
        return float(value[:-1]) * 1000.0
    if value.endswith("us") or value.endswith("µs"):
        clean = value.replace("µ", "u")
        return float(clean[:-2]) / 1000.0
    raise ValueError(f"Unknown latency unit: {value}")

def fmt_ms(value):
    if value is None:
        return "na"
    return f"{value:.2f}ms"

def excerpt(s: str, max_len: int = 2000) -> str:
    s = s.strip()
    if len(s) <= max_len:
        return s
    return s[:max_len] + " …(truncated)…"

result = {
    "ok": True,
    "tool": tool,
    "url": url,
    "duration_s": duration,
    "warmup_s": warmup,
    "concurrency": concurrency,
    "threads": threads,
    "requests_per_sec": "na",
    "p50": "na",
    "p95": "na",
    "p99": "na",
    "http_non2xx": "na",
    "socket_errors": {},
}

# If the runner already failed, keep ok=false but still try to parse what exists.
if run_ok == 0:
    result["ok"] = False
    result["error"] = run_err

# Parse Requests/sec
m = re.search(r"Requests/sec:\s*([0-9]+(?:\.[0-9]+)?)", text)
if m:
    try:
        result["requests_per_sec"] = round(float(m.group(1)), 2)
    except Exception:
        result["requests_per_sec"] = "na"

# Parse non-2xx count (wrk)
m = re.search(r"Non-2xx or 3xx responses:\s*([0-9]+)", text)
if m:
    result["http_non2xx"] = int(m.group(1))

# Parse socket errors (wrk)
m = re.search(r"Socket errors:\s*connect\s*([0-9]+),\s*read\s*([0-9]+),\s*write\s*([0-9]+),\s*timeout\s*([0-9]+)", text)
if m:
    result["socket_errors"] = {
        "connect": int(m.group(1)),
        "read": int(m.group(2)),
        "write": int(m.group(3)),
        "timeout": int(m.group(4)),
    }

# Percentiles
try:
    if tool == "wrk":
        lat = {}
        for mm in re.finditer(r"(?m)^\s*([0-9]+)%\s+([0-9.]+(?:us|µs|ms|s))", text):
            lat[int(mm.group(1))] = mm.group(2)
        available = {k: to_ms(v) for k, v in lat.items()}
        p50 = available.get(50)
        p90 = available.get(90)
        p95 = available.get(95)
        p99 = available.get(99)

        # If not present, approximate p95 from p90/p99 if available
        if p95 is None and p90 is not None and p99 is not None:
            p95 = (p90 + p99) / 2.0

        result["p50"] = fmt_ms(p50)
        result["p95"] = fmt_ms(p95)
        result["p99"] = fmt_ms(p99)

        # If core metrics missing, mark ok=false but keep JSON
        if result["requests_per_sec"] == "na" or result["p50"] == "na" or result["p99"] == "na":
            result["ok"] = False
            result.setdefault("error", "failed to parse required metrics from wrk output")

    elif tool == "hey":
        lat = {}
        for mm in re.finditer(r"(?m)^\s*([0-9]+)% in ([0-9.]+) secs", text):
            lat[int(mm.group(1))] = float(mm.group(2)) * 1000.0

        result["p50"] = fmt_ms(lat.get(50))
        result["p95"] = fmt_ms(lat.get(95))
        result["p99"] = fmt_ms(lat.get(99))

        if result["requests_per_sec"] == "na" or result["p50"] == "na" or result["p99"] == "na":
            result["ok"] = False
            result.setdefault("error", "failed to parse required metrics from hey output")
    else:
        result["ok"] = False
        result["error"] = "unsupported tool"
except Exception as e:
    result["ok"] = False
    result["error"] = f"parser exception: {e.__class__.__name__}: {e}"

result["raw_excerpt"] = excerpt(text, 2000)

print(json.dumps(result))
PY
py_rc=$?
set -e

# If python parsing failed completely, emit minimal JSON (never empty).
if [[ $py_rc -ne 0 ]]; then
  echo "{\"ok\":false,\"tool\":\"$tool\",\"url\":\"$url\",\"error\":\"python parser failed (exit=$py_rc)\"}"
fi

# IMPORTANT: never fail via exit code; caller decides based on JSON.
exit 0