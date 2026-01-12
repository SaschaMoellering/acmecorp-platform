#!/usr/bin/env bash
set -euo pipefail

# usage: bench/collect.sh <branch_dir>
branch_dir="${1:?usage: $0 <branch_dir>}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/infra/local/docker-compose.yml}"

# Python detection (prefer python3)
PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
  PYTHON_BIN="$(command -v python || true)"
fi
if [[ -z "$PYTHON_BIN" ]]; then
  echo "ERROR: python3 (or python) is required" >&2
  exit 1
fi

out="$branch_dir/containers.json"
tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

# Collect container id + compose service + container name for THIS compose project
docker compose -f "$COMPOSE_FILE" ps -q | while read -r cid; do
  [[ -n "$cid" ]] || continue

  svc="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.service" }}' "$cid" 2>/dev/null || true)"
  name="$(docker inspect -f '{{ .Name }}' "$cid" 2>/dev/null | sed 's|^/||' || true)"

  # Fall back
  [[ -n "$svc" ]] || svc="unknown"
  [[ -n "$name" ]] || name="unknown"

  printf "%s|%s|%s\n" "$cid" "$svc" "$name"
done >"$tmp_list"

"$PYTHON_BIN" - <<PY >"$out"
import json
import subprocess

tmp_list = "${tmp_list}"
items = []

def mem_for(cid: str) -> str:
    # "123.4MiB / 1.9GiB" -> take left side
    try:
        out = subprocess.check_output(
            ["docker", "stats", "--no-stream", "--format", "{{.MemUsage}}", cid],
            text=True
        ).strip()
        if not out:
            return "na"
        return out.split("/")[0].strip()
    except Exception:
        return "na"

with open(tmp_list, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        cid, svc, name = line.split("|", 2)
        items.append({
            "service": svc,
            "container": name,
            "id": cid,
            "mem": mem_for(cid),
        })

print(json.dumps(items, indent=2))
PY

echo "$out"
