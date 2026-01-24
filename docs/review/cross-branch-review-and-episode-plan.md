# Cross-Branch Review

## Branch Matrix

| Branch | Purpose (intended) | Key diffs vs `main` | Risk level | Recommended actions |
| --- | --- | --- | --- | --- |
| `main` | Java 21 baseline (per `VERSION_MATRIX.md`) | Spring Boot Dockerfiles default to Java 25, Quarkus uses 21; CI runs JDK 21; fixed sleeps in CI; tracked `dist` symlink | Medium | Align Dockerfiles to Java 21 (or update matrix); replace CI sleeps with health waits; remove tracked `dist` symlink and keep CI shim only. |
| `java11` | Java 11 compatibility branch | Very large logic + API changes across services (error models, DTOs, virtual thread config removed), integration tests rewritten for Java 11, migrations removed, new benchmarking scripts and branch tooling | High | Rebase/fast-forward from `main`, keep *only* Java 11 compatibility deltas (toolchain + Docker `FROM` + JVM flags). Restore removed DB migrations and error contracts. Document any necessary logic changes explicitly in `VERSION_MATRIX.md`. |
| `java17` | Java 17 compatibility branch | Large logic changes similar to `java11`, removal of error/DTO classes and virtual thread config; integration tests reworked; local compose tweaks | High | Same as `java11`: re-align with `main` and keep only Java version deltas. Restore shared API contracts and migrations. |
| `java21` | Java 21 mirror branch for comparisons | Diverges from `main` with logic changes and removed classes; integration tests simplified; compose tweaks | High | Make this a true mirror of `main` (fast-forward only). If there are required deltas, document them in `VERSION_MATRIX.md`. |
| `java25` | Experimental Java 25 branch | Spring Boot 4 upgrade, sealed error models, RestClient config additions, CI changes, Java 25 Dockerfiles, stray `.attach_pid*` files; broad logic changes | Very High | Treat as experimental `feature/java25` branch with explicit scope. Keep app logic identical where possible. Remove stray `.attach_pid*` files and align CI/benching with `main`. |

## Priority Improvements

1. **Align Dockerfile Java defaults with the branch policy.**
   - Why: `main` is documented as Java 21 but Spring Boot Dockerfiles default to Java 25, which undermines reproducibility and cross-branch comparisons.
   - Files: `services/spring-boot/orders-service/Dockerfile:1`, `services/spring-boot/gateway-service/Dockerfile:1`, `services/spring-boot/billing-service/Dockerfile:1`, `services/spring-boot/notification-service/Dockerfile:1`, `services/spring-boot/analytics-service/Dockerfile:1`.
   - Patch approach: set `ARG JAVA_VERSION=21` in `main` (or update `VERSION_MATRIX.md` and CI to reflect 25); ensure branch-specific overrides are explicit via `--build-arg` or branch-specific Dockerfiles.
   - Effort: S.

2. **Replace fixed sleeps in CI with deterministic readiness checks.**
   - Why: `sleep 40`/`sleep 30` causes flaky integration/smoke runs and wastes CI time.
   - Files: `/.github/workflows/ci.yml:111-116`, `/.github/workflows/ci.yml:139-145`, `scripts/wait-for-compose-health.sh:1-157`.
   - Patch approach: call `scripts/wait-for-compose-health.sh` after compose up (and optionally increase timeout via env).
   - Effort: S.

3. **Remove tracked `dist` symlink and keep CI worker shim as a build step.**
   - Why: `dist` points into `node_modules` and is tracked (`dist` in `git ls-files`), which breaks clean checkouts and can confuse tooling.
   - Files: `dist` (tracked symlink), `/.github/workflows/ci.yml:51-63`.
   - Patch approach: delete `dist` from git, add a note in `webapp/README.md` or keep CI shim step only.
   - Effort: S.

4. **Restore and keep Flyway migrations across all Java branches.**
   - Why: migrations are removed in `java11`, `java17`, `java21`, `java25`, which breaks DB portability and makes tests non-comparable.
   - Files: `services/spring-boot/orders-service/src/main/resources/db/migration/V1__create_orders_tables.sql` (missing in branches), `V2__create_order_idempotency.sql`, `V3__add_order_idempotency_fk.sql`.
   - Patch approach: reintroduce migrations in all branches and enforce parity with a CI check.
   - Effort: M.

