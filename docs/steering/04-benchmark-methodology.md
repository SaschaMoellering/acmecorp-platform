# Benchmark Methodology

Startup benchmarks follow strict rules.

Metric

Time until successful HTTP response from:

/actuator/health

Conditions

- cold start
- identical machine
- identical build artifact

Runs

Each benchmark must run at least:

5 runs

Reported metric

Median of runs.

Benchmarks compare:

- Java 11
- Java 17
- Java 21

Optional:

- Java 25

Benchmark scripts live in:

bench/
