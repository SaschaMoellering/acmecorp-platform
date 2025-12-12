# Benchmark harness (single branch)

This directory contains helper scripts to run a lightweight benchmark for the current branch without touching the Java toolchain.

## Prerequisites

- Docker & Docker Compose (used by `infra/local/docker-compose.yml`)
- `curl` (for health checks)

## Scripts

- `run-once.sh`: builds and starts the local compose stack, waits for gateway health, captures startup time + container RSS memory via `collect.sh`, and writes results into `bench/results/<timestamp>/summary.*`.
- `collect.sh`: helper that gathers memory usage from the gateway, orders, and catalog containers (using `docker stats`) and saves a JSON array to the provided results directory.

## Use

```bash
bash bench/run-once.sh
```

Results will be under `bench/results/<timestamp>/`. Each run produces `summary.json`, `summary.md`, and `containers.json`.
