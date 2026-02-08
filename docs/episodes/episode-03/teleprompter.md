# Episode 3 — API Boundaries, Gateway & Error Containment (Refined)

## Opening – Where systems really fail

In Episode 2, we made the AcmeCorp Platform run locally using Docker Compose.

We also established a non-negotiable rule: **all interaction goes through the Gateway**.

That rule is not about convenience.

It is about survival.

Distributed systems almost never fail because of a single bug.

They fail when boundaries are unclear:

* when internal APIs leak
* when errors propagate uncontrolled
* when clients start to depend on implementation details

In this episode, we sharpen the most important boundary in the system: the **API boundary**.

---

## External vs internal APIs

**[DIAGRAM: E03-D01-gateway-external-vs-internal]**

External APIs are contracts.

Internal APIs are implementation details.

If internal service APIs are exposed directly, three things happen:

1. Clients couple to internal URLs and endpoints
2. Clients rely on internal data structures
3. Refactoring turns into a breaking change

In AcmeCorp, we avoid this entirely.

The **Gateway exposes the only public API**.

Every other API is internal and free to evolve.

---

## Why the Gateway is not just routing

**[DIAGRAM: E03-D02-gateway-request-flow]**

A Gateway that only routes traffic is architectural debt.

The Gateway earns its place by centralizing cross-cutting concerns:

* Authentication and authorization
* Request validation and normalization
* API versioning
* Error translation
* Retry and timeout policies
* Observability hooks (metrics, logs, traces)

Episode 2 insisted on Gateway-based local verification for this exact reason.

If the Gateway is the boundary, it must behave the same locally, in CI, and in production.

---

## Service boundaries vs API boundaries

**[DIAGRAM: E03-D01-gateway-external-vs-internal – boundary emphasis]**

A microservice boundary defines ownership.

An API boundary defines responsibility.

These are not the same thing.

Orders, Catalog, Billing, Notifications, and Analytics are service boundaries.

The Gateway defines the API boundary.

This allows services to evolve independently without exposing instability to clients.

---

## Read paths vs write paths

**[DIAGRAM: E03-D02-gateway-request-flow – read vs write emphasis]**

Not all requests are equal.

**Read paths**:

* often aggregate data
* may tolerate partial degradation
* prioritize latency and consistency

**Write paths**:

* change system state
* must enforce rules strictly
* trigger downstream side effects

The Gateway allows us to treat these paths differently without leaking complexity.

---

## Error propagation and containment

**[DIAGRAM: E03-D03-error-propagation-paths]**

Failure is inevitable.

What matters is where it is contained.

Without a Gateway boundary:

* downstream timeouts reach the client
* internal error messages leak
* clients implement service-specific workarounds

With a Gateway boundary:

* errors are translated into stable external responses
* retry and fallback behavior is centralized
* clients see consistent semantics

---

## Error taxonomy and mapping

**[DIAGRAM: E03-D04-error-taxonomy]**

Not all errors are equal.

The Gateway enforces a clear taxonomy:

* **4xx**: client errors (validation, authorization)
* **5xx**: server-side failures
* **timeouts**: treated explicitly, never leaked raw

Internal services may fail in many ways.

Externally, we expose a small, stable error surface.

---

## Retries, timeouts, and circuit breakers

**[DIAGRAM: E03-D05-retry-circuit-breaker]**

Resilience belongs at the boundary.

Retries inside services amplify load.

Retries at the Gateway are controlled.

Circuit breakers prevent cascading failures.

This is where we decide whether a failure is contained or amplified.

---

## Why this matters for the next episode

Strong API boundaries are a prerequisite for observability.

Metrics, logs, and traces only make sense when boundaries are clear.

In Episode 4, we deploy the platform to Kubernetes and make these boundaries observable.

---

## Closing – Containment over elegance

Good API design is not about elegance.

It is about containment.

Boundaries are what allow systems to evolve without breaking.