5. **Re-establish consistent API error/DTO contracts across branches.**
   - Why: error response classes and DTOs are deleted or altered in multiple branches, risking contract drift and flaky UI/integration tests.
   - Files: e.g., `services/spring-boot/gateway-service/src/main/java/com/acmecorp/gateway/api/error/ApiErrorResponse.java`, `services/spring-boot/orders-service/src/main/java/com/acmecorp/orders/api/error/ApiError.java`, `services/quarkus/catalog-service/src/main/java/com/acmecorp/catalog/error/ApiErrorResponse.java` (removed in java* branches).
   - Patch approach: centralize error/DTO types in a shared module or keep per-service copies but enforce parity via diff checks.
   - Effort: M.

6. **Introduce Maven toolchains + Java version enforcement per branch.**
   - Why: CI uses JDK 21 in `main`; Java-specific branches may be compiled with mismatched JDKs, causing subtle breakages.
   - Files: `services/*/pom.xml` (e.g., `services/spring-boot/gateway-service/pom.xml:10-37`), `integration-tests/pom.xml:12-41`.
   - Patch approach: add toolchain config and a `java.version` property per branch to prevent accidental cross-version builds.
   - Effort: M.

7. **Add Maven cache to CI backend job.**
   - Why: repeated `mvn test` per service is slow and increases flake risk due to dependency downloads.
   - Files: `/.github/workflows/ci.yml:15-28`.
   - Patch approach: use `actions/setup-java` cache for Maven or add `actions/cache` for `~/.m2/repository`.
   - Effort: S.

8. **Parallelize backend tests with a job matrix.**
   - Why: one service failure hides failures in others and elongates CI feedback time.
   - Files: `/.github/workflows/ci.yml:8-28`.
   - Patch approach: convert backend job into a matrix over service paths and aggregate results.
   - Effort: M.

9. **Add compose healthchecks for app services or leverage readiness endpoints.**
   - Why: compose only waits on infra services; app services start asynchronously, causing tests to race startup.
   - Files: `infra/local/docker-compose.yml:48-234`.
   - Patch approach: add `healthcheck` for each app service (e.g., `/actuator/health/readiness` and `/q/health/ready`) and use `depends_on: condition: service_healthy` where supported.
   - Effort: M.

10. **Standardize JVM flags in a shared file or env var.**
   - Why: JVM flags are duplicated across multiple Dockerfiles and diverge between Spring Boot and Quarkus.
   - Files: `services/spring-boot/*/Dockerfile:41-50`, `services/quarkus/catalog-service/Dockerfile:18-26`.
   - Patch approach: create a shared `jvm.options` template or pass `JAVA_TOOL_OPTIONS` consistently in compose.
   - Effort: S/M.

11. **Introduce memory limits in docker-compose to make perf results meaningful.**
   - Why: without container limits, JVM uses host memory and results vary across machines.
   - Files: `infra/local/docker-compose.yml:48-234`.
   - Patch approach: set `deploy.resources.limits.memory` for local perf runs (or add a `docker-compose.perf.yml`).
   - Effort: S.

12. **Make integration test seeding more robust with retries.**
   - Why: `seedDemoData()` is called once at startup; if any downstream service is still warming up, tests can fail.
   - Files: `integration-tests/src/test/java/com/acmecorp/integration/AbstractIntegrationTest.java:193-198`.
   - Patch approach: wrap seed call with a small retry/backoff or reuse `Awaitility` pattern used elsewhere.
   - Effort: S.

13. **Avoid ordering assumptions in history assertions.**
   - Why: `orderHistoryTracksStatusChanges()` assumes API returns chronological order; if API ordering changes, test flakes.
   - Files: `integration-tests/src/test/java/com/acmecorp/integration/OrdersCatalogIntegrationTest.java:161-169`.
   - Patch approach: sort by timestamp or assert set membership instead of positional ordering.
   - Effort: S.

14. **Add a CI check enforcing branch parity.**
   - Why: large logic deltas are present in java* branches despite policy.
   - Files: `VERSION_MATRIX.md`, new script in `scripts/`.
   - Patch approach: use `git diff --name-only main..javaXX` and fail if non-allowed paths are modified.
   - Effort: M.

