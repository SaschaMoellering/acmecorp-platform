#!/usr/bin/env bash
# scripts/crac-restore-runs.sh
set -euo pipefail

# -------------------------
# Config (env overrides)
# -------------------------
RESTORE_RUNS="${RESTORE_RUNS:-7}"                 # total runs per service (incl. warmup)
WARMUP_RUNS="${WARMUP_RUNS:-1}"                   # discard first N runs from stats (but still logged to CSV)
CRAC_SERVICES="${CRAC_SERVICES:-gateway-service,orders-service,billing-service,notification-service,analytics-service}"

CRAC_CHECKPOINT_BASE="${CRAC_CHECKPOINT_BASE:-/opt/crac}"  # base checkpoint dir inside container
POLL_MAX_SECONDS="${POLL_MAX_SECONDS:-20}"                 # how long to wait for restore markers
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-0.1}"

FORCE_FLAT_CHECKPOINT_DIR="${FORCE_FLAT_CHECKPOINT_DIR:-0}" # 0 => /opt/crac/<svc>, 1 => /opt/crac
COMPOSE_FILES=(
  -f infra/local/docker-compose.yml
  -f infra/local/docker-compose.crac.yml
)

# If you want less compose spam you can try:
# export COMPOSE_STATUS_STDOUT=0
# export COMPOSE_PROGRESS=quiet

# -------------------------
# Helpers
# -------------------------
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing dependency: $1" >&2; exit 1; }; }
need docker
need awk
need sort
need date
need rg

compose() { docker compose "${COMPOSE_FILES[@]}" "$@"; }

split_csv() {
  local s="$1"
  # split on commas into lines
  echo "$s" | tr ',' '\n' | awk 'NF{print $0}'
}

checkpoint_dir_for() {
  local svc="$1"
  if [[ "${FORCE_FLAT_CHECKPOINT_DIR}" == "1" ]]; then
    echo "${CRAC_CHECKPOINT_BASE}"
  else
    echo "${CRAC_CHECKPOINT_BASE}/${svc}"
  fi
}

# Nearest-rank percentile on sorted numbers file (one number per line)
# p in [0..100], returns value at rank ceil(p/100 * n), 1-indexed.
percentile() {
  local p="$1" file="$2"
  awk -v p="$p" '
    { a[NR]=$1 }
    END{
      n=NR
      if(n==0){ exit 1 }
      r = int((p*n + 99)/100)   # ceil(p*n/100)
      if(r<1) r=1
      if(r>n) r=n
      print a[r]
    }' "$file"
}

ms_from_log() {
  local log="$1"
  # Spring marker (your services emit: "restored JVM running for <ms> ms")
  rg -o "restored JVM running for [0-9]+ ms" "$log" | rg -o "[0-9]+" | tail -n1 || true
}

warp_ok_from_log() {
  local log="$1"
  rg -q "warp: Restore successful" "$log"
}

