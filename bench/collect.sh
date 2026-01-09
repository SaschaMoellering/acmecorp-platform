#!/usr/bin/env bash
set -euo pipefail

# Resolve python executable early (set -u safe)
PYTHON_BIN="${PYTHON_BIN:-python}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "required command 'python' (or 'python3') is missing" >&2
  exit 1
fi
export PYTHON_BIN

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/local/docker-compose.yml"

RESULT_DIR="${1:?}"
if [[ ! -d "$RESULT_DIR" ]]; then
  mkdir -p "$RESULT_DIR"
fi

MEMORY_SAMPLES="$RESULT_DIR/memory_samples.json"
CONTAINERS_FILE="$RESULT_DIR/containers.json"
SUMMARY_FILE="$RESULT_DIR/summary.json"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "compose file missing: $COMPOSE_FILE" >&2
  exit 1
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

services=("gateway-service" "orders-service" "catalog-service")

prev_sample=0
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

for sample in 0 30 60; do
  if [[ $sample -gt 0 ]]; then
    sleep $((sample - prev_sample))
  fi
  prev_sample=$sample
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  for svc in "${services[@]}"; do
    ids=$("${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps -q "$svc")
    for id in $ids; do
      [[ -z "$id" ]] && continue
      stats=$(docker stats --no-stream --no-trunc --format '{{.Name}}|{{.MemUsage}}' "$id")
      name="${stats%%|*}"
      mem_usage_full="${stats#*|}"
      mem="${mem_usage_full%% / *}"
      printf '%s|%s|%s|%s|%s\n' "$sample" "$timestamp" "$svc" "$name" "$mem" >> "$tmpfile"
    done
  done
done

"$PYTHON_BIN" - <<PY
import json
import math
import os
import statistics
import re

tmpfile = "${tmpfile}"
memory_samples_path = "${MEMORY_SAMPLES}"
containers_path = "${CONTAINERS_FILE}"
summary_path = "${SUMMARY_FILE}"

def parse_mem(value):
    value = value.strip()
    m = re.match(r"(?P<num>[0-9.]+)(?P<unit>[KMGT]iB)?", value)
    if not m:
        return None
    num = float(m.group("num"))
    unit = m.group("unit") or "B"
    factors = {"KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4}
    return num * factors.get(unit, 1)

data = []
with open(tmpfile) as fh:
    for line in fh:
        sample, timestamp, service, container, mem = line.strip().split("|")
        mem_value = mem.split("/")[0].strip()
        mem_bytes = parse_mem(mem_value)
        if mem_bytes is None:
            continue
        data.append({
            "sample": int(sample),
            "timestamp": timestamp,
            "service": service,
            "container": container,
            "mem_readable": mem_value,
            "mem_bytes": mem_bytes
        })

samples = []
for entry in data:
    samples.append({
        "sample": entry["sample"],
        "timestamp": entry["timestamp"],
        "service": entry["service"],
        "container": entry["container"],
        "mem_readable": entry["mem_readable"],
        "mem_bytes": entry["mem_bytes"]
    })

with open(memory_samples_path, "w") as out:
    json.dump(samples, out, indent=2)

services = {}
for entry in samples:
    services.setdefault(entry["service"], []).append(entry["mem_bytes"])

median_map = {}
for service, values in services.items():
    median_bytes = statistics.median(values)
    median_map[service] = {
        "median_bytes": median_bytes,
        "median_readable": f"{median_bytes / (1024**2):.2f}MiB"
    }

max_sample = max(entry["sample"] for entry in samples) if samples else 0
containers = [entry for entry in samples if entry["sample"] == max_sample]

with open(containers_path, "w") as f:
    json.dump([{
        "service": entry["service"],
        "container": entry["container"],
        "mem": entry["mem_readable"]
    } for entry in containers], f, indent=2)

summary = {
    "median": median_map,
    "samples": os.path.basename(memory_samples_path)
}

with open(summary_path, "w") as f:
    json.dump(summary, f, indent=2)

print(containers_path)
PY