15. **Fix tracked PID attach files in `java25`.**
   - Why: `.attach_pid*` files are transient JVM artifacts and should never be committed.
   - Files: `services/spring-boot/orders-service/.attach_pid2579228`, `services/spring-boot/orders-service/.attach_pid498335` (java25 only).
   - Patch approach: remove files and add `.attach_pid*` to `.gitignore`.
   - Effort: S.

16. **Consolidate health endpoint usage between scripts and tests.**
   - Why: `bench/run-once.sh` uses `/api/gateway/status` while tests use `/api/gateway/system/status`; readiness semantics differ.
   - Files: `bench/run-once.sh:25-45`, `bench/run-matrix.sh:6-20`, `scripts/wait-for-compose-health.sh:26-29`.
   - Patch approach: standardize on `/actuator/health/readiness` + `/api/gateway/system/status` for perf and CI waits.
   - Effort: S.

17. **Centralize service URLs and ports across compose + apps.**
   - Why: `SERVER_PORT` overrides are scattered in compose, while app defaults differ; repeated edits are error-prone.
   - Files: `infra/local/docker-compose.yml:54-225`, `services/spring-boot/*/src/main/resources/application.yml`.
   - Patch approach: move ports into a `.env` used by compose and application configs.
   - Effort: S/M.

18. **Add or document Quarkus metrics endpoints for parity.**
   - Why: Spring services expose Prometheus; Quarkus has micrometer but no explicit doc/config; parity matters for perf demos.
   - Files: `services/quarkus/catalog-service/pom.xml:48-63`, `docs/getting-started.md`.
   - Patch approach: set `quarkus.micrometer.export.prometheus.enabled=true` and document `/q/metrics`.
   - Effort: S.

19. **Harden local compose by reducing unnecessary host exposure.**
   - Why: RabbitMQ management port `15672` is exposed by default; not required for CI.
   - Files: `infra/local/docker-compose.yml:21-35`.
   - Patch approach: move management port under a `profiles: ["debug"]` or document its use.
   - Effort: S.

20. **Extend bench collection to include CPU and latency metrics.**
   - Why: current `bench/collect.sh` only captures memory, missing CPU time and throughput comparisons.
   - Files: `bench/collect.sh:31-62`, `bench/run-matrix.sh`.
   - Patch approach: add `docker stats --no-stream --format` for CPU and integrate loadtest output for latency/throughput.
   - Effort: M.

## CI/Test Stability Issues

- Fixed sleeps in CI (`/.github/workflows/ci.yml:111-116`, `:139-145`) are the primary flake source; use readiness checks.
- Branch parity violations (missing migrations, deleted error models) will cause integration and UI tests to fail differently across `java11`, `java17`, `java21`, `java25`.
- Tracked `dist` symlink (`dist`) will break in clean checkouts and can fail CI on Linux/macOS path semantics.
- App services in compose have no healthchecks; integration/smoke jobs run before services are truly ready.

## Refactoring Opportunities

- **Error/DTO models** duplicated across Spring services and Quarkus: extract into a shared library or enforce parity via tests/scripts.
- **Health-check logic** exists in `scripts/wait-for-compose-health.sh` and integration tests; unify or reuse to avoid divergence.
- **JVM launch flags** duplicated in each Dockerfile; centralize in a shared file or `JAVA_TOOL_OPTIONS`.
- **Benchmarking scripts** diverge across branches; consolidate in `main` and pull to java branches via a sync script.

# Episode Plan: Java Optimizations

## Storyline

1. **Hook / problem statement**: Cold starts and memory are the hidden cost of Java in containers. Show baseline start time and memory for `main` (Java 21) in `infra/local`.
2. **Baseline measurement**: Run `bench/run-once.sh` on baseline and capture: startup time, RSS, and throughput with a short load test.
3. **CRaC demo**: Checkpoint after warmup, restore for near-instant start. Show startup time and memory delta.
4. **AppCDS demo**: Build class data archive once, then run with `-Xshare:on`. Compare startup + memory.
5. **GraalVM Native Image demo**: Build a native binary container and compare cold start + memory vs JVM.
6. **Comparison + trade-offs**: Show a table for startup time, memory, CPU, build time, operational complexity.
7. **Ops considerations**: How each technique fits in container/K8s (ECS/EKS), handling ephemeral storage, permissions, and CI build time.

