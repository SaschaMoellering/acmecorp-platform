# Java Version Matrix

This document defines the branch strategy and allowed deltas while keeping the **business logic identical** across all Java variants. Use the matrix to understand which settings may change per branch and to document any additional justifications.

## Branch matrix

| Branch | Java version | Build image (JDK) | Runtime image (JRE) | JVM flags (baseline) | Notes / allowed caveats |
| --- | --- | --- | --- | --- | --- |
| `main` | 21 (current baseline) | `maven:3.9.9-eclipse-temurin-21` (as in Dockerfiles) | `eclipse-temurin:21-jre` | `-server` (default Spring Boot) | Reference branch; all features validated here |
| `java11` | 11 | `maven:3.9.9-eclipse-temurin-11` | `eclipse-temurin:11-jre` | same baseline, add compatibility flags only if compiler/jvm refuses to start | Allowed changes: Maven compiler release/toolchain, Docker `FROM`, JVM flags. No logic changes unless noted |
| `java17` | 17 | `maven:3.9.9-eclipse-temurin-17` | `eclipse-temurin:17-jre` | baseline | Same change set as java11 |
| `java21` | 21 | `maven:3.9.9-eclipse-temurin-21` | `eclipse-temurin:21-jre` | baseline | Mirrors `main` but used for explicit comparison runs |
| `java25` | 25 | `maven:3.9.9-eclipse-temurin-25`* | `eclipse-temurin:25-jre`* | baseline | Spring Boot services may adopt Java 25 language features for demo purposes (records, pattern-matching switch). Quarkus catalog remains on Java 21. |

\* If the JVM version is not yet published, note the closest compatible image (e.g., `openjdk:25-jdk`).

## Policy

- **Business logic parity**: All branches must keep the same source files, DTOs, API contracts, and configuration values unless a change is explicitly noted in this table.
- **Allowed diffs**: Only update Maven compiler/toolchain settings, Docker build/runtime images, and JVM launch flags to satisfy version compatibility. Any other change requires a justification entry in the matrix notes.
- **Benchmark harness**: When the benchmark scripts exist, they must run identically on every branch except for the JVM they invoke.

## Java enforcement

- Each Java service and `integration-tests` enforces the branch Java version via `maven-enforcer-plugin` using the `java.version` property.
- For local builds, either set `JAVA_HOME` to the branch version or use `scripts/run-build-in-jdk.sh <11|17|21|25>` to build in a containerized JDK.
- Tests on `main`/`java21` require JDK 21, and tests on `java25` require JDK 25 (enforced by Maven).

## How to use

```bash
# inspect a version branch
git fetch origin
git checkout java17

# after making configuration-only changes run the benchmark harness (scripts will live under bench/)
bench/run-once.sh

# to run the full matrix once scripts exist
bench/run-matrix.sh
```

Update this file whenever a new Java branch or special override is introduced.

## Java 25 language feature deltas (Spring Boot services only)

These changes are allowed on `java25` to showcase modern Java while keeping behavior stable:

- **Records for DTOs**: Error/response DTOs in Spring Boot services use `record` for immutability and concise models.
- **Pattern matching switch**: Exception mapping and payload normalization use `switch` with type patterns/guards.
- **Guarded list handling**: Payload normalization uses pattern matching for list vs null cases.

Quarkus (`catalog-service`) remains on Java 21 and does not adopt these deltas.
