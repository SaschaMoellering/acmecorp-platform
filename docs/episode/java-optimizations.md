# Java Optimizations Episode: CRaC, AppCDS, Native Image

## Storyline outline (30–45 min)

1. Hook: Java in containers — fast startup vs runtime throughput trade-offs.
2. Baseline: Java 21 container startup + memory for this repo.
3. CRaC demo: checkpoint after warmup, near-instant restore.
4. AppCDS demo: build archive, compare startup + memory.
5. Native Image demo: build native container, compare cold start + RSS.
6. Comparison table: startup, RSS, CPU, throughput, build time, complexity.
7. Ops considerations: permissions, storage, CI time, container orchestration.

## Measurement plan

Metrics:
- Cold start time to readiness (`/actuator/health/readiness` + `/api/gateway/system/status`).
- Warm start time (CRaC restore or post-warmup restart).
- Memory RSS (per-container `docker stats --no-stream`).
- CPU time under load (docker stats or cgroup).
- Throughput + p95 latency (load test, e.g. `loadtest`, `wrk`, or `k6`).

Output:
- Write results to `bench/results/episode-YYYYMMDD.json` and a summary markdown.

## How to run

Baseline (Java 21):
- Use `episode/baseline-java21`.
- `bench/run-once.sh` (or extended harness) captures startup and memory.

CRaC:
- Use `episode/crac-java21`.
- Run checkpoint/restore script and re-measure readiness and RSS.

AppCDS:
- Use `episode/appcds-java21`.
- Generate CDS archive, run with `-Xshare:on`.

Native Image:
- Use `episode/native-java21`.
- Build native image container and measure cold start + RSS.

## Branch policy for the episode

- Keep application code identical to `episode/baseline-java21`.
- Only change Dockerfiles, compose overlays, scripts, and docs.
- Keep measurements consistent across all variants.
