# Architecture Principles

AcmeCorp Platform follows these core architecture principles.

1. Cloud Native First

Services are designed for containerized deployment.

Preferred targets:

- Kubernetes
- Amazon EKS
- container runtimes

2. Polyglot Java Frameworks

Two primary frameworks are used:

- Spring Boot
- Quarkus

These allow architectural and performance comparisons.

3. Observability by Default

All services expose:

- Prometheus metrics
- health endpoints
- structured logging

4. Performance Engineering

Performance characteristics must be measurable.

Focus areas:

- startup time
- memory footprint
- warmup behaviour
- JVM tuning

5. Reproducibility

All environments must be reproducible via:

- Docker
- scripts
- infrastructure manifests
