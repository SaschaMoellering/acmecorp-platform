# Course Blueprint — AcmeCorp Platform

> **Consolidated & Restored Blueprint**  
> This document is the *single source of truth* for the course narrative.  
> It restores the detailed narrative content from earlier iterations **and** keeps the normalized episode order, visuals, and hands‑on model.

---

# Episode 0 — Course Overview & Goals

## Duration
~7–8 minutes

## Purpose of this Episode
Set expectations for the course. Explain what the AcmeCorp Platform is, why it exists, and how this course differs from typical cloud or Java tutorials.

This episode helps viewers decide whether this course is right for them — before we dive into architecture or code.

## Target Audience
- Senior Java developers
- Software architects
- Platform, cloud, and infrastructure engineers
- Engineers who already know frameworks, but want to understand *trade-offs and real-world behavior*

## High-Level Narrative

This course exists because modern systems fail less often due to missing features — and more often due to **misunderstood trade-offs**.

We focus on real systems, real constraints, and real runtime behavior. This is not a framework tutorial, but a guided exploration of how architecture, performance, observability, and infrastructure interact in production.

## What Is Shown
- Slides only (no code)
- Course structure, learning goals, and expectations

---

# Episode 1 — AcmeCorp Platform Overview & Architecture

## Duration
~10 minutes

## Purpose of this Episode
Introduce the AcmeCorp Platform as a reference system and establish a shared mental model of its architecture, domain, and goals.

## High-Level Narrative

Most example platforms are either too trivial to teach real lessons, or so complex that they obscure fundamentals. AcmeCorp is intentionally positioned in between: the business domain is boring by design, so we can focus on architecture, performance, and operations.

Microservices are used here not because they are fashionable, but because they allow us to reason about startup behavior, dependency management, observability, and deployment trade-offs.

## Architecture & Visuals
- High-level system architecture
- Service boundaries and request flow

## What Is Shown
- Architecture diagrams
- Repository and service layout walkthrough

---

# Episode 2 — Local Development & Docker Compose

## Duration
~10 minutes

## Purpose of this Episode
Explain how developers work with the AcmeCorp Platform locally and why **local development and CI are equal architectural constraints**.

## High-Level Narrative

If a system does not behave predictably on a developer laptop, it will not behave predictably in CI or production. Local reproducibility is not a convenience feature — it is a design requirement.

Docker Compose is used here not just to start containers, but as an architectural mirror: service boundaries, dependencies, and startup ordering become immediately visible.

## Architecture & Visuals
- **E02-D01-compose-architecture** — Docker Compose stack and dependencies
- **E02-D02-local-request-flow** — Request flow through the Gateway
- **E02-D03-startup-health-signals** — Startup order, health, readiness

## What Is Shown (Live / Hands-on)
- `docker compose up` walkthrough
- Health and readiness endpoints
- Code walkthrough of compose files and health checks
- Optional controlled failure to show cascading effects

## What Is Intentionally Deferred
- Kubernetes deployment
- Cloud infrastructure
- Performance tuning

---

# Episode 3 — API Design, Gateway & Service Boundaries

## Duration
~10 minutes

## Purpose of this Episode
Explain how APIs are exposed, why the Gateway exists, and how service boundaries protect the system from cascading failures.

## High-Level Narrative

Distributed systems rarely fail because of business logic. They fail at their boundaries: unclear responsibilities, leaky abstractions, and uncontrolled coupling.

The Gateway in AcmeCorp is both a technical and organizational boundary. It limits blast radius, centralizes cross-cutting concerns, and enables controlled API evolution.

## Architecture & Visuals
- **E03-D01-gateway-external-vs-internal** — External API vs internal services
- **E03-D02-gateway-request-flow** — Routing and aggregation flow
- **E03-D03-error-propagation-paths** — Error handling and retries

## What Is Shown (Live / Hands-on)
- Gateway request routing
- Code walkthrough of controllers and downstream clients
- Failure propagation demonstration

## What Is Intentionally Deferred
- Authentication and authorization
- Rate limiting
- Cloud ingress

---

# Episode 4 — Observability: Metrics, Health & Prometheus

