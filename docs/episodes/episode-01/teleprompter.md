# Episode 1 — Teleprompter Script

> **Opening – Why we need a reference system**

[SHOW: title slide – “AcmeCorp Platform: Architecture Overview”]

In the last episode, I explained why this course exists and what kind of problems we are trying to solve.

In this episode, we need to establish a shared reference point.

Because it’s very hard to talk about architecture, performance, or observability in the abstract.

So instead of discussing patterns in isolation, we’ll anchor everything in a concrete system.

---

> **Why AcmeCorp exists**

[SHOW: E01-D01-system-overview]

The AcmeCorp Platform is a fictional system, but it is not a toy.

It is designed to look and behave like systems I’ve seen in real companies over many years.

At the same time, it avoids unnecessary domain complexity.

The business domain is intentionally boring.

That’s not a weakness — it’s a feature.

---

> **Boring domain, interesting problems**

[SHOW: E01-D01-system-overview, highlight domain services]

Orders, catalogs, notifications.

You’ve seen these domains before.

And that’s exactly the point.

Because when the domain is familiar, we can focus on what actually causes trouble in production:
startup behavior, memory usage, service dependencies, and operational complexity.

---

> **High-level architecture**

[SHOW: E01-D02-service-boundaries]

At a high level, the platform consists of multiple backend services and a single gateway.

The gateway is the only service exposed externally.

All other services are internal.

This is a very deliberate choice.

---

> **Why a single gateway**

[SHOW: E01-D03-request-flow]

In many systems, every service is exposed directly.

That often works at the beginning.

But over time, it creates tight coupling, inconsistent APIs, and a very large blast radius when things go wrong.

By introducing a single gateway, we create a clear boundary.

This boundary becomes central later, when we talk about observability, error handling, and performance.

---

> **Microservices, but with constraints**

[SHOW: E01-D02-service-boundaries, zoomed on internal services]

This platform uses a microservices architecture.

But microservices are not the goal.

They are a means to explore specific behaviors:
startup time, dependency graphs, readiness, and failure propagation.

Throughout the course, we will also talk about where microservices add complexity — and where they don’t.

---

> **Technology choices**

[SHOW: slide with Spring Boot, Quarkus, React, Docker]

The platform uses a mix of Spring Boot and Quarkus.

That is intentional.

It allows us to compare different runtime characteristics within the same overall system.

The frontend is implemented with React, but it is kept separate from the backend.

We do not treat the frontend as just another microservice.

---

> **Repository layout**

[SHOW: E01-D04-repo-mapping]

The repository mirrors the architecture.

Each service lives in its own module.

Infrastructure and tooling are explicit, not hidden.

This structure will make later episodes much easier to follow.

---

> **Infrastructure as part of the system**

[SHOW: E01-D01-system-overview, include DB / MQ / cache]

Databases, messaging systems, and caches are not afterthoughts.

They shape how your system behaves.

So from the very beginning, we treat infrastructure components as first-class parts of the architecture.

---

> **What we are not doing yet**

[SHOW: slide “What we defer”]

In this episode, we are not setting up local development.

We are not discussing Kubernetes or cloud deployment.

And we are not optimizing anything.

All of that comes later — and for good reasons.

---

> **Closing – setting expectations**

[SHOW: E01-D01-system-overview, zoomed out]

By the end of this episode, you should have a clear mental model of the AcmeCorp Platform.

You don’t need to remember every service name.

What matters is that you understand the *shape* of the system.

In the next episode, we’ll start working with the platform locally.

