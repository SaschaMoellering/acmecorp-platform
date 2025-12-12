# Benchmark harness (single branch)

This directory contains helper scripts to run a lightweight benchmark for the current branch without touching the Java toolchain.

## Prerequisites

- Docker & Docker Compose (used by `infra/local/docker-compose.yml`)
- `curl` (for health checks)

## Scripts

- `run-once.sh`: builds and starts the local compose stack, waits for gateway health, captures startup time + container RSS memory via `collect.sh`, and writes results into `bench/results/<timestamp>/summary.*`.
- `collect.sh`: helper that gathers memory usage from the gateway, orders, and catalog containers (using `docker stats`) and saves a JSON array to the provided results directory.
- `loadtest.sh`: executes a warmup + measurement load run against the gateway using the first available tool (prefer `wrk`, fall back to `hey`). It outputs JSON with requests/sec and latency percentiles.
- `run-matrix.sh`: iterates the Java variant branches, packages the code, runs the compose stack, invokes `loadtest.sh`, collects metrics, and emits per-branch + matrix summaries (see section below).

## Use

```bash
bash bench/run-once.sh
```

Results will be under `bench/results/<timestamp>/`. Each run produces `summary.json`, `summary.md`, and `containers.json`.

```bash
bash bench/run-matrix.sh
```

Runs through the Java branches (`java11`, `java17`, `java21`, `main`, `java25`), capturing startup time, RSS, latency p50/p95/p99, and throughput. Matrix-wide results appear under `bench/results/<timestamp>/matrix-summary.md`.
