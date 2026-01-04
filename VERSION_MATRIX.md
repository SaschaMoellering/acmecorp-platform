# Java Version Matrix

This document defines the branch strategy and allowed deltas while keeping the **business logic identical** across all Java variants. Use the matrix to understand which settings may change per branch and to document any additional justifications.

## Branch matrix

| Branch | Java version | Build image (JDK) | Runtime image (JRE) | JVM flags (baseline) | Notes / allowed caveats |
| --- | --- | --- | --- | --- | --- |
| `main` | 21 (current baseline) | `maven:3.9.9-eclipse-temurin-21` (as in Dockerfiles) | `eclipse-temurin:21-jre` | `-server` (default Spring Boot) | Reference branch; all features validated here |
| `java11` | 11 | `maven:3.9.9-eclipse-temurin-11` | `eclipse-temurin:11-jre` | same baseline, add compatibility flags only if compiler/jvm refuses to start | Allowed changes: Maven compiler release/toolchain, Docker `FROM`, JVM flags. No logic changes unless noted |
| `java17` | 17 | `maven:3.9.9-eclipse-temurin-17` | `eclipse-temurin:17-jre` | baseline | Same change set as java11 (compiler + Docker + CI pins updated) |
| `java21` | 21 | `maven:3.9.9-eclipse-temurin-21` | `eclipse-temurin:21-jre` | baseline | Mirrors `main` but used for explicit comparison runs |
| `java25` | 25 | `maven:3.9.9-eclipse-temurin-25`* | `eclipse-temurin:25-jre`* | baseline | If official Temurin 25 images are unavailable, document alternative in notes. |

\* If the JVM version is not yet published, note the closest compatible image (e.g., `openjdk:25-jdk`).

## Policy

- **Business logic parity**: All branches must keep the same source files, DTOs, API contracts, and configuration values unless a change is explicitly noted in this table.
- **Allowed diffs**: Only update Maven compiler/toolchain settings, Docker build/runtime images, and JVM launch flags to satisfy version compatibility. Any other change requires a justification entry in the matrix notes.
- **Benchmark harness**: When the benchmark scripts exist, they must run identically on every branch except for the JVM they invoke.

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
