# Cross-Branch Review

## Branch Matrix

| Branch | Purpose (intended) | Key diffs vs `main` | Risk level | Recommended actions |
| --- | --- | --- | --- | --- |
| `main` | Java 21 baseline (per `VERSION_MATRIX.md`) | Spring Boot Dockerfiles default to Java 25, Quarkus uses 21; CI runs JDK 21; fixed sleeps in CI; tracked `dist` symlink | Medium | Align Dockerfiles to Java 21 (or update matrix); replace CI sleeps with health waits; remove tracked `dist` symlink and keep CI shim only. |
| `java11` | Java 11 compatibility branch | Very large logic + API changes across services (error models, DTOs, virtual thread config removed), integration tests rewritten for Java 11, migrations removed, new benchmarking scripts and branch tooling | High | Rebase/fast-forward from `main`, keep only Java 11 compatibility deltas (toolchain + Docker `FROM` + JVM flags). Restore removed DB migrations and error contracts. Document any necessary logic changes explicitly in `VERSION_MATRIX.md`. |
| `java17` | Java 17 compatibility branch | Large logic changes similar to `java11`, removal of error/DTO classes and virtual thread config; integration tests reworked; local compose tweaks | High | Same as `java11`: re-align with `main` and keep only Java version deltas. Restore shared API contracts and migrations. |
| `java21` | Java 21 mirror branch for comparisons | Diverges from `main` with logic changes and removed classes; integration tests simplified; compose tweaks | High | Make this a true mirror of `main` (fast-forward only). If there are required deltas, document them in `VERSION_MATRIX.md`. |
| `java25` | Experimental Java 25 branch | Spring Boot 4 upgrade, sealed error models, RestClient config additions, CI changes, Java 25 Dockerfiles, stray `.attach_pid*` files; broad logic changes | Very High | Treat as experimental `feature/java25` branch with explicit scope. Keep app logic identical where possible. Remove stray `.attach_pid*` files and align CI/benching with `main`. |

## Priority Improvements

1. Align Dockerfile Java defaults with the branch policy.
2. Replace fixed sleeps in CI with deterministic readiness checks.
3. Remove tracked `dist` symlink and keep CI worker shim as a build step.
4. Restore and keep Flyway migrations across all Java branches.
5. Re-establish consistent API error/DTO contracts across branches.
6. Introduce Maven toolchains + Java version enforcement per branch.
7. Add Maven cache to CI backend job.
8. Parallelize backend tests with a job matrix.
9. Add compose healthchecks for app services or leverage readiness endpoints.
10. Standardize JVM flags in a shared file or env var.
11. Introduce memory limits in docker-compose to make perf results meaningful.
12. Make integration test seeding more robust with retries.
13. Avoid ordering assumptions in history assertions.
14. Add a CI check enforcing branch parity.
15. Fix tracked PID attach files in `java25`.
16. Consolidate health endpoint usage between scripts and tests.
17. Centralize service URLs and ports across compose + apps.
18. Add or document Quarkus metrics endpoints for parity.
19. Harden local compose by reducing unnecessary host exposure.
20. Extend bench collection to include CPU and latency metrics.

## CI/Test Stability Issues

- Fixed sleeps in CI are the primary flake source; use readiness checks.
- Branch parity violations will cause integration and UI tests to fail differently across branches.
- Tracked `dist` symlink will break in clean checkouts and can fail CI on Linux/macOS path semantics.
- App services in compose have no healthchecks; integration/smoke jobs run before services are truly ready.

## Refactoring Opportunities

- Error/DTO models duplicated across Spring services and Quarkus.
- Health-check logic duplicated in scripts and integration tests.
- JVM launch flags duplicated in each Dockerfile.
- Benchmarking scripts diverge across branches.

# Episode Plan: Java Optimizations

## Storyline

1. Hook / problem statement: Cold starts and memory are the hidden cost of Java in containers.
2. Baseline measurement: capture startup time, RSS, and throughput on Java 21.
3. CRaC demo: checkpoint after warmup, then restore for near-instant start.
4. AppCDS demo: build a class data archive and compare startup + memory.
5. GraalVM Native Image demo: compare cold start + memory vs JVM.
6. Comparison + trade-offs: startup time, memory, CPU, build time, operational complexity.
7. Ops considerations: fit for containers/K8s, storage, permissions, and CI build time.

## Measurement Plan

- Cold start time: `/actuator/health/readiness` + `/api/gateway/system/status`.
- Warm start time: post-warmup restart or CRaC restore time.
- Memory RSS: `docker stats --no-stream`.
- CPU time: `docker stats` or cgroup metrics.
- Throughput + p95 latency: `bench/loadtest.sh` or similar.

## Branch Strategy

- Use a clean baseline branch plus dedicated optimization branches.
- Keep application code identical and isolate changes to build/runtime configuration.

## Implementation Checklist

- `episode/baseline-java21`: no app logic changes, Java 21 baseline.
- `episode/crac-java21`: CRaC-enabled Docker/runtime changes only.
- `episode/appcds-java21`: AppCDS archive generation and runtime flags only.
- `episode/native-java21`: native-image build/runtime changes only.