# -------------------------
# Core
# -------------------------
run_restores_for_service() {
  local svc="$1"
  local runs="$2"
  local warmups="$3"

  local ckpt_dir; ckpt_dir="$(checkpoint_dir_for "$svc")"
  local csv="/tmp/crac-restore.${svc}.csv"
  local tmpdir="/tmp/crac-restore.${svc}.$(date +%s)"
  mkdir -p "$tmpdir"

  echo "== ${svc} =="

  # CSV header (overwrite each run)
  cat >"$csv" <<EOF
timestamp,service,run,phase,status,ms,checkpoint_dir,container_id,log_path
EOF

  # warmup-discarded stats file
  local nums_file="$tmpdir/ms_numbers.txt"
  : >"$nums_file"

  local ok=0 fail=0 warp_ok=0 numeric=0 discarded=0

  for i in $(seq 1 "$runs"); do
    local ts; ts="$(date -Iseconds)"
    local cid=""
    local log="$tmpdir/run-${i}.log"
    : >"$log"

    # Run restore detached so we can poll logs deterministically
    echo " Container $(compose run -d -T -e CRAC_MODE=restore -e CRAC_CHECKPOINT_DIR="$ckpt_dir" "$svc") Creating " >/dev/null 2>&1 || true

    # Real cid from last created container:
    # docker compose run -d prints the container id, but compose output can be noisy.
    # So we pick newest container matching "*-${svc}-run-*".
    cid="$(docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.CreatedAt}}' | rg "${svc}-run" | head -n1 | awk '{print $1}' || true)"

    # If we didn’t get a cid, try again with a more deterministic call:
    if [[ -z "$cid" ]]; then
      cid="$(compose run -d -T -e CRAC_MODE=restore -e CRAC_CHECKPOINT_DIR="$ckpt_dir" "$svc" 2>/dev/null || true)"
    fi

    if [[ -z "$cid" ]]; then
      echo "  $i FAIL (no cid)" >&2
      echo "${ts},${svc},${i},restore,FAIL,,${ckpt_dir},,${log}" >>"$csv"
      fail=$((fail+1))
      continue
    fi

    # Poll for marker or warp success
    local max_loops
    max_loops="$(awk -v t="$POLL_MAX_SECONDS" -v s="$POLL_INTERVAL_SECONDS" 'BEGIN{printf("%d", (t/s)+0.5)}')"
    local loops=0
    local ms="" status="FAIL"

    while [[ $loops -lt $max_loops ]]; do
      loops=$((loops+1))

      # capture logs tail progressively
      docker logs "$cid" --tail=400 2>/dev/null >"$log" || true

      ms="$(ms_from_log "$log")"
      if [[ -n "$ms" ]]; then
        status="OK"
        break
      fi

      if warp_ok_from_log "$log"; then
        status="WARP_OK_NO_MS"
        break
      fi

      # early break if container is gone
      docker ps --format '{{.ID}}' | rg -q "^${cid:0:12}" || break

      sleep "$POLL_INTERVAL_SECONDS"
    done

    # Persist CSV row
    if [[ "$status" == "OK" ]]; then
      echo "  $i spring=${ms}"
      echo "${ts},${svc},${i},restore,OK,${ms},${ckpt_dir},${cid},${log}" >>"$csv"
      ok=$((ok+1))

      # warmup discard
      if (( i <= warmups )); then
        discarded=$((discarded+1))
      else
        echo "$ms" >>"$nums_file"
        numeric=$((numeric+1))
      fi

    elif [[ "$status" == "WARP_OK_NO_MS" ]]; then
      echo "  $i warp=OK"
      echo "${ts},${svc},${i},restore,WARP_OK_NO_MS,,${ckpt_dir},${cid},${log}" >>"$csv"
      warp_ok=$((warp_ok+1))
      # no numeric sample
      if (( i <= warmups )); then
        discarded=$((discarded+1))
      fi
    else
      echo "  $i FAIL"
      echo "${ts},${svc},${i},restore,FAIL,,${ckpt_dir},${cid},${log}" >>"$csv"
      fail=$((fail+1))
    fi

    # Cleanup container
    docker rm -f "$cid" >/dev/null 2>&1 || true
  done

  # Stats on numeric samples only (after warmups)
  if [[ -s "$nums_file" ]]; then
    sort -n "$nums_file" >"$tmpdir/ms_sorted.txt"
    local sorted="$tmpdir/ms_sorted.txt"
    local min p50 p90 p95 max
    min="$(head -n1 "$sorted")"
    max="$(tail -n1 "$sorted")"
    p50="$(percentile 50 "$sorted")"
    p90="$(percentile 90 "$sorted")"
    p95="$(percentile 95 "$sorted")"

    echo "  min=${min}"
    echo "  p50=${p50}"
    echo "  p90=${p90}"
    echo "  p95=${p95}"
    echo "  max=${max}"
  else
    echo "  (no numeric ms samples after warmup; check CSV/logs)"
  fi

  echo "  (runs=${runs}, warmup_discarded=${warmups}, numeric_used=${numeric}, ok=${ok}, warp_ok_no_ms=${warp_ok}, fail=${fail})"
  echo "  CSV: ${csv}"
  echo
}

# -------------------------
# Main
# -------------------------
echo "RESTORE_RUNS=${RESTORE_RUNS}"
echo "WARMUP_RUNS=${WARMUP_RUNS}"
echo "CRAC_SERVICES=${CRAC_SERVICES}"
echo "CRAC_CHECKPOINT_BASE=${CRAC_CHECKPOINT_BASE}"
echo "POLL_MAX_SECONDS=${POLL_MAX_SECONDS}"
echo "FORCE_FLAT_CHECKPOINT_DIR=${FORCE_FLAT_CHECKPOINT_DIR}"
echo

# Ensure dependencies are up
compose up -d postgres redis rabbitmq >/dev/null 2>&1 || true

while IFS= read -r svc; do
  run_restores_for_service "$svc" "$RESTORE_RUNS" "$WARMUP_RUNS"
done < <(split_csv "$CRAC_SERVICES")