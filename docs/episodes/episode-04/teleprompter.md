# Episode 4 — Observability: Metrics, Health & Signals

## Opening – Observability is not optional

**[SHOW: Title slide – “Observability: Metrics & Health”]**

Up to this point, we have focused on structure and behavior.

In Episode 1, we defined the *shape* of the system.
In Episode 2, we made the system run locally and treated local development and CI as equal constraints.
In Episode 3, we introduced strict API boundaries and error containment.

Now we arrive at the question that determines whether this system can be operated at all:

**How do we know what the system is doing?**

Most teams look at metrics only when something is already broken.

At that point, observability turns into forensics.

In this episode, we take a different approach.

Observability is not optional.

It must be designed into the system from day one.

---

## Health, readiness, and liveness

**[SHOW: E04-D01-health-readiness-liveness.md]**

The word “health” is often overloaded.

Not all health checks mean the same thing.

This distinction becomes critical once we run on Kubernetes or behind a load balancer.

* **Liveness** answers: *Is the process alive?*
* **Readiness** answers: *Can this instance handle traffic right now?*
* **Health** is often used as an umbrella term that hides these differences

A service can be alive but not ready.

Routing traffic to an unready service is one of the fastest ways to create cascading failures.

This is exactly why Episode 2 emphasized startup order and readiness signals.

---

## Readiness as a traffic gate

**[SHOW: E04-D01-health-readiness-liveness.md – readiness focus]**

Readiness is not primarily a monitoring signal.

It is a **traffic gate**.

When readiness is false:

* load balancers must stop sending traffic
* Kubernetes must not route requests to the instance

This allows the system to absorb:

* slow startups
* dependency outages
* restore or warmup phases

Without readiness, every transient problem becomes visible to users immediately.

---

## From concepts to real code

**[SHOW: IntelliJ IDEA – `services/orders-service`]**

Observability only exists if signals are produced by real application code.

Concepts alone are not observable.

So let’s look at a concrete example.

We will use the **Orders Service** and start at the very edge: the REST API layer.

---

## OrdersController – the API surface

**[SHOW: IntelliJ – `OrdersController`]**

Let’s look at the `OrdersController`.

This controller is the REST API layer for our orders microservice.

It is annotated with `@RestController` and `@RequestMapping`, which makes it handle all requests under `/api/orders`.

This is the boundary where external requests enter the Orders Service.

---

## CRUD and lifecycle operations

**[SHOW: IntelliJ – scroll through controller methods]**

The controller provides standard CRUD operations:

* `POST` to create orders
* `GET` to retrieve orders
* `PUT` to update orders
* `DELETE` to remove orders

We also support pagination and filtering via query parameters.

Beyond basic CRUD, there are explicit business operations:

* `confirm` to advance the order lifecycle
* `cancel` to roll it back
* a `history` endpoint that shows how an order’s state changed over time

This is a realistic API surface, not a toy example.

---

## The interesting part: no metrics code

**[SHOW: IntelliJ – highlight controller code]**

Now here is the interesting part.

There is **no metrics code** in this controller.

No timers.
No counters.
No manual instrumentation.

And that is intentional.

---

## Zero-code HTTP metrics with Spring Boot Actuator

**[SHOW: IntelliJ – `pom.xml` or `build.gradle`]**

When we add the `spring-boot-starter-actuator` dependency, something important happens.

Every HTTP request to every endpoint is instrumented automatically.

Spring Boot, together with Micrometer, tracks:

* request counts
* response times
* error rates
* HTTP status codes

All of this happens without writing a single line of metrics code.

---

## Prometheus endpoint configuration

**[SHOW: IntelliJ – `application.yml`]**

In our application configuration, we expose the Prometheus endpoint.

This endpoint produces metrics in a format that Prometheus and Grafana can consume directly.

The application does not know about dashboards.

It only exposes signals.

---

## What metrics do we get?

**[SHOW: Browser or terminal – `/actuator/prometheus`]**

For every HTTP endpoint, we automatically get metrics such as:

* request count (`http.server.requests.count`)
* total time spent handling requests (`sum`)
* slowest request (`max`)

Each metric is tagged with:

* the URI
* the HTTP method
* the status code
* the outcome

This allows us to slice and aggregate metrics by endpoint, by success versus failure, or by any combination.

---

## JVM metrics for free

**[SHOW: `/actuator/prometheus` – JVM section]**

In addition to HTTP metrics, we also get JVM metrics automatically.

This includes:

* heap and non-heap memory usage
* garbage collection pauses
* thread counts
* CPU usage

Again, without writing any metrics code.

---

## Seeing metrics in action

**[SHOW: curl or browser call to `/actuator/prometheus`]**

When we curl the Prometheus endpoint, we see hundreds of metrics.

These metrics feed directly into Grafana dashboards.

At this point, observability is no longer abstract.

It is tangible and verifiable.

---

## Demonstrating a performance problem

**[SHOW: IntelliJ – demo endpoint `nplus1`]**

For demonstration purposes, we even have an endpoint called `nplus1`.

This endpoint intentionally introduces a performance problem.

When we call it, response times spike immediately.

The metrics reflect this instantly.

We can see exactly which endpoint is degrading and how it affects latency.

---

## Metrics as signals, not answers

**[SHOW: E04-D02-metrics-signal-model.md]**

Metrics do not explain *why* something happens.

They tell us *where* to look.

In this case, the metrics point us directly at the problematic endpoint.

That is the power of observability.

---

## From metrics to dashboards

**[SHOW: E04-D08-grafana-data-flow.md]**

Metrics become useful when we turn them into views.

That is the role of Grafana.

Grafana does not collect data.

It queries metrics that already exist.

---

## Dashboards as hypotheses

**[SHOW: E04-D05-grafana-dashboard-model.md]**

Dashboards are not truth.

They are hypotheses.

A dashboard says:

*“If something goes wrong, this is where we should look first.”*

Good dashboards align with API boundaries from Episode 3.

---

## Showing a real dashboard

**[SHOW: Grafana – Orders Service Dashboard]**

This dashboard shows:

* request rate
* error rate
* latency percentiles
* JVM behavior

Each panel corresponds to a question, not a feature.

---

## Why observability comes before performance

Without observability:

* performance discussions are guesswork
* optimizations are risky
* regressions go unnoticed

With observability in place, we finally have something we can trust.

---

## Closing – Seeing before fixing

Observability is not about dashboards.

It is about visibility.

Only when we can see the system clearly can we begin to change it safely.

In the next episode, we will use these signals to talk about performance.

Not as theory.

But as something we can measure, reason about, and improve.