## Duration
~10 minutes

## Purpose of this Episode
Establish observability as a foundational capability and explain how health, metrics, and monitoring work together.

## High-Level Narrative

Most teams discover observability only after incidents. In this episode, observability is treated as a design-time concern, not an operational afterthought.

Health, readiness, and liveness are not synonyms. Metrics are signals, not vanity numbers. Dashboards are hypotheses, not truth.

## Architecture & Visuals
- **E04-D01-health-readiness-liveness** — Health vs readiness vs liveness
- **E04-D02-prometheus-scrape-flow** — Prometheus scraping model
- **E04-D03-grafana-dashboard-model** — Dashboards as mental models

## What Is Shown (Live / Hands-on)
- Health and readiness behavior
- Metrics endpoints
- Prometheus scrape results
- Grafana dashboards

## What Is Intentionally Deferred
- Alerting strategies
- Distributed tracing
- AI-based diagnostics

---

# Episode 5 — Performance Pitfalls: Hibernate N+1 Problem

## Duration
~10 minutes

## Purpose of this Episode
Demonstrate a real, common performance problem in production systems and show how seemingly correct abstractions hide severe inefficiencies.

## High-Level Narrative

The most dangerous performance bugs are the ones you cannot see. ORMs increase productivity, but they also hide cost. Without deliberate measurement, teams ship performance regressions to production.

## Architecture & Visuals
- **E05-D01-nplus1-query-pattern** — Broken query pattern
- **E05-D02-optimized-fetch-strategy** — Optimized fetch strategy

## What Is Shown (Live / Hands-on)
- Broken endpoint behavior
- Code walkthrough of JPA mappings
- Fix and validation via tests

## What Is Intentionally Deferred
- Second-level caches
- Database-specific tuning

---

# Episode 6 — Java in Containers: AppCDS, Native Images & CRaC

## Duration
~12 minutes

## Purpose of this Episode
Explain JVM startup and memory behavior in containerized environments and show how **AppCDS, native images (Mandrel/GraalVM), and CRaC** address different parts of the startup problem.

After this episode, viewers should understand that there is no single "silver bullet" — only a spectrum of techniques with different trade-offs.

## High-Level Narrative

JVM startup is not slow by accident. It is slow for concrete, observable reasons: class loading, initialization, and runtime warmup.

This episode deliberately compares **three fundamentally different approaches**:
- *Optimize the JVM* (AppCDS)
- *Change the execution model* (native images)
- *Shift startup cost in time* (CRaC)

Rather than presenting them as competing technologies, the episode frames them as tools for different operational constraints.

## Key Concepts Covered
- JVM startup phases and where time is actually spent
- AppCDS: what it accelerates — and what it doesn’t
- Native images with Mandrel/GraalVM: benefits and costs
- CRaC: checkpoint/restore semantics and constraints

## Architecture & Visuals
- **E06-D01-jvm-startup-phases** — JVM startup phases
- **E06-D02-appcds-classloading** — Class loading with and without AppCDS
- **E06-D03-native-vs-jvm-execution** — JVM vs native execution model
- **E06-D04-crac-checkpoint-restore-flow** — CRaC lifecycle

## What Is Shown (Live / Hands-on)
- Startup time comparison: baseline JVM vs AppCDS
- Code/config walkthrough for AppCDS generation
- Native image build outputs (Mandrel/GraalVM)
- CRaC restore vs cold start comparison

## What Is Intentionally Deferred
- Low-level JVM flags tuning
- GraalVM internals
- CRIU/Warp internals

---


# Episode 7 — JVM Performance Baselines: Java 11 → 17 → 21

## Duration
~10 minutes

## Purpose of this Episode
Show why JVM upgrades are architectural decisions, not just dependency updates.

## High-Level Narrative

Staying on older JVM versions silently costs performance, memory efficiency, and stability. This episode establishes a historical and practical baseline.

## Architecture & Visuals
- **E07-D01-startup-comparison** — Startup time comparison
- **E07-D02-memory-footprint-comparison** — Memory footprint comparison

