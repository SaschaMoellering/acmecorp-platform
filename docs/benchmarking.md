# Benchmarking

## Purpose

This document is the canonical benchmark methodology reference for the repository.

Use it to understand:
- what the current harness measures
- what a maintained-platform branch comparison does and does not prove
- how to run the standard benchmark commands
- which result artifacts should be cited in documentation and course material

For branch semantics, use [branch-model.md](branch-model.md).

## What The Harness Measures

The benchmark harness under `bench/` measures application and platform behavior for the current repository state. The standard scripts capture:

- startup and readiness timing for the local platform stack
- `orders-service` in-process startup milestones from `/api/orders/startup`
- load-test throughput and latency against the gateway
- container RSS snapshots from Docker stats

The harness output is operationally useful because it measures the platform as it actually runs locally with the repository's current Docker Compose setup.

## Platform-Branch Benchmark Vs Pure JVM Benchmark

Most branch comparisons in this repository are platform-branch benchmarks, not pure JVM benchmarks.

That means a comparison such as `java21` versus `java25` may include differences in:
- Java runtime version
- framework baseline
- packaging and container setup
- runtime flags
- branch-specific code or configuration

Do not describe those results as universal JVM conclusions unless the harness explicitly isolates only the JVM and keeps the rest of the platform fixed.

Interpretation rule:
- `java21` versus `java25` usually means "Java 21 platform branch versus Java 25 platform branch"
- it does not automatically mean "same application on two JVMs with all other variables fixed"

## Java21 Vs Java25 Interpretation Rules

When documenting `java21` versus `java25` results:

- treat the comparison as a maintained-platform branch comparison unless proven otherwise
- do not claim that Java 25 is automatically faster
- do not present Java 25 results as a universal JVM performance win
- describe wins and regressions by metric, not by hype

Acceptable wording:
- "The `java25` branch improved `orders-service main-to-ready` in this platform benchmark."
- "The `java21` branch remained stronger on throughput in this benchmark campaign."

Avoid wording such as:
- "Java 25 is faster than Java 21."
- "The JVM upgrade improved everything."

## Standard Commands

Single current-branch run:

```bash
bash bench/run-once.sh
```

Full maintained-branch matrix:

```bash
bash bench/run-matrix.sh
```

Java 21 versus Java 25 campaign:

```bash
RUNS_PER_BRANCH=5 WARMUP=60 DURATION=120 CONCURRENCY=25 \
bash bench/run-java21-vs-java25.sh
```

Episode 7 median refresh:

```bash
RUNS_PER_BRANCH=5 WARMUP=60 DURATION=120 CONCURRENCY=25 DO_FETCH=0 \
BRANCHES="java11 java17 java21 java25" \
bash bench/run-episode07-refresh.sh
```

Prefer the existing scripts in `bench/` over ad hoc one-off commands.

## Result Artifacts

The standard benchmark outputs to cite are:

- `summary.md`
- `summary.json` when produced
- `load.json`
- `containers.json`
- `orders-startup.json`

These artifacts are the current source material for benchmark interpretation. Older artifact names such as `startup.txt`, `latency.txt`, and `memory.txt` are not the canonical outputs for the current harness.

Typical usage:
- use `summary.md` for human-readable summaries
- use `summary.json` for structured summary data when present
- use `load.json` for throughput and latency details
- use `containers.json` for container RSS snapshots
- use `orders-startup.json` for in-process startup timing

## Default Campaign Guidance

The standard scripts are parameterized, but the repository's documented comparison pattern uses:

- warmup before measurement
- fixed duration per measured run
- repeated runs per branch
- fixed concurrency across compared branches

Recommended campaign shape for branch comparisons:

- `RUNS_PER_BRANCH=5`
- `WARMUP=60`
- `DURATION=120`
- `CONCURRENCY=25`

Reporting guidance:
- prefer medians over single-run anecdotes
- keep warmup and duration identical across compared branches
- keep concurrency identical across compared branches
- do not compare campaigns that used materially different harness settings without stating the difference

## Experiment Branch Interpretation

Optimization branches are separate experiments:

- `cds` = AppCDS experiment
- `crac` = CRaC experiment
- `graalvm` = native-image experiment

Results from those branches prove experiment-specific behavior for those branches. They do not automatically generalize to the maintained platform branches, and they should not be described as cumulative optimization layers unless a dedicated combined experiment exists.

## How Course Material Should Cite Results

Course episodes, teleprompters, and slide diagrams are teaching material. They should cite canonical benchmark artifacts rather than acting as the operational source of truth.

When course material cites benchmark results:

- point back to the benchmark campaign or artifact set when feasible
- describe the run as a platform-branch comparison unless the harness isolated only the JVM
- name the artifact used for the claim
- avoid universal wording such as "Java 25 wins"

Example citation pattern:
- startup claim based on `summary.md` and `orders-startup.json`
- throughput and latency claim based on `load.json`
- memory claim based on `containers.json`

## Related Documents

- [branch-model.md](branch-model.md)
- [optimizations/README.md](optimizations/README.md)
- [../bench/README.md](../bench/README.md)
