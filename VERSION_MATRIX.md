# Java Version Matrix

This file is a compatibility summary only.

The canonical branch strategy lives in [docs/branch-model.md](docs/branch-model.md).
Use that document for branch purpose, sync direction, experiment semantics, and benchmark interpretation rules.

This matrix is retained to summarize the Java and image baselines that usually characterize the long-lived branches. It must not be read as a claim that the branches differ only by configuration or that they preserve exact parity in implementation details.

## Branch matrix

| Branch | Java version | Build image (JDK) | Runtime image (JRE) | JVM flags (baseline) | Notes / allowed caveats |
| --- | --- | --- | --- | --- | --- |
| `main` | 21-based integration branch | Java 21-based tooling and docs integration | Java 21-based local and integration assumptions | integration-oriented defaults | Canonical docs and shared tooling; not necessarily identical to `java21` |
| `java11` | 11 | branch-specific Java 11 toolchain | Java 11 runtime baseline | Java 11-compatible baseline | Maintained older baseline; preserve Java 11 compatibility |
| `java17` | 17 | branch-specific Java 17 toolchain | Java 17 runtime baseline | Java 17-compatible baseline | Maintained older baseline; preserve Java 17 compatibility |
| `java21` | 21 | branch-specific Java 21 toolchain | Java 21 runtime baseline | Java 21-compatible baseline | Clean Java 21 baseline for stable comparison |
| `java25` | 25 | branch-specific Java 25 toolchain | Java 25 runtime baseline | Java 25-compatible baseline | Leading newest-generation technical reference; not an automatic performance win |

## Policy

- **No blind parity claims**: The long-lived branches can differ in framework baseline, runtime behavior, build setup, and experiment semantics.
- **No blind merges**: Port fixes deliberately and preserve the target branch baseline.
- **Benchmark interpretation**: Treat `java21` versus `java25` as a platform-branch comparison unless the harness explicitly isolates only the JVM.
- **Experiment branches**: `cds`, `crac`, and `graalvm` are separate experiment branches and should not be treated as cumulative optimization layers by default.

## Java enforcement

- Each Java service and `integration-tests` enforces the branch Java version via `maven-enforcer-plugin` using the `java.version` property.
- For local builds, either set `JAVA_HOME` to the branch version or use `scripts/run-build-in-jdk.sh <11|17|21|25>` to build in a containerized JDK.
- Tests on `main`/`java21` require JDK 21, and tests on `java25` require JDK 25 (enforced by Maven).

## How to use

```bash
# inspect a version branch
git fetch origin
git checkout java17

# run the current-branch benchmark harness
bench/run-once.sh

# run the full matrix
bench/run-matrix.sh
```

If branch purpose, sync direction, or experiment semantics change, update [docs/branch-model.md](docs/branch-model.md) first and keep this file as a supporting summary.