## Measurement Plan

**Success metrics**
- Cold start time (container start to readiness: `/actuator/health/readiness` + `/api/gateway/system/status`).
- Warm start time (post-warmup restart or CRaC restore time).
- Memory RSS per container (via `docker stats --no-stream`).
- CPU time during steady load (via `docker stats` or cgroup metrics).
- Throughput + p95 latency (via `bench/loadtest` or `wrk`/`k6`).

**How to measure with this repo**
- Use `bench/run-once.sh` as baseline; extend it to:
  - record `startup_time_seconds` from readiness endpoint
  - capture memory + CPU from `docker stats`
  - run a short load test (`bench/loadtest.sh` or `loadtest` if present) for throughput/latency
- Standardize readiness with `/actuator/health/readiness` and `/api/gateway/system/status` to ensure downstream services are up.
- Record results in `bench/results/episode-YYYYMMDD.json` with the same schema across variants.

## Branch Strategy

**Recommendation**: Use dedicated branches per optimization for clarity and reproducible demos, *but keep app code identical* and isolate changes to build/runtime configuration. The existing Java version branches already diverge; for the episode, use a clean baseline branch and three optimization branches based on that baseline.

**Why branches over profiles**
- CRaC/AppCDS/Native Image each require non-trivial Dockerfile and runtime entrypoint changes that are easier to review and demonstrate in dedicated branches.
- Profiles are fine for local experimentation, but branches keep the demo “clean” and verifiable for viewers.

## Implementation Checklist

**Proposed branch names + contents**

- `episode/baseline-java21`
  - No app logic changes.
  - Dockerfiles pinned to Java 21.
  - Scripts to measure baseline in `bench/`.

- `episode/crac-java21`
  - Dockerfile changes to install CRaC JDK (or use a CRaC base image).
  - Add a checkpoint script to warm up, trigger checkpoint, and restore.
  - Runtime flags: `-XX:CRaCCheckpointTo=/checkpoint`.

- `episode/appcds-java21`
  - Dockerfile: stage to generate AppCDS archive (`-Xshare:dump` or `-XX:SharedArchiveFile`).
  - Runtime flags: `-Xshare:on -XX:SharedArchiveFile=/app/appcds.jsa`.

- `episode/native-java21`
  - Dockerfile + build pipeline for GraalVM/Mandrel native image.
  - Add reflection/resource config if needed (Spring AOT or Quarkus native).

**Files to change per branch**
- Dockerfiles (Spring Boot + Quarkus) to adjust build images and runtime flags.
- `infra/local/docker-compose.yml` to mount checkpoint/AppCDS artifacts if needed.
- `bench/` scripts to include startup and memory measurements for the variant.
- `README.md`/`docs/getting-started.md` to document how to run the demo.

**CRaC pitfalls**
- Requires CRaC-enabled JDK; checkpoint/restore flow needs filesystem permissions and a writable volume for `/checkpoint`.
- Some frameworks need explicit “warmup” hooks to avoid invalid state during restore.
- Container runtime constraints: checkpoint/restore may require privileged settings or CRaC-friendly base images.

**AppCDS pitfalls**
- Archive is JVM-version sensitive; must rebuild the archive for each JDK update.
- Ensure classpath consistency between archive generation and runtime.

**Native Image pitfalls**
- Reflection, proxies, SSL, and Netty often need config; Spring AOT/Quarkus native tooling can help.
- Builds are slow and resource-heavy; use CI caching if possible.

**CI implications**
- Native builds and AppCDS archive generation can add minutes to CI; isolate to dedicated workflows.
- CRaC may require special runners or disabled on CI if kernel features are missing.

## Optional: Episode Harness Script

Suggested script (not implemented here): `scripts/episode-java-optimizations.sh`

- Builds/runs baseline + each optimization variant.
- Writes results to `bench/results/episode-YYYYMMDD.json` and a markdown summary.
- Flow:
  1) `git checkout episode/baseline-java21` → run benchmark
  2) `git checkout episode/crac-java21` → run checkpoint/restore benchmark
  3) `git checkout episode/appcds-java21` → run AppCDS benchmark
  4) `git checkout episode/native-java21` → run native benchmark
