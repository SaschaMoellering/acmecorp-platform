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

I’m not trying to prove that microservices are the “right” architecture. And I’m definitely not trying to build some overly complex distributed system just to make it look modern.

That’s not the point.

In this platform, microservices are simply a tool.

They help us expose behavior that you just don’t see in a monolith. Network calls. Startup sequencing. Readiness dependencies. Failure propagation. Resource consumption across boundaries.

But we keep it intentionally small.

Only a handful of services. Each with a clear responsibility. No artificial splitting. No “because we can” decomposition.

If a service owns something, it really owns it.

And communication between services is explicit. You can follow the calls. You can trace the flow. When something is slow, you can reason about why.

That’s the important part.

This platform isn’t about distributed complexity. It’s about understanding system behavior.

How long does it take to start?
What actually consumes memory?
What happens when one service isn’t ready?
How does failure ripple through the system?

If we added too many services, we’d just create noise.

So instead, we keep the system controlled — small enough to understand, but realistic enough to behave like a production system.

Microservices aren’t the objective.

They’re just the setup that lets us study how real Java cloud systems behave under real conditions.

---

## Technology choices

**[SHOW: tech-stack]**

Now let’s quickly walk through the overall tech stack, so you understand how everything fits together.

Think of it in layers.

At the top, we have the client layer.

That’s the React frontend.
It talks to the system over HTTP using JSON APIs.

Nothing exotic there. Just clean HTTPS communication into the backend.

Now directly behind that sits the edge layer.

We have a gateway built with Spring WebFlux.

All external traffic goes through that gateway. It handles routing, aggregation, and acts as the single entry point into the system.

So from the outside, the platform looks like one system.

Internally, it’s multiple services.

Behind the gateway, we move into the service layer.

This is where we mix Spring Boot and Quarkus services.

Some services are implemented in Spring Boot.
Others in Quarkus.

Same domain. Same infrastructure. Different runtime behavior.

That allows us to compare startup time, memory footprint, and framework trade-offs inside a controlled environment.

Then below that, we have the platform layer.

All services run in containers — Docker images.

Those containers are orchestrated either by Kubernetes — typically EKS in the cloud — or Docker Compose when we run locally.

So the environment stays conceptually consistent between local and cloud.

Finally, we have the data and messaging layer.

Postgres as the primary relational database.
RabbitMQ for asynchronous messaging.
Redis for caching and fast data access patterns.

Both Spring Boot and Quarkus services talk to these infrastructure components.

And that’s important.

Because real systems are not just HTTP calls.

They involve persistence, messaging, caching, and network boundaries.

If you look at the flow end-to-end, it’s straightforward:

React sends HTTPS requests →
Gateway receives them →
Gateway routes to Spring Boot or Quarkus services →
Services interact with Postgres, RabbitMQ, and Redis →
Everything runs in containers →
Containers are orchestrated locally or in Kubernetes.

It’s not overly complicated.

But it’s realistic.

And that realism is what allows us to study behavior that actually matters in production.

Startup sequencing.
Dependency readiness.
Database connection pressure.
Message backlog behavior.
Memory consumption across services.

The stack is modern, but intentionally grounded.

Just enough moving parts to behave like a real cloud system —
without turning into an academic distributed systems experiment.

---

## Repository layout mirrors architecture

**[SHOW: E01-D04-repo-mapping.md]**

If you look at the repository, you’ll notice something pretty quickly.

The structure mirrors the architecture.

That’s not accidental.

Each service lives in its own module.
Not just logically separated — physically separated.

So when you open the repository, the boundaries are visible immediately. You don’t have to guess where one responsibility ends and another begins.

The same applies to infrastructure.

Deployment files, Docker definitions, Kubernetes manifests, scripts, benchmarking tools — they’re all explicit.

Nothing is buried inside some opaque build plugin.
Nothing depends on hidden conventions you’re supposed to “just know.”

If something happens in the system, you can trace it from the code to the container to the orchestration layer.

That’s important for what we’re doing here.

Because later in the course, we’ll run experiments.

And when we do that, we need clarity.

If the structure were messy, or if half the behavior were hidden behind build magic, every experiment would become a debugging session.

Instead, the repository is designed to make reasoning easy.

Clear modules.
Clear infrastructure.
Clear tooling.

So when we change something, we know exactly what we changed.

And when the system behaves differently, we can understand why.

---

Gateway service as the entry point

[SHOW: IntelliJ – services/gateway-service]

Let’s start with the gateway.

You can see it sits in its own module. Nothing surprising here.

If you open it, you’ll mostly find routing, API definitions, and some cross-cutting stuff like logging and metrics.

What you won’t find is business logic.

That’s deliberate.

The gateway’s job is to sit at the edge.
It routes requests.
It applies common concerns.
And then it gets out of the way.

We’ll spend much more time here in Episode 3.
For now, just notice how focused it is.

Backend services follow the same pattern

[SHOW: IntelliJ – services/orders-service]

Now let’s open one of the backend services — say, the orders service.

If you’ve worked with Spring or Quarkus before, this will look pretty familiar.

Controllers.
Services.
Domain model.
Persistence.

Nothing exotic.

And that’s the point.

Every backend service follows the same structure.

We’re not trying to be creative with folder layouts.
We’re trying to be predictable.

When you move between services, you shouldn’t have to re-orient yourself.

You should be able to focus on behavior — not on figuring out where things are.

That consistency becomes really helpful later, especially when we start measuring things or introducing failure scenarios.

Because when something behaves differently, you want to know it’s due to the system — not because every service is structured differently.

---

## Infrastructure as part of the system

**[SHOW: E01-D01-system-overview.md – DB, MQ, cache included]**

Infrastructure components are first-class citizens in this platform.

They’re not just “things in the background.”

The database, the message broker, the cache — they all influence how the system behaves.

They affect startup time.
They affect readiness.
They influence failure modes.
And of course, they impact performance.

If Postgres isn’t ready, services behave differently.
If RabbitMQ is slow, you’ll see backpressure.
If Redis is unavailable, certain flows degrade.

These aren’t edge cases — they’re normal production behavior.

That’s why we model these components explicitly from day one.

They’re part of the system. Not external details.

What we are not doing yet

Now, just as important — what we’re not doing in this episode.

We’re not setting up local development in detail yet.
We’re not deploying anything to Kubernetes or the cloud.
And we’re definitely not optimizing.

No tuning. No performance experiments. No benchmarking.

Right now, we’re just establishing structure.

Because optimization without structure is just chaos.

First we understand the system.

Then we run it.

Then we measure it.

And only after that do we start tuning.

Closing – setting expectations

[SHOW: E01-D01-system-overview.md – zoomed out]

So at this point, you should have a clear mental model of the AcmeCorp Platform.

You don’t need to remember every service name.

You don’t need to memorize every technology.

What matters is that you understand the shape of the system.

Where the entry point is.
Where responsibilities live.
How components interact.

That mental model is what we’ll build on in the next episodes.

In the next episode, we’ll actually run the system locally — and you’ll see this architecture move from diagrams into something that behaves.

That’s when it starts to get interesting.