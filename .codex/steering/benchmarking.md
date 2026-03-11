# Benchmarking Steering

The AcmeCorp Platform includes benchmark-based comparisons across runtime
versions, frameworks, and optimization techniques.

## Benchmarking Principles

1. Reproducibility over anecdotal numbers
2. Comparability over isolated wins
3. Documented methodology over informal measurement
4. Repeated runs over single-run claims

## Agents must protect

- benchmark scripts
- JVM flags used for measurement
- container resource settings
- startup measurement methodology
- baseline comparability across branches

## Any change that affects measured performance must answer

- what changed
- why it changed
- whether old results remain comparable
- whether benchmarks must be rerun
