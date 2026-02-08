# AcmeCorp Platform – Teleprompter Scripts

---

# Episode 1 — Platform Overview & Architecture

## Opening – Why we need a reference system

In the last episode, I explained why this course exists and what kind of problems we are trying to solve.

In this episode, we establish a shared reference point.

Talking about architecture, performance, or observability in the abstract does not work well.

So instead of discussing patterns in isolation, we anchor everything in a concrete system: the **AcmeCorp Platform**.

The goal of this episode is not to explain every detail.

The goal is to build a **shared mental model** that we can reuse in all following episodes.

---

## Why AcmeCorp exists

**[SHOW: E01-D02-domain-map.md]**

Let’s start with the business domain.

AcmeCorp represents a very typical online commerce scenario: customers browse products, place orders, pay for them, and receive notifications.

The domain is intentionally simple and familiar.

This is not a limitation — it is a design choice.

A boring domain removes cognitive noise and lets us focus on technical behavior instead of business trivia.

---

## Boring domain, interesting problems

**[SHOW: E01-D01-system-overview.md – domain services highlighted]**

Here we see the domain translated into backend services.

Each box represents an independently deployable service:

* **Catalog Service** owns product data
* **Orders Service** owns the order lifecycle
* **Billing Service** handles payment and invoicing
* **Notifications Service** sends emails or messages
* **Analytics Service** processes events and metrics

At the front sits the **Gateway Service**.

The important aspect here is ownership.

Each service owns its data and its behavior.

This setup allows us to explore real production problems such as startup ordering, dependency graphs, readiness, and failure propagation.

---

## High-level architecture

**[SHOW: E01-D01-system-overview.md]**

At a high level, this is a classic microservices architecture.

Multiple backend services, deployed independently.

But there is exactly one external entry point: the gateway.

All other services are internal.

This constraint is deliberate and becomes critical later when we talk about observability, error handling, and performance.

---

## Why a single gateway

**[SHOW: E01-D03-request-flow.md]**

Clients never talk directly to backend services.

All requests go through the gateway.

The gateway handles:

* request validation
* authentication and authorization
* logging and metrics
* routing to backend services

This creates a clear boundary between external consumers and internal complexity.

It also drastically reduces coupling and limits the blast radius of failures.

---

## Concrete request flow example

**[SHOW: E01-D03-request-flow.md – step-by-step]**

Let’s walk through a concrete example.

1. A user clicks “Buy” in the frontend
2. The frontend sends `POST /api/orders` to the gateway
3. The gateway forwards the request to Orders Service
4. Orders Service validates the request
5. Orders Service calls Catalog Service to verify product data
6. Orders Service calls Billing Service to trigger payment
7. Domain events are emitted to Analytics and Notifications

From the client’s point of view, this is a single API call.

All orchestration happens inside the platform.

This separation is intentional.

---

## Microservices, but with constraints

**[SHOW: E01-D01-system-overview.md]**

Microservices are not the goal of this platform.

They are a tool to surface system behavior.

We intentionally keep:

* the number of services manageable
* responsibilities clear
* communication explicit

This allows us to reason about startup time, memory usage, readiness, and failure propagation without drowning in complexity.

---

## Technology choices

**[SHOW: tech-stack]**

The backend uses a mix of **Spring Boot** and **Quarkus**.

This is intentional.

It allows us to compare runtime characteristics within the same system:

* JVM startup behavior
* memory footprint
* framework trade-offs

The frontend is built with **React**.

It is deliberately not treated as a backend service.

This mirrors real-world deployments where static assets are typically served via object storage or CDNs.

---

## Repository layout mirrors architecture

**[SHOW: E01-D04-repo-mapping.md]**

The repository structure mirrors the architecture.

Each service lives in its own module.

Infrastructure, scripts, and tooling are explicit.

Nothing is hidden behind build magic or conventions.

This makes later episodes easier to follow and experiments easier to reason about.

---

## Code walkthrough – making the structure tangible

**[SHOW: IntelliJ IDEA – project root]**

Before we move on, let’s briefly open the codebase.

The goal here is not to understand implementation details.

The goal is to connect the diagrams to real files and directories.

---

## Gateway service as the entry point

**[SHOW: IntelliJ – `services/gateway-service`]**

The gateway has a very focused responsibility.

You will typically find:

* routing configuration
* API definitions
* centralized error handling
* cross-cutting concerns like metrics and logging

We will return to this service in much more detail in Episode 3.

---

## Backend services follow the same pattern

**[SHOW: IntelliJ – `services/orders-service`]**

Each backend service follows the same structural pattern.

This consistency is intentional.

It reduces cognitive load and makes cross-service reasoning easier.

We are not interested in clever variations here.

We are interested in predictable structure.

---

## Infrastructure as part of the system

**[SHOW: E01-D01-system-overview.md – DB, MQ, cache included]**

Infrastructure components are first-class citizens.

Databases, message brokers, and caches influence:

* startup behavior
* readiness
* failure modes
* performance

That is why we model them explicitly from day one.

---

## What we are not doing yet

In this episode, we are deliberately not:

* setting up local development
* deploying to Kubernetes or the cloud
* optimizing anything

First we establish structure.

Optimization and tuning come later.

---

## Closing – setting expectations

**[SHOW: E01-D01-system-overview.md – zoomed out]**

At this point, you should have a clear mental model of the AcmeCorp Platform.

You do not need to remember every service name.

What matters is understanding the *shape* of the system and where responsibilities live.

In the next episode, we will make this system run locally and see this architecture in action.