## What Is Shown (Live / Hands-on)
- Benchmark results
- Version-based comparisons

---

# Episode 8 — Cloud Deployment Strategy (AWS)

## Duration
~10 minutes

## Purpose of this Episode
Explain why infrastructure decisions must follow system understanding.

## High-Level Narrative

Cloud platforms amplify both good and bad architecture. Moving to the cloud without understanding system behavior increases complexity without increasing reliability.

## Architecture & Visuals
- **E08-D01-aws-reference-architecture** — AWS reference architecture
- **E08-D02-frontend-backend-separation** — Frontend outside Kubernetes

## What Is Shown (Live / Hands-on)
- Deployment flow overview
- Configuration walkthrough

---

# Episode 9 — Secure Data Plane: Aurora PostgreSQL IAM Auth

## Duration
~10 minutes

## Purpose of this Episode
Demonstrate modern, credential-free database access using IAM.

## High-Level Narrative

Static database credentials are an operational liability. This episode shows how identity-based access reduces risk and operational burden.

## What Is Shown (Live / Hands-on)
- IAM authentication flow
- Code walkthrough

---

# Episode 10 — Understanding JVM Performance Signals

## Duration
~10 minutes

## Purpose of this Episode
Teach how to *read, interpret, and reason about* JVM performance signals, without yet building benchmarks yourself.

After this episode, viewers should be able to look at performance numbers and ask the *right questions* — instead of drawing the wrong conclusions.

## High-Level Narrative

Performance problems are rarely caused by a single metric. They emerge from interactions between startup behavior, memory usage, garbage collection, and workload shape.

This episode focuses on **performance literacy**: understanding what JVM performance signals actually mean, which ones matter in practice, and which ones are often misunderstood.

## Key Concepts Covered
- Startup time vs steady-state behavior
- Throughput vs latency vs tail latency
- Memory footprint and allocation patterns
- Why JVM version changes affect *signals*, not just speed

## Architecture & Visuals
- **E10-D01-startup-vs-steady-state** — Startup vs steady state lifecycle
- **E10-D02-latency-distribution** — Average vs tail latency
- **E10-D03-memory-signal-overview** — Heap, native memory, GC interaction

## What Is Shown (Live / Hands-on)
- Walkthrough of real performance dashboards and metrics
- Comparison of JVM versions using *existing* measurements
- Guided interpretation: what these signals allow you to conclude — and what they don’t

## What Is Intentionally Deferred
- How to build benchmarks
- Statistical rigor and confidence intervals
- Microbenchmarking tools (e.g., JMH)

---


# Episode 11 — Cutting Edge JVMs: Java 21 vs Java 25

## Duration
~10 minutes

## Purpose of this Episode
Evaluate bleeding-edge JVM upgrades and show how to make upgrade decisions with evidence rather than hype.

## High-Level Narrative

Upgrading to a new major JVM is not a performance lottery ticket — it is a risk-managed decision. This episode focuses on how to evaluate Java 25 pragmatically: what changed, what it means for latency and stability, and when upgrading is worth it.

## Architecture & Visuals
- **E11-D01-java21-vs-java25-change-surface** — What changes between 21 and 25 (high-level categories)
- **E11-D02-risk-reward-decision-matrix** — Decision matrix: risk vs reward
- **E11-D03-operational-stability-checks** — Operational stability checklist (crash loops, GC, tail latency)

## What Is Shown (Live / Hands-on)
- Benchmark comparison outputs across Java 21 vs Java 25
- Short code/config walkthrough of the version matrix setup
- A pragmatic “go/no-go” checklist applied to the platform

## What Is Intentionally Deferred
- Deep dive into individual JEPs
- Vendor-specific EA builds

---

# Episode 12 — Secure Data Plane: Aurora PostgreSQL IAM Auth

## Duration
~10 minutes

## Purpose of this Episode
Show production-grade database access using IAM-based authentication, and explain the operational implications.

## High-Level Narrative

Passwords do not scale operationally. They leak, they live too long, and rotation becomes a tax. Identity-based authentication changes the game — but it introduces new constraints (token TTL, pooling, caching). This episode shows how to adopt IAM auth without breaking your runtime behavior.

