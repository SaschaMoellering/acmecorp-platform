# AcmeCorp Platform — Episode Overview

## **Episode 1 — AcmeCorp Platform Overview & Architecture**

**Purpose:** Set the stage and explain the domain.

- What AcmeCorp Platform is (cloud-native reference platform)
- Business domain overview (orders, catalog, gateway, notifications)
- Microservices architecture
- Tech stack:
    - Spring Boot, Quarkus
    - React frontend
    - Docker, Docker Compose
- High-level request flow
- Why this platform exists (education, performance, observability)

---

## **Episode 2 — Local Development & Docker Compose**

**Purpose:** Show how developers work locally.

- Docker Compose stack walkthrough
- Service dependencies (Postgres, RabbitMQ, Redis)
- Local configuration profiles
- Health endpoints & startup order
- Common local pitfalls
- Verifying the platform locally via Gateway

---

## **Episode 3 — API Design, Gateway & Service Boundaries**

**Purpose:** Explain API exposure and service separation.

- Gateway pattern (Spring WebFlux)
- Routing & aggregation
- Downstream service communication
- Error handling & retries
- Why only the gateway is exposed externally
- API structure and naming conventions

---

## **Episode 4 — Kubernetes & Helm Deployment**

**Purpose:** Move from local to production-style deployment.

- Why Kubernetes for backend services
- Helm basics (umbrella chart + subcharts)
- AcmeCorp Helm structure
- Values vs templates
- Environment separation (dev/prod)
- Gateway Ingress (ALB-ready)
- Why frontend is **not** in Helm

---

## **Episode 5 — Observability: Metrics, Health & Prometheus**

**Purpose:** Make the platform observable.

- Health vs readiness vs liveness
- Spring Boot Actuator
- Quarkus metrics (`/q/metrics`)
- Prometheus scraping (annotations + ServiceMonitor)
- Grafana dashboards
- What to monitor first in production

---

## **Episode 6 — Performance Pitfalls: Hibernate N+1 Problem**

**Purpose:** Show a *real* performance bug and how to fix it.

- What the N+1 problem is
- How it manifests in Hibernate/JPA
- Demo endpoint:
    - `/api/orders/demo/nplus1`
- Optimized path:
    - preload + `findAllWithItemsByIds`
- SQL query count comparison
- Regression test with Hibernate statistics
- Why this matters in real systems

---

## **Episode 7 — Java in Containers: Native Images & CRaC**

**Purpose:** JVM startup & memory optimization.

- JVM startup costs in containers
- GraalVM / Mandrel native images
- Tradeoffs of native vs JVM
- CRaC (Checkpoint/Restore at Runtime)
- When CRaC makes sense
- AppCDS/AOT
- Integration into AcmeCorp services

---

## **Episode 8 — Cloud Deployment Strategy (AWS)**

**Purpose:** Explain real-world AWS architecture choices.

- Backend on Amazon EKS
- Frontend on S3 + CloudFront
- ALB Ingress
- Why we don’t run React in Kubernetes
- Environment separation
- Cost & operational considerations

---

## **Episode 9 — Java Performance Baseline: Java 11 vs Java 17**

**Purpose:** Establish a historical baseline.

- Why Java 11 was common
- Improvements in Java 17
- Startup time comparison
- Memory footprint
- Throughput & latency
- “Free performance” from upgrading

---

## **Episode 10 — Modern JVMs: Java 17 vs Java 21**

**Purpose:** Explain why Java 21 is the new baseline.

- Container ergonomics
- GC improvements
- Memory behavior
- Tail latency stability
- Why `main` = Java 21 in AcmeCorp

---

## **Episode 11 — Cutting Edge JVMs: Java 21 vs Java 25**

**Purpose:** Evaluate bleeding-edge Java.

- What changed in Java 25
- Performance impact
- Stability considerations
- Should you upgrade?
- Risk vs reward analysis

---

## **Episode 12 — Secure Data Plane: Aurora PostgreSQL IAM Auth**

**Purpose:** Show production-grade security.

- Aurora PostgreSQL with IAM authentication
- Why passwords are problematic
- Token-based DB auth
- EKS Pod Identity
- ServiceAccounts & IAM policies
- Orders & Catalog services using IAM auth
- Operational considerations (token TTL, pools)

---

## **Episode 13 — Asynchronous Messaging with RabbitMQ** *(planned / partially implemented)*

**Purpose:** Event-driven architecture basics.

- Why async messaging
- Orders emitting domain events
- Notification service consumption
- Retries & dead-letter queues
- Where RabbitMQ fits in AcmeCorp

*(We intentionally postponed finalizing this episode.)*

---

## **Episode 14 — AI in the Platform**

**Purpose:** Show how AI fits into modern platforms.

- AI-assisted diagnostics
- Performance analysis & anomaly detection
- AI for developer productivity
- Potential integrations (e.g., log analysis, recommendations)
- Where AI adds value (and where it doesn’t)

---

## **Episode 15 — Benchmarking & Performance Methodology**

**Purpose:** Make benchmarks credible.

- Why benchmarks often lie
- Fixed container resources
- Warmup vs measurement
- Startup vs steady state
- Reproducible benchmarking with Git branches
- How AcmeCorp ensures fairness