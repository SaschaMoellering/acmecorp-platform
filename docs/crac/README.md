# CRaC + Warp Local Harness

This is the canonical guide for running local CRaC benchmark flows on this branch.

## Prerequisites

- Docker + Docker Compose
- Bash
- Python 3 (used for export conversion/summary)
- Build from repo root:
  - `docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml ...`

## Commands

- Single service demo:

```bash
scripts/crac-demo.sh demo orders-service
```

- Matrix mode (default Spring services):

```bash
scripts/crac-demo.sh matrix
```

- Matrix run with export:

```bash
CRAC_EXPORT_DIR=/tmp/crac-results scripts/crac-demo.sh matrix
```

## Environment Variables

- `CRAC_MATRIX_SERVICES` (default: `gateway-service,orders-service,billing-service,notification-service,analytics-service`)
- `CRAC_CHECKPOINT_BASE` (default: `/opt/crac`)
- `BASE_READY_MAX_SECONDS` (default: `180`)
- `CRAC_CHECKPOINT_POLL_MAX_SECONDS` (default: `180`)
- `CRAC_RESTORE_POLL_MAX_SECONDS` (default: `60`)
- `CRAC_POLL_MAX_SECONDS` (legacy fallback for both)
- `CRAC_MATRIX_REPEATS` (default: `1`)
- `BASE_READY_URL` (default: `http://localhost:8080/actuator/health`)
- `CRAC_SMOKE` (default: `0`, set `1` to enable post-restore smoke checks)
- `CRAC_SMOKE_URLS` (optional)
- `SMOKE_PROBE_IMAGE` (default: `curlimages/curl:8.5.0`)
- `CRAC_EXPORT_DIR` (optional; enables export)
- `CRAC_DEBUG` (default: `0`, set `1` for verbose diagnostics)

## Smoke Checks

When `CRAC_SMOKE=1`, smoke checks run via a helper container that joins the restored container network namespace:

- `docker run --rm --network "container:<restore-cid>" ...`

This avoids requiring curl/wget/busybox inside the application image.

- Default smoke path for all services: `/actuator/health`
- `CRAC_SMOKE_URLS` format:
  - Per-service mapping (comma-separated services, semicolon-separated paths):
    - `orders-service=/actuator/health;/actuator/info,billing-service=/actuator/health`
  - Optional global fallback (no `=` token):
    - `/actuator/health;/actuator/info`

If smoke fails, the service row is marked `SMOKE_FAILED` and further restore repeats for that service stop.

If the smoke probe image cannot be pulled/used, set:

```bash
SMOKE_PROBE_IMAGE=<local-or-available-image-with-curl>
```

## Repeats + Stats

`CRAC_MATRIX_REPEATS=N` runs restore `N` times per service after one checkpoint.

- Base startup + checkpoint run once per service.
- Restore stats are computed from numeric restore samples:
  - `min`, `med`, `p95`, `max`, `n`
- Matrix includes:
  - `restore_ready_ms` = median
  - `restore_stats` = full summary

If a restore succeeds but returns non-numeric timing, it is excluded from stats while run still counts as success.

## Measurement Semantics (Startup Timing)

We track three different startup measurements and they are **not** expected to match:

1) **Spring log startup time**  
   The application log line: `Started ... in X seconds`. This is reported by Spring after the application context is fully refreshed. It does **not** include:
   - container networking/port binding timing
   - readiness group checks
   - external probe cadence

2) **health_200_ms (netns probe)**  
   A curl request from a helper container sharing the app container’s network namespace:
   `http://localhost:8080/actuator/health`.  
   This reflects when the health endpoint is actually reachable over HTTP, which can lag the `Started ...` log due to:
   - Netty binding timing
   - actuator readiness group availability
   - polling cadence (bench script uses `POLL_INTERVAL_SECONDS`, default `0.1`)

3) **normal_ready_ms (crac-demo.sh)**  
   This is the `scripts/crac-demo.sh matrix` base readiness metric, measured using the same netns HTTP probe. It is intentionally a fast “ready” signal for CRaC matrix runs and may be lower than full startup time if the endpoint is reachable early.

**Why they differ:** polling cadence, readiness group availability, network/port binding, and any warmup steps can shift these measurements independently.

## Measurement Semantics (Restore Timing)

CRaC restore reports two explicit metrics plus a derived one:

- **restore_jvm_ms**: parsed from the Spring CRaC log marker (`restored JVM running for XX ms`). This reflects JVM + Spring lifecycle restart time.
- **restore_ready_ms**: time-to-HTTP-200 for `/actuator/health` via the netns helper probe. This includes post-restore work and probe cadence/overhead.
- **post_restore_ms**: `restore_ready_ms - restore_jvm_ms` when both are present. This estimates the time between JVM restart completion and readiness.

For more accurate `restore_ready_ms`, use `PROBE_MODE=loop` and set `RESTORE_POLL_INTERVAL_SECONDS=0.05` (or `0.1`). The polling cadence directly affects the reported restore_ready_ms resolution. If `RESTORE_DEBUG_HTTP=1` is set, the restore logs include probe errors (e.g. 503/timeout) to explain post_restore_ms.

> Note: `docker compose up` does **not** rebuild images. Use the rebuild + recreate sequence below when testing startup changes, and set `COMPOSE_BAKE=false` to avoid building unrelated images.

### How to run the benchmark helper

```bash
COMPOSE_BAKE=false scripts/bench-startup-gateway.sh
```

This script rebuilds the gateway image, forces a container recreate, measures health_200_ms via netns curl, extracts the `Started ... in X seconds` line, and prints a single summary line.

Maven entry point (opt-in):

```bash
mvn -pl :gateway-service -Pbench-startup -Dbench.startup=true -DskipTests=true verify
```

Rebuild + recreate manually:

```bash
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml build --no-cache gateway-service
docker compose -f infra/local/docker-compose.yml -f infra/local/docker-compose.crac.yml up -d --no-deps --force-recreate gateway-service
```

Polling variables:

- `scripts/bench-startup-gateway.sh` uses `POLL_INTERVAL_SECONDS` for health probe cadence.
- `scripts/crac-demo.sh` uses `BASE_READY_MAX_SECONDS`, `CRAC_CHECKPOINT_POLL_MAX_SECONDS`, and `CRAC_RESTORE_POLL_MAX_SECONDS` for timeouts.

## Export Outputs

Set `CRAC_EXPORT_DIR` to enable exports.

Example:

```bash
CRAC_EXPORT_DIR=/tmp/crac-results scripts/crac-demo.sh matrix
```

Outputs in `/tmp/crac-results/<timestamp>/`:

- `matrix.md`
- `matrix.csv`
- `summary.md`

Metadata in summary includes timestamp, git branch/commit, engine, repeats, smoke config, services, poll timeouts.

## Warp vs CRIU

- Warp checkpoints are valid when `core.img` exists.
- CRIU-like engines require non-core checkpoint artifacts.
- Warp does **not** require adding `criu` binary in images.

## Troubleshooting

- `CHECKPOINT_EMPTY`: no expected checkpoint artifacts
- `CHECKPOINT_CRASH`: checkpoint container exited non-zero
- `RESTORE_TIMEOUT` / `RESTORE_FAILED`: restore did not become healthy in time or exited early
- `SMOKE_FAILED`: restore booted but functional endpoint checks failed

If stuck, rerun with:

```bash
CRAC_DEBUG=1 scripts/crac-demo.sh matrix
```