## Architecture & Visuals
- **E12-D01-iam-auth-flow** — Token-based DB authentication flow
- **E12-D02-pod-identity-to-db** — Pod Identity (or IRSA) → Aurora auth chain
- **E12-D03-token-ttl-and-pooling** — Token TTL vs connection pooling implications

## What Is Shown (Live / Hands-on)
- Code walkthrough: how tokens are generated and injected
- Kubernetes identity binding (Pod Identity / IRSA) walkthrough
- Test/validation: connectivity and failure modes (expired token, pool behavior)

## What Is Intentionally Deferred
- Cross-account database auth patterns
- Multi-region failover

---

# Episode 13 — Asynchronous Messaging with RabbitMQ

## Duration
~10 minutes

## Purpose of this Episode
Explain event-driven architecture fundamentals with RabbitMQ, including retries and dead-letter queues.

## High-Level Narrative

Synchronous calls are easy — until they become your bottleneck and your failure amplifier. Messaging introduces decoupling, but it also introduces new failure modes. This episode teaches the mental models: delivery guarantees, retries, idempotency, and DLQs.

> Note: In the course plan, finalizing this episode can be intentionally postponed. The blueprint still defines the target scope.

## Architecture & Visuals
- **E13-D01-sync-vs-async-boundaries** — Where async replaces sync
- **E13-D02-event-flow-orders-to-notifications** — Orders emits events → Notifications consumes
- **E13-D03-retry-and-dlq-flow** — Retries and DLQ lifecycle

## What Is Shown (Live / Hands-on)
- Walkthrough of message flow in the local stack
- Code walkthrough: publisher and consumer
- Demo of retries and DLQ handling

## What Is Intentionally Deferred
- Exactly-once semantics
- Kafka comparisons

---

# Episode 14 — AI for Developer Productivity: Amazon Q & Kiro

## Duration
~10 minutes

## Purpose of this Episode
Show how modern AI-assisted developer tools can **increase productivity and quality** when used deliberately — without replacing engineering judgment.

## High-Level Narrative

AI does not make engineers obsolete. It changes *where* they spend their time.

This episode focuses on **AI as a developer tool**, not as a runtime component: understanding how tools like Amazon Q Developer and Kiro fit into daily workflows, and where their limits are.

## Key Concepts Covered
- AI-assisted code understanding and navigation
- Large-scale refactoring and migration support
- Prompting as a technical skill
- Where AI helps — and where it actively hurts

## Architecture & Visuals
- **E14-D01-ai-dev-workflow** — Developer → AI tool → codebase feedback loop
- **E14-D02-human-in-the-loop** — Human oversight and validation
- **E14-D03-ai-failure-modes** — Hallucinations, stale context, overconfidence

## What Is Shown (Live / Hands-on)
- Guided walkthrough of Amazon Q Developer (code explanation, refactoring)
- Example workflow using Kiro for structured changes
- Small, intentional live coding where it clarifies AI-assisted workflows

## What Is Intentionally Deferred
- Fully autonomous code generation
- Model training or fine-tuning

---


# Episode 15 — Benchmarking & Performance Methodology

## Duration
~10 minutes

## Purpose of this Episode
Make benchmarks credible by teaching the methodology: control variables, measure correctly, and interpret results honestly.

## High-Level Narrative

Benchmarks often lie because people accidentally change multiple variables at once. This episode shows how to build a trustworthy benchmarking practice: fixed resources, warmup, multiple samples, and reproducible runs across branches.

## Architecture & Visuals
- **E15-D01-benchmark-pitfalls** — Common pitfalls and why they mislead
- **E15-D02-measurement-lifecycle** — Warmup → measurement → reporting
- **E15-D03-reproducible-branch-matrix** — Branch-based reproducibility model

## What Is Shown (Live / Hands-on)
- Walkthrough of benchmark scripts and the matrix approach
- Example: startup vs steady state measurement
- Example: multi-sample memory snapshots and interpretation

## What Is Intentionally Deferred
- Microbenchmarking with JMH
- Statistical significance deep dive

---

