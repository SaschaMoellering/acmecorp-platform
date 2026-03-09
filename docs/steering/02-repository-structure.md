# Repository Structure

The repository follows a predictable layout.

services/
    spring/
    quarkus/

bench/
    startup benchmarks
    performance scripts

infra/
    docker compose
    kubernetes manifests

docs/
    architecture
    steering documents
    course material

Important rule:

Benchmark scripts must always live inside:

bench/
